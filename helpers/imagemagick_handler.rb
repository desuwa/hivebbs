module Hive

class BBS < Sinatra::Base
  
  def process_file_imagemagick(file, dest)
    limits = cfg(:file_limits)[:image]
    
    if file.size > limits[:file_size]
      failure t(:file_size_too_big)
    end
    
    cmd = "identify -quiet -ping -format \"%m %w %h\" \"#{file.path}[0]\""
    
    status, output = run_cmd(cmd, 10)
    
    if status != 0
      if output.strip.include?('no decode delegate')
        failure t(:bad_file_format)
      else
        logger.error "identify failed: #{output.strip}"
        failure t(:server_error)
      end
    end
    
    image_info = output.strip.split(' ')
    image_format = image_info[0].downcase
    image_width = image_info[1].to_i
    image_height = image_info[2].to_i
    
    if image_width > limits[:dimensions] || image_height > limits[:dimensions]
      failure t(:dimensions_too_large)
    end
    
    if image_format == 'jpeg'
      image_format = 'jpg'
    end
    
    if !cfg(:file_types).include?(image_format)
      failure t(:bad_file_format)
    end
    
    thumb_dims = cfg(:thumb_dimensions)
    
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
    
    cmd = "convert \"#{file.path}[0]\" -format jpg " <<
      "-resize #{th_width}x#{th_height}! -background \"#FFFAFA\" " <<
      "-alpha remove -strip -quality #{cfg(:thumb_quality).to_i} \"#{dest}\""
    
    status, output = run_cmd(cmd, 10)
    
    if status != 0
      logger.error "convert failed: #{output.strip}"
      FileUtils.rm_f(dest) if File.exist?(dest)
      failure t(:server_error)
    end
    
    return {
      ext: image_format,
      w: image_width,
      h: image_height,
      th_w: th_width,
      th_h: th_height,
      size: file.size
    }
  end
  
end

end
