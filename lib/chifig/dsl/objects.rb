# =============================================================================
# objects.rb -- CHIFIG::DSL::Object and derived classes
#
# Copyright
#
# LICENSE
# =============================================================================

require 'json'
require_relative 'dataset'

module CHIFIG

module DSL

#
# Obejct -- base for all DSL objects
#
# Instance variables
# data::         Hash of parameters, sub-objects
# bool_opts::    Array of single token keys that indicate 'true'
# xy_opts::      Array of keys that take 'x, y' arguments
# list_subs::    Array of sub-object names that require enumeration in JSON
# index_subs::   Boolean flag; index objects with names in @list_subs?
# json_built::   Boolean flag; have we already generated JSON?
# commands::     Array of commands exposed for parsing
#
class Object
   def initialize(index_subs=true)
      @data = {}
      @bool_opts = []
      @xy_opts = []
      @list_subs = []
      @index_subs = index_subs
      @json_built = false
      @commands = ['title', 'line']
   end

   private

   # Return an Array with all keys that include name
   def _keys_include(name)
      @data.keys.find_all {|k| k.include?(name)}
   end

   # Final steps before generating JSON
   def _pre_json
   end

   public

   attr_reader :bool_opts, :xy_opts, :commands, :index_subs

   # Add val to @data; if it is an indexed sub-object, set the key to 
   # e.g. "plot1", "label2", "box3", etc.
   def add_data(key, val)
      k = key
      if @index_subs && @list_subs.include?(key)
         n = _keys_include(key).length
         k = "#{key}#{n+1}"
      end
      case val
         when 'true'
            v = true
         when 'false'
            v = false
         else
            v = val
      end
      @data[k] = v
   end

   # Command: title 'text' [, 'color']
   def title(args)
      return false, 'Missing title text' if args.length < 2
      @data['title'] = {'text' => args[0]}
      @data['title']['color'] = args[1] if args.length > 2
      return true, ''
   end

   # Command: line 'style' [, 'color'] [, width=n, dash_length=n, dash_gap=n, \
   #                                      dot_gap=n]
   def line(args)
      return false, 'Missing line style' if args.length < 2
      ln = {'style' => args[0]}
      ln['color'] = args[1] if args.length > 2
      args.last.each {|k,v| ln[k] = v.to_s}
      @data['line'] = ln
      return true, ''
   end

   # Return a JSON string representing this DSLObject
   def to_json(*a)
      if ! @json_built
         _pre_json
         @list_subs.each do |name|
            names = (name[-1] == 'x') ? "#{name}es" : "#{name}s"
            @data[names] = _keys_include(name)
         end
         @json_built = true
      end
      #@data.to_json(*a)
      JSON.pretty_generate(@data)
   end
end

# 
# Axis
#
class Axis < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @bool_opts << 'logscale'
   end
end

#
# Grid
#
class Grid < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @bool_opts << 'show'
   end
end

#
# Arrow
#
class Arrow < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @xy_opts << 'from' << 'to'
      @commands << 'head'
   end
   
   # Command: head hide | width, length, inset
   def head(args)
      syn = 'Expecting "head hide | width, length, inset"'
      return false, syn if args.length < 2 || args.length > 4
      h = {'show' => true}
      if args[0] == 'hide'
         h['show'] = false
      else
         h['width'] = args[0]
         h['length'] = args[1]
         h['inset'] = args[2]
      end
      @data['head'] = h
      return true, ''
   end
end

# 
# Box
#
class Box < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @xy_opts << 'll' << 'ur'
   end
end

#
# Circle
#
class Circle < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @xy_opts << 'position'
   end
end

#
# Curve
#
class Curve < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @bool_opts = ['xaxis2', 'yaxis2']
      @commands << 'symbol' << 'generate' << 'generate_t' << 'read'
      @d = Dataset.new
   end

   private

   def _pre_json
      @data['data'] = {'x' => @d.xarr, 'y' => @d.yarr}
      @data['data']['xerr'] = @d.xerrarr if @d.xerror
      @data['data']['yerr'] = @d.yerrarr if @d.yerror
   end

   public

   # Command: symbol 'shape' [, color] [, fill=bool, scale=real]
   def symbol(args)
      return false, 'Expecting "symbol shape"' if args.length < 2
      s = {'shape' => args[0]}
      if args[0] != 'none'
         return false, 'Expecting "symbol shape, color"' if args.length < 3
         s['color'] = args[1]
      end
      h = args.last
      s['fill'] = h['fill'] if h.has_key?('fill')
      s['scale'] = h['scale'].to_s if h.has_key?('scale')
      @data['symbol'] = s
      return true, ''
   end

   # DSL: generate 'expr', xmin, xmax, dx
   def generate(args)
      return false, 'Expecting "expr, xmin, xmax, dx"' if args.length != 5
      ec = ExpressionChecker.new
      safe, s = ec.check(args[0])
      raise RuntimeError, "Unable to evaluate '#{args[0]}': '#{s}'" unless safe
      @d.generate_fx(args[0], args[1].to_f, args[2].to_f, args[3].to_f)
      return true, ''
   end

   # DSL: generate_t 'xexpr', 'yexpr', tmin, tmax, dt
   def generate_t(args)
      return false, 'Expecting "xexpr, yexpr, tmin, tmax, dt"' if args.length != 6
      ec = ExpressionChecker.new
      safe, s = ec.check(args[0])
      raise RuntimeError, "Unable to evaluate '#{args[0]}': '#{s}'" unless safe
      safe, s = ec.check(args[1])
      raise RuntimeError, "Unable to evaluate '#{args[1]}': '#{s}'" unless safe
      @d.generate_xyt(args[0], args[1], args[2].to_f, args[3].to_f, args[4].to_f)
      return true, ''
   end

   # DSL: read 'file' [, xcol=n, ycol=n, xerrcol=n, yerrcol=n, every=n, \
   #                     delim='', xshift='', yshift='']
   def read(args)
      return false, 'Expecting data file path' if args.length < 2
      h = args[1]
      xcol = (h.has_key?('xcol')) ? h['xcol'].to_i : 1
      ycol = (h.has_key?('ycol')) ? h['ycol'].to_i : 2
      xerrcol = (h.has_key?('xerrcol')) ? h['xerrcol'].to_i : 0
      yerrcol = (h.has_key?('yerrcol')) ? h['yerrcol'].to_i : 0
      every = (h.has_key?('every')) ? h['every'].to_i : 1
      delim = (h.has_key?('delim')) ? h['delim'] : " \t,;:"
      ec = ExpressionChecker.new
      if xshift = h['xshift']
         safe, s = ec.check(xshift)
         raise RuntimeError,"Unable to evaluate '#{xshift}': '#{s}'" unless safe
      end
      if yshift = h['yshift']
         safe, s = ec.check(yshift)
         raise RuntimeError,"Unable to evaluate '#{yshift}': '#{s}'" unless safe
      end
      @d.read(args[0], xcol, ycol, xerrcol, yerrcol, every, delim, xshift, yshift)
      return true, ''
   end
end

# 
# Plot
#
class Plot < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @data['key'] = {}
      @list_subs = ['curve', 'box', 'circle', 'arrow', 'label']
      @commands << 'label' << 'key'
   end

   private

   def _pre_json
      ['xaxis', 'yaxis', 'xaxis2', 'yaxis2'].each do |ax| 
         @data[ax] = Axis.new unless @data.has_key?(ax)
      end
   end

   public

   # Command: label 'text', x, y [, color=clr, angle=ang]
   def label(args)
      return false, 'Expecting "label \"text\", x, y' if args.length != 4
      t = {'text' => args[0]}
      h = args[3]
      t['color'] = h['color'] if h.has_key?('color')
      lb = {'title' => t, 'position' => "#{args[1]},#{args[2]}"}
      lb['angle'] = h['angle'].to_s if h.has_key?('angle')
      add_data('label', lb)
      return true, ''
   end

   # Command: key [hide] [x,y]
   def key(args)
      if args.length < 2 || args.length > 3
         return false, 'Expecting "key hide" or "key x, y"'
      end
      if args[0] == 'hide'
         @data['key'] = {'show' => false}
      else
         @data['key']['position'] = "#{args[0]},#{args[1]}"
      end
      return true, ''
   end
end

#
# Default
#
class Default < CHIFIG::DSL::Object
   def initialize(index_subs=false)
      super(false)
   end
end

# 
# Figure
#
class Figure < CHIFIG::DSL::Object
   def initialize(index_subs=true)
      super(index_subs)
      @data['rgb'] = {}
      @list_subs = ['plot']
      @commands << 'rgb'
   end

   public

   # Command: rgb 'colorname', 'r g b'
   def rgb(args)
      return false, 'Expecting rgb "colorname", "r g b"' if args.length != 3
      @data['rgb'][args[0]] = args[1]
      return true, ''
   end
end

end  # DSL

end  # CHIFIG
