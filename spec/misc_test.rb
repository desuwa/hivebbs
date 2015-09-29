#!/usr/bin/env ruby

require_relative 'spec_helper.rb'

class HiveTest < MiniTest::Test
  include Hive
  
  APP = BBS.new!
  
  def pages_as_ary(page, total, count)
    pages = []
    APP.paginate_html(page, total, count) do |p|
      pages << p
    end
    pages
  end
  
  def test_html_pagination
    assert_nil APP.paginate_html(1, 1, 5)
    
    assert_equal(1..5, APP.paginate_html(1, 5, 5))
    
    assert_equal([1, 2, 3, :next], pages_as_ary(1, 3, 5))
    
    assert_equal([:previous, 1, 2, 3, :next], pages_as_ary(2, 3, 5))
    
    assert_equal([:previous, 1, 2, 3], pages_as_ary(3, 3, 5))
    
    assert_equal([:first, :previous, 2, 3, :next], pages_as_ary(2, 3, 2))
    
    assert_equal([:first, :previous, 2, 3], pages_as_ary(3, 3, 2))
  end
end
