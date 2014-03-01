module Asciidoctor
module Helpers
  # Internal: Require the specified library using Kernel#require.
  #
  # Attempts to load the library specified in the first argument using the
  # Kernel#require. Rescues the LoadError if the library is not available and
  # passes a message to Kernel#fail to communicate to the user that processing
  # is being aborted. If a gem_name is specified, the failure message
  # communicates that a required gem is not installed.
  #
  # name  - the String name of the library to require.
  # gem   - a Boolean that indicates whether this library is provided by a RubyGem,
  #         or the String name of the RubyGem if it differs from the library name
  #         (default: true)
  #
  # returns the return value of Kernel#require if the library is available,
  # otherwise Kernel#fail is called with an appropriate message.
  def self.require_library name, gem = true
    require name
  rescue ::LoadError => e
    if gem
      fail %(asciidoctor: FAILED: required gem '#{gem == true ? name : gem}' is not installed. Processing aborted.)
    else
      fail %(asciidoctor: FAILED: #{e.message.chomp '.'}. Processing aborted.)
    end
  end

  # Public: Normalize the data to prepare for parsing
  #
  # Delegates to Helpers#normalize_lines_from_string if data is a String.
  # Delegates to Helpers#normalize_lines_array if data is a String Array.
  #
  # returns a String Array of normalized lines
  def self.normalize_lines data
    data.class == ::String ? (normalize_lines_from_string data) : (normalize_lines_array data)
  end

  # Public: Normalize the array of lines to prepare them for parsing
  #
  # Force encodes the data to UTF-8 and removes trailing whitespace from each line.
  #
  # If a BOM is present at the beginning of the data, a best attempt
  # is made to encode from the specified encoding to UTF-8.
  #
  # data - a String Array of lines to normalize
  #
  # returns a String Array of normalized lines
  def self.normalize_lines_array data
    return [] if data.empty?
 
    # NOTE if data encoding is UTF-*, we only need 0..1
    leading_bytes = (first_line = data[0])[0..2].bytes.to_a
    if COERCE_ENCODING
      utf8 = ::Encoding::UTF_8
      if (leading_2_bytes = leading_bytes[0..1]) == BOM_BYTES_UTF_16LE
        # Ruby messes up trailing whitespace on UTF-16LE, so take a different route
        return ((data.join.force_encoding ::Encoding::UTF_16LE)[1..-1].encode utf8).lines.map {|line| line.rstrip }
      elsif leading_2_bytes == BOM_BYTES_UTF_16BE
        data[0] = (first_line.force_encoding ::Encoding::UTF_16BE)[1..-1]
        return data.map {|line| "#{((line.force_encoding ::Encoding::UTF_16BE).encode utf8).rstrip}" }
      elsif leading_bytes[0..2] == BOM_BYTES_UTF_8
        data[0] = (first_line.force_encoding utf8)[1..-1]
      end

      data.map {|line| line.encoding == utf8 ? line.rstrip : (line.force_encoding utf8).rstrip }
    else
      # Ruby 1.8 has no built-in re-encoding, so no point in removing the UTF-16 BOMs
      if leading_bytes == BOM_BYTES_UTF_8
        data[0] = first_line[3..-1]
      end
      data.map {|line| line.rstrip }
    end
  end

  # Public: Normalize the String and split into lines to prepare them for parsing
  #
  # Force encodes the data to UTF-8 and removes trailing whitespace from each line.
  # Converts the data to a String Array.
  #
  # If a BOM is present at the beginning of the data, a best attempt
  # is made to encode from the specified encoding to UTF-8.
  #
  # data - a String of lines to normalize
  #
  # returns a String Array of normalized lines
  def self.normalize_lines_from_string data 
    return [] if data.nil_or_empty?

    if COERCE_ENCODING
      utf8 = ::Encoding::UTF_8
      # NOTE if data encoding is UTF-*, we only need 0..1
      leading_bytes = data[0..2].bytes.to_a
      if (leading_2_bytes = leading_bytes[0..1]) == BOM_BYTES_UTF_16LE
        data = (data.force_encoding ::Encoding::UTF_16LE)[1..-1].encode utf8
      elsif leading_2_bytes == BOM_BYTES_UTF_16BE
        data = (data.force_encoding ::Encoding::UTF_16BE)[1..-1].encode utf8
      elsif leading_bytes[0..2] == BOM_BYTES_UTF_8
        data = data.encoding == utf8 ? data[1..-1] : (data.force_encoding utf8)[1..-1]
      else
        data = data.force_encoding utf8 unless data.encoding == utf8
      end
    else
      # Ruby 1.8 has no built-in re-encoding, so no point in removing the UTF-16 BOMs
      if data[0..2].bytes.to_a == BOM_BYTES_UTF_8
        data = data[3..-1]
      end
    end
    data.each_line.map {|line| line.rstrip }
  end

  # Matches the characters in a URI to encode
  REGEXP_ENCODE_URI_CHARS = /[^\w\-.!~*';:@=+$,()\[\]]/

  # Public: Encode a string for inclusion in a URI
  #
  # str - the string to encode
  #
  # returns an encoded version of the str
  def self.encode_uri(str)
    str.gsub(REGEXP_ENCODE_URI_CHARS) do
      $&.each_byte.map {|c| sprintf '%%%02X', c}.join
    end
  end

  # Public: Removes the file extension from filename and returns the result
  #
  # file_name - The String file name to process
  #
  # Examples
  #
  #   Helpers.rootname('part1/chapter1.adoc')
  #   # => "part1/chapter1"
  #
  # Returns the String filename with the file extension removed
  def self.rootname(file_name)
    # alternatively, this could be written as ::File.basename file_name, ((::File.extname file_name) || '')
    (ext = ::File.extname(file_name)).empty? ? file_name : file_name[0...-ext.length]
  end

  def self.mkdir_p(dir)
    unless ::File.directory? dir
      parent_dir = ::File.dirname(dir)
      if !::File.directory?(parent_dir = ::File.dirname(dir)) && parent_dir != '.'
        mkdir_p(parent_dir)
      end
      ::Dir.mkdir(dir)
    end
  end
end
end
