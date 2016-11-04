class String
  # Safely truncate the string to the specified number of bytes.
  # If a multibyte char gets split, the dangling fragment is removed.
  def limit_bytesize size
    return self unless size < bytesize
    # NOTE JRuby 1.7 & Rubinius fail to detect invalid encoding unless encoding is forced; impact is marginal.
    size -= 1 until ((result = byteslice 0, size).force_encoding ::Encoding::UTF_8).valid_encoding?
    result
  end unless method_defined? :limit_bytesize
end
