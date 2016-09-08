if RUBY_ENGINE_JRUBY
  class String
    # Safely truncate the string to the specified number of bytes.
    # If a multibyte char gets split, the dangling fragment is removed.
    def limit size
      return self unless size < bytesize
      result = (unpack %(a#{size}))[0]
      begin
        result.unpack 'U*'
      rescue ArgumentError
        result.chop!
        retry
      end
      result
    end unless method_defined? :limit
  end
else
  class String
    # Safely truncate the string to the specified number of bytes.
    # If a multibyte char gets split, the dangling fragment is removed.
    def limit size
      return self unless size < bytesize
      result = (unpack %(a#{size}))[0]
      result.chop! until result.empty? || /.$/u =~ result
      result
    end unless method_defined? :limit
  end
end
