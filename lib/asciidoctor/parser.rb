# encoding: UTF-8
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

  # Regexp for replacing tab character
  TabRx = /\t/

  # Regexp for leading tab indentation
  TabIndentRx = /^\t+/

  StartOfBlockProc = lambda {|l| ((l.start_with? '[') && (BlockAttributeLineRx.match? l)) || (is_delimited_block? l) }

  StartOfListProc = lambda {|l| AnyListRx.match? l }

  StartOfBlockOrListProc = lambda {|l| (is_delimited_block? l) || ((l.start_with? '[') && (BlockAttributeLineRx.match? l)) || (AnyListRx.match? l) }

  NoOp = nil

  # Internal: A Hash mapping horizontal alignment abbreviations to alignments
  # that can be applied to a table cell (or to all cells in a column)
  TableCellHorzAlignments = {
    '<' => 'left',
    '>' => 'right',
    '^' => 'center'
  }

  # Internal: A Hash mapping vertical alignment abbreviations to alignments
  # that can be applied to a table cell (or to all cells in a column)
  TableCellVertAlignments = {
    '<' => 'top',
    '>' => 'bottom',
    '^' => 'middle'
  }

  # Internal: A Hash mapping styles abbreviations to styles that can be applied
  # to a table cell (or to all cells in a column)
  TableCellStyles = {
    'd' => :none,
    's' => :strong,
    'e' => :emphasis,
    'm' => :monospaced,
    'h' => :header,
    'l' => :literal,
    'v' => :verse,
    'a' => :asciidoc
  }

  # Public: Make sure the Parser object doesn't get initialized.
  #
  # Raises RuntimeError if this constructor is invoked.
  def initialize
    raise 'Au contraire, mon frere. No parser instances will be running around.'
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

    while reader.has_more_lines?
      new_section, block_attributes = next_section(reader, document, block_attributes)
      document << new_section if new_section
    end unless options[:header_only]

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
    # capture lines of block-level metadata and plow away comment lines that precede first block
    block_attributes = parse_block_metadata_lines reader, document

    # special case, block title is not allowed above document title,
    # carry attributes over to the document body
    if (implicit_doctitle = is_next_line_doctitle? reader, block_attributes, document.attributes['leveloffset']) &&
        (block_attributes.key? 'title')
      return document.finalize_header block_attributes, false
    end

    # yep, document title logic in AsciiDoc is just insanity
    # definitely an area for spec refinement
    assigned_doctitle = nil
    unless (val = document.attributes['doctitle']).nil_or_empty?
      document.title = assigned_doctitle = val
    end

    section_title = nil
    # if the first line is the document title, add a header to the document and parse the header metadata
    if implicit_doctitle
      source_location = reader.cursor if document.sourcemap
      document.id, _, doctitle, _, single_line = parse_section_title reader, document
      unless assigned_doctitle
        document.title = assigned_doctitle = doctitle
      end
      # default to compat-mode if document uses atx-style doctitle
      document.set_attr 'compat-mode' unless single_line || (document.attribute_locked? 'compat-mode')
      if (separator = block_attributes.delete 'separator')
        document.set_attr 'title-separator', separator unless document.attribute_locked? 'title-separator'
      end
      document.header.source_location = source_location if source_location
      document.attributes['doctitle'] = section_title = doctitle
      # QUESTION: should the id assignment on Document be encapsulated in the Document class?
      if document.id
        block_attributes.delete 1
        block_attributes.delete 'id'
      else
        if (style = block_attributes.delete 1)
          style_attrs = { 1 => style }
          parse_style_attribute style_attrs, reader
          block_attributes['id'] = style_attrs['id'] if style_attrs.key? 'id'
        end
        document.id = block_attributes.delete 'id'
      end
      parse_header_metadata reader, document
    end

    unless (val = document.attributes['doctitle']).nil_or_empty? || val == section_title
      document.title = assigned_doctitle = val
    end

    # restore doctitle attribute to original assignment
    document.attributes['doctitle'] = assigned_doctitle if assigned_doctitle

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
    if ManpageTitleVolnumRx =~ document.attributes['doctitle']
      document.attributes['mantitle'] = document.sub_attributes $1.downcase
      document.attributes['manvolnum'] = $2
    else
      warn %(asciidoctor: ERROR: #{reader.prev_line_info}: malformed manpage title)
      # provide sensible fallbacks
      document.attributes['mantitle'] = document.attributes['doctitle']
      document.attributes['manvolnum'] = '1'
    end

    reader.skip_blank_lines

    if is_next_line_section?(reader, {})
      name_section = initialize_section(reader, document, {})
      if name_section.level == 1
        name_section_buffer = reader.read_lines_until(:break_on_blank_lines => true) * ' '
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
  #   Parser.next_section(reader, doc)[0].title
  #   # => "Greetings"
  #
  #   Parser.next_section(reader, doc)[0].title
  #   # => "Salutations"
  #
  # returns a two-element Array containing the Section and Hash of orphaned attributes
  def self.next_section reader, parent, attributes = {}
    preamble = intro = part = false

    # FIXME if attributes[1] is a verbatim style, then don't check for section

    # check if we are at the start of processing the document
    # NOTE we could drop a hint in the attributes to indicate
    # that we are at a section title (so we don't have to check)
    if parent.context == :document && parent.blocks.empty? && ((has_header = parent.has_header?) ||
        (attributes.delete 'invalid-header') || !(is_next_line_section? reader, attributes))
      doctype = (document = parent).doctype
      if has_header || (doctype == 'book' && attributes[1] != 'abstract')
        preamble = intro = (Block.new parent, :preamble, :content_model => :compound)
        preamble.title = parent.attr 'preface-title' if doctype == 'book' && (parent.attr? 'preface-title')
        parent << preamble
      end
      section = parent

      current_level = 0
      if parent.attributes.key? 'fragment'
        expected_next_levels = nil
      # small tweak to allow subsequent level-0 sections for book doctype
      elsif doctype == 'book'
        expected_next_levels = [0, 1]
      else
        expected_next_levels = [1]
      end
    else
      doctype = (document = parent.document).doctype
      section = initialize_section reader, parent, attributes
      # clear attributes except for title attribute, which must be carried over to next content block
      attributes = (title = attributes['title']) ? { 'title' => title } : {}
      part = section.sectname == 'part'
      expected_next_levels = [(current_level = section.level) + 1]
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
      parse_block_metadata_lines reader, document, attributes

      if (next_level = is_next_line_section?(reader, attributes))
        next_level += document.attr('leveloffset').to_i if document.attr?('leveloffset')
        if next_level > current_level || (next_level == 0 && section.context == :document)
          if next_level == 0 && doctype != 'book'
            warn %(asciidoctor: ERROR: #{reader.line_info}: only book doctypes can contain level 0 sections)
          elsif expected_next_levels && !expected_next_levels.include?(next_level)
            warn %(asciidoctor: WARNING: #{reader.line_info}: section title out of sequence: expected #{expected_next_levels.size > 1 ? 'levels' : 'level'} #{expected_next_levels * ' or '}, got level #{next_level})
          end
          # the attributes returned are those that are orphaned
          new_section, attributes = next_section reader, section, attributes
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
        if (new_block = next_block reader, intro || section, attributes, :parse_metadata => false)
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

  # Public: Parse and return the next Block at the Reader's current location
  #
  # This method begins by skipping over blank lines to find the start of the
  # next block (paragraph, block macro, or delimited block). If a block is
  # found, that block is parsed, initialized as a Block object, and returned.
  # Otherwise, the method returns nothing.
  #
  # Regular expressions from the Asciidoctor module are used to match block
  # boundaries. The ensuing lines are then processed according to the content
  # model.
  #
  # reader     - The Reader from which to retrieve the next Block.
  # parent     - The Document, Section or Block to which the next Block belongs.
  # attributes - A Hash of attributes that will become the attributes
  #              associated with the parsed Block (default: {}).
  # options    - An options Hash to control parsing (default: {}):
  #              * :text indicates that the parser is only looking for text content
  #
  # Returns a Block object built from the parsed content of the processed
  # lines, or nothing if no block is found.
  def self.next_block(reader, parent, attributes = {}, options = {})
    # Skip ahead to the block content
    skipped = reader.skip_blank_lines

    # bail if we've reached the end of the parent block or document
    return unless reader.has_more_lines?

    # check for option to find list item text only
    # if skipped a line, assume a list continuation was
    # used and block content is acceptable
    if (text_only = options[:text]) && skipped > 0
      options.delete :text
      text_only = false
    end

    document = parent.document

    if options.fetch :parse_metadata, true
      # read lines until there are no more metadata lines to read
      while parse_block_metadata_line reader, document, attributes, options
        advanced = reader.advance
      end
      if advanced && !reader.has_more_lines?
        # NOTE there are no cases when these attributes are used, but clear them anyway
        attributes.clear
        return
      end
    end

    if (extensions = document.extensions)
      block_extensions, block_macro_extensions = extensions.blocks?, extensions.block_macros?
    end

    # QUESTION should we introduce a parsing context object?
    source_location = reader.cursor if document.sourcemap
    this_path, this_lineno, this_line, in_list = reader.path, reader.lineno, reader.read_line, ListItem === parent
    block = block_context = cloaked_context = terminator = nil
    style = attributes[1] ? (parse_style_attribute attributes, reader) : nil

    if (delimited_block = is_delimited_block? this_line, true)
      block_context = cloaked_context = delimited_block.context
      terminator = delimited_block.terminator
      if !style
        style = attributes['style'] = block_context.to_s
      elsif style != block_context.to_s
        if delimited_block.masq.include? style
          block_context = style.to_sym
        elsif delimited_block.masq.include?('admonition') && ADMONITION_STYLES.include?(style)
          block_context = :admonition
        elsif block_extensions && extensions.registered_for_block?(style, block_context)
          block_context = style.to_sym
        else
          warn %(asciidoctor: WARNING: #{this_path}: line #{this_lineno}: invalid style for #{block_context} block: #{style})
          style = block_context.to_s
        end
      end
    end

    # this loop is used for flow control; it only executes once, and only when delimited_block is set
    # break once a block is found or at end of loop
    # returns nil if the line should be dropped
    while true
      # process lines verbatim
      if style && Compliance.strict_verbatim_paragraphs && VERBATIM_STYLES.include?(style)
        block_context = style.to_sym
        reader.unshift_line this_line
        # advance to block parsing =>
        break
      end

      # process lines normally
      if text_only
        indented = this_line.start_with? ' ', TAB
      else
        # NOTE move this declaration up if we need it when text_only is false
        md_syntax = Compliance.markdown_syntax
        if this_line.start_with? ' '
          indented, ch0 = true, ' '
          # QUESTION should we test line length?
          if md_syntax && this_line.lstrip.start_with?(*MARKDOWN_THEMATIC_BREAK_CHARS.keys) &&
              #!(this_line.start_with? '    ') &&
              (MarkdownThematicBreakRx.match? this_line)
            # NOTE we're letting break lines (horizontal rule, page_break, etc) have attributes
            block = Block.new(parent, :thematic_break, :content_model => :empty)
            break
          end
        elsif this_line.start_with? TAB
          indented, ch0 = true, TAB
        else
          indented, ch0 = false, this_line.chr
          layout_break_chars = md_syntax ? HYBRID_LAYOUT_BREAK_CHARS : LAYOUT_BREAK_CHARS
          if (layout_break_chars.key? ch0) && (md_syntax ? (HybridLayoutBreakRx.match? this_line) :
              (this_line == ch0 * (ll = this_line.length) && ll > 2))
            # NOTE we're letting break lines (horizontal rule, page_break, etc) have attributes
            block = Block.new(parent, layout_break_chars[ch0], :content_model => :empty)
            break
          # NOTE very rare that a text-only line will end in ] (e.g., inline macro), so check that first
          elsif (this_line.end_with? ']') && (this_line.include? '::')
            #if (this_line.start_with? 'image', 'video', 'audio') && (match = BlockMediaMacroRx.match(this_line))
            if (ch0 == 'i' || (this_line.start_with? 'video:', 'audio:')) && (match = BlockMediaMacroRx.match(this_line))
              blk_ctx, target = match[1].to_sym, match[2]
              block = Block.new(parent, blk_ctx, :content_model => :empty)
              case blk_ctx
              when :video
                posattrs = ['poster', 'width', 'height']
              when :audio
                posattrs = []
              else # :image
                posattrs = ['alt', 'width', 'height']
              end
              block.parse_attributes(match[3], posattrs, :sub_input => true, :sub_result => false, :into => attributes)
              # style doesn't have special meaning for media macros
              attributes.delete 'style' if attributes.key? 'style'
              if (target.include? '{') && (target = block.sub_attributes target, :attribute_missing => 'drop-line').empty?
                # retain as unparsed if attribute-missing is skip
                if document.attributes.fetch('attribute-missing', Compliance.attribute_missing) == 'skip'
                  return Block.new(parent, :paragraph, :content_model => :simple, :source => [this_line])
                # otherwise, drop the line
                else
                  attributes.clear
                  return
                end
              end
              if blk_ctx == :image
                block.document.register :images, target
                # NOTE style is the value of the first positional attribute in the block attribute line
                attributes['alt'] ||= style || (attributes['default-alt'] = Helpers.basename(target, true).tr('_-', ' '))
                unless (scaledwidth = attributes.delete 'scaledwidth').nil_or_empty?
                  # NOTE assume % units if not specified
                  attributes['scaledwidth'] = (TrailingDigitsRx.match? scaledwidth) ? %(#{scaledwidth}%) : scaledwidth
                end
                block.title = attributes.delete 'title'
                block.assign_caption((attributes.delete 'caption'), 'figure')
              end
              attributes['target'] = target
              break

            elsif ch0 == 't' && (this_line.start_with? 'toc:') && (match = BlockTocMacroRx.match(this_line))
              block = Block.new(parent, :toc, :content_model => :empty)
              block.parse_attributes(match[1], [], :sub_result => false, :into => attributes)
              break

            elsif block_macro_extensions && (match = CustomBlockMacroRx.match(this_line)) &&
                (extension = extensions.registered_for_block_macro?(match[1]))
              target = match[2]
              content = match[3]
              if extension.config[:content_model] == :attributes
                unless content.empty?
                  document.parse_attributes(content, extension.config[:pos_attrs] || [],
                      :sub_input => true, :sub_result => false, :into => attributes)
                end
              else
                attributes['text'] = content
              end
              if (default_attrs = extension.config[:default_attrs])
                attributes.update(default_attrs) {|_, old_v| old_v }
              end
              if (block = extension.process_method[parent, target, attributes])
                attributes.replace block.attributes
                break
              else
                attributes.clear
                return
              end
            end
          end
        end
      end

      # haven't found anything yet, continue
      if !indented && CALLOUT_LIST_LEADERS.include?(ch0 ||= this_line.chr) &&
          (CalloutListSniffRx.match? this_line) && (match = CalloutListRx.match this_line)
        block = List.new(parent, :colist)
        attributes['style'] = 'arabic'
        reader.unshift_line this_line
        expected_index = 1
        # NOTE skip the match on the first time through as we've already done it (emulates begin...while)
        while match || (reader.has_more_lines? && (match = CalloutListRx.match(reader.peek_line)))
          list_item_lineno = reader.lineno
          # might want to move this check to a validate method
          unless match[1] == expected_index.to_s
            warn %(asciidoctor: WARNING: #{reader.path}: line #{list_item_lineno}: callout list item index: expected #{expected_index} got #{match[1]})
          end
          if (list_item = next_list_item reader, block, match)
            block << list_item
            if (coids = document.callouts.callout_ids block.items.size).empty?
              warn %(asciidoctor: WARNING: #{reader.path}: line #{list_item_lineno}: no callouts refer to list item #{block.items.size})
            else
              list_item.attributes['coids'] = coids
            end
          end
          expected_index += 1
          match = nil
        end

        document.callouts.next_list
        break

      elsif UnorderedListRx.match? this_line
        reader.unshift_line this_line
        block = next_item_list(reader, :ulist, parent)
        if (style || (Section === parent && parent.sectname)) == 'bibliography'
          attributes['style'] = 'bibliography' unless style
          block.items.each {|item| catalog_inline_biblio_anchor item.instance_variable_get(:@text), item, document }
        end
        break

      elsif (match = OrderedListRx.match(this_line))
        reader.unshift_line this_line
        block = next_item_list(reader, :olist, parent)
        # FIXME move this logic into next_item_list
        unless style
          marker = block.items[0].marker
          if marker.start_with? '.'
            # first one makes more sense, but second one is AsciiDoc-compliant
            # TODO control behavior using a compliance setting
            #attributes['style'] = (ORDERED_LIST_STYLES[block.level - 1] || 'arabic').to_s
            attributes['style'] = (ORDERED_LIST_STYLES[marker.length - 1] || 'arabic').to_s
          else
            attributes['style'] = (ORDERED_LIST_STYLES.find {|s| OrderedListMarkerRxMap[s].match? marker } || 'arabic').to_s
          end
        end
        break

      elsif (match = DescriptionListRx.match(this_line))
        reader.unshift_line this_line
        block = next_description_list(reader, match, parent)
        break

      elsif (style == 'float' || style == 'discrete') && (Compliance.underline_style_section_titles ?
          (is_section_title? this_line, (reader.peek_line true)) : !indented && (is_section_title? this_line))
        reader.unshift_line this_line
        float_id, float_reftext, float_title, float_level, _ = parse_section_title(reader, document)
        attributes['reftext'] = float_reftext if float_reftext
        block = Block.new(parent, :floating_title, :content_model => :empty)
        block.title = float_title
        attributes.delete 'title'
        block.id = float_id || attributes['id'] ||
            ((document.attributes.key? 'sectids') ? (Section.generate_id block.title, document) : nil)
        block.level = float_level
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
          warn %(asciidoctor: WARNING: #{this_path}: line #{this_lineno}: invalid style for paragraph: #{style})
          style = nil
          # continue to process paragraph
        end
      end

      break_at_list = (skipped == 0 && in_list)
      reader.unshift_line this_line

      # a literal paragraph: contiguous lines starting with at least one whitespace character
      # NOTE style can only be nil or "normal" at this point
      if indented && !style
        lines = read_paragraph_lines reader, break_at_list, :skip_line_comments => text_only

        adjust_indentation! lines

        block = Block.new(parent, :literal, :content_model => :verbatim, :source => lines, :attributes => attributes)
        # a literal gets special meaning inside of a description list
        # TODO this feels hacky, better way to distinguish from explicit literal block?
        block.set_option('listparagraph') if in_list

      # a normal paragraph: contiguous non-blank/non-continuation lines (left-indented or normal style)
      else
        lines = read_paragraph_lines reader, break_at_list, :skip_line_comments => true

        # NOTE we need this logic because we've asked the reader to skip
        # line comments, which may leave us w/ an empty buffer if those
        # were the only lines found
        if in_list && lines.empty?
          # call advance since the reader preserved the last line
          reader.advance
          return
        end

        # NOTE don't check indented here since it's extremely rare
        #if text_only || indented
        if text_only
          # if [normal] is used over an indented paragraph, shift content to left margin
          # QUESTION do we even need to shift since whitespace is normalized by XML in this case?
          adjust_indentation! lines if indented && style == 'normal'
          block = Block.new(parent, :paragraph, :content_model => :simple, :source => lines, :attributes => attributes)
        elsif (ADMONITION_STYLE_LEADERS.include? ch0) && (this_line.include? ':') && (AdmonitionParagraphRx =~ this_line)
          lines[0] = $' # string after match
          attributes['name'] = admonition_name = (attributes['style'] = $1).downcase
          attributes['textlabel'] = (attributes.delete 'caption') || document.attributes[%(#{admonition_name}-caption)]
          block = Block.new(parent, :admonition, :content_model => :simple, :source => lines, :attributes => attributes)
        elsif md_syntax && ch0 == '>' && this_line.start_with?('> ')
          lines.map! {|line| line == '>' ? line[1..-1] : ((line.start_with? '> ') ? line[2..-1] : line) }
          if lines[-1].start_with? '-- '
            attribution, citetitle = lines.pop[3..-1].split(', ', 2)
            attributes['attribution'] = attribution if attribution
            attributes['citetitle'] = citetitle if citetitle
            lines.pop while lines[-1].empty?
          end
          attributes['style'] = 'quote'
          # NOTE will only detect headings that are floating titles (not section titles)
          # TODO could assume a floating title when inside a block context
          # FIXME Reader needs to be created w/ line info
          block = build_block(:quote, :compound, false, parent, Reader.new(lines), attributes)
        elsif ch0 == '"' && lines.size > 1 && (lines[-1].start_with? '-- ') && (lines[-2].end_with? '"')
          lines[0] = this_line[1..-1] # strip leading quote
          attribution, citetitle = lines.pop[3..-1].split(', ', 2)
          attributes['attribution'] = attribution if attribution
          attributes['citetitle'] = citetitle if citetitle
          lines.pop while lines[-1].empty?
          lines[-1] = lines[-1].chop # strip trailing quote
          attributes['style'] = 'quote'
          block = Block.new(parent, :quote, :content_model => :simple, :source => lines, :attributes => attributes)
        else
          # if [normal] is used over an indented paragraph, shift content to left margin
          # QUESTION do we even need to shift since whitespace is normalized by XML in this case?
          adjust_indentation! lines if indented && style == 'normal'
          block = Block.new(parent, :paragraph, :content_model => :simple, :source => lines, :attributes => attributes)
        end

        catalog_inline_anchors lines * LF, block, document
      end

      break # forbid loop from executing more than once
    end unless delimited_block

    # either delimited block or styled paragraph
    unless block
      # abstract and partintro should be handled by open block
      # FIXME kind of hackish...need to sort out how to generalize this
      block_context = :open if block_context == :abstract || block_context == :partintro

      case block_context
      when :admonition
        attributes['name'] = admonition_name = style.downcase
        attributes['textlabel'] = (attributes.delete 'caption') || document.attributes[%(#{admonition_name}-caption)]
        block = build_block(block_context, :compound, terminator, parent, reader, attributes)

      when :comment
        build_block(block_context, :skip, terminator, parent, reader, attributes)
        return

      when :example
        block = build_block(block_context, :compound, terminator, parent, reader, attributes)

      when :listing, :literal
        block = build_block(block_context, :verbatim, terminator, parent, reader, attributes)

      when :source
        AttributeList.rekey attributes, [nil, 'language', 'linenums']
        if document.attributes.key? 'source-language'
          attributes['language'] = document.attributes['source-language'] || 'text'
        end unless attributes.key? 'language'
        if (attributes.key? 'linenums-option') || (document.attributes.key? 'source-linenums-option')
          attributes['linenums'] = ''
        end unless attributes.key? 'linenums'
        if document.attributes.key? 'source-indent'
          attributes['indent'] = document.attributes['source-indent']
        end unless attributes.key? 'indent'
        block = build_block(:listing, :verbatim, terminator, parent, reader, attributes)

      when :fenced_code
        attributes['style'] = 'source'
        if (ll = this_line.length) == 3
          language = nil
        elsif (comma_idx = (language = this_line.slice 3, ll).index ',')
          if comma_idx > 0
            language = (language.slice 0, comma_idx).strip
            attributes['linenums'] = '' if comma_idx < ll - 4
          else
            language = nil
            attributes['linenums'] = '' if ll > 4
          end
        else
          language = language.lstrip
        end
        if language.nil_or_empty?
          if document.attributes.key? 'source-language'
            attributes['language'] = document.attributes['source-language'] || 'text'
          end
        else
          attributes['language'] = language
        end
        if (attributes.key? 'linenums-option') || (document.attributes.key? 'source-linenums-option')
          attributes['linenums'] = ''
        end unless attributes.key? 'linenums'
        if document.attributes.key? 'source-indent'
          attributes['indent'] = document.attributes['source-indent']
        end unless attributes.key? 'indent'
        terminator = terminator.slice 0, 3
        block = build_block(:listing, :verbatim, terminator, parent, reader, attributes)

      when :pass
        block = build_block(block_context, :raw, terminator, parent, reader, attributes)

      when :stem, :latexmath, :asciimath
        if block_context == :stem
          attributes['style'] = if (explicit_stem_syntax = attributes[2])
            explicit_stem_syntax.include?('tex') ? 'latexmath' : 'asciimath'
          elsif (default_stem_syntax = document.attributes['stem']).nil_or_empty?
            'asciimath'
          else
            default_stem_syntax
          end
        end
        block = build_block(:stem, :raw, terminator, parent, reader, attributes)

      when :open, :sidebar
        block = build_block(block_context, :compound, terminator, parent, reader, attributes)

      when :table
        block_reader = Reader.new reader.read_lines_until(:terminator => terminator, :skip_line_comments => true), reader.cursor
        # NOTE it's very rare that format is set when using a format hint char, so short-circuit
        unless terminator.start_with? '|', '!'
          # NOTE infer dsv once all other format hint chars are ruled out
          attributes['format'] ||= (terminator.start_with? ',') ? 'csv' : 'dsv'
        end
        block = next_table(block_reader, parent, attributes)

      when :quote, :verse
        AttributeList.rekey(attributes, [nil, 'attribution', 'citetitle'])
        block = build_block(block_context, (block_context == :verse ? :verbatim : :compound), terminator, parent, reader, attributes)

      else
        if block_extensions && (extension = extensions.registered_for_block?(block_context, cloaked_context))
          if (content_model = extension.config[:content_model]) != :skip
            if !(pos_attrs = extension.config[:pos_attrs] || []).empty?
              AttributeList.rekey(attributes, [nil].concat(pos_attrs))
            end
            if (default_attrs = extension.config[:default_attrs])
              default_attrs.each {|k, v| attributes[k] ||= v }
            end
            # QUESTION should we clone the extension for each cloaked context and set in config?
            attributes['cloaked-context'] = cloaked_context
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

    # FIXME we've got to clean this up, it's horrible!
    block.source_location = source_location if source_location
    # FIXME title should be assigned when block is constructed
    block.title = attributes.delete 'title' if attributes.key? 'title'
    #unless attributes.key? 'reftext'
    #  attributes['reftext'] = document.attributes['reftext'] if document.attributes.key? 'reftext'
    #end
    # TODO eventually remove the style attribute from the attributes hash
    #block.style = attributes.delete 'style'
    block.style = attributes['style']
    if (block_id = (block.id ||= attributes['id']))
      unless document.register :refs, [block_id, block, attributes['reftext'] || (block.title? ? block.title : nil)]
        warn %(asciidoctor: WARNING: #{this_path}: line #{this_lineno}: id assigned to block already in use: #{block_id})
      end
    end
    # FIXME remove the need for this update!
    block.attributes.update(attributes) unless attributes.empty?
    block.lock_in_subs

    #if document.attributes.key? :pending_attribute_entries
    #  document.attributes.delete(:pending_attribute_entries).each do |entry|
    #    entry.save_to block.attributes
    #  end
    #end

    if block.sub? :callouts
      # No need to sub callouts if none are found when cataloging
      block.remove_sub :callouts unless catalog_callouts block.source, document
    end

    block
  end

  def self.read_paragraph_lines reader, break_at_list, opts = {}
    opts[:break_on_blank_lines] = true
    opts[:break_on_list_continuation] = true
    opts[:preserve_last_line] = true
    break_condition = (break_at_list ?
        (Compliance.block_terminates_paragraph ? StartOfBlockOrListProc : StartOfListProc) :
        (Compliance.block_terminates_paragraph ? StartOfBlockProc : NoOp))
    reader.read_lines_until opts, &break_condition
  end

  # Public: Determines whether this line is the start of any of the delimited blocks
  #
  # returns the match data if this line is the first line of a delimited block or nil if not
  def self.is_delimited_block? line, return_match_data = false
    # highly optimized for best performance
    return unless (line_len = line.length) > 1 && DELIMITED_BLOCK_LEADERS.include?(line.slice 0, 2)
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
        tip = line.slice 0, 4
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

    if DELIMITED_BLOCKS.key? tip
      # tip is the full line when delimiter is minimum length
      if tl < 4 || tl == line_len
        if return_match_data
          context, masq = DELIMITED_BLOCKS[tip]
          BlockMatchData.new(context, masq, tip, tip)
        else
          true
        end
      elsif %(#{tip}#{tip[-1..-1] * (line_len - tl)}) == line
        if return_match_data
          context, masq = DELIMITED_BLOCKS[tip]
          BlockMatchData.new(context, masq, tip, line)
        else
          true
        end
      # only enable if/when we decide to support non-congruent block delimiters
      #elsif (match = BlockDelimiterRx.match(line))
      #  if return_match_data
      #    context, masq = DELIMITED_BLOCKS[tip]
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

  # whether a block supports compound content should be a config setting
  # if terminator is false, that means the all the lines in the reader should be parsed
  # NOTE could invoke filter in here, before and after parsing
  def self.build_block(block_context, content_model, terminator, parent, reader, attributes, options = {})
    if content_model == :skip
      skip_processing = true
      parse_as_content_model = :simple
    elsif content_model == :raw
      skip_processing = false
      parse_as_content_model = :simple
    else
      skip_processing = false
      parse_as_content_model = content_model
    end

    if terminator.nil?
      if parse_as_content_model == :verbatim
        lines = reader.read_lines_until :break_on_blank_lines => true, :break_on_list_continuation => true
      else
        content_model = :simple if content_model == :compound
        # TODO we could also skip processing if we're able to detect reader is a BlockReader
        lines = read_paragraph_lines reader, false, :skip_line_comments => true, :skip_processing => skip_processing
        # QUESTION check for empty lines after grabbing lines for simple content model?
      end
      block_reader = nil
    elsif parse_as_content_model != :compound
      lines = reader.read_lines_until :terminator => terminator, :skip_processing => skip_processing
      block_reader = nil
    # terminator is false when reader has already been prepared
    elsif terminator == false
      lines = nil
      block_reader = reader
    else
      lines = nil
      block_reader = Reader.new reader.read_lines_until(:terminator => terminator, :skip_processing => skip_processing), reader.cursor
    end

    if content_model == :skip
      attributes.clear
      # FIXME we shouldn't be mixing return types
      return lines
    end

    if content_model == :verbatim
      if (indent = attributes['indent'])
        adjust_indentation! lines, indent, (attributes['tabsize'] || parent.document.attributes['tabsize'])
      elsif (tab_size = (attributes['tabsize'] || parent.document.attributes['tabsize']).to_i) > 0
        adjust_indentation! lines, nil, tab_size
      end
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
    if (attributes.key? 'title') && block.context != :admonition &&
        (parent.document.attributes.key? %(#{block.context}-caption))
      block.title = attributes.delete 'title'
      block.assign_caption(attributes.delete 'caption')
    end

    # reader is confined within boundaries of a delimited block, so look for
    # blocks until there are no more lines
    parse_blocks block_reader, block if content_model == :compound

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
    while (block = next_block reader, parent)
      parent << block
    end
  end

  # Internal: Parse and construct an item list (ordered or unordered) from the current position of the Reader
  #
  # reader    - The Reader from which to retrieve the outline list
  # list_type - A Symbol representing the list type (:olist for ordered, :ulist for unordered)
  # parent    - The parent Block to which this outline list belongs
  #
  # Returns the Block encapsulating the parsed outline (unordered or ordered) list
  def self.next_item_list(reader, list_type, parent)
    list_block = List.new(parent, list_type)
    if parent.context == list_type
      list_block.level = parent.level + 1
    else
      list_block.level = 1
    end

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
  # document - The current document in which the callouts are stored
  #
  # Returns A Boolean indicating whether callouts were found
  def self.catalog_callouts(text, document)
    found = false
    text.scan(CalloutScanRx) {
      # lead with assignments for Ruby 1.8.7 compat
      captured, num = $&, $2
      document.callouts.register num unless captured.start_with? '\\'
      # we have to mark as found even if it's escaped so it can be unescaped
      found = true
    } if text.include? '<'
    found
  end

  # Internal: Catalog any inline anchors found in the text (but don't convert)
  #
  # text     - The String text in which to look for inline anchors
  # block    - The block in which the references should be searched
  # document - The current Document on which the references are stored
  #
  # Returns nothing
  def self.catalog_inline_anchors text, block, document
    text.scan(InlineAnchorScanRx) do
      if (id = $1)
        if (reftext = $2)
          next if (reftext.include? '{') && (reftext = document.sub_attributes reftext).empty?
        end
      else
        id = $3
        if (reftext = $4)
          reftext = reftext.gsub '\]', ']' if reftext.include? ']'
          next if (reftext.include? '{') && (reftext = document.sub_attributes reftext).empty?
        end
      end
      unless document.register :refs, [id, (Inline.new block, :anchor, reftext, :type => :ref, :id => id), reftext]
        warn %(asciidoctor: WARNING: #{document.reader.path}: id assigned to anchor already in use: #{id})
      end
    end if (text.include? '[[') || (text.include? 'or:')
    nil
  end

  # Internal: Catalog the bibliography inline anchor found in the start of the list item (but don't convert)
  #
  # text     - The String text in which to look for an inline bibliography anchor
  # block    - The ListItem block in which the reference should be searched
  # document - The current document in which the reference is stored
  #
  # Returns nothing
  def self.catalog_inline_biblio_anchor text, block, document
    if InlineBiblioAnchorRx =~ text
      # QUESTION should we sub attributes in reftext (like with regular anchors)?
      unless document.register :refs, [(id = $1), (Inline.new block, :anchor, (reftext = %([#{$2 || id}])), :type => :bibref, :id => id), reftext]
        warn %(asciidoctor: WARNING: #{document.reader.path}: id assigned to bibliography anchor already in use: #{id})
      end
    end
    nil
  end

  # Internal: Parse and construct a description list Block from the current position of the Reader
  #
  # reader    - The Reader from which to retrieve the description list
  # match     - The Regexp match for the head of the list
  # parent    - The parent Block to which this description list belongs
  #
  # Returns the Block encapsulating the parsed description list
  def self.next_description_list(reader, match, parent)
    list_block = List.new(parent, :dlist)
    previous_pair = nil
    # allows us to capture until we find a description item
    # that uses the same delimiter (::, :::, :::: or ;;)
    sibling_pattern = DescriptionListSiblingRx[match[2]]

    # NOTE skip the match on the first time through as we've already done it (emulates begin...while)
    while match || (reader.has_more_lines? && (match = sibling_pattern.match(reader.peek_line)))
      term, item = next_list_item(reader, list_block, match, sibling_pattern)
      if previous_pair && !previous_pair[-1]
        previous_pair.pop
        previous_pair[0] << term
        previous_pair << item
      else
        # FIXME this misses the automatic parent assignment
        list_block.items << (previous_pair = [[term], item])
      end
      match = nil
    end

    list_block
  end

  # Internal: Parse and construct the next ListItem for the current bulleted
  # (unordered or ordered) list Block, callout lists included, or the next
  # term ListItem and description ListItem pair for the description list Block.
  #
  # First collect and process all the lines that constitute the next list
  # item for the parent list (according to its type). Next, parse those lines
  # into blocks and associate them with the ListItem (in the case of a
  # description list, the description ListItem). Finally, fold the first block
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
        elsif text.start_with?('[x] ', '[*] ')
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
    list_item_reader = Reader.new read_lines_for_list_item(reader, list_type, sibling_trait, has_text), reader.cursor
    if list_item_reader.has_more_lines?
      # NOTE peek on the other side of any comment lines
      comment_lines = list_item_reader.skip_line_comments
      if (subsequent_line = list_item_reader.peek_line)
        list_item_reader.unshift_lines comment_lines unless comment_lines.empty?
        if (continuation_connects_first_block = subsequent_line.empty?)
          content_adjacent = false
        else
          content_adjacent = true
          # treat lines as paragraph text if continuation does not connect first block (i.e., has_text = false)
          has_text = false unless list_type == :dlist
        end
      else
        # NOTE we have no use for any trailing comment lines we might have found
        continuation_connects_first_block = false
        content_adjacent = false
      end

      # only relevant for :dlist
      options = {:text => !has_text}

      # we can look for blocks until there are no more lines (and not worry
      # about sections) since the reader is confined within the boundaries of a
      # list
      while list_item_reader.has_more_lines?
        if (new_block = next_block(list_item_reader, list_item, {}, options))
          list_item << new_block
        end
      end

      list_item.fold_first(continuation_connects_first_block, content_adjacent)
    end

    if list_type == :dlist
      if list_item.text? || list_item.blocks?
        [list_term, list_item]
      else
        [list_term, nil]
      end
    else
      list_item
    end
  end

  # Internal: Collect the lines belonging to the current list item, navigating
  # through all the rules that determine what comprises a list item.
  #
  # Grab lines until a sibling list item is found, or the block is broken by a
  # terminator (such as a line comment). Description lists are more greedy if
  # they don't have optional inline item text...they want that text
  #
  # reader          - The Reader from which to retrieve the lines.
  # list_type       - The Symbol context of the list (:ulist, :olist, :colist or :dlist)
  # sibling_trait   - A Regexp that matches a sibling of this list item or String list marker
  #                   of the items in this list (default: nil)
  # has_text        - Whether the list item has text defined inline (always true except for description lists)
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
      elsif list_type == :dlist && continuation != :active && (BlockAttributeLineRx.match? this_line)
        break
      else
        if continuation == :active && !this_line.empty?
          # literal paragraphs have special considerations (and this is one of
          # two entry points into one)
          # if we don't process it as a whole, then a line in it that looks like a
          # list item will throw off the exit from it
          if LiteralParagraphRx.match? this_line
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
          elsif (BlockTitleRx.match? this_line) || (BlockAttributeLineRx.match? this_line) || (AttributeEntryRx.match? this_line)
            buffer << this_line
          else
            if nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).find {|ctx| ListRxMap[ctx].match? this_line }
              within_nested_list = true
              if nested_list_type == :dlist && $3.nil_or_empty?
                # get greedy again
                has_text = false
              end
            end
            buffer << this_line
            continuation = :inactive
          end
        elsif prev_line && prev_line.empty?
          # advance to the next line of content
          if this_line.empty?
            reader.skip_blank_lines
            this_line = reader.read_line
            # stop reading if we hit eof or a sibling list item
            break unless this_line && !is_sibling_list_item?(this_line, list_type, sibling_trait)
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
              elsif nested_list_type = NESTABLE_LIST_CONTEXTS.find {|ctx| ListRxMap[ctx] =~ this_line }
                buffer << this_line
                within_nested_list = true
                if nested_list_type == :dlist && $3.nil_or_empty?
                  # get greedy again
                  has_text = false
                end
              # slurp up any literal paragraph offset by blank lines
              # NOTE we have to check for indented list items first
              elsif LiteralParagraphRx.match? this_line
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
          if nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).find {|ctx| ListRxMap[ctx] =~ this_line }
            within_nested_list = true
            if nested_list_type == :dlist && $3.nil_or_empty?
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

    #warn "BUFFER[#{list_type},#{sibling_trait}]>#{buffer * LF}<BUFFER"
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
  def self.initialize_section reader, parent, attributes = {}
    document = parent.document
    source_location = reader.cursor if document.sourcemap
    sect_id, sect_reftext, sect_title, sect_level, single_line = parse_section_title reader, document
    if sect_reftext
      attributes['reftext'] = sect_reftext
    elsif attributes.key? 'reftext'
      sect_reftext = attributes['reftext']
    #elsif document.attributes.key? 'reftext'
    #  sect_reftext = attributes['reftext'] = document.attributes['reftext']
    end

    # parse style, id, and role attributes from first positional attribute if present
    style = attributes[1] ? (parse_style_attribute attributes, reader) : nil
    if style
      if style == 'abstract' && document.doctype == 'book'
        sect_name, sect_level = 'chapter', 1
      else
        sect_name, sect_special = style, true
        sect_level = 1 if sect_level == 0
        sect_numbered_force = style == 'appendix'
      end
    else
      case document.doctype
      when 'book'
        sect_name = sect_level == 0 ? 'part' : (sect_level == 1 ? 'chapter' : 'section')
      when 'manpage'
        if (sect_title.casecmp 'synopsis') == 0
          sect_name, sect_special = 'synopsis', true
        else
          sect_name = 'section'
        end
      else
        sect_name = 'section'
      end
    end

    section = Section.new parent, sect_level, false
    section.id, section.title, section.sectname, section.source_location = sect_id, sect_title, sect_name, source_location
    # TODO honor special section numbering option (#661)
    if sect_special
      section.special = true
      section.numbered = true if sect_numbered_force
    elsif sect_level > 0 && (document.attributes.key? 'sectnums')
      section.numbered = section.special ? (parent.context == :section && parent.numbered) : true
    end

    # generate an ID if one was not embedded or specified as anchor above section title
    if (id = section.id ||= (attributes['id'] ||
        ((document.attributes.key? 'sectids') ? (Section.generate_id section.title, document) : nil)))
      unless document.register :refs, [id, section, sect_reftext || section.title]
        warn %(asciidoctor: WARNING: #{reader.path}: line #{reader.lineno - (single_line ? 1 : 2)}: id assigned to section already in use: #{id})
      end
    end

    section.update_attributes(attributes)
    reader.skip_blank_lines

    section
  end

  # Internal: Checks if the next line on the Reader is a section title
  #
  # reader     - the source Reader
  # attributes - a Hash of attributes collected above the current line
  #
  # Returns the Integer section level if the Reader is positioned at a section title or nil otherwise
  def self.is_next_line_section?(reader, attributes)
    if attributes.key?(1) && (attr1 = attributes[1] || '').start_with?('float', 'discrete') && FloatingTitleStyleRx.match?(attr1)
      return
    elsif reader.has_more_lines?
      Compliance.underline_style_section_titles ? is_section_title?(*reader.peek_lines(2)) : is_section_title?(reader.peek_line)
    end
  end

  # Internal: Convenience API for checking if the next line on the Reader is the document title
  #
  # reader      - the source Reader
  # attributes  - a Hash of attributes collected above the current line
  # leveloffset - an Integer (or integer String value) the represents the current leveloffset
  #
  # returns true if the Reader is positioned at the document title, false otherwise
  def self.is_next_line_doctitle? reader, attributes, leveloffset
    if leveloffset
      (sect_level = is_next_line_section? reader, attributes) && (sect_level + leveloffset.to_i == 0)
    else
      (is_next_line_section? reader, attributes) == 0
    end
  end

  # Public: Checks if these lines are a section title
  #
  # line1 - the first line as a String
  # line2 - the second line as a String (default: nil)
  #
  # Returns the Integer section level if these lines are a section title or nil otherwise
  def self.is_section_title?(line1, line2 = nil)
    is_single_line_section_title?(line1) || (line2.nil_or_empty? ? nil : is_two_line_section_title?(line1, line2))
  end

  def self.is_single_line_section_title?(line1)
    if (line1.start_with?('=') || (Compliance.markdown_syntax && line1.start_with?('#'))) && AtxSectionRx =~ line1
    #if line1.start_with?('=', '#') && AtxSectionRx =~ line1 && (line1.start_with?('=') || Compliance.markdown_syntax)
      # NOTE level is 1 less than number of line markers
      $1.length - 1
    end
  end

  def self.is_two_line_section_title?(line1, line2)
    if (level = SETEXT_SECTION_LEVELS[line2_ch1 = line2.chr]) &&
        line2_ch1 * (line2_len = line2.length) == line2 && SetextSectionTitleRx.match?(line1) &&
        (line_length(line1) - line2_len).abs < 2
      level
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
    sect_id = sect_reftext = nil
    line1 = reader.read_line

    #if line1.start_with?('=', '#') && AtxSectionRx =~ line1 && (line1.start_with?('=') || Compliance.markdown_syntax)
    if (line1.start_with?('=') || (Compliance.markdown_syntax && line1.start_with?('#'))) && AtxSectionRx =~ line1
      # NOTE level is 1 less than number of line markers
      sect_level, sect_title, single_line = $1.length - 1, $2, true
      if sect_title.end_with?(']]') && InlineSectionAnchorRx =~ sect_title && !$1 # escaped
        sect_title, sect_id, sect_reftext = (sect_title.slice 0, sect_title.length - $&.length), $2, $3
      end
    elsif Compliance.underline_style_section_titles && (line2 = reader.peek_line(true)) &&
        (sect_level = SETEXT_SECTION_LEVELS[line2_ch1 = line2.chr]) &&
        line2_ch1 * (line2_len = line2.length) == line2 && (sect_title = SetextSectionTitleRx =~ line1 && $1) &&
        (line_length(line1) - line2_len).abs < 2
      single_line = false
      if sect_title.end_with?(']]') && InlineSectionAnchorRx =~ sect_title && !$1 # escaped
        sect_title, sect_id, sect_reftext = (sect_title.slice 0, sect_title.length - $&.length), $2, $3
      end
      reader.advance
    else
      raise %(Unrecognized section at #{reader.prev_line_info})
    end
    sect_level += document.attr('leveloffset').to_i if document.attr?('leveloffset')
    [sect_id, sect_reftext, sect_title, sect_level, single_line]
  end

  # Public: Calculate the number of unicode characters in the line, excluding the endline
  #
  # line - the String to calculate
  #
  # returns the number of unicode characters in the line
  if FORCE_UNICODE_LINE_LENGTH
    def self.line_length(line)
      line.scan(UnicodeCharScanRx).size
    end
  else
    def self.line_length(line)
      line.length
    end
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
    process_attribute_entries reader, document

    metadata, implicit_author, implicit_authors = {}, nil, nil

    if reader.has_more_lines? && !reader.next_line_empty?
      unless (author_metadata = process_authors reader.read_line).empty?
        if document
          # apply header subs and assign to document
          author_metadata.each do |key, val|
            unless document.attributes.key? key
              document.attributes[key] = ::String === val ? (document.apply_header_subs val) : val
            end
          end

          implicit_author = document.attributes['author']
          implicit_authors = document.attributes['authors']
        end

        metadata = author_metadata
      end

      # NOTE this will discard any comment lines, but not skip blank lines
      process_attribute_entries reader, document

      rev_metadata = {}

      if reader.has_more_lines? && !reader.next_line_empty?
        rev_line = reader.read_line
        if (match = RevisionInfoLineRx.match(rev_line))
          rev_metadata['revnumber'] = match[1].rstrip if match[1]
          unless (component = match[2].strip).empty?
            # version must begin with 'v' if date is absent
            if !match[1] && (component.start_with? 'v')
              rev_metadata['revnumber'] = component[1..-1]
            else
              rev_metadata['revdate'] = component
            end
          end
          rev_metadata['revremark'] = match[3].rstrip if match[3]
        else
          # throw it back
          reader.unshift_line rev_line
        end
      end

      unless rev_metadata.empty?
        if document
          # apply header subs and assign to document
          rev_metadata.each do |key, val|
            unless document.attributes.key? key
              document.attributes[key] = document.apply_header_subs(val)
            end
          end
        end

        metadata.update rev_metadata
      end

      # NOTE this will discard any comment lines, but not skip blank lines
      process_attribute_entries reader, document

      reader.skip_blank_lines
    end

    # process author attribute entries that override (or stand in for) the implicit author line
    if document
      if document.attributes.key?('author') && (author_line = document.attributes['author']) != implicit_author
        # do not allow multiple, process as names only
        author_metadata = process_authors author_line, true, false
      elsif document.attributes.key?('authors') && (author_line = document.attributes['authors']) != implicit_authors
        # allow multiple, process as names only
        author_metadata = process_authors author_line, true
      else
        authors, author_idx, author_key, explicit, sparse = [], 1, 'author_1', false, false
        while document.attributes.key? author_key
          # only use indexed author attribute if value is different
          # leaves corner case if line matches with underscores converted to spaces; use double space to force
          if (author_override = document.attributes[author_key]) == author_metadata[author_key]
            authors << nil
            sparse = true
          else
            authors << author_override
            explicit = true
          end
          author_key = %(author_#{author_idx += 1})
        end
        if explicit
          # rebuild implicit author names to reparse
          authors.each_with_index do |author, idx|
            unless author
              authors[idx] = [
                author_metadata[%(firstname_#{name_idx = idx + 1})],
                author_metadata[%(middlename_#{name_idx})],
                author_metadata[%(lastname_#{name_idx})]
              ].compact.map {|it| it.tr ' ', '_' } * ' '
            end
          end if sparse
          # process as names only
          author_metadata = process_authors authors, true, false
        else
          author_metadata = {}
        end
      end

      unless author_metadata.empty?
        document.attributes.update author_metadata

        # special case
        if !document.attributes.key?('email') && document.attributes.key?('email_1')
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
  def self.process_authors author_line, names_only = false, multiple = true
    author_metadata = {}
    keys = ['author', 'authorinitials', 'firstname', 'middlename', 'lastname', 'email']
    author_entries = multiple ? (author_line.split ';').map {|it| it.strip } : Array(author_line)
    author_entries.each_with_index do |author_entry, idx|
      next if author_entry.empty?
      key_map = {}
      if idx == 0
        keys.each do |key|
          key_map[key.to_sym] = key
        end
      else
        keys.each do |key|
          key_map[key.to_sym] = %(#{key}_#{idx + 1})
        end
      end

      segments = nil
      if names_only # when parsing an attribute value
        # QUESTION should we rstrip author_entry?
        if author_entry.include? '<'
          author_metadata[key_map[:author]] = author_entry.tr('_', ' ')
          author_entry = author_entry.gsub XmlSanitizeRx, ''
        end
        # NOTE split names and collapse repeating whitespace (split drops any leading whitespace)
        if (segments = author_entry.split nil, 3).size == 3
          segments << (segments.pop.squeeze ' ')
        end
      elsif (match = AuthorInfoLineRx.match(author_entry))
        (segments = match.to_a).shift
      end

      if segments
        author = author_metadata[key_map[:firstname]] = fname = segments[0].tr('_', ' ')
        author_metadata[key_map[:authorinitials]] = fname.chr
        if segments[1]
          if segments[2]
            author_metadata[key_map[:middlename]] = mname = segments[1].tr('_', ' ')
            author_metadata[key_map[:lastname]] = lname = segments[2].tr('_', ' ')
            author = fname + ' ' + mname + ' ' + lname
            author_metadata[key_map[:authorinitials]] = %(#{fname.chr}#{mname.chr}#{lname.chr})
          else
            author_metadata[key_map[:lastname]] = lname = segments[1].tr('_', ' ')
            author = fname + ' ' + lname
            author_metadata[key_map[:authorinitials]] = %(#{fname.chr}#{lname.chr})
          end
        end
        author_metadata[key_map[:author]] ||= author
        author_metadata[key_map[:email]] = segments[3] unless names_only || !segments[3]
      else
        author_metadata[key_map[:author]] = author_metadata[key_map[:firstname]] = fname = author_entry.squeeze(' ').strip
        author_metadata[key_map[:authorinitials]] = fname.chr
      end

      author_metadata['authorcount'] = idx + 1
      # only assign the _1 attributes if there are multiple authors
      if idx == 1
        keys.each do |key|
          author_metadata[%(#{key}_1)] = author_metadata[key] if author_metadata.key? key
        end
      end
      if idx == 0
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
  # document   - the current Document
  # attributes - a Hash of attributes in which any metadata found will be stored (default: {})
  # options    - a Hash of options to control processing: (default: {})
  #              *  :text indicates that parser is only looking for text content
  #                   and thus the block title should not be captured
  #
  # returns the Hash of attributes including any metadata found
  def self.parse_block_metadata_lines reader, document, attributes = {}, options = {}
    while parse_block_metadata_line reader, document, attributes, options
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
  # document   - the current Document
  # attributes - a Hash of attributes in which any metadata found will be stored
  # options    - a Hash of options to control processing: (default: {})
  #              *  :text indicates the parser is only looking for text content,
  #                   thus neither a block title or attribute entry should be captured
  #
  # returns true if the line contains metadata, otherwise false
  def self.parse_block_metadata_line reader, document, attributes, options = {}
    if (next_line = reader.peek_line) &&
        (options[:text] ? (next_line.start_with? '[', '/') : (normal = next_line.start_with? '[', '.', '/', ':'))
      if next_line.start_with? '['
        if next_line.start_with? '[['
          if (next_line.end_with? ']]') && BlockAnchorRx =~ next_line
            # NOTE registration of id and reftext is deferred until block is processed
            attributes['id'] = $1
            if (reftext = $2)
              attributes['reftext'] = (reftext.include? '{') ? (document.sub_attributes reftext) : reftext
            end
            return true
          end
        elsif (next_line.end_with? ']') && BlockAttributeListRx =~ next_line
          document.parse_attributes $1, [], :sub_input => true, :into => attributes
          return true
        end
      elsif normal && (next_line.start_with? '.')
        if BlockTitleRx =~ next_line
          # NOTE title doesn't apply to section, but we need to stash it for the first block
          # TODO should issue an error if this is found above the document title
          attributes['title'] = $1
          return true
        end
      elsif !normal || (next_line.start_with? '/')
        if next_line == '//'
          return true
        elsif normal && '/' * (ll = next_line.length) == next_line
          unless ll == 3
            reader.read_lines_until :skip_first_line => true, :preserve_last_line => true, :terminator => next_line, :skip_processing => true
            return true
          end
        else
          return true unless next_line.start_with? '///'
        end if next_line.start_with? '//'
      # NOTE the final condition can be consolidated into single line
      elsif normal && (next_line.start_with? ':') && AttributeEntryRx =~ next_line
        process_attribute_entry reader, document, attributes, $~
        return true
      end
    end
  end

  def self.process_attribute_entries reader, document, attributes = nil
    reader.skip_comment_lines
    while process_attribute_entry reader, document, attributes
      # discard line just processed
      reader.advance
      reader.skip_comment_lines
    end
  end

  def self.process_attribute_entry reader, document, attributes = nil, match = nil
    if (match ||= (reader.has_more_lines? ? (AttributeEntryRx.match reader.peek_line) : nil))
      if (value = match[2]).nil_or_empty?
        value = ''
      elsif value.end_with? LINE_CONTINUATION, LINE_CONTINUATION_LEGACY
        con, value = value.slice(-2, 2), value.slice(0, value.length - 2).rstrip
        while reader.advance && !(next_line = reader.peek_line.lstrip).empty?
          if (keep_open = next_line.end_with? con)
            next_line = (next_line.slice 0, next_line.length - 2).rstrip
          end
          value = %(#{value}#{(value.end_with? HARD_LINE_BREAK) ? LF : ' '}#{next_line})
          break unless keep_open
        end
      end

      store_attribute match[1], value, document, attributes
      true
    end
  end

  # Public: Store the attribute in the document and register attribute entry if accessible
  #
  # name  - the String name of the attribute to store;
  #         if name begins or ends with !, it signals to remove the attribute with that root name
  # value - the String value of the attribute to store
  # doc   - the Document being parsed
  # attrs - the attributes for the current context
  #
  # returns a 2-element array containing the resolved attribute name (minus the ! indicator) and value
  def self.store_attribute name, value, doc = nil, attrs = nil
    # TODO move processing of attribute value to utility method
    if name.end_with? '!'
      # a nil value signals the attribute should be deleted (unset)
      name, value = name.chop, nil
    elsif name.start_with? '!'
      # a nil value signals the attribute should be deleted (unset)
      name, value = (name.slice 1, name.length), nil
    end

    name = sanitize_attribute_name name
    # alias numbered attribute to sectnums
    name = 'sectnums' if name == 'numbered'

    if doc
      if value
        if name == 'leveloffset'
          # support relative leveloffset values
          if value.start_with? '+'
            value = ((doc.attr 'leveloffset', 0).to_i + (value[1..-1] || 0).to_i).to_s
          elsif value.start_with? '-'
            value = ((doc.attr 'leveloffset', 0).to_i - (value[1..-1] || 0).to_i).to_s
          end
        end
        # QUESTION should we set value to locked value if set_attribute returns false?
        if (resolved_value = doc.set_attribute name, value)
          value = resolved_value
          (Document::AttributeEntry.new name, value).save_to attrs if attrs
        end
      elsif (doc.delete_attribute name) && attrs
        (Document::AttributeEntry.new name, value).save_to attrs
      end
    elsif attrs
      (Document::AttributeEntry.new name, value).save_to attrs
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
    if list_type == :olist
      (marker.start_with? '.') ? marker : (resolve_ordered_list_marker marker, ordinal, validate, reader)
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
    expected = actual = nil
    case ORDERED_LIST_STYLES.find {|s| OrderedListMarkerRxMap[s].match? marker }
    when :arabic
      if validate
        expected = ordinal + 1
        actual = marker.to_i # remove trailing . and coerce to int
      end
      marker = '1.'
    when :loweralpha
      if validate
        expected = ('a'[0].ord + ordinal).chr
        actual = marker.chop # remove trailing .
      end
      marker = 'a.'
    when :upperalpha
      if validate
        expected = ('A'[0].ord + ordinal).chr
        actual = marker.chop # remove trailing .
      end
      marker = 'A.'
    when :lowerroman
      if validate
        # TODO report this in roman numerals; see https://github.com/jamesshipton/roman-numeral/blob/master/lib/roman_numeral.rb
        expected = ordinal + 1
        actual = roman_numeral_to_int(marker.chop) # remove trailing ) and coerce to int
      end
      marker = 'i)'
    when :upperroman
      if validate
        # TODO report this in roman numerals; see https://github.com/jamesshipton/roman-numeral/blob/master/lib/roman_numeral.rb
        expected = ordinal + 1
        actual = roman_numeral_to_int(marker.chop) # remove trailing ) and coerce to int
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
    if ::Regexp === sibling_trait
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
    if attributes.key? 'title'
      table.title = attributes.delete 'title'
      table.assign_caption(attributes.delete 'caption')
    end

    if (attributes.key? 'cols') && !(colspecs = parse_colspecs attributes['cols']).empty?
      table.create_columns colspecs
      explicit_colspecs = true
    end

    skipped = table_reader.skip_blank_lines

    parser_ctx = Table::ParserContext.new table_reader, table, attributes
    format, loop_idx, implicit_header_boundary = parser_ctx.format, -1, nil
    implicit_header = true unless skipped > 0 || (attributes.key? 'header-option') || (attributes.key? 'noheader-option')
    while (line = table_reader.read_line)
      if (loop_idx += 1) > 0 && line.empty?
        line = nil
        implicit_header_boundary += 1 if implicit_header_boundary
      elsif format == 'psv'
        if parser_ctx.starts_with_delimiter? line
          line = line.slice 1, line.length
          # push empty cell spec if cell boundary appears at start of line
          parser_ctx.close_open_cell
          implicit_header_boundary = nil if implicit_header_boundary
        else
          next_cellspec, line = parse_cellspec line, :start, parser_ctx.delimiter
          # if cellspec is not nil, we're at a cell boundary
          if next_cellspec
            parser_ctx.close_open_cell next_cellspec
            implicit_header_boundary = nil if implicit_header_boundary
          # otherwise, the cell continues from previous line
          elsif implicit_header_boundary && implicit_header_boundary == loop_idx
            implicit_header, implicit_header_boundary = false, nil
          end
        end
      end

      # NOTE implicit header is offset by at least one blank line; implicit_header_boundary tracks size of gap
      if loop_idx == 0 && implicit_header
        if table_reader.has_more_lines? && table_reader.peek_line.empty?
          implicit_header_boundary = 1
        else
          implicit_header = false
        end
      end

      # this loop is used for flow control; internal logic controls how many times it executes
      while true
        if line && (m = parser_ctx.match_delimiter line)
          case format
          when 'csv'
            if parser_ctx.buffer_has_unclosed_quotes? m.pre_match
              break if (line = parser_ctx.skip_past_delimiter m).empty?
              redo
            end
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{m.pre_match})
          when 'dsv'
            if m.pre_match.end_with? '\\'
              if (line = parser_ctx.skip_past_escaped_delimiter m).empty?
                parser_ctx.buffer = %(#{parser_ctx.buffer}#{LF})
                parser_ctx.keep_cell_open
                break
              end
              redo
            end
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{m.pre_match})
          else # psv
            if m.pre_match.end_with? '\\'
              if (line = parser_ctx.skip_past_escaped_delimiter m).empty?
                parser_ctx.buffer = %(#{parser_ctx.buffer}#{LF})
                parser_ctx.keep_cell_open
                break
              end
              redo
            end
            next_cellspec, cell_text = parse_cellspec m.pre_match
            parser_ctx.push_cellspec next_cellspec
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{cell_text})
          end
          # don't break if empty to preserve empty cell found at end of line (see issue #1106)
          line = nil if (line = m.post_match).empty?
          parser_ctx.close_cell
        else
          # no other delimiters to see here; suck up this line into the buffer and move on
          parser_ctx.buffer = %(#{parser_ctx.buffer}#{line}#{LF})
          case format
          when 'csv'
            # QUESTION make stripping endlines in csv data an option? (unwrap-option?)
            parser_ctx.buffer = %(#{parser_ctx.buffer.rstrip} )
            if parser_ctx.buffer_has_unclosed_quotes?
              implicit_header, implicit_header_boundary = false, nil if implicit_header_boundary && loop_idx == 0
              parser_ctx.keep_cell_open
            else
              parser_ctx.close_cell true
            end
          when 'dsv'
            parser_ctx.close_cell true
          else # psv
            parser_ctx.keep_cell_open
          end
          break
        end
      end

      table_reader.skip_blank_lines unless parser_ctx.cell_open?

      unless table_reader.has_more_lines?
        # NOTE may have already closed cell in csv or dsv table (see previous call to parser_ctx.close_cell(true))
        parser_ctx.close_cell true if parser_ctx.cell_open?
      end
    end

    unless (table.attributes['colcount'] ||= table.columns.size) == 0 || explicit_colspecs
      table.assign_column_widths
    end

    if implicit_header
      table.has_header_option = true
      attributes['header-option'] = ''
      attributes['options'] = (attributes.key? 'options') ? %(#{attributes['options']},header) : 'header'
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
  def self.parse_colspecs records
    records = records.delete ' ' if records.include? ' '
    # check for deprecated syntax: single number, equal column spread
    if records == records.to_i.to_s
      return ::Array.new(records.to_i) { { 'width' => 1 } }
    end

    specs = []
    # NOTE -1 argument ensures we don't drop empty records
    records.split(',', -1).each {|record|
      if record.empty?
        specs << { 'width' => 1 }
      # TODO might want to use scan rather than this mega-regexp
      elsif (m = ColumnSpecRx.match(record))
        spec = {}
        if m[2]
          # make this an operation
          colspec, rowspec = m[2].split '.'
          if !colspec.nil_or_empty? && TableCellHorzAlignments.key?(colspec)
            spec['halign'] = TableCellHorzAlignments[colspec]
          end
          if !rowspec.nil_or_empty? && TableCellVertAlignments.key?(rowspec)
            spec['valign'] = TableCellVertAlignments[rowspec]
          end
        end

        # to_i permits us to support percentage width by stripping the %
        # NOTE this is slightly out of compliance w/ AsciiDoc, but makes way more sense
        spec['width'] = (m[3] ? m[3].to_i : 1)

        # make this an operation
        if m[4] && TableCellStyles.key?(m[4])
          spec['style'] = TableCellStyles[m[4]]
        end

        if m[1]
          1.upto(m[1].to_i) {
            specs << spec.dup
          }
        else
          specs << spec
        end
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
  def self.parse_cellspec(line, pos = :end, delimiter = nil)
    m, rest = nil, ''

    if pos == :start
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
    else # pos == :end
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
      if !colspec.nil_or_empty? && TableCellHorzAlignments.key?(colspec)
        spec['halign'] = TableCellHorzAlignments[colspec]
      end
      if !rowspec.nil_or_empty? && TableCellVertAlignments.key?(rowspec)
        spec['valign'] = TableCellVertAlignments[rowspec]
      end
    end

    if m[4] && TableCellStyles.key?(m[4])
      spec['style'] = TableCellStyles[m[4]]
    end

    [spec, rest]
  end

  # Public: Parse the first positional attribute and assign named attributes
  #
  # Parse the first positional attribute to extract the style, role and id
  # parts, assign the values to their cooresponding attribute keys and return
  # the parsed style from the first positional attribute.
  #
  # attributes - The Hash of attributes to process and update
  #
  # Examples
  #
  #   puts attributes
  #   => { 1 => "abstract#intro.lead%fragment", "style" => "preamble" }
  #
  #   parse_style_attribute(attributes)
  #   => "abstract"
  #
  #   puts attributes
  #   => { 1 => "abstract#intro.lead%fragment", "style" => "abstract", "id" => "intro",
  #         "role" => "lead", "options" => "fragment", "fragment-option" => '' }
  #
  # Returns the String style parsed from the first positional attribute
  def self.parse_style_attribute(attributes, reader = nil)
    # NOTE spaces are not allowed in shorthand, so if we detect one, this ain't no shorthand
    if (raw_style = attributes[1]) && !raw_style.include?(' ') && Compliance.shorthand_property_syntax
      type, collector, parsed = :style, [], {}
      # QUESTION should this be a private method? (though, it's never called if shorthand isn't used)
      save_current = lambda {
        if collector.empty?
          unless type == :style
            warn %(asciidoctor: WARNING:#{reader ? " #{reader.prev_line_info}:" : nil} invalid empty #{type} detected in style attribute)
          end
        else
          case type
          when :role, :option
            (parsed[type] ||= []) << collector.join
          when :id
            if parsed.key? :id
              warn %(asciidoctor: WARNING:#{reader ? " #{reader.prev_line_info}:" : nil} multiple ids detected in style attribute)
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
          collector << c
        end
      end

      # small optimization if no shorthand is found
      if type == :style
        attributes['style'] = raw_style
      else
        save_current.call

        parsed_style = attributes['style'] = parsed[:style] if parsed.key? :style

        attributes['id'] = parsed[:id] if parsed.key? :id

        attributes['role'] = parsed[:role] * ' ' if parsed.key? :role

        if parsed.key? :option
          (options = parsed[:option]).each {|option| attributes[%(#{option}-option)] = '' }
          if (existing_opts = attributes['options'])
            attributes['options'] = (options + existing_opts.split(',')) * ','
          else
            attributes['options'] = options * ','
          end
        end

        parsed_style
      end
    else
      attributes['style'] = raw_style
    end
  end

  # Remove the block indentation (the leading whitespace equal to the amount of
  # leading whitespace of the least indented line), then replace tabs with
  # spaces (using proper tab expansion logic) and, finally, indent the lines by
  # the amount specified.
  #
  # This method preserves the relative indentation of the lines.
  #
  # lines  - the Array of String lines to process (no trailing endlines)
  # indent - the integer number of spaces to add to the beginning
  #          of each line; if this value is nil, the existing
  #          space is preserved (optional, default: 0)
  #
  # Examples
  #
  #   source = <<EOS
  #       def names
  #         @name.split
  #       end
  #   EOS
  #
  #   source.split "\n"
  #   # => ["    def names", "      @names.split", "    end"]
  #
  #   puts Parser.adjust_indentation!(source.split "\n") * "\n"
  #   # => def names
  #   # =>   @names.split
  #   # => end
  #
  # returns Nothing
  #--
  # QUESTION should indent be called margin?
  def self.adjust_indentation! lines, indent = 0, tab_size = 0
    return if lines.empty?

    # expand tabs if a tab is detected unless tab_size is nil
    if (tab_size = tab_size.to_i) > 0 && (lines.join.include? TAB)
    #if (tab_size = tab_size.to_i) > 0 && (lines.index {|line| line.include? TAB })
      full_tab_space = ' ' * tab_size
      lines.map! do |line|
        next line if line.empty?

        # NOTE Opal has to patch this use of sub!
        line.sub!(TabIndentRx) { full_tab_space * $&.length } if line.start_with? TAB

        if line.include? TAB
          # keeps track of how many spaces were added to adjust offset in match data
          spaces_added = 0
          # NOTE Opal has to patch this use of gsub!
          line.gsub!(TabRx) {
            # calculate how many spaces this tab represents, then replace tab with spaces
            if (offset = ($~.begin 0) + spaces_added) % tab_size == 0
              spaces_added += (tab_size - 1)
              full_tab_space
            else
              unless (spaces = tab_size - offset % tab_size) == 1
                spaces_added += (spaces - 1)
              end
              ' ' * spaces
            end
          }
        else
          line
        end
      end
    end

    # skip adjustment of gutter if indent is -1
    return unless indent && (indent = indent.to_i) > -1

    # determine width of gutter
    gutter_width = nil
    lines.each do |line|
      next if line.empty?
      # NOTE this logic assumes no whitespace-only lines
      if (line_indent = line.length - line.lstrip.length) == 0
        gutter_width = nil
        break
      else
        unless gutter_width && line_indent > gutter_width
          gutter_width = line_indent
        end
      end
    end

    # remove gutter then apply new indent if specified
    # NOTE gutter_width is > 0 if not nil
    if indent == 0
      if gutter_width
        lines.map! {|line| line.empty? ? line : line[gutter_width..-1] }
      end
    else
      padding = ' ' * indent
      if gutter_width
        lines.map! {|line| line.empty? ? line : padding + line[gutter_width..-1] }
      else
        lines.map! {|line| line.empty? ? line : padding + line }
      end
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
