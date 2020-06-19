# =============================================================================
# exec.rb -- CHIFIG methods to run other programs
#
# Copyright (c) 2019-2020 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

require 'open3'

module CHIFIG

# Run cmd and wait for it to produce output.  If input != nil, write it to cmd.
# If outsize > 0, wait for at least outsize bytes; otherwise, wait for cmd to
# finish and return all output.  Output is stdout+stderr.  Raise RuntimeError
# on error.
def self.exec_read(cmd, input=nil, outsize=0)
   output = ''
   begin
      pin, pout, thwait = Open3.popen2e(cmd)
      pin.write(input) if input
      readsize = (outsize > 0) ? outsize : 1024
      while true
         begin
            output << pout.readpartial(readsize) 
            break if outsize > 0 && output.length > outsize
         rescue EOFError 
            break
         end
      end
   rescue SystemCallError => e
      raise RuntimeError, "Error running \"#{cmd}\": #{e.message}"
   ensure
      pin.close
      pout.close
   end
   output
end

# Run cmd and wait for it to finish.  If input != nil, write it to cmd.
# Return true/false to indicated success/failure.  Raise RuntimeError on error.
def self.exec_wait(cmd, input=nil)
   success = false
   begin
      pin, pout, thwait = Open3.popen2e(cmd)
      pin.write(input) if input
      status = thwait.value
      success = status.success?
   rescue SystemCallError => e
      raise RuntimeError, "Error running \"#{cmd}\": #{e.message}"
   ensure
      pin.close
      pout.close
   end
   success
end

# Fork a new process and exec cmd.  Return read pipe and pid of the child.
# Raise RuntimeError on error.
def self.exec_fork(cmd)
   begin
      rd,wr = IO.pipe
      pid = Process.fork do
         # Child
         rd.close
         $stdout.reopen(wr)
         $stderr.reopen(wr)
         exec(cmd)
      end
   rescue SystemCallError => e
      raise RuntimeError, "Error running \"#{cmd}\": #{e.message}"
   ensure
      # Resume parent
      wr.close
   end
   return rd, pid
end

# Run cmd with the intention to drive it interactively.  Return input pipe, 
# output pipe, wait thread.  Raise RuntimeError on error.
def self.exec_drive(cmd)
   begin
      pin, pout, thwait = Open3.popen2e(cmd)
   rescue SystemCallError => e
      raise RuntimeError, "Error running \"#{cmd}\": #{e.message}"
   end
   return pin, pout, thwait
end

end  # CHIFIG
