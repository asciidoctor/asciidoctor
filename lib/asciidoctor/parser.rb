# frozen_string_literal: true
module Asciidoctor
# Internal: Methods to parse lines of AsciiDoc into an object hierarchy
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
  include Logging

  BlockMatchData = Struct.new :context, :masq, :tip, :terminator

  # String for matching tab character
  TAB = ?\t

  # Regexp for leading tab indentation
  TabIndentRx = /^\t+/

  StartOfBlockProc = proc {|l| ((l.start_with? '[') && (BlockAttributeLineRx.match? l)) || (is_delimited_block? l) }

  StartOfListProc = proc {|l| AnyListRx.match? l }

  StartOfBlockOrListProc = proc {|l| (is_delimited_block? l) || ((l.start_with? '[') && (BlockAttributeLineRx.match? l)) || (AnyListRx.match? l) }

  NoOp = nil

  AuthorKeys = ['author', 'authorinitials', 'firstname', 'middlename', 'lastname', 'email']

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
    'a' => :asciidoc
  }

  # Hide the default constructor to make sure this class doesn't get instantiated.
  #
  # Raises NoMethodError if an attempt is made to invoke the constructor.
  private_class_method :new

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
    block_attributes = parse_document_header(reader, document, (header_only = options[:header_only]))

    # NOTE don't use a postfix conditional here as it's known to confuse JRuby in certain circumstances
    unless header_only
      while reader.has_more_lines?
        new_section, block_attributes = next_section(reader, document, block_attributes)
        if new_section
          document.assign_numeral new_section
          document.blocks << new_section
        end
      end
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
  def self.parse_document_header(reader, document, header_only = false)
    # capture lines of block-level metadata and plow away comment lines that precede first block
    block_attrs = reader.skip_blank_lines ? (parse_block_metadata_lines reader, document) : {}
    doc_attrs = document.attributes

    # special case, block title is not allowed above document title,
    # carry attributes over to the document body
    if (implicit_doctitle = is_next_line_doctitle? reader, block_attrs, doc_attrs['leveloffset']) && block_attrs['title']
      doc_attrs['authorcount'] = 0
      return document.finalize_header block_attrs, false
    end

    # yep, document title logic in AsciiDoc is just insanity
    # definitely an area for spec refinement

    unless (val = doc_attrs['doctitle']).nil_or_empty?
      document.title = doctitle_attr_val = val
    end

    # if the first line is the document title, add a header to the document and parse the header metadata
    if implicit_doctitle
      source_location = reader.cursor if document.sourcemap
      document.id, _, l0_section_title, _, atx = parse_section_title reader, document
      if doctitle_attr_val
        # NOTE doctitle attribute (set above or below implicit doctitle) overrides implicit doctitle
        l0_section_title = nil
      else
        document.title = l0_section_title
        if (doc_attrs['doctitle'] = doctitle_attr_val = document.sub_specialchars l0_section_title).include? ATTR_REF_HEAD
          # QUESTION should we defer substituting attributes until the end of the header? or should we substitute again if necessary?
          doc_attrs['doctitle'] = doctitle_attr_val = document.sub_attributes doctitle_attr_val, attribute_missing: 'skip'
        end
      end
      document.header.source_location = source_location if source_location
      # default to compat-mode if document has setext doctitle
      doc_attrs['compat-mode'] = '' unless atx || (document.attribute_locked? 'compat-mode')
      if (separator = block_attrs['separator'])
        doc_attrs['title-separator'] = separator unless document.attribute_locked? 'title-separator'
      end
      if (doc_id = block_attrs['id'])
        document.id = doc_id
      else
        doc_id = document.id
      end
      if (role = block_attrs['role'])
        doc_attrs['role'] = role
      end
      if (reftext = block_attrs['reftext'])
        doc_attrs['reftext'] = reftext
      end
      block_attrs.clear
      (modified_attrs = document.instance_variable_get :@attributes_modified).delete 'doctitle'
      parse_header_metadata reader, document, nil
      if modified_attrs.include? 'doctitle'
        if (val = doc_attrs['doctitle']).nil_or_empty? || val == doctitle_attr_val
          doc_attrs['doctitle'] = doctitle_attr_val
        else
          document.title = val
        end
      elsif !l0_section_title
        modified_attrs << 'doctitle'
      end
      document.register :refs, [doc_id, document] if doc_id
    elsif (author = doc_attrs['author'])
      author_metadata = process_authors author, true, false
      author_metadata.delete 'authorinitials' if doc_attrs['authorinitials']
      doc_attrs.update author_metadata
    elsif (author = doc_attrs['authors'])
      author_metadata = process_authors author, true
      doc_attrs.update author_metadata
    else
      doc_attrs['authorcount'] = 0
    end

    # parse title and consume name section of manpage document
    parse_manpage_header reader, document, block_attrs, header_only if document.doctype == 'manpage'

    # NOTE block_attrs are the block-level attributes (not document attributes) that
    # precede the first line of content (document title, first section or first block)
    document.finalize_header block_attrs
  end

  # Public: Parses the manpage header of the AsciiDoc source read from the Reader
  #
  # returns Nothing
  def self.parse_manpage_header(reader, document, block_attributes, header_only = false)
    if ManpageTitleVolnumRx =~ (doc_attrs = document.attributes)['doctitle']
      doc_attrs['manvolnum'] = manvolnum = $2
      doc_attrs['mantitle'] = (((mantitle = $1).include? ATTR_REF_HEAD) ? (document.sub_attributes mantitle) : mantitle).downcase
    else
      logger.error message_with_context 'non-conforming manpage title', source_location: (reader.cursor_at_line 1)
      # provide sensible fallbacks
      doc_attrs['mantitle'] = doc_attrs['doctitle'] || doc_attrs['docname'] || 'command'
      doc_attrs['manvolnum'] = manvolnum = '1'
    end
    if (manname = doc_attrs['manname']) && doc_attrs['manpurpose']
      doc_attrs['manname-title'] ||= 'Name'
      doc_attrs['mannames'] = [manname]
      if document.backend == 'manpage'
        doc_attrs['docname'] = manname
        doc_attrs['outfilesuffix'] = %(.#{manvolnum})
      end
    elsif header_only
      # done
    else
      reader.skip_blank_lines
      reader.save
      block_attributes.update parse_block_metadata_lines reader, document
      if (name_section_level = is_next_line_section? reader, {})
        if name_section_level == 1
          name_section = initialize_section reader, document, {}
          name_section_buffer = (reader.read_lines_until break_on_blank_lines: true, skip_line_comments: true).map {|l| l.lstrip }.join ' '
          if ManpageNamePurposeRx =~ name_section_buffer
            if (manname = $1).include? ATTR_REF_HEAD
              manname = document.sub_attributes manname
            end
            if manname.include? ','
              manname = (mannames = (manname.split ',').map {|n| n.lstrip })[0]
            else
              mannames = [manname]
            end
            if (manpurpose = $2).include? ATTR_REF_HEAD
              manpurpose = document.sub_attributes manpurpose
            end
            doc_attrs['manname-title'] ||= name_section.title
            doc_attrs['manname-id'] = name_section.id if name_section.id
            doc_attrs['manname'] = manname
            doc_attrs['mannames'] = mannames
            doc_attrs['manpurpose'] = manpurpose
            if document.backend == 'manpage'
              doc_attrs['docname'] = manname
              doc_attrs['outfilesuffix'] = %(.#{manvolnum})
            end
          else
            error_msg = 'non-conforming name section body'
          end
        else
          error_msg = 'name section must be at level 1'
        end
      else
        error_msg = 'name section expected'
      end
      if error_msg
        reader.restore_save
        logger.error message_with_context error_msg, source_location: reader.cursor
        doc_attrs['manname'] = manname = doc_attrs['docname'] || 'command'
        doc_attrs['mannames'] = [manname]
        if document.backend == 'manpage'
          doc_attrs['docname'] = manname
          doc_attrs['outfilesuffix'] = %(.#{manvolnum})
        end
      else
        reader.discard_save
      end
    end
    nil
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
  #   reader = Reader.new source, nil, normalize: true
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

    # check if we are at the start of processing the document
    # NOTE we could drop a hint in the attributes to indicate
    # that we are at a section title (so we don't have to check)
    if parent.context == :document && parent.blocks.empty? && ((has_header = parent.header?) ||
        (attributes.delete 'invalid-header') || !(is_next_line_section? reader, attributes))
      book = (document = parent).doctype == 'book'
      if has_header || (book && attributes[1] != 'abstract')
        preamble = intro = Block.new parent, :preamble, content_model: :compound
        preamble.title = parent.attr 'preface-title' if book && (parent.attr? 'preface-title')
        parent.blocks << preamble
      end
      section = parent
      current_level = 0
      if parent.attributes.key? 'fragment'
        expected_next_level = -1
      # small tweak to allow subsequent level-0 sections for book doctype
      elsif book
        expected_next_level, expected_next_level_alt = 1, 0
      else
        expected_next_level = 1
      end
    else
      book = (document = parent.document).doctype == 'book'
      section = initialize_section reader, parent, attributes
      # clear attributes except for title attribute, which must be carried over to next content block
      attributes = (title = attributes['title']) ? { 'title' => title } : {}
      expected_next_level = (current_level = section.level) + 1
      if current_level == 0
        part = book
      elsif current_level == 1 && section.special
        # NOTE technically preface sections are only permitted in the book doctype
        unless (sectname = section.sectname) == 'appendix' || sectname == 'preface' || sectname == 'abstract'
          expected_next_level = nil
        end
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
      parse_block_metadata_lines reader, document, attributes
      if (next_level = is_next_line_section?(reader, attributes))
        if document.attr? 'leveloffset'
          next_level += (document.attr 'leveloffset').to_i
          next_level = 0 if next_level < 0
        end
        if next_level > current_level
          if expected_next_level
            unless next_level == expected_next_level || (expected_next_level_alt && next_level == expected_next_level_alt) || expected_next_level < 0
              expected_condition = expected_next_level_alt ? %(expected levels #{expected_next_level_alt} or #{expected_next_level}) : %(expected level #{expected_next_level})
              logger.warn message_with_context %(section title out of sequence: #{expected_condition}, got level #{next_level}), source_location: reader.cursor
            end
          else
            logger.error message_with_context %(#{sectname} sections do not support nested sections), source_location: reader.cursor
          end
          new_section, attributes = next_section reader, section, attributes
          section.assign_numeral new_section
          section.blocks << new_section
        elsif next_level == 0 && section == document
          logger.error message_with_context 'level 0 sections can only be used when doctype is book', source_location: reader.cursor unless book
          new_section, attributes = next_section reader, section, attributes
          section.assign_numeral new_section
          section.blocks << new_section
        else
          # close this section (and break out of the nesting) to begin a new one
          break
        end
      else
        # just take one block or else we run the risk of overrunning section boundaries
        block_cursor = reader.cursor
        if (new_block = next_block reader, intro || section, attributes, parse_metadata: false)
          # REVIEW this may be doing too much
          if part
            if !section.blocks?
              # if this not a [partintro] open block, enclose it in a [partintro] open block
              if new_block.style != 'partintro'
                # if this is already a normal open block, simply add the partintro style
                if new_block.style == 'open' && new_block.context == :open
                  new_block.style = 'partintro'
                else
                  new_block.parent = (intro = Block.new section, :open, content_model: :compound)
                  intro.style = 'partintro'
                  section.blocks << intro
                end
              # if this is a [partintro] paragraph, convert it to a [partintro] open block w/ single paragraph
              elsif new_block.content_model == :simple
                new_block.content_model = :compound
                new_block << (Block.new new_block, :paragraph, source: new_block.lines, subs: new_block.subs)
                new_block.lines.clear
                new_block.subs.clear
              end
            elsif section.blocks.size == 1
              first_block = section.blocks[0]
              # open the [partintro] open block for appending
              if !intro && first_block.content_model == :compound
                logger.error message_with_context 'illegal block content outside of partintro block', source_location: block_cursor
              # rebuild [partintro] paragraph as an open block
              elsif first_block.content_model != :compound
                new_block.parent = (intro = Block.new section, :open, content_model: :compound)
                if first_block.style == (intro.style = 'partintro')
                  first_block.context = :paragraph
                  first_block.style = nil
                end
                section.blocks.shift
                intro << first_block
                section.blocks << intro
              end
            end
          end

          (intro || section).blocks << new_block
          attributes.clear
        end
      end

      reader.skip_blank_lines || break
    end

    if part
      unless section.blocks? && section.blocks[-1].context == :section
        logger.error message_with_context 'invalid part, must have at least one section (e.g., chapter, appendix, etc.)', source_location: reader.cursor
      end
    # NOTE we could try to avoid creating a preamble in the first place, though
    # that would require reworking assumptions in next_section since the preamble
    # is treated like an untitled section
    elsif preamble # implies parent == document
      if preamble.blocks?
        if book || document.blocks[1] || !Compliance.unwrap_standalone_preamble
          preamble.source_location = preamble.blocks[0].source_location if document.sourcemap
        # unwrap standalone preamble (i.e., document has no sections) except for books, if permissible
        else
          document.blocks.shift
          while (child_block = preamble.blocks.shift)
            document << child_block
          end
        end
      # drop the preamble if it has no content
      else
        document.blocks.shift
      end
    end

    # The attributes returned here are orphaned attributes that fall at the end
    # of a section that need to get transferred to the next section
    # see "trailing block attributes transfer to the following section" in
    # test/attributes_test.rb for an example
    [section == parent ? nil : section, attributes.merge]
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
  #              * :text_only indicates that the parser is only looking for text content
  #              * :list_type indicates this block will be attached to a list item in a list of the specified type
  #
  # Returns a Block object built from the parsed content of the processed
  # lines, or nothing if no block is found.
  def self.next_block(reader, parent, attributes = {}, options = {})
    # skip ahead to the block content; bail if we've reached the end of the reader
    return unless (skipped = reader.skip_blank_lines)

    # check for option to find list item text only
    # if skipped a line, assume a list continuation was
    # used and block content is acceptable
    if (text_only = options[:text_only]) && skipped > 0
      options.delete :text_only
      text_only = nil
    end

    document = parent.document

    if options.fetch :parse_metadata, true
      # read lines until there are no more metadata lines to read; note that :text_only option impacts parsing rules
      while parse_block_metadata_line reader, document, attributes, options
        # discard the line just processed
        reader.shift
        # QUESTION should we clear the attributes? no known cases when it's necessary
        reader.skip_blank_lines || return
      end
    end

    if (extensions = document.extensions)
      block_extensions, block_macro_extensions = extensions.blocks?, extensions.block_macros?
    end

    # QUESTION should we introduce a parsing context object?
    reader.mark
    this_line, doc_attrs, style = reader.read_line, document.attributes, attributes[1]
    block = block_context = cloaked_context = terminator = nil

    if (delimited_block = is_delimited_block? this_line, true)
      block_context = cloaked_context = delimited_block.context
      terminator = delimited_block.terminator
      if style
        unless style == block_context.to_s
          if delimited_block.masq.include? style
            block_context = style.to_sym
          elsif delimited_block.masq.include?('admonition') && ADMONITION_STYLES.include?(style)
            block_context = :admonition
          elsif block_extensions && extensions.registered_for_block?(style, block_context)
            block_context = style.to_sym
          else
            logger.debug message_with_context %(unknown style for #{block_context} block: #{style}), source_location: reader.cursor_at_mark if logger.debug?
            style = block_context.to_s
          end
        end
      else
        style = attributes['style'] = block_context.to_s
      end
    end

    # this loop is used for flow control; it only executes once, and only when delimited_block is not set
    # break once a block is found or at end of loop
    # returns nil if the line should be dropped
    while true
      # process lines verbatim
      if style && Compliance.strict_verbatim_paragraphs && (VERBATIM_STYLES.include? style)
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
            block = Block.new(parent, :thematic_break, content_model: :empty)
            break
          end
        elsif this_line.start_with? TAB
          indented, ch0 = true, TAB
        else
          indented, ch0 = false, this_line.chr
          layout_break_chars = md_syntax ? HYBRID_LAYOUT_BREAK_CHARS : LAYOUT_BREAK_CHARS
          if (layout_break_chars.key? ch0) &&
              (md_syntax ? (ExtLayoutBreakRx.match? this_line) : (uniform? this_line, ch0, (ll = this_line.length)) && ll > 2)
            # NOTE we're letting break lines (horizontal rule, page_break, etc) have attributes
            block = Block.new(parent, layout_break_chars[ch0], content_model: :empty)
            break
          # NOTE very rare that a text-only line will end in ] (e.g., inline macro), so check that first
          elsif (this_line.end_with? ']') && (this_line.include? '::')
            #if (this_line.start_with? 'image', 'video', 'audio') && BlockMediaMacroRx =~ this_line
            if (ch0 == 'i' || (this_line.start_with? 'video:', 'audio:')) && BlockMediaMacroRx =~ this_line
              blk_ctx, target, blk_attrs = $1.to_sym, $2, $3
              block = Block.new parent, blk_ctx, content_model: :empty
              if blk_attrs
                case blk_ctx
                when :video
                  posattrs = ['poster', 'width', 'height']
                when :audio
                  posattrs = []
                else # :image
                  posattrs = ['alt', 'width', 'height']
                end
                block.parse_attributes blk_attrs, posattrs, sub_input: true, into: attributes
              end
              # style doesn't have special meaning for media macros
              attributes.delete 'style' if attributes.key? 'style'
              if target.include? ATTR_REF_HEAD
                if (expanded_target = block.sub_attributes target).empty? &&
                    (doc_attrs['attribute-missing'] || Compliance.attribute_missing) == 'drop-line' &&
                    (block.sub_attributes target + ' ', attribute_missing: 'drop-line', drop_line_severity: :ignore).empty?
                  attributes.clear
                  return
                else
                  target = expanded_target
                end
              end
              if blk_ctx == :image
                document.register :images, target
                attributes['imagesdir'] = doc_attrs['imagesdir']
                # NOTE style is the value of the first positional attribute in the block attribute line
                attributes['alt'] ||= style || (attributes['default-alt'] = Helpers.basename(target, true).tr('_-', ' '))
                unless (scaledwidth = attributes.delete 'scaledwidth').nil_or_empty?
                  # NOTE assume % units if not specified
                  attributes['scaledwidth'] = (TrailingDigitsRx.match? scaledwidth) ? %(#{scaledwidth}%) : scaledwidth
                end
                if attributes['title']
                  block.title = block_title = attributes.delete 'title'
                  block.assign_caption (attributes.delete 'caption'), 'figure'
                end
              end
              attributes['target'] = target
              break

            elsif ch0 == 't' && (this_line.start_with? 'toc:') && BlockTocMacroRx =~ this_line
              block = Block.new parent, :toc, content_model: :empty
              block.parse_attributes $1, [], into: attributes if $1
              break

            elsif block_macro_extensions ? (CustomBlockMacroRx =~ this_line &&
                (extension = extensions.registered_for_block_macro? $1) || (report_unknown_block_macro = logger.debug?)) :
                (logger.debug? && (report_unknown_block_macro = CustomBlockMacroRx =~ this_line))
              if report_unknown_block_macro
                logger.debug message_with_context %(unknown name for block macro: #{$1}), source_location: reader.cursor_at_mark
              else
                content = $3
                if (target = $2).include? ATTR_REF_HEAD
                  if (expanded_target = parent.sub_attributes target).empty? &&
                      (doc_attrs['attribute-missing'] || Compliance.attribute_missing) == 'drop-line' &&
                      (parent.sub_attributes target + ' ', attribute_missing: 'drop-line', drop_line_severity: :ignore).empty?
                    attributes.clear
                    return
                  else
                    target = expanded_target
                  end
                end
                if (ext_config = extension.config)[:content_model] == :attributes
                  document.parse_attributes content, ext_config[:positional_attrs] || ext_config[:pos_attrs] || [], sub_input: true, into: attributes if content
                else
                  attributes['text'] = content || ''
                end
                if (default_attrs = ext_config[:default_attrs])
                  attributes.update(default_attrs) {|_, old_v| old_v }
                end
                if (block = extension.process_method[parent, target, attributes]) && block != parent
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
      end

      # haven't found anything yet, continue
      if !indented && (ch0 ||= this_line.chr) == '<' && CalloutListRx =~ this_line
        reader.unshift_line this_line
        block = parse_callout_list(reader, $~, parent, document.callouts)
        attributes['style'] = 'arabic'
        break

      elsif UnorderedListRx.match? this_line
        reader.unshift_line this_line
        attributes['style'] = style = 'bibliography' if !style && Section === parent && parent.sectname == 'bibliography'
        block = parse_list(reader, :ulist, parent, style)
        break

      elsif OrderedListRx.match? this_line
        reader.unshift_line this_line
        block = parse_list(reader, :olist, parent, style)
        attributes['style'] = block.style if block.style
        break

      elsif ((this_line.include? '::') || (this_line.include? ';;')) && DescriptionListRx =~ this_line
        reader.unshift_line this_line
        block = parse_description_list(reader, $~, parent)
        break

      elsif (style == 'float' || style == 'discrete') && (Compliance.underline_style_section_titles ?
          (is_section_title? this_line, reader.peek_line) : !indented && (atx_section_title? this_line))
        reader.unshift_line this_line
        float_id, float_reftext, block_title, float_level = parse_section_title reader, document, attributes['id']
        attributes['reftext'] = float_reftext if float_reftext
        block = Block.new(parent, :floating_title, content_model: :empty)
        block.title = block_title
        attributes.delete 'title'
        block.id = float_id || ((doc_attrs.key? 'sectids') ? (Section.generate_id block.title, document) : nil)
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
          logger.debug message_with_context %(unknown style for paragraph: #{style}), source_location: reader.cursor_at_mark if logger.debug?
          style = nil
          # continue to process paragraph
        end
      end

      reader.unshift_line this_line

      # a literal paragraph: contiguous lines starting with at least one whitespace character
      # NOTE style can only be nil or "normal" at this point
      if indented && !style
        lines = read_paragraph_lines reader, (content_adjacent = skipped == 0 ? options[:list_type] : nil), skip_line_comments: text_only
        adjust_indentation! lines
        if text_only || content_adjacent == :dlist
          # this block gets folded into the list item text
          block = Block.new(parent, :paragraph, content_model: :simple, source: lines, attributes: attributes)
        else
          block = Block.new(parent, :literal, content_model: :verbatim, source: lines, attributes: attributes)
        end
      # a normal paragraph: contiguous non-blank/non-continuation lines (left-indented or normal style)
      else
        lines = read_paragraph_lines reader, skipped == 0 && options[:list_type], skip_line_comments: true
        # NOTE don't check indented here since it's extremely rare
        #if text_only || indented
        if text_only
          # if [normal] is used over an indented paragraph, shift content to left margin
          # QUESTION do we even need to shift since whitespace is normalized by XML in this case?
          adjust_indentation! lines if indented && style == 'normal'
          block = Block.new(parent, :paragraph, content_model: :simple, source: lines, attributes: attributes)
        elsif (ADMONITION_STYLE_HEADS.include? ch0) && (this_line.include? ':') && (AdmonitionParagraphRx =~ this_line)
          lines[0] = $' # string after match
          attributes['name'] = admonition_name = (attributes['style'] = $1).downcase
          attributes['textlabel'] = (attributes.delete 'caption') || doc_attrs[%(#{admonition_name}-caption)]
          block = Block.new(parent, :admonition, content_model: :simple, source: lines, attributes: attributes)
        elsif md_syntax && ch0 == '>' && this_line.start_with?('> ')
          lines.map! {|line| line == '>' ? (line.slice 1, line.length) : ((line.start_with? '> ') ? (line.slice 2, line.length) : line) }
          if lines[-1].start_with? '-- '
            credit_line = (credit_line = lines.pop).slice 3, credit_line.length
            unless lines.empty?
              lines.pop while lines[-1].empty?
            end
          end
          attributes['style'] = 'quote'
          # NOTE will only detect discrete (aka free-floating) headings
          # TODO could assume a discrete heading when inside a block context
          # FIXME Reader needs to be created w/ line info
          block = build_block(:quote, :compound, false, parent, Reader.new(lines), attributes)
          if credit_line
            attribution, citetitle = (block.apply_subs credit_line).split ', ', 2
            attributes['attribution'] = attribution if attribution
            attributes['citetitle'] = citetitle if citetitle
          end
        elsif ch0 == '"' && lines.size > 1 && (lines[-1].start_with? '-- ') && (lines[-2].end_with? '"')
          lines[0] = this_line.slice 1, this_line.length # strip leading quote
          credit_line = (credit_line = lines.pop).slice 3, credit_line.length
          lines.pop while lines[-1].empty?
          lines << lines.pop.chop # strip trailing quote
          attributes['style'] = 'quote'
          block = Block.new(parent, :quote, content_model: :simple, source: lines, attributes: attributes)
          attribution, citetitle = (block.apply_subs credit_line).split ', ', 2
          attributes['attribution'] = attribution if attribution
          attributes['citetitle'] = citetitle if citetitle
        else
          # if [normal] is used over an indented paragraph, shift content to left margin
          # QUESTION do we even need to shift since whitespace is normalized by XML in this case?
          adjust_indentation! lines if indented && style == 'normal'
          block = Block.new(parent, :paragraph, content_model: :simple, source: lines, attributes: attributes)
        end

        catalog_inline_anchors((lines.join LF), block, document, reader)
      end

      break # forbid loop from executing more than once
    end unless delimited_block

    # either delimited block or styled paragraph
    unless block
      case block_context
      when :listing, :source
        if block_context == :source || (!attributes[1] && (language = attributes[2] || doc_attrs['source-language']))
          if language
            attributes['style'] = 'source'
            attributes['language'] = language
            AttributeList.rekey attributes, [nil, nil, 'linenums']
          else
            AttributeList.rekey attributes, [nil, 'language', 'linenums']
            if doc_attrs.key? 'source-language'
              attributes['language'] = doc_attrs['source-language']
            end unless attributes.key? 'language'
          end
          if attributes['linenums-option'] || doc_attrs['source-linenums-option']
            attributes['linenums'] = ''
          end unless attributes.key? 'linenums'
          if doc_attrs.key? 'source-indent'
            attributes['indent'] = doc_attrs['source-indent']
          end unless attributes.key? 'indent'
        end
        block = build_block(:listing, :verbatim, terminator, parent, reader, attributes)
      when :fenced_code
        attributes['style'] = 'source'
        if (ll = this_line.length) > 3
          if (comma_idx = (language = this_line.slice 3, ll).index ',')
            if comma_idx > 0
              language = (language.slice 0, comma_idx).strip
              attributes['linenums'] = '' if comma_idx < ll - 4
            elsif ll > 4
              attributes['linenums'] = ''
            end
          else
            language = language.lstrip
          end
        end
        if language.nil_or_empty?
          attributes['language'] = doc_attrs['source-language'] if doc_attrs.key? 'source-language'
        else
          attributes['language'] = language
        end
        if attributes['linenums-option'] || doc_attrs['source-linenums-option']
          attributes['linenums'] = ''
        end unless attributes.key? 'linenums'
        if doc_attrs.key? 'source-indent'
          attributes['indent'] = doc_attrs['source-indent']
        end unless attributes.key? 'indent'
        terminator = terminator.slice 0, 3
        block = build_block(:listing, :verbatim, terminator, parent, reader, attributes)
      when :table
        block_cursor = reader.cursor
        block_reader = Reader.new reader.read_lines_until(terminator: terminator, skip_line_comments: true, context: :table, cursor: :at_mark), block_cursor
        # NOTE it's very rare that format is set when using a format hint char, so short-circuit
        unless terminator.start_with? '|', '!'
          # NOTE infer dsv once all other format hint chars are ruled out
          attributes['format'] ||= (terminator.start_with? ',') ? 'csv' : 'dsv'
        end
        block = parse_table(block_reader, parent, attributes)
      when :sidebar
        block = build_block(block_context, :compound, terminator, parent, reader, attributes)
      when :admonition
        attributes['name'] = admonition_name = style.downcase
        attributes['textlabel'] = (attributes.delete 'caption') || doc_attrs[%(#{admonition_name}-caption)]
        block = build_block(block_context, :compound, terminator, parent, reader, attributes)
      when :open, :abstract, :partintro
        block = build_block(:open, :compound, terminator, parent, reader, attributes)
      when :literal
        block = build_block(block_context, :verbatim, terminator, parent, reader, attributes)
      when :example
        attributes['caption'] = '' if attributes['collapsible-option']
        block = build_block(block_context, :compound, terminator, parent, reader, attributes)
      when :quote, :verse
        AttributeList.rekey(attributes, [nil, 'attribution', 'citetitle'])
        block = build_block(block_context, (block_context == :verse ? :verbatim : :compound), terminator, parent, reader, attributes)
      when :stem, :latexmath, :asciimath
        attributes['style'] = STEM_TYPE_ALIASES[attributes[2] || doc_attrs['stem']] if block_context == :stem
        block = build_block(:stem, :raw, terminator, parent, reader, attributes)
      when :pass
        block = build_block(block_context, :raw, terminator, parent, reader, attributes)
      when :comment
        build_block(block_context, :skip, terminator, parent, reader, attributes)
        attributes.clear
        return
      else
        if block_extensions && (extension = extensions.registered_for_block? block_context, cloaked_context)
          unless (content_model = (ext_config = extension.config)[:content_model]) == :skip
            unless (positional_attrs = ext_config[:positional_attrs] || ext_config[:pos_attrs]).nil_or_empty?
              AttributeList.rekey(attributes, [nil] + positional_attrs)
            end
            if (default_attrs = ext_config[:default_attrs])
              default_attrs.each {|k, v| attributes[k] ||= v }
            end
            # QUESTION should we clone the extension for each cloaked context and set in config?
            attributes['cloaked-context'] = cloaked_context
          end
          unless (block = build_block block_context, content_model, terminator, parent, reader, attributes, extension: extension)
            attributes.clear
            return
          end
        else
          # this should only happen if there's a misconfiguration
          raise %(Unsupported block type #{block_context} at #{reader.cursor})
        end
      end
    end

    # FIXME we've got to clean this up, it's horrible!
    block.source_location = reader.cursor_at_mark if document.sourcemap
    # FIXME title and caption should be assigned when block is constructed (though we need to handle all cases)
    if attributes['title']
      block.title = block_title = attributes.delete 'title'
      block.assign_caption attributes.delete 'caption' if CAPTION_ATTRIBUTE_NAMES[block.context]
    end
    # TODO eventually remove the style attribute from the attributes hash
    #block.style = attributes.delete 'style'
    block.style = attributes['style']
    if (block_id = block.id || (block.id = attributes['id']))
      # convert title to resolve attributes while in scope
      block.title if block_title ? (block_title.include? ATTR_REF_HEAD) : block.title?
      unless document.register :refs, [block_id, block]
        logger.warn message_with_context %(id assigned to block already in use: #{block_id}), source_location: reader.cursor_at_mark
      end
    end
    # FIXME remove the need for this update!
    block.update_attributes attributes unless attributes.empty?
    block.commit_subs

    #if doc_attrs.key? :pending_attribute_entries
    #  doc_attrs.delete(:pending_attribute_entries).each do |entry|
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

  # Public: Determines whether this line is the start of a known delimited block.
  #
  # Returns the BlockMatchData (if return_match_data is true) or true (if return_match_data is false) if this line is
  # the start of a delimited block, otherwise nothing.
  def self.is_delimited_block? line, return_match_data = nil
    # highly optimized for best performance
    return unless (line_len = line.length) > 1 && DELIMITED_BLOCK_HEADS[line.slice 0, 2]
    # open block
    if line_len == 2
      tip = line
      tip_len = 2
    else
      # all other delimited blocks, including fenced code
      if line_len < 5
        tip = line
        tip_len = line_len
      else
        tip = line.slice 0, (tip_len = 4)
      end
      # special case for fenced code blocks
      if Compliance.markdown_syntax && (tip.start_with? '`')
        if tip_len == 4
          if tip == '````' || (tip = tip.chop) != '```'
            return
          end
          line = tip
          line_len = tip_len = 3
        elsif tip != '```'
          return
        end
      elsif tip_len == 3
        return
      end
    end
    # NOTE line matches the tip when delimiter is minimum length or fenced code
    context, masq = DELIMITED_BLOCKS[tip]
    if context && (line_len == tip_len || (uniform? (line.slice 1, line_len), DELIMITED_BLOCK_TAILS[tip], (line_len - 1)))
      return_match_data ? (BlockMatchData.new context, masq, tip, line) : true
    end
  end

  # whether a block supports compound content should be a config setting
  # if terminator is false, that means the all the lines in the reader should be parsed
  # NOTE could invoke filter in here, before and after parsing
  def self.build_block(block_context, content_model, terminator, parent, reader, attributes, options = {})
    case content_model
    when :skip
      skip_processing, parse_as_content_model = true, :simple
    when :raw
      skip_processing, parse_as_content_model = false, :simple
    else
      skip_processing, parse_as_content_model = false, content_model
    end

    if terminator.nil?
      if parse_as_content_model == :verbatim
        lines = reader.read_lines_until break_on_blank_lines: true, break_on_list_continuation: true
      else
        content_model = :simple if content_model == :compound
        # TODO we could also skip processing if we're able to detect reader is a BlockReader
        lines = read_paragraph_lines reader, false, skip_line_comments: true, skip_processing: skip_processing
        # QUESTION check for empty lines after grabbing lines for simple content model?
      end
      block_reader = nil
    elsif parse_as_content_model != :compound
      lines = reader.read_lines_until terminator: terminator, skip_processing: skip_processing, context: block_context, cursor: :at_mark
      block_reader = nil
    # terminator is false when reader has already been prepared
    elsif terminator == false
      lines = nil
      block_reader = reader
    else
      lines = nil
      block_cursor = reader.cursor
      block_reader = Reader.new reader.read_lines_until(terminator: terminator, skip_processing: skip_processing, context: block_context, cursor: :at_mark), block_cursor
    end

    case content_model
    when :verbatim
      tab_size = (attributes['tabsize'] || parent.document.attributes['tabsize']).to_i
      if (indent = attributes['indent'])
        adjust_indentation! lines, indent.to_i, tab_size
      elsif tab_size > 0
        adjust_indentation! lines, -1, tab_size
      end
    when :skip
      # QUESTION should we still invoke process method if extension is specified?
      return
    end

    if (extension = options[:extension])
      # QUESTION do we want to delete the style?
      attributes.delete('style')
      if (block = extension.process_method[parent, block_reader || (Reader.new lines), attributes.merge]) && block != parent
        attributes.replace block.attributes
        # NOTE an extension can change the content model from :simple to :compound. It's up to the extension
        # to decide which one to use. The extension can consult the cloaked-context attribute to determine
        # if the input is a paragraph or delimited block.
        if block.content_model == :compound && Block === block && !(lines = block.lines).empty?
          content_model = :compound
          block_reader = Reader.new lines
        end
      else
        return
      end
    else
      block = Block.new(parent, block_context, content_model: content_model, source: lines, attributes: attributes)
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
  def self.parse_blocks(reader, parent, attributes = nil)
    if attributes
      while ((block = next_block reader, parent, attributes.merge) && parent.blocks << block) || reader.has_more_lines?; end
    else
      while ((block = next_block reader, parent) && parent.blocks << block) || reader.has_more_lines?; end
    end
    nil
  end

  # Internal: Parse and construct an ordered or unordered list at the current position of the Reader
  #
  # reader    - The Reader from which to retrieve the list
  # list_type - A Symbol representing the list type (:olist for ordered, :ulist for unordered)
  # parent    - The parent Block to which this list belongs
  # style     - The block style assigned to this list (optional, default: nil)
  #
  # Returns the Block encapsulating the parsed unordered or ordered list
  def self.parse_list reader, list_type, parent, style
    list_block = List.new parent, list_type
    list_rx = ListRxMap[list_type]

    while reader.has_more_lines? && list_rx =~ reader.peek_line
      # NOTE parse_list_item will stop at sibling item or end of list; never sees ancestor items
      if (list_item = parse_list_item reader, list_block, $~, $1, style)
        list_block.items << list_item
      end

      reader.skip_blank_lines || break
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
    autonum = 0
    text.scan CalloutScanRx do
      document.callouts.register $2 == '.' ? (autonum += 1).to_s : $2 unless $&.start_with? '\\'
      # we have to mark as found even if it's escaped so it can be unescaped
      found = true
    end if text.include? '<'
    found
  end

  # Internal: Catalog a matched inline anchor.
  #
  # id       - The String id of the anchor
  # reftext  - The optional String reference text of the anchor
  # node     - The AbstractNode parent node of the anchor node
  # location - The source location (file and line) where the anchor was found
  # doc      - The document to which the node belongs; computed from node if not specified
  #
  # Returns nothing
  def self.catalog_inline_anchor id, reftext, node, location, doc = node.document
    reftext = doc.sub_attributes reftext if reftext && (reftext.include? ATTR_REF_HEAD)
    unless doc.register :refs, [id, (Inline.new node, :anchor, reftext, type: :ref, id: id)]
      location = location.cursor if Reader === location
      logger.warn message_with_context %(id assigned to anchor already in use: #{id}), source_location: location
    end
    nil
  end

  # Internal: Catalog any inline anchors found in the text (but don't convert)
  #
  # text     - The String text in which to look for inline anchors
  # block    - The block in which the references should be searched
  # document - The current Document on which the references are stored
  #
  # Returns nothing
  def self.catalog_inline_anchors text, block, document, reader
    text.scan InlineAnchorScanRx do
      if (id = $1)
        next if (reftext = $2) && (reftext.include? ATTR_REF_HEAD) && (reftext = document.sub_attributes reftext).empty?
      else
        id = $3
        if (reftext = $4)
          if reftext.include? ']'
            reftext = reftext.gsub '\]', ']'
            reftext = document.sub_attributes reftext if reftext.include? ATTR_REF_HEAD
          elsif reftext.include? ATTR_REF_HEAD
            reftext = nil if (reftext = document.sub_attributes reftext).empty?
          end
        end
      end
      unless document.register :refs, [id, (Inline.new block, :anchor, reftext, type: :ref, id: id)]
        location = reader.cursor_at_mark
        if (offset = ($`.count LF) + (($&.start_with? LF) ? 1 : 0)) > 0
          (location = location.dup).advance offset
        end
        logger.warn message_with_context %(id assigned to anchor already in use: #{id}), source_location: location
      end
    end if (text.include? '[[') || (text.include? 'or:')
    nil
  end

  # Internal: Catalog the bibliography inline anchor found in the start of the list item (but don't convert)
  #
  # id      - The String id of the anchor
  # reftext - The optional String reference text of the anchor
  # node    - The AbstractNode parent node of the anchor node
  # reader  - The source Reader for the current Document, positioned at the current list item
  #
  # Returns nothing
  def self.catalog_inline_biblio_anchor id, reftext, node, reader
    # QUESTION should we sub attributes in reftext (like with regular anchors)?
    unless node.document.register :refs, [id, (Inline.new node, :anchor, reftext && %([#{reftext}]), type: :bibref, id: id)]
      logger.warn message_with_context %(id assigned to bibliography anchor already in use: #{id}), source_location: reader.cursor
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
  def self.parse_description_list reader, match, parent
    list_block = List.new parent, :dlist
    # detects a description list item that uses the same delimiter (::, :::, :::: or ;;)
    sibling_pattern = DescriptionListSiblingRx[match[2]]
    list_block.items << (current_pair = parse_list_item reader, list_block, match, sibling_pattern)

    while reader.has_more_lines? && sibling_pattern =~ reader.peek_line
      next_pair = parse_list_item reader, list_block, $~, sibling_pattern
      if current_pair[1]
        list_block.items << (current_pair = next_pair)
      else
        current_pair[0] << next_pair[0][0]
        current_pair[1] = next_pair[1]
      end
    end

    list_block
  end

  # Internal: Parse and construct a callout list Block from the current position of the Reader and
  # advance the document callouts catalog to the next list.
  #
  # reader   - The Reader from which to retrieve the callout list.
  # match    - The Regexp match containing the head of the list.
  # parent   - The parent Block to which this callout list belongs.
  # callouts - The document callouts catalog.
  #
  # Returns the Block that represents the parsed callout list.
  def self.parse_callout_list reader, match, parent, callouts
    list_block = List.new(parent, :colist)
    next_index = 1
    autonum = 0
    # NOTE skip the match on the first time through as we've already done it (emulates begin...while)
    while match || ((match = CalloutListRx.match reader.peek_line) && reader.mark)
      if (num = match[1]) == '.'
        num = (autonum += 1).to_s
      end
      # might want to move this check to a validate method
      unless num == next_index.to_s
        logger.warn message_with_context %(callout list item index: expected #{next_index}, got #{num}), source_location: reader.cursor_at_mark
      end
      if (list_item = parse_list_item reader, list_block, match, '<1>')
        list_block.items << list_item
        if (coids = callouts.callout_ids list_block.items.size).empty?
          logger.warn message_with_context %(no callout found for <#{list_block.items.size}>), source_location: reader.cursor_at_mark
        else
          list_item.attributes['coids'] = coids
        end
      end
      next_index += 1
      match = nil
    end

    callouts.next_list
    list_block
  end

  # Internal: Parse and construct the next ListItem (unordered, ordered, or callout list) or next
  # term ListItem and description ListItem pair (description list) for the specified list Block.
  #
  # First, collect and process all the lines that constitute the next list item for the specified
  # list (according to its type). Next, create a ListItem (in the case of a description list, a
  # description ListItem), parse the lines into blocks, and associate those blocks with that
  # ListItem. Finally, fold the first block into the item's text attribute according to rules
  # described in ListItem.
  #
  # reader        - The Reader from which to retrieve the next list item
  # list_block    - The parent list Block for this ListItem. Also provides access to the list type.
  # match         - The MatchData that contains the list item marker and first line text of the ListItem
  # sibling_trait - The trait to match a sibling list item. For ordered and unordered lists, this is
  #                 a String marker (e.g., '**' or 'ii)'). For description lists, this is a Regexp
  #                 marker pattern.
  # style         - The block style assigned to this list (optional, default: nil)
  #
  # Returns the next ListItem or [[ListItem], ListItem] pair (description list) for the parent list Block.
  def self.parse_list_item(reader, list_block, match, sibling_trait, style = nil)
    if (list_type = list_block.context) == :dlist
      dlist = true
      list_term = ListItem.new(list_block, (term_text = match[1]))
      if term_text.start_with?('[[') && LeadingInlineAnchorRx =~ term_text
        catalog_inline_anchor $1, ($2 || $'.lstrip), list_term, reader
      end
      has_text = true if (item_text = match[3])
      list_item = ListItem.new(list_block, item_text)
      if list_block.document.sourcemap
        list_term.source_location = reader.cursor
        if has_text
          list_item.source_location = list_term.source_location
        else
          sourcemap_assignment_deferred = true
        end
      end
    else
      has_text = true
      list_item = ListItem.new(list_block, (item_text = match[2]))
      list_item.source_location = reader.cursor if list_block.document.sourcemap
      case list_type
      when :ulist
        list_item.marker = sibling_trait
        if item_text.start_with?('[')
          if style && style == 'bibliography'
            if InlineBiblioAnchorRx =~ item_text
              catalog_inline_biblio_anchor $1, $2, list_item, reader
            end
          elsif item_text.start_with?('[[')
            if LeadingInlineAnchorRx =~ item_text
              catalog_inline_anchor $1, $2, list_item, reader
            end
          elsif item_text.start_with?('[ ] ', '[x] ', '[*] ')
            list_block.set_option 'checklist'
            list_item.attributes['checkbox'] = ''
            list_item.attributes['checked'] = '' unless item_text.start_with? '[ '
            list_item.text = item_text.slice(4, item_text.length)
          end
        end
      when :olist
        sibling_trait, implicit_style = resolve_ordered_list_marker(sibling_trait, (ordinal = list_block.items.size), true, reader)
        list_item.marker = sibling_trait
        if ordinal == 0 && !style
          # using list level makes more sense, but we don't track it
          # basing style on marker level is compliant with AsciiDoc.py
          list_block.style = implicit_style || (ORDERED_LIST_STYLES[sibling_trait.length - 1] || 'arabic').to_s
        end
        if item_text.start_with?('[[') && LeadingInlineAnchorRx =~ item_text
          catalog_inline_anchor $1, $2, list_item, reader
        end
      else # :colist
        list_item.marker = sibling_trait
        if item_text.start_with?('[[') && LeadingInlineAnchorRx =~ item_text
          catalog_inline_anchor $1, $2, list_item, reader
        end
      end
    end

    # first skip the line with the marker / term (it gets put back onto the reader by next_block)
    reader.shift
    block_cursor = reader.cursor
    list_item_reader = Reader.new read_lines_for_list_item(reader, list_type, sibling_trait, has_text), block_cursor
    if list_item_reader.has_more_lines?
      list_item.source_location = block_cursor if sourcemap_assignment_deferred
      # NOTE peek on the other side of any comment lines
      comment_lines = list_item_reader.skip_line_comments
      if (subsequent_line = list_item_reader.peek_line)
        list_item_reader.unshift_lines comment_lines unless comment_lines.empty?
        unless subsequent_line.empty?
          content_adjacent = true
          # treat lines as paragraph text if continuation does not connect first block (i.e., has_text = nil)
          has_text = nil unless dlist
        end
      end

      # reader is confined to boundaries of list, which means only blocks will be found (no sections)
      if (block = next_block(list_item_reader, list_item, {}, text_only: has_text ? nil : true, list_type: list_type))
        list_item.blocks << block
      end

      while list_item_reader.has_more_lines?
        if (block = next_block(list_item_reader, list_item, {}, list_type: list_type))
          list_item.blocks << block
        end
      end

      list_item.fold_first if content_adjacent && (first_block = list_item.blocks[0]) && first_block.context == :paragraph
    end

    dlist ? [[list_term], (list_item.text? || list_item.blocks? ? list_item : nil)] : list_item
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

    dlist = list_type == :dlist

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
      if (match = is_delimited_block? this_line, true)
        break unless continuation == :active
        buffer << this_line
        # grab all the lines in the block, leaving the delimiters in place
        # we're being more strict here about the terminator, but I think that's a good thing
        buffer.concat reader.read_lines_until terminator: match.terminator, read_last_line: true, context: nil
        continuation = :inactive
      # BlockAttributeLineRx only breaks dlist if ensuing line is not a list item
      elsif dlist && continuation != :active && (this_line.start_with? '[') && (BlockAttributeLineRx.match? this_line)
        block_attribute_lines = [this_line]
        while (next_line = reader.peek_line)
          if is_delimited_block? next_line
            interrupt = true
          elsif next_line.empty? || ((next_line.start_with? '[') && (BlockAttributeLineRx.match? next_line))
            block_attribute_lines << reader.read_line
            next
          elsif (AnyListRx.match? next_line) && !(is_sibling_list_item? next_line, list_type, sibling_trait)
            buffer.concat block_attribute_lines
          else # rubocop:disable Lint/DuplicateBranch
            interrupt = true
          end
          break
        end
        if interrupt
          reader.unshift_lines block_attribute_lines
          break
        end
      elsif continuation == :active && !this_line.empty?
        # literal paragraphs have special considerations (and this is one of
        # two entry points into one)
        # if we don't process it as a whole, then a line in it that looks like a
        # list item will throw off the exit from it
        if LiteralParagraphRx.match? this_line
          reader.unshift_line this_line
          if dlist
            # we may be in an indented list disguised as a literal paragraph
            # so we need to make sure we don't slurp up a legitimate sibling
            buffer.concat reader.read_lines_until(preserve_last_line: true, break_on_blank_lines: true, break_on_list_continuation: true) {|line| is_sibling_list_item? line, list_type, sibling_trait }
          else
            buffer.concat reader.read_lines_until(preserve_last_line: true, break_on_blank_lines: true, break_on_list_continuation: true)
          end
          continuation = :inactive
        # let block metadata play out until we find the block
        elsif ((ch0 = this_line.chr) == '.' && (BlockTitleRx.match? this_line)) ||
            (ch0 == '[' && (BlockAttributeLineRx.match? this_line)) || (ch0 == ':' && (AttributeEntryRx.match? this_line))
          buffer << this_line
        else
          if (nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).find {|ctx| ListRxMap[ctx].match? this_line })
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
          # stop reading if we reach eof
          break unless (this_line = reader.skip_blank_lines && reader.read_line)
          # stop reading if we hit a sibling list item
          break if is_sibling_list_item? this_line, list_type, sibling_trait
        end

        if this_line == LIST_CONTINUATION
          detached_continuation = buffer.size
          buffer << this_line
        elsif has_text # has_text only relevant for dlist, which is more greedy until it has text for an item; has_text is always true for all other lists
          # in this block, we have to see whether we stay in the list
          # TODO any way to combine this with the check after skipping blank lines?
          if is_sibling_list_item?(this_line, list_type, sibling_trait)
            break
          elsif (nested_list_type = NESTABLE_LIST_CONTEXTS.find {|ctx| ListRxMap[ctx] =~ this_line })
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
            if dlist
              # we may be in an indented list disguised as a literal paragraph
              # so we need to make sure we don't slurp up a legitimate sibling
              buffer.concat reader.read_lines_until(preserve_last_line: true, break_on_blank_lines: true, break_on_list_continuation: true) {|line| is_sibling_list_item? line, list_type, sibling_trait }
            else
              buffer.concat reader.read_lines_until(preserve_last_line: true, break_on_blank_lines: true, break_on_list_continuation: true)
            end
          else
            break
          end
        else # only dlist in need of item text, so slurp it up!
          # pop the blank line so it's not interpreted as a list continuation
          buffer.pop unless within_nested_list
          buffer << this_line
          has_text = true
        end
      else
        has_text = true unless this_line.empty?
        if (nested_list_type = (within_nested_list ? [:dlist] : NESTABLE_LIST_CONTEXTS).find {|ctx| ListRxMap[ctx] =~ this_line })
          within_nested_list = true
          if nested_list_type == :dlist && $3.nil_or_empty?
            # get greedy again
            has_text = false
          end
        end
        buffer << this_line
      end
      this_line = nil
    end

    reader.unshift_line this_line if this_line

    buffer[detached_continuation] = '' if detached_continuation

    until buffer.empty?
      # strip trailing blank lines to prevent empty blocks
      if (last_line = buffer[-1]).empty?
        buffer.pop
      else
        # drop optional trailing continuation
        # (a blank line would have served the same purpose in the document)
        buffer.pop if last_line == LIST_CONTINUATION
        break
      end
    end

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
  #
  # Returns the section [Block]
  def self.initialize_section reader, parent, attributes = {}
    document = parent.document
    book = (doctype = document.doctype) == 'book'
    source_location = reader.cursor if document.sourcemap
    sect_style = attributes[1]
    sect_id, sect_reftext, sect_title, sect_level, sect_atx = parse_section_title reader, document, attributes['id']

    if sect_style
      if book && sect_style == 'abstract'
        sect_name, sect_level = 'chapter', 1
      elsif (sect_style.start_with? 'sect') && (SectionLevelStyleRx.match? sect_style)
        sect_name = 'section'
      else
        sect_name, sect_special = sect_style, true
        sect_level = 1 if sect_level == 0
        sect_numbered = sect_name == 'appendix'
      end
    elsif book
      sect_name = sect_level == 0 ? 'part' : (sect_level > 1 ? 'section' : 'chapter')
    elsif doctype == 'manpage' && (sect_title.casecmp 'synopsis') == 0
      sect_name, sect_special = 'synopsis', true
    else
      sect_name = 'section'
    end

    attributes['reftext'] = sect_reftext if sect_reftext
    section = Section.new parent, sect_level
    section.id, section.title, section.sectname, section.source_location = sect_id, sect_title, sect_name, source_location
    if sect_special
      section.special = true
      if sect_numbered
        section.numbered = true
      elsif document.attributes['sectnums'] == 'all'
        section.numbered = (book && sect_level == 1 ? :chapter : true)
      end
    elsif document.attributes['sectnums'] && sect_level > 0
      # NOTE a special section here is guaranteed to be nested in another section
      section.numbered = section.special ? parent.numbered && true : true
    elsif book && sect_level == 0 && document.attributes['partnums']
      section.numbered = true
    end

    # generate an ID if one was not embedded or specified as anchor above section title
    if (id = section.id || (section.id = (document.attributes.key? 'sectids') ? (generated_id = Section.generate_id section.title, document) : nil))
      # convert title to resolve attributes while in scope
      section.title unless generated_id || !(sect_title.include? ATTR_REF_HEAD)
      unless document.register :refs, [id, section]
        logger.warn message_with_context %(id assigned to section already in use: #{id}), source_location: (reader.cursor_at_line reader.lineno - (sect_atx ? 1 : 2))
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
    return if (style = attributes[1]) && (style == 'discrete' || style == 'float')
    if Compliance.underline_style_section_titles
      next_lines = reader.peek_lines 2, style && style == 'comment'
      is_section_title?(next_lines[0] || '', next_lines[1])
    else
      atx_section_title?(reader.peek_line || '')
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

  # Public: Checks whether the lines given are an atx or setext section title.
  #
  # line1 - [String] candidate title.
  # line2 - [String] candidate underline (default: nil).
  #
  # Returns the [Integer] section level if these lines are a section title, otherwise nothing.
  def self.is_section_title?(line1, line2 = nil)
    atx_section_title?(line1) || (line2.nil_or_empty? ? nil : setext_section_title?(line1, line2))
  end

  # Checks whether the line given is an atx section title.
  #
  # The level returned is 1 less than number of leading markers.
  #
  # line - [String] candidate title with leading atx marker.
  #
  # Returns the [Integer] section level if this line is an atx section title, otherwise nothing.
  def self.atx_section_title? line
    if Compliance.markdown_syntax ? ((line.start_with? '=', '#') && ExtAtxSectionTitleRx =~ line) :
        ((line.start_with? '=') && AtxSectionTitleRx =~ line)
      $1.length - 1
    end
  end

  # Checks whether the lines given are an setext section title.
  #
  # line1 - [String] candidate title
  # line2 - [String] candidate underline
  #
  # Returns the [Integer] section level if these lines are an setext section title, otherwise nothing.
  def self.setext_section_title? line1, line2
    if (level = SETEXT_SECTION_LEVELS[line2_ch0 = line2.chr]) && (uniform? line2, line2_ch0, (line2_len = line2.length)) &&
        (SetextSectionTitleRx.match? line1) && (line1.length - line2_len).abs < 2
      level
    end
  end

  # Internal: Parse the section title from the current position of the reader
  #
  # Parse an atx (single-line) or setext (underlined) section title. After this method is called,
  # the Reader will be positioned at the line after the section title.
  #
  # For efficiency, we don't reuse methods internally that check for a section title.
  #
  # reader   - the source [Reader], positioned at a section title.
  # document - the current [Document].
  #
  # Examples
  #
  #   reader.lines
  #   # => ["Foo", "~~~"]
  #
  #   id, reftext, title, level, atx = parse_section_title(reader, document)
  #
  #   title
  #   # => "Foo"
  #   level
  #   # => 2
  #   id
  #   # => nil
  #   atx
  #   # => false
  #
  #   line1
  #   # => "==== Foo"
  #
  #   id, reftext, title, level, atx = parse_section_title(reader, document)
  #
  #   title
  #   # => "Foo"
  #   level
  #   # => 3
  #   id
  #   # => nil
  #   atx
  #   # => true
  #
  # Returns an 5-element [Array] containing the id (String), reftext (String),
  # title (String), level (Integer), and flag (Boolean) indicating whether an
  # atx section title was matched, or nothing.
  def self.parse_section_title(reader, document, sect_id = nil)
    sect_reftext = nil
    line1 = reader.read_line

    if Compliance.markdown_syntax ? ((line1.start_with? '=', '#') && ExtAtxSectionTitleRx =~ line1) :
        ((line1.start_with? '=') && AtxSectionTitleRx =~ line1)
      # NOTE level is 1 less than number of line markers
      sect_level, sect_title, atx = $1.length - 1, $2, true
      if sect_title.end_with?(']]') && InlineSectionAnchorRx =~ sect_title && !$1 # escaped
        sect_title, sect_id, sect_reftext = (sect_title.slice 0, sect_title.length - $&.length), $2, $3
      end unless sect_id
    elsif Compliance.underline_style_section_titles && (line2 = reader.peek_line(true)) &&
        (sect_level = SETEXT_SECTION_LEVELS[line2_ch0 = line2.chr]) && (uniform? line2, line2_ch0, (line2_len = line2.length)) &&
        (sect_title = SetextSectionTitleRx =~ line1 && $1) && (line1.length - line2_len).abs < 2
      atx = false
      if sect_title.end_with?(']]') && InlineSectionAnchorRx =~ sect_title && !$1 # escaped
        sect_title, sect_id, sect_reftext = (sect_title.slice 0, sect_title.length - $&.length), $2, $3
      end unless sect_id
      reader.shift
    else
      raise %(Unrecognized section at #{reader.cursor_at_prev_line})
    end
    if document.attr? 'leveloffset'
      sect_level += (document.attr 'leveloffset').to_i
      sect_level = 0 if sect_level < 0
    end
    [sect_id, sect_reftext, sect_title, sect_level, atx]
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
  #  parse_header_metadata(Reader.new data, nil, normalize: true)
  #  # => { 'author' => 'Author Name', 'firstname' => 'Author', 'lastname' => 'Name', 'email' => 'author@example.org',
  #  #       'revnumber' => '1.0', 'revdate' => '2012-12-21', 'revremark' => 'Coincide w/ end of world.' }
  def self.parse_header_metadata reader, document = nil, retrieve = true
    doc_attrs = document && document.attributes
    # NOTE this will discard any comment lines, but not skip blank lines
    process_attribute_entries reader, document

    if reader.has_more_lines? && !reader.next_line_empty?
      authorcount = (implicit_author_metadata = process_authors reader.read_line).delete 'authorcount'
      if document && (doc_attrs['authorcount'] = authorcount) > 0
        implicit_author_metadata.each do |key, val|
          # apply header subs and assign to document; attributes substitution only relevant for email
          doc_attrs[key] = document.apply_header_subs val unless doc_attrs.key? key
        end
        implicit_author = doc_attrs['author']
        implicit_authorinitials = doc_attrs['authorinitials']
        implicit_authors = doc_attrs['authors']
      end
      implicit_author_metadata['authorcount'] = authorcount

      # NOTE this will discard any comment lines, but not skip blank lines
      process_attribute_entries reader, document

      if reader.has_more_lines? && !reader.next_line_empty?
        rev_line = reader.read_line
        if (match = RevisionInfoLineRx.match rev_line)
          rev_metadata = {}
          rev_metadata['revnumber'] = match[1].rstrip if match[1]
          unless (component = match[2].strip).empty?
            # version must begin with 'v' if date is absent
            if !match[1] && (component.start_with? 'v')
              rev_metadata['revnumber'] = component.slice 1, component.length
            else
              rev_metadata['revdate'] = component
            end
          end
          rev_metadata['revremark'] = match[3].rstrip if match[3]
          if document && !rev_metadata.empty?
            # apply header subs and assign to document
            rev_metadata.each do |key, val|
              doc_attrs[key] = document.apply_header_subs val unless doc_attrs.key? key
            end
          end
        else
          # throw it back
          reader.unshift_line rev_line
        end
      end

      # NOTE this will discard any comment lines, but not skip blank lines
      process_attribute_entries reader, document

      reader.skip_blank_lines
    else
      implicit_author_metadata = {}
    end

    # process author attribute entries that override (or stand in for) the implicit author line
    if document
      if doc_attrs.key?('author') && (author_line = doc_attrs['author']) != implicit_author
        # do not allow multiple, process as names only
        author_metadata = process_authors author_line, true, false
        author_metadata.delete 'authorinitials' if doc_attrs['authorinitials'] != implicit_authorinitials
      elsif doc_attrs.key?('authors') && (author_line = doc_attrs['authors']) != implicit_authors
        # allow multiple, process as names only
        author_metadata = process_authors author_line, true
      else
        authors, author_idx, author_key, explicit, sparse = [], 1, 'author_1', false, false
        while doc_attrs.key? author_key
          # only use indexed author attribute if value is different
          # leaves corner case if line matches with underscores converted to spaces; use double space to force
          if (author_override = doc_attrs[author_key]) == implicit_author_metadata[author_key]
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
            next if author
            authors[idx] = [
              implicit_author_metadata[%(firstname_#{name_idx = idx + 1})],
              implicit_author_metadata[%(middlename_#{name_idx})],
              implicit_author_metadata[%(lastname_#{name_idx})]
            ].compact.map {|it| it.tr ' ', '_' }.join ' '
          end if sparse
          # process as names only
          author_metadata = process_authors authors, true, false
        else
          author_metadata = { 'authorcount' => 0 }
        end
      end

      if author_metadata['authorcount'] == 0
        if authorcount
          author_metadata = nil
        else
          doc_attrs['authorcount'] = 0
        end
      else
        doc_attrs.update author_metadata

        # special case
        if !doc_attrs.key?('email') && doc_attrs.key?('email_1')
          doc_attrs['email'] = doc_attrs['email_1']
        end
      end
    end

    implicit_author_metadata.merge rev_metadata.to_h, author_metadata.to_h if retrieve
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
    author_idx = 0
    (multiple && (author_line.include? ';') ? (author_line.split AuthorDelimiterRx) : [*author_line]).each do |author_entry|
      next if author_entry.empty?
      key_map = {}
      if (author_idx += 1) == 1
        AuthorKeys.each {|key| key_map[key.to_sym] = key }
      else
        AuthorKeys.each {|key| key_map[key.to_sym] = %(#{key}_#{author_idx}) }
      end

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

      if author_idx == 1
        author_metadata['authors'] = author_metadata[key_map[:author]]
      else
        # only assign the _1 attributes once we see the second author
        if author_idx == 2
          AuthorKeys.each {|key| author_metadata[%(#{key}_1)] = author_metadata[key] if author_metadata.key? key }
        end
        author_metadata['authors'] = %(#{author_metadata['authors']}, #{author_metadata[key_map[:author]]})
      end
    end

    author_metadata['authorcount'] = author_idx
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
  #              *  :text_only indicates that parser is only looking for text content
  #                   and thus the block title should not be captured
  #
  # returns the Hash of attributes including any metadata found
  def self.parse_block_metadata_lines reader, document, attributes = {}, options = {}
    while parse_block_metadata_line reader, document, attributes, options
      # discard the line just processed
      reader.shift
      reader.skip_blank_lines || break
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
  #              *  :text_only indicates the parser is only looking for text content,
  #                   thus neither a block title or attribute entry should be captured
  #
  # returns true if the line contains metadata, otherwise falsy
  def self.parse_block_metadata_line reader, document, attributes, options = {}
    if (next_line = reader.peek_line) &&
        (options[:text_only] ? (next_line.start_with? '[', '/') : (normal = next_line.start_with? '[', '.', '/', ':'))
      if next_line.start_with? '['
        if next_line.start_with? '[['
          if (next_line.end_with? ']]') && BlockAnchorRx =~ next_line
            # NOTE registration of id and reftext is deferred until block is processed
            attributes['id'] = $1
            if (reftext = $2)
              attributes['reftext'] = (reftext.include? ATTR_REF_HEAD) ? (document.sub_attributes reftext) : reftext
            end
            return true
          end
        elsif (next_line.end_with? ']') && BlockAttributeListRx =~ next_line
          current_style = attributes[1]
          # extract id, role, and options from first positional attribute and remove, if present
          if (document.parse_attributes $1, [], sub_input: true, sub_result: true, into: attributes)[1]
            attributes[1] = (parse_style_attribute attributes, reader) || current_style
          end
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
        elsif normal && (uniform? next_line, '/', (ll = next_line.length))
          unless ll == 3
            reader.read_lines_until terminator: next_line, skip_first_line: true, preserve_last_line: true, skip_processing: true, context: :comment
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
    nil
  end

  # Process consecutive attribute entry lines, ignoring adjacent line comments and comment blocks.
  #
  # Returns nothing
  def self.process_attribute_entries reader, document, attributes = nil
    reader.skip_comment_lines
    while process_attribute_entry reader, document, attributes
      # discard line just processed
      reader.shift
      reader.skip_comment_lines
    end
  end

  def self.process_attribute_entry reader, document, attributes = nil, match = nil
    if match || (match = reader.has_more_lines? ? (AttributeEntryRx.match reader.peek_line) : nil)
      if (value = match[2]).nil_or_empty?
        value = ''
      elsif value.end_with? LINE_CONTINUATION, LINE_CONTINUATION_LEGACY
        con, value = (value.slice value.length - 2, 2), (value.slice 0, value.length - 2).rstrip
        while reader.advance && !(next_line = reader.peek_line || '').empty?
          next_line = next_line.lstrip
          next_line = (next_line.slice 0, next_line.length - 2).rstrip if (keep_open = next_line.end_with? con)
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
      name = name.chop
      value = nil
    elsif name.start_with? '!'
      # a nil value signals the attribute should be deleted (unset)
      name = (name.slice 1, name.length)
      value = nil
    end

    if (name = sanitize_attribute_name name) == 'numbered'
      name = 'sectnums'
    elsif name == 'hardbreaks'
      name = 'hardbreaks-option'
    elsif name == 'showtitle'
      store_attribute 'notitle', (value ? nil : ''), doc, attrs
    end

    if doc
      if value
        if name == 'leveloffset'
          # support relative leveloffset values
          if value.start_with? '+'
            value = ((doc.attr 'leveloffset', 0).to_i + (value.slice 1, value.length).to_i).to_s
          elsif value.start_with? '-'
            value = ((doc.attr 'leveloffset', 0).to_i - (value.slice 1, value.length).to_i).to_s
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
    case list_type
    when :ulist
      marker
    when :olist
      resolve_ordered_list_marker(marker, ordinal, validate, reader)[0]
    else # :colist
      '<1>'
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
  #  Parser.resolve_ordered_list_marker(marker, 1, true, reader)
  #  # => ['A.', :upperalpha]
  #
  #  marker = '.'
  #  Parser.resolve_ordered_list_marker(marker, 1, true, reader)
  #  # => ['.']
  #
  # Returns a tuple that contains the String of the first marker in this number
  # series and the implicit list style, if applicable
  def self.resolve_ordered_list_marker(marker, ordinal = 0, validate = false, reader = nil)
    return [marker] if marker.start_with? '.'
    # NOTE case statement is guaranteed to match one of the conditions
    case (style = ORDERED_LIST_STYLES.find {|s| OrderedListMarkerRxMap[s].match? marker })
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
        expected = Helpers.int_to_roman(ordinal + 1).downcase
        actual = marker.chop # remove trailing )
      end
      marker = 'i)'
    when :upperroman
      if validate
        expected = Helpers.int_to_roman(ordinal + 1)
        actual = marker.chop # remove trailing )
      end
      marker = 'I)'
    end

    if validate && expected != actual
      logger.warn message_with_context %(list item index: expected #{expected}, got #{actual}), source_location: reader.cursor
    end

    [marker, style]
  end

  # Internal: Determine whether the this line is a sibling list item
  # according to the list type and trait (marker) provided.
  #
  # line          - The String line to check
  # list_type     - The context of the list (:olist, :ulist, :colist, :dlist)
  # sibling_trait - The String marker for the list or the Regexp to match a sibling
  #
  # Returns a Boolean indicating whether this line is a sibling list item given the criteria provided
  def self.is_sibling_list_item? line, list_type, sibling_trait
    if ::Regexp === sibling_trait
      sibling_trait.match? line
    else
      ListRxMap[list_type] =~ line && sibling_trait == (resolve_list_marker list_type, $1)
    end
  end

  # Internal: Parse the table contained in the provided Reader
  #
  # table_reader - a Reader containing the source lines of an AsciiDoc table
  # parent       - the parent Block of this Asciidoctor::Table
  # attributes   - attributes captured from above this Block
  #
  # returns an instance of Asciidoctor::Table parsed from the provided reader
  def self.parse_table(table_reader, parent, attributes)
    table = Table.new(parent, attributes)

    if (attributes.key? 'cols') && !(colspecs = parse_colspecs attributes['cols']).empty?
      table.create_columns colspecs
      explicit_colspecs = true
    end

    skipped = table_reader.skip_blank_lines || 0
    if attributes['header-option']
      table.has_header_option = true
    elsif skipped == 0 && !attributes['noheader-option']
      # NOTE: assume table has header until we know otherwise; if it doesn't (nil), cells in first row get reprocessed
      table.has_header_option = :implicit
      implicit_header = true
    end
    parser_ctx = Table::ParserContext.new table_reader, table, attributes
    format, loop_idx, implicit_header_boundary = parser_ctx.format, -1, nil

    while (line = table_reader.read_line)
      if (beyond_first = (loop_idx += 1) > 0) && line.empty?
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
            table.has_header_option = implicit_header = implicit_header_boundary = nil
          end
        end
      end

      unless beyond_first
        table_reader.mark
        # NOTE implicit header is offset by at least one blank line; implicit_header_boundary tracks size of gap
        if implicit_header
          if table_reader.has_more_lines? && table_reader.peek_line.empty?
            implicit_header_boundary = 1
          else
            table.has_header_option = implicit_header = nil
          end
        end
      end

      # this loop is used for flow control; internal logic controls how many times it executes
      while true
        if line && (m = parser_ctx.match_delimiter line)
          pre_match, post_match = m.pre_match, m.post_match
          case format
          when 'csv'
            if parser_ctx.buffer_has_unclosed_quotes? pre_match
              parser_ctx.skip_past_delimiter pre_match
              break if (line = post_match).empty?
              redo
            end
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{pre_match})
          when 'dsv'
            if pre_match.end_with? '\\'
              parser_ctx.skip_past_escaped_delimiter pre_match
              if (line = post_match).empty?
                parser_ctx.buffer = %(#{parser_ctx.buffer}#{LF})
                parser_ctx.keep_cell_open
                break
              end
              redo
            end
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{pre_match})
          else # psv
            if pre_match.end_with? '\\'
              parser_ctx.skip_past_escaped_delimiter pre_match
              if (line = post_match).empty?
                parser_ctx.buffer = %(#{parser_ctx.buffer}#{LF})
                parser_ctx.keep_cell_open
                break
              end
              redo
            end
            next_cellspec, cell_text = parse_cellspec pre_match
            parser_ctx.push_cellspec next_cellspec
            parser_ctx.buffer = %(#{parser_ctx.buffer}#{cell_text})
          end
          # don't break if empty to preserve empty cell found at end of line (see issue #1106)
          line = nil if (line = post_match).empty?
          parser_ctx.close_cell
        else
          # no other delimiters to see here; suck up this line into the buffer and move on
          parser_ctx.buffer = %(#{parser_ctx.buffer}#{line}#{LF})
          case format
          when 'csv'
            if parser_ctx.buffer_has_unclosed_quotes?
              table.has_header_option = implicit_header = implicit_header_boundary = nil if implicit_header_boundary && loop_idx == 0
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

      # NOTE cell may already be closed if table format is csv or dsv
      if parser_ctx.cell_open?
        parser_ctx.close_cell true unless table_reader.has_more_lines?
      else
        table_reader.skip_blank_lines || break
      end
    end

    table.assign_column_widths unless (table.attributes['colcount'] ||= table.columns.size) == 0 || explicit_colspecs
    table.has_header_option = true if implicit_header
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
    ((records.include? ',') ? (records.split ',', -1) : (records.split ';', -1)).each do |record|
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

        if (width = m[3])
          # to_i will strip the optional %
          spec['width'] = width == '~' ? -1 : width.to_i
        else
          spec['width'] = 1
        end

        # make this an operation
        if m[4] && TableCellStyles.key?(m[4])
          spec['style'] = TableCellStyles[m[4]]
        end

        if m[1]
          1.upto(m[1].to_i) { specs << spec.merge }
        else
          specs << spec
        end
      end
    end
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
        spec_part, _, rest = line.partition delimiter
        if (m = CellSpecStartRx.match spec_part)
          return [{}, rest] if m[0].empty?
        else
          return [nil, line]
        end
      else
        return [nil, line]
      end
    elsif (m = CellSpecEndRx.match line) # when pos == :end
      # NOTE return the line stripped of trailing whitespace if no cellspec is found in this case
      return [{}, line.rstrip] if m[0].lstrip.empty?
      rest = m.pre_match
    else
      return [{}, line]
    end

    spec = {}
    if m[1]
      colspec, rowspec = m[1].split '.'
      colspec = colspec.nil_or_empty? ? 1 : colspec.to_i
      rowspec = rowspec.nil_or_empty? ? 1 : rowspec.to_i
      case m[2]
      when '+'
        spec['colspan'] = colspec unless colspec == 1
        spec['rowspan'] = rowspec unless rowspec == 1
      when '*'
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
  # parts, assign the values to their corresponding attribute keys and return
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
  def self.parse_style_attribute attributes, reader = nil
    # NOTE spaces are not allowed in shorthand, so if we detect one, this ain't no shorthand
    if (raw_style = attributes[1]) && !raw_style.include?(' ') && Compliance.shorthand_property_syntax
      name = nil
      accum = ''
      parsed_attrs = {}

      raw_style.each_char do |c|
        case c
        when '.'
          yield_buffered_attribute parsed_attrs, name, accum, reader
          accum = ''
          name = :role
        when '#'
          yield_buffered_attribute parsed_attrs, name, accum, reader
          accum = ''
          name = :id
        when '%'
          yield_buffered_attribute parsed_attrs, name, accum, reader
          accum = ''
          name = :option
        else
          accum += c
        end
      end

      # small optimization if no shorthand is found
      if name
        yield_buffered_attribute parsed_attrs, name, accum, reader

        if (parsed_style = parsed_attrs[:style])
          attributes['style'] = parsed_style
        end

        attributes['id'] = parsed_attrs[:id] if parsed_attrs.key? :id

        if parsed_attrs.key? :role
          attributes['role'] = (existing_role = attributes['role']).nil_or_empty? ? (parsed_attrs[:role].join ' ') : %(#{existing_role} #{parsed_attrs[:role].join ' '})
        end

        parsed_attrs[:option].each {|opt| attributes[%(#{opt}-option)] = '' } if parsed_attrs.key? :option

        parsed_style
      else
        attributes['style'] = raw_style
      end
    else
      attributes['style'] = raw_style
    end
  end

  # Internal: Save the collected attribute (:id, :option, :role, or nil for :style) in the attribute Hash.
  def self.yield_buffered_attribute attrs, name, value, reader
    if name
      if value.empty?
        if reader
          logger.warn message_with_context %(invalid empty #{name} detected in style attribute), source_location: reader.cursor_at_prev_line
        else
          logger.warn %(invalid empty #{name} detected in style attribute)
        end
      elsif name == :id
        if attrs.key? :id
          if reader
            logger.warn message_with_context 'multiple ids detected in style attribute', source_location: reader.cursor_at_prev_line
          else
            logger.warn 'multiple ids detected in style attribute'
          end
        end
        attrs[name] = value
      else
        (attrs[name] ||= []) << value
      end
    else
      attrs[:style] = value unless value.empty?
    end
    nil
  end

  # Remove the block indentation (the amount of whitespace of the least indented line), replace tabs with spaces (using
  # proper tab expansion logic) and, finally, indent the lines by the margin width. Modifies the input Array directly.
  #
  # This method preserves the significant indentation (that exceeding the block indent) on each line.
  #
  # lines       - The Array of String lines to process (no trailing newlines)
  # indent_size - The Integer number of spaces to readd to the start of non-empty lines after removing the indentation.
  #               If this value is < 0, the existing indentation is preserved (optional, default: 0)
  # tab_size    - the Integer number of spaces to use in place of a tab. A value of <= 0 disables the replacement
  #               (optional, default: 0)
  #
  # Examples
  #
  #   source = <<EOS
  #       def names
  #         @name.split
  #       end
  #   EOS
  #
  #   source.split ?\n
  #   # => ["    def names", "      @names.split", "    end"]
  #
  #   puts (Parser.adjust_indentation! source.split ?\n).join ?\n
  #   # => def names
  #   # =>   @names.split
  #   # => end
  #
  # returns Nothing
  def self.adjust_indentation! lines, indent_size = 0, tab_size = 0
    return if lines.empty?

    # expand tabs if a tab character is detected and tab_size > 0
    if tab_size > 0 && lines.any? {|line| line.include? TAB }
      full_tab_space = ' ' * tab_size
      lines.map! do |line|
        if line.empty? || (tab_idx = line.index TAB).nil?
          line
        else
          if tab_idx == 0
            leading_tabs = 0
            line.each_byte do |b|
              break unless b == 9
              leading_tabs += 1
            end
            line = %(#{full_tab_space * leading_tabs}#{line.slice leading_tabs, line.length})
            next line unless line.include? TAB
          end
          # keeps track of how many spaces were added to adjust offset in match data
          spaces_added = 0
          idx = 0
          result = ''
          line.each_char do |c|
            if c == TAB
              # calculate how many spaces this tab represents, then replace tab with spaces
              if (offset = idx + spaces_added) % tab_size == 0
                spaces_added += tab_size - 1
                result += full_tab_space
              else
                unless (spaces = tab_size - offset % tab_size) == 1
                  spaces_added += spaces - 1
                end
                result += ' ' * spaces
              end
            else
              result += c
            end
            idx += 1
          end
          result
        end
      end
    end

    # skip block indent adjustment if indent_size is < 0
    return if indent_size < 0

    # determine block indent (assumes no whitespace-only lines are present)
    block_indent = nil
    lines.each do |line|
      next if line.empty?
      if (line_indent = line.length - line.lstrip.length) == 0
        block_indent = nil
        break
      end
      block_indent = line_indent unless block_indent && block_indent < line_indent
    end

    # remove block indent then apply indent_size if specified
    # NOTE block_indent is > 0 if not nil
    if indent_size == 0
      lines.map! {|line| line.empty? ? line : (line.slice block_indent, line.length) } if block_indent
    else
      new_block_indent = ' ' * indent_size
      if block_indent
        lines.map! {|line| line.empty? ? line : new_block_indent + (line.slice block_indent, line.length) }
      else
        lines.map! {|line| line.empty? ? line : new_block_indent + line }
      end
    end

    nil
  end

  def self.uniform? str, chr, len
    (str.count chr) == len
  end

  # Internal: Convert a string to a legal attribute name.
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
end
end
