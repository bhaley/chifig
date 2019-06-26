# =============================================================================
#
# Installation configuration
#
# =============================================================================

require 'rbconfig'

module CHIFIG

module INSTALL

CONFIG = {}

# -----------------------------------------------------------------------------
# Edit the options below for installation on your system
# -----------------------------------------------------------------------------

# Directory where programs are installed
CONFIG['BINDIR'] = RbConfig::CONFIG['bindir']

# Directory where code libraries are installed
CONFIG['LIBDIR'] = RbConfig::CONFIG['sitelibdir']

# Directory where data files are installed
CONFIG['DATADIR'] = File.join(RbConfig::CONFIG['datadir'], 'chifig')

# latex binary
CONFIG['LATEX_PATH'] = '/usr/bin/latex'

# dvips binary
CONFIG['DVIPS_PATH'] = '/usr/bin/dvips'

# Editor (used only for chide)
CONFIG['EDITOR_PATH'] = '/usr/bin/gvim -f'
#CONFIG['EDITOR_PATH'] = '/usr/bin/gvim -f -U ~/.gvimrc_chifig'

# Ghostscript binary (used only for chide)
CONFIG['GS_PATH'] = '/usr/bin/gs'

# -----------------------------------------------------------------------------
# Do not edit below
# -----------------------------------------------------------------------------

# Echo the installation commands, but do not execute them
ECHO_ONLY = false

# Execute shell cmd 
def self.do_cmd(cmd)
   if ECHO_ONLY
      puts cmd
   else
      Rake.sh cmd
   end
end

# Create dir if it doesn't exist
def self.verify_dir(dir)
   do_cmd("#{RbConfig::CONFIG['MKDIR_P']} #{dir}") unless File.directory?(dir)
end

# Recursively install all files in srcdir to destdir, using install_cmd, 
# creating subdirectories as needed
def self.install_files(srcdir, destdir, install_cmd)
   verify_dir(destdir)
   Dir.chdir(srcdir) do 
      Dir.entries('.').each do |file|
         next if file[0] == '.'
         if File.directory?(file)
            dest = File.join(destdir, file)
            install_files(file, dest, install_cmd)
         else
            do_cmd("#{install_cmd} #{file} #{destdir}")
         end
      end
   end
end

end  # INSTALL

end  # CHIFIG
