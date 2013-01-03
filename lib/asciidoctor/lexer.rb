# Public: Methods to parse lines of AsciiDoc into an object hierarchy
# representing the structure of the document. All methods are class methods and
# should be invoked from the Lexer class. The main entry point is ::next_block.
# No Lexer instances shall be discovered running around. (Any attempt to
# instantiate a Lexer will be futile).
#
# The object hierarchy created by the Lexer consists of zero or more Section
# and Block objects. Section objects may be nested and a Section object
# contains zero or more Block objects. Block objects may be nested, but may
# only contain other Block objects. Block objects which represent lists may
# contain zero or more ListItem objects.
#
# Examples
#
#   # Create a Reader for the AsciiDoc lines and retrieve the next block from it.
#   # Lexer::next_block requires a parent, so we begin by instantiating an empty Document.
#
#   doc = Document.new
#   reader = Reader.new lines
#   block = Lexer.next_block(reader, doc)
#   block.class
#   # => Asciidoctor::Block
class Asciidoctor::Lexer

  include Asciidoctor

  # Public: Make sure the Lexer object doesn't get initialized.
  #
  # Raises RuntimeError if this constructor is invoked.
  def initialize
    raise 'Au contraire, mon frere. No lexer instances will be running around.'
  end

  # Public: Return the next Section or Block object from the Reader.
  #
  # Begins by skipping over blank lines to find the start of the next Section
  # or Block. Processes each line of the reader in sequence until a Section or
  # Block is found or the reader has no more lines.
  #
  # Uses regular expressions from the Asciidoctor module to match Section
  # and Block delimiters. The ensuing lines are then processed according
  # to the type of content.
  #
  # reader - The Reader from which to retrieve the next block
  # parent - The Document, Section or Block to which the next block belongs
  # 
  # Returns a Section or Block object holding the parsed content of the processed lines
  def self.next_block(reader, parent)
    # Skip ahead to the block content
    reader.skip_blank

    return nil unless reader.has_lines?

    Asciidoctor.debug "/"*64
    Asciidoctor.debug "#{File.basename(__FILE__)}:#{__LINE__} -> #{__method__} - First two lines are:"
    Asciidoctor.debug reader.peek_line
    tmp_line = reader.get_line
    Asciidoctor.debug reader.peek_line
    reader.unshift tmp_line
    Asciidoctor.debug "/"*64

    context = parent.is_a?(Block) ? parent.context : nil
    block = nil
    title = nil
    caption = nil
    buffer = []
    attributes = {}

    while reader.has_lines? && block.nil?
      buffer.clear
      this_line = reader.get_line
      next_line = reader.peek_line || ''

      if match = this_line.match(REGEXP[:anchor])
        Asciidoctor.debug "Found an anchor in line:\n\t#{this_line}"
        id, reftext = match[1].split(',')
        attributes['id'] = id
        # AsciiDoc always use [id] as the reftext in HTML output,
        # but I'd like to do better in Asciidoctor
        #parent.document.references[id] = '[' + id + ']'
        if reftext
          attributes['reftext'] = reftext
          parent.document.references[id] = reftext
        end
        reader.skip_blank

      elsif this_line.match(REGEXP[:comment_blk])
        reader.grab_lines_until {|line| line.match( REGEXP[:comment_blk] ) }
        reader.skip_blank

      elsif this_line.match(REGEXP[:comment])
        reader.skip_blank

      elsif match = this_line.match(REGEXP[:attr_list_blk])
        AttributeList.new(parent.document.sub_attributes(match[1]), parent).parse_into(attributes)
        reader.skip_blank

      # we're letting ruler have attributes
      elsif this_line.match(REGEXP[:ruler])
        block = Block.new(parent, :ruler)
        reader.skip_blank

      # Only look for sections if we are processing the Document or a Section
      # We can't have new sections inside of blocks. Given that precondition...
      # Check if we've come to a new section, then we need to recurse into it. Treat it
      # as a whole as our current block. Pull any attributes that got orphaned
      # from the preceding block. (Preceding does not mean sibling, just
      # whereever we broke from the last block in document order).
      elsif context.nil? && is_section_heading?(this_line, next_line)
        if parent.document.attributes.has_key? 'orphaned'
          attributes.update(parent.document.attributes['orphaned'])
          parent.document.attributes.delete('orphaned')
        end
        reader.unshift(this_line)
        Asciidoctor.debug "#{__method__}: SENDING to next_section with lines[0] = #{reader.peek_line}"
        block = next_section(reader, parent)

      elsif match = this_line.match(REGEXP[:title])
        title = match[1]
        reader.skip_blank

      elsif match = this_line.match(REGEXP[:image_blk])
        block = Block.new(parent, :image)
        AttributeList.new(parent.document.sub_attributes(match[2])).parse_into(attributes, ['alt', 'width', 'height'])
        target = block.sub_attributes(match[1])
        if !target.to_s.empty?
          attributes['target'] = target
          attributes['alt'] ||= File.basename(target, File.extname(target))
        else
          # drop the line if target resolves to nothing
          block = nil
        end
        reader.skip_blank

      elsif this_line.match(REGEXP[:open_blk])
        # an open block is surrounded by '--' lines and has zero or more blocks inside
        buffer = Reader.new reader.grab_lines_until { |line| line.match(REGEXP[:open_blk]) }

        # Strip lines off end of block - not implemented yet
        # while buffer.has_lines? && buffer.last.strip.empty?
        #   buffer.pop
        # end

        block = Block.new(parent, :open)
        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      # needs to come before list detection
      elsif this_line.match(REGEXP[:sidebar_blk])
        # sidebar is surrounded by '****' (4 or more '*' chars) lines
        # FIXME violates DRY because it's a duplication of quote parsing
        block = Block.new(parent, :sidebar)
        buffer = Reader.new reader.grab_lines_until {|line| line.match( REGEXP[:sidebar_blk] ) }

        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      elsif list_type = [:colist].detect{|l| this_line.match( REGEXP[l] )}
        items = []
        Asciidoctor.debug "Creating block of type: #{list_type}"
        block = Block.new(parent, list_type)
        attributes['style'] ||= 'arabic'
        while !this_line.nil? && match = this_line.match(REGEXP[list_type])
          item = ListItem.new(block)

          # Store first line as the text of the list item
          item.text = match[2]
          list_item_reader = Reader.new grab_lines_for_list_item(reader, list_type)
          while item_reader.has_lines?
            new_block = next_block(list_item_reader, block)
            item.blocks << new_block unless new_block.nil?
          end

          items << item

          reader.skip_blank

          this_line = reader.get_line
        end
        reader.unshift(this_line) unless this_line.nil?

        block.buffer = items

      elsif match = this_line.match(REGEXP[:ulist])
        AttributeList.rekey(attributes, ['style'])
        reader.unshift(this_line)
        block = next_outline_list(reader, :ulist, parent)

      elsif match = this_line.match(REGEXP[:olist])
        AttributeList.rekey(attributes, ['style'])
        reader.unshift(this_line)
        block = next_outline_list(reader, :olist, parent)
        # QUESTION move this logic to next_outline_list?
        if !(attributes.has_key? 'style') && !(block.attributes.has_key? 'style')
          marker = block.buffer.first.marker
          if marker.start_with? '.'
            # first one makes more sense, but second on is AsciiDoc-compliant
            #attributes['style'] = (ORDERED_LIST_STYLES[block.level - 1] || ORDERED_LIST_STYLES.first).to_s
            attributes['style'] = (ORDERED_LIST_STYLES[marker.length - 1] || ORDERED_LIST_STYLES.first).to_s
          else
            style = ORDERED_LIST_STYLES.detect{|s| marker.match(ORDERED_LIST_MARKER_PATTERNS[s]) }
            attributes['style'] = (style || ORDERED_LIST_STYLES.first).to_s
          end
        end

      elsif match = this_line.match(REGEXP[:dlist])
        block = next_labeled_list(reader, match, parent)
    
      # FIXME violates DRY because it's a duplication of other block parsing
      elsif this_line.match(REGEXP[:example])
        # example is surrounded by lines with 4 or more '=' chars
        AttributeList.rekey(attributes, ['style'])
        if admonition_style = ADMONITION_STYLES.detect {|s| attributes['style'] == s}
          block = Block.new(parent, :admonition)
          attributes['name'] = admonition_style.downcase
          attributes['caption'] ||= admonition_style.capitalize
        else
          block = Block.new(parent, :example)
        end
        buffer = Reader.new reader.grab_lines_until {|line| line.match( REGEXP[:example] ) }

        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      # FIXME violates DRY w/ non-delimited block listing
      elsif this_line.match(REGEXP[:listing])
        AttributeList.rekey(attributes, ['style', 'language', 'linenums'])
        buffer = reader.grab_lines_until {|line| line.match( REGEXP[:listing] )}
        buffer.last.chomp! unless buffer.empty?
        block = Block.new(parent, :listing, buffer)

      elsif this_line.match(REGEXP[:quote])
        # multi-line verse or quote is surrounded by a block delimiter
        AttributeList.rekey(attributes, ['style', 'attribution', 'citetitle'])
        quote_context = (attributes['style'] == 'verse' ? :verse : :quote)
        block_reader = Reader.new reader.grab_lines_until {|line| line.match( REGEXP[:quote] ) }

        # only quote can have other section elements (as as section block)
        section_body = (quote_context == :quote)

        if section_body
          block = Block.new(parent, quote_context)
          while block_reader.has_lines?
            new_block = next_block(block_reader, block)
            block.blocks << new_block unless new_block.nil?
          end
        else
          block_reader.chomp_last!
          block = Block.new(parent, quote_context, block_reader.lines)
        end

      elsif this_line.match(REGEXP[:lit_blk])
        # example is surrounded by '....' (4 or more '.' chars) lines
        buffer = reader.grab_lines_until {|line| line.match( REGEXP[:lit_blk] ) }
        buffer.last.chomp! unless buffer.empty?
        block = Block.new(parent, :literal, buffer)

      elsif this_line.match(REGEXP[:lit_par])
        # literal paragraph is contiguous lines starting with
        # one or more space or tab characters

        # So we need to actually include this one in the grab_lines group
        reader.unshift this_line
        buffer = reader.grab_lines_until(:preserve_last_line => true, :break_on_blank_lines => true) {|line|
          context == :dlist && line.match(REGEXP[:dlist])
        }

        # trim off the indentation equivalent to the size of the least indented line
        if !buffer.empty?
          offset = buffer.map {|line| line.match(REGEXP[:leading_blanks])[1].length }.min
          if offset > 0
            buffer = buffer.map {|l| l.nuke(/^\s{1,#{offset}}/) }
          end
          buffer.last.chomp!
        end

        block = Block.new(parent, :literal, buffer)
        # a literal gets special meaning inside of a definition list
        if LIST_CONTEXTS.include?(context)
          attributes['options'] ||= []
          # TODO this feels hacky, better way to distinguish from explicit literal block?
          attributes['options'] << 'listparagraph'
        end

      ## these switches based on style need to come immediately before the else ##

      elsif attributes[1] == 'source'
        AttributeList.rekey(attributes, ['style', 'language', 'linenums'])
        reader.unshift(this_line)
        buffer = reader.grab_lines_until(:break_on_blank_lines => true)
        buffer.last.chomp! unless buffer.empty?
        block = Block.new(parent, :listing, buffer)

      elsif admonition_style = ADMONITION_STYLES.detect{|s| attributes[1] == s}
        # an admonition preceded by [<TYPE>] and lasts until a blank line
        reader.unshift(this_line)
        buffer = reader.grab_lines_until(:break_on_blank_lines => true)
        buffer.last.chomp! unless buffer.empty?
        block = Block.new(parent, :admonition, buffer)
        attributes['style'] = admonition_style
        attributes['name'] = admonition_style.downcase
        attributes['caption'] ||= admonition_style.capitalize

      elsif quote_context = [:quote, :verse].detect{|s| attributes[1] == s.to_s}
        # single-paragraph verse or quote is preceded by [verse] or [quote], respectively, and lasts until a blank line
        AttributeList.rekey(attributes, ['style', 'attribution', 'citetitle'])
        reader.unshift(this_line)
        buffer = reader.grab_lines_until(:break_on_blank_lines => true)
        buffer.last.chomp! unless buffer.empty?
        block = Block.new(parent, quote_context, buffer)

      else
        # paragraph is contiguous nonblank/noncontinuation lines
        reader.unshift this_line
        buffer = reader.grab_lines_until(:break_on_blank_lines => true, :preserve_last_line => true) {|line|
          (context == :dlist && line.match(REGEXP[:dlist])) ||
          line.match(REGEXP[:open_blk]) ||
          # total hack job, we need to rethink this in a more generic way
          (context == :olist && [:ulist, :dlist].detect {|c| line.match(REGEXP[c])}) ||
          (context == :ulist && [:olist, :dlist].detect {|c| line.match(REGEXP[c])}) ||
          line.match(REGEXP[:attr_line])
        }

        if !buffer.empty? && admonition = buffer.first.match(Regexp.new('^(' + ADMONITION_STYLES.join('|') + '):\s+'))
          buffer[0] = admonition.post_match
          block = Block.new(parent, :admonition, buffer)
          attributes['style'] = admonition[1]
          attributes['name'] = admonition[1].downcase
          attributes['caption'] ||= admonition[1].capitalize
        else
          buffer.last.chomp! unless buffer.empty?
          Asciidoctor.debug "Proud parent #{parent} getting a new paragraph with buffer: #{buffer}"
          block = Block.new(parent, :paragraph, buffer)
        end
      end
    end

    # when looking for nested content, one or more line comments, comment
    # blocks or trailing attribute lists could leave us without a block,
    # so handle accordingly
    if !block.nil?
      block.id        = attributes['id'] if attributes.has_key?('id')
      block.title   ||= title
      block.caption ||= caption unless block.is_a?(Section)
      # AsciiDoc always use [id] as the reftext in HTML output,
      # but I'd like to do better in Asciidoctor
      if block.id && block.title && !attributes.has_key?('reftext')
        block.document.references[block.id] = block.title
      end
      block.update_attributes(attributes)
    # if the block ended with unrooted attributes, then give them
    # to the next block; this seems like a hack, but it really
    # is the simplest solution to this problem
    elsif !attributes.empty?
      parent.document.attributes['orphaned'] = attributes
    end

    block
  end

  # Internal: Parse and construct an outline list Block from the current position of the Reader
  #
  # reader    - The Reader from which to retrieve the outline list
  # list_type - A Symbol representing the list type (:olist for ordered, :ulist for unordered)
  # parent    - The parent Block to which this outline list belongs
  #
  # Returns the Block encapsulating the parsed outline (unordered or ordered) list
  def self.next_outline_list(reader, list_type, parent)
    list_block = Block.new(parent, list_type)
    items = []
    list_block.buffer = items
    if parent.context == list_type
      list_block.level = parent.level + 1
    else
      list_block.level = 1
    end
    Asciidoctor.debug "Created #{list_type} block: #{list_block}"

    while reader.has_lines? && match = reader.peek_line.match(REGEXP[list_type])

      marker = (list_type == :olist && !(match[1].start_with? '.')) ?
          resolve_ordered_list_marker(match[1]) : match[1]

      # if we are moving to the next item, and the marker is different
      # determine if we are moving up or down in nesting
      if items.size > 0 && marker != items.first.marker
        # assume list is nested by default, but then check to see if we are
        # popping out of a nested list by matching an ancestor's list marker
        this_item_level = list_block.level + 1
        p = parent
        while p.context == list_type
          if marker == p.buffer.first.marker
            this_item_level = p.level
            break
          end
          p = p.parent
        end
      else
        this_item_level = list_block.level
      end

      if items.size == 0
        list_item = next_list_item(reader, list_block, match)
      else
        if this_item_level < list_block.level
          # leave this block
          break
        elsif this_item_level > list_block.level
          # If this next list level is down one from the
          # current Block's, append it to content of the current list item
          items.last.blocks << next_block(reader, list_block)
        else
          list_item = next_list_item(reader, list_block, match)
        end
      end

      items << list_item unless list_item.nil?
      list_item = nil

      reader.skip_blank
    end

    list_block
  end

  # Internal: Parse and construct a labeled (e.g., definition) list Block from the current position of the Reader
  #
  # reader    - The Reader from which to retrieve the labeled list
  # match     - The Regexp match for the head of the list
  # parent    - The parent Block to which this labeled list belongs
  #
  # Returns the Block encapsulating the parsed labeled list
  def self.next_labeled_list(reader, match, parent)
    pairs = []
    block = Block.new(parent, :dlist)
    # allows us to capture until we find a labeled item using the same delimiter (::, :::, :::: or ;;)
    sibling_pattern = REGEXP[:dlist_siblings][match[3]]

    begin
      dt = ListItem.new(block, match[2])
      unless match[1].nil?
        dt.id = match[1]
        dt.attributes['reftext'] = '[' + match[1] + ']'
      end
      dd = ListItem.new(block, match[5])

      dd_reader = Reader.new grab_lines_for_list_item(reader, :dlist, sibling_pattern)
      continuation_connects_first_block = (dd_reader.has_lines? && dd_reader.peek_line.chomp == LIST_CONTINUATION)
      if continuation_connects_first_block
        dd_reader.get_line
      end
      while dd_reader.has_lines?
        new_block = next_block(dd_reader, block)
        dd.blocks << new_block unless new_block.nil?
      end

      dd.fold_first(continuation_connects_first_block)

      pairs << [dt, dd]

      # this skip_blank might be redundant
      reader.skip_blank
      this_line = reader.get_line
    end while !this_line.nil? && match = this_line.match(sibling_pattern)

    reader.unshift(this_line) unless this_line.nil?
    block.buffer = pairs
    block
  end

  # Internal: Parse and construct the next ListItem for the current bulleted (unordered or ordered) list Block.
  #
  # First collect and process all the lines that constitute the next list item
  # for the parent list (according to its type). Next, parse those lines into
  # blocks and associate them with the ListItem. Finally, fold the first block
  # into the item's text attribute according to rules described in ListItem.
  #
  # reader      - The Reader from which to retrieve the next list item
  # list_block  - The parent list Block of this ListItem. Also provides access to the list type.
  # match       - The match Array which contains the marker and text (first-line) of the ListItem
  #
  # Returns the next ListItem for the parent list Block.
  def self.next_list_item(reader, list_block, match)
    list_item = ListItem.new(list_block)
    ordinal = list_block.buffer.size
    list_item.marker = list_block.context == :olist ?
        resolve_ordered_list_marker(match[1], ordinal, true) : match[1]

    Asciidoctor.debug "#{__FILE__}:#{__LINE__}: Created ListItem #{list_item} with match[2]: #{match[2]} and level: #{list_item.level}"

    # Store first line as the text of the list item
    list_item.text = match[2]

    # first skip the line with the marker
    reader.get_line
    list_item_reader = Reader.new grab_lines_for_list_item(reader, list_block.context)
    continuation_connects_first_block = list_item_reader.peek_line == "\n"
    while list_item_reader.has_lines?
      new_block = next_block(list_item_reader, list_block)
      list_item.blocks << new_block unless new_block.nil?
    end

    Asciidoctor.debug "\n\nlist_item has #{list_item.blocks.count} blocks, and first is a #{list_item.blocks.first.class} with context #{list_item.blocks.first.context rescue 'n/a'}\n\n"

    list_item.fold_first(continuation_connects_first_block)
    list_item
  end

  # Internal: Collect the lines belonging to the current list item.
  #
  # Definition lists (:dlist) are handled slightly differently than regular
  # lists (:olist or :ulist):
  #
  # Regular lists - grab lines until another list item is found, or the
  # block is broken by a terminator (such as a line comment or a blank line).
  #
  # Definition lists - grab lines until a sibling list item is found, or the
  # block is broken by a terminator (such as a line comment). Definition lists
  # are more lenient about allowing blank lines.
  #
  # reader          - The Reader from which to retrieve the lines.
  # list_type       - The context Symbol of the list (:ulist, :olist or :dlist)
  # sibling_pattern - A Regexp that matches a sibling of this list item (default: nil)
  # phase           - The Symbol representing the parsing phase (:collect or :process) (default: :process)
  #
  # Returns an Array of lines belonging to the current list item.
  def self.grab_lines_for_list_item(reader, list_type, sibling_pattern = nil, phase = :process)
    buffer = []
    next_item_pattern = sibling_pattern ? sibling_pattern : REGEXP[list_type]

    # three states: :inactive, :active & :frozen
    # :frozen signifies we've detected sequential continuation lines &
    # continuation is not permitted until reset 
    continuation = :inactive
    rescued_stray_paragraph = false
    while reader.has_lines?
      this_line = reader.get_line
      prev_line = buffer.empty? ? nil : buffer.last.chomp
      break if this_line.match(next_item_pattern)

      if prev_line == LIST_CONTINUATION
        if continuation == :inactive
          continuation = :active
          buffer.pop if phase == :process && list_type != :dlist
        end

        if this_line.chomp == LIST_CONTINUATION
          if continuation != :frozen
            continuation = :frozen
            buffer << this_line
          end
          this_line = nil
          next
        end
      end

      if match = this_line.match(REGEXP[:any_blk])
        terminator = match[0].rstrip
        if continuation == :active
          buffer << this_line
          # we're being more strict here about the terminator, but I think that's a good thing
          buffer.concat reader.grab_lines_until(:grab_last_line => true) {|line| line.rstrip == terminator }
          continuation = :inactive
        else
          break
        end
      elsif list_type == :dlist
        # labeled lists permit interspersed blank lines in certain
        # circumstances, so we have to do some detective work to figure out
        # when to break
        if !prev_line.nil? && prev_line.strip.empty?
          if this_line.match(REGEXP[:comment]) || this_line.match(REGEXP[:title])
            break 
          # allow for repeat literal paragraphs offset by blank lines
          elsif this_line.match(REGEXP[:lit_par])
            reader.unshift this_line
            buffer.concat reader.grab_lines_until(:preserve_last_line => true, :break_on_blank_lines => true)
            rescued_stray_paragraph = true
          else
            if this_line.match(REGEXP[:dlist])
              # reset if we get a new list item context
              rescued_stray_paragraph = false
              buffer << this_line
            elsif rescued_stray_paragraph
              break
            else
              buffer << this_line
              rescued_stray_paragraph = true
            end
          end
        else
          buffer << this_line
        end
      # :olist & :ulist
      else
        if continuation == :active && !this_line.strip.empty?
          # swallow the continuation into a blank line in the process phase
          buffer << "\n" if phase == :process
          buffer << this_line
          continuation = :inactive
        # bulleted and numbered lists are divided by blank lines unless followed by a list
        elsif !prev_line.nil? && prev_line.strip.empty?
          # a literal must have a trailing blank line or else it will suck up the next list item
          if this_line.match(REGEXP[:lit_par])
            reader.unshift this_line
            buffer.concat reader.grab_lines_until(:preserve_last_line => true, :break_on_blank_lines => true)
          elsif LIST_CONTEXTS.select{|t| t != list_type}.detect { |t| this_line.match(REGEXP[t]) }
            buffer << this_line
          else
            break
          end
        else
          buffer << this_line
        end
      end
      this_line = nil
    end

    reader.unshift this_line if !this_line.nil?

    if phase == :process
      
      # NOTE this is hackish, but since we process differently than ulist & olist
      # we need to do the line continuation substitution post-scan
      # we also need to hold on to the first line continuation because an endline
      # alone doesn't tell us that the first paragraph was attached via a line continuation
      if list_type == :dlist && buffer.size > 0 && buffer.first == "+\n"
        first = buffer.shift
        buffer = buffer.map {|l| l == "+\n" ? "\n" : l}
        buffer.unshift(first)
      end

      # QUESTION should we strip these trailing endlines?
      buffer.pop while buffer.last == "\n"

      # We do need to replace the trailing continuation
      if list_type != :dlist && buffer.last == "+\n"
        buffer.pop
        # QUESTION do we strip the endlines exposed by popping the list continuation?
        #buffer.pop while buffer.last == "\n"
        #buffer.push "\n"
      end
    end

    buffer
  end

  # Private: Get the Integer section level based on the characters
  # used in the ASCII line under the section title.
  #
  # line - the String line from under the section title.
  def self.section_level(line)
    char = line.strip.chars.to_a.uniq
    case char
    when ['=']; 0
    when ['-']; 1
    when ['~']; 2
    when ['^']; 3
    when ['+']; 4
    end
  end

  #--
  # = is level 0, == is level 1, etc.
  def self.single_line_section_level(line)
    [line.length - 1, 0].max
  end

  def self.is_single_line_section_heading?(line)
    !line.nil? && line.match(REGEXP[:section_heading])
  end

  def self.is_two_line_section_heading?(line1, line2)
    !line1.nil? && !line2.nil? &&
    line1.match(REGEXP[:heading_name]) && line2.match(REGEXP[:heading_line]) &&
    # chomp so that a (non-visible) endline does not impact calculation
    (line1.chomp.size - line2.chomp.size).abs <= 1
  end

  def self.is_section_heading?(line1, line2 = nil)
    is_single_line_section_heading?(line1) ||
    is_two_line_section_heading?(line1, line2)
  end

  def self.is_title_section?(section, parent)
    section.level == 0 && parent.is_a?(Document) && parent.blocks.empty?
  end

  # Private: Extracts the title, level and (optional) embedded id from a
  #          1- or 2-line section heading.
  #
  # Returns an array of [String, Integer, String, Boolean] or nil.
  #
  # Examples
  #
  #   [line1, line2]
  #   # => ["Foo\n", "~~~\n"]
  #
  #   title, level, id, single = extract_section_heading(line1, line2)
  #
  #   title
  #   # => "Foo"
  #   level
  #   # => 2
  #   id
  #   # => nil
  #   single
  #   # => false
  #
  #   line1
  #   # => "==== Foo\n"
  #
  #   title, level, id, single = extract_section_heading(line1)
  #
  #   title
  #   # => "Foo"
  #   level
  #   # => 3
  #   id
  #   # => nil
  #   single
  #   # => true
  #
  def self.extract_section_heading(line1, line2 = nil)
    Asciidoctor.debug "#{__method__} -> line1: #{line1.chomp rescue 'nil'}, line2: #{line2.chomp rescue 'nil'}"
    sect_title = sect_id = nil
    sect_level = 0

    single_line = false
    if is_single_line_section_heading?(line1)
      header_match = line1.match(REGEXP[:section_heading])
      sect_title = header_match[2]
      sect_id = header_match[3]
      sect_level = single_line_section_level(header_match[1])
      single_line = true
    elsif is_two_line_section_heading?(line1, line2)
      # TODO could be optimized into a single regexp
      header_match = line1.match(REGEXP[:heading_name])
      if anchor_match = header_match[1].match(REGEXP[:anchor_embedded])
        sect_title = anchor_match[1]
        sect_id = anchor_match[2]
      else
        sect_title = header_match[1]
      end
      sect_level = section_level(line2)
    end
    Asciidoctor.debug "#{__method__} -> Returning #{sect_title}, #{sect_level} (id: '#{sect_id || '<none>'}')"
    return [sect_title, sect_level, sect_id, single_line]
  end

  # Public: Consume and parse the two header lines (line 1 = author info, line 2 = revision info).
  #
  # Returns the Hash of header metadata
  #
  # Examples
  #
  #  parse_header_metadata(Reader.new ["Author Name <author@example.org>\n", "v1.0, 2012-12-21: Coincide w/ end of world.\n"])
  #  # => {'author' => 'Author Name', 'firstname' => 'Author', 'lastname' => 'Name', 'email' => 'author@example.org',
  #  #       'revnumber' => '1.0', 'revdate' => '2012-12-21', 'revremark' => 'Coincide w/ end of world.'}
  def self.parse_header_metadata(reader)
    # capture consecutive comment lines so we can reinsert them after the header
    comment_lines = reader.consume_comments

    metadata = {}
    if reader.has_lines? && !reader.peek_line.strip.empty?
      author_line = reader.get_line
      match = author_line.match(REGEXP[:author_info])
      if match
        metadata['firstname'] = fname = match[1].tr('_', ' ')
        metadata['author'] = fname
        metadata['authorinitials'] = fname[0, 1]
        if !match[2].nil? && !match[3].nil?
          metadata['middlename'] = mname = match[2].tr('_', ' ')
          metadata['lastname'] = lname = match[3].tr('_', ' ')
          metadata['author'] = [fname, mname, lname].join ' '
          metadata['authorinitials'] = [fname[0, 1], mname[0, 1], lname[0, 1]].join
        elsif !match[2].nil?
          metadata['lastname'] = lname = match[2].tr('_', ' ')
          metadata['author'] = [fname, lname].join ' '
          metadata['authorinitials'] = [fname[0, 1], lname[0, 1]].join
        end
        metadata['email'] = match[4] unless match[4].nil?
      else
        metadata['author'] = metadata['firstname'] = author_line.strip.squeeze(' ')
        metadata['authorinitials'] = metadata['firstname'][0, 1]
      end

      # capture consecutive comment lines so we can reinsert them after the header
      comment_lines += reader.consume_comments

      if reader.has_lines? && !reader.peek_line.strip.empty?
        rev_line = reader.get_line 
        match = rev_line.match(REGEXP[:revision_info])
        if match
          metadata['revdate'] = match[2]
          metadata['revnumber'] = match[1] unless match[1].nil?
          metadata['revremark'] = match[3] unless match[3].nil?
        else
          metadata['revdate'] = rev_line.strip
        end
      end

      reader.skip_blank
    end

    reader.unshift(*comment_lines)
    metadata
  end

  # Public: Return the next section from the Reader.
  #
  # This method begins by collecting the lines that belong to this section and
  # wrapping them in a reader. It then parses those lines into a hierarchy of
  # objects by calling ::next_block until all the lines for this section have
  # been consumed.
  #
  # When a block delimiter is found, the block segments are consumed as a whole
  # so as not to interpret lines that look like headings that occur within
  # those blocks as sections.
  #
  # NOTE: The assumption is made that this method is entered with the cursor
  # positioned at a section line.
  #
  # Examples
  #
  #   source
  #   # => "GREETINGS\n---------\nThis is my doc.\n\nSALUTATIONS\n-----------\nIt is awesome."
  #
  #   reader = Reader.new source.lines.entries
  #   # create empty document to parent the section
  #   # and hold attributes extracted from header
  #   doc = Document.new
  #
  #   Lexer.next_section(reader, doc).title
  #   # => "GREETINGS"
  #
  #   Lexer.next_section(reader, doc).title
  #   # => "SALUTATIONS"
  def self.next_section(reader, parent)
    section = Section.new(parent)

    Asciidoctor.debug "%"*64
    Asciidoctor.debug "#{File.basename(__FILE__)}:#{__LINE__} -> #{__method__} - First two lines are:"
    Asciidoctor.debug reader.peek_line
    tmp_line = reader.get_line
    Asciidoctor.debug reader.peek_line
    reader.unshift tmp_line
    Asciidoctor.debug "%"*64

    this_line = reader.get_line
    next_line = reader.peek_line || ''
    section.title, section.level, section.id, single_line = extract_section_heading(this_line, next_line)
    # generate an id if one was not *embedded* in the heading line
    section.id ||= section.generate_id
    reader.get_line unless single_line

    if (title_section = is_title_section? section, parent)
      parent.attributes.update(parse_header_metadata(reader))
    end

    # Grab all the lines that belong to this section
    section_lines = []
    while reader.has_lines?
      this_line = reader.get_line
      next_line = reader.peek_line

      # don't let it confuse attributes over a block for a section heading
      if this_line.match(REGEXP[:attr_line])
        section_lines << this_line
      # skip past any known blocks
      elsif (match = this_line.match(REGEXP[:any_blk]))
        terminator = match[0].rstrip
        section_lines << this_line
        section_lines.concat reader.grab_lines_until(:grab_last_line => true) {|line| line.rstrip == terminator }

      elsif (match = this_line.match(REGEXP[:dlist]))
        begin
          sibling_pattern = REGEXP[:dlist_siblings][match[3]]
          section_lines << this_line
          section_lines.concat grab_lines_for_list_item(reader, :dlist, sibling_pattern, :collect)
          this_line = reader.get_line
        end while (match = this_line.match(REGEXP[:dlist]))
        reader.unshift this_line unless this_line.nil?

      elsif (list_type = [:ulist, :olist].detect {|t| this_line.match(REGEXP[t])})
        begin
          section_lines << this_line
          section_lines.concat grab_lines_for_list_item(reader, list_type, nil, :collect)
          this_line = reader.get_line
        end while !this_line.nil? && (list_type = [:ulist, :olist].detect {|t| this_line.match(REGEXP[t])})
        reader.unshift this_line unless this_line.nil?

      elsif is_section_heading? this_line, next_line
        _, this_level, _, single_line = extract_section_heading(this_line, next_line)

        # A section can't contain a broader (lower level) to itself or a sibling section,
        # so this signifies the end of this section. The attributes leading up to this
        # section will be carried over through the 'orphaned' attribute of the document.
        if this_level <= section.level
          reader.unshift this_line
          break
        else
          section_lines << this_line
          section_lines << reader.get_line unless single_line
        end
      else
        section_lines << this_line
      end
    end

    section_reader = Reader.new section_lines
    # Now parse section_lines into Blocks belonging to the current Section
    while section_reader.has_lines?
      new_block = next_block(section_reader, section)
      section << new_block unless new_block.nil?
    end

    # detect preamble and push it into a block
    # QUESTION make this an operation on Section named extract_preamble?
    if title_section
      blocks = section.blocks.take_while {|b| !b.is_a? Section}
      if !blocks.empty?
        # QUESTION Should we propagate the buffer?
        #preamble = Block.new(section, :preamble, blocks.reduce {|a, b| a.buffer + b.buffer})
        preamble = Block.new(section, :preamble)
        blocks.each { preamble << section.delete_at(0) }
        section.insert(0, preamble)
      end
    end

    section
  end

  # Internal: Resolve the 0-index marker for this ordered list item
  #
  # Match the marker used for this ordered list item against the
  # known ordered list markers and determine which marker is
  # the first (0-index) marker in its number series.
  #
  # The purpose of this method is to normalize the implicit numbered markers
  # so that they can be compared against other list items.
  #
  # marker   - The marker used for this list item
  # ordinal  - The 0-based index of the list item (default: 0)
  # validate - Perform validation that the marker provided is the proper
  #            marker in the sequence (default: false)
  #
  # Examples
  #
  #  marker = 'B.'
  #  Lexer::resolve_ordered_list_marker(marker, 1, true)
  #  # => 'A.'
  #
  # Returns the String of the first marker in this number series 
  def self.resolve_ordered_list_marker(marker, ordinal = 0, validate = false)
    number_style = ORDERED_LIST_STYLES.detect {|s| marker.match(ORDERED_LIST_MARKER_PATTERNS[s]) }
    expected = actual = nil
    case number_style
      when :arabic
        if validate
          expected = ordinal + 1
          actual = marker.to_i
        end
        marker = '1.'
      when :loweralpha
        if validate
          expected = ('a'[0].ord + ordinal).chr
          actual = marker.chomp('.')
        end
        marker = 'a.'
      when :upperalpha
        if validate
          expected = ('A'[0].ord + ordinal).chr
          actual = marker.chomp('.')
        end
        marker = 'A.'
      when :lowerroman
        if validate
          # TODO report this in roman numerals; see https://github.com/jamesshipton/roman-numeral/blob/master/lib/roman_numeral.rb
          expected = ordinal + 1
          actual = roman_numeral_to_int(marker.chomp(')'))
        end
        marker = 'i)'
      when :upperroman
        if validate
          # TODO report this in roman numerals; see https://github.com/jamesshipton/roman-numeral/blob/master/lib/roman_numeral.rb
          expected = ordinal + 1
          actual = roman_numeral_to_int(marker.chomp(')'))
        end
        marker = 'I)'
    end

    if validate && expected != actual
      puts "asciidoctor: WARNING: list item index: expected #{expected}, got #{actual}"
    end

    marker
  end

  # Internal: Converts a Roman numeral to an integer value.
  #
  # value - The String Roman numeral to convert
  #
  # Returns the Integer for this Roman numeral
  def self.roman_numeral_to_int(value)
    value = value.downcase
    digits = { 'i' => 1, 'v' => 5, 'x' => 10 }
    result = 0
    (0..value.length - 1).each {|i|
      digit = digits[value[i..i]]
      if i + 1 < value.length && digits[value[i+1..i+1]] > digit
        result -= digit
      else
        result += digit
      end
    }
    result
  end
end
