module Hive

class BBS < Sinatra::Base
  
  MAX_BAN = 2147483647
  
  USER_LEVELS = {
    :admin => 99,
    :mod => 50,
  }
  
  USER_GROUPS = USER_LEVELS.invert
  
  THREAD_LOCKED = 1
  
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
  
  def validate_honeypot
    halt if params['email'] && !params['email'].empty?
  end
  
  def verify_captcha
    resp_token = params['g-recaptcha-response'.freeze]
    
    failure t(:captcha_empty_error) if !resp_token || resp_token.empty?
    
    data = {
      'secret'.freeze => cfg(:captcha_private_key),
      'response'.freeze => resp_token
    }
    
    resp = nil
    
    Timeout::timeout(3) do
      http = Net::HTTP.new('www.google.com'.freeze, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      resp = http.get("/recaptcha/api/siteverify?#{URI.encode_www_form(data)}")
    end
    
    captcha = JSON.parse(resp.body)
    
    if captcha['success'.freeze] != true
      failure t(:captcha_invalid_error)
    end
  rescue
    failure t(:captcha_generic_error)
  end
  
  def ban_duration_ts(created_on, duration)
    if duration < 0
      expires_on = MAX_BAN
    elsif duration == 0
      expires_on = 0
    else
      expires_on = created_on + duration * 3600
      expires_on = MAX_BAN if expires_on > MAX_BAN
    end
    expires_on
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
    DB[:posts].where(:thread_id => ids).delete
    
    dismiss_reports(:thread_id => ids) if cfg(:post_reporting)
    
    FileUtils.rm_rf(paths)
  end
  
  def delete_replies(posts, file_only = false)
    ids = []
    paths = []
    
    files_dir = settings.files_dir
    
    posts.each do |post|
      next if !file_only && post[:num] == 1
      
      ids << post[:id]
      
      if post[:file_hash]
        meta = JSON.parse(post[:meta])['file']
        root = "#{files_dir}/#{post[:board_id]}/#{post[:thread_id]}"
        paths << "#{root}/#{post[:file_hash]}.#{meta['ext']}"
        paths << "#{root}/t_#{post[:file_hash]}.jpg"
      end
    end
    
    if file_only
      DB[:posts].where(:id => ids).update(:file_hash => nil)
    else
      DB[:posts].where(:id => ids).delete
    end
    
    dismiss_reports(:post_id => ids) if cfg(:post_reporting)
    
    FileUtils.rm_f(paths)
  end
  
  def user_has_level?(user, level)
    USER_LEVELS[level] <= user[:level]
  end
  
  def dismiss_reports(by)
    DB[:reports].where(by).delete
  end
end

end
