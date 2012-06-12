# Public: Methods for parsing Asciidoc documents and rendering them
# using erb templates.
class Asciidoc::Document

  include Asciidoc

  # Public: Get the String document source.
  attr_reader :source

  # Public: Get the Asciidoc::Renderer instance currently being used
  # to render this Document.
  attr_reader :renderer

  # Public: Get the Hash of document references
  attr_reader :references

  # Need these for pseudo-template yum
  attr_reader :header, :preamble

  # Root element of the parsed document
  attr_reader :root

  # Public: Initialize an Asciidoc object.
  #
  # data  - The String Asciidoc source document.
  # block - A block that can be used to retrieve external Asciidoc
  #         data to include in this document.
  #
  # Examples
  #
  #   base = File.dirname(filename)
  #   data = File.readlines(filename)
  #   doc  = Asciidoc.new(data)
  def initialize(data, &block)
    raw_source = []
    @defines = {}
    @references = {}

    include_regexp = /^include::([^\[]+)\[\]\s*\n?\z/
    data.each do |line|
      if inc = line.match(include_regexp)
        raw_source.concat(File.readlines(inc[1]))
      else
        raw_source << line
      end
    end

    ifdef_regexp = /^(ifdef|ifndef)::([^\[]+)\[\]/
    endif_regexp = /^endif::/
    defattr_regexp = /^:([^:]+):\s*(.*)\s*$/
    conditional_regexp = /^\s*\{([^\?]+)\?\s*([^\}]+)\s*\}/
    skip_to = nil
    continuing_value = nil
    continuing_key = nil
    @lines = []
    raw_source.each do |line|
      if !skip_to.nil?
        skip_to = nil if line.match(skip_to)
      elsif !continuing_value.nil?
        close_continue = false
        # Lines that start with whitespace are a continuation,
        # so gobble them up into `value`
        if match = line.match(/\s+(.+)\s+\+\s*$/)
          continuing_value += match[1]
        elsif match = line.match(/\s+(.+)/)
          # If this continued line doesn't end with a +, then this
          # is the end of the continuation, no matter what the next
          # line does.
          continuing_value += match[1]
          close_continue = true
        else
          # If this line doesn't start with whitespace, then it's
          # not a valid continuation line, so TODO FIGURE THIS OUT.
          # Possibly we don't care about this crap, and we just
          # look for a properly whitespace-opening and close it out
          # if there's no + on the end.
          close_continue = true
          raise "Yeah, you can't do that here: #{__FILE__}:#{__LINE__}"
        end
        if close_continue
          puts "Closing out continuation for key #{continuing_key}, final value: '#{continuing_value}'"
          @defines[continuing_key] = continuing_value
          continuing_key = nil
          continuing_value = nil
        end
      elsif match = line.match(ifdef_regexp)
        attr = match[2]
        skip = case match[1]
               when 'ifdef';  !@defines.has_key?(attr)
               when 'ifndef'; @defines.has_key?(attr)
               end
        skip_to = /^endif::#{attr}\[\]\s*\n/ if skip
      elsif match = line.match(defattr_regexp)
        key = match[1]
        value = match[2]
        if match = value.match(/(.+)\s+\+\s*$/)
          # continuation line, grab lines until we run out of continuation lines
          continuing_key = key
          continuing_value = match[1]  # strip off the spaces and +
          puts "continuing key: #{continuing_key} with partial value: '#{continuing_value}'"
        else
          @defines[key] = value
          puts "Defines[#{key}] is '#{value}'"
        end
      elsif !line.match(endif_regexp)
        while match = line.match(conditional_regexp)
          value = @defines.has_key?(match[1]) ? match[2] : ''
          line.sub!(conditional_regexp, value)
        end
        @lines << line unless line.match(REGEXP[:comment])
      end
    end

    # Process bibliography references, so they're available when text
    # before the reference is being rendered.
    @lines.each do |line|
      if biblio = line.match(REGEXP[:biblio])
        references[biblio[1]] = "[#{biblio[1]}]"
      end
    end

    @source = @lines.join

    @root = next_section(@lines)
    # After processing blocks, if the first block is a Section, pull it out
    # as the @header.
    if @root.blocks.first.is_a?(Section)
      @header = @root.blocks.shift
    else
      # Otherwise, make a new Section, and pull off all leading Block objects
      # and concat them as the @preamble.
      @preamble = Section.new(self)
      while @root.blocks.first.is_a?(Block)
        @preamble << @root.blocks.shift
      end
    end
  end

  def splain
    if @header
      puts "Header is #{@header}"
    else
      puts "No header"
    end
    if @preamble
      puts "Preamble is #{@preamble}"
      puts "It has #{@preamble.blocks.count} blocks."
    else
      puts "No preamble"
    end
    puts "I have #{@root.blocks.count} blocks"
    @root.blocks.each_with_index do |block, i|
      puts "Block ##{i} is a #{block.class}"
      puts "Name is #{block.name}"
      puts "=" * 40
    end
  end

  # Public: Render the Asciidoc document using erb templates
  #
  def render
    @renderer ||= Renderer.new
    puts "Document#renderer is #{@renderer}"

    html = self.renderer.render('document', @root, :header => @header, :preamble => @preamble)
  end

  private

  # Private: Strip off leading blank lines in the Array of lines.
  #
  # lines - the Array of String lines.
  #
  # Returns nil.
  #
  # Examples
  #
  #   content
  #   => ["\n", "\t\n", "Foo\n", "Bar\n", "\n"]
  #
  #   skip_blank(content)
  #   => nil
  #
  #   lines
  #   => ["Foo\n", "Bar\n"]
  def skip_blank(lines)
    while lines.any? && lines.first.strip.empty?
      lines.shift
    end

    nil
  end

  # Private: Strip off and return the list item segment (one or more contiguous blocks) from the Array of lines.
  #
  # lines   - the Array of String lines.
  # options - an optional Hash of processing options:
  #           * :alt_ending may be used to specify a regular expression match other than
  #             a blank line to signify the end of the segment.
  # Returns the Array of lines from the next segment.
  #
  # Examples
  #
  #   content
  #   => ["First paragraph\n", "+\n", "Second paragraph\n", "--\n", "Open block\n", "\n", "Can have blank lines\n", "--\n", "\n", "In a different segment\n"]
  #
  #   list_item_segment(content)
  #   => ["First paragraph\n", "+\n", "Second paragraph\n", "--\n", "Open block\n", "\n", "Can have blank lines\n", "--\n"]
  #
  #   content
  #   => ["In a different segment\n"]
  def list_item_segment(lines, options={})
    alternate_ending = options[:alt_ending]
    segment = []

    skip_blank(lines)

    # Grab lines until the first blank line not inside an open block
    # or listing
    in_oblock = false
    in_listing = false
    while lines.any?
      this_line = lines.shift
      in_oblock = !in_oblock if this_line.match(REGEXP[:oblock])
      in_listing = !in_listing if this_line.match(REGEXP[:listing])
      if !in_oblock && !in_listing
        if this_line.strip.empty?
          # From the Asciidoc user's guide:
          #   Another list or a literal paragraph immediately following
          #   a list item will be implicitly included in the list item
          next_nonblank = lines.detect{|l| !l.strip.empty?}
          if !next_nonblank.nil? &&
             ( alternate_ending.nil? ||
               !next_nonblank.match(alternate_ending)
             ) && [:ulist, :olist, :colist, :dlist, :lit_par, :continue].
                  find { |pattern| next_nonblank.match(REGEXP[pattern]) }

             # Pull blank lines into the segment, so the next thing up for processing
             # will be the next nonblank line.
             while lines.first.strip.empty?
               segment << this_line
               this_line = lines.shift
             end
          else
            break
          end
        elsif !alternate_ending.nil? && this_line.match(alternate_ending)
          lines.unshift this_line
          break
        end
      end

      segment << this_line
    end

    segment
  end

  # Private: Return all the lines from `lines` until we run out of lines,
  #   find a blank line without :include_blank => true, or find a line
  #   for which the given block evals to true.
  #
  # lines   - the Array of String lines.
  # options - an optional Hash of processing options:
  #           * :break_on_blank_lines may be used to specify to break on blank lines
  #           * :preserve_last_line may be used to specify that the String
  #               causing the method to stop processing lines should be
  #               pushed back onto the `lines` Array.
  #
  # Returns the Array of lines from the next segment.
  #
  # Examples
  #
  #   content
  #   => ["First paragraph\n", "Second paragraph\n", "Open block\n", "\n", "Can have blank lines\n", "--\n", "\n", "In a different segment\n"]
  #
  #   grab_lines_until(content)
  #   => ["First paragraph\n", "Second paragraph\n", "Open block\n"]
  #
  #   content
  #   => ["In a different segment\n"]
  def grab_lines_until(lines, options = {}, &block)
    buffer = []

    while (this_line = lines.shift)
      puts "Processing line: '#{this_line}'"
      finis = this_line.nil?
      finis ||= true if options[:break_on_blank_lines] && this_line.strip.empty?
      finis ||= true if block && value = yield(this_line)
      if finis
        lines.unshift(this_line) if options[:preserve_last_line] and ! this_line.nil?
        break
      end

      buffer << this_line
    end
    buffer
  end

  # Private: Return the next block from the section.
  #
  # * Skip over blank lines to find the start of the next content block.
  # * Use defined regular expressions to determine the type of content block.
  # * Based on the type of content block, grab lines to the end of the block.
  # * Return a new Asciidoc::Block or Asciidoc::Section instance with the
  #   content set to the grabbed lines.
  def next_block(lines, parent = self)
    # Skip ahead to the block content
    skip_blank(lines)

    return nil if lines.empty?

    # NOTE: An anchor looks like this:
    #   [[foo]]
    # with the inside [foo] (including brackets) as match[1]
    if match = lines.first.match(REGEXP[:anchor])
      puts "Found an anchor in line:\n\t#{lines.first}"
      # NOTE: This expression conditionally strips off the brackets from
      # [foo], though REGEXP[:anchor] won't actually match without
      # match[1] being bracketed, so the condition isn't necessary.
      anchor = match[1].match(/^\[(.*)\]/) ? $1 : match[1]
      # NOTE: Set @references['foo'] = '[foo]'
      @references[anchor] = match[1]
      lines.shift
    else
      anchor = nil
    end

    puts "/"*64
    puts "#{__FILE__}:#{__LINE__} - First two lines are:"
    puts lines.first
    puts lines[1]
    puts "/"*64

    block = nil
    title = nil
    caption = nil
    buffer = []
    while lines.any? && block.nil?
      buffer.clear
      this_line = lines.shift
      next_line = lines.first || ''

      if this_line.match(REGEXP[:comment])
        next
      elsif match = this_line.match(REGEXP[:title])
        title = match[1]
      elsif match = this_line.match(REGEXP[:caption])
        caption = match[1]
      elsif is_section_heading?(this_line, next_line)
        # If we've come to a new section, then we've found the end of this
        # current block.  Likewise if we'd found an unassigned anchor, push
        # it back as well, so it can go with this next heading.
        # NOTE - I don't think this will assign the anchor properly. Anchors
        # only match with double brackets - [[foo]], but what's stored in
        # `anchor` at this point is only the `foo` part that was stripped out
        # after matching.  TODO: Need a way to test this.
        lines.unshift(this_line)
        lines.unshift(anchor) unless anchor.nil?
        block = next_section(lines)
      elsif this_line.match(REGEXP[:oblock])
        # oblock is surrounded by '--' lines and has zero or more blocks inside
        buffer = grab_lines_until(lines) { |line| line.match(REGEXP[:oblock]) }

        while buffer.any? && buffer.last.strip.empty?
          buffer.pop
        end

        block = Block.new(parent, :oblock, [])
        while buffer.any?
          block.blocks << next_block(buffer, block)
        end

      elsif list_type = [:olist, :ulist, :colist].detect{|l| this_line.match( REGEXP[l] )}
        items = []
        block = Block.new(parent, list_type)
        while !this_line.nil? && match = this_line.match(REGEXP[list_type])
          item = ListItem.new

          lines.unshift match[2].lstrip.sub(/^\./, '\.')
          item_segment = list_item_segment(lines, :alt_ending => REGEXP[list_type])
          while item_segment.any?
            item.blocks << next_block(item_segment, block)
          end

          if item.blocks.any? &&
             item.blocks.first.is_a?(Block) &&
             (item.blocks.first.context == :paragraph || item.blocks.first.context == :literal)
            item.content = item.blocks.shift.buffer.map{|l| l.strip}.join("\n")
          end

          items << item

          skip_blank(lines)

          this_line = lines.shift
        end
        lines.unshift(this_line) unless this_line.nil?

        block.buffer = items

      elsif match = this_line.match(REGEXP[:dlist])
        pairs = []
        block = Block.new(parent, :dlist)

        this_dlist = Regexp.new(/^#{match[1]}(.*)#{match[3]}\s*$/)

        while !this_line.nil? && match = this_line.match(this_dlist)
          if anchor = match[1].match( /\[\[([^\]]+)\]\]/ )
            dt = ListItem.new( $` + $' )
            dt.anchor = anchor[1]
          else
            dt = ListItem.new( match[1] )
          end
          dd = ListItem.new
          lines.shift if lines.any? && lines.first.strip.empty? # workaround eg. git-config OPTIONS --get-colorbool

          dd_segment = list_item_segment(lines, :alt_ending => this_dlist)
          while dd_segment.any?
            dd.blocks << next_block(dd_segment, block)
          end

          if dd.blocks.any? &&
             dd.blocks.first.is_a?(Block) &&
             (dd.blocks.first.context == :paragraph || dd.blocks.first.context == :literal)
            dd.content = dd.blocks.shift.buffer.map{|l| l.strip}.join("\n")
          end

          pairs << [dt, dd]

          skip_blank(lines)

          this_line = lines.shift
        end
        lines.unshift(this_line) unless this_line.nil?
        block.buffer = pairs
      elsif this_line.match(REGEXP[:verse])
        # verse is preceded by [verse] and lasts until a blank line
        buffer = grab_lines_until(lines, :break_on_blank_lines => true)
        block = Block.new(parent, :verse, buffer)
      elsif this_line.match(REGEXP[:note])
        # note is an admonition preceded by [NOTE] and lasts until a blank line
        buffer = grab_lines_until(lines, :break_on_blank_lines => true) {|line| line.match( REGEXP[:continue] ) }
        block = Block.new(parent, :note, buffer)
      elsif text = [:listing, :example].detect{|t| this_line.match( REGEXP[t] )}
        buffer = grab_lines_until(lines) {|line| line.match( REGEXP[text] )}
        block = Block.new(parent, text, buffer)
      elsif this_line.match( REGEXP[:quote] )
        block = Block.new(parent, :quote)
        buffer = grab_lines_until(lines) {|line| line.match( REGEXP[:quote] ) }

        while buffer.any?
          block.blocks << next_block(buffer, block)
        end
      elsif this_line.match(REGEXP[:lit_blk])
        # example is surrounded by '....' (4 or more '.' chars) lines
        buffer = grab_lines_until(lines) {|line| line.match( REGEXP[:lit_blk] ) }
        block = Block.new(parent, :literal, buffer)
      elsif this_line.match(REGEXP[:lit_par])
        # literal paragraph is contiguous lines starting with
        # one or more space or tab characters

        # So we need to actually include this one in the grab_lines group
        lines.unshift( this_line )
        buffer = grab_lines_until(lines, :preserve_last_line => true) {|line| ! line.match( REGEXP[:lit_par] ) }

        block = Block.new(parent, :literal, buffer)
      elsif this_line.match(REGEXP[:sidebar_blk])
        # example is surrounded by '****' (4 or more '*' chars) lines
        buffer = grab_lines_until(lines) {|line| line.match( REGEXP[:sidebar_blk] ) }
        block = Block.new(parent, :sidebar, buffer)
      else
        # paragraph is contiguous nonblank/noncontinuation lines
        while !this_line.nil? && !this_line.strip.empty?
          break if this_line.match(REGEXP[:continue])
          if this_line.match( REGEXP[:listing] ) || this_line.match( REGEXP[:oblock] )
            lines.unshift this_line
            break
          end
          buffer << this_line
          this_line = lines.shift
        end

        if buffer.any? && admonition = buffer.first.match(/^NOTE:\s*/)
          buffer[0] = admonition.post_match
          block = Block.new(parent, :note, buffer)
        else
          block = Block.new(parent, :paragraph, buffer)
        end
      end
    end

    block.anchor  ||= anchor
    block.title   ||= title
    block.caption ||= caption

    block
  end

  # Private: Get the Integer section level based on the characters
  # used in the ASCII line under the section name.
  #
  # line - the String line from under the section name.
  def section_level(line)
    char = line.strip.chars.to_a.uniq
    case char
    when ['=']; 0
    when ['-']; 1
    when ['~']; 2
    when ['^']; 3
    when ['+']; 4
    end
  end

  def is_section_heading?(line1, line2)
    !line1.nil? && !line2.nil? &&
    line1.match(REGEXP[:name]) && line2.match(REGEXP[:line]) &&
    (line1.size - line2.size).abs <= 1
  end

  # Private: Return the next section from the document.
  #
  # Examples
  #
  #   source
  #   => "GREETINGS\n---------\nThis is my doc.\n\nSALUTATIONS\n-----------\nIt is awesome."
  #
  #   doc = Asciidoc::Document.new(source)
  #
  #   doc.next_section
  #   ["GREETINGS", [:paragraph, "This is my doc."]]
  #
  #   doc.next_section
  #   ["SALUTATIONS", [:paragraph, "It is awesome."]]
  def next_section(lines)
    section = Section.new(self)

    puts "%"*64
    puts "#{__FILE__}:#{__LINE__} - First two lines are:"
    puts lines.first
    puts lines[1]
    puts "%"*64

    # Skip ahead to the next section definition
    while lines.any? && section.name.nil?
      this_line = lines.shift
      next_line = lines.first || ''
      if match = this_line.match(REGEXP[:anchor])
        puts "#{__FILE__}#{__LINE__}: Found an anchor '#{match[1]}'"
        section.anchor = match[1]
      elsif is_section_heading?(this_line, next_line)
        header_match = this_line.match(REGEXP[:name])
        if anchor_match = header_match[1].match(REGEXP[:anchor_embedded])
          section.name   = anchor_match[1]
          section.anchor = anchor_match[2]
        else
          section.name = header_match[1]
        end
        section.level = section_level(next_line)
        lines.shift
      end
    end

    if section.anchor
      puts "#{__FILE__}:#{__LINE__} (#{__method__}) - WE have a SECTION anchor, yo: '#{section.anchor}'"
    else
      puts "#{__FILE__}:#{__LINE__} (#{__method__}) - WE have NO SECTION anchor for section #{section.name}"
    end

    if !section.anchor.nil?
      anchor_id = section.anchor.match(/^\[(.*)\]/) ? $1 : section.anchor
      @references[anchor_id] = section.anchor
      section.anchor = anchor_id
    end

    # Grab all the lines that belong to this section
    section_lines = []
    while lines.any?
      this_line = lines.shift
      next_line = lines.first

      if is_section_heading?(this_line, next_line)
        if section_level(next_line) <= section.level
          lines.unshift this_line
          lines.unshift section_lines.pop if section_lines.any? && section_lines.last.match(REGEXP[:anchor])
          break
        else
          section_lines << this_line
          section_lines << lines.shift
        end
      elsif this_line.match(REGEXP[:listing])
        section_lines << this_line
        this_line = lines.shift
        while !this_line.nil? && !this_line.match(REGEXP[:listing])
          section_lines << this_line
          this_line = lines.shift
        end
        section_lines << this_line unless this_line.nil?
      else
        section_lines << this_line
      end
    end

    # Now parse section_lines into Blocks
    while section_lines.any?
      skip_blank(section_lines)

      section << next_block(section_lines, section) if section_lines.any?
    end

    puts "#{__FILE__}:#{__LINE__} Final SECTION anchor is: '#{section.anchor.inspect}'"

    section
  end
  # end private
end
