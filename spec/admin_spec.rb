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
        '/users', '/users/create', '/users/update/1'
      ],
      :post => [
        '/boards/create', '/boards/update', '/boards/delete',
        '/users/create', '/users/update', '/users/delete'
      ]
    },
    :mod => {
      :get => [
        '', '/bans', '/bans/create/test/1/1', '/boards/update/1', '/reports',
        '/profile'
      ],
      :post => [
        '/bans/update', '/profile',
        '/posts/delete', '/reports/delete', '/threads/flags'
      ]
    }
  }
  
  def setup
    HiveSpec.reset_board_dir
    HiveSpec.reset_config
  end
  
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
  
  describe '/manage/auth' do
    it 'shows the login form' do
      get '/manage/auth'
      assert last_response.ok?
    end
    
    it 'logs users in' do
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
            
            if path == '/manage'
              assert last_response.location.include?('/manage'), '/manage'
            else
              assert last_response.forbidden?, "#{group} #{method} #{path}"
            end
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
    
    it 'destroys the session after logging out' do
      sid_as('mod')
      
      post '/manage/logout', { 'csrf' => 'ok' }
      
      assert last_response.redirect?, last_response.body
      assert_empty rack_mock_session.cookie_jar['sid']
      assert_empty rack_mock_session.cookie_jar['csrf']
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
  
  describe '/manage/users' do
    it 'allows to edit user profiles' do
      sid_as('admin')
      get '/manage/users/update/1'
      assert last_response.body.include?(DB[:users].where(id: 1).get(:username))
    end
    
    it 'creates users' do
      sid_as('admin')
      
      DB.transaction(:rollback => :always) do
        post '/manage/users/create', {
          'username' => 'testuser',
          'level' => BBS::USER_LEVELS[:mod],
          'csrf' => 'ok'
        }
        assert DB[:users].first(:username => 'testuser') != nil
      end
    end
    
    it 'updates users' do
      sid_as('admin')
      
      DB.transaction(:rollback => :always) do
        user_id = DB[:users].insert({
          username: 'testupdateuser',
          password: 'testdeluser',
          level: BBS::USER_LEVELS[:mod],
          created_on: Time.now.utc.to_i
        })
        
        post "/manage/users/update", {
          'username' => 'testupdateuser2',
          'level' => BBS::USER_LEVELS[:mod], 'id' => user_id,
          'csrf' => 'ok'
        }
        
        assert DB[:users].first(:id => user_id)[:username] == 'testupdateuser2'
      end
    end
    
    it 'deletes users' do
      sid_as('admin')
      
      DB.transaction(:rollback => :always) do
        user_id = DB[:users].insert({
          username: 'testdeluser',
          password: 'testdeluser',
          level: BBS::USER_LEVELS[:mod],
          created_on: Time.now.utc.to_i
        })
        
        post "/manage/users/delete", {
          'confirm_keyword' => t(:confirm_keyword),
          'id' => user_id, 'csrf' => 'ok'
        }
        
        assert_nil DB[:users].first(:id => user_id)
      end
    end
  end
  
  describe  '/manage/boards' do
    it 'creates boards' do
      HiveSpec.reset_dirs
      
      sid_as('admin')
      
      DB.transaction(:rollback => :always) do
        post '/manage/boards/create', {
          'slug' => 'test2', 'title' => 'Test', 'config' => '', 'csrf' => 'ok'
        }
        assert DB[:boards].first(:slug => 'test2') != nil
      end
    end
    
    it 'updates boards' do
      sid_as('admin')
      
      DB.transaction(:rollback => :always) do
        board_id = DB[:boards].insert({
          slug: 'test2',
          title: 'Test',
          config: '',
          created_on: Time.now.utc.to_i
        })
        
        post "/manage/boards/update", {
          'slug' => 'testing', 'title' => 'Test', 'config' => '{}',
          'id' => board_id, 'csrf' => 'ok',
        }
        
        board = DB[:boards].first(:id => board_id, :slug => 'testing')
        assert board, last_response.body
      end
    end
  
    it 'deletes boards' do
      HiveSpec.reset_dirs
      
      sid_as('admin')
      
      DB.transaction(:rollback => :always) do
        board_id = DB[:boards].insert({
          slug: 'test2',
          title: 'Test',
          config: '',
          created_on: Time.now.utc.to_i
        })
        
        board_dir = "#{app.settings.files_dir}/#{board_id}"
        
        FileUtils.mkdir(board_dir)
        
        post "/manage/boards/delete", {
          'confirm_keyword' => t(:confirm_keyword),
          'id' => board_id, 'csrf' => 'ok'
        }
        
        assert_nil DB[:boards].first(:id => board_id)
        assert File.directory?(board_dir) == false
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
        
        assert_nil DB[:threads].first(:id => tid), 'thread'
        assert_empty DB[:posts].where(:thread_id => tid).all, 'replies'
     end
    end
    
    it 'deletes files only' do
      DB.transaction(:rollback => :always) do
        tid, tnum = prepare_thread
        
        sid_as('admin')
        
        dir = "#{app.settings.files_dir}/1/#{tid}"
        
        post '/manage/posts/delete', {
          'board' => 'test', 'thread' => tnum, 'post' => '3',
          'csrf' => 'ok', 'file_only' => '1'
        }
        
        assert last_response.body.include?(t(:done)), last_response.body
        
        refute_nil DB[:threads].first(:id => tid), 'thread'
        refute_empty DB[:posts].where(:thread_id => tid).all, 'replies'
        
        File.exist?("#{dir}/dead3.jpg").must_equal false, 'file 3'
        File.exist?("#{dir}/t_dead3.jpg").must_equal false, 'thumb 3'
      end
    end
  end
  
  describe '/manage/reports' do
    def prepare_report
      DB[:reports].insert({
        board_id: 1,
        thread_id: 1,
        post_id: 1,
        created_on: Time.now.utc.to_i,
        ip: '127.0.0.1',
        score: 1,
        category: ''
      })
    end
    
    it 'shows reported posts' do
      sid_as('mod')
      get '/manage/reports'
      assert last_response.ok?, last_response.body
    end

    it 'clears reports by post id' do
      DB.transaction(:rollback => :always) do
        prepare_report
        
        sid_as('mod')
        
        post '/manage/reports/delete', { 'post_id' => '1', 'csrf' => 'ok' }
        
        count = DB[:reports].count
        
        assert_equal(0, count)
      end
    end
    
    it 'clears reports when a post is deleted' do
      DB.transaction(:rollback => :always) do
        prepare_report
        
        sid_as('mod')
        
        post '/manage/posts/delete', {
          'board' => 'test', 'thread' => '1', 'post' => '1', 'csrf' => 'ok'
        }
        
        assert_equal(0, DB[:reports].count)
      end
    end
    
    it 'clears reports when a file is deleted' do
      DB.transaction(:rollback => :always) do
        prepare_report
        
        sid_as('mod')
        
        post '/manage/posts/delete', {
          'board' => 'test', 'thread' => '1', 'post' => '1',
          'file_only' => '1', 'csrf' => 'ok'
        }
        
        assert_equal(0, DB[:reports].count)
      end
    end
  end
  
  describe '/manage/bans' do
    # The duration is expressed in hours
    
    it 'allows to create bans from posts' do
      sid_as('mod')
      get '/manage/bans/create/test/1/1'
      assert last_response.ok?, last_response.body
    end
    
    it 'shows a list of most recent bans' do
      sid_as('mod')
      get '/manage/bans'
      assert last_response.ok?, last_response.body
    end
    
    it 'allows to search bans by IP' do
      sid_as('mod')
      
      [
        '192.0.2.1',
        '2001:db8:1:1::1',
        '::ffff:192.0.2.1',
        '::192.0.2.1'
      ].each do |ip|
        DB.transaction(:rollback => :always) do
          ban_id = prepare_ban(ip, 24)
          get '/manage/bans', { 'q' => ip }
          assert last_response.body.include?(ip), last_response.body
        end
      end
    end
    
    it 'creates bans from posts' do
      sid_as('mod')
      
      [
        '192.0.2.1',
        '2001:db8:1:1::1',
        '::ffff:192.0.2.1',
        '::192.0.2.1'
      ].each do |ip|
        DB.transaction(:rollback => :always) do
          tid = insert_thread { |t, p| p[:ip] = ip }
          
          thread = DB[:threads].where(id: tid).get(:num)
          
          post '/manage/bans/update', {
            'board' => 'test', 'thread' => thread, 'post' => 1,
            'duration' => 24, 'reason' => 'test', 'csrf' => 'ok'
          }
          
          assert last_response.body.include?(t(:done)), last_response.body
          
          ip_addr = IPAddr.new(ip)
          
          if ip_addr.ipv6?
            if ip_addr.ipv4_compat? || ip_addr.ipv4_mapped?
              ip_addr = ip_addr.native
            else
              ip_addr = ip_addr.mask(64)
            end
          end
          
          bin_ip = Sequel::SQL::Blob.new(ip_addr.hton)
          assert DB[:bans].first(ip: bin_ip), ip
        end
      end
    end
    
    it 'creates a warning if the duration is zero' do
      sid_as('mod')
      
      DB.transaction(:rollback => :always) do
        post '/manage/bans/update', {
          'board' => 'test', 'thread' => 1, 'post' => 1,
          'duration' => 0, 'reason' => 'test', 'csrf' => 'ok'
        }
        assert_equal(1, DB[:bans].count)
      end
    end
    
    it 'creates a permanent ban if duration < 0 or expires_on > MAX_BAN' do
      sid_as('mod')
      
      DB.transaction(:rollback => :always) do
        post '/manage/bans/update', {
          'board' => 'test', 'thread' => 1, 'post' => 1,
          'duration' => -1, 'reason' => 'test', 'csrf' => 'ok'
        }
        assert_equal(1, DB[:bans].count)
        assert_equal(BBS::MAX_BAN, DB[:bans].first[:expires_on])
      end
      
      DB.transaction(:rollback => :always) do
        post '/manage/bans/update', {
          'board' => 'test', 'thread' => 1, 'post' => 1,
          'duration' => Time.now.to_i, 'reason' => 'test', 'csrf' => 'ok'
        }
        assert_equal(1, DB[:bans].count)
        assert_equal(BBS::MAX_BAN, DB[:bans].first[:expires_on])
      end
    end
    
    it 'requires a public reason' do
      sid_as('mod')
      
      DB.transaction(:rollback => :always) do
        post '/manage/bans/update', {
          'duration' => 24, 'reason' => '', 'csrf' => 'ok'
        }
        assert_equal(0, DB[:bans].count)
        assert last_response.body.include?(t(:empty_ban_reason))
      end
    end
    
    it 'allows to edit existing bans' do
      sid_as('mod')
      DB.transaction(:rollback => :always) do
        ban_id = prepare_ban('192.0.2.1', 24)
        get "/manage/bans/update/#{ban_id}"
        assert last_response.ok?, last_response.body
      end
    end
    
    it 'updates existing bans' do
      sid_as('mod')
      
      DB.transaction(:rollback => :always) do
        reason = Time.now.to_s
        ban_id = prepare_ban('192.0.2.1', 24)
        post "/manage/bans/update", {
          'id' => ban_id, 'duration' => 24, 'reason' => reason, 'csrf' => 'ok'
        }
        assert_equal(1, DB[:bans].count)
        assert_equal(reason, DB[:bans].first[:reason])
      end
    end
  end
  
  describe '/banned' do
    it 'shows when an IPv4 or an IPv6 /64 block is banned or warned' do
      cases = [
        ['192.0.2.1', 3600, '192.0.2.1', 'user-banned'],
        ['192.0.2.1', 0, '192.0.2.1', 'user-warned'],
        ['2001:db8:1:1::1', 3600, '2001:db8:1:1::2', 'user-banned'],
        ['2001:db8:1:1::1', 0, '2001:db8:1:1::2', 'user-warned'],
        ['192.0.2.1', 3600, '192.0.2.2', t(:not_banned)],
        ['2001:db8:1:1::1', 3600, '2001:db8:1:2::1', t(:not_banned)],
        ['::ffff:192.0.2.1', 3600, '::ffff:192.0.2.1', 'user-banned'],
        ['::192.0.2.1', 3600, '::192.0.2.1', 'user-banned'],
      ]
      
      cases.each do |p|
        DB.transaction(:rollback => :always) do
          prepare_ban(p[0], p[1])
          get '/banned', {},  { 'REMOTE_ADDR' => p[2] }
          assert last_response.body.include?(p[3]), "#{p[0]}/#{p[3]} failed"
        end
      end
    end
    
    it 'handles ban expiration' do
      DB.transaction(:rollback => :always) do
        prepare_ban('192.0.2.1', -3600)
        get '/banned', {},  { 'REMOTE_ADDR' => '192.0.2.1' }
        assert_equal(false, DB[:bans].first[:active])
      end
    end
  end
  
  describe 'Thread pinning' do
    it 'can pin threads to the top of the list' do
      sid_as('mod')
      
      DB.transaction(:rollback => :always) do
        post '/manage/threads/flags', {
          'board' => 'test',
          'thread' => '1',
          'flag' => 'pinned',
          'value' => '1',
          'csrf' => 'ok'
        }
        
        assert last_response.body.include?(t(:done)), last_response.body
        assert_equal 1, DB[:threads].first(:id => 1)[:pinned]
      end
    end
    
    it 'respects pinning order' do
      sid_as('mod')
      
      DB.transaction(:rollback => :always) do
        title_bottom = 'BottomPin'
        title_top = 'TopPin'
        
        insert_thread do |t, p|
          t[:board_id] = 1
          t[:title] = title_bottom
          t[:pinned] = 1
        end
        
        insert_thread do |t, p|
          t[:board_id] = 1
          t[:title] = title_top
          t[:pinned] = 2
        end
        
        get '/test/'
        body = last_response.body
        
        assert body.index(title_top) < body.index(title_bottom)
      end
    end
  end
  
  describe 'Thread locking' do
    it 'makes threads unable to receive new replies' do
      sid_as('mod')
      
      DB.transaction(:rollback => :always) do
        post '/manage/threads/flags', {
          'board' => 'test',
          'thread' => '1',
          'flag' => 'locked',
          'value' => BBS::THREAD_LOCKED,
          'csrf' => 'ok'
        }
        
        assert last_response.body.include?(t(:done)), last_response.body
        assert_equal BBS::THREAD_LOCKED, DB[:threads].first(:id => 1)[:locked]
      end
    end
  end
  
  describe '/manage/profile' do
    it 'shows the profile of the currently logged in user' do
      sid_as('mod')
      get '/manage/profile'
      assert last_response.ok?
    end
    
    it 'lets users change their password' do
      sid_as('mod')
      new_pwd = 'newmod1337'
      DB.transaction(:rollback => :always) do
        post '/manage/profile', {
          'old_pwd' => 'mod',
          'new_pwd' => new_pwd,
          'new_pwd_again' => new_pwd,
          'csrf' => 'ok'
        }
        assert last_response.body.include?(t(:done)), last_response.body
        user = DB[:users].first(:username => 'mod')
        assert app.password_valid?(new_pwd, user[:password])
      end
    end
    
    it 'validates password complexity' do
      sid_as('mod')
      new_pwd = '1'
      DB.transaction(:rollback => :always) do
        post '/manage/profile', {
          'old_pwd' => 'mod',
          'new_pwd' => new_pwd,
          'new_pwd_again' => new_pwd,
          'csrf' => 'ok'
        }
        body = last_response.body
        assert body.include?(t(:passwd_too_short)), body
      end
    end
    
    it 'validates password confirmation' do
      sid_as('mod')
      new_pwd = 'newmod1337'
      DB.transaction(:rollback => :always) do
        post '/manage/profile', {
          'old_pwd' => 'mod',
          'new_pwd' => new_pwd,
          'new_pwd_again' => 'nope',
          'csrf' => 'ok'
        }
        body = last_response.body
        assert body.include?(t(:passwd_mismatch)), body
      end
    end
    
    it 'validates old password' do
      sid_as('mod')
      new_pwd = 'newmod1337'
      DB.transaction(:rollback => :always) do
        post '/manage/profile', {
          'old_pwd' => 'nope',
          'new_pwd' => new_pwd,
          'new_pwd_again' => new_pwd,
          'csrf' => 'ok'
        }
        assert last_response.forbidden?, last_response.body
      end
    end
  end
end
