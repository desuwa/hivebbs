#!/usr/bin/env ruby

require_relative 'spec_helper.rb'

class HiveSpec < MiniTest::Spec
  self.reset_db
  self.reset_dirs
  
  def setup
    HiveSpec.reset_board_dir
    HiveSpec.reset_config
  end
  
  describe 'Reporting' do
    it 'lets users request post deletion' do
      DB.transaction(:rollback => :always) do
        post '/report/test/1/1'
        count = DB[:reports].count
        assert_equal(1, count)
      end
    end
    
    it 'can be disabled' do
      CONFIG[:post_reporting] = false
      DB.transaction(:rollback => :always) do
        post '/report/test/1/1'
        count = DB[:reports].count
        assert_equal(0, count)
        assert last_response.body.include?(t(:cannot_report))
      end
    end
    
    it 'supports categories and priorities' do
      CONFIG[:report_categories] = {
        'rule' => 1,
        'illegal' => 100
      }
      
      DB.transaction(:rollback => :always) do
        post '/report/test/1/1'
        count = DB[:reports].count
        assert_equal(0, count)
        assert last_response.body.include?(t(:bad_report_cat))
      end
      
      DB.transaction(:rollback => :always) do
        post '/report/test/1/1', { 'category' => 'rule' }
        count = DB[:reports].count
        assert_equal(1, count)
      end
    end
    
    it 'only allows one report per user per post' do
      DB.transaction(:rollback => :always) do
        post '/report/test/1/1'
        post '/report/test/1/1'
        count = DB[:reports].count
        assert_equal(1, count)
        assert last_response.body.include?(t(:duplicate_report))
      end
    end
    
    it 'enforces cooldowns' do
      CONFIG[:delay_report] = 9999
      DB.transaction(:rollback => :always) do
        post '/report/test/1/1'
        make_post({ 'thread' => '1', 'comment' => 'test' })
        post '/report/test/1/2'
        count = DB[:reports].count
        assert_equal(1, count)
        assert last_response.body.include?(t(:fast_report))
      end
    end
    
    it 'fails if the honeypot field is not empty' do
      DB.transaction(:rollback => :always) do
        post '/report/test/1/1', { 'email' => '1' }
        last_response.body.size.must_equal 0
      end
    end
  end
end
