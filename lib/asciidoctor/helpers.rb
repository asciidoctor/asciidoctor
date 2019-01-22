module Asciidoctor
# Internal: Except where noted, a module that contains internal helper functions.
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

  # Internal: Prepare the source data Array for parsing.
  #
  # Encodes the data to UTF-8, if necessary, and removes any trailing
  # whitespace from every line.
  #
  # If a BOM is found at the beginning of the data, a best attempt is made to
  # encode it to UTF-8 from the specified source encoding.
  #
  # data - the source data Array to prepare (no nil entries allowed)
  #
  # returns a String Array of prepared lines
  def self.prepare_source_array data
    return [] if data.empty?
    if (leading_2_bytes = (leading_bytes = (first = data[0]).unpack 'C3').slice 0, 2) == BOM_BYTES_UTF_16LE
      data[0] = first.byteslice 2, first.bytesize
      # NOTE you can't split a UTF-16LE string using .lines when encoding is UTF-8; doing so will cause this line to fail
      return data.map {|line| (line.encode UTF_8, ::Encoding::UTF_16LE).rstrip }
    elsif leading_2_bytes == BOM_BYTES_UTF_16BE
      data[0] = first.byteslice 2, first.bytesize
      return data.map {|line| (line.encode UTF_8, ::Encoding::UTF_16BE).rstrip }
    elsif leading_bytes == BOM_BYTES_UTF_8
      data[0] = first.byteslice 3, first.bytesize
    end
    if first.encoding == UTF_8
      data.map {|line| line.rstrip }
    else
      data.map {|line| (line.encode UTF_8).rstrip }
    end
  end

  # Internal: Prepare the source data String for parsing.
  #
  # Encodes the data to UTF-8, if necessary, splits it into an array, and
  # removes any trailing whitespace from every line.
  #
  # If a BOM is found at the beginning of the data, a best attempt is made to
  # encode it to UTF-8 from the specified source encoding.
  #
  # data - the source data String to prepare
  #
  # returns a String Array of prepared lines
  def self.prepare_source_string data
    return [] if data.nil_or_empty?
    if (leading_2_bytes = (leading_bytes = data.unpack 'C3').slice 0, 2) == BOM_BYTES_UTF_16LE
      data = (data.byteslice 2, data.bytesize).encode UTF_8, ::Encoding::UTF_16LE
    elsif leading_2_bytes == BOM_BYTES_UTF_16BE
      data = (data.byteslice 2, data.bytesize).encode UTF_8, ::Encoding::UTF_16BE
    elsif leading_bytes == BOM_BYTES_UTF_8
      data = data.byteslice 3, data.bytesize
      data = data.encode UTF_8 unless data.encoding == UTF_8
    elsif data.encoding != UTF_8
      data = data.encode UTF_8
    end
    data.lines.map {|line| line.rstrip }
  end

  # Public: Safely truncates a string to the specified number of bytes.
  #
  # If a multibyte char gets split, the dangling fragment is dropped.
  #
  # str - The String the truncate.
  # max - The maximum allowable size of the String, in bytes.
  #
  # Returns the String truncated to the specified bytesize.
  def self.limit_bytesize str, max
    if str.bytesize > max
      max -= 1 until (str = str.byteslice 0, max).valid_encoding?
    end
    str
  end

  # Internal: Efficiently checks whether the specified String resembles a URI
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

  # Internal: Efficiently retrieves the URI prefix of the specified String
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
  UriEncodeCharsRx = /[^\w\-.!~*';:@=+$,()\[\]]/

  # Internal: Encode a String for inclusion in a URI.
  #
  # str - the String to URI encode
  #
  # Returns the String with all URI reserved characters encoded.
  def self.uri_encode str
    str.gsub(UriEncodeCharsRx) { $&.each_byte.map {|c| sprintf '%%%02X', c }.join }
  end

  # Public: Removes the file extension from filename and returns the result
  #
  # filename - The String file name to process
  #
  # Examples
  #
  #   Helpers.rootname 'part1/chapter1.adoc'
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
  #   Helpers.basename 'images/tiger.png', true
  #   # => "tiger"
  #
  #   Helpers.basename 'images/tiger.png', '.png'
  #   # => "tiger"
  #
  # Returns the String filename with leading directories removed and, if specified, the extension removed
  def self.basename filename, drop_ext = nil
    if drop_ext
      ::File.basename filename, (drop_ext == true ? (::File.extname filename) : drop_ext)
    else
      ::File.basename filename
    end
  end

  # Internal: Make a directory, ensuring all parent directories exist.
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

  # Internal: Converts an integer to a Roman numeral.
  #
  # val - the [Integer] value to convert
  #
  # Returns the [String] roman numeral for this integer
  def self.int_to_roman val
    ROMAN_NUMERALS.map do |l, i|
      repeat, val = val.divmod i
      l * repeat
    end.join
  end

  # Internal: Get the next value in the sequence.
  #
  # Handles both integer and character sequences.
  #
  # current - the value to increment as a String or Integer
  #
  # returns the next value in the sequence according to the current value's type
  def self.nextval current
    if ::Integer === current
      current + 1
    else
      intval = current.to_i
      if intval.to_s != current.to_s
        (current[0].ord + 1).chr
      else
        intval + 1
      end
    end
  end

  # Internal: Resolve the specified object as a Class
  #
  # object - The Object to resolve as a Class
  #
  # Returns a Class if the specified object is a Class (but not a Module) or
  # a String that resolves to a Class; otherwise, nil
  def self.resolve_class object
    ::Class === object ? object : (::String === object ? (class_for_name object) : nil)
  end

  # Internal: Resolves a Class object (not a Module) for the qualified name.
  #
  # Returns Class
  def self.class_for_name qualified_name
    raise unless ::Class === (resolved = ::Object.const_get qualified_name, false)
    resolved
  rescue
    raise ::NameError, %(Could not resolve class for name: #{qualified_name})
  end
end
end
