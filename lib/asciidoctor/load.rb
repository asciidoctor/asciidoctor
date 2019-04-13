module Asciidoctor
  module_function

  # Public: Parse the AsciiDoc source input into a {Document}
  #
  # Accepts input as an IO (or StringIO), String or String Array object. If the
  # input is a File, the object is expected to be opened for reading and is not
  # closed afterwards by this method. Information about the file (filename,
  # directory name, etc) gets assigned to attributes on the Document object.
  #
  # input   - the AsciiDoc source as a IO, String or Array.
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See {Document#initialize} for details about these options.
  #
  # Returns the Document
  def load input, options = {}
    options = options.merge

    if (timings = options[:timings])
      timings.start :read
    end

    if (logger = options[:logger]) && logger != LoggerManager.logger
      LoggerManager.logger = logger
    end

    if !(attrs = options[:attributes])
      attrs = {}
    elsif ::Hash === attrs
      attrs = attrs.merge
    elsif (defined? ::Java::JavaUtil::Map) && ::Java::JavaUtil::Map === attrs
      attrs = attrs.dup
    elsif ::Array === attrs
      attrs = {}.tap do |accum|
        attrs.each do |entry|
          k, _, v = entry.partition '='
          accum[k] = v
        end
      end
    elsif ::String === attrs
      # condense and convert non-escaped spaces to null, unescape escaped spaces, then split on null
      attrs = {}.tap do |accum|
        attrs.gsub(SpaceDelimiterRx, '\1' + NULL).gsub(EscapedSpaceRx, '\1').split(NULL).each do |entry|
          k, _, v = entry.partition '='
          accum[k] = v
        end
      end
    elsif (attrs.respond_to? :keys) && (attrs.respond_to? :[])
      # coerce attrs to a real Hash
      attrs = {}.tap {|accum| attrs.keys.each {|k| accum[k] = attrs[k] } }
    else
      raise ::ArgumentError, %(illegal type for attributes option: #{attrs.class.ancestors.join ' < '})
    end

    if ::File === input
      options[:input_mtime] = input.mtime
      # NOTE defer setting infile and indir until we get a better sense of their purpose
      # TODO cli checks if input path can be read and is file, but might want to add check to API too
      attrs['docfile'] = input_path = ::File.absolute_path input.path
      attrs['docdir'] = ::File.dirname input_path
      attrs['docname'] = Helpers.basename input_path, (attrs['docfilesuffix'] = Helpers.extname input_path)
      source = input.read
    elsif input.respond_to? :read
      # NOTE tty, pipes & sockets can't be rewound, but can't be sniffed easily either
      # just fail the rewind operation silently to handle all cases
      input.rewind rescue nil
      source = input.read
    elsif ::String === input
      source = input
    elsif ::Array === input
      source = input.drop 0
    elsif input
      raise ::ArgumentError, %(unsupported input type: #{input.class})
    end

    if timings
      timings.record :read
      timings.start :parse
    end

    options[:attributes] = attrs
    doc = options[:parse] == false ? (Document.new source, options) : (Document.new source, options).parse

    timings.record :parse if timings
    doc
  rescue => ex
    begin
      context = %(asciidoctor: FAILED: #{attrs['docfile'] || '<stdin>'}: Failed to load AsciiDoc document)
      if ex.respond_to? :exception
        # The original message must be explicitly preserved when wrapping a Ruby exception
        wrapped_ex = ex.exception %(#{context} - #{ex.message})
        # JRuby automatically sets backtrace; MRI did not until 2.6
        wrapped_ex.set_backtrace ex.backtrace
      else
        # Likely a Java exception class
        wrapped_ex = ex.class.new context, ex
        wrapped_ex.stack_trace = ex.stack_trace
      end
    rescue
      wrapped_ex = ex
    end
    raise wrapped_ex
  end

  # Public: Parse the contents of the AsciiDoc source file into an Asciidoctor::Document
  #
  # input   - the String AsciiDoc source filename
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See Asciidoctor::Document#initialize for details about options.
  #
  # Returns the Asciidoctor::Document
  def load_file filename, options = {}
    ::File.open(filename, FILE_READ_MODE) {|file| load file, options }
  end
end
