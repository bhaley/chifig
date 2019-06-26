# =============================================================================
# test.rb -- Test methods
#
# Copyright (c) 2019 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

# Return Array of Postscript Strings with date and other non-essential lines
# removed and all whitespace removed; the whitespace in the Postscript can
# change between package versions (why?)
def ps_to_a(ps)
   tags = ['CreationDate', 'Creator', 'DVIPSSource', 'dvi']
   ps.gsub(/\s+/, '').split("\n").delete_if do |line|
      tags.find {|tag| line.include?(tag)}
   end
end
      
# Run all tests; compare the Postscript generated by calling ps_lambda to the
# canonical test Postscript
def run_tests(test_dir, tests, ps_lambda)
   psfile = 'test.ps'
   $stdout.write("\n")
   Dir.chdir(test_dir) do
      tests.each do |t|
         base = File.basename(t, '.*')
         begin
            ps_lambda.call(t, psfile)
            $stdout.printf("%12.12s: ", base)
            if ps_to_a(File.read(psfile)) == ps_to_a(File.read("#{base}.ps"))
               $stdout.write("ok\n")
            else 
               $stdout.write("--> FAILED <--\n")
            end
         rescue RuntimeError => e
            $stdout.write("Postscript generation failed for #{t}: #{e}")
         end
      end
      File.delete(psfile) if File.exists?(psfile)
   end
   $stdout.write("\n")
end
