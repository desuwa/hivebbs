ENV['RACK_ENV'] = 'test'

require_relative '../hive.rb'
require 'minitest/autorun'
require 'rack/test'

class HiveSpec < MiniTest::Spec
  
  include Rack::Test::Methods
  
  include Hive
  
  DATA = File.expand_path(File.dirname(__FILE__)) + '/data'
  
  DB = BBS::DB
  
  CONFIG = BBS::CONFIG
  
  CONFIG[:delay_thread] = 0
  CONFIG[:delay_reply] = 0
  CONFIG[:file_uploads] = true
  
  CONFIG_CLEAN = Marshal.load(Marshal.dump(CONFIG))
  
  DIRS = [:files_dir, :tmp_dir]
  
  def app
    BBS.new!
  end
  
  def t(str)
    BBS::STRINGS[str]
  end
  
  def make_post(fields = {})
    fields['board'] = 'test'
    
    if fields['file']
      fields['file'] = Rack::Test::UploadedFile.new(
        "#{DATA}/#{fields['file']}", 'application/octet-stream', true
      )
    end
    
    post '/post', fields
  end
  
  def self.reset_config
    CONFIG.merge!(Marshal.load(Marshal.dump(CONFIG_CLEAN)))
  end
  
  def self.reset_board_dir
    FileUtils.rm_rf(BBS.settings.files_dir + '/1')
    FileUtils.mkdir_p(BBS.settings.files_dir + '/1/1')
  end
  
  def self.reset_dirs
    DIRS.each do |dir|
      path = BBS.settings.send(dir)
      
      unless File.directory?(path)
        FileUtils.mkdir_p(path)
      end
    end
    
    self.reset_board_dir
  end
  
  def self.reset_db
    now = Time.now.utc.to_i - 1
    
    trunc = 'TRUNCATE TABLE %s'
    
    if DB.database_type == :sqlite
      sql = "SELECT name FROM sqlite_master WHERE type = 'table'"
      DB.fetch(sql).each do |row|
        table = row.values.first
        next if table == 'schema_info'
        DB.run("DELETE FROM #{table}")
      end
      DB.run("DROP TABLE IF EXISTS sqlite_sequence")
    elsif DB.database_type == :postgres
      sql = "SELECT table_name FROM information_schema.tables " <<
            "WHERE table_schema='public'"
      DB.fetch(sql).each do |row|
        table = row.values.first
        next if table == 'schema_info'
        DB.run("TRUNCATE TABLE #{table} RESTART IDENTITY")
      end
      trunc << ' RESTART IDENTITY'
    else
      DB.fetch('SHOW TABLES').each do |row|
        table = row.values.first
        next if table == 'schema_info'
        DB[table.to_sym].truncate
      end
    end
    
    DB[:boards].insert({
      slug: 'test',
      title: 'Test',
      created_on: now,
      thread_count: 1
    })
    
    DB[:threads].insert({
      board_id: 1,
      num: 1,
      title: 'Test',
      created_on: now,
      updated_on: now,
      post_count: 1
    })
    
    DB[:posts].insert({
      board_id: 1,
      thread_id: 1,
      num: 1,
      created_on: now,
      ip: '127.0.0.1',
      comment: 'Test'
    })
    
    BBS::USER_LEVELS.merge({ 'none' => 0 }).each do |username, level|
      DB[:users].insert({
        username: username.to_s,
        password: BCrypt::Password.create(username.to_s),
        level: level,
        created_on: now,
      })
    end
    
    BBS::USER_LEVELS.merge({ 'none' => 0 }).keys.each_with_index do |user, id|
      DB[:sessions].insert({
        sid: BBS.new!.hash_session_id(user.to_s),
        user_id: id + 1,
        ip: '127.0.0.1',
        created_on: now,
        updated_on: now
      })
    end
  
  end

  Minitest.after_run do
    DIRS.each do |dir|
      path = BBS.settings.send(dir)
      
      if File.directory?(path)
        FileUtils.rm_rf(path)
      end
    end
  end
  
end
