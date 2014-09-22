module Hive

class BBS < Sinatra::Base
  
  MAX_BAN = 2147483647
  
  USER_LEVELS = {
    :admin => 99,
    :mod => 50,
  }
  
  USER_GROUPS = USER_LEVELS.invert
  
  def resolve_name(ip)
    Resolv.getname(ip)
  rescue Resolv::ResolvError, Resolv::ResolvTimeout
    nil
  end
  
  def csrf_tag(value, name = 'csrf')
    "<input type=\"hidden\" name=\"#{name}\" value=\"#{value}\">"
  end
  
  def validate_csrf_token(name = 'csrf')
    csrf_cookie = request.cookies[name].to_s
    csrf_param = params[name].to_s
    
    if !csrf_cookie.empty? && !csrf_param.empty? && csrf_cookie == csrf_param
      return
    end
    
    bad_request 
  end
  
  def validate_referrer
    ref = request.referrer.to_s
    return if ref.empty? || URI.parse(ref).host == request.host
    bad_request
  rescue URI::InvalidURIError
  end
  
  def hash_password(plain_pwd)
    BCrypt::Password.create(plain_pwd)
  end
  
  def password_valid?(plain_pwd, hashed_pwd)
    BCrypt::Password.new(hashed_pwd) == plain_pwd
  end
  
  def hash_session_id(sid)
    OpenSSL::Digest::SHA256.hexdigest(sid)
  end
  
  def set_session_cookies(sid)
    expires = Time.now + cfg(:auth_ttl)
    
    response.set_cookie('sid',
      value: sid,
      path: '/manage',
      httponly: true,
      secure: cfg(:secure_cookies),
      expires: expires
    )
    
    response.set_cookie('sid',
      value: sid,
      path: '/post',
      httponly: true,
      secure: cfg(:secure_cookies),
      expires: expires
    )
    
    response.set_cookie('csrf',
      value: random_base64bytes(16),
      path: '/',
      secure: cfg(:secure_cookies),
      expires: expires
    )
  end
  
  def clear_session_cookies
    response.delete_cookie('sid',
      path: '/manage',
      httponly: true,
      secure: cfg(:secure_cookies)
    )
    
    response.delete_cookie('sid',
      path: '/post',
      httponly: true,
      secure: cfg(:secure_cookies)
    )
    response.delete_cookie('csrf',
      path: '/',
      secure: cfg(:secure_cookies)
    )
  end
  
  def get_user_session
    sid = request.cookies['sid'].to_s
    
    return nil if sid.empty?
    
    sid = hash_session_id(sid)
    
    session = DB[:sessions].first(:sid => sid)
    
    unless session
      clear_session_cookies
      return nil
    end
    
    now = Time.now.utc.to_i
    
    if session[:created_on] <= now - cfg(:auth_ttl) ||
        session[:updated_on] <= now - cfg(:auth_idle)
      clear_session_cookies
      DB[:sessions].where(:sid => sid).delete
      return nil
    end
    
    user = DB[:users].first(:id => session[:user_id])
    
    unless user
      clear_session_cookies
      return nil
    end
    
    DB[:sessions].where(:id => session[:id]).update(:updated_on => now)
    
    user
  end
  
  def authenticate_user(username, password)
    if username.empty? || password.empty?
      forbidden
    end
    
    now = Time.now.utc.to_i
    
    DB[:auth_fails].where('created_on < ?', now - cfg(:delay_auth)).delete
    
    if DB[:auth_fails].first(:ip => request.ip)
      failure t(:fast_auth), 403
    end
    
    user = DB[:users].first(:username => username)
    
    if user && password_valid?(password, user[:password])
      return user
    end
    
    DB[:auth_fails].insert(:ip => request.ip, :created_on => now)
    
    forbidden
  end
  
  def get_post_by_path(slug, thread_num, post_num)
    board = DB[:boards].select(:id).first(:slug => slug)
    return nil unless board
    
    thread = DB[:threads]
      .select(:id)
      .first(:board_id => board[:id], :num => thread_num)
    return nil unless thread
    
    DB[:posts].first(:thread_id => thread[:id], :num => post_num)
  end
  
  def delete_threads(threads)
    ids = []
    paths = []
    
    root = settings.files_dir
    
    threads.each do |thread|
      ids << thread[:id]
      paths << "#{root}/#{thread[:board_id]}/#{thread[:id]}"
    end
    
    DB[:threads].where(:id => ids).delete
    
    FileUtils.rm_rf(paths)
  end
  
  def delete_posts(thread, posts)
    ids = []
    paths = []
    
    root = "#{settings.files_dir}/#{thread[:board_id]}/#{thread[:id]}"
    
    posts.each do |post|
      if post[:num] == 1
        next
      end
      
      ids << post[:id]
      
      if post[:file_hash]
        meta = JSON.parse(post[:meta])['file_meta']
        paths << "#{root}/#{post[:file_hash]}.#{meta['ext']}"
        paths << "#{root}/t_#{post[:file_hash]}.jpg"
      end
    end
    
    DB[:posts].where(:id => ids).delete
    
    FileUtils.rm_f(paths)
  end
  
  def user_has_level?(user, level)
    USER_LEVELS[level] <= user[:level]
  end
  
end

end
