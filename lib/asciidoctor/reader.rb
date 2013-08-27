module Asciidoctor
# Public: Methods for retrieving lines from AsciiDoc source files
class Reader
  class Cursor
    attr_accessor :file
    attr_accessor :dir
    attr_accessor :path
    attr_accessor :lineno
  
    def initialize file, dir = nil, path = nil, lineno = nil
      @file = file
      @dir = dir
      @path = path
      @lineno = lineno
    end

    def line_info
      %(#{path}: line #{lineno})
    end
  end

  attr_reader :file
  attr_reader :dir
  attr_reader :path

  # Public: Get the 1-based offset of the current line.
  attr_reader :lineno

  # Public: Get the document source as a String Array of lines.
  attr_reader :source_lines

  # Public: Control whether lines are processed using Reader#process_line on first visit (default: true)
  attr_accessor :process_lines

  # Public: Initialize the Reader object
  def initialize data = nil, cursor = nil
    if cursor.nil?
      @file = @dir = nil
      @path = '<stdin>'
      @lineno = 1 # IMPORTANT lineno assignment must proceed prepare_lines call!
    elsif cursor.is_a? String
      @file = cursor
      @dir = File.dirname @file
      @path = File.basename @file
      @lineno = 1 # IMPORTANT lineno assignment must proceed prepare_lines call!
    else
      @file = cursor.file
      @dir = cursor.dir
      @path = cursor.path || '<stdin>'
      unless @file.nil?
        if @dir.nil?
          # REVIEW might to look at this assignment closer
          @dir = File.dirname @file
          @dir = nil if @dir == '.' # right?
        end

        if cursor.path.nil?
          @path = File.basename @file
        end
      end
      @lineno = cursor.lineno || 1 # IMPORTANT lineno assignment must proceed prepare_lines call!
    end
    @lines = data.nil? ? [] : (prepare_lines data)
    @source_lines = @lines.dup
    @eof = @lines.empty?
    @look_ahead = 0
    @process_lines = true
    @unescape_next_line = false
  end

  # Internal: Prepare the lines from the provided data
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
  # opts - A Hash of options to control what cleansing is done
  #
  # Returns The String lines extracted from the data
  def prepare_lines data, opts = {}
    data.is_a?(String) ? data.each_line.to_a : data.dup
  end

  # Internal: Processes a previously unvisited line
  #
  # By default, this method marks the line as processed
  # by incrementing the look_ahead counter and returns
  # the line unmodified.
  #
  # Returns The String line the Reader should make available to the next
  # invocation of Reader#read_line or nil if the Reader should drop the line,
  # advance to the next line and process it.
  def process_line line
    @look_ahead += 1 if @process_lines
    line
  end

  # Public: Check whether there are any lines left to read.
  #
  # If a previous call to this method resulted in a value of false,
  # immediately returned the cached value. Otherwise, delegate to
  # peek_line to determine if there is a next line available.
  #
  # Returns True if there are more lines, False if there are not.
  def has_more_lines?
    !(@eof || (@eof = peek_line.nil?))
  end

  # Public: Peek at the next line and check if it's empty (i.e., whitespace only)
  #
  # This method Does not consume the line from the stack.
  #
  # Returns True if the there are no more lines or if the next line is empty
  def next_line_empty?
    (line = peek_line).nil? || line.chomp.empty?
  end

  # Public: Peek at the next line of source data. Processes the line, if not
  # already marked as processed, but does not consume it.
  #
  # This method will probe the reader for more lines. If there is a next line
  # that has not previously been visited, the line is passed to the
  # Reader#preprocess_line method to be initialized. This call gives
  # sub-classess the opportunity to do preprocessing. If the return value of
  # the Reader#process_line is nil, the data is assumed to be changed and
  # Reader#peek_line is invoked again to perform further processing.
  #
  # direct  - A Boolean flag to bypasses the check for more lines and immediately
  #           returns the first element of the internal @lines Array. (default: false)
  #
  # Returns the next line of the source data as a String if there are lines remaining.
  # Returns nil if there is no more data.
  def peek_line direct = false
    if direct || @look_ahead > 0
      @unescape_next_line ? @lines.first[1..-1] : @lines.first
    elsif @eof || @lines.empty?
      @eof = true
      @look_ahead = 0
      nil
    else
      # FIXME the problem with this approach is that we aren't
      # retaining the modified line (hence the @unescape_next_line tweak)
      # perhaps we need a stack of proxy lines
      if (line = process_line @lines.first).nil?
        peek_line
      else
        line
      end
    end
  end

  # Public: Peek at the next multiple lines of source data. Processes the lines, if not
  # already marked as processed, but does not consume them.
  #
  # This method delegates to Reader#read_line to process and collect the line, then
  # restores the lines to the stack before returning them. This allows the lines to
  # be processed and marked as such so that subsequent reads will not need to process
  # the lines again.
  #
  # num    - The Integer number of lines to peek.
  # direct - A Boolean indicating whether processing should be disabled when reading lines
  #
  # Returns A String Array of the next multiple lines of source data, or an empty Array
  # if there are no more lines in this Reader.
  def peek_lines num = 1, direct = true
    old_look_ahead = @look_ahead
    result = []
    (1..num).each do
      if (line = read_line direct)
        result << line
      else
        break
      end
    end

    unless result.empty?
      result.reverse_each {|line| unshift line }
      @look_ahead = old_look_ahead if direct
    end

    result
  end

  # Public: Get the next line of source data. Consumes the line returned.
  #
  # direct  - A Boolean flag to bypasses the check for more lines and immediately
  #           returns the first element of the internal @lines Array. (default: false)
  #
  # Returns the String of the next line of the source data if data is present.
  # Returns nil if there is no more data.
  def read_line direct = false
    if direct || @look_ahead > 0 || has_more_lines?
      shift
    else
      nil
    end
  end

  # Public: Get the remaining lines of source data.
  #
  # This method calls Reader#read_line repeatedly until all lines are consumed
  # and returns the lines as a String Array. This method differs from
  # Reader#lines in that it processes each line in turn, hence triggering
  # any preprocessors implemented in sub-classes.
  #
  # Returns the lines read as a String Array
  def read_lines
    lines = []
    while has_more_lines?
      lines << read_line
    end
    lines
  end
  alias :readlines :read_lines

  # Public: Get the remaining lines of source data joined as a String.
  #
  # Delegates to Reader#read_lines, then joins the result.
  #
  # Returns the lines read joined as a String
  def read
    read_lines.join
  end

  # Public: Advance to the next line by discarding the line at the front of the stack
  #
  # direct  - A Boolean flag to bypasses the check for more lines and immediately
  #           returns the first element of the internal @lines Array. (default: true)
  #
  # returns a Boolean indicating whether there was a line to discard.
  def advance direct = true
    !(read_line direct).nil?
  end

  # Public: Push the String line onto the beginning of the Array of source data.
  #
  # Since this line was (assumed to be) previously retrieved through the
  # reader, it is marked as seen.
  #
  # returns nil
  def unshift_line line_to_restore
    unshift line_to_restore
    nil
  end
  alias :restore_line :unshift_line

  # Public: Push an Array of lines onto the front of the Array of source data.
  #
  # Since these lines were (assumed to be) previously retrieved through the
  # reader, they are marked as seen.
  #
  # Returns nil
  def unshift_lines lines_to_restore
    # QUESTION is it faster to use unshift(*lines_to_restore)?
    lines_to_restore.reverse_each {|line| unshift line }
    nil
  end
  alias :restore_lines :unshift_lines

  # Public: Replace the current line with the specified line.
  #
  # Calls Reader#advance to consume the current line, then calls
  # Reader#unshift to push the replacement onto the top of the
  # line stack.
  #
  # replacement  - The String line to put in place of the line at the cursor.
  #
  # Returns nothing.
  def replace_line replacement
    advance
    unshift replacement
    nil
  end

  # Public: Strip off leading blank lines in the Array of lines.
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
    return 0 if eof?

    num_skipped = 0
    # optimized code for shortest execution path
    while (next_line = peek_line)
      if next_line.chomp.empty?
        advance
        num_skipped += 1
      else
        return num_skipped
      end
    end

    num_skipped
  end

  # Public: Skip consecutive lines containing line comments and return them.
  #
  # Examples
  #   @lines
  #   => ["// foo\n", "bar\n"]
  #
  #   comment_lines = skip_comment_lines
  #   => ["// foo\n"]
  #
  #   @lines
  #   => ["bar\n"]
  #
  # Returns the Array of lines that were skipped
  def skip_comment_lines opts = {}
    return [] if eof?

    comment_lines = []
    include_blank_lines = opts[:include_blank_lines]
    while (next_line = peek_line)
      if include_blank_lines && next_line.chomp.empty?
        comment_lines << read_line
      elsif (commentish = next_line.start_with?('//')) && (match = next_line.match(REGEXP[:comment_blk]))
        comment_lines << read_line
        comment_lines.push(*(read_lines_until(:terminator => match[0], :read_last_line => true, :skip_processing => true)))
      elsif commentish && next_line.match(REGEXP[:comment])
        comment_lines << read_line
      else
        break
      end
    end

    comment_lines
  end

  # Public: Skip consecutive lines that are line comments and return them.
  def skip_line_comments
    return [] if eof?

    comment_lines = []
    # optimized code for shortest execution path
    while (next_line = peek_line)
      if next_line.match(REGEXP[:comment])
        comment_lines << read_line
      else
        break
      end
    end

    comment_lines
  end

  # Public: Advance to the end of the reader, consuming all remaining lines
  #
  # Returns nothing.
  def terminate
    @lineno += @lines.size
    @lines.clear
    @eof = true
    @look_ahead = 0
    nil
  end

  # Public: Check whether this reader is empty (contains no lines)
  #
  # Returns true if there are no more lines to peek, otherwise false.
  def eof?
    !has_more_lines?
  end
  alias :empty? :eof?

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
  #           * :read_last_line may be used to specify that the String
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
  #   reader.read_lines_until
  #   => ["First paragraph\n", "Second paragraph\n", "Open block\n"]
  def read_lines_until options = {}
    result = []
    advance if options[:skip_first_line]
    if @process_lines && options[:skip_processing]
      @process_lines = false
      restore_process_lines = true
    else
      restore_process_lines = false
    end

    has_block = block_given?
    if (terminator = options[:terminator])
      break_on_blank_lines = false
      break_on_list_continuation = false
      chomp_last_line = options.fetch :chomp_last_line, false
    else
      break_on_blank_lines = options[:break_on_blank_lines]
      break_on_list_continuation = options[:break_on_list_continuation]
      chomp_last_line = break_on_blank_lines
    end
    skip_line_comments = options[:skip_line_comments]
    line_read = false
    line_restored = false
    
    while (line = read_line)
      finish = while true
        break true if terminator && line.chomp == terminator
        # QUESTION: can we get away with line.chomp.empty? here?
        break true if break_on_blank_lines && line.chomp.empty?
        if break_on_list_continuation && line_read && line.chomp == LIST_CONTINUATION
          options[:preserve_last_line] = true
          break true
        end
        break true if has_block && (yield line)
        break false
      end

      if finish
        if options[:read_last_line]
          result << line
          line_read = true
        end
        if options[:preserve_last_line]
          restore_line line
          line_restored = true
        end
        break
      end

      unless skip_line_comments && line.start_with?('//') && line.match(REGEXP[:comment])
        result << line
        line_read = true
      end
    end

    if chomp_last_line && line_read
      result << result.pop.chomp
    end

    if restore_process_lines
      @process_lines = true
      @look_ahead -= 1 if line_restored && terminator.nil?
    end
    result
  end

  # Internal: Shift the line off the stack and increment the lineno
  def shift
    @lineno += 1
    @look_ahead -= 1 unless @look_ahead == 0
    @lines.shift
  end

  # Internal: Restore the line to the stack and decrement the lineno
  def unshift line
    @lineno -= 1
    @look_ahead += 1
    @eof = false
    @lines.unshift line
  end

  def cursor
    Cursor.new @file, @dir, @path, @lineno
  end

  # Public: Get information about the last line read, including file name and line number.
  #
  # Returns A String summary of the last line read
  def line_info
    %(#{@path}: line #{@lineno})
  end
  alias :next_line_info :line_info

  def prev_line_info
    %(#{@path}: line #{@lineno - 1})
  end

  # Public: Get a copy of the remaining Array of String lines managed by this Reader
  #
  # Returns A copy of the String Array of lines remaining in this Reader
  def lines
    @lines.dup
  end

  # Public: Get a copy of the remaining lines managed by this Reader joined as a String
  def string
    @lines.join
  end

  # Public: Get the source lines for this Reader joined as a String
  def source
    @source_lines.join
  end

  # Public: Get a summary of this Reader.
  #
  #
  # Returns A string summary of this reader, which contains the path and line information
  def to_s
    line_info
  end
end

# Public: Methods for retrieving lines from AsciiDoc source files, evaluating preprocessor
# directives as each line is read off the Array of lines.
class PreprocessorReader < Reader
  attr_reader :include_stack
  attr_reader :includes

  # Public: Initialize the PreprocessorReader object
  def initialize document, data = nil, cursor = nil
    @document = document
    super data, cursor
    include_depth_default = document.attributes.fetch('max-include-depth', 64).to_i
    include_depth_default = 0 if include_depth_default < 0
    # track both absolute depth for comparing to size of include stack and relative depth for reporting
    @maxdepth = {:abs => include_depth_default, :rel => include_depth_default}
    @include_stack = []
    @includes = (document.references[:includes] ||= [])
    @skipping = false
    @conditional_stack = []
    @include_processors = nil
  end

  def prepare_lines data, opts = {}
    if data.is_a?(String)
      if ::Asciidoctor::FORCE_ENCODING
        result = data.each_line.map {|line| "#{line.rstrip.force_encoding ::Encoding::UTF_8}#{::Asciidoctor::EOL}" }
      else
        result = data.each_line.map {|line| "#{line.rstrip}#{::Asciidoctor::EOL}" }
      end
    else
      if ::Asciidoctor::FORCE_ENCODING
        result = data.map {|line| "#{line.rstrip.force_encoding ::Encoding::UTF_8}#{::Asciidoctor::EOL}" }
      else
        result = data.map {|line| "#{line.rstrip}#{::Asciidoctor::EOL}" }
      end
    end

    # QUESTION should this work for AsciiDoc table cell content? Currently it does not.
    unless @document.nil? || !(@document.attributes.has_key? 'skip-front-matter')
      if (front_matter = skip_front_matter! result)
        @document.attributes['front-matter'] = front_matter.join.chomp
      end
    end

    # QUESTION should we chomp last line? (with or without the condense flag?)
    if opts.fetch(:condense, true)
      result.shift && @lineno += 1 while !(first = result.first).nil? && first == ::Asciidoctor::EOL
      result.pop while !(last = result.last).nil? && last == ::Asciidoctor::EOL
    end

    if (indent = opts.fetch(:indent, nil))
      Lexer.reset_block_indent! result, indent.to_i
    end

    result
  end

  def process_line line
    return line unless @process_lines

    if line.chomp.empty?
      @look_ahead += 1
      return ''
    end

    macroish = line.include?('::') && line.include?('[')
    if macroish && line.include?('if') && (match = line.match(REGEXP[:ifdef_macro]))
      # if escaped, mark as processed and return line unescaped
      if line.start_with? '\\'
        @unescape_next_line = true
        @look_ahead += 1
        line[1..-1]
      else
        if preprocess_conditional_inclusion(*match.captures)
          # move the pointer past the conditional line
          advance
          # treat next line as uncharted territory
          nil
        else
          # the line was not a valid conditional line
          # mark it as visited and return it
          @look_ahead += 1
          line
        end
      end
    elsif @skipping
      advance
      nil 
    elsif macroish && line.include?('include::') && (match = line.match(REGEXP[:include_macro]))
      # if escaped, mark as processed and return line unescaped
      if line.start_with? '\\'
        @unescape_next_line = true
        @look_ahead += 1
        line[1..-1]
      else
        # QUESTION should we strip whitespace from raw attributes in Substituters#parse_attributes? (check perf)
        if preprocess_include match[1], match[2].strip
          # peek again since the content has changed
          nil
        else
          # the line was not a valid include line and is unchanged
          # mark it as visited and return it
          @look_ahead += 1
          line
        end
      end
    else
      # optimization to inline super
      #super
      @look_ahead += 1
      line
    end
  end

  # Public: Override the Reader#peek_line method to pop the include
  # stack if the last line has been reached and there's at least
  # one include on the stack.
  #
  # Returns the next line of the source data as a String if there are lines remaining
  # in the current include context or a parent include context.
  # Returns nil if there are no more lines remaining and the include stack is empty.
  def peek_line direct = false
    if (line = super)
      line
    elsif @include_stack.empty?
      nil
    else
      pop_include
      peek_line direct
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
  # returns a Boolean indicating whether the cursor should be advanced
  def preprocess_conditional_inclusion directive, target, delimiter, text
    # must have a target before brackets if ifdef or ifndef
    # must not have text between brackets if endif
    # don't honor match if it doesn't meet this criteria
    # QUESTION should we warn for these bogus declarations?
    if ((directive == 'ifdef' || directive == 'ifndef') && target.empty?) ||
        (directive == 'endif' && !text.nil?)
      return false
    end

    if directive == 'endif'
      stack_size = @conditional_stack.size
      if stack_size > 0
        pair = @conditional_stack.last
        if target.empty? || target == pair[:target]
          @conditional_stack.pop
          @skipping = @conditional_stack.empty? ? false : @conditional_stack.last[:skipping]
        else
          warn "asciidoctor: ERROR: #{line_info}: mismatched macro: endif::#{target}[], expected endif::#{pair[:target]}[]"
        end
      else
        warn "asciidoctor: ERROR: #{line_info}: unmatched macro: endif::#{target}[]"
      end
      return true
    end

    skip = false
    unless @skipping
      # QUESTION any way to wrap ifdef & ifndef logic up together?
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
          return false
        end

        lhs = resolve_expr_val expr_match[1]
        # regex enforces a restrict set of math-related operations
        op = expr_match[2]
        rhs = resolve_expr_val expr_match[3]

        skip = !(lhs.send op.to_sym, rhs)
      end
    end

    # conditional inclusion block
    if directive == 'ifeval' || text.nil?
      @skipping = true if skip
      @conditional_stack << {:target => target, :skip => skip, :skipping => @skipping}
    # single line conditional inclusion
    else
      unless @skipping || skip
        # FIXME slight hack to skip past conditional line
        # but keep our synthetic line marked as processed
        conditional_line = peek_line true
        replace_line "#{text.rstrip}#{::Asciidoctor::EOL}"
        unshift conditional_line
        return true
      end
    end

    true
  end

  # Internal: Preprocess the directive (macro) to include the target document.
  #
  # Preprocess the directive to include the target document. The scenarios
  # are as follows:
  #
  # If SafeMode is SECURE or greater, the directive is ignore and the include
  # directive line is emitted verbatim.
  #
  # Otherwise, if an include processor is specified pass the target and
  # attributes to that processor and expect an Array of String lines in return.
  #
  # Otherwise, if the max depth is greater than 0, and is not exceeded by the
  # stack size, normalize the target path and read the lines onto the beginning
  # of the Array of source data.
  #
  # If none of the above apply, emit the include directive line verbatim.
  #
  # target - The name of the source document to include as specified in the
  #          target slot of the include::[] macro
  #
  # returns a Boolean indicating whether the line under the cursor has changed.
  def preprocess_include target, raw_attributes
    target = @document.sub_attributes target, :attribute_missing => 'drop-line'
    if target.empty?
      if @document.attributes.fetch('attribute-missing', COMPLIANCE[:attribute_missing]) == 'skip'
        false
      else
        advance
        true
      end
    # assume that if an include processor is given, the developer wants
    # to handle when and how to process the include
    elsif include_processors? &&
        (processor = @include_processors.find {|candidate| candidate.handles? target })
      advance
      # QUESTION should we use @document.parse_attribues?
      processor.process self, target, AttributeList.new(raw_attributes).parse
      true
    # if running in SafeMode::SECURE or greater, don't process this directive
    # however, be friendly and at least make it a link to the source document
    elsif @document.safe >= SafeMode::SECURE
      replace_line "link:#{target}[]#{::Asciidoctor::EOL}"
      # TODO make creating the output target a helper method
      #output_target = %(#{File.join(File.dirname(target), File.basename(target, File.extname(target)))}#{@document.attributes['outfilesuffix']})
      #unshift "link:#{output_target}[]#{::Asciidoctor::EOL}"
      true
    elsif (abs_maxdepth = @maxdepth[:abs]) > 0 && @include_stack.size >= abs_maxdepth
      warn %(asciidoctor: ERROR: #{line_info}: maximum include depth of #{@maxdepth[:rel]} exceeded)
      false
    elsif abs_maxdepth > 0
      if target.include?(':') && target.match(REGEXP[:uri_sniff])
        unless @document.attributes.has_key? 'allow-uri-read'
          replace_line "link:#{target}[]#{::Asciidoctor::EOL}"
          return true
        end

        target_type = :uri
        include_file = path = target
        if @document.attributes.has_key? 'cache-uri'
          # caching requires the open-uri-cached gem to be installed
          # processing will be automatically aborted if these libraries can't be opened
          Helpers.require_library 'open-uri/cached', 'open-uri-cached'
        else
          Helpers.require_library 'open-uri'
        end
      else
        target_type = :file
        # include file is resolved relative to dir of current include, or base_dir if within original docfile
        include_file = @document.normalize_system_path(target, @dir, nil, :target_name => 'include file')
        if !File.file?(include_file)
          warn "asciidoctor: WARNING: #{line_info}: include file not found: #{include_file}"
          advance
          return true
        end
        #path = @document.relative_path include_file
        path = PathResolver.new.relative_path include_file, @document.base_dir
      end

      inc_lines = nil
      tags = nil
      attributes = {}
      if !raw_attributes.empty?
        # QUESTION should we use @document.parse_attribues?
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
        elsif attributes.has_key? 'tag'
          tags = [attributes['tag']]
        elsif attributes.has_key? 'tags'
          tags = attributes['tags'].split(REGEXP[:ssv_or_csv_delim]).uniq
        end
      end
      if !inc_lines.nil?
        if !inc_lines.empty?
          selected = []
          inc_line_offset = 0
          inc_lineno = 0
          begin
            open(include_file) do |f|
              f.each_line do |l|
                inc_lineno += 1
                take = inc_lines.first
                if take.is_a?(Float) && take.infinite?
                  selected.push l
                  inc_line_offset = inc_lineno if inc_line_offset == 0
                else
                  if f.lineno == take
                    selected.push l
                    inc_line_offset = inc_lineno if inc_line_offset == 0
                    inc_lines.shift
                  end
                  break if inc_lines.empty?
                end
              end
            end
          rescue
            warn "asciidoctor: WARNING: #{line_info}: include #{target_type} not readable: #{include_file}"
            advance
            return true
          end
          advance
          # FIXME not accounting for skipped lines in reader line numbering
          push_include selected, include_file, path, inc_line_offset, attributes
        end
      elsif !tags.nil?
        if !tags.empty?
          selected = []
          inc_line_offset = 0
          inc_lineno = 0
          active_tag = nil
          begin
            open(include_file) do |f|
              f.each_line do |l|
                inc_lineno += 1
                # must force encoding here since we're performing String operations on line
                l.force_encoding(::Encoding::UTF_8) if ::Asciidoctor::FORCE_ENCODING
                if !active_tag.nil?
                  if l.include?("end::#{active_tag}[]")
                    active_tag = nil
                  else
                    selected.push l
                    inc_line_offset = inc_lineno if inc_line_offset == 0
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
            warn "asciidoctor: WARNING: #{line_info}: include #{target_type} not readable: #{include_file}"
            advance
            return true
          end
          advance
          # FIXME not accounting for skipped lines in reader line numbering
          push_include selected, include_file, path, inc_line_offset, attributes
        end
      else
        begin
          advance
          push_include open(include_file) {|f| f.read }, include_file, path, 1, attributes
        rescue
          warn "asciidoctor: WARNING: #{line_info}: include #{target_type} not readable: #{include_file}"
          advance
          return true
        end
      end
      true
    else
      false
    end
  end

  def push_include data, file = nil, path = nil, lineno = 1, attributes = {}
    @include_stack << [@lines, @file, @dir, @path, @lineno, @maxdepth, @process_lines]
    @includes << Helpers.rootname(path)
    @file = file
    @dir = File.dirname file
    @path = path
    @lineno = lineno
    # NOTE only process lines in AsciiDoc files
    @process_lines = ASCIIDOC_EXTENSIONS[File.extname(@file)]
    if attributes.has_key? 'depth'
      depth = attributes['depth'].to_i
      depth = 1 if depth <= 0
      @maxdepth = {:abs => (@include_stack.size - 1) + depth, :rel => depth}
    end
    # effectively fill the buffer
    @lines = prepare_lines data, :condense => false, :indent => attributes['indent']
    # FIXME kind of a hack
    #Document::AttributeEntry.new('infile', @file).save_to_next_block @document
    #Document::AttributeEntry.new('indir', File.dirname(@file)).save_to_next_block @document
    if @lines.empty?
      pop_include
    else
      @eof = false
      @look_ahead = 0
    end
  end

  def pop_include
    if @include_stack.size > 0
      @lines, @file, @dir, @path, @lineno, @maxdepth, @process_lines = @include_stack.pop
      # FIXME kind of a hack
      #Document::AttributeEntry.new('infile', @file).save_to_next_block @document
      #Document::AttributeEntry.new('indir', File.dirname(@file)).save_to_next_block @document
      @eof = @lines.empty?
      @look_ahead = 0
    end
  end

  def include_depth
    @include_stack.size 
  end

  def exceeded_max_depth?
    if (abs_maxdepth = @maxdepth[:abs]) > 0 && @include_stack.size >= abs_maxdepth
      @maxdepth[:rel]
    else
      false
    end
  end

  # TODO Document this override
  # also, we now have the field in the super class, so perhaps
  # just implement the logic there?
  def shift
    if @unescape_next_line
      @unescape_next_line = false
      super[1..-1]
    else
      super
    end
  end

  # Private: Ignore front-matter, commonly used in static site generators
  def skip_front_matter! data, increment_linenos = true
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

  # Private: Resolve the value of one side of the expression
  #
  # Examples
  #
  #   expr = '"value"'
  #   resolve_expr_val(expr)
  #   # => "value"
  #
  #   expr = '"value'
  #   resolve_expr_val(expr)
  #   # => "\"value"
  #
  #   expr = '"{undefined}"'
  #   resolve_expr_val(expr)
  #   # => ""
  #
  #   expr = '{undefined}'
  #   resolve_expr_val(expr)
  #   # => nil
  #
  #   expr = '2'
  #   resolve_expr_val(expr)
  #   # => 2
  #
  #   @document.attributes['name'] = 'value'
  #   expr = '"{name}"'
  #   resolve_expr_val(expr)
  #   # => "value"
  #
  # Returns The value of the expression, coerced to the appropriate type
  def resolve_expr_val(str)
    val = str
    type = nil

    if val.start_with?('"') && val.end_with?('"') ||
        val.start_with?('\'') && val.end_with?('\'')
      type = :string
      val = val[1...-1]
    end

    # QUESTION should we substitute first?
    if val.include? '{'
      val = @document.sub_attributes val
    end

    unless type == :string
      if val.empty?
        val = nil
      elsif val.strip.empty?
        val = ' '
      elsif val == 'true'
        val = true
      elsif val == 'false'
        val = false
      elsif val.include?('.')
        val = val.to_f
      else
        # fallback to coercing to integer, since we
        # require string values to be explicitly quoted
        val = val.to_i
      end
    end

    val
  end

  def include_processors?
    if @include_processors.nil?
      if @document.extensions? && @document.extensions.include_processors?
        @include_processors = @document.extensions.load_include_processors(@document)
        true
      else
        @include_processors = false
        false
      end
    else
      @include_processors != false
    end
  end

  def to_s
    %(#{self.class.name} [path: #{@path}, line #: #{@lineno}, include depth: #{@include_stack.size}, include stack: [#{@include_stack.map {|inc| inc.to_s}.join ', '}]])
  end
end
end
