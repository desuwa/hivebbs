ENV['RACK_ENV'] = 'test'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start { add_filter '/spec/' }
end

require_relative '../hive.rb'
require 'minitest'
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
  CONFIG[:delay_report] = 0
  CONFIG[:file_uploads] = true
  CONFIG[:post_reporting] = true
  CONFIG[:reporting_captcha] = false
  
  CONFIG_CLEAN = Marshal.load(Marshal.dump(CONFIG))
  
  DIRS = [:files_dir, :tmp_dir]
  
  def app
    BBS.new!
  end
  
  def t(str)
    BBS::STRINGS[str]
  end
  
  def make_post(fields = {}, rack_env = {})
    fields['board'] = 'test'
    
    if fields['file']
      fields['file'] = Rack::Test::UploadedFile.new(
        "#{DATA}/#{fields['file']}", 'application/octet-stream', true
      )
    end
    
    post '/post', fields, rack_env
  end
  
  def insert_thread(opts = {})
    num = DB[:threads].max(:num).to_i + 1
    
    now = Time.now.utc.to_i
    
    tid = DB[:threads].insert({
      board_id: 1,
      num: num,
      title: "Test #{num}",
      created_on: now,
      updated_on: now,
      post_count: 1
    }.merge(opts))
    
    DB[:posts].insert({
      board_id: opts[:board_id] || 1,
      thread_id: num,
      num: 1,
      created_on: now,
      ip: '127.0.0.1',
      comment: "Test #{num}"
    })
    
    return tid
  end
  
  def prepare_ban(ip_str, seconds = nil, active = true)
    now = Time.now.utc.to_i
    
    if !seconds
      expires_on = BBS::MAX_BAN
    else
      expires_on = now + seconds
    end
    
    ip_addr = IPAddr.new(ip_str)
    
    if ip_addr.ipv6?
      if ip_addr.ipv4_compat? || ip_addr.ipv4_mapped?
        ip_addr = ip_addr.native
      else
        ip_addr = ip_addr.mask(64)
      end
    end
    
    post = DB[:posts].first
    
    post[:slug] = 'test'
    
    DB[:bans].insert({
      :active => active,
      :created_on => now,
      :expires_on => expires_on,
      :duration => seconds.to_i / 3600,
      :reason => 'test reason',
      :info => 'test description',
      :ip => Sequel::SQL::Blob.new(ip_addr.hton),
      :created_by => 1,
      :post => post.to_json
    })
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
      
      FileUtils.rm_rf(path) if File.directory?(path)
      FileUtils.mkdir_p(path)
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
      #DB.run("DROP TABLE IF EXISTS sqlite_sequence")
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
  
  def stub_instance(klass, method, ret)
    tmp_method = "__hive_#{method}"
    
    klass.class_eval do
      alias_method tmp_method, method
      
      define_method(method) do |*args|
        if ret.respond_to? :call
          ret.call(*args)
        else
          ret
        end
      end
    end
    
    yield
  ensure
    klass.class_eval do
      undef_method method
      alias_method method, tmp_method
      undef_method tmp_method
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
