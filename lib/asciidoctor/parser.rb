module Asciidoctor
# Public: Methods to parse lines of AsciiDoc into an object hierarchy
# representing the structure of the document. All methods are class methods and
# should be invoked from the Parser class. The main entry point is ::next_block.
# No Parser instances shall be discovered running around. (Any attempt to
# instantiate a Parser will be futile).
#
# The object hierarchy created by the Parser consists of zero or more Section
# and Block objects. Section objects may be nested and a Section object
# contains zero or more Block objects. Block objects may be nested, but may
# only contain other Block objects. Block objects which represent lists may
# contain zero or more ListItem objects.
#
# Examples
#
#   # Create a Reader for the AsciiDoc lines and retrieve the next block from it.
#   # Parser.next_block requires a parent, so we begin by instantiating an empty Document.
#
#   doc = Document.new
#   reader = Reader.new lines
#   block = Parser.next_block(reader, doc)
#   block.class
#   # => Asciidoctor::Block
class Parser

  BlockMatchData = Struct.new :context, :masq, :tip, :terminator

  # Public: Make sure the Parser object doesn't get initialized.
  #
  # Raises RuntimeError if this constructor is invoked.
  def initialize
    raise 'Au contraire, mon frere. No lexer instances will be running around.'
  end

  # Public: Parses AsciiDoc source read from the Reader into the Document
  #
  # This method is the main entry-point into the Parser when parsing a full document.
  # It first looks for and, if found, processes the document title. It then
  # proceeds to iterate through the lines in the Reader, parsing the document
  # into nested Sections and Blocks.
  #
  # reader   - the Reader holding the source lines of the document
  # document - the empty Document into which the lines will be parsed
  # options  - a Hash of options to control processing
  #
  # returns the Document object
  def self.parse(reader, document, options = {})
    block_attributes = parse_document_header(reader, document)

    unless options[:header_only]
      while reader.has_more_lines?
        new_section, block_attributes = next_section(reader, document, block_attributes)
        document << new_section if new_section
      end
      # NOTE we could try to avoid creating a preamble in the first place, though
      # that would require reworking assumptions in next_section since the preamble
      # is treated like an untitled section
      # NOTE logic relocated to end of next_section
      #if Compliance.unwrap_standalone_preamble &&
      #    document.blocks.size == 1 && (first_block = document.blocks[0]).context == :preamble &&
      #    first_block.blocks? && (document.doctype != 'book' || first_block.blocks[0].style != 'abstract')
      #  preamble = document.blocks.shift
      #  while (child_block = preamble.blocks.shift)
      #    child_block.parent = document
      #    document << child_block
      #  end
      #end
    end

    document
  end

  # Public: Parses the document header of the AsciiDoc source read from the Reader
  #
  # Reads the AsciiDoc source from the Reader until the end of the document
  # header is reached. The Document object is populated with information from
  # the header (document title, document attributes, etc). The document
  # attributes are then saved to establish a save point to which to rollback
  # after parsing is complete.
  #
  # This method assumes that there are no blank lines at the start of the document,
  # which are automatically removed by the reader.
  #
  # returns the Hash of orphan block attributes captured above the header
  def self.parse_document_header(reader, document)
    # capture any lines of block-level metadata and plow away any comment lines
    # that precede first block
    block_attributes = parse_block_metadata_lines(reader, document)

    # special case, block title is not allowed above document title,
    # carry attributes over to the document body
    if block_attributes.has_key?('title')
      return document.finalize_header block_attributes, false
    end

    # yep, document title logic in AsciiDoc is just insanity
    # definitely an area for spec refinement
    assigned_doctitle = nil
    unless (val = document.attributes['doctitle']).nil_or_empty?
      document.title = val
      assigned_doctitle = val
    end

    section_title = nil
    # check if the first line is the document title
    # if so, add a header to the document and parse the header metadata
    if is_next_line_document_title?(reader, block_attributes)
      source_location = reader.cursor if document.sourcemap
      document.id, _, doctitle, _, single_line = parse_section_title(reader, document)
      unless assigned_doctitle
        document.title = doctitle
        assigned_doctitle = doctitle
      end
      # default to compat-mode if document uses atx-style doctitle
      document.set_attribute 'compat-mode', '' unless single_line
      document.header.source_location = source_location if source_location
      document.attributes['doctitle'] = section_title = doctitle
      # QUESTION: should the id assignment on Document be encapsulated in the Document class?
      unless document.id
        document.id = block_attributes.delete('id')
      end
      parse_header_metadata(reader, document)
    end

    if !(val = document.attributes['doctitle']).nil_or_empty? &&
        val != section_title
      document.title = val
      assigned_doctitle = val
    end

    # restore doctitle attribute to original assignment
    if assigned_doctitle
      document.attributes['doctitle'] = assigned_doctitle
    end

    # parse title and consume name section of manpage document
    parse_manpage_header(reader, document) if document.doctype == 'manpage'
 
    # NOTE block_attributes are the block-level attributes (not document attributes) that
    # precede the first line of content (document title, first section or first block)
    document.finalize_header block_attributes
  end

  # Public: Parses the manpage header of the AsciiDoc source read from the Reader
  #
  # returns Nothing
  def self.parse_manpage_header(reader, document)
    if (m = ManpageTitleVolnumRx.match(document.attributes['doctitle']))
      document.attributes['mantitle'] = document.sub_attributes(m[1].rstrip.downcase)
      document.attributes['manvolnum'] = m[2].strip
    else
      warn %(asciidoctor: ERROR: #{reader.prev_line_info}: malformed manpage title)
    end

    reader.skip_blank_lines

    if is_next_line_section?(reader, {})
      name_section = initialize_section(reader, document, {})
      if name_section.level == 1
        name_section_buffer = reader.read_lines_until(:break_on_blank_lines => true).join(' ').tr_s(' ', ' ')
        if (m = ManpageNamePurposeRx.match(name_section_buffer))
          document.attributes['manname'] = document.sub_attributes m[1]
          document.attributes['manpurpose'] = m[2] 
          # TODO parse multiple man names

          if document.backend == 'manpage'
            document.attributes['docname'] = document.attributes['manname']
            document.attributes['outfilesuffix'] = %(.#{document.attributes['manvolnum']})
          end
        else
          warn %(asciidoctor: ERROR: #{reader.prev_line_info}: malformed name section body)
        end
      else
        warn %(asciidoctor: ERROR: #{reader.prev_line_info}: name section title must be at level 1)
      end
    else
      warn %(asciidoctor: ERROR: #{reader.prev_line_info}: name section expected)
    end
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
  #   # => "= Greetings\n\nThis is my doc.\n\n== Salutations\n\nIt is awesome."
  #
  #   reader = Reader.new source, nil, :normalize => true
  #   # create empty document to parent the section
  #   # and hold attributes extracted from header
  #   doc = Document.new
  #
  #   Parser.next_section(reader, doc).first.title
  #   # => "Greetings"
  #
  #   Parser.next_section(reader, doc).first.title
  #   # => "Salutations"
  #
  # returns a two-element Array containing the Section and Hash of orphaned attributes
  def self.next_section(reader, parent, attributes = {})
    preamble = false
    part = false
    intro = false

    # FIXME if attributes[1] is a verbatim style, then don't check for section

    # check if we are at the start of processing the document
    # NOTE we could drop a hint in the attributes to indicate
    # that we are at a section title (so we don't have to check)
    if parent.context == :document && parent.blocks.empty? &&
        ((has_header = parent.has_header?) || attributes.delete('invalid-header') || !is_next_line_section?(reader, attributes))
      doctype = parent.doctype
      if has_header || (doctype == 'book' && attributes[1] != 'abstract')
        preamble = intro = Block.new(parent, :preamble, :content_model => :compound)
        parent << preamble
      end
      section = parent

      current_level = 0
      if parent.attributes.has_key? 'fragment'
        expected_next_levels = nil
      # small tweak to allow subsequent level-0 sections for book doctype
      elsif doctype == 'book'
        expected_next_levels = [0, 1]
      else
        expected_next_levels = [1]
      end
    else
      doctype = parent.document.doctype
      section = initialize_section(reader, parent, attributes)
      # clear attributes, except for title which carries over
      # section title to next block of content
      attributes = (title = attributes['title']) ? { 'title' => title } : {}
      current_level = section.level
      if current_level == 0 && doctype == 'book'
        part = !section.special
        # subsections in preface & appendix in multipart books start at level 2
        if section.special && (['preface', 'appendix'].include? section.sectname)
          expected_next_levels = [current_level + 2]
        else
          expected_next_levels = [current_level + 1]
        end
      else
        expected_next_levels = [current_level + 1]
      end
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
    while reader.has_more_lines?
      parse_block_metadata_lines(reader, section, attributes)

      if (next_level = is_next_line_section? reader, attributes)
        next_level += section.document.attr('leveloffset', 0).to_i
        if next_level > current_level || (section.context == :document && next_level == 0)
          if next_level == 0 && doctype != 'book'
            warn %(asciidoctor: ERROR: #{reader.line_info}: only book doctypes can contain level 0 sections)
          elsif expected_next_levels && !expected_next_levels.include?(next_level)
            warn %(asciidoctor: WARNING: #{reader.line_info}: section title out of sequence: ) +
                %(expected #{expected_next_levels.size > 1 ? 'levels' : 'level'} #{expected_next_levels * ' or '}, ) +
                %(got level #{next_level})
          end
          # the attributes returned are those that are orphaned
          new_section, attributes = next_section(reader, section, attributes)
          section << new_section
        else
          if next_level == 0 && doctype != 'book'
            warn %(asciidoctor: ERROR: #{reader.line_info}: only book doctypes can contain level 0 sections)
          end
          # close this section (and break out of the nesting) to begin a new one
          break
        end
      else
        # just take one block or else we run the risk of overrunning section boundaries
        block_line_info = reader.line_info
        if (new_block = next_block reader, (intro || section), attributes, :parse_metadata => false)
          # REVIEW this may be doing too much
          if part
            if !section.blocks?
              # if this block wasn't marked as [partintro], emulate behavior as if it had
              if new_block.style != 'partintro'
                # emulate [partintro] paragraph
                if new_block.context == :paragraph
                  new_block.context = :open
                  new_block.style = 'partintro'
                # emulate [partintro] open block
                else
                  intro = Block.new section, :open, :content_model => :compound
                  intro.style = 'partintro'
                  new_block.parent = intro
                  section << intro
                end
              end
            elsif section.blocks.size == 1
              first_block = section.blocks[0]
              # open the [partintro] open block for appending
              if !intro && first_block.content_model == :compound
                #new_block.parent = (intro = first_block)
                warn %(asciidoctor: ERROR: #{block_line_info}: illegal block content outside of partintro block)
              # rebuild [partintro] paragraph as an open block
              elsif first_block.content_model != :compound
                intro = Block.new section, :open, :content_model => :compound
                intro.style = 'partintro'
                section.blocks.shift 
                if first_block.style == 'partintro'
                  first_block.context = :paragraph
                  first_block.style = nil
                end
                first_block.parent = intro
                intro << first_block
                new_block.parent = intro
                section << intro
              end
            end
          end

          (intro || section) << new_block
          attributes = {}
        #else
        #  # don't clear attributes if we don't find a block because they may
        #  # be trailing attributes that didn't get associated with a block
        end
      end

      reader.skip_blank_lines
    end

    if part
      unless section.blocks? && section.blocks[-1].context == :section
        warn %(asciidoctor: ERROR: #{reader.line_info}: invalid part, must have at least one section (e.g., chapter, appendix, etc.))
      end
    # NOTE we could try to avoid creating a preamble in the first place, though
    # that would require reworking assumptions in next_section since the preamble
    # is treated like an untitled section
    elsif preamble # implies parent == document
      document = parent
      if preamble.blocks?
        # unwrap standalone preamble (i.e., no sections), if permissible
        if Compliance.unwrap_standalone_preamble && document.blocks.size == 1 && doctype != 'book'
          document.blocks.shift
          while (child_block = preamble.blocks.shift)
            child_block.parent = document
            document << child_block
          end
        end
      # drop the preamble if it has no content
      else
        document.blocks.shift
      end
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
  #--
  # QUESTION should next_block have an option for whether it should keep looking until
  # a block is found? right now it bails when it encounters a line to be skipped
  def self.next_block(reader, parent, attributes = {}, options = {})
    # Skip ahead to the block content
    skipped = reader.skip_blank_lines

    # bail if we've reached the end of the parent block or document
    return unless reader.has_more_lines?

    # check for option to find list item text only
    # if skipped a line, assume a list continuation was
    # used and block content is acceptable
    if (text_only = options[:text]) && skipped > 0
      options.delete(:text)
      text_only = false
    end
    
    parse_metadata = options.fetch(:parse_metadata, true)
    #parse_sections = options.fetch(:parse_sections, false)

    document = parent.document
    if (extensions = document.extensions)
      block_extensions = extensions.blocks?
      block_macro_extensions = extensions.block_macros?
    else
      block_extensions = block_macro_extensions = false
    end
    #parent_context = parent.is_a?(Block) ? parent.context : nil
    in_list = (parent.is_a? List)
    block = nil
    style = nil
    explicit_style = nil
    sourcemap = document.sourcemap
    source_location = nil

    while !block && reader.has_more_lines?
      # if parsing metadata, read until there is no more to read
      if parse_metadata && parse_block_metadata_line(reader, document, attributes, options)
        reader.advance
        next
      #elsif parse_sections && !parent_context && is_next_line_section?(reader, attributes)
      #  block, attributes = next_section(reader, parent, attributes)
      #  break
      end

      # QUESTION should we introduce a parsing context object?
      source_location = reader.cursor if sourcemap
      this_line = reader.read_line
      delimited_block = false
      block_context = nil
      cloaked_context = nil
      terminator = nil
      # QUESTION put this inside call to rekey attributes?
      if attributes[1]
        style, explicit_style = parse_style_attribute(attributes, reader)
      end

      if (delimited_blk_match = is_delimited_block? this_line, true)
        delimited_block = true
        block_context = cloaked_context = delimited_blk_match.context
        terminator = delimited_blk_match.terminator
        if !style
          style = attributes['style'] = block_context.to_s
        elsif style != block_context.to_s
          if delimited_blk_match.masq.include? style
            block_context = style.to_sym
          elsif delimited_blk_match.masq.include?('admonition') && ADMONITION_STYLES.include?(style)
            block_context = :admonition
          elsif block_extensions && extensions.registered_for_block?(style, block_context)
            block_context = style.to_sym
          else
            warn %(asciidoctor: WARNING: #{reader.prev_line_info}: invalid style for #{block_context} block: #{style})
            style = block_context.to_s
          end
        end
      end

      unless delimited_block

        # this loop only executes once; used for flow control
        # break once a block is found or at end of loop
        # returns nil if the line must be dropped
        # Implementation note - while(true) is twice as fast as loop
        while true

          # process lines verbatim
          if style && Compliance.strict_verbatim_paragraphs && VERBATIM_STYLES.include?(style)
            block_context = style.to_sym
            reader.unshift_line this_line
            # advance to block parsing =>
            break
          end

          # process lines normally
          unless text_only
            first_char = Compliance.markdown_syntax ? this_line.lstrip.chr : this_line.chr
            # NOTE we're letting break lines (horizontal rule, page_break, etc) have attributes
            if (LAYOUT_BREAK_LINES.has_key? first_char) && this_line.length >= 3 &&
                (Compliance.markdown_syntax ? LayoutBreakLinePlusRx : LayoutBreakLineRx) =~ this_line
              block = Block.new(parent, LAYOUT_BREAK_LINES[first_char], :content_model => :empty)
              break

            elsif this_line.end_with?(']') && (match = MediaBlockMacroRx.match(this_line))
              blk_ctx = match[1].to_sym
              block = Block.new(parent, blk_ctx, :content_model => :empty)
              if blk_ctx == :image
                posattrs = ['alt', 'width', 'height']
              elsif blk_ctx == :video
                posattrs = ['poster', 'width', 'height']
              else
                posattrs = []
              end

              unless !style || explicit_style
                attributes['alt'] = style if blk_ctx == :image
                attributes.delete('style')
                style = nil
              end

              block.parse_attributes(match[3], posattrs,
                  :unescape_input => (blk_ctx == :image),
                  :sub_input => true,
                  :sub_result => false,
                  :into => attributes)
              target = block.sub_attributes(match[2], :attribute_missing => 'drop-line')
              if target.empty?
                # retain as unparsed if attribute-missing is skip
                if document.attributes.fetch('attribute-missing', Compliance.attribute_missing) == 'skip'
                  return Block.new(parent, :paragraph, :content_model => :simple, :source => [this_line])
                # otherwise, drop the line
                else
                  attributes.clear
                  return
                end
              end

              attributes['target'] = target
              # now done down below
              #block.title = attributes.delete('title') if attributes.has_key?('title')
              #if blk_ctx == :image
              #  if attributes.has_key? 'scaledwidth'
              #    # append % to scaledwidth if ends in number (no units present)
              #    if (48..57).include?((attributes['scaledwidth'][-1] || 0).ord)
              #      attributes['scaledwidth'] = %(#{attributes['scaledwidth']}%)
              #    end
              #  end
              #  document.register(:images, target)
              #  attributes['alt'] ||= ::File.basename(target, ::File.extname(target)).tr('_-', ' ')
              #  # QUESTION should video or audio have an auto-numbered caption?
              #  block.assign_caption attributes.delete('caption'), 'figure'
              #end
              break

            # NOTE we're letting the toc macro have attributes
            elsif first_char == 't' && (match = TocBlockMacroRx.match(this_line))
              block = Block.new(parent, :toc, :content_model => :empty)
              block.parse_attributes(match[1], [], :sub_result => false, :into => attributes)
              break

            elsif block_macro_extensions && (match = GenericBlockMacroRx.match(this_line)) &&
                (extension = extensions.registered_for_block_macro?(match[1]))
              target = match[2]
              raw_attributes = match[3]
              if extension.config[:content_model] == :attributes
                unless raw_attributes.empty?
                  document.parse_attributes(raw_attributes, (extension.config[:pos_attrs] || []),
                      :sub_input => true, :sub_result => false, :into => attributes)
                end
              else
                attributes['text'] = raw_attributes
              end
              if (default_attrs = extension.config[:default_attrs])
                default_attrs.each {|k, v| attributes[k] ||= v }
              end
              if (block = extension.process_method[parent, target, attributes.dup])
                attributes.replace block.attributes
              else
                attributes.clear
                return
              end
              break
            end
          end

          # haven't found anything yet, continue
          if (match = CalloutListRx.match(this_line))
            block = List.new(parent, :colist)
            attributes['style'] = 'arabic'
            reader.unshift_line this_line
            expected_index = 1
            begin
              # might want to move this check to a validate method
              if match[1].to_i != expected_index
                # FIXME this lineno - 2 hack means we need a proper look-behind cursor
                warn %(asciidoctor: WARNING: #{reader.path}: line #{reader.lineno - 2}: callout list item index: expected #{expected_index} got #{match[1]})
              end
              list_item = next_list_item(reader, block, match)
              expected_index += 1
              if list_item
                block << list_item
                coids = document.callouts.callout_ids(block.items.size)
                if !coids.empty?
                  list_item.attributes['coids'] = coids
                else
                  # FIXME this lineno - 2 hack means we need a proper look-behind cursor
                  warn %(asciidoctor: WARNING: #{reader.path}: line #{reader.lineno - 2}: no callouts refer to list item #{block.items.size})
                end
              end
            end while reader.has_more_lines? && (match = CalloutListRx.match(reader.peek_line))

            document.callouts.next_list
            break

          elsif UnorderedListRx =~ this_line
            reader.unshift_line this_line
            block = next_outline_list(reader, :ulist, parent)
            break

          elsif (match = OrderedListRx.match(this_line))
            reader.unshift_line this_line
            block = next_outline_list(reader, :olist, parent)
            # QUESTION move this logic to next_outline_list?
            if !attributes['style'] && !block.attributes['style']
              marker = block.items[0].marker
              if marker.start_with? '.'
                # first one makes more sense, but second one is AsciiDoc-compliant
                #attributes['style'] = (ORDERED_LIST_STYLES[block.level - 1] || ORDERED_LIST_STYLES[0]).to_s
                attributes['style'] = (ORDERED_LIST_STYLES[marker.length - 1] || ORDERED_LIST_STYLES[0]).to_s
              else
                style = ORDERED_LIST_STYLES.detect{|s| OrderedListMarkerRxMap[s] =~ marker }
                attributes['style'] = (style || ORDERED_LIST_STYLES[0]).to_s
              end
            end
            break

          elsif (match = DefinitionListRx.match(this_line))
            reader.unshift_line this_line
            block = next_labeled_list(reader, match, parent)
            break

          elsif (style == 'float' || style == 'discrete') &&
              is_section_title?(this_line, (Compliance.underline_style_section_titles ? reader.peek_line(true) : nil))
            reader.unshift_line this_line
            float_id, float_reftext, float_title, float_level, _ = parse_section_title(reader, document)
            attributes['reftext'] = float_reftext if float_reftext
            float_id ||= attributes['id'] if attributes.has_key?('id')
            block = Block.new(parent, :floating_title, :content_model => :empty)
            if float_id.nil_or_empty?
              # FIXME remove hack of creating throwaway Section to get at the generate_id method
              tmp_sect = Section.new(parent)
              tmp_sect.title = float_title
              block.id = tmp_sect.generate_id
            else
              block.id = float_id
            end
            block.level = float_level
            block.title = float_title
            break

          # FIXME create another set for "passthrough" styles
          # FIXME make this more DRY!
          elsif style && style != 'normal'
            if PARAGRAPH_STYLES.include?(style)
              block_context = style.to_sym
              cloaked_context = :paragraph
              reader.unshift_line this_line
              # advance to block parsing =>
              break
            elsif ADMONITION_STYLES.include?(style)
              block_context = :admonition
              cloaked_context = :paragraph
              reader.unshift_line this_line
              # advance to block parsing =>
              break
            elsif block_extensions && extensions.registered_for_block?(style, :paragraph)
              block_context = style.to_sym
              cloaked_context = :paragraph
              reader.unshift_line this_line
              # advance to block parsing =>
              break
            else
              warn %(asciidoctor: WARNING: #{reader.prev_line_info}: invalid style for paragraph: #{style})
              style = nil
              # continue to process paragraph
            end
          end

          break_at_list = (skipped == 0 && in_list)

          # a literal paragraph is contiguous lines starting at least one space
          if style != 'normal' && LiteralParagraphRx =~ this_line
            # So we need to actually include this one in the read_lines group
            reader.unshift_line this_line
            lines = reader.read_lines_until(
                :break_on_blank_lines => true,
                :break_on_list_continuation => true,
                :preserve_last_line => true) {|line|
              # a preceding blank line (skipped > 0) indicates we are in a list continuation
              # and therefore we should not break at a list item
              # (this won't stop breaking on item of same level since we've already parsed them out)
              # QUESTION can we turn this block into a lambda or function call?
              (break_at_list && AnyListRx =~ line) ||
              (Compliance.block_terminates_paragraph && (is_delimited_block?(line) || BlockAttributeLineRx =~ line))
            }

            reset_block_indent! lines

            block = Block.new(parent, :literal, :content_model => :verbatim, :source => lines, :attributes => attributes)
            # a literal gets special meaning inside of a definition list
            # TODO this feels hacky, better way to distinguish from explicit literal block?
            block.set_option('listparagraph') if in_list

          # a paragraph is contiguous nonblank/noncontinuation lines
          else
            reader.unshift_line this_line
            lines = reader.read_lines_until(
                :break_on_blank_lines => true,
                :break_on_list_continuation => true,
                :preserve_last_line => true,
                :skip_line_comments => true) {|line|
              # a preceding blank line (skipped > 0) indicates we are in a list continuation
              # and therefore we should not break at a list item
              # (this won't stop breaking on item of same level since we've already parsed them out)
              # QUESTION can we turn this block into a lambda or function call?
              (break_at_list && AnyListRx =~ line) ||
              (Compliance.block_terminates_paragraph && (is_delimited_block?(line) || BlockAttributeLineRx =~ line))
            }

            # NOTE we need this logic because we've asked the reader to skip
            # line comments, which may leave us w/ an empty buffer if those
            # were the only lines found
            if lines.empty?
              # call advance since the reader preserved the last line
              reader.advance
              return
            end

            catalog_inline_anchors(lines.join(EOL), document)

            first_line = lines[0]
            if !text_only && (admonition_match = AdmonitionParagraphRx.match(first_line))
              lines[0] = admonition_match.post_match.lstrip
              attributes['style'] = admonition_match[1]
              attributes['name'] = admonition_name = admonition_match[1].downcase
              attributes['caption'] ||= document.attributes[%(#{admonition_name}-caption)]
              block = Block.new(parent, :admonition, :content_model => :simple, :source => lines, :attributes => attributes)
            elsif !text_only && Compliance.markdown_syntax && first_line.start_with?('> ')
              lines.map! {|line|
                if line == '>'
                  line[1..-1]
                elsif line.start_with? '> '
                  line[2..-1]
                else
                  line
                end
              }

              if lines[-1].start_with? '-- '
                attribution, citetitle = lines.pop[3..-1].split(', ', 2)
                lines.pop while lines[-1].empty?
              else
                attribution, citetitle = nil
              end
              attributes['style'] = 'quote'
              attributes['attribution'] = attribution if attribution
              attributes['citetitle'] = citetitle if citetitle
              # NOTE will only detect headings that are floating titles (not section titles)
              # TODO could assume a floating title when inside a block context
              # FIXME Reader needs to be created w/ line info
              block = build_block(:quote, :compound, false, parent, Reader.new(lines), attributes)
            elsif !text_only && lines.size > 1 && first_line.start_with?('"') &&
                lines[-1].start_with?('-- ') && lines[-2].end_with?('"')
              lines[0] = first_line[1..-1]
              attribution, citetitle = lines.pop[3..-1].split(', ', 2)
              lines.pop while lines[-1].empty?
              # strip trailing quote
              lines[-1] = lines[-1].chop
              attributes['style'] = 'quote'
              attributes['attribution'] = attribution if attribution
              attributes['citetitle'] = citetitle if citetitle
              block = Block.new(parent, :quote, :content_model => :simple, :source => lines, :attributes => attributes)
            else
              # if [normal] is used over an indented paragraph, unindent it
              if style == 'normal' && ((first_char = lines[0].chr) == ' ' || first_char == TAB)
                first_line = lines[0]
                first_line_shifted = first_line.lstrip
                indent = line_length(first_line) - line_length(first_line_shifted)
                lines[0] = first_line_shifted
                # QUESTION should we fix the rest of the lines, since in XML output it's insignificant?
                lines.size.times do |i|
                  lines[i] = lines[i][indent..-1] if i > 0
                end
              end

              block = Block.new(parent, :paragraph, :content_model => :simple, :source => lines, :attributes => attributes)
            end
          end

          # forbid loop from executing more than once
          break
        end
      end

      # either delimited block or styled paragraph
      if !block && block_context
        # abstract and partintro should be handled by open block
        # FIXME kind of hackish...need to sort out how to generalize this
        block_context = :open if block_context == :abstract || block_context == :partintro

        case block_context
        when :admonition
          attributes['name'] = admonition_name = style.downcase
          attributes['caption'] ||= document.attributes[%(#{admonition_name}-caption)]
          block = build_block(block_context, :compound, terminator, parent, reader, attributes)

        when :comment
          build_block(block_context, :skip, terminator, parent, reader, attributes)
          return

        when :example
          block = build_block(block_context, :compound, terminator, parent, reader, attributes)

        when :listing, :fenced_code, :source
          if block_context == :fenced_code
            style = attributes['style'] = 'source'
            language, linenums = this_line[3..-1].split(',', 2)
            if language && !(language = language.strip).empty?
              attributes['language'] = language
              attributes['linenums'] = '' if linenums && !linenums.strip.empty?
            elsif (default_language = document.attributes['source-language'])
              attributes['language'] = default_language
            end
            terminator = terminator[0..2]
          elsif block_context == :source
            AttributeList.rekey(attributes, [nil, 'language', 'linenums'])
            unless attributes.has_key? 'language'
              if (default_language = document.attributes['source-language'])
                attributes['language'] = default_language
              end
            end
          end
          block = build_block(:listing, :verbatim, terminator, parent, reader, attributes)

        when :literal
          block = build_block(block_context, :verbatim, terminator, parent, reader, attributes)
        
        when :pass
          block = build_block(block_context, :raw, terminator, parent, reader, attributes)

        when :stem, :latexmath, :asciimath
          if block_context == :stem
            attributes['style'] = (default_stem_syntax = document.attributes['stem']).nil_or_empty? ? 'asciimath' : default_stem_syntax
          end
          block = build_block(:stem, :raw, terminator, parent, reader, attributes)

        when :open, :sidebar
          block = build_block(block_context, :compound, terminator, parent, reader, attributes)

        when :table
          cursor = reader.cursor
          block_reader = Reader.new reader.read_lines_until(:terminator => terminator, :skip_line_comments => true), cursor
          case terminator.chr
            when ','
              attributes['format'] = 'csv'
            when ':'
              attributes['format'] = 'dsv'
          end
          block = next_table(block_reader, parent, attributes)

        when :quote, :verse
          AttributeList.rekey(attributes, [nil, 'attribution', 'citetitle'])
          block = build_block(block_context, (block_context == :verse ? :verbatim : :compound), terminator, parent, reader, attributes)

        else
          if block_extensions && (extension = extensions.registered_for_block?(block_context, cloaked_context))
            # TODO pass cloaked_context to extension somehow (perhaps a new instance for each cloaked_context?)
            if (content_model = extension.config[:content_model]) != :skip
              if !(pos_attrs = extension.config[:pos_attrs] || []).empty?
                AttributeList.rekey(attributes, [nil].concat(pos_attrs))
              end
              if (default_attrs = extension.config[:default_attrs])
                default_attrs.each {|k, v| attributes[k] ||= v }
              end
            end
            block = build_block block_context, content_model, terminator, parent, reader, attributes, :extension => extension
            unless block && content_model != :skip
              attributes.clear
              return
            end
          else
            # this should only happen if there's a misconfiguration
            raise %(Unsupported block type #{block_context} at #{reader.line_info})
          end
        end
      end
    end

    # when looking for nested content, one or more line comments, comment
    # blocks or trailing attribute lists could leave us without a block,
    # so handle accordingly
    # REVIEW we may no longer need this nil check
    # FIXME we've got to clean this up, it's horrible!
    if block
      block.source_location = source_location if source_location
      # REVIEW seems like there is a better way to organize this wrap-up
      block.title     = attributes['title'] unless block.title?
      # FIXME HACK don't hardcode logic for alt, caption and scaledwidth on images down here
      if block.context == :image
        resolved_target = attributes['target']
        block.document.register(:images, resolved_target)
        attributes['alt'] ||= ::File.basename(resolved_target, ::File.extname(resolved_target)).tr('_-', ' ')
        attributes['alt'] = block.sub_specialcharacters attributes['alt']
        block.assign_caption attributes.delete('caption'), 'figure'
        if (scaledwidth = attributes['scaledwidth'])
          # append % to scaledwidth if ends in number (no units present)
          if (48..57).include?((scaledwidth[-1] || 0).ord)
            attributes['scaledwidth'] = %(#{scaledwidth}%)
          end
        end
      else
        block.caption ||= attributes.delete('caption')
      end
      # TODO eventualy remove the style attribute from the attributes hash
      #block.style     = attributes.delete('style')
      block.style     = attributes['style']
      # AsciiDoc always use [id] as the reftext in HTML output,
      # but I'd like to do better in Asciidoctor
      if (block_id = (block.id ||= attributes['id']))
        # TODO sub reftext
        document.register(:ids, [block_id, (attributes['reftext'] || (block.title? ? block.title : nil))])
      end
      # FIXME remove the need for this update!
      block.attributes.update(attributes) unless attributes.empty?
      block.lock_in_subs

      #if document.attributes.has_key? :pending_attribute_entries
      #  document.attributes.delete(:pending_attribute_entries).each do |entry|
      #    entry.save_to block.attributes
      #  end
      #end

      if block.sub? :callouts
        unless (catalog_callouts block.source, document)
          # No need to look for callouts if they aren't there
          block.remove_sub :callouts
        end
      end
    end

    block
  end

  # Public: Determines whether this line is the start of any of the delimited blocks
  #
  # returns the match data if this line is the first line of a delimited block or nil if not
  def self.is_delimited_block? line, return_match_data = false
    # highly optimized for best performance
    return unless (line_len = line.length) > 1 && (DELIMITED_BLOCK_LEADERS.include? line[0..1])
    # catches open block
    if line_len == 2
      tip = line
      tl = 2
    else
      # catches all other delimited blocks, including fenced code
      if line_len <= 4
        tip = line
        tl = line_len
      else
        tip = line[0..3]
        tl = 4
      end

      # special case for fenced code blocks
      # REVIEW review this logic
      fenced_code = false
      if Compliance.markdown_syntax
        tip_3 = (tl == 4 ? tip.chop : tip)
        if tip_3 == '```'
          if tl == 4 && tip.end_with?('`')
            return
          end
          tip = tip_3
          tl = 3
          fenced_code = true
        end
      end

      # short circuit if not a fenced code block
      return if tl == 3 && !fenced_code
    end

    if DELIMITED_BLOCKS.has_key? tip
      # tip is the full line when delimiter is minimum length
      if tl < 4 || tl == line_len
        if return_match_data
          context, masq = *DELIMITED_BLOCKS[tip]
          BlockMatchData.new(context, masq, tip, tip)
        else
          true
        end
      elsif %(#{tip}#{tip[-1..-1] * (line_len - tl)}) == line
        if return_match_data
          context, masq = *DELIMITED_BLOCKS[tip]
          BlockMatchData.new(context, masq, tip, line)
        else
          true
        end
      # only enable if/when we decide to support non-congruent block delimiters
      #elsif (match = BlockDelimiterRx.match(line))
      #  if return_match_data
      #    context, masq = *DELIMITED_BLOCKS[tip]
      #    BlockMatchData.new(context, masq, tip, match[0])
      #  else
      #    true
      #  end
      else
        nil
      end
    else
      nil
    end
  end

  # whether a block supports complex content should be a config setting
  # if terminator is false, that means the all the lines in the reader should be parsed
  # NOTE could invoke filter in here, before and after parsing
  def self.build_block(block_context, content_model, terminator, parent, reader, attributes, options = {})
    if content_model == :skip || content_model == :raw
      skip_processing = content_model == :skip
      parse_as_content_model = :simple
    else
      skip_processing = false
      parse_as_content_model = content_model
    end

    if terminator.nil?
      if parse_as_content_model == :verbatim
        lines = reader.read_lines_until(:break_on_blank_lines => true, :break_on_list_continuation => true)
      else
        content_model = :simple if content_model == :compound
        lines = reader.read_lines_until(
            :break_on_blank_lines => true,
            :break_on_list_continuation => true,
            :preserve_last_line => true,
            :skip_line_comments => true,
            :skip_processing => skip_processing) {|line|
          Compliance.block_terminates_paragraph && (is_delimited_block?(line) || BlockAttributeLineRx =~ line)
        }
        # QUESTION check for empty lines after grabbing lines for simple content model?
      end
      block_reader = nil
    elsif parse_as_content_model != :compound
      lines = reader.read_lines_until(:terminator => terminator, :skip_processing => skip_processing)
      block_reader = nil
    # terminator is false when reader has already been prepared
    elsif terminator == false
      lines = nil
      block_reader = reader
    else
      lines = nil
      cursor = reader.cursor
      block_reader = Reader.new reader.read_lines_until(:terminator => terminator, :skip_processing => skip_processing), cursor
    end

    if content_model == :skip
      attributes.clear
      # FIXME we shouldn't be mixing return types
      return lines
    end

    if content_model == :verbatim && (indent = attributes['indent'])
      reset_block_indent! lines, indent.to_i
    end

    if (extension = options[:extension])
      # QUESTION do we want to delete the style?
      attributes.delete('style')
      if (block = extension.process_method[parent, block_reader || (Reader.new lines), attributes.dup])
        attributes.replace block.attributes
        # FIXME if the content model is set to compound, but we only have simple in this context, then
        # forcefully set the content_model to simple to prevent parsing blocks from children
        # TODO document this behavior!!
        if block.content_model == :compound && !(lines = block.lines).nil_or_empty?
          content_model = :compound
          block_reader = Reader.new lines
        end
      else
        # FIXME need a test to verify this returns nil at the right time
        return
      end
    else
      block = Block.new(parent, block_context, :content_model => content_model, :source => lines, :attributes => attributes)
    end

    # QUESTION should we have an explicit map or can we rely on check for *-caption attribute?
    if (attributes.has_key? 'title') && (block.document.attr? %(#{block.context}-caption))
      block.title = attributes.delete 'title'
      block.assign_caption attributes.delete('caption')
    end

    if content_model == :compound
      # we can look for blocks until there are no more lines (and not worry
      # about sections) since the reader is confined within the boundaries of a
      # delimited block
      parse_blocks block_reader, block
    end
    block
  end

  # Public: Parse blocks from this reader until there are no more lines.
  #
  # This method calls Parser#next_block until there are no more lines in the
  # Reader. It does not consider sections because it's assumed the Reader only
  # has lines which are within a delimited block region.
  #
  # reader - The Reader containing the lines to process
  # parent - The parent Block to which to attach the parsed blocks
  #
  # Returns nothing.
  def self.parse_blocks(reader, parent)
    while reader.has_more_lines?
      block = Parser.next_block(reader, parent)
      parent << block if block
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
    list_block = List.new(parent, list_type)
    if parent.context == list_type
      list_block.level = parent.level + 1
    else
      list_block.level = 1
    end
    #Debug.debug { "Created #{list_type} block: #{list_block}" }

    while reader.has_more_lines? && (match = ListRxMap[list_type].match(reader.peek_line))
      marker = resolve_list_marker(list_type, match[1])

      # if we are moving to the next item, and the marker is different
      # determine if we are moving up or down in nesting
      if list_block.items? && marker != list_block.items[0].marker
        # assume list is nested by default, but then check to see if we are
        # popping out of a nested list by matching an ancestor's list marker
        this_item_level = list_block.level + 1
        ancestor = parent
        while ancestor.context == list_type
          if marker == ancestor.items[0].marker
            this_item_level = ancestor.level
            break
          end
          ancestor = ancestor.parent
        end
      else
        this_item_level = list_block.level
      end

      if !list_block.items? || this_item_level == list_block.level
        list_item = next_list_item(reader, list_block, match)
      elsif this_item_level < list_block.level
        # leave this block
        break
      elsif this_item_level > list_block.level
        # If this next list level is down one from the
        # current Block's, append it to content of the current list item
        list_block.items[-1] << next_block(reader, list_block)
      end

      list_block << list_item if list_item
      list_item = nil

      reader.skip_blank_lines
    end

    list_block
  end

  # Internal: Catalog any callouts found in the text, but don't process them
  #
  # text     - The String of text in which to look for callouts
  # document - The current document on which the callouts are stored
  #
  # Returns A Boolean indicating whether callouts were found
  def self.catalog_callouts(text, document)
    found = false
    if text.include? '<'
      text.scan(CalloutQuickScanRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        if m[0].chr != '\\'
          document.callouts.register(m[2])
        end
        # we have to mark as found even if it's escaped so it can be unescaped
        found = true
      }
    end
    found
  end

  # Internal: Catalog any inline anchors found in the text, but don't process them
  #
  # text     - The String text in which to look for inline anchors
  # document - The current document on which the references are stored
  #
  # Returns nothing
  def self.catalog_inline_anchors(text, document)
    if text.include? '['
      text.scan(InlineAnchorRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        next if m[0].start_with? '\\'
        id = m[1] || m[3]
        reftext = m[2] || m[4]
        # enable if we want to allow double quoted values
        #id = id.sub(DoubleQuotedRx, '\2')
        #if reftext
        #  reftext = reftext.sub(DoubleQuotedMultiRx, '\2')
        #end
        document.register(:ids, [id, reftext])
      }
    end
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
    list_block = List.new(parent, :dlist)
    previous_pair = nil
    # allows us to capture until we find a labeled item
    # that uses the same delimiter (::, :::, :::: or ;;)
    sibling_pattern = DefinitionListSiblingRx[match[2]]

    begin
      term, item = next_list_item(reader, list_block, match, sibling_pattern)
      if previous_pair && !previous_pair[-1]
        previous_pair.pop
        previous_pair[0] << term
        previous_pair << item
      else
        # FIXME this misses the automatic parent assignment
        list_block.items << (previous_pair = [[term], item])
      end
    end while reader.has_more_lines? && (match = sibling_pattern.match(reader.peek_line))

    list_block
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
    if (list_type = list_block.context) == :dlist
      list_term = ListItem.new(list_block, match[1])
      list_item = ListItem.new(list_block, match[3])
      has_text = !match[3].nil_or_empty?
    else
      # Create list item using first line as the text of the list item
      text = match[2]
      checkbox = false
      if list_type == :ulist && text.start_with?('[')
        if text.start_with?('[ ] ')
          checkbox = true
          checked = false
          text = text[3..-1].lstrip
        elsif text.start_with?('[x] ') || text.start_with?('[*] ')
          checkbox = true
          checked = true
          text = text[3..-1].lstrip
        end
      end
      list_item = ListItem.new(list_block, text)

      if checkbox
        # FIXME checklist never makes it into the options attribute
        list_block.attributes['checklist-option'] = ''
        list_item.attributes['checkbox'] = ''
        list_item.attributes['checked'] = '' if checked
      end

      sibling_trait ||= resolve_list_marker(list_type, match[1], list_block.items.size, true, reader)
      list_item.marker = sibling_trait
      has_text = true
    end

    # first skip the line with the marker / term
    reader.advance
    cursor = reader.cursor
    list_item_reader = Reader.new read_lines_for_list_item(reader, list_type, sibling_trait, has_text), cursor
    if list_item_reader.has_more_lines?
      comment_lines = list_item_reader.skip_line_comments
      subsequent_line = list_item_reader.peek_line
      list_item_reader.unshift_lines comment_lines unless comment_lines.empty? 

      if !subsequent_line.nil?
        continuation_connects_first_block = subsequent_line.empty?
        # if there's no continuation connecting the first block, then
        # treat the lines as paragraph text (activated when has_text = false)
        if !continuation_connects_first_block && list_type != :dlist
          has_text = false
        end
        content_adjacent = !continuation_connects_first_block && !subsequent_line.empty?
      else
        continuation_connects_first_block = false
        content_adjacent = false
      end

      # only relevant for :dlist
      options = {:text => !has_text}

      # we can look for blocks until there are no more lines (and not worry
      # about sections) since the reader is confined within the boundaries of a
      # list
      while list_item_reader.has_more_lines?
        new_block = next_block(list_item_reader, list_block, {}, options)
        list_item << new_block if new_block
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
  def self.read_lines_for_list_item(reader, list_type, sibling_trait = nil, has_text = true)
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

    while reader.has_more_lines?
      this_line = reader.read_line

      # if we've arrived at a sibling item in this list, we've captured
      # the complete list item and can begin processing it
      # the remainder of the method determines whether we've reached
      # the termination of the list
      break if is_sibling_list_item?(this_line, list_type, sibling_trait)

      prev_line = buffer.empty? ? nil : buffer[-1]

      if prev_line == LIST_CONTINUATION
        if continuation == :inactive
          continuation = :active
          has_text = true
          buffer[-1] = '' unless within_nested_list
        end

        # dealing with adjacent list continuations (which is really a syntax error)
        if this_line == LIST_CONTINUATION
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
      if (match = is_delimited_block?(this_line, true))
        if continuation == :active
          buffer << this_line
          # grab all the lines in the block, leaving the delimiters in place
          # we're being more strict here about the terminator, but I think that's a good thing
          buffer.concat reader.read_lines_until(:terminator => match.terminator, :read_last_line => true)
          continuation = :inactive
        else
          break
        end
      # technically BlockAttributeLineRx only breaks if ensuing line is not a list item
      # which really means BlockAttributeLineRx only breaks if it's acting as a block delimiter
      # FIXME to be AsciiDoc compliant, we shouldn't break if style in attribute line is "literal" (i.e., [literal])
      elsif list_type == :dlist && continuation != :active && BlockAttributeLineRx =~ this_line
        break
      else
        if continuation == :active && !this_line.empty?
          # literal paragraphs have special considerations (and this is one of 
          # two entry points into one)
          # if we don't process it as a whole, then a line in it that looks like a
          # list item will throw off the exit from it
          if LiteralParagraphRx =~ this_line
            reader.unshift_line this_line
            buffer.concat reader.read_lines_until(
                :preserve_last_line => true,
                :break_on_blank_lines => true,
                :break_on_list_continuation => true) {|line|
              # we may be in an indented list disguised as a literal paragraph
              # so we need to make sure we don't slurp up a legitimate sibling
              list_type == :dlist && is_sibling_list_item?(line, list_type, sibling_trait)
            }
            continuation = :inactive
          # let block metadata play out until we find the block
          elsif BlockTitleRx =~ this_line || BlockAttributeLineRx =~ this_line || AttributeEntryRx =~ this_line
            buffer << this_line
          else
            if nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).detect {|ctx| ListRxMap[ctx] =~ this_line }
              within_nested_list = true
              if nested_list_type == :dlist && $~[3].nil_or_empty?
                # get greedy again
                has_text = false
              end
            end
            buffer << this_line
            continuation = :inactive
          end
        elsif !prev_line.nil? && prev_line.empty?
          # advance to the next line of content
          if this_line.empty?
            reader.skip_blank_lines
            this_line = reader.read_line 
            # if we hit eof or a sibling, stop reading
            break if this_line.nil? || is_sibling_list_item?(this_line, list_type, sibling_trait)
          end

          if this_line == LIST_CONTINUATION
            detached_continuation = buffer.size
            buffer << this_line
          else
            # has_text is only relevant for dlist, which is more greedy until it has text for an item
            # for all other lists, has_text is always true
            # in this block, we have to see whether we stay in the list
            if has_text
              # TODO any way to combine this with the check after skipping blank lines?
              if is_sibling_list_item?(this_line, list_type, sibling_trait)
                break
              elsif nested_list_type = NESTABLE_LIST_CONTEXTS.detect {|ctx| ListRxMap[ctx] =~ this_line }
                buffer << this_line
                within_nested_list = true
                if nested_list_type == :dlist && $~[3].nil_or_empty?
                  # get greedy again
                  has_text = false
                end
              # slurp up any literal paragraph offset by blank lines
              # NOTE we have to check for indented list items first
              elsif LiteralParagraphRx =~ this_line
                reader.unshift_line this_line
                buffer.concat reader.read_lines_until(
                    :preserve_last_line => true,
                    :break_on_blank_lines => true,
                    :break_on_list_continuation => true) {|line|
                  # we may be in an indented list disguised as a literal paragraph
                  # so we need to make sure we don't slurp up a legitimate sibling
                  list_type == :dlist && is_sibling_list_item?(line, list_type, sibling_trait)
                }
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
          has_text = true if !this_line.empty?
          if nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).detect {|ctx| ListRxMap[ctx] =~ this_line }
            within_nested_list = true
            if nested_list_type == :dlist && $~[3].nil_or_empty?
              # get greedy again
              has_text = false
            end
          end
          buffer << this_line
        end
      end
      this_line = nil
    end

    reader.unshift_line this_line if this_line

    if detached_continuation
      buffer.delete_at detached_continuation
    end

    # strip trailing blank lines to prevent empty blocks
    buffer.pop while !buffer.empty? && buffer[-1].empty?

    # We do need to replace the optional trailing continuation
    # a blank line would have served the same purpose in the document
    buffer.pop if !buffer.empty? && buffer[-1] == LIST_CONTINUATION

    #warn "BUFFER[#{list_type},#{sibling_trait}]>#{buffer * EOL}<BUFFER"
    #warn "BUFFER[#{list_type},#{sibling_trait}]>#{buffer.inspect}<BUFFER"

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
    document = parent.document
    source_location = reader.cursor if document.sourcemap
    sect_id, sect_reftext, sect_title, sect_level, _ = parse_section_title(reader, document)
    attributes['reftext'] = sect_reftext if sect_reftext
    section = Section.new parent, sect_level, document.attributes.has_key?('sectnums')
    section.source_location = source_location if source_location
    section.id = sect_id
    section.title = sect_title
    # parse style, id and role from first positional attribute
    if attributes[1]
      style, _ = parse_style_attribute attributes, reader
      # handle case where only id and/or role are given (e.g., #idname.rolename)
      if style
        section.sectname = style
        section.special = true
        # HACK needs to be refactored so it's driven by config
        if section.sectname == 'abstract' && document.doctype == 'book'
          section.sectname = 'sect1'
          section.special = false
          section.level = 1
        end
      else
        section.sectname = %(sect#{section.level})
      end
    elsif sect_title.downcase == 'synopsis' && document.doctype == 'manpage'
      section.special = true
      section.sectname = 'synopsis'
    else
      section.sectname = %(sect#{section.level})
    end

    if !section.id && (id = attributes['id'])
      section.id = id
    else
      # generate an id if one was not *embedded* in the heading line
      # or as an anchor above the section
      section.id ||= section.generate_id
    end

    if section.id
      # TODO sub reftext
      section.document.register(:ids, [section.id, (attributes['reftext'] || section.title)])
    end
    section.update_attributes(attributes)
    reader.skip_blank_lines

    section
  end

  # Private: Get the Integer section level based on the characters
  # used in the ASCII line under the section title.
  #
  # line - the String line from under the section title.
  def self.section_level(line)
    SECTION_LEVELS[line.chr]
  end

  #--
  # = is level 0, == is level 1, etc.
  def self.single_line_section_level(marker)
    marker.length - 1
  end

  # Internal: Checks if the next line on the Reader is a section title
  #
  # reader     - the source Reader
  # attributes - a Hash of attributes collected above the current line
  #
  # returns the section level if the Reader is positioned at a section title,
  # false otherwise
  def self.is_next_line_section?(reader, attributes)
    if !(val = attributes[1]).nil? && ((ord_0 = val[0].ord) == 100 || ord_0 == 102) && val =~ FloatingTitleStyleRx
      return false
    end
    return false unless reader.has_more_lines?
    Compliance.underline_style_section_titles ? is_section_title?(*reader.peek_lines(2)) : is_section_title?(reader.peek_line)
  end

  # Internal: Convenience API for checking if the next line on the Reader is the document title
  #
  # reader     - the source Reader
  # attributes - a Hash of attributes collected above the current line
  #
  # returns true if the Reader is positioned at the document title, false otherwise
  def self.is_next_line_document_title?(reader, attributes)
    is_next_line_section?(reader, attributes) == 0
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
    elsif line2 && (level = is_two_line_section_title?(line1, line2))
      level
    else
      false
    end
  end

  def self.is_single_line_section_title?(line1)
    first_char = line1 ? line1.chr : nil
    if (first_char == '=' || (Compliance.markdown_syntax && first_char == '#')) &&
        (match = AtxSectionRx.match(line1))
      single_line_section_level match[1]
    else
      false
    end
  end

  def self.is_two_line_section_title?(line1, line2)
    if line1 && line2 && SECTION_LEVELS.has_key?(line2.chr) &&
        line2 =~ SetextSectionLineRx && line1 =~ SetextSectionTitleRx &&
        # chomp so that a (non-visible) endline does not impact calculation
        (line_length(line1) - line_length(line2)).abs <= 1
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
  # document- the current document
  #
  # Examples
  #
  #   reader.lines
  #   # => ["Foo", "~~~"]
  #
  #   id, reftext, title, level, single = parse_section_title(reader, document)
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
  #   # => "==== Foo"
  #
  #   id, reftext, title, level, single = parse_section_title(reader, document)
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
  # returns an Array of [String, String, Integer, String, Boolean], representing the
  # id, reftext, title, level and line count of the Section, or nil.
  #
  #--
  # NOTE for efficiency, we don't reuse methods that check for a section title
  def self.parse_section_title(reader, document)
    line1 = reader.read_line
    sect_id = nil
    sect_title = nil
    sect_level = -1
    sect_reftext = nil
    single_line = true

    first_char = line1.chr
    if (first_char == '=' || (Compliance.markdown_syntax && first_char == '#')) &&
        (match = AtxSectionRx.match(line1))
      sect_level = single_line_section_level match[1]
      sect_title = match[2]
      if sect_title.end_with?(']]') && (anchor_match = InlineSectionAnchorRx.match(sect_title))
        if anchor_match[2].nil?
          sect_title = anchor_match[1]
          sect_id = anchor_match[3]
          sect_reftext = anchor_match[4]
        end
      end
    elsif Compliance.underline_style_section_titles
      if (line2 = reader.peek_line(true)) && SECTION_LEVELS.has_key?(line2.chr) && line2 =~ SetextSectionLineRx &&
        (name_match = SetextSectionTitleRx.match(line1)) &&
        # chomp so that a (non-visible) endline does not impact calculation
        (line_length(line1) - line_length(line2)).abs <= 1
        sect_title = name_match[1]
        if sect_title.end_with?(']]') && (anchor_match = InlineSectionAnchorRx.match(sect_title))
          if anchor_match[2].nil?
            sect_title = anchor_match[1]
            sect_id = anchor_match[3]
            sect_reftext = anchor_match[4]
          end
        end
        sect_level = section_level line2
        single_line = false
        reader.advance
      end
    end
    if sect_level >= 0
      sect_level += document.attr('leveloffset', 0).to_i
    end
    [sect_id, sect_reftext, sect_title, sect_level, single_line]
  end

  # Public: Calculate the number of unicode characters in the line, excluding the endline
  #
  # line - the String to calculate
  #
  # returns the number of unicode characters in the line
  def self.line_length(line)
    FORCE_UNICODE_LINE_LENGTH ? line.scan(UnicodeCharScanRx).length : line.length
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
  #  data = ["Author Name <author@example.org>\n", "v1.0, 2012-12-21: Coincide w/ end of world.\n"]
  #  parse_header_metadata(Reader.new data, nil, :normalize => true)
  #  # => {'author' => 'Author Name', 'firstname' => 'Author', 'lastname' => 'Name', 'email' => 'author@example.org',
  #  #       'revnumber' => '1.0', 'revdate' => '2012-12-21', 'revremark' => 'Coincide w/ end of world.'}
  def self.parse_header_metadata(reader, document = nil)
    # NOTE this will discard away any comment lines, but not skip blank lines
    process_attribute_entries(reader, document)

    metadata = {}
    implicit_author = nil
    implicit_authors = nil

    if reader.has_more_lines? && !reader.next_line_empty?
      author_metadata = process_authors reader.read_line

      unless author_metadata.empty?
        if document
          # apply header subs and assign to document
          author_metadata.each do |key, val|
            unless document.attributes.has_key? key
              document.attributes[key] = ((val.is_a? ::String) ? document.apply_header_subs(val) : val)
            end
          end

          implicit_author = document.attributes['author']
          implicit_authors = document.attributes['authors']
        end

        metadata = author_metadata
      end

      # NOTE this will discard any comment lines, but not skip blank lines
      process_attribute_entries(reader, document)

      rev_metadata = {}

      if reader.has_more_lines? && !reader.next_line_empty?
        rev_line = reader.read_line 
        if (match = RevisionInfoLineRx.match(rev_line))
          rev_metadata['revdate'] = match[2].strip
          rev_metadata['revnumber'] = match[1].rstrip unless match[1].nil?
          rev_metadata['revremark'] = match[3].rstrip unless match[3].nil?
        else
          # throw it back
          reader.unshift_line rev_line
        end
      end

      unless rev_metadata.empty?
        if document
          # apply header subs and assign to document
          rev_metadata.each do |key, val|
            unless document.attributes.has_key? key
              document.attributes[key] = document.apply_header_subs(val)
            end
          end
        end

        metadata.update rev_metadata
      end

      # NOTE this will discard any comment lines, but not skip blank lines
      process_attribute_entries(reader, document)

      reader.skip_blank_lines
    end

    if document
      # process author attribute entries that override (or stand in for) the implicit author line
      author_metadata = nil
      if document.attributes.has_key?('author') &&
          (author_line = document.attributes['author']) != implicit_author
        # do not allow multiple, process as names only
        author_metadata = process_authors author_line, true, false
      elsif document.attributes.has_key?('authors') &&
          (author_line = document.attributes['authors']) != implicit_authors
        # allow multiple, process as names only
        author_metadata = process_authors author_line, true
      else
        authors = []
        author_key = %(author_#{authors.size + 1})
        while document.attributes.has_key? author_key
          authors << document.attributes[author_key]
          author_key = %(author_#{authors.size + 1})
        end
        if authors.size == 1
          # do not allow multiple, process as names only
          author_metadata = process_authors authors[0], true, false
        elsif authors.size > 1
          # allow multiple, process as names only
          author_metadata = process_authors authors.join('; '), true
        end
      end

      if author_metadata
        document.attributes.update author_metadata

        # special case
        if !document.attributes.has_key?('email') && document.attributes.has_key?('email_1')
          document.attributes['email'] = document.attributes['email_1']
        end
      end
    end

    metadata
  end

  # Internal: Parse the author line into a Hash of author metadata
  #
  # author_line  - the String author line
  # names_only   - a Boolean flag that indicates whether to process line as
  #                names only or names with emails (default: false)
  # multiple     - a Boolean flag that indicates whether to process multiple
  #                semicolon-separated entries in the author line (default: true)
  #
  # returns a Hash of author metadata
  def self.process_authors(author_line, names_only = false, multiple = true)
    author_metadata = {}
    keys = ['author', 'authorinitials', 'firstname', 'middlename', 'lastname', 'email']
    author_entries = multiple ? (author_line.split ';').map {|line| line.strip } : [author_line]
    author_entries.each_with_index do |author_entry, idx|
      next if author_entry.empty?
      key_map = {}
      if idx.zero?
        keys.each do |key|
          key_map[key.to_sym] = key
        end
      else
        keys.each do |key|
          key_map[key.to_sym] = %(#{key}_#{idx + 1})
        end
      end

      segments = nil
      if names_only
        # splitting on ' ' will collapse repeating spaces
        segments = author_entry.split(' ', 3)
      elsif (match = AuthorInfoLineRx.match(author_entry))
        segments = match.to_a
        segments.shift
      end

      unless segments.nil?
        author_metadata[key_map[:firstname]] = fname = segments[0].tr('_', ' ')
        author_metadata[key_map[:author]] = fname
        author_metadata[key_map[:authorinitials]] = fname[0, 1]
        if !segments[1].nil? && !segments[2].nil?
          author_metadata[key_map[:middlename]] = mname = segments[1].tr('_', ' ')
          author_metadata[key_map[:lastname]] = lname = segments[2].tr('_', ' ')
          author_metadata[key_map[:author]] = [fname, mname, lname].join ' '
          author_metadata[key_map[:authorinitials]] = [fname[0, 1], mname[0, 1], lname[0, 1]].join
        elsif !segments[1].nil?
          author_metadata[key_map[:lastname]] = lname = segments[1].tr('_', ' ')
          author_metadata[key_map[:author]] = [fname, lname].join ' '
          author_metadata[key_map[:authorinitials]] = [fname[0, 1], lname[0, 1]].join
        end
        author_metadata[key_map[:email]] = segments[3] unless names_only || segments[3].nil?
      else
        author_metadata[key_map[:author]] = author_metadata[key_map[:firstname]] = fname = author_entry.strip.tr_s(' ', ' ')
        author_metadata[key_map[:authorinitials]] = fname[0, 1]
      end

      author_metadata['authorcount'] = idx + 1
      # only assign the _1 attributes if there are multiple authors
      if idx == 1
        keys.each do |key|
          author_metadata[%(#{key}_1)] = author_metadata[key] if author_metadata.has_key? key
        end
      end
      if idx.zero?
        author_metadata['authors'] = author_metadata[key_map[:author]]
      else
        author_metadata['authors'] = %(#{author_metadata['authors']}, #{author_metadata[key_map[:author]]})
      end
    end

    author_metadata
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
      reader.advance
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
    return false unless reader.has_more_lines?
    next_line = reader.peek_line
    if (commentish = next_line.start_with?('//')) && (match = CommentBlockRx.match(next_line))
      terminator = match[0]
      reader.read_lines_until(:skip_first_line => true, :preserve_last_line => true, :terminator => terminator, :skip_processing => true)
    elsif commentish && CommentLineRx =~ next_line
      # do nothing, we'll skip it
    elsif !options[:text] && next_line.start_with?(':') && (match = AttributeEntryRx.match(next_line))
      process_attribute_entry(reader, parent, attributes, match)
    elsif (in_square_brackets = next_line.start_with?('[') && next_line.end_with?(']')) && (match = BlockAnchorRx.match(next_line))
      unless match[1].nil_or_empty?
        attributes['id'] = match[1]
        # AsciiDoc always uses [id] as the reftext in HTML output,
        # but I'd like to do better in Asciidoctor
        # registration is deferred until the block or section is processed
        attributes['reftext'] = match[2] unless match[2].nil?
      end
    elsif in_square_brackets && (match = BlockAttributeListRx.match(next_line))
      parent.document.parse_attributes(match[1], [], :sub_input => true, :into => attributes)
    # NOTE title doesn't apply to section, but we need to stash it for the first block
    # TODO should issue an error if this is found above the document title
    elsif !options[:text] && (match = BlockTitleRx.match(next_line))
      attributes['title'] = match[1]
    else
      return false
    end

    true
  end

  def self.process_attribute_entries(reader, parent, attributes = nil)
    reader.skip_comment_lines
    while process_attribute_entry(reader, parent, attributes)
      # discard line just processed
      reader.advance
      reader.skip_comment_lines
    end
  end

  def self.process_attribute_entry(reader, parent, attributes = nil, match = nil)
    match ||= (reader.has_more_lines? ? AttributeEntryRx.match(reader.peek_line) : nil)
    if match
      name = match[1]
      unless (value = match[2] || '').empty?
        if value.end_with?(line_continuation = LINE_CONTINUATION) ||
            value.end_with?(line_continuation = LINE_CONTINUATION_LEGACY)
          value = value.chop.rstrip
          while reader.advance
            break if (next_line = reader.peek_line.strip).empty?
            if (keep_open = next_line.end_with? line_continuation)
              next_line = next_line.chop.rstrip
            end
            separator = (value.end_with? LINE_BREAK) ? EOL : ' '
            value = %(#{value}#{separator}#{next_line})
            break unless keep_open
          end
        end
      end

      store_attribute(name, value, (parent ? parent.document : nil), attributes)
      true
    else
      false
    end
  end

  # Public: Store the attribute in the document and register attribute entry if accessible
  #
  # name  - the String name of the attribute to store
  # value - the String value of the attribute to store
  # doc   - the Document being parsed
  # attrs - the attributes for the current context
  #
  # returns a 2-element array containing the attribute name and value
  def self.store_attribute(name, value, doc = nil, attrs = nil)
    # TODO move processing of attribute value to utility method
    if name.end_with?('!')
      # a nil value signals the attribute should be deleted (undefined)
      value = nil
      name = name.chop
    elsif name.start_with?('!')
      # a nil value signals the attribute should be deleted (undefined)
      value = nil
      name = name[1..-1]
    end

    name = sanitize_attribute_name(name)
    accessible = true
    if doc
      # alias numbered attribute to sectnums
      if name == 'numbered'
        name = 'sectnums'
      # support relative leveloffset values
      elsif name == 'leveloffset'
        if value
          case value.chr
          when '+'
            value = ((doc.attr 'leveloffset', 0).to_i + (value[1..-1] || 0).to_i).to_s
          when '-'
            value = ((doc.attr 'leveloffset', 0).to_i - (value[1..-1] || 0).to_i).to_s
          end
        end
      end
      accessible = value ? doc.set_attribute(name, value) : doc.delete_attribute(name)
    end

    if accessible && attrs
      Document::AttributeEntry.new(name, value).save_to(attrs)
    end

    [name, value]
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
  def self.resolve_list_marker(list_type, marker, ordinal = 0, validate = false, reader = nil)
    if list_type == :olist && !marker.start_with?('.')
      resolve_ordered_list_marker(marker, ordinal, validate, reader)
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
  #  Parser.resolve_ordered_list_marker(marker, 1, true)
  #  # => 'A.'
  #
  # Returns the String of the first marker in this number series 
  def self.resolve_ordered_list_marker(marker, ordinal = 0, validate = false, reader = nil)
    number_style = ORDERED_LIST_STYLES.detect {|s| OrderedListMarkerRxMap[s] =~ marker }
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
      warn %(asciidoctor: WARNING: #{reader.line_info}: list item index: expected #{expected}, got #{actual})
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
    if sibling_trait.is_a? ::Regexp
      matcher = sibling_trait
      expected_marker = false
    else
      matcher = ListRxMap[list_type]
      expected_marker = sibling_trait
    end

    if (m = matcher.match(line))
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
    if (attributes.has_key? 'title')
      table.title = attributes.delete 'title'
      table.assign_caption attributes.delete('caption')
    end

    if attributes.has_key? 'cols'
      table.create_columns(parse_col_specs(attributes['cols']))
      explicit_col_specs = true
    else
      explicit_col_specs = false
    end

    skipped = table_reader.skip_blank_lines

    parser_ctx = Table::ParserContext.new(table_reader, table, attributes)
    loop_idx = -1
    while table_reader.has_more_lines?
      loop_idx += 1
      line = table_reader.read_line

      if skipped == 0 && loop_idx.zero? && !attributes.has_key?('options') &&
          !(next_line = table_reader.peek_line).nil? && next_line.empty?
        table.has_header_option = true
        table.set_option 'header'
      end

      if parser_ctx.format == 'psv'
        if parser_ctx.starts_with_delimiter? line
          line = line[1..-1]
          # push an empty cell spec if boundary at start of line
          parser_ctx.close_open_cell
        else
          next_cell_spec, line = parse_cell_spec(line, :start, parser_ctx.delimiter)
          # if the cell spec is not null, then we're at a cell boundary
          if !next_cell_spec.nil?
            parser_ctx.close_open_cell next_cell_spec
          else
            # QUESTION do we not advance to next line? if so, when will we if we came into this block?
          end
        end
      end

      seen = false
      while !seen || !line.empty?
        seen = true
        if (m = parser_ctx.match_delimiter(line))
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
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{cell_text})
          else
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{m.pre_match})
          end

          line = m.post_match
          parser_ctx.close_cell
        else
          # no other delimiters to see here
          # suck up this line into the buffer and move on
          parser_ctx.buffer = %(#{parser_ctx.buffer}#{line}#{EOL})
          # QUESTION make stripping endlines in csv data an option? (unwrap-option?)
          if parser_ctx.format == 'csv'
            parser_ctx.buffer = %(#{parser_ctx.buffer.rstrip} )
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

      skipped = table_reader.skip_blank_lines unless parser_ctx.cell_open?

      if !table_reader.has_more_lines?
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
    # check for deprecated syntax: single number, equal column spread
    # REVIEW could use records == records.to_i.to_s instead of regexp
    if DigitsRx =~ records
      return ::Array.new(records.to_i) { { 'width' => 1 } }
    end

    specs = []
    records.split(',').each {|record|
      # TODO might want to use scan rather than this mega-regexp
      if (m = ColumnSpecRx.match(record))
        spec = {}
        if m[2]
          # make this an operation
          colspec, rowspec = m[2].split '.'
          if !colspec.nil_or_empty? && Table::ALIGNMENTS[:h].has_key?(colspec)
            spec['halign'] = Table::ALIGNMENTS[:h][colspec]
          end
          if !rowspec.nil_or_empty? && Table::ALIGNMENTS[:v].has_key?(rowspec)
            spec['valign'] = Table::ALIGNMENTS[:v][rowspec]
          end
        end

        # to_i permits us to support percentage width by stripping the %
        # NOTE this is slightly out of compliance w/ AsciiDoc, but makes way more sense
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
  # The default spec when pos == :end is {} since we already know we're at a
  # delimiter. When pos == :start, we *may* be at a delimiter, nil indicates
  # we're not.
  # 
  # returns the Hash of attributes that indicate how to layout
  # and style this cell in the table.
  def self.parse_cell_spec(line, pos = :start, delimiter = nil)
    m = nil
    rest = ''

    case pos
    when :start
      if line.include? delimiter
        spec_part, rest = line.split delimiter, 2
        if (m = CellSpecStartRx.match spec_part)
          return [{}, rest] if m[0].empty?
        else
          return [nil, line]
        end
      else
        return [nil, line]
      end
    when :end
      if (m = CellSpecEndRx.match line)
        # NOTE return the line stripped of trailing whitespace if no cellspec is found in this case
        return [{}, line.rstrip] if m[0].lstrip.empty?
        rest = m.pre_match
      else
        return [{}, line]
      end
    end

    spec = {}
    if m[1]
      colspec, rowspec = m[1].split '.'
      colspec = colspec.nil_or_empty? ? 1 : colspec.to_i
      rowspec = rowspec.nil_or_empty? ? 1 : rowspec.to_i
      if m[2] == '+'
        spec['colspan'] = colspec unless colspec == 1
        spec['rowspan'] = rowspec unless rowspec == 1
      elsif m[2] == '*'
        spec['repeatcol'] = colspec unless colspec == 1
      end
    end
    
    if m[3]
      colspec, rowspec = m[3].split '.'
      if !colspec.nil_or_empty? && Table::ALIGNMENTS[:h].has_key?(colspec)
        spec['halign'] = Table::ALIGNMENTS[:h][colspec]
      end
      if !rowspec.nil_or_empty? && Table::ALIGNMENTS[:v].has_key?(rowspec)
        spec['valign'] = Table::ALIGNMENTS[:v][rowspec]
      end
    end

    if m[4] && Table::TEXT_STYLES.has_key?(m[4])
      spec['style'] = Table::TEXT_STYLES[m[4]]
    end

    [spec, rest]
  end

  # Public: Parse the first positional attribute and assign named attributes
  #
  # Parse the first positional attribute to extract the style, role and id
  # parts, assign the values to their cooresponding attribute keys and return
  # both the original style attribute and the parsed value from the first
  # positional attribute.
  #
  # attributes - The Hash of attributes to process and update
  #
  # Examples
  #
  #   puts attributes
  #   => {1 => "abstract#intro.lead%fragment", "style" => "preamble"}
  #
  #   parse_style_attribute(attributes)
  #   => ["abstract", "preamble"]
  #
  #   puts attributes
  #   => {1 => "abstract#intro.lead", "style" => "abstract", "id" => "intro",
  #         "role" => "lead", "options" => ["fragment"], "fragment-option" => ''}
  #
  # Returns a two-element Array of the parsed style from the
  # first positional attribute and the original style that was
  # replaced
  def self.parse_style_attribute(attributes, reader = nil)
    original_style = attributes['style']
    raw_style = attributes[1]
    # NOTE spaces are not allowed in shorthand, so if we find one, this ain't shorthand
    if raw_style && !raw_style.include?(' ') && Compliance.shorthand_property_syntax
      type = :style
      collector = []
      parsed = {}
      # QUESTION should this be a private method? (though, it's never called if shorthand isn't used)
      save_current = lambda {
        if collector.empty?
          if type != :style
            warn %(asciidoctor: WARNING:#{reader.nil? ? nil : " #{reader.prev_line_info}:"} invalid empty #{type} detected in style attribute)
          end
        else
          case type
          when :role, :option
            parsed[type] ||= []
            parsed[type].push collector.join
          when :id
            if parsed.has_key? :id
              warn %(asciidoctor: WARNING:#{reader.nil? ? nil : " #{reader.prev_line_info}:"} multiple ids detected in style attribute)
            end
            parsed[type] = collector.join
          else
            parsed[type] = collector.join
          end
          collector = []
        end
      }

      raw_style.each_char do |c|
        if c == '.' || c == '#' || c == '%'
          save_current.call
          case c
          when '.'
            type = :role
          when '#'
            type = :id
          when '%'
            type = :option
          end
        else
          collector.push c
        end
      end
      
      # small optimization if no shorthand is found
      if type == :style
        parsed_style = attributes['style'] = raw_style
      else
        save_current.call

        if parsed.has_key? :style
          parsed_style = attributes['style'] = parsed[:style]
        else
          parsed_style = nil
        end

        if parsed.has_key? :id
          attributes['id'] = parsed[:id]
        end

        if parsed.has_key? :role
          attributes['role'] = parsed[:role] * ' '
        end

        if parsed.has_key? :option
          (options = parsed[:option]).each do |option|
            attributes[%(#{option}-option)] = ''
          end
          if (existing_opts = attributes['options'])
            attributes['options'] = (options + existing_opts.split(',')) * ',' 
          else
            attributes['options'] = options * ','
          end
        end
      end

      [parsed_style, original_style]
    else
      attributes['style'] = raw_style
      [raw_style, original_style]
    end
  end

  # Remove the indentation (block offset) shared by all the lines, then
  # indent the lines by the specified amount if specified
  #
  # Trim the leading whitespace (indentation) equivalent to the length
  # of the indent on the least indented line. If the indent argument
  # is specified, indent the lines by this many spaces (columns).
  # 
  # The purpose of this method is to shift a block of text to
  # align to the left margin, while still preserving the relative
  # indentation between lines
  #
  # lines  - the Array of String lines to process
  # indent - the integer number of spaces to add to the beginning
  #          of each line; if this value is nil, the existing
  #          space is preserved (optional, default: 0)
  #
  # Examples
  #
  #   source = <<EOS
  #       def names
  #         @name.split ' ')
  #       end
  #   EOS
  #
  #   source.split("\n")
  #   # => ["    def names", "      @names.split ' '", "    end"]
  #
  #   Parser.reset_block_indent(source.split "\n")
  #   # => ["def names", "  @names.split ' '", "end"]
  #
  #   puts Parser.reset_block_indent(source.split "\n") * "\n"
  #   # => def names
  #   # =>   @names.split ' '
  #   # => end
  #
  # returns the Array of String lines with block offset removed
  #--
  # FIXME refactor gsub matchers into compiled regex
  def self.reset_block_indent!(lines, indent = 0)
    return if !indent || lines.empty?

    tab_detected = false
    # TODO make tab size configurable
    tab_expansion = '    '
    # strip leading block indent
    offsets = lines.map do |line|
      # break if the first char is non-whitespace
      break [] unless line.chr.lstrip.empty?
      if line.include? TAB
        tab_detected = true
        line = line.gsub(TAB_PATTERN, tab_expansion)
      end
      if (flush_line = line.lstrip).empty?
        nil
      elsif (offset = line.length - flush_line.length) == 0
        break []
      else
        offset
      end
    end
    
    unless offsets.empty? || (offsets = offsets.compact).empty?
      if (offset = offsets.min) > 0
        lines.map! {|line|
          line = line.gsub(TAB_PATTERN, tab_expansion) if tab_detected
          line[offset..-1].to_s
        }
      end
    end

    if indent > 0
      padding = ' ' * indent
      lines.map! {|line| %(#{padding}#{line}) }
    end

    nil
  end

  # Public: Convert a string to a legal attribute name.
  #
  # name  - the String name of the attribute
  #
  # Returns a String with the legal AsciiDoc attribute name.
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
  def self.sanitize_attribute_name(name)
    name.gsub(InvalidAttributeNameCharsRx, '').downcase
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
end
