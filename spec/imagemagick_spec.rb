#!/usr/bin/env ruby

require_relative 'spec_helper.rb'

class HiveSpec < MiniTest::Spec
  self.reset_db
  self.reset_dirs
  
  def setup
    HiveSpec.reset_board_dir
    HiveSpec.reset_config
  end
  
  def post_file(file)
    skip "Missing sample data: #{file}" unless File.exist?("#{DATA}/#{file}")
    DB.transaction(:rollback => :always) do
      make_post({ 'title' => 'Test', 'file' => file })
    end
  end
  
  describe 'ImageMagick file handler' do
    it 'validates and renders thumbnails for image files' do
      post_file('test.png')
      assert last_response.body.include?('http-equiv="Refresh"')
    end
    
    it 'fails if the file is not a valid image' do
      post_file('test_blank.png')
      assert last_response.body.include?(t(:bad_file_format))
    end
    
    it 'enforces dimensions limits' do
      CONFIG[:file_limits][:image][:dimensions] = 0
      post_file('test.png')
      assert last_response.body.include?(t(:dimensions_too_large))
    end
    
    it 'enforces file size limits' do
      CONFIG[:file_limits][:image][:file_size] = 0
      post_file('test.png')
      assert last_response.body.include?(t(:file_size_too_big))
    end
    
    it 'only accepts allowed file types' do
      CONFIG[:file_types] = ['png']
      post_file('test_gif.png')
      assert last_response.body.include?(t(:bad_file_format))
    end
  end
end
