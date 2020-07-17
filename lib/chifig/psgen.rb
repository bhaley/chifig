# =============================================================================
# psgen.rb -- CHIFIG::PSGen class
#
# Copyright (c) 2019-2020 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

$debug = false

require 'json'
require_relative 'merge'
require_relative 'exec'
require_relative 'axis'

module CHIFIG

#
# PSGen -- generate Postscript from a JSON description
#
# Instance variables
# latex_cmd::   String command to invoke LaTeX
# dvips_cmd::   String command to invokd dvips
# data::        Data from JSON input
# latex_str::   LaTeX input String constructed from parsing @data
# tmpfile::     String name of temp LaTeX file 
# size_re::     Regexp for extracting text size from LaTeX output
# xkey::        Current Float X position of key in a plot
# ykey::        Current Float Y position of key in a plot
# zero::        Float values less than this are considered zero
#
class PSGen

   LOGSCALE_TICK_FORMAT = '$10^{%g}$'
   SEPARATOR = ':'

   def initialize(latex_cmd, dvips_cmd)
      @latex_cmd = latex_cmd
      @dvips_cmd = dvips_cmd
      @data = nil
      @latex_str = ''
      @tmpfile = "tmp#{Process.pid}"
      @size_re = /^([\d\.]+).*\n([\d\.]+).*\n([\d\.]+).*\n/
      @xkey = 0
      @ykey = 0
      @zero = 1e-15
   end

   private

   # Return a value for key; search first in obj, if obj != nil, then search
   # in defobj if no match is found.  Assumes obj[] returns nil if no match.
   # Raise a RuntimeError if key is not found in obj and defobj is nil.
   # If the value contains SEPARATOR (i.e. if it is the path to another value),
   # search from @data.
   # XXX avoid '' values in obj; the key should not be in obj if value is not
   # specified
   def _get_value(key, obj, defobj)
      val = (obj) ? obj[key] : nil
      if val == nil
         raise RuntimeError, "Unable to find value for '#{key}'" unless defobj
         val = defobj[key]
      end
      while val && val.respond_to?(:split) && val[0] == '@'
         #puts "handling #{val}"
         comps = val[1..-1].split(SEPARATOR)
         if comps.length > 1
            val = @data
            comps.each {|c| val = val[c]}
         end
      end
      val
   end

   # Return a Float value from _get_value()
   def _get_float_value(key, obj, defobj)
      s = _get_value(key, obj, defobj)
      raise RuntimeError, "Bad float value: '#{s}'" if s == nil || s.length == 0
      s.to_f
   end

   # Return a Integer value from _get_value()
   def _get_int_value(key, obj, defobj)
      s = _get_value(key, obj, defobj)
      raise RuntimeError, "Bad int value: '#{s}'" if s == nil || s.length == 0
      s.to_i
   end

   # Return common header used for all LaTeX inputs
   def _latex_header(obj=nil, defobj=@data['default'])
      ptsize = _get_value('font_size', obj, defobj)
      s  = "\\documentclass[class=scrreprt,#{ptsize}pt]{standalone}\n"
      s << "\\pagestyle{empty}\n"
      s << "\\usepackage{pstricks}\n"
      s << "\\usepackage{pst-plot}\n"
      s << "\\usepackage{times}\n"
      s << "\\begin{document}\n"
      s << "\\psset{unit=#{_get_value('unit', obj, defobj)}}\n"
      s
   end

   # Return width, height+depth of text as determined by LaTeX
   def _get_size(text, obj=nil)
      w = h = d = 0
      s = _latex_header(obj)
      s += "\\newlength{\\twid}\n"
      s += "\\newlength{\\tht}\n"
      s << "\\newlength{\\tdp}\n"
      s << "\\newsavebox{\\ttxt}\n"
      s << "\\savebox{\\ttxt}{#{text}}\n"
      s << "\\settowidth{\\twid}{\\usebox{\\ttxt}}\n"
      s << "\\settoheight{\\tht}{\\usebox{\\ttxt}}\n"
      s << "\\settodepth{\\tdp}{\\usebox{\\ttxt}}\n"
      s << "\\typeout{\\the\\twid}\n"
      s << "\\typeout{\\the\\tht}\n"
      s << "\\typeout{\\the\\tdp}\n"
      s << "\\end{document}"
      texpath = "#{@tmpfile}.tex"
      File.open(texpath, 'w') {|f| f.write(s)}
      output = CHIFIG.exec_read("#{@latex_cmd} #{texpath}")
      m = @size_re.match(output)
      if m
         w = m[1].to_f
         h = m[2].to_f
         d = m[3].to_f
      end
      return w, h+d
   end

   # Add commands to @latex_str to set line styles for obj
   def _set_line(obj, defobj)
      lnobj = (obj) ? obj['line'] : nil
      deflnobj = defobj['line']
      style = _get_value('style', lnobj, deflnobj)
      color = _get_value('color', lnobj, deflnobj)
      width = _get_float_value('width', lnobj, deflnobj)
      stylestr = "linestyle=#{style}"
      if style == 'dashed'
         stylestr << ',dash='
         stylestr << _get_value('dash_length', lnobj, deflnobj)
         stylestr << ' ' 
         stylestr << _get_value('dash_gap', lnobj, deflnobj)
      elsif style == 'dotted'
         stylestr << ",dotsep=" << _get_value('dot_gap', lnobj, deflnobj)
      end
      @latex_str << "\\psset{linewidth=#{width},linecolor=#{color},#{stylestr}}\n"
   end

   # Add commands to restore default line styles
   def _reset_line
      _set_line(nil, @data['default'])
   end

   # Transform a data coordinate v, in [vmin,vmax], to a Postscript coordinate 
   # in [clow,chigh]
   def _trans(v, vmin, vmax, clow, chigh)
      if v < vmin
         return clow
      elsif v > vmax
         return chigh
      end
      clow + (chigh-clow)*((v-vmin)/(vmax-vmin))
   end

   # Add commands to @latex_str to display title text at (x,y) with reference 
   # point ref
   def _add_text(text, x, y, angle, color, ref=nil)
      if text && text.length > 0
         s = ''
         s << "\\rput"
         s << "[#{ref}]" if ref
         s << "{#{angle}}(#{x},#{y}){"
         s << "\\#{color} " if color.length > 0
         s << "#{text}}\n"
         @latex_str << s
      end
   end

   # Add commands to @latex_str to display the box described by bobj
   def _add_box(bobj, xmin, ymin, xmax, ymax, axis_x0, axis_y0, axis_x1,axis_y1)
      defobj = @data['default']['plot']['box']
      _set_line(bobj, defobj)
      bgcolor = _get_value('bgcolor', bobj, defobj)
      opts = "fillcolor=#{bgcolor},fillstyle=solid,"
      sobj = bobj['shadow']
      defobj = defobj['shadow']
      if _get_value('show', sobj, defobj)
         opts << 'shadow=true,'
         size = _get_float_value('width', sobj, defobj)
         opts << "shadowsize=#{size},"
         color = _get_value('color', sobj, defobj)
         opts << "shadowcolor=#{color},"
         shdir = _get_value('direction', sobj, defobj)
         case shdir
            when 'ne'
               ang = 45
            when 'nw'
               ang = 135
            when 'sw'
               ang = -135
            when 'se'
               ang = -45
            else
               raise RuntimeError, "Unknown shadow direction: #{shdir}"
         end
         opts << "shadowangle=#{ang}"
      else
         opts << 'shadow=false'
      end
      ll = _get_value('ll', bobj, defobj).split(',')
      ur = _get_value('ur', bobj, defobj).split(',')
      llx = _trans(ll[0].to_f, xmin, xmax, axis_x0, axis_x1)
      lly = _trans(ll[1].to_f, ymin, ymax, axis_y0, axis_y1)
      urx = _trans(ur[0].to_f, xmin, xmax, axis_x0, axis_x1)
      ury = _trans(ur[1].to_f, ymin, ymax, axis_y0, axis_y1)
      @latex_str << "\\psframe[#{opts}](#{llx},#{lly})(#{urx},#{ury})\n"
      _reset_line
   end

   # Add commands to @latex_str to display the circle described by cobj
   def _add_circle(cobj, xmin, ymin, xmax, ymax,axis_x0,axis_y0,axis_x1,axis_y1)
      defobj = @data['default']['plot']['circle']
      _set_line(cobj, defobj)
      bgcolor = _get_value('bgcolor', cobj, defobj)
      opts = "fillcolor=#{bgcolor},fillstyle=solid,"
      pos = _get_value('position', cobj, defobj).split(',')
      x = _trans(pos[0].to_f, xmin, xmax, axis_x0, axis_x1)
      y = _trans(pos[1].to_f, ymin, ymax, axis_y0, axis_y1)
      rad = _get_float_value('radius', cobj, defobj)
      @latex_str<< "\\pscircle[#{opts}](#{x},#{y}){#{rad}}\n"
      _reset_line
   end

   # Add commands to @latex_str to display the arrow described by aobj
   def _add_arrow(aobj, xmin, ymin, xmax, ymax, axis_x0,axis_y0,axis_x1,axis_y1)
      defobj = @data['default']['plot']['arrow']
      _set_line(aobj, defobj)
      opts = ''
      hobj = aobj['head']
      defhobj = defobj['head']
      if _get_value('show', hobj, defhobj)
         opts = 'arrows=->,'
         len = _get_value('length', hobj, defhobj)
         opts << "arrowlength=#{len},"
         inset = _get_value('inset', hobj, defhobj)
         opts << "arrowinset=#{inset},"
         width = _get_value('width', hobj, defhobj)
         opts << "arrowsize=0 #{width}"
      else
         opts << 'arrows=-,'
      end
      p0 = _get_value('from', aobj, defobj).split(',')
      p1 = _get_value('to', aobj, defobj).split(',')
      x0 = _trans(p0[0].to_f, xmin, xmax, axis_x0, axis_x1)
      y0 = _trans(p0[1].to_f, ymin, ymax, axis_y0, axis_y1)
      x1 = _trans(p1[0].to_f, xmin, xmax, axis_x0, axis_x1)
      y1 = _trans(p1[1].to_f, ymin, ymax, axis_y0, axis_y1)
      @latex_str << "\\psline[#{opts}](#{x0},#{y0})(#{x1},#{y1})\n"
      _reset_line
   end

   # Add commands to @latex_str to display the label described by lobj
   def _add_label(lobj, xmin, ymin, xmax, ymax, axis_x0,axis_y0,axis_x1,axis_y1,
                  xlogscale, ylogscale)
      defobj = @data['default']['plot']['label']
      pos = _get_value('position', lobj, defobj).split(',')
      if xlogscale
         xmin = Math.log10(xmin)
         xmax = Math.log10(xmax)
         pos[0] = Math.log10(pos[0].to_f)
      end
      x = _trans(pos[0].to_f, xmin, xmax, axis_x0, axis_x1)
      if ylogscale
         ymin = Math.log10(ymin)
         ymax = Math.log10(ymax)
         pos[1] = Math.log10(pos[1].to_f)
      end
      y = _trans(pos[1].to_f, ymin, ymax, axis_y0, axis_y1)
      ang = _get_float_value('angle', lobj, defobj)
      tobj = lobj['title']
      deftobj = defobj['title']
      text = _get_value('text', tobj, deftobj)
      color = _get_value('color', tobj, deftobj)
      _add_text(text, x, y, ang, color)
   end

   # Return the default curve for key, or the defcurve if key is not found
   def _def_curve(key)
      @data['default']['plot'][key] || @data['default']['plot']['defcurve']
    end

   # Add commands to @latex_str to display the curve described by cobj
   def _add_curve(cobj, defcobj, xmin, xmax, ymin, ymax, xlow, xhigh, ylow, 
                  yhigh, show_key, key_line_len, padding, xlogscale, ylogscale)
      if xlogscale
         xmin = Math.log10(xmin)
         xmax = Math.log10(xmax)
      end
      if ylogscale
         ymin = Math.log10(ymin)
         ymax = Math.log10(ymax)
      end
      pts = ''
      dobj = cobj['data']
      xd = dobj['x']
      yd = dobj['y']
      0.upto(xd.length-1) do |i|
         x = (xlogscale) ? Math.log10(xd[i]) : xd[i]
         y = (ylogscale) ? Math.log10(yd[i]) : yd[i]
         xt = _trans(x, xmin, xmax, xlow, xhigh)
         yt = _trans(y, ymin, ymax, ylow, yhigh)
         pts << "(#{xt},#{yt})"
      end
      if show_key
         tobj = cobj['title']
         deftobj = defcobj['title']
         key_text = _get_value('text', tobj, deftobj)
         key_color = _get_value('color', tobj, deftobj)
         wkey, hkey = _get_size(key_text)
         @ykey -= hkey/2
      end

      lobj = cobj['line']
      deflobj = defcobj['line']
      style = _get_value('style', lobj, deflobj)
      if style != 'none'
         _set_line(cobj, defcobj)
         @latex_str << "\\psline#{pts}\n"
         if show_key
            @latex_str << "\\psline(#{@xkey},#{@ykey})"
            @latex_str << "(#{@xkey+key_line_len},#{@ykey})\n"
         end
         _reset_line
      end

      sobj = cobj['symbol']
      defsobj = defcobj['symbol']
      shape = _get_value('shape', sobj, defsobj)
      fill = _get_value('fill', sobj, defsobj)
      scale = _get_float_value('scale', sobj, defsobj)
      color = _get_value('color', sobj, defsobj)
      show_pts = true
      ang = 0.0
      case shape
         when 'circle'
            shape = (fill) ? '' : 'o'
         when 'diamond'
            shape = 'square'
            ang = 45.0
         when 'x', '+'
            fill = false
         when 'del'
            shape = 'triangle'
            ang = 180.0
         when 'xerrbar', 'yerrbar'
            barwidth = _get_float_value('errorbar_width', nil, @data['default'])
            show_pts = false
         when 'none'
            show_pts = false
      end
      shape << '*' if fill
      
      if show_pts
         @latex_str << "\\psset{linecolor=#{color}}\n"
         opts = "showpoints=true,dotstyle=#{shape}"
         opts << ",dotangle=#{ang}" if ang != 0.0
         opts << ",dotscale=#{scale} #{scale}" if scale != 1.0
         @latex_str << "\\psdots[#{opts}]#{pts}\n"
         if show_key
            @latex_str << "\\psdots[#{opts}](#{@xkey+0.5*key_line_len},#{@ykey})\n"
         end
         _reset_line
      elsif shape == 'xerrbar'
         @latex_str << "\\psset{linecolor=#{color}}\n"
         opts = 'arrows=|-|'
         opts << ",tbarsize=0 #{barwidth}"
         dobj = cobj['data']
         xerr = dobj['xerr']
         raise RuntimeError, 'Missing x error data' unless xerr
         0.upto(xd.length-1) do |i|
            x = (xlogscale) ? Math.log10(xd[i]) : xd[i]
            y = (ylogscale) ? Math.log10(yd[i]) : yd[i]
            xe = (xlogscale) ? Math.log10(xerr[i]) : xerr[i]
            y0 = _trans(y, xmin, xmax, xlow, xhigh)
            x0 = _trans(x-xe, ymin, ymax, ylow, yhigh)
            x1 = _trans(x+xe, ymin, ymax, ylow, yhigh)
            @latex_str << "\\psline[#{opts}](#{x0},#{y0})(#{x1},#{y0})\n"
         end
         if show_key
            x0 = @xkey + 0.5*key_line_len
            @latex_str << "\\psline[#{opts}]"
            @latex_str << "(#{x0-barwidth},#{@ykey})"
            @latex_str << "(#{x0+barwidth},#{@ykey})\n"
         end
         _reset_line
      elsif shape == 'yerrbar'
         @latex_str << "\\psset{linecolor=#{color}}\n"
         opts = 'arrows=|-|'
         opts << ",tbarsize=0 #{barwidth}"
         dobj = cobj['data']
         yerr = dobj['yerr']
         raise RuntimeError, 'Missing y error data' unless yerr
         0.upto(xd.length-1) do |i|
            x = (xlogscale) ? Math.log10(xd[i]) : xd[i]
            y = (ylogscale) ? Math.log10(yd[i]) : yd[i]
            ye = (ylogscale) ? Math.log10(yerr[i]) : yerr[i]
            x0 = _trans(x, xmin, xmax, xlow, xhigh)
            y0 = _trans(y-ye, ymin, ymax, ylow, yhigh)
            y1 = _trans(y+ye, ymin, ymax, ylow, yhigh)
            @latex_str << "\\psline[#{opts}](#{x0},#{y0})(#{x0},#{y1})\n"
         end
         if show_key
            x0 = @xkey + 0.5*key_line_len
            @latex_str << "\\psline[#{opts}]"
            @latex_str << "(#{x0},#{@ykey-barwidth})"
            @latex_str << "(#{x0},#{@ykey+barwidth})\n"
         end
         _reset_line
      end

      if show_key
         # Can't escape underscores here: $J_2$, for example, requires '_'
         # XXX key text can't contain underscores
         _add_text(key_text, @xkey + key_line_len + padding, @ykey, 0.0, 
                   key_color, 'l')
         @ykey -= hkey/2 + padding
      end
   end  # _add_curve()

   # Add commands to display the plot pobj
   def _add_plot(pobj, defpobj, orig_x, orig_y, width, height)
      padding = _get_float_value('padding', nil, @data['default'])

      # Initial range of all axes: data range
      axes = []
      4.times {axes << Axis.new}
      curves = pobj['curves']
      raise RuntimeError, 'Missing curves' unless curves
      curves.each_with_index do |ckey,i|
         curve = pobj[ckey]
         raise RuntimeError, "Missing curve #{ckey}" unless curve
         dobj = curve['data']
         raise RuntimeError "Missing data for curve #{ckey}" unless dobj
         xd = dobj['x']
         raise RuntimeError, "Missing x data for curve #{ckey}" unless xd
         yd = dobj['y']
         raise RuntimeError, "Missing y data for curve #{ckey}" unless yd
         raise RuntimeError, "x size != y size for curve #{ckey}" unless xd.length == yd.length
         defcobj = _def_curve("curve#{i+1}")
         j = _get_value('xaxis2', curve, defcobj) ? 2 : 0
         axes[j].update_range(xd)
         j = _get_value('yaxis2', curve, defcobj) ? 3 : 1
         axes[j].update_range(yd)
      end
      # If min/max explicitly specificed for any axis, override data range
      ['xaxis', 'yaxis', 'xaxis2', 'yaxis2'].each_with_index do |axname,i|
         aobj = pobj[axname]
         defaobj = @data['default']['plot'][axname]
         min = _get_value('min', aobj, defaobj)
         axes[i].min = min.to_f if min.length > 0
         max = _get_value('max', aobj, defaobj)
         axes[i].max = max.to_f if max.length > 0
      end

      axis_x0 = orig_x
      axis_y0 = orig_y
      axis_x1 = axis_x0 + width
      axis_y1 = axis_y0 + height

      #
      # Bottom axis: move axis_y0 in from plot edge 
      #
      ax = axes[0]
      aobj = pobj['xaxis']
      defaobj = defpobj['xaxis']
      logscale = _get_value('logscale', aobj, defaobj) 
      bottom_axis_title_y = axis_y0
      tobj = aobj['title']
      deftobj = defaobj['title']
      text = _get_value('text', tobj, deftobj)
      if text.length > 0
         w,h = _get_size(text)
         axis_y0 += h + padding
         axis_x0 += padding
      end
      tobj = aobj['ticks']
      deftobj = defaobj['ticks']
      min = _get_value('min', tobj, deftobj)
      max = _get_value('max', tobj, deftobj)
      num = _get_int_value('number', tobj, deftobj)
      fmt = (logscale) ? LOGSCALE_TICK_FORMAT : _get_value('format', tobj, deftobj)
      scale = _get_float_value('scale', tobj, deftobj)
      ax.set_ticks(min, max, num, logscale, @zero)
      bottom_tick_labels = []
      ax.ticks.each do |tick|
         label = sprintf(fmt, tick/scale)
         bottom_tick_labels << label
      end
      bottom_axis_tick_y = axis_y0
      w, h = _get_size(bottom_tick_labels.last)  # assume all same height
      axis_y0 += h + padding if h > 0
      bottom_tick_half = 0
      axmax = (logscale) ? Math.log10(ax.max) : ax.max
      bottom_tick_half = w/2 if (ax.ticks.last - axmax).abs < @zero

      #
      # Left axis: move axis_x0 in from plot edge 
      #
      ax = axes[1]
      aobj = pobj['yaxis']
      defaobj = defpobj['yaxis']
      logscale = _get_value('logscale', aobj, defaobj) 
      tobj = aobj['title']
      deftobj = defaobj['title']
      text = _get_value('text', tobj, deftobj)
      if text.length > 0
         w,h = _get_size(text)
         axis_x0 += h
         left_axis_title_x = axis_x0
         axis_x0 += padding
      end
      tobj = aobj['ticks']
      deftobj = defaobj['ticks']
      min = _get_value('min', tobj, deftobj)
      max = _get_value('max', tobj, deftobj)
      num = _get_int_value('number', tobj, deftobj)
      fmt = (logscale) ? LOGSCALE_TICK_FORMAT : _get_value('format', tobj, deftobj)
      scale = _get_float_value('scale', tobj, deftobj)
      ax.set_ticks(min, max, num, logscale, @zero)
      left_tick_labels = []
      longest_label = ''
      ax.ticks.each do |tick|
         label = sprintf(fmt, tick/scale)
         left_tick_labels << label
         longest_label = label if label.length > longest_label.length
      end
      wmax, h = _get_size(longest_label)
      if wmax > 0
         left_axis_tick_x = axis_x0 + wmax/2
         axis_x0 += wmax + padding
      end
      left_tick_half = 0
      axmax = (logscale) ? Math.log10(ax.max) : ax.max
      if (ax.ticks.last - axmax).abs < @zero
         w, h = _get_size(left_tick_labels.last)
         left_tick_half = h/2
      end

      #
      # Top axis: move axis_x1 in from plot edge
      #
      tobj = pobj['title']
      deftobj = defpobj['title']
      text = _get_value('text', tobj, deftobj)
      if text.length > 0
         w,h = _get_size(text)
         axis_y1 -= h
         plot_title_y = axis_y1
         axis_y1 -= padding
      end
      ax = axes[2]
      top_tick_labels = []
      if ax.used
         aobj = pobj['xaxis2']
         defaobj = defpobj['xaxis2']
         logscale = _get_value('logscale', aobj, defaobj) 
         tobj = aobj['title']
         deftobj = defaobj['title']
         text = _get_value('text', tobj, deftobj)
         if text.length > 0
            w,h = _get_size(text)
            axis_y1 -= h
            top_axis_title_y = axis_y1
            axis_y1 -= padding
         end
         tobj = aobj['ticks']
         deftobj = defaobj['ticks']
         min = _get_value('min', tobj, deftobj)
         max = _get_value('max', tobj, deftobj)
         num = _get_int_value('number', tobj, deftobj)
         fmt = (logscale) ? LOGSCALE_TICK_FORMAT : _get_value('format', tobj, deftobj)
         scale = _get_float_value('scale', tobj, deftobj)
         ax.set_ticks(min, max, num, logscale, @zero)
         ax.ticks.each do |tick|
            label = sprintf(fmt, tick/scale)
            top_tick_labels << label
         end
         w, h = _get_size(top_tick_labels.last)  # assume all same height
         if h > 0
            axis_y1 -= h
            top_axis_tick_y = axis_y1
            axis_y1 -= padding
         end
      end
      axis_y1 -= left_tick_half if axis_y1 == orig_y + height

      #
      # Right axis: move axis_x1 in from plot edge
      #
      ax = axes[3]
      right_tick_labels = []
      if ax.used
         aobj = pobj['yaxis2']
         defaobj = defpobj['yaxis2']
         logscale = _get_value('logscale', aobj, defaobj) 
         tobj = aobj['title']
         deftobj = defaobj['title']
         text = _get_value('text', tobj, deftobj)
         if text.length > 0
            w,h = _get_size(text)
            axis_x1 -= h
            right_axis_title_x = axis_x1
            axis_x1 -= padding
         end
         tobj = aobj['ticks']
         deftobj = defaobj['ticks']
         min = _get_value('min', tobj, deftobj)
         max = _get_value('max', tobj, deftobj)
         num = _get_int_value('number', tobj, deftobj)
         fmt = (logscale) ? LOGSCALE_TICK_FORMAT : _get_value('format', tobj, deftobj)
         scale = _get_float_value('scale', tobj, deftobj)
         ax.set_ticks(min, max, num, logscale, @zero)
         longest_label = ''
         ax.ticks.each do |tick|
            label = sprintf(fmt, tick/scale)
            right_tick_labels << label
            longest_label = label if label.length > longest_label.length
         end
         w, h = _get_size(longest_label)
         if w > 0
            axis_x1 -= w
            right_axis_tick_x = axis_x1
            axis_x1 -= padding
         end
      end
      axis_x1 -= bottom_tick_half if axis_x1 == orig_x + width 


      # 
      # Axis box
      # 
      axis_width = axis_x1 - axis_x0
      axis_height = axis_y1 - axis_y0
      bgcolor = _get_value('bgcolor', pobj, defpobj)
      @latex_str << "\\psframe[fillcolor=#{bgcolor},fillstyle=solid]"
      @latex_str << "(#{axis_x0},#{axis_y0})(#{axis_x1},#{axis_y1})\n"
      linewidth = @data['default']['line']['width'].to_i

      # 
      # Bottom axis: ticks, labels, title 
      # 
      ax = axes[0]
      aobj = pobj['xaxis']
      defaobj = defpobj['xaxis']
      logscale = _get_value('logscale', aobj, defaobj) 
      tobj = aobj['ticks']
      deftobj = defaobj['ticks']
      ticklen = _get_int_value('length', tobj, deftobj)
      clow = axis_x0
      chigh = axis_x1
      vmin = ax.min
      vmax = ax.max
      if logscale
         vmin = Math.log10(vmin)
         vmax = Math.log10(vmax)
      end
      y1 = axis_y0 + ticklen
      reset_line = false
      echo_bottom_ticks = false
      gobj = pobj['xgrid']
      defgobj = defpobj['xgrid']
      if _get_value('show', gobj, defgobj)
         y1 = axis_y1
         _set_line(gobj, defgobj)
         reset_line = true
      elsif !axes[2].used
         echo_bottom_ticks = true
      end
      tobj = aobj['title']
      deftobj = defaobj['title']
      color = _get_value('color', tobj, deftobj)
      ax.ticks.each_with_index do |tv,i|
         x = _trans(tv, vmin, vmax, clow, chigh)
         if (x-axis_x0).abs > linewidth && (x-axis_x1).abs > linewidth
            @latex_str << "\\psline(#{x},#{axis_y0})(#{x},#{y1})\n"
            if echo_bottom_ticks
               @latex_str << "\\psline(#{x},#{axis_y1})(#{x},#{axis_y1-ticklen})\n"
            end
         end
         _add_text(bottom_tick_labels[i], x, bottom_axis_tick_y, 0.0, color,'b')
      end
      _reset_line if reset_line
      text = _get_value('text', tobj, deftobj)
      if text.length > 0
         _add_text(text, axis_x0+axis_width/2, bottom_axis_title_y, 0.0,
                   color, 'b')
      end

      @xkey = axis_x0 + ticklen + padding
      @ykey = axis_y1 - ticklen - padding

      # 
      # Left axis: ticks, labels, title 
      # 
      ax = axes[1]
      aobj = pobj['yaxis']
      defaobj = defpobj['yaxis']
      logscale = _get_value('logscale', aobj, defaobj) 
      tobj = aobj['ticks']
      deftobj = defaobj['ticks']
      ticklen = _get_int_value('length', tobj, deftobj)
      clow = axis_y0
      chigh = axis_y1
      vmin = ax.min
      vmax = ax.max
      if logscale
         vmin = Math.log10(vmin)
         vmax = Math.log10(vmax)
      end
      x1 = axis_x0 + ticklen
      @xkey = x1 + padding
      reset_line = false
      echo_left_ticks = false
      gobj = pobj['ygrid']
      defgobj = defpobj['ygrid']
      if _get_value('show', gobj, defgobj)
         x1 = axis_x1
         _set_line(gobj, defgobj)
         reset_line = true
      elsif !axes[3].used
         echo_left_ticks = true
      end
      tobj = aobj['title']
      deftobj = defaobj['title']
      color = _get_value('color', tobj, deftobj)
      ax.ticks.each_with_index do |tv,i|
         y = _trans(tv, vmin, vmax, clow, chigh)
         if (y-axis_y0).abs > linewidth && (y-axis_y1).abs > linewidth
            @latex_str << "\\psline(#{axis_x0},#{y})(#{x1},#{y})\n"
            if echo_left_ticks
               @latex_str << "\\psline(#{axis_x1},#{y})(#{axis_x1-ticklen},#{y})\n"
            end
         end
         _add_text(left_tick_labels[i], left_axis_tick_x, y, 0.0, color)
      end
      _reset_line if reset_line
      text = _get_value('text', tobj, deftobj)
      if text.length > 0
         _add_text(text, left_axis_title_x, axis_y0+axis_height/2, 90.0,
                   color, 'b')
      end

      # 
      # Top axis: ticks, labels, title, plot title
      # 
      tobj = pobj['title']
      deftobj = defpobj['title']
      text = _get_value('text', tobj, deftobj)
      color = _get_value('color', tobj, deftobj)
      if text.length > 0
         _add_text(text, axis_x0+axis_width/2, plot_title_y, 0.0, color, 'b')
      end
      ax = axes[2]
      if ax.used
         aobj = pobj['xaxis2']
         defaobj = defpobj['xaxis2']
         logscale = _get_value('logscale', aobj, defaobj) 
         tobj = aobj['ticks']
         deftobj = defaobj['ticks']
         ticklen = _get_int_value('length', tobj, deftobj)
         tobj = aobj['title']
         deftobj = defaobj['title']
         color = _get_value('color', tobj, deftobj)
         clow = axis_x0
         chigh = axis_x1
         vmin = ax.min
         vmax = ax.max
         if logscale
            vmin = Math.log10(vmin)
            vmax = Math.log10(vmax)
         end
         y1 = axis_y1 - ticklen
         ax.ticks.each_with_index do |tv,i|
            x = _trans(tv, vmin, vmax, clow, chigh)
            if (x-axis_x0).abs > linewidth && (x-axis_x1).abs > linewidth
               @latex_str << "\\psline(#{x},#{axis_y1})(#{x},#{y1})\n"
            end
            _add_text(top_tick_labels[i], x, top_axis_tick_y, 0.0, color, 'b')
         end
         text = _get_value('text', tobj, deftobj)
         if text.length > 0
            _add_text(text, axis_x0+axis_width/2,top_axis_title_y,0.0,color,'b')
         end
      end

      #
      # Right axis: ticks, labels, title
      #
      ax = axes[3]
      if ax.used
         aobj = pobj['yaxis2']
         defaobj = defpobj['yaxis2']
         logscale = _get_value('logscale', aobj, defaobj) 
         tobj = aobj['ticks']
         deftobj = defaobj['ticks']
         ticklen = _get_int_value('length', tobj, deftobj)
         tobj = aobj['title']
         deftobj = defaobj['title']
         color = _get_value('color', tobj, deftobj)
         clow = axis_y0
         chigh = axis_y1
         vmin = ax.min
         vmax = ax.max
         if logscale
            vmin = Math.log10(vmin)
            vmax = Math.log10(vmax)
         end
         x1 = axis_x1 - ticklen
         ax.ticks.each_with_index do |tv,i|
            y = _trans(tv, vmin, vmax, clow, chigh)
            if (y-axis_y0).abs > linewidth && (y-axis_y1).abs > linewidth
               @latex_str << "\\psline(#{axis_x1},#{y})(#{x1},#{y})\n"
            end
            _add_text(right_tick_labels[i], right_axis_tick_x, y, 0.0,color,'l')
         end
         text = _get_value('text', tobj, deftobj)
         if text.length > 0
            _add_text(text, right_axis_title_x, axis_y0+axis_height/2, -90.0,
                      color, 'b')
         end
      end

      #
      # Plot elements 
      #
      ax = axes[0]
      xmin = ax.min
      xmax = ax.max
      aobj = pobj['xaxis']
      defaobj = defpobj['xaxis']
      xlogscale = _get_value('logscale', aobj, defaobj) 
      ax = axes[1]
      ymin = ax.min
      ymax = ax.max
      aobj = pobj['yaxis']
      defaobj = defpobj['yaxis']
      ylogscale = _get_value('logscale', aobj, defaobj) 
      ax = axes[2]
      xmin2 = ax.min
      xmax2 = ax.max
      aobj = pobj['xaxis2']
      defaobj = defpobj['xaxis2']
      xlogscale2 = _get_value('logscale', aobj, defaobj) 
      ax = axes[3]
      ymin2 = ax.min
      ymax2 = ax.max
      aobj = pobj['yaxis2']
      defaobj = defpobj['yaxis2']
      ylogscale2 = _get_value('logscale', aobj, defaobj) 

      kobj = pobj['key']
      defkobj = defpobj['key']
      show_key = _get_value('show', kobj, defkobj)
      key_line_len = _get_int_value('line_len', kobj, defkobj)
      text = _get_value('position', kobj, defkobj)
      if text.length > 0
         pos = text.split(',')
         vmin = xmin
         vmax = xmax
         if xlogscale
            vmin = Math.log10(vmin)
            vmax = Math.log10(vmax)
            pos[0] = Math.log10(pos[0].to_f)
         end
         @xkey = _trans(pos[0].to_f, vmin, vmax, axis_x0, axis_x1)
         vmin = ymin
         vmax = ymax
         if ylogscale
            vmin = Math.log10(vmin)
            vmax = Math.log10(vmax)
            pos[1] = Math.log10(pos[1].to_f)
         end
         @ykey = _trans(pos[1].to_f, vmin, vmax, axis_y0, axis_y1)
      end

      boxes = _get_value('boxes', pobj, defpobj)
      boxes.each do |bkey|
         bobj = pobj[bkey]
         raise RuntimeError, "Missing box #{bkey}" unless bobj
         _add_box(bobj, xmin, ymin, xmax, ymax, axis_x0,axis_y0,axis_x1,axis_y1)
      end

      circles = _get_value('circles', pobj, defpobj)
      circles.each do |ckey|
         cobj = pobj[ckey]
         raise RuntimeError, "Missing circle #{ckey}" unless cobj
         _add_circle(cobj, xmin, ymin,xmax,ymax,axis_x0,axis_y0,axis_x1,axis_y1)
      end

      arrows = _get_value('arrows', pobj, defpobj)
      arrows.each do |akey|
         aobj = pobj[akey]
         raise RuntimeError, "Missing arrow #{akey}" unless aobj
        _add_arrow(aobj, xmin, ymin, xmax, ymax,axis_x0,axis_y0,axis_x1,axis_y1)
      end

      labels = _get_value('labels', pobj, defpobj)
      labels.each do |lkey|
         lobj = pobj[lkey]
         raise RuntimeError, "Missing label #{lkey}" unless lobj
         _add_label(lobj, xmin, ymin, xmax,ymax,axis_x0,axis_y0,axis_x1,axis_y1,
                    xlogscale, ylogscale)
      end

      curves = _get_value('curves', pobj, defpobj)
      curves.each_with_index do |ckey,i|
         cobj = pobj[ckey]
         raise RuntimeError, "Missing curve #{ckey}" unless cobj
         dckey = "curve#{i+1}"
         defcobj = _def_curve(dckey)  # defpobj = @data['default']['plot']
         raise RuntimeError, "Missing default curve #{dckey}" unless defcobj
         if _get_value('xaxis2', cobj, defcobj)
            x0 = xmin2
            x1 = xmax2
            xls = xlogscale2
         else
            x0 = xmin
            x1 = xmax
            xls = xlogscale
         end
         if _get_value('yaxis2', cobj, defcobj)
            y0 = ymin2
            y1 = ymax2
            yls = ylogscale2
         else
            y0 = ymin
            y1 = ymax
            yls = ylogscale
         end
         _add_curve(cobj, defcobj, x0, x1, y0, y1, axis_x0, axis_x1, axis_y0, 
                    axis_y1, show_key, key_line_len, padding, xls, yls)
      end
   end  # _add_plot()

   public

   attr_reader :tmpfile

   # Write new Postscript file to psfile, generated from json_str
   def convert(json_str, default_json_str, psfile)
      @data = JSON.parse(json_str)
      default = JSON.parse(default_json_str)
      # Allow defaults in json_str to override default_json_str
      default.merge(@data['default']) if @data.has_key?('default')
      @data['default'] = default

      @zero = _get_float_value('zero', @data, @data['default'])

      @latex_str = _latex_header(@data, @data['default'])
      @latex_str << "\\nonstopmode\n"

      rgb = @data['default']['rgb']
      rgb.each {|k,v| @latex_str << "\\newrgbcolor{#{k}}{#{v}}\n"}
      if rgb = @data['rgb']
         rgb.each {|k,v| @latex_str << "\\newrgbcolor{#{k}}{#{v}}\n"}
      end

      @latex_str << "\\#{_get_value('font_family', @data, @data['default'])}\n"
      _reset_line
      @latex_str << "\\psset{fillstyle=none}\n"

      fig_width = _get_int_value('width', @data, @data['default'])
      fig_height = _get_int_value('height', @data, @data['default'])

      if _get_value('show_bbox', @data, @data['default'])
         opts = 'linewidth=0.5,linecolor=lightgray'
         @latex_str << "\\psframe[#{opts}](0,0)(#{fig_width},#{fig_height})\n"
      end
      @latex_str << "\\pspicture*(0,0)(#{fig_width},#{fig_height})\n"

      layout = _get_value('layout', @data, @data['default']) 
      case layout
         when '1'
            plot_width = fig_width
            plot_height = fig_height
            plot_origin = [[0,0]]
         when '2h'
            plot_width = fig_width/2
            plot_height = fig_height
            plot_origin = [[0,0], [plot_width,0]]
         when '2v'
            plot_width = fig_width
            plot_height = fig_height/2
            plot_origin = [[0,plot_height], [0,0]]
         when '4'
            plot_width = fig_width/2
            plot_height = fig_height/2
            plot_origin = [[0,plot_height], [plot_width,plot_height], 
                           [0,0], [plot_width,0]]
         # XXX more layout options 
         else
            raise RuntimeError, "Unknown figure layout: #{layout}"
      end

      plots = _get_value('plots', @data, @data['default'])
      plots.each_with_index do |pkey,i|
         pobj = @data[pkey]
         defpobj = @data['default']['plot']
         w = plot_width
         h = plot_height
         orig = plot_origin[i]
         if _get_value('inset', pobj, defpobj)
            w = _get_int_value('width', pobj, defpobj)
            raise RuntimeError, "Missing width for inset plot #{pkey}" unless w
            h = _get_int_value('height', pobj, defpobj)
            raise RuntimeError, "Missing height for inset plot #{pkey}" unless h
            v = _get_value('origin', pobj, defpobj)
            raise RuntimeError, "Missing origin for inset plot #{pkey}" unless v
            msg = "Expecting origin format 'x,y', not #{v}" 
            raise RuntimeError, msg unless v.include?(',')
            orig = v.split(',')
         end
         _add_plot(pobj, defpobj, orig[0].to_i, orig[1].to_i, w, h)
      end
      @latex_str << "\\endpspicture\n"
      @latex_str << "\\end{document}"

      texpath = "#{@tmpfile}.tex"
      File.open(texpath, 'w') {|f| f.write(@latex_str)}
      latex_stat = CHIFIG.exec_wait("#{@latex_cmd} #{texpath}")
      raise RuntimeError, "#{@latex_cmd} failed" unless latex_stat
      dvips_stat = CHIFIG.exec_wait("#{@dvips_cmd} -E #{@tmpfile} -o #{psfile}")
      raise RuntimeError, "#{@dvips_cmd} failed" unless dvips_stat 

      unless $debug
         ['aux', 'dvi', 'log', 'tex'].each do |ext|
            path = "#{@tmpfile}.#{ext}"
            File.delete(path) if File.exists?(path)
         end
      end
   end  # convert()

end  # PSGen

end  # CHIFIG

