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
    itemtext = parent.attributes['itemtext']
    parent.attributes.delete('itemtext') if itemtext
    # Skip ahead to the block content
    skipped = reader.skip_blank

    # bail if we've reached the end of the section content
    return nil unless reader.has_lines?

    if itemtext && skipped > 0
      itemtext = nil
    end

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

      elsif match = this_line.match(REGEXP[:blk_attr_list])
        AttributeList.new(parent.document.sub_attributes(match[1]), parent).parse_into(attributes)
        reader.skip_blank

      # NOTE we're letting ruler have attributes
      elsif !itemtext && this_line.match(REGEXP[:ruler])
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

      elsif !itemtext && match = this_line.match(REGEXP[:title])
        title = match[1]
        reader.skip_blank

      elsif !itemtext && match = this_line.match(REGEXP[:image_blk])
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

      elsif match = this_line.match(REGEXP[:colist])
        Asciidoctor.debug "Creating block of type: :colist"
        block = Block.new(parent, :colist)
        attributes['style'] = 'arabic'
        items = []
        block.buffer = items
        reader.unshift this_line
        expected_index = 1
        begin
          # might want to move this check to a validate method
          if match[1].to_i != expected_index
            puts "asciidoctor: WARNING: callout list item index: expected #{expected_index} got #{match[1]}"
          end
          list_item = next_list_item(reader, block, match)
          expected_index += 1
          if !list_item.nil?
            items << list_item
            coids = parent.document.callouts.callout_ids(items.size)
            if !coids.empty?
              list_item.attributes['coids'] = coids
            else
              puts 'asciidoctor: WARNING: no callouts refer to list item ' + items.size.to_s
            end
          end
        end while reader.has_lines? && match = reader.peek_line.match(REGEXP[:colist])

        block.document.callouts.next_list

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
        reader.unshift this_line
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
          line.match(REGEXP[:any_blk])
        }

        # trim off the indentation equivalent to the size of the least indented line
        if !buffer.empty?
          offset = buffer.map {|line| line.match(REGEXP[:leading_blanks])[1].length }.min
          if offset > 0
            buffer = buffer.map {|l| l.sub(/^\s{1,#{offset}}/, '') }
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

      else # paragraph, contiguous nonblank/noncontinuation lines
        reader.unshift this_line
        buffer = reader.grab_lines_until(:break_on_blank_lines => true, :preserve_last_line => true, :skip_line_comments => true) {|line|
          line.match(REGEXP[:any_blk]) || line.match(REGEXP[:attr_line]) ||
          # next list item can be directly adjacent to paragraph of previous list item
          context == :dlist && line.match(REGEXP[:dlist])
          # not sure if there are any cases when we need this check for other list types
          #LIST_CONTEXTS.include?(context) && line.match(REGEXP[context])
        }

        catalog_inline_anchors(buffer.join, parent.document)

        if !itemtext && !buffer.empty? && admonition = buffer.first.match(Regexp.new('^(' + ADMONITION_STYLES.join('|') + '):\s+'))
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

      if block.context == :listing || block.context == :literal
        catalog_callouts(block.buffer.join, block.document)
      end
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

      marker = resolve_list_marker(list_type, match[1])

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

  # Internal: Catalog any callouts found in the text, but don't process them
  #
  # text     - The String of text in which to look for callouts
  # document - The current document on which the callouts are stored
  #
  # Returns nothing
  def self.catalog_callouts(text, document)
    text.scan(REGEXP[:callout_scan]) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      next if m[0].start_with? '\\'
      document.callouts.register(m[1])
    }
  end

  # Internal: Catalog any inline anchors found in the text, but don't process them
  #
  # text     - The String text in which to look for inline anchors
  # document - The current document on which the references are stored
  #
  # Returns nothing
  def self.catalog_inline_anchors(text, document)
    text.scan(REGEXP[:anchor_macro]) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      next if m[0].start_with? '\\'
      id, reftext = m[1].split(',')
      document.references[id] = reftext || '[' + id + ']'
    }
    nil
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
    block.buffer = pairs
    # allows us to capture until we find a labeled item
    # that uses the same delimiter (::, :::, :::: or ;;)
    sibling_pattern = REGEXP[:dlist_siblings][match[2]]

    begin
      pairs << next_list_item(reader, block, match, sibling_pattern)
    end while reader.has_lines? && match = reader.peek_line.match(sibling_pattern)

    block
  end

  # Internal: Parse and construct the next ListItem for the current bulleted
  # (unordered or ordered) list Block, callout lists included, or the next
  # term ListItem and definition ListItem pair for the labeled list Block.
  #
  # First collect and process all the lines that constitute the next list
  # item for the parent list (according to its type). Next, parse those lines
  # into blocks and associate them with the ListItem (in the case of a
  # labeled list, the definition ListItem). Finally, fold the first block
  # into the item's text attribute according to rules described in ListItem.
  #
  # reader        - The Reader from which to retrieve the next list item
  # list_block    - The parent list Block of this ListItem. Also provides access to the list type.
  # match         - The match Array which contains the marker and text (first-line) of the ListItem
  # sibling_trait - The list marker or the Regexp to match a sibling item
  #
  # Returns the next ListItem or ListItem pair (depending on the list type)
  # for the parent list Block.
  def self.next_list_item(reader, list_block, match, sibling_trait = nil)
    list_type = list_block.context

    if list_type == :dlist
      list_term = ListItem.new(list_block, match[1])
      list_item = ListItem.new(list_block, match[3])
      has_text = !match[3].to_s.empty?
    else
      # Create list item using first line as the text of the list item
      list_item = ListItem.new(list_block, match[2])

      if !sibling_trait
        sibling_trait = resolve_list_marker(list_type, match[1], list_block.buffer.size, true)
      end
      list_item.marker = sibling_trait
      has_text = true
    end

    Asciidoctor.debug "#{__FILE__}:#{__LINE__}: Created ListItem #{list_item} with text: #{list_type == :dlist ? match[3] : match[2]} and level: #{list_item.level}"

    # first skip the line with the marker / term
    reader.get_line
    list_item_reader = Reader.new grab_lines_for_list_item(reader, list_type, sibling_trait, has_text)
    if list_item_reader.has_lines?
      comment_lines = list_item_reader.consume_line_comments
      subsequent_line = list_item_reader.peek_line
      list_item_reader.unshift(*comment_lines) unless comment_lines.empty? 

      if !subsequent_line.nil?
        continuation_connects_first_block = (subsequent_line == "\n")
        content_adjacent = !subsequent_line.strip.empty?
      else
        continuation_connects_first_block = false
        content_adjacent = false
      end

      # only relevant for :dlist
      list_block.attributes['itemtext'] = true if !has_text

      while list_item_reader.has_lines?
        new_block = next_block(list_item_reader, list_block)
        list_item.blocks << new_block unless new_block.nil?
      end

      list_item.fold_first(continuation_connects_first_block, content_adjacent)
    end

    Asciidoctor.debug "\n\nlist_item has #{list_item.blocks.count} blocks, and first is a #{list_item.blocks.first.class} with context #{list_item.blocks.first.context rescue 'n/a'}\n\n"

    list_type == :dlist ? [list_term, list_item] : list_item
  end

  # Internal: Collect the lines belonging to the current list item, navigating
  # through all the rules that determine what comprises a list item.
  #
  # Grab lines until a sibling list item is found, or the block is broken by a
  # terminator (such as a line comment). Definition lists are more greedy if
  # they don't have optional inline item text...they want that text
  #
  # reader          - The Reader from which to retrieve the lines.
  # list_type       - The Symbol context of the list (:ulist, :olist, :colist or :dlist)
  # sibling_trait   - A Regexp that matches a sibling of this list item or String list marker 
  #                   of the items in this list (default: nil)
  # has_text        - Whether the list item has text defined inline (always true except for labeled lists)
  # phase           - The Symbol representing the parsing phase (:collect or :process) (default: :process)
  #
  # Returns an Array of lines belonging to the current list item.
  def self.grab_lines_for_list_item(reader, list_type, sibling_trait = nil, has_text = true, phase = :process)
    buffer = []

    # three states for continuation: :inactive, :active & :frozen
    # :frozen signifies we've detected sequential continuation lines &
    # continuation is not permitted until reset 
    continuation = :inactive

    # if we are within a nested list, we don't throw away the list
    # continuation marks because they will be processed when grabbing
    # the lines for those nested lists
    within_nested_list = false

    # a detached continuation is a list continuation that follows a blank line
    # it gets associated with the outermost block
    detached_continuation = nil

    while reader.has_lines?
      this_line = reader.get_line

      # if we've arrived at a sibling item in this list, we've captured
      # the complete list item and can begin processing it
      # the remainder of the method determines whether we've reached
      # the termination of the list
      break if is_sibling_list_item?(this_line, list_type, sibling_trait)

      prev_line = buffer.empty? ? nil : buffer.last.chomp

      if prev_line == LIST_CONTINUATION
        if continuation == :inactive
          continuation = :active
          has_text = true
          buffer[buffer.size - 1] = "\n" if phase == :process && !within_nested_list
        end

        # dealing with adjacent list continuations (which is really a syntax error)
        if this_line.chomp == LIST_CONTINUATION
          if continuation != :frozen
            continuation = :frozen
            buffer << this_line
          end
          this_line = nil
          next
        end
      end

      # a delimited block immediately breaks the list unless preceded
      # by a list continuation (they are harsh like that ;0)
      if (match = this_line.match(REGEXP[:any_blk])) ||
        # technically attr_line only breaks if ensuing line is not a list item
        # which really means attr_line only breaks if it's acting as a block delimiter
        (list_type == :dlist && match = this_line.match(REGEXP[:attr_line]))
        terminator = match[0].rstrip
        if continuation == :active
          buffer << this_line
          # grab all the lines in the block, leaving the delimiters in place
          # we're being more strict here about the terminator, but I think that's a good thing
          buffer.concat reader.grab_lines_until(:grab_last_line => true) {|line| line.rstrip == terminator }
          continuation = :inactive
        else
          break
        end
      else
        if continuation == :active && !this_line.strip.empty?
          # literal paragraphs have special considerations (and this is one of 
          # two entry points into one)
          # if we don't process it as a whole, then a line in it that looks like a
          # list item will throw off the exit from it
          if this_line.match(REGEXP[:lit_par])
            reader.unshift this_line
            buffer.concat reader.grab_lines_until(:preserve_last_line => true, :break_on_blank_lines => true, :break_on_list_continuation => true)
          else
            if !within_nested_list && NESTABLE_LIST_CONTEXTS.detect {|ctx| this_line.match(REGEXP[ctx]) }
              within_nested_list = true
            end
            buffer << this_line
          end
          continuation = :inactive
        elsif !prev_line.nil? && prev_line.strip.empty?
          # advance to the next line of content
          if this_line.strip.empty?
            reader.skip_blank
            this_line = reader.get_line 
            if this_line.nil?
              break
            end
          end

          if this_line.chomp == LIST_CONTINUATION
            detached_continuation = buffer.size
            buffer << this_line
          else
            # has_text is only relevant for dlist, which is more greedy until it has text for an item
            # for all other lists, has_text is always true
            # in this block, we have to see whether we hold on to the list
            if has_text && !within_nested_list
              # slurp up any literal paragraph offset by blank lines
              if this_line.match(REGEXP[:lit_par])
                reader.unshift this_line
                buffer.concat reader.grab_lines_until(:preserve_last_line => true, :break_on_blank_lines => true, :break_on_list_continuation => true)
              elsif NESTABLE_LIST_CONTEXTS.detect {|ctx| this_line.match(REGEXP[ctx]) }
                buffer.pop unless within_nested_list
                buffer << this_line
                within_nested_list = true
              else
                break
              end
            else # only dlist in need of item text, so slurp it up!
              buffer.pop unless within_nested_list
              buffer << this_line
              has_text = true
            end
          end
        else
          if !within_nested_list && NESTABLE_LIST_CONTEXTS.detect {|ctx| this_line.match(REGEXP[ctx]) }
            within_nested_list = true
          end
          buffer << this_line
          has_text = true if !this_line.strip.empty?
        end
      end
      this_line = nil
    end

    reader.unshift this_line if !this_line.nil?

    if phase == :process
      if detached_continuation
        buffer.delete_at detached_continuation
      end

      # QUESTION should we strip these trailing endlines?
      #buffer.pop while buffer.last == "\n"

      # We do need to replace the optional trailing continuation
      # a blank line would have served the same purpose in the document
      if !buffer.empty? && buffer.last.chomp == LIST_CONTINUATION
        buffer.pop
      end
      #puts "BUFFER>#{buffer.join}<BUFFER"
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
          sibling_pattern = REGEXP[:dlist_siblings][match[2]]
          section_lines << this_line
          section_lines.concat grab_lines_for_list_item(reader, :dlist, sibling_pattern, !match[3].to_s.empty?, :collect)
          this_line = reader.get_line
        end while (!this_line.nil? && match = this_line.match(REGEXP[:dlist]))
        reader.unshift this_line unless this_line.nil?

      elsif (list_type = [:ulist, :olist, :colist].detect {|ctx| this_line.match(REGEXP[ctx])})
        begin
          section_lines << this_line
          section_lines.concat grab_lines_for_list_item(reader, list_type, resolve_list_marker(list_type, $1), true, :collect)
          this_line = reader.get_line
        end while !this_line.nil? && (list_type = [:ulist, :olist, :colist].detect {|ctx| this_line.match(REGEXP[ctx])})
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

  # Internal: Resolve the 0-index marker for this list item
  #
  # For ordered lists, match the marker used for this list item against the
  # known list markers and determine which marker is the first (0-index) marker
  # in its number series.
  #
  # For callout lists, return <1>.
  #
  # For bulleted lists, return the marker as passed to this method.
  #
  # list_type  - The Symbol context of the list
  # marker     - The String marker for this list item
  # ordinal    - The position of this list item in the list
  # validate   - Whether to validate the value of the marker
  #
  # Returns the String 0-index marker for this list item
  def self.resolve_list_marker(list_type, marker, ordinal = 0, validate = false)
    if list_type == :olist && !marker.start_with?('.')
      resolve_ordered_list_marker(marker, ordinal, validate)
    elsif list_type == :colist
      '<1>'
    else
      marker
    end
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

  # Internal: Determine whether the this line is a sibling list item
  # according to the list type and trait (marker) provided.
  #
  # line          - The String line to check
  # list_type     - The context of the list (:olist, :ulist, :colist, :dlist)
  # sibling_trait - The String marker for the list or the Regexp to match a sibling 
  #
  # Returns a Boolean indicating whether this line is a sibling list item given
  # the criteria provided
  def self.is_sibling_list_item?(line, list_type, sibling_trait)
    if sibling_trait.is_a?(Regexp)
      matcher = sibling_trait
      expected_marker = false
    else
      matcher = REGEXP[list_type]
      expected_marker = sibling_trait
    end

    if m = line.match(matcher)
      if expected_marker
        expected_marker == resolve_list_marker(list_type, m[1])
      else
        true
      end
    else
      false
    end
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
