module Hive

class BBS < Sinatra::Base
  
  def process_file_ffmpeg(file, dest)
    limits = cfg(:file_limits)[:video]
    
    if file.size > limits[:file_size]
      failure t(:file_size_too_big)
    end
    
    cmd = "ffprobe -i \"#{file.path}\" -v quiet -show_streams -show_format -of json"
    
    status, output = run_cmd(cmd, 10)
    
    if status != 0
      if /^{\s+}$/ =~ output.strip
        failure t(:bad_file_format)
      else
        logger.error "FFprobe failed: #{output.strip}"
        failure t(:server_error)
      end
    end
    
    info = JSON.parse(output)
    
    if info['format']['format_name'] != 'matroska,webm'
      failure t(:bad_file_format)
    end
    
    duration = info['format']['duration'].to_f
    
    if duration > limits[:duration]
      failure t(:duration_too_long)
    end
    
    sar = width = height = nil
    has_audio = false
    has_video = false
    
    info['streams'].each do |stream|
      type = stream['codec_type']
      
      if type == 'audio'
        failure t(:webm_audio_disabled) if !limits[:allow_audio]
        failure t(:too_many_audio) if has_audio
        failure t(:invalid_audio) if stream['codec_name'] != 'vorbis'
        has_audio = true
      elsif type == 'video'
        failure t(:too_many_video) if has_video
        failure t(:invalid_video) if stream['codec_name'] != 'vp8'
        
        has_video = true
        
        width = stream['width'].to_i
        height = stream['height'].to_i
        
        if width > limits[:dimensions] || height > limits[:dimensions]
          failure t(:dimensions_too_large)
        end
        
        if tmp_sar = stream['sample_aspect_ratio']
          tmp_sar = tmp_sar.split(':').map { |x| x.to_i }
          
          if tmp_sar[1] && tmp_sar[0] != tmp_sar[1]
            tmp_sar = tmp_sar[0].to_f / tmp_sar[1]
            
            if tmp_sar < 2 && tmp_sar > 0.5
              sar = tmp_sar
            end
          end
        end
      else
        failure t(:invalid_stream)
      end
    end
    
    if !has_video
      failure t(:no_video_streams)
    end
    
    thumb_dims = cfg(:thumb_dimensions)
    
    if sar
      if sar > 1.0
        image_width = width
        image_height = (height / sar).ceil
      else
        image_width = (width * sar).ceil
        image_height = height
      end
    else
      image_width = width
      image_height = height
    end
    
    th_width = image_width
    th_height = image_height
    
    if image_width > thumb_dims || image_height > thumb_dims
      ratio = image_width.to_f / image_height
      
      if ratio > 1
        th_width = thumb_dims
        th_height = (thumb_dims / ratio).ceil
      else
        th_height = thumb_dims
        th_width = (thumb_dims * ratio).ceil
      end
    end
    
    q = 1 + ((100 - cfg(:thumb_quality)) * 0.15).floor
    
    cmd = "ffmpeg -i \"#{file.path}\" -vframes 1 "  <<
      "-s #{th_width}x#{th_height} -qscale #{q} -an -y \"#{dest}\" 2>&1"
    
    status, output = run_cmd(cmd, 10)
    
    if status != 0
      logger.error "FFmpeg failed: #{output.strip}"
      failure t(:server_error)
    end
    
    meta = {
      ext: 'webm',
      w: width,
      h: height,
      th_w: th_width,
      th_h: th_height,
      size: file.size
    }
    
    if has_audio
      meta[:has_audio] = true
    end
    
    meta
  end
  
end

end
