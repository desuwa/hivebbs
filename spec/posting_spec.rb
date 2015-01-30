#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'spec_helper.rb'

class HiveSpec < MiniTest::Spec
  self.reset_db
  self.reset_dirs
  
  def setup
    HiveSpec.reset_board_dir
    HiveSpec.reset_config
  end
  
  describe 'Posting' do
    it 'allows to post threads' do
      DB.transaction(:rollback => :always) do
        make_post({ 'title' => 'test', 'comment' => 'test' })
      end
      assert last_response.body.include?('http-equiv="Refresh"')
    end
    
    it 'allows to post replies' do
      DB.transaction(:rollback => :always) do
        make_post({ 'thread' => '1', 'comment' => 'test' })
      end
      assert last_response.body.include?('http-equiv="Refresh"')
    end
    
    it 'fails if the thread has no title' do
      DB.transaction(:rollback => :always) do
        make_post({ 'comment' => 'test' })
      end
      assert last_response.body.include?(t(:title_empty))
    end
    
    it 'fails if both the comment and the file fields are empty' do
      DB.transaction(:rollback => :always) do
        make_post({ 'title' => 'test' })
      end
      assert last_response.body.include?(t(:comment_empty))
    end
    
    it 'fails if the title field is too long' do
      DB.transaction(:rollback => :always) do
        make_post({
          'title' => 'W' * (CONFIG[:title_length] + 1),
          'comment' => 'test'
        })
      end
      assert last_response.body.include?(t(:title_too_long))
    end
    
    it 'fails if the name field is too long' do
      DB.transaction(:rollback => :always) do
        make_post({
          'title' => 'test',
          'comment' => 'test',
          'author' => 'W' * (CONFIG[:author_length] + 1)
        })
      end
      assert last_response.body.include?(t(:name_too_long))
    end
    
    it 'fails if the comment field is too long' do
      DB.transaction(:rollback => :always) do
        make_post({
          'title' => 'test',
          'comment' => 'W' * (CONFIG[:comment_length] + 1),
        })
      end
      assert last_response.body.include?(t(:comment_too_long))
    end
    
    it 'fails if the comment field has too many lines' do
      DB.transaction(:rollback => :always) do
        make_post({
          'title' => 'test',
          'comment' => "W\n" * (CONFIG[:comment_lines] + 1),
        })
      end
      assert last_response.body.include?(t(:comment_too_long))
    end
    
    it 'fails if a field contains utf8 characters out of the BMP' do
      DB.transaction(:rollback => :always) do
        ['title', 'comment', 'author'].each do |field|
          p = { 'title' => 'test', 'author' => 'test', 'comment' => 'test' }
          p[field] = '🙊'
          make_post(p)
          assert last_response.body.include?(t(:invalid_chars)), field
        end
      end
    end
    
    it 'enforces cooldowns between new threads' do
      DB.transaction(:rollback => :always) do
        make_post({ 'title' => 'test', 'comment' => 'test' })
        CONFIG[:delay_thread] = 100
        make_post({ 'title' => 'test', 'comment' => 'test' })
        assert last_response.body.include?(t(:fast_post))
      end
    end
    
    it 'enforces cooldowns between new replies' do
      DB.transaction(:rollback => :always) do
        make_post({ 'thread' => '1', 'comment' => 'test' })
        CONFIG[:delay_reply] = 100
        make_post({ 'thread' => '1', 'comment' => 'test' })
        assert last_response.body.include?(t(:fast_post))
      end
    end
    
    it 'fails if the honeypot field is not empty' do
      DB.transaction(:rollback => :always) do
        make_post({ 'title' => 'test', 'email' => '1', 'comment' => 'test' })
        last_response.body.size.must_equal 0
      end
    end
    
    it 'limits the number of replies per thread' do
      CONFIG[:post_limit] = 1
      DB.transaction(:rollback => :always) do
        make_post({ 'thread' => '1', 'comment' => 'test' })
        assert last_response.body.include?(t(:thread_full))
      end
    end
    
    it 'prunes inactive threads when a new thread is made' do
      CONFIG[:thread_limit] = 1
      DB.transaction(:rollback => :always) do
        make_post({ 'title' => 'test', 'comment' => 'test' })
        DB[:threads].first(:id => 1).must_be_nil
      end
    end
    
    it 'understands sage' do
      DB.transaction(:rollback => :always) do
        th = DB[:threads].first(:id => 1)
        post_count = th[:post_count]
        updated_on = th[:updated_on]
        make_post({ 'thread' => '1', 'comment' => 'test', 'sage' => '1' })
        th = DB[:threads].first(:id => 1)
        th[:post_count].must_equal(post_count + 1, "Post didn't go through")
        th[:updated_on].must_equal updated_on
      end
    end
    
    describe 'Captcha' do
      it 'validates reCaptcha v2' do
        CONFIG[:captcha] = true
        
        stub_instance(Net::HTTP, :get, Net::HTTPResponse.new(1.0, 200, 'OK')) do
          # Empty captcha
          stub_instance(Net::HTTPResponse, :body, '{"success":true}') do
            DB.transaction(:rollback => :always) do
              make_post({ 'title' => 'test', 'comment' => 'test' })
            end
          end
          assert last_response.body.include?(t(:captcha_empty_error)), 'Empty'
          
          # Bad captcha
          stub_instance(Net::HTTPResponse, :body, '{"success":false}') do
            DB.transaction(:rollback => :always) do
              make_post({ 'title' => 'test', 'comment' => 'test',
                'g-recaptcha-response' => 'x' })
            end
          end
          assert last_response.body.include?(t(:captcha_invalid_error)), 'Bad'
          
          # Good captcha
          stub_instance(Net::HTTPResponse, :body, '{"success":true}') do
            DB.transaction(:rollback => :always) do
              make_post({ 'title' => 'test', 'comment' => 'test',
                'g-recaptcha-response' => 'x' })
            end
          end
          assert last_response.body.include?('http-equiv="Refresh"'), 'Good'
        end
      end
    end
  end
end
