#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/hive.rb')

Hive::BBS::DB.disconnect

run Hive::BBS
