# Safely truncate the string to the specified number of bytes.
# If a multibyte char gets split, the remaining fragment is removed.
if RUBY_MIN_VERSION_1_9
  class String
    # NOTE JRuby 1.7 & Rubinius fail to detect invalid encoding unless encoding is forced; impact is marginal.
    def limit size
      return self unless size < bytesize
      size -= 1 until ((result = byteslice 0, size).force_encoding ::Encoding::UTF_8).valid_encoding?
      result
    end unless method_defined? :limit
  end
elsif RUBY_ENGINE_JRUBY
  class String
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
    def limit size
      return self unless size < bytesize
      result = (unpack %(a#{size}))[0]
      result.chop! until result.empty? || /.$/u =~ result
      result
    end unless method_defined? :limit
  end
end
