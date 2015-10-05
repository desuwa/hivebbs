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
  
  def test_tripcodes
    assert APP.make_tripcode('test')
  end
  
  def test_pretty_bytesize
    {
      1023 => '1023 B',
      1024 => '1 KiB',
      10250 => '10 KiB',
      1048576 => '1.0 MiB',
      10485770 => '10.0 MiB'
    }.each { |k, v| assert_equal v, APP.pretty_bytesize(k) }
  end
end
