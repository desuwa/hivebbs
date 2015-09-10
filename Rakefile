require 'rake/testtask'

Encoding.default_external = 'UTF-8'

include Rake

task :test => 'test:all'

namespace :test do
  TestTask.new(:all) do |t|
    t.description = 'Run all tests'
    t.test_files = FileList['spec/*_spec.rb']
  end
  
  TestTask.new(:nomedia) do |t|
    t.description = 'Skip all upload handlers tests'
    t.test_files = Dir['spec/*_spec.rb'].reject { |f| /imagemagic|ffmpeg/ =~f }
  end
  
  TestTask.new(:noffmpeg) do |t|
    t.description = 'Skip FFmpeg handler tests'
    t.test_files = Dir['spec/*_spec.rb'].reject { |f| f.include?('ffmpeg') }
  end
  
  TestTask.new(:nomagick) do |t|
    t.description = 'Skip ImageMagick handler tests'
    t.test_files = Dir['spec/*_spec.rb'].reject { |f| f.include?('magick') }
  end 
end

task :build => 'build:all'

namespace :build do
  desc 'Minify and precompress everything'
  task :all do
    Rake::Task['build:js'].invoke
    Rake::Task['build:css'].invoke
  end
  
  desc 'Minify and precompress JavaScript'
  task :js do
    require 'zlib'
    require 'uglifier'
    
    root = 'public/javascripts'
    ['hive', 'tegaki', 'manage'].each do |basename|
      next unless File.exist?("#{root}/#{basename}.js")
      
      u = Uglifier.new(
        screw_ie8: true,
        source_filename: "#{basename}.js",
        output_filename: "#{basename}.min.js"
      )
      
      js, sm = u.compile_with_map(File.read("#{root}/#{basename}.js"))
      
      js << "\n//# sourceMappingURL=#{basename}.min.js.map"
      
      Zlib::GzipWriter.open("#{root}/#{basename}.min.js.gz") do |gz|
        gz.write(js)
      end
      
      File.open("#{root}/#{basename}.min.js", 'w') { |f| f.write js }
      File.open("#{root}/#{basename}.min.js.map", 'w') { |f| f.write sm }
    end
  end
  
  desc 'Minify and precompress CSS'
  task :css do
    require 'zlib'
    require 'sass'
    
    root = 'public/stylesheets'
    
    ['hive', 'tegaki'].each do |basename|
      next unless File.exist?("#{root}/#{basename}.css")
      
      sass = Sass::Engine.new(
        File.read("#{root}/#{basename}.css"),
        style: :compressed, cache: false, syntax: :scss
      )
      
      css = sass.render
      
      Zlib::GzipWriter.open("#{root}/#{basename}.min.css.gz") do |gz|
        gz.write(css)
      end
      
      File.open("#{root}/#{basename}.min.css", 'w') { |f| f.write css }
    end
  end
end

desc 'Run JShint'
task :jshint do |t|
  require 'jshintrb'
  
  opts = {
    laxbreak: true,
    boss: true,
    expr: true,
    sub: true
  }
  
  root = 'public/javascripts'
  
  ['hive', 'tegaki', 'manage'].each do |basename|
    f = "#{root}/#{basename}.js"
    
    next unless File.exist?(f)
    
    puts "--> #{root}/#{basename}.js"
    puts Jshintrb.report(File.read(f), opts)
  end
end

namespace :db do
  cfg = 'config/db.rb'
  
  desc 'Create admin account using the provided username'
  task :init, [:username] do |t, args|
    require 'bcrypt'
    require 'sequel'
    
    username = args.username || 'admin'
    
    Sequel.connect(eval(File.open(cfg, 'r') { |f| f.read }))[:users].insert({
      username: username,
      password: BCrypt::Password.create('admin'),
      level: 99,
      created_on: Time.now.utc.to_i,
    })
    
    puts "Added admin account (username: #{username} / password: admin)"
  end
  
  desc 'Run migrations'
  task :migrate, [:cfg] do |t, args|
    require 'sequel'
    
    cfg = "config/#{args.cfg}.rb" if args.cfg
    
    DB = Sequel.connect(eval(File.open(cfg, 'r') { |f| f.read }))
    
    Sequel.extension :migration
    Sequel::Migrator.run(DB, 'migrations')
    
    puts 'Done migrating'
  end
end

namespace :puma do
  cfg = 'puma-hive.rb'
  
  desc 'Create Puma config file'
  task :init do |t|
    if File.exist?(cfg)
      puts 'Puma configuration file already exists. Aborting'
      next
    end
    
    File.open(cfg, 'w') do |f|
      f.write <<-'PUMA'.gsub(/^[ \t]+/, '')
        #!/usr/bin/env puma
        
        cwd = File.expand_path(File.dirname(__FILE__))
        
        environment 'production'
        rackup "#{cwd}/config.ru"
        bind "unix://#{cwd}/tmp/puma.sock"
        pidfile "#{cwd}/tmp/puma.pid"
        stdout_redirect "#{cwd}/log/stdout.log", "#{cwd}/log/stderr.log"
        quiet
        threads 0, 8
        workers 2
        daemonize
      PUMA
    end
    
    puts "Done generating #{cfg}"
  end
  
  desc 'Start Puma'
  task :start do |t|
    system('puma -C puma-hive.rb')
  end
  
  desc 'Reload Puma (phased restart)'
  task :reload do |t|
    system('pumactl -F puma-hive.rb phased-restart')
  end
  
  desc 'Restart Puma'
  task :restart do |t|
    system('pumactl -F puma-hive.rb restart')
  end
  
  desc 'Stop Puma'
  task :stop do |t|
    system('pumactl -F puma-hive.rb halt')
  end
end

desc 'Generate the tripcode pepper file'
task :gentripkey, [:size] do |t, args|
  key_file = 'config/trip.key'
  
  if File.exist?(key_file)
    puts 'config/trip.key already exists. Aborting'
    next
  end
  
  size = args.size.to_i
  size = 256 if size.zero?
  
  system("openssl rand -out #{key_file} #{size}")
end
