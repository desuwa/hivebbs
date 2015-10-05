#!/usr/bin/env ruby

require_relative 'spec_helper.rb'

class HiveSpec < MiniTest::Spec
  self.reset_db
  self.reset_dirs
  
  def setup
    HiveSpec.reset_config
  end
  
  describe 'Index page' do
    it 'lists boards' do
      get '/'
      assert last_response.ok?
    end
  end
  
  describe 'Board page' do
    it 'lists threads' do
      get '/test/'
      assert last_response.ok?
    end
    
    it 'redirects to the board root when the page number is 1' do
      get '/test/1'
      assert last_response.redirect?
      assert last_response['Location'].end_with?('/test/')
    end
    
    it 'returns 404 for out of bounds page numbers' do
      get '/test/0'
      assert last_response.not_found?, "Page 0 didn't 404"
      get '/test/2'
      assert last_response.not_found?, "Out of bounds page didn't 404"
      CONFIG[:threads_per_page] = nil
      get '/test/1'
      assert last_response.not_found?, "Pagination disabled"
    end
  end
  
  describe 'Thread page' do
    it 'displays the thread' do
      get '/test/read/1'
      assert last_response.ok?
    end
  end
  
  describe '/markup' do
    it 'generates comment previews' do
      post '/markup', { 'comment' => '*test*' }
      assert last_response.body.include?('>test</')
    end
  end
end
