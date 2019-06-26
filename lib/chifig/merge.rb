# =============================================================================
# merge.rb -- Monkey patch for merging Hashes
#
# Copyright
#
# LICENSE
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
