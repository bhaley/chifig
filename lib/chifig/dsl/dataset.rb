# =============================================================================
# dataset.rb -- CHIFIG::Dataset and CHIFIG::ExpressionChecker classes
# 
# Copyright
#
# LICENSE
# =============================================================================

$have_gsl = true
begin
   require 'gsl'
rescue LoadError
   $have_gsl = false
end

module CHIFIG

#
# Point -- (x,y) point with error (xerr, yerr)
#
# Instance variables
# x::      Float X value
# y::      Float Y value
# xerr::   Float error in X
# yerr::   Float error in Y
#
class Point
   def initialize(x, y, xerr=0.0, yerr=0.0)
      @x = x.to_f
      @y = y.to_f
      @xerr = xerr.to_f
      @yerr = yerr.to_f
   end

   public 

   attr_reader :x, :y, :xerr, :yerr

end  # Point

#
# Dataset -- ordered container of Points with read and generate methods
#
# Instance variables
# points::  Array of Points
# xmin::    Float minimum X value
# xmax::    Float maximum X value
# ymin::    Float minimum Y value
# ymax::    Float maximum Y value
# xerror::  Boolean: X error values given
# yerror::  Boolean: Y error values given
# descr::   String description
#
class Dataset
   include Math        # evaluate math functions
   if $have_gsl
      include GSL
      include GSL::Sf  # evaluate special functions from GSL
   end

   def initialize
      @points = []
      @xmin =  Float::MAX
      @xmax = -Float::MAX
      @ymin =  Float::MAX
      @ymax = -Float::MAX
      @xerror = false
      @yerror = false
      @descr = ''
   end

   private

   # Add a new Point
   def _add_pt(x, y, xerr=0.0, yerr=0.0)
      @points << Point.new(x, y, xerr, yerr)
      @xmin = x if x < @xmin
      @xmax = x if x > @xmax
      @ymin = y if y < @ymin
      @ymax = y if y > @ymax
   end

   public

   attr_reader :points, :xmin, :xmax, :ymin, :ymax, :descr, :xerror, :yerror

   # Return the number of (x,y) Points
   def npoints
      @points.length
   end

   # Return Array of x values
   def xarr
      @points.collect {|p| p.x}
   end

   # Return Array of y values
   def yarr
      @points.collect {|p| p.y}
   end

   # Return Array of x error values
   def xerrarr
      @points.collect {|p| p.xerr}
   end

   # Return Array of y error values
   def yerrarr
      @points.collect {|p| p.yerr}
   end

   # Read data from a file; raise RuntimeError if read fails.
   # Note that shift is expected to be validated already by ExpressionChecker
   def read(path, xcol, ycol, xerrcol=0, yerrcol=0, every=1, delim=" \t,;:", 
            xshift=nil, yshift=nil)
      @descr = path
      @descr += ", xcol=#{xcol}" if xcol != 1
      @descr += ", ycol=#{ycol}" if ycol != 2
      if xerrcol > 0
         @descr += ", xerrcol=#{xerrcol}"
         @xerror = true
      end
      if yerrcol > 0
         @descr += ", yerrcol=#{yerrcol}"
         @yerror = true
      end
      @descr += ", xshift=\"#{xshift}\"" if xshift
      @descr += ", yshift=\"#{yshift}\"" if yshift
      maxcol = [xcol, ycol, xerrcol, yerrcol].max
      delim_re = Regexp.new("[#{delim}]+")
      count = 0
      begin 
         IO.foreach(path) do |line|
            next if line[0] == '#'
            words = line.strip.split(delim_re)
            next if words.length < maxcol
            count += 1
            next if count.modulo(every) != 0
            x = words[xcol-1].to_f
            y = words[ycol-1].to_f
            x = eval(xshift) if xshift
            y = eval(yshift) if yshift
            xerr = (@xerror) ? words[xerrcol-1].to_f : 0.0
            yerr = (@yerror) ? words[yerrcol-1].to_f : 0.0
            _add_pt(x, y, xerr, yerr)
         end
      rescue SystemCallError => e
         raise RuntimeError, "Unable to read data from #{path}: #{e.message}"
      end
   end

   # Generate data from f(x) expression; note expr is expected to be validated
   # already by ExpressionChecker; raise RuntimeError if eval fails
   def generate_fx(expr, xmin, xmax, dx)
      @descr = expr
      x_max = xmax + 0.5*dx
      x = xmin
      errmsg = "Evaluation of \"#{expr}\" failed: "
      begin
         begin
            y = eval(expr)
            _add_pt(x, y)
            x += dx
         end while x < x_max
      rescue SyntaxError => e
         raise RuntimeError, "#{errmsg}: #{e.message}"
      rescue NoMethodError => e
         raise RuntimeError, "#{errmsg}: #{e.message}"
      end
   end

   # Generate data from x(t), y(t) parametric expressions; note xexpr and expr
   # are expected to be validated already by ExpressionChecker; raise 
   # RuntimeError if eval fails
   def generate_xyt(xexpr, yexpr, tmin, tmax, dt)
      @descr = "x(t) = #{xexpr}, y(t) = #{yexpr}"
      t_max = tmax + 0.5*dt
      t = tmin
      errmsg = "Evaluation of \"#{xexpr}, #{yexpr}\" failed: "
      begin
         begin
            x = eval(xexpr)
            y = eval(yexpr)
            _add_pt(x, y)
            t += dt
         end while t < t_max
      rescue SyntaxError => e
         raise RuntimeError, "#{errmsg}: #{e.message}"
      rescue NoMethodError => e
         raise RuntimeError, "#{errmsg}: #{e.message}"
      end
   end

end  # Dataset

#
# ExpressionChecker -- verify expression String before evaluating
#
# Instance variables
# allowed::  Array of allowed Symbols in expression
#
class ExpressionChecker
   def initialize
      @allowed = [:x, :t]
      @allowed += Math.methods(false)
      @allowed += Math.constants  # E, PI
      @allowed += GSL.methods(false) if $have_gsl
      @allowed += GSL::Sf.methods(false) if $have_gsl
   end

   public

   # Return false and the offending String if any word (alphabet characters) 
   # in expr is not allowed; return true, '' if expr is OK
   def check(expr)
      s = expr
      while (m = /([A-Za-z]+)/.match(s))
         return false, m[1] unless @allowed.include?(m[1].to_sym)
         s = m.post_match
      end
      return true, ''
   end

end  # ExpressionChecker

end  # CHIFIG
