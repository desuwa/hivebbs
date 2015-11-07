{
  locale: 'en',
  
  app_name: 'hiveBBS',
  
  anon: 'Anonymous',
  forced_anon: false,
  
  auth_idle: 5 * 86400,
  auth_ttl: 30 * 86400,
  secure_cookies: settings.production?,
  
  thread_limit: 500,
  post_limit: 500,
  threads_per_page: 50,
  
  author_length: 50,
  title_length: 100,
  comment_length: 5000,
  comment_lines: 100,
  
  delay_auth: 30,
  delay_thread: 60,
  delay_reply: 15,
  
  thumb_dimensions: 100,
  thumb_quality: 80,
  
  captcha: false,
  captcha_public_key: nil,
  captcha_private_key: nil,
  
  file_uploads: false,
  
  tegaki: false,
  tegaki_width: 380,
  tegaki_height: 380,
  tegaki_data_limit: 1 * 1048576,
  
  file_types: [ 'jpg', 'png', 'gif', 'webm' ],
  
  file_limits: {
    image: {
      file_size: 5 * 1048576,
      dimensions: 5120,
    },
    
    video: {
      file_size: 5 * 1048576,
      dimensions: 2048,
      duration: 5 * 3600,
      allow_audio: false
    }
  },
  
  post_reporting: false,
  reporting_captcha: false,
  delay_report: 15,
  
  report_categories: {
    #'rule' => 1,
    #'illegal' => 100
  }
}
