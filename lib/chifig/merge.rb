# =============================================================================
# merge.rb -- Monkey patch for merging Hashes
#
# Copyright (c) 2019-2020 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

class Hash
   # Recursively merge h into self; values in h overwrite values in self
   def merge(h)
      h.each do |k,v|
         if self.has_key?(k)
            _v = self[k]
            if v.respond_to?(:merge) && _v.respond_to?(:merge)
               _v.merge(v)  # recurse
            else
               self[k] = v  # replace
            end
         else
            self[k] = v  # new entry
         end
      end
   end
end 
