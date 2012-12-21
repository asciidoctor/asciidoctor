# Public: Methods for retrieving lines from Asciidoc documents
class Asciidoctor::Reader

  include Asciidoctor

  # Public: Get the String document source.
  attr_reader :source

  # Public: Get the String Array of lines parsed from the source
  attr_reader :lines

  # Public: Get the Hash of attributes
  attr_reader :attributes

  attr_reader :references

  # Public: Convert a string to a legal attribute name.
  #
  # name  - The String holding the Asciidoc attribute name.
  #
  # Returns a String with the legal name.
  #
  # Examples
  #
  #   sanitize_attribute_name('Foo Bar')
  #   => 'foobar'
  #
  #   sanitize_attribute_name('foo')
  #   => 'foo'
  #
  #   sanitize_attribute_name('Foo 3 #-Billy')
  #   => 'foo3-billy'
  def sanitize_attribute_name(name)
    name.gsub(/[^\w\-]/, '').downcase
  end

  # Public: Initialize the Reader object.
  #
  # data  - The Array of Strings holding the Asciidoc source document.
  # block - A block that can be used to retrieve external Asciidoc
  #         data to include in this document.
  #
  # Examples
  #
  #   data   = File.readlines(filename)
  #   reader = Asciidoctor::Reader.new(data)
  def initialize(data = [], attributes = nil, &block)
    @references = {}

    data = data.lines.entries if data.is_a? String

    # if attributes are nil, we assume this is a preprocessed string
    if attributes.nil?
      @lines = data
    else
      @attributes = attributes
      process(data)
    end

    #Asciidoctor.debug "About to leave Reader#init, and references is #{@references.inspect}"
    @source = @lines.join
    Asciidoctor.debug "Leaving Reader#init, and I have #{@lines.count} lines"
    Asciidoctor.debug "Also, has_lines? is #{self.has_lines?}"
  end

  # Public: Check whether there are any lines left to read.
  #
  # Returns true if !@lines.empty? is true, or false otherwise.
  def has_lines?
    !@lines.empty?
  end

  # Private: Strip off leading blank lines in the Array of lines.
  #
  # Returns nil.
  #
  # Examples
  #
  #   @lines
  #   => ["\n", "\t\n", "Foo\n", "Bar\n", "\n"]
  #
  #   skip_blank
  #   => nil
  #
  #   @lines
  #   => ["Foo\n", "Bar\n"]
  def skip_blank
    while has_lines? && @lines.first.strip.empty?
      @lines.shift
    end

    nil
  end

  # Public: Consume consecutive lines containing line- or block-level comments.
  #
  # Returns the Array of lines that were consumed
  #
  # Examples
  #   @lines
  #   => ["// foo\n", "////\n", "foo bar\n", "////\n", "actual text\n"]
  #
  #   comment_lines = consume_comments
  #   => ["// foo\n", "////\n", "foo bar\n", "////\n"]
  #
  #   @lines
  #   => ["actual text\n"]
  def consume_comments
    comment_lines = []
    while !@lines.empty?
      next_line = peek_line
      if next_line.match(REGEXP[:comment_blk])
        comment_lines << get_line
        comment_lines.push *(grab_lines_until(:preserve_last_line => true) {|line| line.match(REGEXP[:comment_blk])})
        comment_lines << get_line
      elsif next_line.match(REGEXP[:comment])
        comment_lines << get_line
      else
        break
      end
    end

    comment_lines
  end

  # Skip the next line if it's a list continuation character
  # 
  # Returns nil
  def skip_list_continuation
    if has_lines? && @lines.first.chomp == '+'
      @lines.shift
    end

    nil
  end

  # Public: Get the next line of source data. Consumes the line returned.
  #
  # Returns the String of the next line of the source data if data is present.
  # Returns nil if there is no more data.
  def get_line
    @lines.shift
  end

  # Public: Get the next line of source data. Does not consume the line returned.
  #
  # Returns a String dup of the next line of the source data if data is present.
  # Returns nil if there is no more data.
  def peek_line
    @lines.first.dup if @lines.first
  end

  # Public: Push Array of string `lines` onto queue of source data lines, unless `lines` has no non-nil values.
  #
  # Returns nil
  def unshift(*lines)
    @lines.unshift(*lines) if lines.any?
    nil
  end

  # Public: Return all the lines from `@lines` until we (1) run out them,
  #   (2) find a blank line with :break_on_blank_lines => true, or (3) find
  #   a line for which the given block evals to true.
  #
  # options - an optional Hash of processing options:
  #           * :break_on_blank_lines may be used to specify to break on
  #               blank lines
  #           * :preserve_last_line may be used to specify that the String
  #               causing the method to stop processing lines should be
  #               pushed back onto the `lines` Array.
  #
  # Returns the Array of lines forming the next segment.
  #
  # Examples
  #
  #   reader = Reader.new ["First paragraph\n", "Second paragraph\n",
  #                        "Open block\n", "\n", "Can have blank lines\n",
  #                        "--\n", "\n", "In a different segment\n"]
  #
  #   reader.grab_lines_until
  #   => ["First paragraph\n", "Second paragraph\n", "Open block\n"]
  def grab_lines_until(options = {}, &block)
    buffer = []

    while (this_line = self.get_line)
      Asciidoctor.debug "Processing line: '#{this_line}'"
      finis ||= true if options[:break_on_blank_lines] && this_line.strip.empty?
      finis ||= true if block && yield(this_line)
      if finis
        self.unshift(this_line) if options[:preserve_last_line]
        break
      end

      buffer << this_line
    end
    buffer
  end

  # Private: Process raw input, used for the outermost reader.
  def process(data)

    raw_source = []
    include_regexp = /^include::([^\[]+)\[\]\s*\n?\z/

    data.each do |line|
      if inc = line.match(include_regexp)
        if block_given?
          raw_source << yield(inc[1])
        else
          raw_source.concat(File.readlines(inc[1]))
        end
      else
        raw_source << line
      end
    end

    ifdef_regexp = /^(ifdef|ifndef)::([^\[]+)\[\]/
    endif_regexp = /^endif::/
    defattr_regexp = /^:([^:!]+):\s*(.*)\s*$/
    delete_attr_regexp = /^:([^:]+)!:\s*$/
    conditional_regexp = /^\s*\{([^\?]+)\?\s*([^\}]+)\s*\}/

    skip_to = nil
    continuing_value = nil
    continuing_key = nil
    @lines = []
    raw_source.each do |line|
      if skip_to
        skip_to = nil if line.match(skip_to)
      elsif continuing_value
        close_continue = false
        # Lines that start with whitespace and end with a '+' are
        # a continuation, so gobble them up into `value`
        if match = line.match(/\s+(.+)\s+\+\s*$/)
          continuing_value += ' ' + match[1]
        elsif match = line.match(/\s+(.+)/)
          # If this continued line doesn't end with a +, then this
          # is the end of the continuation, no matter what the next
          # line does.
          continuing_value += ' ' + match[1]
          close_continue = true
        else
          # If this line doesn't start with whitespace, then it's
          # not a valid continuation line, so push it back for processing
          close_continue = true
          raw_source.unshift(line)
        end
        if close_continue
          @attributes[continuing_key] = continuing_value
          continuing_key = nil
          continuing_value = nil
        end
      elsif match = line.match(ifdef_regexp)
        attr = match[2]
        skip = case match[1]
               when 'ifdef';  !@attributes.has_key?(attr)
               when 'ifndef'; @attributes.has_key?(attr)
               end
        skip_to = /^endif::#{attr}\[\]\s*\n/ if skip
      elsif match = line.match(defattr_regexp)
        key = sanitize_attribute_name(match[1])
        value = match[2]
        if match = value.match(Asciidoctor::REGEXP[:attr_continue])
          # attribute value continuation line; grab lines until we run out
          # of continuation lines
          continuing_key = key
          continuing_value = match[1]  # strip off the spaces and +
          Asciidoctor.debug "continuing key: #{continuing_key} with partial value: '#{continuing_value}'"
        else
          @attributes[key] = value
          Asciidoctor.debug "Defines[#{key}] is '#{value}'"
        end
      elsif match = line.match(delete_attr_regexp)
        key = sanitize_attribute_name(match[1])
        @attributes.delete(key)
      elsif !line.match(endif_regexp)
        while match = line.match(conditional_regexp)
          value = @attributes.has_key?(match[1]) ? match[2] : ''
          line.sub!(conditional_regexp, value)
        end
        # leave line comments in as they play a role in flow (such as a list divider)
        @lines << line
      end
    end

    # Process bibliography references, so they're available when text
    # before the reference is being rendered.
    @lines.each do |line|
      if biblio = line.match(REGEXP[:biblio])
        @references[biblio[1]] = "[#{biblio[1]}]"
      end
    end
  end

end
