# =============================================================================
# parser.rb -- CHIFIG::DSL::Parser class
#
# Copyright
#
# LICENSE
# =============================================================================

require_relative 'lexer'
require_relative 'objects'

module CHIFIG

module DSL

#
# Parser -- interpret and execute DSL input
#
# Instance variables
# types::  Hash of keys handled with "key {" parsing, creating a new sub object
# 
class Parser
   def initialize
      @types = {
         'xaxis' =>   Axis,
         'yaxis' =>   Axis,
         'xaxis2' =>  Axis,
         'yaxis2' =>  Axis,
         'xgrid' =>   Grid,
         'ygrid' =>   Grid,
         'arrow' =>   Arrow,
         'box' =>     Box, 
         'circle' =>  Circle,
         'curve' =>   Curve, 
         'plot' =>    Plot, 
         'default' => Default
      }
   end

   private

   # Handle parse errors by raising a SyntaxError
   def _error(msg, tok=nil)
      s = ''
      s << "(#{tok.value}, line #{tok.lineno}): " if tok
      s << msg
      raise SyntaxError, s
   end

   # Return an Array of comma separated args to t.  The final arg is a Hash of 
   # optional arguments given in the form opt=value.
   # XXX assumes at least 1 arg ... 
   # 
   # e.g. 'arg1, opt2=val2, opt3=val3, arg4' returns 
   # ['arg1', 'arg4', {'opt2' => 'val2', 'opt3' => 'val3'}]
   def _collect_args(lexer, t)
      args = []
      opts = {}
      begin
         ta = lexer.token
         _error("Missing argument", t) unless ta
         case ta.code
            when Lexer::TOK_QSTRING
               args << ta.value
            when Lexer::TOK_STRING
               v = ta.value.split('=')
               if v.length == 1
                  args << v[0]
               else
                  opts[v[0]] = v[1]
               end
            else
               _error("Unexpected #{ta.value}", ta)
         end

         tc = lexer.token
         # TODO if !tc: ???????????????????????
         if tc.code != Lexer::TOK_COMMA  # end of args
            lexer.push_back(tc)
            break
         end
      end while true
      args << opts
   end

   public

   # Main parser interface: interpret str, return (true, JSON string) or   
   # (false, error message)
   def parse(str)
      lexer = Lexer.new(str)
      stack = [CHIFIG::DSL::Figure.new]

      begin  # error handling
         begin  # loop over tokens
            obj = stack.last  # current object
            _error('Empty stack') unless obj

            t = lexer.token
            break unless t  # EOF

            # single token: boolean flag
            if obj.bool_opts.include?(t.value)
               obj.add_data(t.value, true)
               next
            end

            # single token: }
            if t.code == Lexer::TOK_RBRACE
               stack.pop
               next
            end

            # multiple tokens: key, x, y
            if obj.xy_opts.include?(t.value)
               args = _collect_args(lexer, t)
               _error("Expected x, y args", t) unless args.length == 3
               obj.add_data(t.value, "#{args[0]},#{args[1]}")
               next
            end

            # multiple tokens: key arg, ..., opt=value, ...
            if obj.commands.include?(t.value)
               args = _collect_args(lexer, t)
               #puts "calling #{t.value}, args = #{args}"
               status, msg = obj.send(t.value, args)
               _error(msg, t) if !status
               next
            end

            # need to check the next token
            tn = lexer.token
            _error("Missing argument", t) unless tn

            if tn.code == Lexer::TOK_LBRACE
               if @types.has_key?(t.value)
                  newobj = @types[t.value].new(obj.index_subs)
               else
                  newobj = CHIFIG::DSL::Object.new(obj.index_subs)
               end
               obj.add_data(t.value, newobj)
               stack << newobj
            else  # key value
               obj.add_data(t.value, tn.value)
            end
         end while true
         n = stack.length
         _error("#{n} items on stack at end") unless n == 1
      rescue SyntaxError => e
         return false, e.message
      end
      return true, stack[0].to_json
   end
end  # Parser

end  # DSL

end  # CHIFIG
