# encoding: UTF-8
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

    alias to_s line_info
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
  def initialize data = nil, cursor = nil, opts = {}
    if !cursor
      @file = @dir = nil
      @path = '<stdin>'
      @lineno = 1 # IMPORTANT lineno assignment must proceed prepare_lines call!
    elsif ::String === cursor
      @file = cursor
      @dir, @path = ::File.split @file
      @lineno = 1 # IMPORTANT lineno assignment must proceed prepare_lines call!
    else
      @file = cursor.file
      @dir = cursor.dir
      @path = cursor.path || '<stdin>'
      if @file
        unless @dir
          # REVIEW might to look at this assignment closer
          @dir = ::File.dirname @file
          @dir = nil if @dir == '.' # right?
        end

        unless cursor.path
          @path = ::File.basename @file
        end
      end
      @lineno = cursor.lineno || 1 # IMPORTANT lineno assignment must proceed prepare_lines call!
    end
    @lines = data ? (prepare_lines data, opts) : []
    @source_lines = @lines.dup
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
  # data - A String Array of input data to be normalized
  # opts - A Hash of options to control what cleansing is done
  #
  # Returns The String lines extracted from the data
  def prepare_lines data, opts = {}
    if ::String === data
      if opts[:normalize]
        Helpers.normalize_lines_from_string data
      else
        data.split LF, -1
      end
    else
      if opts[:normalize]
        Helpers.normalize_lines_array data
      else
        data.dup
      end
    end
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
    if @lines.empty?
      @look_ahead = 0
      false
    else
      true
    end
  end

  # Public: Check whether this reader is empty (contains no lines)
  #
  # Returns true if there are no more lines to peek, otherwise false.
  def empty?
    if @lines.empty?
      @look_ahead = 0
      true
    else
      false
    end
  end
  alias eof? empty?

  # Public: Peek at the next line and check if it's empty (i.e., whitespace only)
  #
  # This method Does not consume the line from the stack.
  #
  # Returns True if the there are no more lines or if the next line is empty
  def next_line_empty?
    peek_line.nil_or_empty?
  end

  # Public: Peek at the next line of source data. Processes the line if not
  # already marked as processed, but does not consume it.
  #
  # This method will probe the reader for more lines. If there is a next line
  # that has not previously been visited, the line is passed to the
  # Reader#process_line method to be initialized. This call gives
  # sub-classes the opportunity to do preprocessing. If the return value of
  # the Reader#process_line is nil, the data is assumed to be changed and
  # Reader#peek_line is invoked again to perform further processing.
  #
  # If has_more_lines? is called immediately before peek_line, the direct flag
  # is implicitly true (since the line is flagged as visited).
  #
  # direct  - A Boolean flag to bypasses the check for more lines and immediately
  #           returns the first element of the internal @lines Array. (default: false)
  #
  # Returns the next line of the source data as a String if there are lines remaining.
  # Returns nothing if there is no more data.
  def peek_line direct = false
    if direct || @look_ahead > 0
      @unescape_next_line ? @lines[0][1..-1] : @lines[0]
    elsif @lines.empty?
      @look_ahead = 0
      nil
    else
      # FIXME the problem with this approach is that we aren't
      # retaining the modified line (hence the @unescape_next_line tweak)
      # perhaps we need a stack of proxied lines
      (line = process_line @lines[0]) ? line : peek_line
    end
  end

  # Public: Peek at the next multiple lines of source data. Processes the lines if not
  # already marked as processed, but does not consume them.
  #
  # This method delegates to Reader#read_line to process and collect the line, then
  # restores the lines to the stack before returning them. This allows the lines to
  # be processed and marked as such so that subsequent reads will not need to process
  # the lines again.
  #
  # num    - The positive Integer number of lines to peek (must be greater than 0).
  # direct - A Boolean indicating whether processing should be disabled when reading lines
  #
  # Returns A String Array of the next multiple lines of source data, or an empty Array
  # if there are no more lines in this Reader.
  def peek_lines num, direct = false
    old_look_ahead = @look_ahead
    result = []
    num.times do
      if (line = direct ? shift : read_line)
        result << line
      else
        @lineno -= 1 if direct
        break
      end
    end

    unless result.empty?
      unshift_all result
      @look_ahead = old_look_ahead if direct
    end

    result
  end

  # Public: Get the next line of source data. Consumes the line returned.
  #
  # Returns the String of the next line of the source data if data is present.
  # Returns nothing if there is no more data.
  def read_line
    # has_more_lines? triggers preprocessor
    shift if @look_ahead > 0 || has_more_lines?
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
    # has_more_lines? triggers preprocessor
    while has_more_lines?
      lines << shift
    end
    lines
  end
  alias readlines read_lines

  # Public: Get the remaining lines of source data joined as a String.
  #
  # Delegates to Reader#read_lines, then joins the result.
  #
  # Returns the lines read joined as a String
  def read
    read_lines * LF
  end

  # Public: Advance to the next line by discarding the line at the front of the stack
  #
  # Returns a Boolean indicating whether there was a line to discard.
  def advance
    shift ? true : false
  end

  # Public: Push the String line onto the beginning of the Array of source data.
  #
  # A line pushed on the reader using this method is not processed again. The
  # method assumes the line was previously retrieved from the reader or does
  # not otherwise contain preprocessor directives. Therefore, it is marked as
  # processed immediately.
  #
  # line_to_restore - the line to restore onto the stack
  #
  # Returns nothing.
  def unshift_line line_to_restore
    unshift line_to_restore
    nil
  end
  alias restore_line unshift_line

  # Public: Push an Array of lines onto the front of the Array of source data.
  #
  # Lines pushed on the reader using this method are not processed again. The
  # method assumes the lines were previously retrieved from the reader or do
  # not otherwise contain preprocessor directives. Therefore, they are marked
  # as processed immediately.
  #
  # Returns nothing.
  def unshift_lines lines_to_restore
    unshift_all lines_to_restore
    nil
  end
  alias restore_lines unshift_lines

  # Public: Replace the next line with the specified line.
  #
  # Calls Reader#advance to consume the current line, then calls
  # Reader#unshift to push the replacement onto the top of the
  # line stack.
  #
  # replacement - The String line to put in place of the next line (i.e., the line at the cursor).
  #
  # Returns nothing.
  def replace_next_line replacement
    shift
    unshift replacement
    nil
  end
  # deprecated
  alias replace_line replace_next_line

  # Public: Skip blank lines at the cursor.
  #
  # Examples
  #
  #   reader.lines
  #   => ["", "", "Foo", "Bar", ""]
  #   reader.skip_blank_lines
  #   => 2
  #   reader.lines
  #   => ["Foo", "Bar", ""]
  #
  # Returns the [Integer] number of lines skipped or nothing if all lines have
  # been consumed (even if lines were skipped by this method).
  def skip_blank_lines
    return if empty?

    num_skipped = 0
    # optimized code for shortest execution path
    while (next_line = peek_line)
      if next_line.empty?
        shift
        num_skipped += 1
      else
        return num_skipped
      end
    end
  end

  # Public: Skip consecutive lines containing line comments and return them.
  #
  # Examples
  #   @lines
  #   => ["// foo", "bar"]
  #
  #   comment_lines = skip_comment_lines
  #   => ["// foo"]
  #
  #   @lines
  #   => ["bar"]
  #
  # Returns the Array of lines that were skipped
  def skip_comment_lines
    return [] if empty?

    comment_lines = []
    while (next_line = peek_line) && !next_line.empty?
      if next_line.start_with? '//'
        if next_line.start_with? '///'
          if (ll = next_line.length) > 3 && next_line == '/' * ll
            comment_lines << shift
            comment_lines.push(*(read_lines_until(:terminator => next_line, :read_last_line => true, :skip_processing => true)))
          else
            break
          end
        else
          comment_lines << shift
        end
      else
        break
      end
    end

    comment_lines
  end

  # Public: Skip consecutive lines that are line comments and return them.
  #
  # This method assumes the reader only contains simple lines (no blocks).
  def skip_line_comments
    return [] if empty?

    comment_lines = []
    # optimized code for shortest execution path
    while (next_line = peek_line) && !next_line.empty?
      if (next_line.start_with? '//')
        comment_lines << shift
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
    @look_ahead = 0
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
  #           * :read_last_line may be used to specify that the String
  #               causing the method to stop processing lines should be
  #               included in the lines being returned
  #
  # Returns the Array of lines forming the next segment.
  #
  # Examples
  #
  #   data = [
  #     "First line\n",
  #     "Second line\n",
  #     "\n",
  #     "Third line\n",
  #   ]
  #   reader = Reader.new data, nil, :normalize => true
  #
  #   reader.read_lines_until
  #   => ["First line", "Second line"]
  def read_lines_until options = {}
    result = []
    shift if options[:skip_first_line]
    if @process_lines && options[:skip_processing]
      @process_lines = false
      restore_process_lines = true
    else
      restore_process_lines = false
    end

    if (terminator = options[:terminator])
      break_on_blank_lines = false
      break_on_list_continuation = false
    else
      break_on_blank_lines = options[:break_on_blank_lines]
      break_on_list_continuation = options[:break_on_list_continuation]
    end
    skip_comments = options[:skip_line_comments]
    line_read = false
    line_restored = false

    complete = false
    while !complete && (line = read_line)
      complete = while true
        break true if terminator && line == terminator
        # QUESTION: can we get away with line.empty? here?
        break true if break_on_blank_lines && line.empty?
        if break_on_list_continuation && line_read && line == LIST_CONTINUATION
          options[:preserve_last_line] = true
          break true
        end
        break true if block_given? && (yield line)
        break false
      end

      if complete
        if options[:read_last_line]
          result << line
          line_read = true
        end
        if options[:preserve_last_line]
          unshift line
          line_restored = true
        end
      else
        unless skip_comments && (line.start_with? '//') && !(line.start_with? '///')
          result << line
          line_read = true
        end
      end
    end

    if restore_process_lines
      @process_lines = true
      @look_ahead -= 1 if line_restored && !terminator
    end
    result
  end

  # Internal: Shift the line off the stack and increment the lineno
  #
  # This method can be used directly when you've already called peek_line
  # and determined that you do, in fact, want to pluck that line off the stack.
  # Use read_line if the line hasn't (or many not have been) visited yet.
  #
  # Returns The String line at the top of the stack
  def shift
    @lineno += 1
    @look_ahead -= 1 unless @look_ahead == 0
    @lines.shift
  end

  # Internal: Restore the line to the stack and decrement the lineno
  def unshift line
    @lineno -= 1
    @look_ahead += 1
    @lines.unshift line
  end

  # Internal: Restore the lines to the stack and decrement the lineno
  def unshift_all lines
    @lineno -= lines.size
    @look_ahead += lines.size
    @lines.unshift(*lines)
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
  alias next_line_info line_info

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
    @lines * LF
  end

  # Public: Get the source lines for this Reader joined as a String
  def source
    @source_lines * LF
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
  def initialize document, data = nil, cursor = nil, opts = {}
    @document = document
    super data, cursor, opts
    include_depth_default = document.attributes.fetch('max-include-depth', 64).to_i
    include_depth_default = 0 if include_depth_default < 0
    # track both absolute depth for comparing to size of include stack and relative depth for reporting
    @maxdepth = {:abs => include_depth_default, :rel => include_depth_default}
    @include_stack = []
    @includes = document.catalog[:includes]
    @skipping = false
    @conditional_stack = []
    @include_processor_extensions = nil
  end

  def prepare_lines data, opts = {}
    result = super

    # QUESTION should this work for AsciiDoc table cell content? Currently it does not.
    if @document && (@document.attributes.key? 'skip-front-matter')
      if (front_matter = skip_front_matter! result)
        @document.attributes['front-matter'] = front_matter * LF
      end
    end

    if opts.fetch :condense, true
      result.shift && @lineno += 1 while (first = result[0]) && first.empty?
      result.pop while (last = result[-1]) && last.empty?
    end

    if opts[:indent]
      Parser.adjust_indentation! result, opts[:indent], (@document.attr 'tabsize')
    end

    result
  end

  def process_line line
    return line unless @process_lines

    if line.empty?
      @look_ahead += 1
      return line
    end

    # NOTE highly optimized
    if line.end_with?(']') && !line.start_with?('[') && line.include?('::')
      if (line.include? 'if') && ConditionalDirectiveRx =~ line
        # if escaped, mark as processed and return line unescaped
        if $1 == '\\'
          @unescape_next_line = true
          @look_ahead += 1
          line[1..-1]
        elsif preprocess_conditional_directive $2, $3, $4, $5
          # move the pointer past the conditional line
          shift
          # treat next line as uncharted territory
          nil
        else
          # the line was not a valid conditional line
          # mark it as visited and return it
          @look_ahead += 1
          line
        end
      elsif @skipping
        shift
        nil
      elsif (line.start_with? 'inc', '\\inc') && IncludeDirectiveRx =~ line
        # if escaped, mark as processed and return line unescaped
        if $1 == '\\'
          @unescape_next_line = true
          @look_ahead += 1
          line[1..-1]
        # QUESTION should we strip whitespace from raw attributes in Substitutors#parse_attributes? (check perf)
        elsif preprocess_include_directive $2, $3.strip
          # peek again since the content has changed
          nil
        else
          # the line was not a valid include line and is unchanged
          # mark it as visited and return it
          @look_ahead += 1
          line
        end
      else
        # NOTE optimization to inline super
        @look_ahead += 1
        line
      end
    elsif @skipping
      shift
      nil
    else
      # NOTE optimization to inline super
      @look_ahead += 1
      line
    end
  end

  # (see Reader#has_more_lines?)
  def has_more_lines?
    peek_line ? true : false
  end

  # (see Reader#empty?)
  def empty?
    peek_line ? false : true
  end
  alias eof? empty?

  # Public: Override the Reader#peek_line method to pop the include
  # stack if the last line has been reached and there's at least
  # one include on the stack.
  #
  # Returns the next line of the source data as a String if there are lines remaining
  # in the current include context or a parent include context.
  # Returns nothing if there are no more lines remaining and the include stack is empty.
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

  # Internal: Preprocess the directive to conditionally include or exclude content.
  #
  # Preprocess the conditional directive (ifdef, ifndef, ifeval, endif) under
  # the cursor. If Reader is currently skipping content, then simply track the
  # open and close delimiters of any nested conditional blocks. If Reader is
  # not skipping, mark whether the condition is satisfied and continue
  # preprocessing recursively until the next line of available content is
  # found.
  #
  # keyword   - The conditional inclusion directive (ifdef, ifndef, ifeval, endif)
  # target    - The target, which is the name of one or more attributes that are
  #             used in the condition (blank in the case of the ifeval directive)
  # delimiter - The conditional delimiter for multiple attributes ('+' means all
  #             attributes must be defined or undefined, ',' means any of the attributes
  #             can be defined or undefined.
  # text      - The text associated with this directive (occurring between the square brackets)
  #             Used for a single-line conditional block in the case of the ifdef or
  #             ifndef directives, and for the conditional expression for the ifeval directive.
  #
  # Returns a Boolean indicating whether the cursor should be advanced
  def preprocess_conditional_directive keyword, target, delimiter, text
    # attributes are case insensitive
    target = target.downcase unless (no_target = target.empty?)

    # must have a target before brackets if ifdef or ifndef
    # must not have text between brackets if endif
    # skip line if it doesn't meet this criteria
    # QUESTION should we warn for these bogus declarations?
    return false if (no_target && (keyword == 'ifdef' || keyword == 'ifndef')) || (text && keyword == 'endif')

    if keyword == 'endif'
      if @conditional_stack.empty?
        warn %(asciidoctor: ERROR: #{line_info}: unmatched macro: endif::#{target}[])
      elsif no_target || target == (pair = @conditional_stack[-1])[:target]
        @conditional_stack.pop
        @skipping = @conditional_stack.empty? ? false : @conditional_stack[-1][:skipping]
      else
        warn %(asciidoctor: ERROR: #{line_info}: mismatched macro: endif::#{target}[], expected endif::#{pair[:target]}[])
      end
      return true
    end

    if @skipping
      skip = false
    else
      # QUESTION any way to wrap ifdef & ifndef logic up together?
      case keyword
      when 'ifdef'
        case delimiter
        when ','
          # skip if no attribute is defined
          skip = target.split(',', -1).none? {|name| @document.attributes.key? name }
        when '+'
          # skip if any attribute is undefined
          skip = target.split('+', -1).any? {|name| !@document.attributes.key? name }
        else
          # if the attribute is undefined, then skip
          skip = !@document.attributes.key?(target)
        end
      when 'ifndef'
        case delimiter
        when ','
          # skip if any attribute is defined
          skip = target.split(',', -1).any? {|name| @document.attributes.key? name }
        when '+'
          # skip if all attributes are defined
          skip = target.split('+', -1).all? {|name| @document.attributes.key? name }
        else
          # if the attribute is defined, then skip
          skip = @document.attributes.key?(target)
        end
      when 'ifeval'
        # the text in brackets must match an expression
        # don't honor match if it doesn't meet this criteria
        return false unless no_target && EvalExpressionRx =~ text.strip

        # NOTE save values eagerly for Ruby 1.8.7 compat
        lhs, op, rhs = $1, $2, $3
        lhs = resolve_expr_val lhs
        rhs = resolve_expr_val rhs

        # regex enforces a restricted set of math-related operations
        if op == '!='
          skip = lhs.send :==, rhs
        else
          skip = !(lhs.send op.to_sym, rhs)
        end
      end
    end

    # conditional inclusion block
    if keyword == 'ifeval' || !text
      @skipping = true if skip
      @conditional_stack << {:target => target, :skip => skip, :skipping => @skipping}
    # single line conditional inclusion
    else
      unless @skipping || skip
        replace_next_line text.rstrip
        # HACK push dummy line to stand in for the opening conditional directive that's subsequently dropped
        unshift ''
        # NOTE force line to be processed again if it looks like an include directive
        # QUESTION should we just call preprocess_include_directive here?
        @look_ahead -= 1 if text.start_with? 'include::'
      end
    end

    true
  end

  # Internal: Preprocess the directive to include lines from another document.
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
  #          target slot of the include::[] directive
  #
  # Returns a Boolean indicating whether the line under the cursor has changed.
  def preprocess_include_directive raw_target, raw_attributes
    if ((target = raw_target).include? ATTR_REF_HEAD) &&
        (target = @document.sub_attributes raw_target, :attribute_missing => 'drop-line').empty?
      shift
      if @document.attributes.fetch('attribute-missing', Compliance.attribute_missing) == 'skip'
        unshift %(Unresolved directive in #{@path} - include::#{raw_target}[#{raw_attributes}])
      end
      true
    elsif include_processors? && (ext = @include_processor_extensions.find {|candidate| candidate.instance.handles? target })
      shift
      # FIXME parse attributes only if requested by extension
      ext.process_method[@document, self, target, AttributeList.new(raw_attributes).parse]
      true
    # if running in SafeMode::SECURE or greater, don't process this directive
    # however, be friendly and at least make it a link to the source document
    elsif @document.safe >= SafeMode::SECURE
      # FIXME we don't want to use a link macro if we are in a verbatim context
      replace_next_line %(link:#{target}[])
      true
    elsif (abs_maxdepth = @maxdepth[:abs]) > 0
      if @include_stack.size >= abs_maxdepth
        warn %(asciidoctor: ERROR: #{line_info}: maximum include depth of #{@maxdepth[:rel]} exceeded)
        return false
      end
      if ::RUBY_ENGINE_OPAL && ::JAVASCRIPT_IO_MODULE == 'xmlhttprequest'
        # NOTE resolves uri relative to currently loaded document
        # NOTE we defer checking if file exists and catch the 404 error if it does not
        target_type = :file
        inc_path = relpath = @include_stack.empty? && ::Dir.pwd == @document.base_dir ? target : (::File.join @dir, target)
      elsif Helpers.uriish? target
        unless @document.attributes.key? 'allow-uri-read'
          replace_next_line %(link:#{target}[])
          return true
        end

        target_type = :uri
        inc_path = relpath = target
        if @document.attributes.key? 'cache-uri'
          # caching requires the open-uri-cached gem to be installed
          # processing will be automatically aborted if these libraries can't be opened
          Helpers.require_library 'open-uri/cached', 'open-uri-cached' unless defined? ::OpenURI::Cache
        elsif !::RUBY_ENGINE_OPAL
          # autoload open-uri
          ::OpenURI
        end
      else
        target_type = :file
        # include file is resolved relative to dir of current include, or base_dir if within original docfile
        inc_path = @document.normalize_system_path target, @dir, nil, :target_name => 'include file'
        unless ::File.file? inc_path
          warn %(asciidoctor: WARNING: #{line_info}: include file not found: #{inc_path})
          replace_next_line %(Unresolved directive in #{@path} - include::#{target}[#{raw_attributes}])
          return true
        end
        # NOTE relpath is the path relative to the root document (or base_dir, if set)
        # QUESTION should we move relative_path method to Document
        relpath = (@path_resolver ||= PathResolver.new).relative_path inc_path, @document.base_dir
      end

      inc_linenos, inc_tags, attributes = nil, nil, {}
      unless raw_attributes.empty?
        # QUESTION should we use @document.parse_attribues?
        attributes = AttributeList.new(raw_attributes).parse
        if attributes.key? 'lines'
          inc_linenos = []
          attributes['lines'].split(DataDelimiterRx).each do |linedef|
            if linedef.include?('..')
              from, to = linedef.split('..', 2).map {|it| it.to_i }
              if to == -1
                inc_linenos << from
                inc_linenos << 1.0/0.0
              else
                inc_linenos.concat ::Range.new(from, to).to_a
              end
            else
              inc_linenos << linedef.to_i
            end
          end
          inc_linenos = inc_linenos.empty? ? nil : inc_linenos.sort.uniq
        elsif attributes.key? 'tag'
          unless (tag = attributes['tag']).empty?
            if tag.start_with? '!'
              inc_tags = { (tag.slice 1, tag.length) => false } unless tag == '!'
            else
              inc_tags = { tag => true }
            end
          end
        elsif attributes.key? 'tags'
          inc_tags = {}
          attributes['tags'].split(DataDelimiterRx).each do |tagdef|
            if tagdef.start_with? '!'
              inc_tags[tagdef.slice 1, tagdef.length] = false unless tagdef == '!'
            else
              inc_tags[tagdef] = true
            end unless tagdef.empty?
          end
          inc_tags = nil if inc_tags.empty?
        end
      end

      if inc_linenos
        inc_lines, inc_offset, inc_lineno = [], nil, 0
        begin
          open(inc_path, 'r') do |f|
            f.each_line do |l|
              inc_lineno += 1
              select = inc_linenos[0]
              if ::Float === select && select.infinite?
                # NOTE record line where we started selecting
                inc_offset ||= inc_lineno
                inc_lines << l
              else
                if inc_lineno == select
                  # NOTE record line where we started selecting
                  inc_offset ||= inc_lineno
                  inc_lines << l
                  inc_linenos.shift
                end
                break if inc_linenos.empty?
              end
            end
          end
        rescue
          warn %(asciidoctor: WARNING: #{line_info}: include #{target_type} not readable: #{inc_path})
          replace_next_line %(Unresolved directive in #{@path} - include::#{target}[#{raw_attributes}])
          return true
        end
        shift
        # FIXME not accounting for skipped lines in reader line numbering
        push_include inc_lines, inc_path, relpath, inc_offset, attributes if inc_offset
      elsif inc_tags
        inc_lines, inc_offset, inc_lineno, tag_stack, tags_used, active_tag = [], nil, 0, [], ::Set.new, nil
        if inc_tags.key? '**'
          if inc_tags.key? '*'
            select = base_select = (inc_tags.delete '**')
            wildcard = inc_tags.delete '*'
          else
            select = base_select = wildcard = (inc_tags.delete '**')
          end
        else
          select = base_select = !(inc_tags.value? true)
          wildcard = inc_tags.delete '*'
        end
        if (ext_idx = inc_path.rindex '.') && (circ_cmt = CIRCUMFIX_COMMENTS[inc_path.slice ext_idx, inc_path.length])
          cmt_suffix_len = (tag_suffix = %([] #{circ_cmt[:suffix]})).length - 2
        end
        begin
          open(inc_path, 'r') do |f|
            f.each_line do |l|
              inc_lineno += 1
              # must force encoding since we're performing String operations on line
              l.force_encoding ::Encoding::UTF_8 if FORCE_ENCODING
              if (((tl = l.chomp).end_with? '[]') ||
                  (tag_suffix && (tl.end_with? tag_suffix) && (tl = tl.slice 0, tl.length - cmt_suffix_len))) &&
                  TagDirectiveRx =~ tl
                if $1 # end tag
                  if (this_tag = $2) == active_tag
                    tag_stack.pop
                    active_tag, select = tag_stack.empty? ? [nil, base_select] : tag_stack[-1]
                  elsif inc_tags.key? this_tag
                    if (idx = tag_stack.rindex {|key, _| key == this_tag })
                      idx == 0 ? tag_stack.shift : (tag_stack.delete_at idx)
                      warn %(asciidoctor: WARNING: #{target}: line #{inc_lineno}: mismatched end tag in include: expected #{active_tag}, found #{this_tag})
                    else
                      warn %(asciidoctor: WARNING: #{target}: line #{inc_lineno}: unexpected end tag in include: #{this_tag})
                    end
                  end
                elsif inc_tags.key?(this_tag = $2)
                  tags_used << this_tag
                  # QUESTION should we prevent tag from being selected when enclosing tag is excluded?
                  tag_stack << [(active_tag = this_tag), (select = inc_tags[this_tag])]
                elsif !wildcard.nil?
                  select = active_tag && !select ? false : wildcard
                  tag_stack << [(active_tag = this_tag), select]
                end
              elsif select
                # NOTE record the line where we started selecting
                inc_offset ||= inc_lineno
                inc_lines << l
              end
            end
          end
        rescue
          warn %(asciidoctor: WARNING: #{line_info}: include #{target_type} not readable: #{inc_path})
          replace_next_line %(Unresolved directive in #{@path} - include::#{target}[#{raw_attributes}])
          return true
        end
        unless (missing_tags = inc_tags.keys.to_a - tags_used.to_a).empty?
          warn %(asciidoctor: WARNING: #{line_info}: tag#{missing_tags.size > 1 ? 's' : nil} '#{missing_tags * ','}' not found in include #{target_type}: #{inc_path})
        end
        shift
        # FIXME not accounting for skipped lines in reader line numbering
        push_include inc_lines, inc_path, relpath, inc_offset, attributes if inc_offset
      else
        begin
          # NOTE read content first so that we only advance cursor if IO operation succeeds
          inc_content = target_type == :file ? (::IO.read inc_path) : open(inc_path, 'r') {|f| f.read }
          shift
          push_include inc_content, inc_path, relpath, 1, attributes
        rescue
          warn %(asciidoctor: WARNING: #{line_info}: include #{target_type} not readable: #{inc_path})
          replace_next_line %(Unresolved directive in #{@path} - include::#{target}[#{raw_attributes}])
          return true
        end
      end
      true
    else
      false
    end
  end

  # Public: Push source onto the front of the reader and switch the context
  # based on the file, document-relative path and line information given.
  #
  # This method is typically used in an IncludeProcessor to add source
  # read from the target specified.
  #
  # Examples
  #
  #    path = 'partial.adoc'
  #    file = File.expand_path path
  #    data = IO.read file
  #    reader.push_include data, file, path
  #
  # Returns this Reader object.
  def push_include data, file = nil, path = nil, lineno = 1, attributes = {}
    @include_stack << [@lines, @file, @dir, @path, @lineno, @maxdepth, @process_lines]
    if file
      @file = file
      @dir = File.dirname file
      # only process lines in AsciiDoc files
      @process_lines = ASCIIDOC_EXTENSIONS[::File.extname file]
    else
      @file = nil
      @dir = '.' # right?
      # we don't know what file type we have, so assume AsciiDoc
      @process_lines = true
    end

    if path
      @includes << Helpers.rootname(@path = path)
    else
      @path = '<stdin>'
    end

    @lineno = lineno

    if attributes.key? 'depth'
      depth = attributes['depth'].to_i
      depth = 1 if depth <= 0
      @maxdepth = {:abs => (@include_stack.size - 1) + depth, :rel => depth}
    end

    # effectively fill the buffer
    if (@lines = prepare_lines data, :normalize => true, :condense => false, :indent => attributes['indent']).empty?
      pop_include
    else
      # FIXME we eventually want to handle leveloffset without affecting the lines
      if attributes.key? 'leveloffset'
        @lines.unshift ''
        @lines.unshift %(:leveloffset: #{attributes['leveloffset']})
        @lines << ''
        if (old_leveloffset = @document.attr 'leveloffset')
          @lines << %(:leveloffset: #{old_leveloffset})
        else
          @lines << ':leveloffset!:'
        end
        # compensate for these extra lines
        @lineno -= 2
      end

      # FIXME kind of a hack
      #Document::AttributeEntry.new('infile', @file).save_to_next_block @document
      #Document::AttributeEntry.new('indir', @dir).save_to_next_block @document
      @look_ahead = 0
    end
    self
  end

  def pop_include
    if @include_stack.size > 0
      @lines, @file, @dir, @path, @lineno, @maxdepth, @process_lines = @include_stack.pop
      # FIXME kind of a hack
      #Document::AttributeEntry.new('infile', @file).save_to_next_block @document
      #Document::AttributeEntry.new('indir', ::File.dirname(@file)).save_to_next_block @document
      @look_ahead = 0
      nil
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
    if data[0] == '---'
      original_data = data.dup
      front_matter = []
      data.shift
      @lineno += 1 if increment_linenos
      while !data.empty? && data[0] != '---'
        front_matter << data.shift
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
  #   resolve_expr_val expr
  #   # => "value"
  #
  #   expr = '"value'
  #   resolve_expr_val expr
  #   # => "\"value"
  #
  #   expr = '"{undefined}"'
  #   resolve_expr_val expr
  #   # => ""
  #
  #   expr = '{undefined}'
  #   resolve_expr_val expr
  #   # => nil
  #
  #   expr = '2'
  #   resolve_expr_val expr
  #   # => 2
  #
  #   @document.attributes['name'] = 'value'
  #   expr = '"{name}"'
  #   resolve_expr_val expr
  #   # => "value"
  #
  # Returns The value of the expression, coerced to the appropriate type
  def resolve_expr_val val
    if ((val.start_with? '"') && (val.end_with? '"')) ||
        ((val.start_with? '\'') && (val.end_with? '\''))
      quoted = true
      val = val[1...-1]
    else
      quoted = false
    end

    # QUESTION should we substitute first?
    # QUESTION should we also require string to be single quoted (like block attribute values?)
    val = @document.sub_attributes val, :attribute_missing => 'drop' if val.include? ATTR_REF_HEAD

    if quoted
      val
    else
      if val.empty?
        nil
      elsif val == 'true'
        true
      elsif val == 'false'
        false
      elsif val.rstrip.empty?
        ' '
      elsif val.include? '.'
        val.to_f
      else
        # fallback to coercing to integer, since we
        # require string values to be explicitly quoted
        val.to_i
      end
    end
  end

  def include_processors?
    if @include_processor_extensions.nil?
      if @document.extensions? && @document.extensions.include_processors?
        !!(@include_processor_extensions = @document.extensions.include_processors)
      else
        @include_processor_extensions = false
      end
    else
      @include_processor_extensions != false
    end
  end

  def to_s
    %(#<#{self.class}@#{object_id} {path: #{@path.inspect}, line #: #{@lineno}, include depth: #{@include_stack.size}, include stack: [#{@include_stack.map {|inc| inc.to_s } * ', '}]}>)
  end
end
end
