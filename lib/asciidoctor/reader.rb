module Asciidoctor
# Public: Methods for retrieving lines from AsciiDoc source files
class Reader

  # Public: Get the document source as a String Array of lines.
  attr_reader :source

  # Public: Get the 1-based offset of the current line.
  attr_reader :lineno

  # Public: Initialize the Reader object.
  #
  # data       - The Array of Strings holding the Asciidoc source document. The
  #              original instance of this Array is not modified (default: nil)
  # document   - The document with which this reader is associated. Used to access
  #              document attributes (default: nil)
  # preprocess - A flag indicating whether to run the preprocessor on these lines.
  #              Only enable for the outer-most Reader. If this argument is true,
  #              a Document object must also be supplied.
  #              (default: false)
  # block      - A block that can be used to retrieve external Asciidoc
  #              data to include in this document.
  #
  # Examples
  #
  #   data   = File.readlines(filename)
  #   reader = Asciidoctor::Reader.new data
  def initialize(data = nil, document = nil, preprocess = false, &block)
    # TODO use Struct to track file/lineno info; track as file changes; offset for sub-readers
    data = [] if data.nil?
    @lineno = 0
    @next_line_preprocessed = false
    @unescape_next_line = false
    @conditionals_stack = []
    @skipping = false
    @eof = false

    if !preprocess
      @lines = data.is_a?(String) ? data.lines.entries : data.dup
      @preprocess_source = false
      # document is not nil in the case of nested AsciiDoc document (in table cell)
      unless document.nil?
        @document = document
        # preprocess first line, since we may not have hit it yet
        # FIXME include handler (block) should be available to the peek_line call
        @include_block = nil
        peek_line true
        @document = nil
      end
    elsif !data.empty?
      # NOTE we assume document is not nil!
      @document = document
      @preprocess_source = true
      @include_block = block_given? ? block : nil
      normalize_data(data.is_a?(String) ? data.lines.entries : data)
    else
      @lines = []
      @preprocess_source = false
    end

    @source = @lines.dup
  end

  # Public: Get a copy of the remaining Array of String lines parsed from the source
  def lines
    @lines.nil? ? nil : @lines.dup
  end

  # Public: Check whether there are any lines left to read.
  #
  # If preprocessing is enabled for this Reader, and there are lines remaining,
  # the next line is preprocessed before checking whether there are more lines. 
  #
  # Returns true if @lines is empty, or false otherwise.
  def has_more_lines?(preprocess = nil)
    if @eof || (@eof = @lines.empty?)
      false
    elsif (preprocess.nil? && @preprocess_source || preprocess) && !@next_line_preprocessed
      preprocess_next_line.nil? ? false : !@lines.empty?
    else
      true
    end
  end

  # Public: Check whether this reader is empty (contains no lines)
  #
  # If preprocessing is enabled for this Reader, and there are lines remaining,
  # the next line is preprocessed before checking whether there are more lines. 
  #
  # Returns true if @lines is empty, otherwise false.
  def empty?
    !has_more_lines?
  end

  # Private: Strip off leading blank lines in the Array of lines.
  #
  # Examples
  #
  #   @lines
  #   => ["\n", "\t\n", "Foo\n", "Bar\n", "\n"]
  #
  #   skip_blank_lines
  #   => 2
  #
  #   @lines
  #   => ["Foo\n", "Bar\n"]
  #
  # Returns an Integer of the number of lines skipped
  def skip_blank_lines
    skipped = 0
    # optimized code for shortest execution path
    while !(next_line = get_line).nil?
      if next_line.chomp.empty?
        skipped += 1
      else
        unshift_line next_line
        break
      end
    end 

    skipped
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
  def consume_comments(options = {})
    comment_lines = []
    preprocess = options.fetch(:preprocess, true)
    while !(next_line = get_line(preprocess)).nil?
      if options[:include_blank_lines] && next_line.chomp.empty?
        comment_lines << next_line
      elsif (commentish = next_line.start_with?('//')) && (match = next_line.match(REGEXP[:comment_blk]))
        comment_lines << next_line
        comment_lines.push(*(grab_lines_until(:terminator => match[0], :grab_last_line => true, :preprocess => false)))
      elsif commentish && next_line.match(REGEXP[:comment])
        comment_lines << next_line
      else
        # throw it back
        unshift_line next_line
        break
      end
    end

    comment_lines
  end
  alias :skip_comment_lines :consume_comments

  # Ignore front-matter, commonly used in static site generators
  def skip_front_matter(data, increment_linenos = true)
    #if data.nil?
    #  data = @lines
    #  increment_linenos = true
    #else
    #  increment_linenos = false
    #end

    front_matter = nil
    if data.size > 0 && data.first.chomp == '---'
      original_data = data.dup
      front_matter = []
      data.shift
      @lineno += 1 if increment_linenos
      while !data.empty? && data.first.chomp != '---'
        front_matter.push data.shift
        @lineno += 1 if increment_linenos
      end

      if data.empty?
        data.unshift(*original_data)
        @lineno = 0 if increment_linenos
        front_matter = nil
      else
        data.shift
        @lineno += 1 if increment_linenos
      end
    end

    front_matter
  end

  # Public: Consume consecutive lines containing line comments.
  #
  # Returns the Array of lines that were consumed
  #
  # Examples
  #   @lines
  #   => ["// foo\n", "bar\n"]
  #
  #   comment_lines = consume_comments
  #   => ["// foo\n"]
  #
  #   @lines
  #   => ["bar\n"]
  def consume_line_comments
    comment_lines = []
    # optimized code for shortest execution path
    while !(next_line = get_line).nil?
      if next_line.match(REGEXP[:comment])
        comment_lines << next_line
      else
        unshift_line next_line
        break
      end
    end

    comment_lines
  end

  # Public: Get the next line of source data. Consumes the line returned.
  #
  # preprocess - A Boolean flag indicating whether to evaluate preprocessing
  #              directives (macros) before reading line (default: true)
  #
  # Returns the String of the next line of the source data if data is present.
  # Returns nil if there is no more data.
  def get_line(preprocess = true)
    if @eof || (@eof = @lines.empty?)
      @next_line_preprocessed = true
      nil
    elsif preprocess && @preprocess_source &&
        !@next_line_preprocessed && preprocess_next_line.nil?
      @next_line_preprocessed = true
      nil
    else
      @lineno += 1
      @next_line_preprocessed = false
      if @unescape_next_line
        @unescape_next_line = false
        @lines.shift[1..-1]
      else
        @lines.shift
      end
    end
  end

  # Public: Advance to the next line by discarding the line at the front of the stack
  #
  # Removes the line at the front of the stack without any processing.
  #
  # returns a boolean indicating whether there was a line to discard
  def advance
    @next_line_preprocessed = false
    # we assume that we're advancing over a line of known content
    if @eof || (@eof = @lines.empty?)
      false
    else
      @lineno += 1
      @lines.shift
      true
    end
  end

  # Public: Get the next line of source data. Does not consume the line returned.
  #
  # preprocess - A Boolean flag indicating whether to evaluate preprocessing
  #              directives (macros) before reading line (default: true)
  #
  # Returns a String dup of the next line of the source data if data is present.
  # Returns nil if there is no more data.
  def peek_line(preprocess = true)
    if !preprocess
      # QUESTION do we need to dup?
      @eof || (@eof = @lines.empty?) ? nil : @lines.first.dup
    elsif has_more_lines? true
      # QUESTION do we need to dup?
      @lines.first.dup
    else
      nil
    end
  end

  # TODO document & test me!
  def peek_lines(number = 1)
    lines = []
    idx = 0
    (1..number).each do
      if @preprocess_source && !@next_line_preprocessed
        advanced = preprocess_next_line
        break if advanced.nil? || @eof || (@eof = @lines.empty?)
        idx = 0 if advanced
      end
      break if idx >= @lines.size
      # QUESTION do we need to dup?
      lines << @lines[idx].dup
      idx += 1
    end
    lines
  end

  # Internal: Preprocess the next line until the cursor is at a line of content
  #
  # Evaluate preprocessor macros on the next line, continuing to do so until
  # the cursor arrives at a line of included content. That line is marked as
  # preprocessed so that preprocessing is not performed multiple times.
  #
  # returns a Boolean indicating whether the cursor advanced, or nil if there
  # are no more lines available.
  def preprocess_next_line
    # this return could be happening from a recursive call
    return nil if @eof || (next_line = @lines.first).nil?
    if next_line.include?('::') && (next_line.include?('if') || next_line.include?('endif')) && (match = next_line.match(REGEXP[:ifdef_macro]))
      if next_line.start_with? '\\'
        @next_line_preprocessed = true
        @unescape_next_line = true
        false
      else
        preprocess_conditional_inclusion(*match.captures)
      end
    elsif @skipping
      advance
      # skip over comment blocks, we don't want to process directives in them
      skip_comment_lines :include_blank_lines => true, :preprocess => false
      preprocess_next_line.nil? ? nil : true
    elsif next_line.include?('include::') && match = next_line.match(REGEXP[:include_macro])
      if next_line.start_with? '\\'
        @next_line_preprocessed = true
        @unescape_next_line = true
        false
      else
        preprocess_include(match[1], match[2].strip)
      end
    else
      @next_line_preprocessed = true
      false
    end
  end

  # Internal: Preprocess the directive (macro) to conditionally include content.
  #
  # Preprocess the conditional inclusion directive (ifdef, ifndef, ifeval,
  # endif) under the cursor. If the Reader is currently skipping content, then
  # simply track the open and close delimiters of any nested conditional
  # blocks. If the Reader is not skipping, mark whether the condition is
  # satisfied and continue preprocessing recursively until the next line of
  # available content is found.
  #
  # directive  - The conditional inclusion directive (ifdef, ifndef, ifeval, endif)
  # target     - The target, which is the name of one or more attributes that are
  #              used in the condition (blank in the case of the ifeval directive)
  # delimiter  - The conditional delimiter for multiple attributes ('+' means all
  #              attributes must be defined or undefined, ',' means any of the attributes
  #              can be defined or undefined.
  # text       - The text associated with this directive (occurring between the square brackets)
  #              Used for a single-line conditional block in the case of the ifdef or
  #              ifndef directives, and for the conditional expression for the ifeval directive.
  #
  # returns a Boolean indicating whether the cursor advanced, or nil if there
  # are no more lines available.
  def preprocess_conditional_inclusion(directive, target, delimiter, text)
    # must have a target before brackets if ifdef or ifndef
    # must not have text between brackets if endif
    # don't honor match if it doesn't meet this criteria
    if ((directive == 'ifdef' || directive == 'ifndef') && target.empty?) ||
        (directive == 'endif' && !text.nil?)
      @next_line_preprocessed = true
      return false
    end

    if directive == 'endif'
      stack_size = @conditionals_stack.size
      if stack_size > 0
        pair = @conditionals_stack.last
        if target.empty? || target == pair[:target]
          @conditionals_stack.pop
          @skipping = @conditionals_stack.empty? ? false : @conditionals_stack.last[:skipping]
        else
          puts "asciidoctor: ERROR: line #{@lineno + 1}: mismatched macro: endif::#{target}[], expected endif::#{pair[:target]}[]"
        end
      else
        puts "asciidoctor: ERROR: line #{@lineno + 1}: unmatched macro: endif::#{target}[]"
      end
      advance
      return preprocess_next_line.nil? ? nil : true
    end

    skip = false
    if !@skipping
      case directive
      when 'ifdef'
        case delimiter
        when nil
          # if the attribute is undefined, then skip
          skip = !@document.attributes.has_key?(target)
        when ','
          # if any attribute is defined, then don't skip
          skip = !target.split(',').detect {|name| @document.attributes.has_key? name }
        when '+'
          # if any attribute is undefined, then skip
          skip = target.split('+').detect {|name| !@document.attributes.has_key? name }
        end
      when 'ifndef'
        case delimiter
        when nil
          # if the attribute is defined, then skip
          skip = @document.attributes.has_key?(target)
        when ','
          # if any attribute is undefined, then don't skip
          skip = !target.split(',').detect {|name| !@document.attributes.has_key? name }
        when '+'
          # if any attribute is defined, then skip
          skip = target.split('+').detect {|name| @document.attributes.has_key? name }
        end
      when 'ifeval'
        # the text in brackets must match an expression
        # don't honor match if it doesn't meet this criteria
        if !target.empty? || !(expr_match = text.strip.match(REGEXP[:eval_expr]))
          @next_line_preprocessed = true
          return false
        end

        lhs = resolve_expr_val(expr_match[1])
        op = expr_match[2]
        rhs = resolve_expr_val(expr_match[3])

        skip = !lhs.send(op.to_sym, rhs)
      end
    end
    advance
    # single line conditional inclusion
    if directive != 'ifeval' && !text.nil?
      if !@skipping && !skip
        unshift_line "#{text.rstrip}\n"
        return true
      end
    # conditional inclusion block
    else
      if !@skipping && skip
        @skipping = true
      end
      @conditionals_stack << {:target => target, :skip => skip, :skipping => @skipping}
    end
    return preprocess_next_line.nil? ? nil : true
  end

  # Internal: Preprocess the directive (macro) to include the target document.
  #
  # Preprocess the directive to include the target document. The scenarios
  # are as follows:
  #
  # If SafeMode is SECURE or greater, the directive is ignore and the include
  # directive line is emitted verbatim.
  #
  # Otherwise, if an include handler is specified (currently controlled by a
  # closure block), pass the target to that block and expect an Array of String
  # lines in return.
  #
  # Otherwise, if the include-depth attribute is greater than 0, normalize the
  # target path and read the lines onto the beginning of the Array of source
  # data.
  #
  # If none of the above apply, emit the include directive line verbatim.
  #
  # target - The name of the source document to include as specified in the
  #          target slot of the include::[] macro
  #
  # returns a Boolean indicating whether the line under the cursor has changed.
  # -
  # FIXME includes bork line numbers
  def preprocess_include(target, raw_attributes)
    target = @document.sub_attributes target
    if target.empty?
      advance
      @next_line_preprocessed = false
      false
    # if running in SafeMode::SECURE or greater, don't process this directive
    # however, be friendly and at least make it a link to the source document
    elsif @document.safe >= SafeMode::SECURE
      @lines[0] = "link:#{target}[#{target}]\n"
      @next_line_preprocessed = true
      false
    # assume that if a block is given, the developer wants
    # to handle when and how to process the include, even
    # if the include-depth attribute is 0
    elsif @include_block
      advance
      @lines.unshift(*normalize_include_data(@include_block.call(target, @document)))
    # FIXME currently we're not checking the upper bound of the include depth
    elsif @document.attributes.fetch('include-depth', 0).to_i > 0
      advance
      if target.include?(':') && target.match(REGEXP[:uri_sniff])
        unless @document.attributes.has_key? 'allow-uri-read'
          @lines[0] = "link:#{target}[#{target}]\n"
          @next_line_preprocessed = true
          return false
        end

        target_type = :uri
        include_file = target
        if @document.attributes.has_key? 'cache-uri'
          # NOTE caching requires the open-uri-cached gem to be installed
          Helpers.require_library 'open-uri/cached', 'open-uri-cached'
        else
          Helpers.require_library 'open-uri'
        end
        # FIXME should stop processing include if required library cannot be loaded; check for -1 return value?
      else
        target_type = :file
        include_file = @document.normalize_system_path(target, nil, nil, :target_name => 'include file')
        if !File.file?(include_file)
          puts "asciidoctor: WARNING: line #{@lineno}: include file not found: #{include_file}"
          return true
        end
      end

      inc_lines = nil
      tags = nil
      attributes = {}
      if !raw_attributes.empty?
        attributes = AttributeList.new(raw_attributes).parse
        if attributes.has_key? 'lines'
          inc_lines = []
          attributes['lines'].split(REGEXP[:ssv_or_csv_delim]).each do |linedef|
            if linedef.include?('..')
              from, to = linedef.split('..').map(&:to_i)
              if to == -1
                inc_lines << from
                inc_lines << 1.0/0.0
              else
                inc_lines.concat Range.new(from, to).to_a
              end
            else
              inc_lines << linedef.to_i
            end
          end
          inc_lines = inc_lines.sort.uniq
        elsif attributes.has_key? 'tags'
          tags = attributes['tags'].split(REGEXP[:ssv_or_csv_delim]).uniq
        end
      end
      if !inc_lines.nil?
        if !inc_lines.empty?
          selected = []
          begin
            open(include_file) do |f|
              f.each_line do |l|
                take = inc_lines.first
                if take.is_a?(Float) && take.infinite?
                  selected.push l
                else
                  if f.lineno == take
                    selected.push l
                    inc_lines.shift 
                  end
                  break if inc_lines.empty?
                end
              end
            end
          rescue
            puts "asciidoctor: WARNING: line #{@lineno}: include #{target_type} not readable: #{include_file}"
            return true
          end
          @lines.unshift(*normalize_include_data(selected, attributes['indent'])) unless selected.empty?
        end
      elsif !tags.nil?
        if !tags.empty?
          selected = []
          active_tag = nil
          begin
            open(include_file) do |f|
              f.each_line do |l|
                l.force_encoding(::Encoding::UTF_8) if ::Asciidoctor::FORCE_ENCODING
                if !active_tag.nil?
                  if l.include?("end::#{active_tag}[]")
                    active_tag = nil
                  else
                    selected.push "#{l.rstrip}\n"
                  end
                else
                  tags.each do |tag|
                    if l.include?("tag::#{tag}[]")
                      active_tag = tag
                      break
                    end
                  end
                end
              end
            end
          rescue
            puts "asciidoctor: WARNING: line #{@lineno}: include #{target_type} not readable: #{include_file}"
            return true
          end
          #@lines.unshift(*selected) unless selected.empty?
          @lines.unshift(*normalize_include_data(selected, attributes['indent'])) unless selected.empty?
        end
      else
        begin
          @lines.unshift(*normalize_include_data(open(include_file) {|f| f.readlines }, attributes['indent']))
        rescue
          puts "asciidoctor: WARNING: line #{@lineno}: include #{target_type} not readable: #{include_file}"
          return true
        end
      end
      true
    else
      @next_line_preprocessed = true
      false
    end
  end

  # Public: Push the String line onto the beginning of the Array of source data.
  #
  # Since this line was (assumed to be) previously retrieved through the
  # reader, it is marked as preprocessed.
  #
  # returns nil
  def unshift_line(line)
    @lines.unshift line
    @next_line_preprocessed = true
    @eof = false
    @lineno -= 1
    nil
  end

  # Public: Push Array of lines onto the front of the Array of source data, unless `lines` has no non-nil values.
  #
  # Returns nil
  def unshift(*new_lines)
    size = new_lines.size
    if size > 0
      @lines.unshift(*new_lines)
      # assume that what we are putting back on is already processed for directives
      @next_line_preprocessed = true
      @eof = false
      @lineno -= size
    end
    nil
  end

  # Public: Chomp the String on the last line if this reader contains at least one line
  #
  # Delegates to chomp!
  #
  # Returns nil
  def chomp_last!
    @lines.last.chomp! unless @eof || (@eof = @lines.empty?)
    nil
  end

  # Public: Return all the lines from `@lines` until we (1) run out them,
  #   (2) find a blank line with :break_on_blank_lines => true, or (3) find
  #   a line for which the given block evals to true.
  #
  # options - an optional Hash of processing options:
  #           * :break_on_blank_lines may be used to specify to break on
  #               blank lines
  #           * :skip_first_line may be used to tell the reader to advance
  #               beyond the first line before beginning the scan
  #           * :preserve_last_line may be used to specify that the String
  #               causing the method to stop processing lines should be
  #               pushed back onto the `lines` Array.
  #           * :grab_last_line may be used to specify that the String
  #               causing the method to stop processing lines should be
  #               included in the lines being returned
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

    advance if options[:skip_first_line]
    # very hot code
    # save options to locals for minor optimizations
    if options.has_key? :terminator
      terminator = options[:terminator]
      break_on_blank_lines = false
      break_on_list_continuation = false
      chomp_last_line = options[:chomp_last_line] || false
    else
      terminator = nil
      break_on_blank_lines = options[:break_on_blank_lines]
      break_on_list_continuation = options[:break_on_list_continuation]
      chomp_last_line = break_on_blank_lines
    end
    skip_line_comments = options[:skip_line_comments]
    preprocess = options.fetch(:preprocess, true)
    buffer_empty = true
    while !(this_line = get_line(preprocess)).nil?
      # effectively a no-args lamba, but much faster
      finish = while true
        break true if terminator && this_line.chomp == terminator
        break true if break_on_blank_lines && this_line.strip.empty?
        if break_on_list_continuation && !buffer_empty && this_line.chomp == LIST_CONTINUATION
          options[:preserve_last_line] = true
          break true
        end
        break true if block && yield(this_line)
        break false
      end

      if finish
        if options[:grab_last_line]
          buffer << this_line
          buffer_empty = false
        end
        # QUESTION should we dup this_line when restoring??
        unshift_line this_line if options[:preserve_last_line]
        break
      end

      unless skip_line_comments && this_line.match(REGEXP[:comment])
        buffer << this_line
        buffer_empty = false
      end
    end

    # should we dup the line before chopping?
    buffer.last.chomp! if chomp_last_line && !buffer_empty
    buffer
  end

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
    Lexer.sanitize_attribute_name(name)
  end

  # Private: Resolve the value of one side of the expression
  def resolve_expr_val(str)
    val = str
    type = nil

    if val.start_with?('"') && val.end_with?('"') ||
        val.start_with?('\'') && val.end_with?('\'')
      type = :s
      val = val[1..-2]
    end

    if val.include? '{'
      val = @document.sub_attributes val
    end

    if type != :s
      if val.empty?
        val = nil
      elsif val == 'true'
        val = true
      elsif val == 'false'
        val = false
      elsif val.include?('.')
        val = val.to_f
      else
        val = val.to_i
      end
    end

    val
  end

  # Private: Normalize raw input read from an include directive
  #
  # This method strips whitespace from the end of every line of
  # the source data and appends a LF (i.e., Unix endline). This
  # whitespace substitution is very important to how Asciidoctor
  # works.
  #
  # Any leading or trailing blank lines are also removed. (DISABLED)
  #
  # data - A String Array of input data to be normalized
  #
  # returns the processed lines
  #-
  # FIXME this shares too much in common w/ normalize_data; combine
  # in a shared function
  def normalize_include_data(data, indent = nil)
    if ::Asciidoctor::FORCE_ENCODING
      result = data.map {|line| "#{line.rstrip.force_encoding(::Encoding::UTF_8)}\n" }
    else
      result = data.map {|line| "#{line.rstrip}\n" }
    end

    # QUESTION: how should this be activated? (defering for now)
    # QUESTION: should we save the front matter read from an include file somewhere?
    #if !@document.nil? && @document.attributes.has_key?('skip-front-matter')
    #  skip_front_matter result
    #end

    unless indent.nil?
      Lexer.reset_block_indent! result, indent.to_i
    end

    result
  end

  # Private: Normalize raw input, used for the outermost Reader.
  #
  # This method strips whitespace from the end of every line of
  # the source data and appends a LF (i.e., Unix endline). This
  # whitespace substitution is very important to how Asciidoctor
  # works.
  #
  # Any leading or trailing blank lines are also removed.
  #
  # The normalized lines are assigned to the @lines instance variable.
  #
  # data - A String Array of input data to be normalized
  #
  # returns nothing
  def normalize_data(data)
    # normalize line ending to LF (purging occurrences of CRLF)
    # this rstrip is *very* important to how Asciidoctor works

    if ::Asciidoctor::FORCE_ENCODING
      @lines = data.map {|line| "#{line.rstrip.force_encoding(::Encoding::UTF_8)}\n" }
    else
      @lines = data.map {|line| "#{line.rstrip}\n" }
    end

    # QUESTION should this work for AsciiDoc table cell content? If so, it won't hit here
    if !@document.nil? && @document.attributes.has_key?('skip-front-matter')
      if (front_matter = skip_front_matter(@lines))
        @document.attributes['front-matter'] = front_matter.join.chomp
      end
    end

    @lines.shift && @lineno += 1 while !@lines.first.nil? && @lines.first.chomp.empty?
    @lines.pop while !@lines.last.nil? && @lines.last.chomp.empty?

    # Process bibliography references, so they're available when text
    # before the reference is being rendered.
    # FIXME reenable whereever it belongs
    #@lines.each do |line|
    #  if biblio = line.match(REGEXP[:biblio])
    #    @document.register(:ids, biblio[1])
    #  end
    #end
    nil
  end
end
end
