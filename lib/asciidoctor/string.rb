# Public: String monkeypatching
class String
  # Public: Makes an underscored, lowercase form from the expression in the string.
  #
  # Changes '::' to '/' to convert namespaces to paths.
  # Changes camelcase words to underscore delimited and lowercase words
  #
  # (Yes, oh Rails, I stealz you so bad)
  #
  # Examples
  #
  #  "ActiveRecord".underscore
  #  # => "active_record"
  #
  #  "ActiveRecord::Errors".underscore
  #  # => active_record/errors
  #
  # Returns A copy of this String with the underscore rules applied
  def underscore
     self.gsub('::', '/').
          gsub(/([[:upper:]]+)([[:upper:]][[:alpha:]])/, '\1_\2').
          gsub(/([[:lower:][:digit:]])([[:upper:]])/, '\1_\2').
          tr('-', '_').
          downcase
  end unless method_defined?(:underscore)

  # Public: Return a copy of this string with the specified character removed
  # from the beginning and the end of the original string.
  #
  # The character will be removed until it is no longer found in the first or
  # last character position of the String.
  #
  # char - The single-character String to remove
  #
  # Returns A copy of this String with the specified character removed from the
  # beginning and end of the original string
  def trim(char)
    self.rtrim(char).ltrim(char)
  end

  # Public: Return a copy of this string with the specified character removed
  # from the beginning of the original string
  #
  # The character will be removed until it is no longer found in the first
  # character position of the String.
  #
  # char - The single-character String to remove
  #
  # Returns A copy of this String with the specified character removed from the
  # beginning of the original string
  def ltrim(char)
    # optimization
    return self.dup if self[0..0] != char

    result = self.dup
    result = result[1..-1] while result[0..0] == char
    result
  end

  # Public: Return a copy of this string with the specified character removed
  # from the end of the original string
  #
  # The character will be removed until it is no longer found in the last
  # character position of the String.
  #
  # char  - The single-character String to remove
  #
  # Returns A copy of this String with the specified character removed from the
  # end of the original string
  def rtrim(char)
    # optimization
    return self.dup if self[-1..-1] != char

    result = self.dup
    result = result[0..-2] while result[-1..-1] == char
    result
  end

  # Public: Return a copy of this String with the first occurrence of the characters that match the specified pattern removed
  #
  # A convenience method for sub(pattern, '')
  #
  # pattern - The Regexp matching characters to remove
  #
  # Returns A copy of this String with the first occurrence of the match characters removed
  def nuke(pattern)
    self.sub(pattern, '')  
  end

  # Public: Return a copy of this String with all the occurrences of the characters that match the specified pattern removed
  #
  # A convenience method for gsub(pattern, '')
  #
  # pattern - The Regexp matching characters to remove
  #
  # Returns A copy of this String with all occurrences of the match characters removed
  def gnuke(pattern)
    self.gsub(pattern, '')  
  end
end
