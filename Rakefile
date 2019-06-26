
require_relative 'install_config'

task :default do
   puts "Typical usage:"
   puts "   rake show_config"
   puts "   Edit install_config.rb"
   puts "   (sudo) rake install"
end

desc 'Run JSON -> ps tests'
task :test_json do
   sh 'ruby test/json.rb'
end

desc 'Run DSL -> ps tests'
task :test_dsl do
   sh 'ruby test/dsl.rb'
end

desc 'Run all tests'
task :test => [:test_json, :test_dsl]

desc 'Show current installation configuration'
task :show_config do
   puts "\nInstall programs to #{CHIFIG::INSTALL::CONFIG['BINDIR']}"
   puts "Install library code to #{CHIFIG::INSTALL::CONFIG['LIBDIR']}"
   puts "Install data files to #{CHIFIG::INSTALL::CONFIG['DATADIR']}"
   puts "LaTeX: #{CHIFIG::INSTALL::CONFIG['LATEX_PATH']}"
   puts "Dvips: #{CHIFIG::INSTALL::CONFIG['DVIPS_PATH']}"
   puts "Editor: #{CHIFIG::INSTALL::CONFIG['EDITOR_PATH']}"
   puts "Ghostscript: #{CHIFIG::INSTALL::CONFIG['GS_PATH']}"
   puts "\nEdit install_config.rb to change these options"
end

desc 'Install library (may require sudo)'
task :install_lib do
   libdir = CHIFIG::INSTALL::CONFIG['LIBDIR']
   install_cmd = RbConfig::CONFIG['INSTALL_SCRIPT']
   CHIFIG::INSTALL.install_files('lib', libdir, install_cmd)
   s = File.read(File.join('lib', 'chifig', 'config.rb'))
   CHIFIG::INSTALL::CONFIG.each {|k,v| s.sub!("@#{k}@", v)}
   script = File.join(libdir, 'chifig', 'config.rb')
   File.open(script, 'w') {|f| f.write(s)} if !CHIFIG::INSTALL::ECHO_ONLY
   puts "Configured #{script}"
end

desc 'Install data files (may require sudo)'
task :install_data do
   datadir = CHIFIG::INSTALL::CONFIG['DATADIR']
   install_cmd = RbConfig::CONFIG['INSTALL_DATA']
   CHIFIG::INSTALL.install_files('data', datadir, install_cmd)
   file = File.join('doc', 'examples', 'logo.ps')
   CHIFIG::INSTALL.do_cmd("#{install_cmd} #{file} #{datadir}")
end

desc 'Install programs (may require sudo)'
task :install_bin do
   bindir = CHIFIG::INSTALL::CONFIG['BINDIR']
   install_cmd = RbConfig::CONFIG['INSTALL_PROGRAM']
   CHIFIG::INSTALL.install_files('bin', bindir, install_cmd)
end

desc 'Install bin, data, lib (may require sudo)'
task :install => [:install_lib, :install_data, :install_bin]

