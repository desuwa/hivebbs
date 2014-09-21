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
  
  describe 'FFmpeg file handler' do
    it 'validates and renders thumbnails for video files' do
      post_file('test.webm')
      assert last_response.body.include?('http-equiv="Refresh"')
    end
    
    it 'fails if the file is not matroska' do
      post_file('test_png.webm')
      assert last_response.body.include?(t(:bad_file_format))
    end
    
    it 'enforces duration limits' do
      CONFIG[:file_limits][:video][:duration] = 0
      post_file('test.webm')
      assert last_response.body.include?(t(:duration_too_long))
    end
    
    it 'enforces dimensions limits' do
      CONFIG[:file_limits][:video][:dimensions] = 0
      post_file('test.webm')
      assert last_response.body.include?(t(:dimensions_too_large))
    end
    
    it 'enforces file size limits' do
      CONFIG[:file_limits][:video][:file_size] = 0
      post_file('test.webm')
      assert last_response.body.include?(t(:file_size_too_big))
    end
    
    it 'rejects files with audio streams when allow_audio is false' do
      CONFIG[:file_limits][:video][:allow_audio] = false
      post_file('test_audio.webm')
      assert last_response.body.include?(t(:webm_audio_disabled))
    end
    
    it 'accepts files with audio streams when allow_audio is true' do
      CONFIG[:file_limits][:video][:allow_audio] = true
      post_file('test_audio.webm')
      assert last_response.body.include?('http-equiv="Refresh"')
    end
    
    it 'only accepts VP8 video streams' do
      post_file('test_vp9.webm')
      assert last_response.body.include?(t(:invalid_video))
    end
    
    it 'rejects files with multiple video streams' do
      post_file('test_multi_v.webm')
      assert last_response.body.include?(t(:too_many_video))
    end
    
    it 'rejects files with multiple audio streams' do
      CONFIG[:file_limits][:video][:allow_audio] = true
      post_file('test_multi_a.webm')
      assert last_response.body.include?(t(:too_many_audio))
    end
    
    it 'rejects files without a video stream' do
      CONFIG[:file_limits][:video][:allow_audio] = true
      post_file('test_no_v.webm')
      assert last_response.body.include?(t(:no_video_streams))
    end
  end
end
