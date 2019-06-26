# =============================================================================
# axis.rb -- CHIFIG::Axis class
#
# Copyright (c) 2019 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

module CHIFIG

#
# Axis -- range and tick information for a plot axis
#
# Instance variables
# min::     Float
# max::     Float
# ticks::   Array of Float tick values
# used::    Boolean flag: is anything plotted against this axis?
#
class Axis
   def initialize
      @min = Float::MAX
      @max = -Float::MAX
      @ticks = []
      @used = false
   end

   public

   attr_reader :ticks, :used
   attr_accessor :min, :max

   def update_range(data)
      m = data.min
      @min = m if m < @min
      m = data.max
      @max = m if m > @max
      @used = true
   end

   # Determine tick mark values for this axis
   def set_ticks(min, max, number, logscale, zero)
      tmin = (min.length > 0) ? min.to_f : @min
      tmin = Math.log10(tmin) if logscale
      tmax = (max.length > 0) ? max.to_f : @max
      tmax = Math.log10(tmax) if logscale
      dt = (tmax - tmin)/(number-1).to_f
      0.upto(number-1) do |i|
         t = tmin + i*dt
         rt = t.round
         t = rt if (rt-t).abs < zero
         t = 0.0 if t.abs < zero
         @ticks << t
      end
   end

end  # Axis

end  # CHIFIG
