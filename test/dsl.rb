# =============================================================================
# dsl.rb -- tests for DSL examples
#
# Copyright (c) 2019-2020 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

require_relative 'test'

topdir = File.dirname(File.dirname(File.expand_path(__FILE__)))
$: << File.join(topdir, 'lib')

require 'chifig'
require 'chifig/dsl'

default_json = File.read(File.join(topdir, 'data', 'default.json'))
parser = CHIFIG::DSL::Parser.new
ps_lambda = lambda do |t, psfile|
   status, out = parser.parse(File.read(t))
   if status
      #File.open("#{t}.json", 'w') {|f| f.write(out)}
      psg = CHIFIG::PSGen.new('latex', 'dvips')  # XXX assumes PATH
      psg.convert(out, default_json, psfile)
   else
      puts "#{t} failed: #{out}"
   end
end
         
test_dir = File.join(topdir, 'doc', 'examples')
tests = Dir.glob(File.join(test_dir, '*.in'))
#tests = ['logo.in']
         
run_tests(test_dir, tests, ps_lambda)
