# frozen_string_literal: true
module Asciidoctor
# Internal: Except where noted, a module that contains internal helper functions.
module Helpers
  module_function

  # Public: Require the specified library using Kernel#require.
  #
  # Attempts to load the library specified in the first argument using the
  # Kernel#require. Rescues the LoadError if the library is not available and
  # passes a message to Kernel#raise if on_failure is :abort or Kernel#warn if
  # on_failure is :warn to communicate to the user that processing is being
  # aborted or functionality is disabled, respectively. If a gem_name is
  # specified, the message communicates that a required gem is not available.
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
  def require_library name, gem_name = true, on_failure = :abort
    require name
  rescue ::LoadError
    include Logging unless include? Logging
    if gem_name
      gem_name = name if gem_name == true
      case on_failure
      when :abort
        details = $!.path == gem_name ? '' : %[ (reason: #{$!.path ? %(cannot load '#{$!.path}') : $!.message})]
        raise ::LoadError, %(asciidoctor: FAILED: required gem '#{gem_name}' is not available#{details}. Processing aborted.)
      when :warn
        details = $!.path == gem_name ? '' : %[ (reason: #{$!.path ? %(cannot load '#{$!.path}') : $!.message})]
        logger.warn %(optional gem '#{gem_name}' is not available#{details}. Functionality disabled.)
      end
    else
      case on_failure
      when :abort
        raise ::LoadError, %(asciidoctor: FAILED: #{$!.message.chomp '.'}. Processing aborted.)
      when :warn
        logger.warn %(#{$!.message.chomp '.'}. Functionality disabled.)
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
  # data     - the source data Array to prepare (no nil entries allowed)
  # trim_end - whether to trim whitespace from the end of each line;
  #            (true cleans all whitespace; false only removes trailing newline) (default: true)
  #
  # returns a String Array of prepared lines
  def prepare_source_array data, trim_end = true
    return [] if data.empty?
    if (leading_2_bytes = (leading_bytes = (first = data[0]).unpack 'C3').slice 0, 2) == BOM_BYTES_UTF_16LE
      data[0] = first.byteslice 2, first.bytesize
      # NOTE you can't split a UTF-16LE string using .lines when encoding is UTF-8; doing so will cause this line to fail
      return trim_end ? data.map {|line| (line.encode UTF_8, ::Encoding::UTF_16LE).rstrip } : data.map {|line| (line.encode UTF_8, ::Encoding::UTF_16LE).chomp }
    elsif leading_2_bytes == BOM_BYTES_UTF_16BE
      data[0] = first.byteslice 2, first.bytesize
      return trim_end ? data.map {|line| (line.encode UTF_8, ::Encoding::UTF_16BE).rstrip } : data.map {|line| (line.encode UTF_8, ::Encoding::UTF_16BE).chomp }
    elsif leading_bytes == BOM_BYTES_UTF_8
      data[0] = first.byteslice 3, first.bytesize
    end
    if first.encoding == UTF_8
      trim_end ? data.map {|line| line.rstrip } : data.map {|line| line.chomp }
    else
      trim_end ? data.map {|line| (line.encode UTF_8).rstrip } : data.map {|line| (line.encode UTF_8).chomp }
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
  # data     - the source data String to prepare
  # trim_end - whether to trim whitespace from the end of each line;
  #            (true cleans all whitespace; false only removes trailing newline) (default: true)
  #
  # returns a String Array of prepared lines
  def prepare_source_string data, trim_end = true
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
    if trim_end
      [].tap {|lines| data.each_line {|line| lines << line.rstrip } }
    else
      [].tap {|lines| data.each_line {|line| lines << line.chomp } }
    end
  end

  # Internal: Efficiently checks whether the specified String resembles a URI
  #
  # Uses the Asciidoctor::UriSniffRx regex to check whether the String begins
  # with a URI prefix (e.g., http://). No validation of the URI is performed.
  #
  # str - the String to check
  #
  # returns true if the String is a URI, false if it is not
  if ::RUBY_ENGINE == 'jruby'
    def uriish? str
      (str.include? ':') && !(str.start_with? 'uri:classloader:') && (UriSniffRx.match? str)
    end
  else
    def uriish? str
      (str.include? ':') && (UriSniffRx.match? str)
    end
  end

  # Internal: Encode a URI component String for safe inclusion in a URI.
  #
  # str - the URI component String to encode
  #
  # Returns the String with all reserved URI characters encoded (e.g., /, &, =, space, etc).
  if RUBY_ENGINE == 'opal'
    def encode_uri_component str
      # patch necessary to adhere with RFC-3986 (and thus CGI.escape)
      # see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent#Description
      %x(
        return encodeURIComponent(str).replace(/%20|[!'()*]/g, function (m) {
          return m === '%20' ? '+' : '%' + m.charCodeAt(0).toString(16)
        })
      )
    end
  else
    CGI = ::CGI
    def encode_uri_component str
      CGI.escape str
    end
  end

  # Internal: Apply URI path encoding to spaces in the specified string (i.e., convert spaces to %20).
  #
  # str - the String to encode
  #
  # Returns the specified String with all spaces replaced with %20.
  def encode_spaces_in_uri str
    (str.include? ' ') ? (str.gsub ' ', '%20') : str
  end

  # Public: Removes the file extension from filename and returns the result
  #
  # filename - The String file name to process; expected to be a posix path
  #
  # Examples
  #
  #   Helpers.rootname 'part1/chapter1.adoc'
  #   # => "part1/chapter1"
  #
  # Returns the String filename with the file extension removed
  def rootname filename
    if (last_dot_idx = filename.rindex '.')
      (filename.index '/', last_dot_idx) ? filename : (filename.slice 0, last_dot_idx)
    else
      filename
    end
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
  def basename filename, drop_ext = nil
    if drop_ext
      ::File.basename filename, (drop_ext == true ? (extname filename) : drop_ext)
    else
      ::File.basename filename
    end
  end

  # Public: Returns whether this path has a file extension.
  #
  # path - The path String to check; expects a posix path
  #
  # Returns true if the path has a file extension, false otherwise
  def extname? path
    (last_dot_idx = path.rindex '.') && !(path.index '/', last_dot_idx)
  end

  # Public: Retrieves the file extension of the specified path. The file extension is the portion of the path in the
  # last path segment starting from the last period.
  #
  # This method differs from File.extname in that it gives us control over the fallback value and is more efficient.
  #
  # path     - The path String in which to look for a file extension
  # fallback - The fallback String to return if no file extension is present (optional, default: '')
  #
  # Returns the String file extension (with the leading dot included) or the fallback value if the path has no file extension.
  if ::File::ALT_SEPARATOR
    def extname path, fallback = ''
      if (last_dot_idx = path.rindex '.')
        (path.index '/', last_dot_idx) || (path.index ::File::ALT_SEPARATOR, last_dot_idx) ? fallback : (path.slice last_dot_idx, path.length)
      else
        fallback
      end
    end
  else
    def extname path, fallback = ''
      if (last_dot_idx = path.rindex '.')
        (path.index '/', last_dot_idx) ? fallback : (path.slice last_dot_idx, path.length)
      else
        fallback
      end
    end
  end

  # Internal: Make a directory, ensuring all parent directories exist.
  def mkdir_p dir
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
  private_constant :ROMAN_NUMERALS

  # Internal: Converts an integer to a Roman numeral.
  #
  # val - the [Integer] value to convert
  #
  # Returns the [String] roman numeral for this integer
  def int_to_roman val
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
  def nextval current
    if ::Integer === current
      current + 1
    elsif (intval = current.to_i).to_s == current.to_s
      intval + 1
    else
      current.succ
    end
  end

  # Internal: Resolve the specified object as a Class
  #
  # object - The Object to resolve as a Class
  #
  # Returns a Class if the specified object is a Class (but not a Module) or
  # a String that resolves to a Class; otherwise, nil
  def resolve_class object
    ::Class === object ? object : (::String === object ? (class_for_name object) : nil)
  end

  # Internal: Resolves a Class object (not a Module) for the qualified name.
  #
  # Returns Class
  def class_for_name qualified_name
    raise unless ::Class === (resolved = ::Object.const_get qualified_name, false)
    resolved
  rescue
    raise ::NameError, %(Could not resolve class for name: #{qualified_name})
  end
end
end
