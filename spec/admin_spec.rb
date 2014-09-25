#!/usr/bin/env ruby

require_relative 'spec_helper.rb'

class HiveSpec < MiniTest::Spec
  self.reset_db
  self.reset_dirs
  
  CONFIG[:delay_auth] = 0
  
  REQUIRED_LEVELS = {
    :admin => {
      :get => [
        '/boards', '/boards/create', '/boards/update/1',
        '/users', '/users/create', '/users/update/1',
      ],
      :post => [
        '/boards/create', '/boards/update/1', '/boards/delete/1',
        '/users/create', '/users/update/1',
      ]
    },
    :mod => {
      :get => [
        '/bans', '/bans/create/test/1/1', '/boards/update/1',
      ],
      :post => [
        '/bans/create/test/1/1', '/boards/update/1',
        '/posts/delete'
      ]
    }
  }
  
  def auth(u, p = nil, csrf = '123')
    set_cookie "auth_csrf=#{csrf}" if csrf
    
    DB.transaction(:rollback => :always) do
      post '/manage/auth', {
        'username' => u,
        'password' => p || u,
        'auth_csrf' => csrf
      }
    end
  end
  
  def sid_as(group)
    set_cookie "sid=#{group}"
    set_cookie "csrf=ok"
  end
  
  describe '/manage/auth' do
    it 'works' do
      auth('admin')
      last_response.location.must_include '/manage'
    end
    
    it 'uses case-sensitive credentials' do
      auth('Admin')
      assert last_response.forbidden?
      
      auth('admin', 'Admin')
      assert last_response.forbidden?
    end
    
    it 'validates csrf tokens' do
      auth('admin', nil, nil)
      assert last_response.bad_request?
    end
  end
  
  describe '/manage' do
    it 'enforces access levels' do
      sorted_levels =
        BBS::USER_LEVELS.to_a.sort { |a, b| b[1] <=> a[1] }.map { |a| a[0] }
      
      sorted_levels << :none
      
      REQUIRED_LEVELS.each do |group, methods|
        above = sorted_levels[sorted_levels.index(group) + 1]
        
        sid_as(above)
        
        methods.each do |method, paths|
          paths.each do |path|
            path = "/manage#{path}"
            
            DB.transaction(:rollback => :always) do
              if method == :post
                post path, { 'csrf' => 'ok' }
              else
                get path
              end
            end
            
            assert last_response.forbidden?, "#{group} #{method} #{path}"
          end
        end
      end
    end
    
    it 'validates csrf tokens' do
      REQUIRED_LEVELS.each do |group, methods|
        next unless methods[:post]
        
        methods[:post].each do |path|
          DB.transaction(:rollback => :always) do
            post "/manage#{path}"
          end
          
          assert last_response.bad_request?, "#{group} /manage#{path}"
        end
      end
    end
  end
  
  describe 'Capcodes' do
    it 'uses the capcode_{level} posting command' do
      REQUIRED_LEVELS.each_key do |level|
        HiveSpec.reset_board_dir
        
        sid_as(level)
        
        DB.transaction(:rollback => :always) do
          make_post({
            'title' => 'test', 'comment' => 'test',
            'author' => "##capcode_#{level}"
          })
        end
        
        assert last_response.body.include?('http-equiv="Refresh"')
      end
    end
  end
  
  describe '/manage/posts/delete' do
    def prepare_thread
      make_post({ 'title' => 'test', 'comment' => 'test' })
      
      tid, tnum = DB[:threads].select(:id, :num).reverse_order(:id).first.values
      
      2.times do
        make_post({ 'thread' => tnum, 'comment' => 'test' })
      end
      
      dir = "#{app.settings.files_dir}/1/#{tid}"
      meta = { file: { ext: 'jpg' } }.to_json
      
      3.times do |i|
        i += 1
        DB[:posts].where(:thread_id => tid, :num => i).update({
          :file_hash => "dead#{i}",
          :meta => meta
        })
        
        FileUtils.touch("#{dir}/dead#{i}.jpg")
        FileUtils.touch("#{dir}/t_dead#{i}.jpg")
      end
      
      [tid, tnum]
    end
    
    it 'deletes posts' do
      DB.transaction(:rollback => :always) do
        tid, tnum = prepare_thread
        
        sid_as('admin')
        
        dir = "#{app.settings.files_dir}/1/#{tid}"
        
        # Delete last reply
        post '/manage/posts/delete', {
          'board' => 'test', 'thread' => tnum, 'post' => '3', 'csrf' => 'ok'
        }
        
        assert last_response.body.include?(t(:done)), last_response.body
        
        File.exist?("#{dir}/dead3.jpg").must_equal false, 'file 3'
        File.exist?("#{dir}/t_dead3.jpg").must_equal false, 'thumb 3'
        
        # Delete whole thread
        post '/manage/posts/delete', {
          'board' => 'test', 'thread' => tnum, 'post' => '1', 'csrf' => 'ok'
        }
        
        assert last_response.body.include?(t(:done)), last_response.body
        
        2.times do |i|
          i += 1
          File.exist?("#{dir}/dead#{i}.jpg").must_equal false, "file #{i}"
          File.exist?("#{dir}/t_dead#{i}.jpg").must_equal false, "thumb #{i}"
        end
      end
    end
  end
end
