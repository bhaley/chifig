# =============================================================================
# json.rb -- Tests for JSON examples
#
# Copyright (c) 2019 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

require_relative 'test'

topdir = File.dirname(File.dirname(File.expand_path(__FILE__)))
$: << File.join(topdir, 'lib')

require 'chifig'

default_json = File.read(File.join(topdir, 'data', 'default.json'))
ps_lambda = lambda do |t, psfile| 
   psg = CHIFIG::PSGen.new('latex', 'dvips')  # XXX assumes PATH
   psg.convert(File.read(t), default_json, psfile)
end

test_dir = File.join(topdir, 'doc', 'examples')
tests = Dir.glob(File.join(test_dir, '*.json'))
#tests = ['bessel.json']
         
run_tests(test_dir, tests, ps_lambda)
