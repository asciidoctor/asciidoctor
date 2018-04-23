# encoding: UTF-8
module Asciidoctor
module Helpers
  # Internal: Require the specified library using Kernel#require.
  #
  # Attempts to load the library specified in the first argument using the
  # Kernel#require. Rescues the LoadError if the library is not available and
  # passes a message to Kernel#raise if on_failure is :abort or Kernel#warn if
  # on_failure is :warn to communicate to the user that processing is being
  # aborted or functionality is disabled, respectively. If a gem_name is
  # specified, the message communicates that a required gem is not installed.
  #
  # name       - the String name of the library to require.
  # gem_name   - a Boolean that indicates whether this library is provided by a RubyGem,
  #              or the String name of the RubyGem if it differs from the library name
  #              (default: true)
  # on_failure - a Symbol that indicates how to handle a load failure (:abort, :warn, :ignore) (default: :abort)
  #
  # Returns The [Boolean] return value of Kernel#require if the library can be loaded.
  # Otherwise, if on_failure is :abort, Kernel#raise is called with an appropriate message.
  # Otherwise, if on_failure is :warn, Kernel#warn is called with an appropriate message and nil returned.
  # Otherwise, nil is returned.
  def self.require_library name, gem_name = true, on_failure = :abort
    require name
  rescue ::LoadError => e
    include Logging unless include? Logging
    if gem_name
      gem_name = name if gem_name == true
      case on_failure
      when :abort
        raise ::LoadError, %(asciidoctor: FAILED: required gem '#{gem_name}' is not installed. Processing aborted.)
      when :warn
        logger.warn %(optional gem '#{gem_name}' is not installed. Functionality disabled.)
      end
    else
      case on_failure
      when :abort
        raise ::LoadError, %(asciidoctor: FAILED: #{e.message.chomp '.'}. Processing aborted.)
      when :warn
        logger.warn %(#{e.message.chomp '.'}. Functionality disabled.)
      end
    end
    nil
  end

  # Public: Normalize the data to prepare for parsing
  #
  # Delegates to Helpers#normalize_lines_from_string if data is a String.
  # Delegates to Helpers#normalize_lines_array if data is a String Array.
  #
  # returns a String Array of normalized lines
  def self.normalize_lines data
    ::String === data ? (normalize_lines_from_string data) : (normalize_lines_array data)
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
    return data if data.empty?

    leading_bytes = (first_line = data[0]).unpack 'C3'
    if COERCE_ENCODING
      utf8 = ::Encoding::UTF_8
      if (leading_2_bytes = leading_bytes.slice 0, 2) == BOM_BYTES_UTF_16LE
        # HACK Ruby messes up trailing whitespace on UTF-16LE, so take a different route
        return ((data.join.force_encoding ::Encoding::UTF_16LE)[1..-1].encode utf8).each_line.map {|line| line.rstrip }
      elsif leading_2_bytes == BOM_BYTES_UTF_16BE
        data[0] = (first_line.force_encoding ::Encoding::UTF_16BE)[1..-1]
        return data.map {|line| %(#{((line.force_encoding ::Encoding::UTF_16BE).encode utf8).rstrip}) }
      elsif leading_bytes == BOM_BYTES_UTF_8
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

    leading_bytes = data.unpack 'C3'
    if COERCE_ENCODING
      utf8 = ::Encoding::UTF_8
      if (leading_2_bytes = leading_bytes.slice 0, 2) == BOM_BYTES_UTF_16LE
        data = (data.force_encoding ::Encoding::UTF_16LE)[1..-1].encode utf8
      elsif leading_2_bytes == BOM_BYTES_UTF_16BE
        data = (data.force_encoding ::Encoding::UTF_16BE)[1..-1].encode utf8
      elsif leading_bytes == BOM_BYTES_UTF_8
        data = data.encoding == utf8 ? data[1..-1] : (data.force_encoding utf8)[1..-1]
      else
        data = data.force_encoding utf8 unless data.encoding == utf8
      end
    else
      # Ruby 1.8 has no built-in re-encoding, so no point in removing the UTF-16 BOMs
      if leading_bytes == BOM_BYTES_UTF_8
        data = data[3..-1]
      end
    end
    data.each_line.map {|line| line.rstrip }
  end

  # Public: Efficiently checks whether the specified String resembles a URI
  #
  # Uses the Asciidoctor::UriSniffRx regex to check whether the String begins
  # with a URI prefix (e.g., http://). No validation of the URI is performed.
  #
  # str - the String to check
  #
  # returns true if the String is a URI, false if it is not
  def self.uriish? str
    (str.include? ':') && (UriSniffRx.match? str)
  end

  # Public: Efficiently retrieves the URI prefix of the specified String
  #
  # Uses the Asciidoctor::UriSniffRx regex to match the URI prefix in the
  # specified String (e.g., http://), if present.
  #
  # str - the String to check
  #
  # returns the string URI prefix if the string is a URI, otherwise nil
  def self.uri_prefix str
    (str.include? ':') && UriSniffRx =~ str ? $& : nil
  end

  # Matches the characters in a URI to encode
  REGEXP_ENCODE_URI_CHARS = /[^\w\-.!~*';:@=+$,()\[\]]/

  # Public: Encode a String for inclusion in a URI.
  #
  # str - the String to URI encode
  #
  # Returns the String with all URI reserved characters encoded.
  def self.uri_encode str
    str.gsub(REGEXP_ENCODE_URI_CHARS) { $&.each_byte.map {|c| sprintf '%%%02X', c }.join }
  end

  # Public: Removes the file extension from filename and returns the result
  #
  # filename - The String file name to process
  #
  # Examples
  #
  #   Helpers.rootname('part1/chapter1.adoc')
  #   # => "part1/chapter1"
  #
  # Returns the String filename with the file extension removed
  def self.rootname filename
    filename.slice 0, ((filename.rindex '.') || filename.length)
  end

  # Public: Retrieves the basename of the filename, optionally removing the extension, if present
  #
  # filename - The String file name to process.
  # drop_ext - A Boolean flag indicating whether to drop the extension
  #            or an explicit String extension to drop (default: nil).
  #
  # Examples
  #
  #   Helpers.basename('images/tiger.png', true)
  #   # => "tiger"
  #
  #   Helpers.basename('images/tiger.png', '.png')
  #   # => "tiger"
  #
  # Returns the String filename with leading directories removed and, if specified, the extension removed
  def self.basename(filename, drop_ext = nil)
    if drop_ext
      ::File.basename filename, (drop_ext == true ? (::File.extname filename) : drop_ext)
    else
      ::File.basename filename
    end
  end

  def self.mkdir_p dir
    unless ::File.directory? dir
      unless (parent_dir = ::File.dirname dir) == '.'
        mkdir_p parent_dir
      end
      begin
        ::Dir.mkdir dir
      rescue ::SystemCallError
        raise unless ::File.directory? dir
      end
    end
  end

  ROMAN_NUMERALS = {
    'M' => 1000, 'CM' => 900, 'D' => 500, 'CD' => 400, 'C' => 100, 'XC' => 90,
    'L' => 50, 'XL' => 40, 'X' => 10, 'IX' => 9, 'V' => 5, 'IV' => 4, 'I' => 1
  }

  # Converts an integer to a Roman numeral.
  #
  # val - the [Integer] value to convert
  #
  # Returns the [String] roman numeral for this integer
  def self.int_to_roman val
    ROMAN_NUMERALS.map {|l, i|
      repeat, val = val.divmod i
      l * repeat
    }.join
  end
end
end
