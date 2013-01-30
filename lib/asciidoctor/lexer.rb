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

  # Public: Parses AsciiDoc source read from the Reader into the Document
  #
  # This method is the main entry-point into the Lexer when parsing a full document.
  # It first looks for and, if found, processes the document title. It then
  # proceeds to iterate through the lines in the Reader, parsing the document
  # into nested Sections and Blocks.
  #
  # reader   - the Reader holding the source lines of the document
  # document - the empty Document into which the lines will be parsed
  #
  # returns the Document object
  def self.parse(reader, document)
    # process and plow away any attribute lines that proceed the first block so
    # we can get at the document title, if present, then begin parsing blocks
    reader.skip_blank_lines
    attributes = parse_block_metadata_lines(reader, document)

    # by processing the header here, we enforce its position at head of the document  
    next_level = is_next_line_section? reader, attributes
    if next_level == 0
      title_info = parse_section_title(reader) 
      document.title = title_info[1]
      parse_header_metadata(reader, document)
    end

    while reader.has_lines?
      new_section, attributes = next_section(reader, document, attributes)
      document << new_section unless new_section.nil?
    end

    document
  end

  # Public: Return the next section from the Reader.
  #
  # This method process block metadata, content and subsections for this
  # section and returns the Section object and any orphaned attributes.
  #
  # If the parent is a Document and has a header (document title), then
  # this method will put any non-section blocks at the start of document
  # into a preamble Block. If there are no such blocks, the preamble is
  # dropped.
  #
  # Since we are reading line-by-line, there's a chance that metadata
  # that should be associated with the following block gets consumed.
  # To deal with this case, the method returns a running Hash of
  # "orphaned" attributes that get passed to the next Section or Block.
  #
  # reader     - the source Reader
  # parent     - the parent Section or Document of this new section
  # attributes - a Hash of metadata that was left orphaned from the
  #              previous Section.
  #
  # Examples
  #
  #   source
  #   # => "Greetings\n---------\nThis is my doc.\n\nSalutations\n-----------\nIt is awesome."
  #
  #   reader = Reader.new source.lines.entries
  #   # create empty document to parent the section
  #   # and hold attributes extracted from header
  #   doc = Document.new
  #
  #   Lexer.next_section(reader, doc).first.title
  #   # => "Greetings"
  #
  #   Lexer.next_section(reader, doc).first.title
  #   # => "Salutations"
  #
  # returns a two-element Array containing the Section and Hash of orphaned attributes
  def self.next_section(reader, parent, attributes = {})
    preamble = false

    # check if we are at the start of processing the document
    # NOTE we could drop a hint in the attributes to indicate
    # that we are at a section title (so we don't have to check)
    if parent.is_a?(Document) && parent.blocks.empty? &&
        (parent.has_header? || !is_next_line_section?(reader, attributes))

      if parent.has_header?
        preamble = Block.new(parent, :preamble)
        parent << preamble
      end
      section = parent

      current_level = 0
      if parent.attributes.has_key? 'fragment'
        expected_next_levels = nil
      # small tweak to allow subsequent level-0 sections for book doctype
      elsif parent.doctype == 'book'
        expected_next_levels = [0, 1]
      else
        expected_next_levels = [1]
      end
    else
      section = initialize_section(reader, parent, attributes)
      # clear attributes, except for title which carries over
      # section title to next block of content
      attributes = attributes.delete_if {|k, v| k != 'title'}
      current_level = section.level
      expected_next_levels = [current_level + 1]
    end

    reader.skip_blank_lines

    # Parse lines belonging to this section and its subsections until we
    # reach the end of this section level
    #
    # 1. first look for metadata thingies (anchor, attribute list, block title line, etc)
    # 2. then look for a section, recurse if found
    # 3. then process blocks
    #
    # We have to parse all the metadata lines before continuing with the loop,
    # otherwise subsequent metadata lines get interpreted as block content
    while reader.has_lines?
      parse_block_metadata_lines(reader, section, attributes)

      next_level = is_next_line_section? reader, attributes
      if next_level
        doctype = parent.document.doctype
        if next_level == 0 && doctype != 'book'
          puts "asciidoctor: ERROR: only book doctypes can contain level 0 sections"
        end
        if next_level > current_level || (section.is_a?(Document) && next_level == 0)
          unless expected_next_levels.nil? || expected_next_levels.include?(next_level)
            puts "asciidoctor: WARNING: section title out of sequence: " +
                "expected #{expected_next_levels.size > 1 ? 'levels' : 'level'} #{expected_next_levels * ' or '}, " +
                "got level #{next_level}"
          end
          # the attributes returned are those that are orphaned
          new_section, attributes = next_section(reader, section, attributes)
          section << new_section
        else
          # close this section (and break out of the nesting) to begin a new one
          break
        end
      else
        # just take one block or else we run the risk of overrunning section boundaries
        new_block = next_block(reader, section, attributes, :parse_metadata => false)
        if !new_block.nil?
          (preamble || section) << new_block
          attributes = {}
        else
          # don't clear attributes if we don't find a block because they may
          # be trailing attributes that didn't get associated with a block
        end
      end

      reader.skip_blank_lines
    end

    # prune the preamble if it has no content
    if preamble && preamble.blocks.empty?
      section.delete_at(0)
    end

    # The attributes returned here are orphaned attributes that fall at the end
    # of a section that need to get transfered to the next section
    # see "trailing block attributes transfer to the following section" in
    # test/attributes_test.rb for an example
    [section != parent ? section : nil, attributes.dup]
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
  def self.next_block(reader, parent, attributes = {}, options = {})
    # Skip ahead to the block content
    skipped = reader.skip_blank

    # bail if we've reached the end of the section content
    return nil unless reader.has_lines?

    if options[:text] && skipped > 0
      options.delete(:text)
    end

    Asciidoctor.debug {
      msg = []
      msg << '/' * 64
      msg << 'next_block() - First two lines are:'
      msg << reader.peek_line
      tmp_line = reader.get_line
      msg << reader.peek_line
      reader.unshift tmp_line
      msg << '/' * 64
      msg * "\n"
    }
    
    parse_metadata = options[:parse_metadata] || true
    parse_sections = options[:parse_sections] || false

    document = parent.document
    context = parent.is_a?(Block) ? parent.context : nil
    block = nil

    while reader.has_lines? && block.nil?
      if parse_metadata && parse_block_metadata_line(reader, document, attributes, options)
        reader.next_line
        next
      elsif parse_sections && context.nil? && is_next_line_section?(reader, attributes)
        block, attributes = next_section(reader, parent, attributes)
        break
      end

      this_line = reader.get_line

      delimited_blk = delimited_block? this_line

      # NOTE I've haven't decided whether I want this check here or in
      # parse_block_metadata (where it is currently)
      #if this_line.match(REGEXP[:comment_blk])
      #  reader.grab_lines_until {|line| line.match( REGEXP[:comment_blk] ) }
      #  reader.skip_blank
      #  # NOTE we should break here because we have found a block, it
      #  # just happens to be nil...if we keep going we potentially overrun
      #  # a section heading which is not processed in this anymore
      #  break

      # NOTE we're letting ruler have attributes
      if !options[:text] && this_line.match(REGEXP[:ruler])
        block = Block.new(parent, :ruler)
        reader.skip_blank

      elsif !options[:text] && (match = this_line.match(REGEXP[:image_blk]))
        block = Block.new(parent, :image)
        AttributeList.new(document.sub_attributes(match[2])).parse_into(attributes, ['alt', 'width', 'height'])
        target = block.sub_attributes(match[1])
        if !target.to_s.empty?
          attributes['target'] = target
          document.register(:images, target)
          attributes['alt'] ||= File.basename(target, File.extname(target))
          # hmmm, this assignment seems like a one-off
          block.title = attributes['title']
          if block.title? && attributes['caption'].nil?
            attributes['caption'] = "Figure #{document.counter('figure-number')}. "
          end
        else
          # drop the line if target resolves to nothing
          block = nil
        end
        reader.skip_blank

      elsif delimited_blk && (match = this_line.match(REGEXP[:open_blk]))
        # an open block is surrounded by '--' lines and has zero or more blocks inside
        terminator = match[0]
        buffer = Reader.new reader.grab_lines_until(:terminator => terminator)

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
      elsif delimited_blk && (match = this_line.match(REGEXP[:sidebar_blk]))
        # sidebar is surrounded by '****' (4 or more '*' chars) lines
        terminator = match[0]
        # FIXME violates DRY because it's a duplication of quote parsing
        block = Block.new(parent, :sidebar)
        buffer = Reader.new reader.grab_lines_until(:terminator => terminator)

        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      elsif match = this_line.match(REGEXP[:colist])
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
            coids = document.callouts.callout_ids(items.size)
            if !coids.empty?
              list_item.attributes['coids'] = coids
            else
              puts 'asciidoctor: WARNING: no callouts refer to list item ' + items.size.to_s
            end
          end
        end while reader.has_lines? && match = reader.peek_line.match(REGEXP[:colist])

        document.callouts.next_list

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
        AttributeList.rekey(attributes, ['style'])

      elsif delimited_blk && (match = this_line.match(document.nested? ? REGEXP[:table_nested] : REGEXP[:table]))
        # table is surrounded by lines starting with a | followed by 3 or more '=' chars
        terminator = match[0]
        AttributeList.rekey(attributes, ['style'])
        table_reader = Reader.new reader.grab_lines_until(:terminator => terminator, :skip_line_comments => true)
        block = next_table(table_reader, parent, attributes)
        # hmmm, this assignment seems like a one-off
        block.title = attributes['title']
        if block.title? && attributes['caption'].nil?
          attributes['caption'] = "Table #{document.counter('table-number')}. "
        end
    
      # FIXME violates DRY because it's a duplication of other block parsing
      elsif delimited_blk && (match = this_line.match(REGEXP[:example]))
        # example is surrounded by lines with 4 or more '=' chars
        terminator = match[0]
        AttributeList.rekey(attributes, ['style'])
        if admonition_style = ADMONITION_STYLES.detect {|s| attributes['style'] == s}
          block = Block.new(parent, :admonition)
          attributes['name'] = admonition_style.downcase
          attributes['caption'] ||= admonition_style.capitalize
        else
          block = Block.new(parent, :example)
          # hmmm, this assignment seems like a one-off
          block.title = attributes['title']
          if block.title? && attributes['caption'].nil?
            attributes['caption'] = "Example #{document.counter('example-number')}. "
          end
        end
        buffer = Reader.new reader.grab_lines_until(:terminator => terminator)

        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      # FIXME violates DRY w/ non-delimited block listing
      elsif delimited_blk && (match = this_line.match(REGEXP[:listing]))
        terminator = match[0]
        AttributeList.rekey(attributes, ['style', 'language', 'linenums'])
        buffer = reader.grab_lines_until(:terminator => terminator)
        buffer.last.chomp! unless buffer.empty?
        block = Block.new(parent, :listing, buffer)

      elsif delimited_blk && (match = this_line.match(REGEXP[:quote]))
        # multi-line verse or quote is surrounded by a block delimiter
        terminator = match[0]
        AttributeList.rekey(attributes, ['style', 'attribution', 'citetitle'])
        quote_context = (attributes['style'] == 'verse' ? :verse : :quote)
        block_reader = Reader.new reader.grab_lines_until(:terminator => terminator)

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

      elsif delimited_blk && (blk_ctx = [:literal, :pass].detect{|t| this_line.match(REGEXP[t])})
        # literal is surrounded by '....' (4 or more '.' chars) lines
        # pass is surrounded by '++++' (4 or more '+' chars) lines
        terminator = $~[0]
        buffer = reader.grab_lines_until(:terminator => terminator)
        buffer.last.chomp! unless buffer.empty?
        # a literal can masquerade as a listing
        if attributes[1] == 'listing'
          blk_ctx = :listing
        end
        block = Block.new(parent, blk_ctx, buffer)

      elsif this_line.match(REGEXP[:lit_par])
        # literal paragraph is contiguous lines starting with
        # one or more space or tab characters

        # So we need to actually include this one in the grab_lines group
        reader.unshift this_line
        buffer = reader.grab_lines_until(:preserve_last_line => true, :break_on_blank_lines => true) {|line|
          # labeled list terms can be indented, but a preceding blank indicates
          # we are in a list continuation and therefore literals should be strictly literal
          (context == :dlist && skipped == 0 && line.match(REGEXP[:dlist])) ||
          delimited_block?(line)
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

      # a floating (i.e., discrete) title
      elsif ['float', 'discrete'].include?(attributes[1]) && is_section_title?(this_line, reader.peek_line)
        attributes['style'] = attributes[1]
        reader.unshift this_line
        float_id, float_title, float_level, _ = parse_section_title reader
        block = Block.new(parent, :floating_title)
        if float_id.nil? || float_id.empty?
          # FIXME remove hack of creating throwaway Section to get at the generate_id method
          tmp_sect = Section.new(parent)
          tmp_sect.title = float_title
          block.id = tmp_sect.generate_id
        else
          block.id = float_id
          @document.register(:ids, [float_id, float_title])
        end
        block.level = float_level
        block.title = float_title

      # a paragraph - contiguous nonblank/noncontinuation lines
      else
        reader.unshift this_line
        buffer = reader.grab_lines_until(:break_on_blank_lines => true, :preserve_last_line => true, :skip_line_comments => true) {|line|
          delimited_block?(line) || line.match(REGEXP[:attr_line]) ||
          # next list item can be directly adjacent to paragraph of previous list item
          context == :dlist && line.match(REGEXP[:dlist])
          # not sure if there are any cases when we need this check for other list types
          #LIST_CONTEXTS.include?(context) && line.match(REGEXP[context])
        }

        # NOTE we need this logic because the reader is processing line
        # comments and that might leave us w/ an empty buffer
        if buffer.empty?
          reader.get_line
          break
        end

        catalog_inline_anchors(buffer.join, document)

        if !options[:text] && (admonition = buffer.first.match(Regexp.new('^(' + ADMONITION_STYLES.join('|') + '):\s+')))
          buffer[0] = admonition.post_match
          block = Block.new(parent, :admonition, buffer)
          attributes['style'] = admonition[1]
          attributes['name'] = admonition[1].downcase
          attributes['caption'] ||= admonition[1].capitalize
        else
          buffer.last.chomp!
          block = Block.new(parent, :paragraph, buffer)
        end
      end
    end

    # when looking for nested content, one or more line comments, comment
    # blocks or trailing attribute lists could leave us without a block,
    # so handle accordingly
    if !block.nil?
      block.id        = attributes['id'] if attributes.has_key?('id')
      block.title     = attributes['title'] unless block.title?
      block.caption ||= attributes['caption'] unless block.is_a?(Section)
      # AsciiDoc always use [id] as the reftext in HTML output,
      # but I'd like to do better in Asciidoctor
      if block.id && block.title? && !attributes.has_key?('reftext')
        document.register(:ids, [block.id, block.title])
      end
      block.update_attributes(attributes)

      if block.context == :listing || block.context == :literal
        catalog_callouts(block.buffer.join, document)
      end
    end

    block
  end

  # Public: Determines whether this line is the start of any of the delimited blocks
  #
  # returns the match data if this line is the first line of a delimited block or nil if not
  #--
  # TODO could use the match value as a lookup for the block type so we don't have
  # to do any subsequent regexp
  def self.delimited_block?(line)
    # naive match
    #line.match(REGEXP[:any_blk])

    # attempt at better performance
    if line.length > 0
      # NOTE accessing the first element before calling ord is first Ruby 1.8.7 compat
      REGEXP[:any_blk_ord].include?(line[0..0][0].ord) ? line.match(REGEXP[:any_blk]) : nil
    else
      nil
    end
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
    Asciidoctor.debug { "Created #{list_type} block: #{list_block}" }

    while reader.has_lines? && (match = reader.peek_line.match(REGEXP[list_type]))

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

      if items.size == 0 || this_item_level == list_block.level
        list_item = next_list_item(reader, list_block, match)
      elsif this_item_level < list_block.level
        # leave this block
        break
      elsif this_item_level > list_block.level
        # If this next list level is down one from the
        # current Block's, append it to content of the current list item
        items.last.blocks << next_block(reader, list_block)
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
      id.sub!(/^("|)(.*)\1$/, '\2')
      if !reftext.nil?
        reftext.sub!(/^("|)(.*)\1$/m, '\2')
      end
      document.register(:ids, [id, reftext])
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
      options = {:text => !has_text}

      while list_item_reader.has_lines?
        new_block = next_block(list_item_reader, list_block, {}, options)
        list_item.blocks << new_block unless new_block.nil?
      end

      list_item.fold_first(continuation_connects_first_block, content_adjacent)
    end

    if list_type == :dlist
      unless list_item.text? || list_item.blocks?
        list_item = nil
      end
      [list_term, list_item]
    else
      list_item
    end
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
  #
  # Returns an Array of lines belonging to the current list item.
  def self.grab_lines_for_list_item(reader, list_type, sibling_trait = nil, has_text = true)
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
          buffer[buffer.size - 1] = "\n" unless within_nested_list
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
      if match = delimited_block?(this_line)
        if continuation == :active
          buffer << this_line
          # grab all the lines in the block, leaving the delimiters in place
          # we're being more strict here about the terminator, but I think that's a good thing
          terminator = match[0]
          buffer.concat reader.grab_lines_until(:terminator => terminator, :grab_last_line => true)
          continuation = :inactive
        else
          break
        end
      # technically attr_line only breaks if ensuing line is not a list item
      # which really means attr_line only breaks if it's acting as a block delimiter
      elsif list_type == :dlist && continuation != :active && this_line.match(REGEXP[:attr_line])
        break
      else
        if continuation == :active && !this_line.chomp.empty?
          # literal paragraphs have special considerations (and this is one of 
          # two entry points into one)
          # if we don't process it as a whole, then a line in it that looks like a
          # list item will throw off the exit from it
          if this_line.match(REGEXP[:lit_par])
            reader.unshift this_line
            buffer.concat reader.grab_lines_until(
              :preserve_last_line => true,
              :break_on_blank_lines => true,
              :break_on_list_continuation => true) {|line|
                # we may be in an indented list disguised as a literal paragraph
                # so we need to make sure we don't slurp up a legitimate sibling
                list_type == :dlist && is_sibling_list_item?(line, list_type, sibling_trait)
            }
            continuation = :inactive
          # let block metadata play out until we find the block
          elsif this_line.match(REGEXP[:blk_title]) || this_line.match(REGEXP[:attr_line])
            buffer << this_line
          else
            if nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).detect {|ctx| this_line.match(REGEXP[ctx]) }
              within_nested_list = true
              if nested_list_type == :dlist && $~[3].to_s.empty?
                # get greedy again
                has_text = false
              end
            end
            buffer << this_line
            continuation = :inactive
          end
        elsif !prev_line.nil? && prev_line.chomp.empty?
          # advance to the next line of content
          if this_line.chomp.empty?
            reader.skip_blank_lines
            this_line = reader.get_line 
            # if we hit eof or a sibling, stop reading
            break if this_line.nil? || is_sibling_list_item?(this_line, list_type, sibling_trait)
          end

          if this_line.chomp == LIST_CONTINUATION
            detached_continuation = buffer.size
            buffer << this_line
          else
            # has_text is only relevant for dlist, which is more greedy until it has text for an item
            # for all other lists, has_text is always true
            # in this block, we have to see whether we stay in the list
            if has_text
              # slurp up any literal paragraph offset by blank lines
              if this_line.match(REGEXP[:lit_par])
                reader.unshift this_line
                buffer.concat reader.grab_lines_until(
                  :preserve_last_line => true,
                  :break_on_blank_lines => true,
                  :break_on_list_continuation => true) {|line|
                    # we may be in an indented list disguised as a literal paragraph
                    # so we need to make sure we don't slurp up a legitimate sibling
                    list_type == :dlist && is_sibling_list_item?(line, list_type, sibling_trait)
                  }
              # TODO any way to combine this with the check after skipping blank lines?
              elsif is_sibling_list_item?(this_line, list_type, sibling_trait)
                break
              elsif nested_list_type = NESTABLE_LIST_CONTEXTS.detect {|ctx| this_line.match(REGEXP[ctx]) }
                buffer << this_line
                within_nested_list = true
                if nested_list_type == :dlist && $~[3].to_s.empty?
                  # get greedy again
                  has_text = false
                end
              else
                break
              end
            else # only dlist in need of item text, so slurp it up!
              # pop the blank line so it's not interpretted as a list continuation
              buffer.pop unless within_nested_list
              buffer << this_line
              has_text = true
            end
          end
        else
          has_text = true if !this_line.chomp.empty?
          if nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).detect {|ctx| this_line.match(REGEXP[ctx]) }
            within_nested_list = true
            if nested_list_type == :dlist && $~[3].to_s.empty?
              # get greedy again
              has_text = false
            end
          end
          buffer << this_line
        end
      end
      this_line = nil
    end

    reader.unshift this_line if !this_line.nil?

    if detached_continuation
      buffer.delete_at detached_continuation
    end

    # strip trailing blank lines to prevent empty blocks
    buffer.pop while !buffer.empty? && buffer.last.strip.empty?

    # We do need to replace the optional trailing continuation
    # a blank line would have served the same purpose in the document
    if !buffer.empty? && buffer.last.chomp == LIST_CONTINUATION
      buffer.pop
    end
    #puts "BUFFER[#{list_type},#{sibling_trait}]>#{buffer.join}<BUFFER"
    #puts "BUFFER[#{list_type},#{sibling_trait}]>#{buffer}<BUFFER"

    buffer
  end

  # Internal: Initialize a new Section object and assign any attributes provided
  #
  # The information for this section is retrieved by parsing the lines at the
  # current position of the reader.
  #
  # reader     - the source reader
  # parent     - the parent Section or Document of this Section
  # attributes - a Hash of attributes to assign to this section (default: {})
  def self.initialize_section(reader, parent, attributes = {})
    section = Section.new parent
    section.id, section.title, section.level, _ = parse_section_title(reader)
    if section.id.nil? && attributes.has_key?('id')
      section.id = attributes['id']
    else
      # generate an id if one was not *embedded* in the heading line
      # or as an anchor above the section
      section.id ||= section.generate_id
    end

    if attributes[1]
      section.sectname = attributes[1]
      section.special = true
      if section.sectname == 'appendix'
        attributes['caption'] ||= "Appendix #{parent.document.counter('appendix-number', 'A')}: "
      end
    else
      section.sectname = "sect#{section.level}"
    end
    section.update_attributes(attributes)
    reader.skip_blank

    section
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

  # Internal: Checks if the next line on the Reader is a section title
  #
  # reader - the source Reader
  #
  # returns the section level if the Reader is positioned at a section title,
  # false otherwise
  def self.is_next_line_section?(reader, attributes)
    return false if !attributes[1].nil? && ['float', 'discrete'].include?(attributes[1])
    if reader.has_lines?
      line1 = reader.get_line
      line2 = reader.peek_line
      reader.unshift line1
    else
      return false
    end

    is_section_title?(line1, line2)
  end

  # Public: Checks if these lines are a section title
  #
  # line1 - the first line as a String
  # line2 - the second line as a String (default: nil)
  #
  # returns the section level if these lines are a section title,
  # false otherwise
  def self.is_section_title?(line1, line2 = nil)
    if (level = is_single_line_section_title?(line1))
      level
    elsif (level = is_two_line_section_title?(line1, line2))
      level
    else
      false
    end
  end

  def self.is_single_line_section_title?(line1)
    if !line1.nil? && (match = line1.match(REGEXP[:section_title]))
      single_line_section_level match[1]
    else
      false
    end
  end

  def self.is_two_line_section_title?(line1, line2)
    if !line1.nil? && !line2.nil? && line1.match(REGEXP[:section_name]) &&
        line2.match(REGEXP[:section_underline]) &&
        # chomp so that a (non-visible) endline does not impact calculation
        (line1.chomp.size - line2.chomp.size).abs <= 1
      section_level line2
    else
      false
    end
  end

  # Internal: Parse the section title from the current position of the reader
  #
  # Parse a single or double-line section title. After this method is called,
  # the Reader will be positioned at the line after the section title.
  #
  # reader  - the source reader, positioned at a section title
  #
  # Examples
  #
  #   reader.lines
  #   # => ["Foo\n", "~~~\n"]
  #
  #   title, level, id, single = parse_section_title(reader)
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
  #   title, level, id, single = parse_section_title(reader)
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
  # returns an Array of [String, Integer, String, Boolean], representing the
  # id, title, level and line count of the Section, or nil.
  #
  #--
  # NOTE for efficiency, we don't reuse methods that check for a section title
  def self.parse_section_title(reader)
    line1 = reader.get_line
    sect_id = nil
    sect_title = nil
    sect_level = -1
    single_line = true

    if match = line1.match(REGEXP[:section_title])
      sect_id = match[3]
      sect_title = match[2]
      sect_level = single_line_section_level match[1]
    else
      line2 = reader.peek_line
      if !line2.nil? && (name_match = line1.match(REGEXP[:section_name])) &&
        line2.match(REGEXP[:section_underline]) &&
        # chomp so that a (non-visible) endline does not impact calculation
        (line1.chomp.size - line2.chomp.size).abs <= 1
        if anchor_match = name_match[1].match(REGEXP[:anchor_embedded]) 
          sect_id = anchor_match[2]
          sect_title = anchor_match[1]
        else
          sect_title = name_match[1]
        end
        sect_level = section_level line2
        single_line = false
        reader.get_line
      end
    end
    return [sect_id, sect_title, sect_level, single_line]
  end

  # Public: Consume and parse the two header lines (line 1 = author info, line 2 = revision info).
  #
  # Returns the Hash of header metadata. If a Document object is supplied, the metadata
  # is applied directly to the attributes of the Document.
  #
  # reader   - the Reader holding the source lines of the document
  # document - the Document we are building (default: nil)
  #
  # Examples
  #
  #  parse_header_metadata(Reader.new ["Author Name <author@example.org>\n", "v1.0, 2012-12-21: Coincide w/ end of world.\n"])
  #  # => {'author' => 'Author Name', 'firstname' => 'Author', 'lastname' => 'Name', 'email' => 'author@example.org',
  #  #       'revnumber' => '1.0', 'revdate' => '2012-12-21', 'revremark' => 'Coincide w/ end of world.'}
  def self.parse_header_metadata(reader, document = nil)
    # capture consecutive comment lines so we can reinsert them after the header
    comment_lines = reader.consume_comments

    metadata = !document.nil? ? document.attributes : {}
    author_initials = metadata['authorinitials']
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

      # hack because of incorrect order of attribute processing
      metadata['authorinitials'] = author_initials unless author_initials.nil?

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

  # Internal: Parse lines of metadata until a line of metadata is not found.
  #
  # This method processes sequential lines containing block metadata, ignoring
  # blank lines and comments.
  #
  # reader     - the source reader
  # parent     - the parent to which the lines belong
  # attributes - a Hash of attributes in which any metadata found will be stored (default: {})
  # options    - a Hash of options to control processing: (default: {})
  #              *  :text indicates that lexer is only looking for text content
  #                   and thus the block title should not be captured
  #
  # returns the Hash of attributes including any metadata found
  def self.parse_block_metadata_lines(reader, parent, attributes = {}, options = {})
    while parse_block_metadata_line(reader, parent, attributes, options)
      # discard the line just processed
      reader.next_line
      reader.skip_blank_lines
    end
    attributes
  end

  # Internal: Parse the next line if it contains metadata for the following block
  #
  # This method handles lines with the following content:
  #
  # * line or block comment
  # * anchor
  # * attribute list
  # * block title
  #
  # Any attributes found will be inserted into the attributes argument.
  # If the line contains block metadata, the method returns true, otherwise false.
  #
  # reader     - the source reader
  # parent     - the parent of the current line
  # attributes - a Hash of attributes in which any metadata found will be stored
  # options    - a Hash of options to control processing: (default: {})
  #              *  :text indicates that lexer is only looking for text content
  #                   and thus the block title should not be captured
  #
  # returns true if the line contains metadata, otherwise false
  def self.parse_block_metadata_line(reader, parent, attributes, options = {})
    return false if !reader.has_lines?
    next_line = reader.peek_line
    if next_line.match(REGEXP[:comment])
      # do nothing, we'll skip it
    # QUESTION should we parse block comments here instead of next_block?
    # disable until we can agree what the current line is coming in
    elsif match = next_line.match(REGEXP[:comment_blk])
      terminator = match[0]
      reader.grab_lines_until(:skip_first_line => true, :preserve_last_line => true, :terminator => terminator)
    elsif match = next_line.match(REGEXP[:anchor])
      id, reftext = match[1].split(',')
      attributes['id'] = id
      # AsciiDoc always use [id] as the reftext in HTML output,
      # but I'd like to do better in Asciidoctor
      #parent.document.register(:ids, id)
      if reftext
        attributes['reftext'] = reftext
        parent.document.register(:ids, [id, reftext])
      end
    elsif match = next_line.match(REGEXP[:blk_attr_list])
      AttributeList.new(parent.document.sub_attributes(match[1]), parent.document).parse_into(attributes)
    # NOTE title doesn't apply to section, but we need to stash it for the first block
    # TODO need test for this getting passed on to first block after section if found above section
    # TODO should issue an error if this is found above the document title
    elsif !options[:text] && (match = next_line.match(REGEXP[:blk_title]))
      attributes['title'] = match[1]
    else
      return false
    end

    true
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

  # Internal: Parse the table contained in the provided Reader
  #
  # table_reader - a Reader containing the source lines of an AsciiDoc table
  # parent       - the parent Block of this Asciidoctor::Table
  # attributes   - attributes captured from above this Block
  #
  # returns an instance of Asciidoctor::Table parsed from the provided reader
  def self.next_table(table_reader, parent, attributes)
    table = Table.new(parent, attributes)

    if attributes.has_key? 'cols'
      table.create_columns(parse_col_specs(attributes['cols']))
      explicit_col_specs = true
    else
      explicit_col_specs = false
    end

    table_reader.skip_blank_lines

    parser_ctx = Asciidoctor::Table::ParserContext.new(table, attributes)
    while table_reader.has_lines?
      line = table_reader.get_line

      if parser_ctx.format == 'psv'
        if parser_ctx.starts_with_delimiter? line
          line = line[1..-1]
          # push an empty cell spec if boundary at start of line
          parser_ctx.close_open_cell
        else
          next_cell_spec, line = parse_cell_spec(line, :start)
          # if the cell spec is not null, then we're at a cell boundary
          if !next_cell_spec.nil?
            parser_ctx.close_open_cell next_cell_spec
          else
            # QUESTION do we not advance to next line? if so, when
            # will we if we came into this block?
          end
        end
      end

      while !line.empty?
        if m = parser_ctx.match_delimiter(line)
          if parser_ctx.format == 'csv'
            if parser_ctx.buffer_has_unclosed_quotes?(m.pre_match)
              # throw it back, it's too small
              line = parser_ctx.skip_matched_delimiter(m)
              next
            end
          else
            if m.pre_match.end_with? '\\'
              line = parser_ctx.skip_matched_delimiter(m, true)
              next
            end
          end

          if parser_ctx.format == 'psv'
            next_cell_spec, cell_text = parse_cell_spec(m.pre_match, :end)
            parser_ctx.push_cell_spec next_cell_spec
            parser_ctx.buffer << cell_text
          else
            parser_ctx.buffer << m.pre_match
          end

          line = m.post_match
          parser_ctx.close_cell
        else
          # no other delimiters to see here
          # suck up this line into the buffer and move on
          parser_ctx.buffer << line
          # QUESTION make this an option? (unwrap-option?)
          if parser_ctx.format == 'csv'
            parser_ctx.buffer.rstrip!.concat(' ')
          end
          line = ''
          if parser_ctx.format == 'psv' || (parser_ctx.format == 'csv' &&
              parser_ctx.buffer_has_unclosed_quotes?)
            parser_ctx.keep_cell_open
          else
            parser_ctx.close_cell true
          end
        end
      end

      table_reader.skip_blank_lines unless parser_ctx.cell_open?

      if !table_reader.has_lines?
        parser_ctx.close_cell true
      end
    end

    table.attributes['colcount'] ||= parser_ctx.col_count

    if !explicit_col_specs
      # TODO further encapsulate this logic (into table perhaps?)
      even_width = (100.0 / parser_ctx.col_count).floor
      table.columns.each {|c| c.assign_width(0, even_width) }
    end

    table.partition_header_footer attributes

    table
  end

  # Internal: Parse the column specs for this table.
  #
  # The column specs dictate the number of columns, relative
  # width of columns, default alignments for cells in each
  # column, and/or default styles or filters applied to the cells in 
  # the column.
  #
  # Every column spec is guaranteed to have a width
  #
  # returns a Hash of attributes that specify how to format
  # and layout the cells in the table.
  def self.parse_col_specs(records)
    specs = []

    # check for deprecated syntax
    if m = records.match(REGEXP[:digits])
      1.upto(m[0].to_i) {
        specs << {'width' => 1}
      }
      return specs
    end

    records.split(',').each {|record|
      # TODO might want to use scan rather than this mega-regexp
      if m = record.match(REGEXP[:table_colspec])
        spec = {}
        if m[2]
          # make this an operation
          colspec, rowspec = m[2].split '.'
          if !colspec.to_s.empty? && Table::ALIGNMENTS[:h].has_key?(colspec)
            spec['halign'] = Table::ALIGNMENTS[:h][colspec]
          end
          if !rowspec.to_s.empty? && Table::ALIGNMENTS[:v].has_key?(rowspec)
            spec['valign'] = Table::ALIGNMENTS[:v][rowspec]
          end
        end

        # TODO support percentage width
        spec['width'] = !m[3].nil? ? m[3].to_i : 1

        # make this an operation
        if m[4] && Table::TEXT_STYLES.has_key?(m[4])
          spec['style'] = Table::TEXT_STYLES[m[4]]
        end

        repeat = !m[1].nil? ? m[1].to_i : 1

        1.upto(repeat) {
          specs << spec.dup
        }
      end
    }
    specs
  end

  # Internal: Parse the cell specs for the current cell.
  #
  # The cell specs dictate the cell's alignments, styles or filters,
  # colspan, rowspan and/or repeating content.
  # 
  # returns the Hash of attributes that indicate how to layout
  # and style this cell in the table.
  def self.parse_cell_spec(line, pos = :start)
    # the default for the end pos it {} since we
    # know we're at a delimiter; when the pos
    # is start, we *may* be at a delimiter and
    # nil indicates we're not
    spec = (pos == :end ? {} : nil)
    rest = line

    if m = line.match(REGEXP[:table_cellspec][pos]) 
      spec = {}
      return [spec, line] if m[0].strip.empty?
      rest = (pos == :start ? m.post_match : m.pre_match)
      if m[1]
        colspec, rowspec = m[1].split '.'
        colspec = colspec.to_s.empty? ? 1 : colspec.to_i
        rowspec = rowspec.to_s.empty? ? 1 : rowspec.to_i
        if m[2] == '+'
          spec['colspan'] = colspec unless colspec == 1
          spec['rowspan'] = rowspec unless rowspec == 1
        elsif m[2] == '*'
          spec['repeatcol'] = colspec unless colspec == 1
        end
      end
      
      if m[3]
        colspec, rowspec = m[3].split '.'
        if !colspec.to_s.empty? && Table::ALIGNMENTS[:h].has_key?(colspec)
          spec['halign'] = Table::ALIGNMENTS[:h][colspec]
        end
        if !rowspec.to_s.empty? && Table::ALIGNMENTS[:v].has_key?(rowspec)
          spec['valign'] = Table::ALIGNMENTS[:v][rowspec]
        end
      end

      if m[4] && Table::TEXT_STYLES.has_key?(m[4])
        spec['style'] = Table::TEXT_STYLES[m[4]]
      end
    end 

    [spec, rest]
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
