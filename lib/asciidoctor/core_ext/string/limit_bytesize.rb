class String
  # Safely truncate the string to the specified number of bytes.
  # If a multibyte char gets split, the dangling fragment is dropped.
  def limit_bytesize size
    return self unless size < bytesize
    size -= 1 until (result = byteslice 0, size).valid_encoding?
    result
  end
end unless String.method_defined? :limit_bytesize
