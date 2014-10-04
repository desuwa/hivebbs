#!/usr/bin/env ruby

require 'bcrypt'
require 'erubis'
require 'escape_utils'
require 'fileutils'
require 'hive_markup'
require 'ipaddr'
require 'json'
require 'logger'
require 'openssl'
require 'resolv'
require 'sequel'
require 'sinatra/base'
require 'timeout'

Encoding.default_external = 'UTF-8'

module Hive

class BBS < Sinatra::Base
  VERSION = '0.0.1'
  
  Dir.glob("#{settings.root}/helpers/*.rb").each { |f| require f }
  
  if settings.test?
    env_sfx = '_test'
  else
    env_sfx = ''
  end
  
  DB = Sequel.connect(eval(
      File.open("#{settings.root}/config/db#{env_sfx}.rb", 'r') { |f| f.read }
    )
  )
  
  if settings.development?
    DB.logger = Logger.new($stdout)
  end
  
  CONFIG = eval(
    File.open("#{settings.root}/config/config.rb", 'r') { |f| f.read }
  )
  
  STRINGS = eval(
    File.open("#{settings.root}/i18n/#{CONFIG[:locale]}.rb", 'r') { |f| f.read }
  )
  
  TRIP_KEY = File.binread("#{settings.root}/config/trip.key")
  
  LOGGER = Logger.new("#{settings.root}/log/error.log", 524288)
  
  set :erb, :engine_class => Erubis::FastEruby
  
  set :files_dir, "#{settings.public_folder}/files#{env_sfx}"
  
  set :tmp_dir, "#{settings.root}/tmp#{env_sfx}"
  
  set :protection, false
  
  ASSETS = {}
  
  get '/' do
    @boards = DB[:boards].all
    erb :index
  end
  
  get %r{^/([0-9a-z]+)/$} do |slug|
    @board = DB[:boards].where(:slug => slug).first
    
    halt 404 if !@board
    
    @threads = DB[:threads]
      .reverse_order(:updated_on)
      .where(:board_id => @board[:id])
      .all
    
    @board_cfg = get_board_config(@board)
    
    erb :board
  end
  
  get %r{^/([0-9a-z]+)/read/([0-9]+)$} do |slug, num|
    @board = DB[:boards].first(:slug => slug)
    
    halt 404 if !@board
    
    @thread = DB[:threads].first(:board_id => @board[:id], :num => num.to_i)
    
    halt 404 if !@thread
    
    @posts = DB[:posts].where(:thread_id => @thread[:id]).all
    
    @board_cfg = get_board_config(@board)
    
    erb :read
  end
  
  post '/markup' do
    content_type :json
    
    comment = params['comment'].to_s
    
    data = if comment.empty?
      comment
    else
      Markup.render(comment)
    end
    
    { status: 'success', data: data }.to_json
  end
  
  post '/post' do
    validate_referrer
    
    halt if params['email'] && !params['email'].empty?
    
    board = DB[:boards].where(:slug => params['board'].to_s).first
    
    failure t(:bad_board) if !board
    
    @board_cfg = get_board_config(board)
    
    now = Time.now.utc.to_i
    
    thread_num = params['thread'].to_i
    
    is_new_thread = thread_num == 0
    
    if is_new_thread
      throttle = now - cfg(:delay_thread)
      
      last_post = DB[:posts].select(1).reverse_order(:id)
        .first('ip = ? AND num = 1 AND created_on > ?', request.ip, throttle)
    else
      throttle = now - cfg(:delay_reply)
      
      last_post = DB[:posts].select(1).reverse_order(:id)
        .first('ip = ? AND created_on > ?', request.ip, throttle)
    end
    
    if last_post
      failure t(:fast_post)
    end
    
    #
    # Ban checks
    #
    ip_addr = IPAddr.new(request.ip)
    
    if ip_addr.ipv6?
      if ip_addr.ipv4_compat? || ip_addr.ipv4_mapped?
        ip_addr = ip_addr.native
      else
        ip_addr = ip_addr.mask(64)
      end
    end
    
    ip_addr = Sequel::SQL::Blob.new(ip_addr.hton)
    
    if DB[:bans].first('ip = ? AND active = ?', ip_addr, true)
      redirect '/banned'
    end
    
    #
    # Author
    #
    author = params['author'].to_s
    
    tripcode = command = nil
    
    if author.empty?
      author = nil
    else
      if author.include?('#')
        author, tripcode, command = author.split('#', 3)
      end
      
      author.gsub!(/[^[:print:]]/u, '')
      author.strip!
      
      if !author.empty? && author != cfg(:anon, @board_cfg)
        if /[^\u0000-\uffff]/u =~ author
          failure t(:invalid_chars)
        end
        
        if author.length > cfg(:author_length)
          failure t(:name_too_long) 
        end
        
        author = EscapeUtils.escape_html(author)
      else
        author = nil
      end
    end
    
    if tripcode
      if tripcode.empty?
        tripcode = nil
      else
        tripcode = make_tripcode(tripcode)
      end
    end
    
    #
    # Comment
    #
    comment = params['comment'].to_s
    
    if /[^\u0000-\uffff]/u =~ comment
      failure t(:invalid_chars)
    end
    
    if comment.lines.count > cfg(:comment_lines)
      failure t(:comment_too_long) 
    end
    
    if comment.length > cfg(:comment_length)
      failure t(:comment_too_long)
    end
    
    comment = Markup.render(comment)
    #comment.gsub!(/[^[:print:]]/u, '')
    
    if comment.empty? || !(/[[:graph:]]/u =~ comment)
      comment = nil
    end
    
    #
    # Title
    #
    if is_new_thread
      title = params['title'].to_s
      title.strip!
      title.gsub!(/[^[:print:]]/u, '')
      
      if title.empty?
        failure t(:title_empty)
      end
      
      if /[^\u0000-\uffff]/u =~ title
        failure t(:invalid_chars)
      end
      
      if title.length > cfg(:title_length)
        failure t(:title_too_long)
      end
      
      title = EscapeUtils.escape_html(title)
    else
      thread = DB[:threads].first(:board_id => board[:id], :num => thread_num)
      
      if !thread
        failure t(:bad_thread)
      end
      
      if thread[:post_count] >= cfg(:post_limit)
        failure t(:thread_full)
      end
    end
    
    file = params['file']
    
    has_file = file.is_a?(Hash) && cfg(:file_uploads, board)
    
    if has_file
      tmp_thumb_path = nil
      
      file_hash = OpenSSL::Digest::MD5.file(file[:tempfile].path).hexdigest
      
      if is_new_thread
        if dup_file = DB[:posts].first(:file_hash => file_hash, :num => 1)
          failure t(:dup_file_thread)
        end
      else
        dup_file = DB[:posts]
          .select(1)
          .first(:file_hash => file_hash, :thread_id => thread[:id])
        
        failure t(:dup_file_reply) if dup_file
      end
      
      if file_ext = file[:filename].scan(/\.([a-z0-9]+$)/i)[0]
        file_ext = file_ext[0].downcase
      else
        failure t(:bad_file_format)
      end
      
      if !cfg(:file_types).include?(file_ext)
        failure t(:bad_file_format)
      end
      
      tmp_thumb_path =
        "#{settings.tmp_dir}/#{board[:id]}_#{thread_num}_#{file_hash}.jpg"
      
      file_meta =
        if file_ext == 'webm'
          process_file_ffmpeg(file[:tempfile], tmp_thumb_path)
        else
          process_file_imagemagick(file[:tempfile], tmp_thumb_path)
        end
    elsif !comment
      failure t(:comment_empty)
    end
    
    begin
      capcode = nil
      
      if command && !command.empty?
        command.sub!(/^capcode_/, '')
        
        if capcode = t(:user_trips)[command]
          user = get_user_session
          
          unless user && user_has_level?(user, command.to_sym)
            failure t(:cmd_forbidden)
          end
          
          author = nil
          tripcode = capcode
        end
      end
      
      if cfg(:forced_anon, @board_cfg) && !capcode
        author = tripcode = nil
      end
      
      DB.transaction do
        if is_new_thread
          thread = {}
          thread[:board_id] = board[:id]
          thread[:num] = board[:thread_count] + 1
          thread[:created_on] = now
          thread[:updated_on] = now
          thread[:title] = title
          
          thread[:id] = DB[:threads].insert(thread)
          
          thread[:post_count] = 1
          
          DB[:boards]
            .where(:id => board[:id])
            .update(:thread_count => Sequel.+(:thread_count, 1))
          
          board[:thread_count] += 1
        else
          new_vals = {
            :post_count => Sequel.+(:post_count, 1)
          }
          
          if !params['sage']
            new_vals[:updated_on] = now
          end
          
          DB[:threads].where(:id => thread[:id]).update(new_vals)
          
          thread[:post_count] += 1
        end
        
        post = {}
        post[:board_id] = board[:id]
        post[:thread_id] = thread[:id]
        post[:num] = thread[:post_count]
        post[:created_on] = now
        post[:author] = author
        post[:tripcode] = tripcode
        post[:ip] = request.ip
        post[:comment] = comment
        
        meta = {}
        
        if file
          post[:file_hash] = file_hash
          meta[:file] = file_meta
        end
        
        if capcode
          meta[:capcode] = true
        end
        
        post[:meta] = meta.to_json unless meta.empty?
        
        DB[:posts].insert(post)
        
        files_dest_dir = "#{settings.files_dir}/#{board[:id]}/#{thread[:id]}"
        
        if is_new_thread
          FileUtils.mkdir(files_dest_dir)
        end
        
        if has_file
          dest_file = "#{files_dest_dir}/#{file_hash}.#{file_meta[:ext]}"
          
          FileUtils.mv(
            tmp_thumb_path,
            "#{files_dest_dir}/t_#{file_hash}.jpg"
          )
          
          tmp_thumb_path = nil
          
          FileUtils.cp(
            file[:tempfile].path,
            dest_file
          )
          
          File.chmod(0644, dest_file)
        end
      end
    ensure
      FileUtils.rm_f(tmp_thumb_path) if tmp_thumb_path
    end
    
    if is_new_thread && board[:thread_count] > cfg(:thread_limit)
      lt = DB[:threads]
        .where(:board_id => board[:id])
        .reverse_order(:updated_on)
        .limit(1, cfg(:thread_limit) - 1)
        .first
      
      if lt
        overflow = DB[:threads]
          .select(:id, :board_id, :num)
          .where('board_id = ? AND updated_on < ?', board[:id], lt[:updated_on])
          .all
        
        delete_threads(overflow) unless overflow.empty?
      end
    end
    
    @thread = thread
    @board = board
    
    erb :post
  end
  
  post '/manage/posts/delete' do
    validate_csrf_token
    
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :mod)
    
    slug = params['board'].to_s
    thread_num = params['thread'].to_i
    post_num = params['post'].to_i
    
    if slug.empty? || thread_num.zero? || post_num.zero?
      bad_request
    end
    
    board = DB[:boards].first(:slug => slug)
    failure t(:bad_board) unless board
    
    thread = DB[:threads].first(:board_id => board[:id], :num => thread_num)
    failure t(:bad_thread) unless thread
    
    if post_num == 1
      delete_threads([thread])
    else
      post = DB[:posts]
        .select(:id, :num, :file_hash, :meta)
        .first(:thread_id => thread[:id], :num => post_num)
      
      failure t(:bad_post) unless post
      
      delete_posts(thread, [post])
    end
    
    success t(:done), "#{board[:slug]}/read/#{thread[:num]}"
  end
  
  get '/banned' do
    ip_addr = IPAddr.new(request.ip)
    
    if ip_addr.ipv6?
      if ip_addr.ipv4_compat? || ip_addr.ipv4_mapped?
        ip_addr = ip_addr.native
      else
        ip_addr = ip_addr.mask(64)
      end
    end
    
    ip_addr = Sequel::SQL::Blob.new(ip_addr.hton)
    now = Time.now.utc.to_i
    
    @bans = DB[:bans]
      .where(:ip => ip_addr, :active => true)
      .reverse_order(:id)
      .all
    
    if @bans.empty?
      success t(:not_banned)
    else
      now = Time.now.utc.to_i
      
      DB[:bans]
        .where('ip = ? AND active = ? AND expires_on <= ?', ip_addr, true, now)
        .update(:active => false)
      
      erb :banned
    end
  end
  
  get '/manage/bans/create/:slug/:thread_num/:post_num' do
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :mod)
    
    slug = params[:slug].to_s
    thread_num = params[:thread_num].to_i
    post_num = params[:post_num].to_i
    
    @post = get_post_by_path(slug, thread_num, post_num)
    
    failure t(:bad_post) unless @post
    
    erb :manage_bans_edit
  end
  
  get '/manage/bans/update/:id' do
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :mod)
    
    @ban = DB[:bans].first(:id => params[:id].to_i)
    
    failure t(:invalid_ban_id) unless @ban
    
    erb :manage_bans_edit
  end
  
  post %r{/manage/bans/(create|update)/([a-z0-9/]+)$} do |action, target|
    validate_csrf_token
    
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :mod)
    
    now = Time.now.utc.to_i
    
    # Expiration
    duration = params['duration'].to_i
    
    if duration < 0 || duration > MAX_BAN
      expires_on = MAX_BAN
    elsif duration == 0
      expires_on = 0
    else
      expires_on = now + duration * 3600
    end
    
    # Reason
    reason = params['reason'].to_s.strip
    
    failure t(:empty_ban_reason) if reason.empty?
    
    reason = EscapeUtils.escape_html(reason)
    
    # Info
    info = params['info'].to_s.strip
    
    if info.empty?
      info = nil
    else
      info = EscapeUtils.escape_html(info)
    end
    
    # Create / Update
    ban = {
      :created_on => now,
      :expires_on => expires_on,
      :duration => duration,
      :reason => reason,
      :info => info,
    }
    
    if action == 'create'
      slug, thread_num, post_num = target.split('/', 3)
      
      slug = slug.to_s
      thread_num = thread_num.to_i
      post_num = post_num.to_i
      
      post = get_post_by_path(slug, thread_num, post_num)
      failure t(:bad_post) unless post
      
      ip_addr = IPAddr.new(post[:ip])
      
      if ip_addr.ipv6?
        if ip_addr.ipv4_compat? || ip_addr.ipv4_mapped?
          ip_addr = ip_addr.native
        else
          ip_addr = ip_addr.mask(64)
        end
      end
      
      post[:slug] = slug
      
      ban[:ip] = Sequel::SQL::Blob.new(ip_addr.hton)
      ban[:post] = post.to_json
      ban[:created_by] = user[:id]
      
      DB[:bans].insert(ban)
    else
      target = target.to_i
      
      target_ban = DB[:bans].select(:active).first(:id => target)
      
      failure t(:invalid_ban_id) unless target_ban 
      failure t(:cannot_edit_expired_ban) unless target_ban[:active]
      
      ban[:updated_by] = user[:id]
      
      DB[:bans].where(:id => target).update(ban)
    end
    
    success t(:done)
  end
  
  get '/manage/bans' do
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :mod)
    
    dataset = DB[:bans]
      .select_all(:bans)
      .select_append(:username)
      .left_join(:users, :id => :id)
      .reverse_order(:bans__id)
    
    if params['q']
      @ip = params['q'].to_s
      
      begin
        ip_addr = IPAddr.new(@ip)
      rescue
        failure t(:invalid_ip)
      end
      
      if ip_addr.ipv6?
        if ip_addr.ipv4_compat? || ip_addr.ipv4_mapped?
          ip_addr = ip_addr.native
        else
          ip_addr = ip_addr.mask(64)
        end
      end
      
      ip_addr = Sequel::SQL::Blob.new(ip_addr.hton)
      
      dataset = dataset.where(:ip => ip_addr)
    else
      @ip = nil
      dataset = dataset.limit(50)
    end
    
    @bans = dataset.all
    
    erb :manage_bans
  end
  
  get '/manage' do
    if (@user = get_user_session) && user_has_level?(@user, :mod)
      erb :manage
    else
      redirect '/manage/auth'
    end
  end
  
  get '/manage/auth' do
    @csrf = random_base64bytes(8)
    
    response.set_cookie('auth_csrf',
      value: @csrf,
      path: '/manage/auth',
      secure: cfg(:secure_cookies)
    )
    
    erb :manage_login
  end
  
  post '/manage/auth' do
    validate_csrf_token('auth_csrf')
    
    user = authenticate_user(params['username'], params['password'])
    
    old_sid = request.cookies['sid'].to_s
    new_sid = random_base64bytes(64)
    
    if !old_sid.empty?
      DB[:sessions].where(:sid => old_sid).delete
    end
    
    now = Time.now.utc.to_i
    
    DB[:sessions].where('created_on <= ?', now - cfg(:auth_ttl)).delete
    
    DB[:sessions].where('updated_on <= ?', now - cfg(:auth_idle)).delete
    
    DB[:sessions].insert({
      sid: hash_session_id(new_sid),
      user_id: user[:id],
      ip: request.ip,
      created_on: now,
      updated_on: now
    })
    
    set_session_cookies(new_sid)
    
    redirect '/manage'
  end
  
  post '/manage/logout' do
    validate_csrf_token
    
    sid = request.cookies['sid'].to_s
    
    redirect '/' if sid.empty?
    
    DB[:sessions].where(:sid => sid).delete
    
    clear_session_cookies
    
    redirect '/'
  end
  
  get '/manage/boards' do
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :admin)
    
    @boards = DB[:boards].all
    
    erb :manage_boards
  end
  
  get %r{/manage/boards/(create|update)(?:/([0-9]+))?} do |action, board_id|
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :admin)
    
    if action == 'update'
      @board = DB[:boards].first(:id => board_id.to_i)
      failure t(:bad_board) unless @board
    end
    
    erb :manage_boards_edit
  end
  
  post %r{/manage/boards/(create|update)(?:/([0-9]+))?} do |action, board_id|
    validate_csrf_token
    
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :admin)
    
    slug = params['slug'].to_s
    title = params['title'].to_s
    config = params['config'].to_s
    
    failure t(:bad_slug) unless /^[a-z0-9]+$/ =~ slug
    failure t(:bad_title) if title.empty?
    
    if config.empty?
      config = nil
    else
      begin
        config = JSON.parse(config).to_json
      rescue JSON::JSONError => e
        failure t(:bad_config_json)
      end
    end
    
    board = {
      slug: slug,
      title: EscapeUtils.escape_html(title),
      config: config
    }
    
    if action == 'update'
      affected = DB[:boards].where(:id => board_id.to_i).update(board)
      failure t(:bad_board) unless affected > 0
    else
      board[:created_on] = Time.now.utc.to_i
      
      DB.transaction do
        board_id = DB[:boards].insert(board)
        
        unless File.directory?(settings.files_dir)
          FileUtils.mkdir settings.files_dir
        end
        
        FileUtils.mkdir "#{settings.files_dir}/#{board_id}"
      end
    end
    
    success t(:done), '/manage/boards'
  end
  
  post '/manage/boards/delete/:id' do
    validate_csrf_token
    
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :admin)
    
    conf = params['confirm_keyword'].to_s
    
    if conf.empty? || conf != t(:confirm_keyword)
      failure t(:bad_confirm_keyword)
    end
    
    board_id = params[:id].to_i
    
    board = DB[:boards].first(:id => board_id)
    
    failure t(:bad_board) unless board
    
    DB.transaction(:rollback => :reraise) do
      DB[:boards].where(:id => board[:id]).delete
      DB[:threads].where(:board_id => board[:id]).delete
      DB[:posts].where(:board_id => board[:id]).delete
    end
    
    begin
      path = "#{settings.files_dir}/#{board[:id]}"
      FileUtils.rm_r(path)
    rescue => e
      logger.error "Failed to delete '#{path}' (#{e.message})"
    end
    
    success t(:done), '/manage/boards'
  end
  
  get '/manage/users' do
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :admin)
    
    @users = DB[:users].all
    
    erb :manage_users
  end
  
  get %r{/manage/users/(create|update)(?:/([0-9]+))?} do |action, user_id|
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :admin)
    
    if action == 'update'
      @user = DB[:users].first(:id => user_id.to_i)
      failure t(:bad_user_id) unless @user
    end
    
    erb :manage_users_edit
  end
  
  post %r{/manage/users/(create|update)(?:/([0-9]+))?} do |action, user_id|
    validate_csrf_token
    
    forbidden unless user = get_user_session
    forbidden unless user_has_level?(user, :admin)
    
    username = params['username'].to_s
    level = params['level'].to_i
    
    failure t(:bad_user_name) unless /^[_a-z0-9]+$/ =~ username
    failure t(:bad_user_level) unless USER_GROUPS[level]
    
    new_user = {
      username: username,
      level: level
    }
    
    if action == 'create' || params['reset_password']
      new_plain_pwd = random_base64bytes(16)
      
      new_user[:password] = hash_password(new_plain_pwd)
    end
    
    if action == 'update'
      user_id = user_id.to_i
      
      affected = DB[:boards].where(:id => user_id).update(new_user)
      
      failure t(:bad_user_id) unless affected > 0
    else
      new_user[:created_on] = Time.now.utc.to_i
      
      DB[:users].insert(new_user)
    end
    
    if new_user[:password]
      success t(:new_passwd) % new_plain_pwd
    else
      success t(:done), '/manage/boards'
    end
  end
  
  get '/manage/profile' do
    forbidden unless @user = get_user_session
    
    erb :manage_profile
  end
  
  post '/manage/profile' do
    validate_csrf_token
    
    forbidden unless user = get_user_session
    
    old_pwd = params['old_pwd'].to_s
    new_pwd = params['new_pwd'].to_s
    new_pwd_again = params['new_pwd_again'].to_s
    
    if old_pwd.empty?
      forbidden
    end
    
    if new_pwd.length < 8
      failure t(:passwd_too_short)
    end
    
    if new_pwd != new_pwd_again
      failure t(:passwd_mismatch)
    end
    
    now = Time.now.utc.to_i
    
    if !password_valid?(old_pwd, user[:password])
      DB[:auth_fails].insert(:ip => request.ip, :created_on => now)
      forbidden
    end
    
    new_hashed_pwd = hash_password(new_pwd)
    
    DB[:users].where(:id => user[:id]).update(:password => new_hashed_pwd)
    
    success t(:done), '/manage/profile'
  end
  
  not_found do
    erb :not_found
  end

  error do
    LOGGER.error(env['sinatra.error'].message)
    failure 'Internal Server Error', 500
  end
  
  run! if app_file == $0
end

end
