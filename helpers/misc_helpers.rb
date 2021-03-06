module Hive

class BBS < Sinatra::Base
  
  def t(id)
    STRINGS[id]
  end
  
  def cfg(id, board_cfg = nil)
    if board_cfg && board_cfg[id]
      board_cfg[id]
    else
      CONFIG[id]
    end
  end
  
  def logger
    LOGGER
  end
  
  def failure(msg, code = nil)
    status code if code
    @msg, @code = msg, code
    halt erb :error
  end
  
  def success(msg, redirect = nil)
    @msg, @redirect = msg, redirect
    halt erb :success
  end
  
  def forbidden
    failure t(:denied), 403
  end
  
  def bad_request
    failure t(:bad_request), 400
  end
  
  def asset(src)
    if a = ASSETS[src]
      return a
    end
    
    min_src = src.sub(/\.([a-z]+)$/, '.min.\1'.freeze)
    min_path = "#{settings.public_dir}#{min_src}".freeze
    
    if settings.production? && File.exist?(min_path)
      path = min_path
      src = min_src
    else
      path = "#{settings.public_dir}#{src}".freeze
    end
    
    v = OpenSSL::Digest::MD5.file(path).hexdigest
    
    ASSETS[src] = "#{src}?#{v[0, 8]}".freeze # query strings, for now...
  end
  
  def paginate_html(page, total, count = 5)
    return if total < 2
    
    buffer = count / 2
    
    stop = page + buffer
    stop = count if stop < count
    stop = total if stop > total
    
    start = stop - count + 1
    start = 1 if start < 1
    
    if block_given?
      yield :first if start > 1
      yield :previous if page > 1
      (start..stop).each { |i| yield i }
      yield :next if total > page
    else
      start..stop
    end
  end
  
  def decode_tegaki_upload(data)
    ext = data.scan(/^data:image\/([a-z0-9]+);base64,/).flatten.join
    
    start = data.index(','.freeze)
    
    failure t(:bad_file_format) if !start
    
    data = Base64.decode64(data[start, (data.size - start)])
    
    tmp = Tempfile.new('hive'.freeze)
    tmp.binmode
    tmp.write data
    tmp.close
    
    {
      tempfile: tmp,
      filename: "raw.#{ext}".freeze
    }
  end
  
  def run_cmd(cmd, timeout = nil)
    rpipe, wpipe = IO.pipe
    
    pid = Process.spawn(
      { 'LANG' => 'C' },
      cmd,
      { STDERR => wpipe , STDOUT => wpipe }
    )
    
    wpipe.close
    
    status = nil
    output = ''
    
    begin
      if timeout
        Timeout.timeout(timeout) do
          Process.waitpid(pid, Process::WUNTRACED)
        end
      else
        Process.waitpid(pid, Process::WUNTRACED)
      end
      
      status = $?.exitstatus
      output = rpipe.readlines.join('')
    rescue Errno::ECHILD
    rescue Timeout::Error
      Process.kill(9, pid) rescue Errno::ESRCH
      Process.waitpid(pid, Process::WUNTRACED) rescue Errno::ECHILD
      logger.warn "run_cmd timed out: #{cmd}"
    end
    
    rpipe.close
    
    [status, output]
  end
  
  def get_board_config(board)
    if board[:config]
      JSON.parse(board[:config], symbolize_names: true)
    else
      nil
    end
  end
  
  def pretty_bytesize(size)
    if size < 1024
      return "#{size} B"
    end
    
    size = size.to_f
    
    if size < 1048576
      size /= 1024
      return "#{size.round} KiB"
    end
    
    size /= 1048576
    return "#{size.round(2)} MiB"
  end
  
  def make_tripcode(data)
    digest = OpenSSL::Digest.new('sha1')
    [OpenSSL::HMAC.digest(digest, TRIP_KEY, data)[0, 9]].pack('m0')
  end
  
  
  def random_base64bytes(length)
    [OpenSSL::Random.random_bytes(length)].pack("m0").tr('+/', '-_').delete('=')
  end
  
end

end
