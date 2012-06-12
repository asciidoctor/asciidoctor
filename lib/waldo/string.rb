unless String.instance_methods.include? 'underscore'
  class String
    # Yes, oh Rails, I stealz you so bad
    def underscore
       self.gsub(/::/, '/').
            gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
            gsub(/([a-z\d])([A-Z])/,'\1_\2').
            tr("-", "_").
            downcase
    end
  end
end