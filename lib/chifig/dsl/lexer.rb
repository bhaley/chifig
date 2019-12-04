# =============================================================================
# lexer.rb -- CHIFIG::DSL::Lexer class
#
# Copyright (c) 2019 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

module CHIFIG

module DSL

Token = Struct.new(:code, :value, :lineno, :done)

#
# Lexer -- split input into tokens
#
# Instance variables
# str::      Input String
# i::        Integer current index in @str
# lineno::   Integer current line number
# cached::   Token that was pushed back during parsing
#
class Lexer
   TOK_LBRACE = 0   # {
   TOK_RBRACE = 1   # }
   TOK_COMMA  = 2   # ,
   TOK_QSTRING = 3  # 'tokens in quotes'
   TOK_STRING = 4   # everything else

   def initialize(str)
      @str = str
      @i = 0
      @lineno = 1
      @cached = nil
   end

   private

   # Return true if the end of input has been reached
   def _eos
      @i == @str.length
   end

   # Handle single character token; if we haven't read any other characters, 
   # this is the current token.  If we have already read some characters into
   # t, decrement @i so we handle c first in the next call to _get_token() and
   # make t a TOK_STRING
   def _single_char_token(t, c, code)
      if t.value.length == 0
         t.value << c
         t.code = code
      else
         @i -= 1
      end
      t.done = true
   end

   # Return the next token extracted from @str.  If the end of @str has already
   # been reached, return nil
   def _get_token
      t = Token.new(TOK_STRING, '', @lineno, _eos)
      in_string = false
      in_comment = false
      while !t.done
         c = @str[@i]
         if c == "\n"
            @lineno += 1
            t.done = true if t.value.length > 0
            t.lineno += 1 unless t.done
            in_string = false
            in_comment = false
         elsif !in_comment
            if c == "'" || c == '"'
               t.code = TOK_QSTRING
               t.done = true if in_string 
               in_string = !in_string
            elsif in_string
               t.value << c
            else
               case c
                  when '{'
                     _single_char_token(t, c, TOK_LBRACE)
                  when '}'
                     _single_char_token(t, c, TOK_RBRACE)
                  when ','
                     _single_char_token(t, c, TOK_COMMA)
                  when ' ', "\t"
                     t.done = true if t.value.length > 0
                  when '#'
                     in_comment = true
                  else
                     t.value << c
               end
            end
         end
         @i += 1
         t.done = _eos unless t.done
      end
      (_eos && t.value.length == 0) ? nil : t
   end

   public

   # Push tok back for the next call to token()
   def push_back(tok)
      @cached = tok
   end

   # Return the next token extracted from str passed to the constructor. 
   # Return nil when no more tokens can be extracted.
   def token
      t = (@cached) ? @cached : _get_token
      @cached = nil
      t
   end
end  # Lexer

end  # DSL

end  # CHIFIG
