# frozen_string_literal: true
module Asciidoctor
class AbstractBlock < AbstractNode
  # Public: Get the Array of {AbstractBlock} child blocks for this block. Only applies if content model is :compound.
  attr_reader :blocks

  # Public: Set the caption for this block.
  attr_writer :caption

  # Public: Describes the type of content this block accepts and how it should be converted. Acceptable values are:
  # * :compound - this block contains other blocks
  # * :simple - this block holds a paragraph of prose that receives normal substitutions
  # * :verbatim - this block holds verbatim text (displayed "as is") that receives verbatim substitutions
  # * :raw - this block holds unprocessed content passed directly to the output with no substitutions applied
  # * :empty - this block has no content
  attr_accessor :content_model

  # Public: Set the Integer level of this {Section} or the level of the Section to which this {AbstractBlock} belongs.
  attr_accessor :level

  # Public: Get/Set the String numeral of this block (if section, relative to parent, otherwise absolute).
  # Only assigned to section if automatic section numbering is enabled.
  # Only assigned to formal block (block with title) if corresponding caption attribute is present.
  attr_accessor :numeral

  # Public: Gets/Sets the location in the AsciiDoc source where this block begins.
  # Tracking source location is not enabled by default, and is controlled by the sourcemap option.
  attr_accessor :source_location

  # Public: Get/Set the String style (block type qualifier) for this block.
  attr_accessor :style

  # Public: Substitutions to be applied to content in this block.
  attr_reader :subs

  def initialize parent, context, opts = {}
    super
    @content_model = :compound
    @blocks = []
    @subs = []
    @id = @title = @caption = @numeral = @style = @default_subs = @source_location = nil
    if context == :document || context == :section
      @level = @next_section_index = 0
      @next_section_ordinal = 1
    elsif AbstractBlock === parent
      @level = parent.level
    else
      @level = nil
    end
  end

  def block?
    true
  end

  def inline?
    false
  end

  # Public: Get the source file where this block started
  def file
    @source_location && @source_location.file
  end

  # Public: Get the source line number where this block started
  def lineno
    @source_location && @source_location.lineno
  end

  # Public: Get the converted String content for this Block.  If the block
  # has child blocks, the content method should cause them to be
  # converted and returned as content that can be included in the
  # parent block's template.
  def convert
    @document.playback_attributes @attributes
    converter.convert self
  end

  # Deprecated: Use {AbstractBlock#convert} instead.
  alias render convert

  # Public: Get the converted result of the child blocks by converting the
  # children appropriate to content model that this block supports.
  def content
    @blocks.map {|b| b.convert }.join LF
  end

  # Public: Update the context of this block.
  #
  # This method changes the context of this block. It also updates the node name accordingly.
  #
  # context - the context Symbol context to assign to this block
  #
  # Returns the specified Symbol context
  def context= context
    @node_name = (@context = context).to_s
  end

  # Public: Append a content block to this block's list of blocks.
  #
  # block - The new child block.
  #
  # Examples
  #
  #   block = Block.new(parent, :preamble, content_model: :compound)
  #
  #   block << Block.new(block, :paragraph, source: 'p1')
  #   block << Block.new(block, :paragraph, source: 'p2')
  #   block.blocks?
  #   # => true
  #   block.blocks.size
  #   # => 2
  #
  # Returns The parent Block
  def << block
    block.parent = self unless block.parent == self
    @blocks << block
    self
  end

  # NOTE append alias required for adapting to a Java API
  alias append <<

  # Public: Determine whether this Block contains block content
  #
  # Returns A Boolean indicating whether this Block has block content
  def blocks?
    @blocks.empty? ? false : true
  end

  # Public: Check whether this block has any child Section objects.
  #
  # Acts an an abstract method that always returns false unless this block is an
  # instance of Document or Section.
  # Both Document and Section provide overrides for this method.
  #
  # Returns false
  def sections?
    false
  end

  # Deprecated: Legacy property to get the String or Integer numeral of this section.
  def number
    (Integer @numeral) rescue @numeral
  end

  # Deprecated: Legacy property to set the numeral of this section by coercing the value to a String.
  def number= val
    @numeral = val.to_s
  end

  # Public: Walk the document tree and find all block-level nodes that match the specified selector (context, style, id,
  # role, and/or custom filter).
  #
  # If a Ruby block is given, it's applied as a supplemental filter. If the filter returns true (which implies :accept),
  # the node is accepted and node traversal continues. If the filter returns false (which implies :skip), the node is
  # skipped, but its children are still visited. If the filter returns :reject, the node and all its descendants are
  # rejected. If the filter returns :prune, the node is accepted, but its descendants are rejected. If no selector
  # or filter block is supplied, all block-level nodes in the tree are returned.
  #
  # Examples
  #
  #   doc.find_by context: :section
  #   #=> Asciidoctor::Section@14459860 { level: 0, title: "Hello, AsciiDoc!", blocks: 0 }
  #   #=> Asciidoctor::Section@14505460 { level: 1, title: "First Section", blocks: 1 }
  #
  #   doc.find_by(context: :section) {|section| section.level == 1 }
  #   #=> Asciidoctor::Section@14505460 { level: 1, title: "First Section", blocks: 1 }
  #
  #   doc.find_by context: :listing, style: 'source'
  #   #=> Asciidoctor::Block@13136720 { context: :listing, content_model: :verbatim, style: "source", lines: 1 }
  #
  # Returns An Array of block-level nodes that match the filter or an empty Array if no matches are found
  #--
  # TODO support jQuery-style selector (e.g., image.thumb)
  def find_by selector = {}, &block
    find_by_internal selector, (result = []), &block
  rescue ::StopIteration
    result
  end

  alias query find_by

  # Move to the next adjacent block in document order. If the current block is the last
  # item in a list, this method will return the following sibling of the list block.
  def next_adjacent_block
    unless @context == :document
      if (p = @parent).context == :dlist && @context == :list_item
        (sib = p.items[(p.items.find_index {|terms, desc| (terms.include? self) || desc == self }) + 1]) ? sib : p.next_adjacent_block
      else
        (sib = p.blocks[(p.blocks.find_index self) + 1]) ? sib : p.next_adjacent_block
      end
    end
  end

  # Public: Get the Array of child Section objects
  #
  # Only applies to Document and Section instances
  #
  # Examples
  #
  #   doc << (sect1 = Section.new doc, 1)
  #   sect1.title = 'Section 1'
  #   para1 = Block.new sect1, :paragraph, source: 'Paragraph 1'
  #   para2 = Block.new sect1, :paragraph, source: 'Paragraph 2'
  #   sect1 << para1 << para2
  #   sect1 << (sect1_1 = Section.new sect1, 2)
  #   sect1_1.title = 'Section 1.1'
  #   sect1_1 << (Block.new sect1_1, :paragraph, source: 'Paragraph 3')
  #   sect1.blocks?
  #   # => true
  #   sect1.blocks.size
  #   # => 3
  #   sect1.sections.size
  #   # => 1
  #
  # Returns an [Array] of Section objects
  def sections
    @blocks.select {|block| block.context == :section }
  end

  # Public: Returns the converted alt text for this block image.
  #
  # Returns the [String] value of the alt attribute with XML special character
  # and replacement substitutions applied.
  def alt
    if (text = @attributes['alt'])
      if text == @attributes['default-alt']
        sub_specialchars text
      else
        text = sub_specialchars text
        (ReplaceableTextRx.match? text) ? (sub_replacements text) : text
      end
    else
      ''
    end
  end

  # Gets the caption for this block.
  #
  # This method routes the deprecated use of the caption method on an
  # admonition block to the textlabel attribute.
  #
  # Returns the [String] caption for this block (or the value of the textlabel
  # attribute if this is an admonition block).
  def caption
    @context == :admonition ? @attributes['textlabel'] : @caption
  end

  # Public: Convenience method that returns the interpreted title of the Block
  # with the caption prepended.
  #
  # Concatenates the value of this Block's caption instance variable and the
  # return value of this Block's title method. No space is added between the
  # two values. If the Block does not have a caption, the interpreted title is
  # returned.
  #
  # Returns the converted String title prefixed with the caption, or just the
  # converted String title if no caption is set
  def captioned_title
    %(#{@caption}#{title})
  end

  # Public: Retrieve the list marker keyword for the specified list type.
  #
  # For use in the HTML type attribute.
  #
  # list_type - the type of list; default to the @style if not specified
  #
  # Returns the single-character [String] keyword that represents the marker for the specified list type
  def list_marker_keyword list_type = nil
    ORDERED_LIST_KEYWORDS[list_type || @style]
  end

  # Public: Get the String title of this Block with title substitutions applied
  #
  # The following substitutions are applied to block and section titles:
  #
  # :specialcharacters, :quotes, :replacements, :macros, :attributes and :post_replacements
  #
  # Examples
  #
  #   block.title = "Foo 3^ # {two-colons} Bar(1)"
  #   block.title
  #   => "Foo 3^ # :: Bar(1)"
  #
  # Returns the converted String title for this Block, or nil if the source title is falsy
  def title
    # prevent substitutions from being applied to title multiple times
    @converted_title ||= @title && (apply_title_subs @title)
  end

  # Public: A convenience method that checks whether the title of this block is defined.
  #
  # Returns a [Boolean] indicating whether this block has a title.
  def title?
    @title ? true : false
  end

  # Public: Set the String block title.
  #
  # Returns the specified String title
  def title= val
    @converted_title = nil
    @title = val
  end

  # Public: A convenience method that checks whether the specified
  # substitution is enabled for this block.
  #
  # name - The Symbol substitution name
  #
  # Returns A Boolean indicating whether the specified substitution is
  # enabled for this block
  def sub? name
    @subs.include? name
  end

  # Public: Remove a substitution from this block
  #
  # sub  - The Symbol substitution name
  #
  # Returns nothing
  def remove_sub sub
    @subs.delete sub
    nil
  end

  # Public: Generate cross reference text (xreftext) that can be used to refer
  # to this block.
  #
  # Use the explicit reftext for this block, if specified, retrieved from the
  # {#reftext} method. Otherwise, if this is a section or captioned block (a
  # block with both a title and caption), generate the xreftext according to
  # the value of the xrefstyle argument (e.g., full, short). This logic may
  # leverage the {Substitutors#sub_quotes} method to apply formatting to the
  # text. If this is not a captioned block, return the title, if present, or
  # nil otherwise.
  #
  # xrefstyle - An optional String that specifies the style to use to format
  #             the xreftext ('full', 'short', or 'basic') (default: nil).
  #
  # Returns the generated [String] xreftext used to refer to this block or
  # nothing if there isn't sufficient information to generate one.
  def xreftext xrefstyle = nil
    if (val = reftext) && !val.empty?
      val
    # NOTE xrefstyle only applies to blocks with a title and a caption or number
    elsif xrefstyle && @title && !@caption.nil_or_empty?
      case xrefstyle
      when 'full'
        quoted_title = sub_placeholder (sub_quotes @document.compat_mode ? %q(``%s'') : '"`%s`"'), title
        if @numeral && (caption_attr_name = CAPTION_ATTRIBUTE_NAMES[@context]) && (prefix = @document.attributes[caption_attr_name])
          %(#{prefix} #{@numeral}, #{quoted_title})
        else
          %(#{@caption.chomp '. '}, #{quoted_title})
        end
      when 'short'
        if @numeral && (caption_attr_name = CAPTION_ATTRIBUTE_NAMES[@context]) && (prefix = @document.attributes[caption_attr_name])
          %(#{prefix} #{@numeral})
        else
          @caption.chomp '. '
        end
      else # 'basic'
        title
      end
    else
      title
    end
  end

  # Public: Generate and assign caption to block if not already assigned.
  #
  # If the block has a title and a caption prefix is available for this block,
  # then build a caption from this information, assign it a number and store it
  # to the caption attribute on the block.
  #
  # If a caption has already been assigned to this block, do nothing.
  #
  # The parts of a complete caption are: <prefix> <number>. <title>
  # This partial caption represents the part the precedes the title.
  #
  # value           - The String caption to assign to this block or nil to use document attribute.
  # caption_context - The Symbol context to use when resolving caption-related attributes. If not provided, the name of
  #                   the context for this block is used. Only certain contexts allow the caption to be looked up.
  #                   (default: @context)
  #
  # Returns nothing.
  def assign_caption value, caption_context = @context
    unless @caption || !@title || (@caption = value || @document.attributes['caption'])
      if (attr_name = CAPTION_ATTRIBUTE_NAMES[caption_context]) && (prefix = @document.attributes[attr_name])
        @caption = %(#{prefix} #{@numeral = @document.increment_and_store_counter %(#{caption_context}-number), self}. )
        nil
      end
    end
  end

  # Internal: Assign the next index (0-based) and numeral (1-based) to the section.
  # If the section is an appendix, the numeral is a letter (starting with A). This
  # method also assigns the appendix caption.
  #
  # section - The section to which to assign the next index and numeral.
  #
  # Assign to the specified section the next index and, if the section is
  # numbered, the numeral within this block (its parent).
  #
  # Returns nothing
  def assign_numeral section
    @next_section_index = (section.index = @next_section_index) + 1
    if (like = section.numbered)
      if (sectname = section.sectname) == 'appendix'
        section.numeral = @document.counter 'appendix-number', 'A'
        section.caption = (caption = @document.attributes['appendix-caption']) ? %(#{caption} #{section.numeral}: ) : %(#{section.numeral}. )
      # NOTE currently chapters in a book doctype are sequential even for multi-part books (see #979)
      elsif sectname == 'chapter' || like == :chapter
        section.numeral = (@document.counter 'chapter-number', 1).to_s
      else
        section.numeral = sectname == 'part' ? (Helpers.int_to_roman @next_section_ordinal) : @next_section_ordinal.to_s
        @next_section_ordinal += 1
      end
    end
    nil
  end

  # Internal: Reassign the section indexes
  #
  # Walk the descendents of the current Document or Section
  # and reassign the section 0-based index value to each Section
  # as it appears in document order.
  #
  # IMPORTANT You must invoke this method on a node after removing
  # child sections or else the internal counters will be off.
  #
  # Returns nothing
  def reindex_sections
    @next_section_index = 0
    @next_section_ordinal = 1
    @blocks.each do |block|
      if block.context == :section
        assign_numeral block
        block.reindex_sections
      end
    end
  end

  protected

  # Internal: Performs the work for find_by, but does not handle the StopIteration exception.
  def find_by_internal selector = {}, result = [], &block
    if ((any_context = (context_selector = selector[:context]) ? nil : true) || context_selector == @context) &&
        (!(style_selector = selector[:style]) || style_selector == @style) &&
        (!(role_selector = selector[:role]) || (has_role? role_selector)) &&
        (!(id_selector = selector[:id]) || id_selector == @id)
      if block_given?
        if (verdict = yield self)
          case verdict
          when :prune
            result << self
            raise ::StopIteration if id_selector
            return result
          when :reject
            raise ::StopIteration if id_selector
            return result
          when :stop
            raise ::StopIteration
          else
            result << self
            raise ::StopIteration if id_selector
          end
        elsif id_selector
          raise ::StopIteration
        end
      else
        result << self
        raise ::StopIteration if id_selector
      end
    end
    case @context
    when :document
      unless context_selector == :document
        # process document header as a section, if present
        if header? && (any_context || context_selector == :section)
          @header.find_by_internal selector, result, &block
        end
        @blocks.each do |b|
          next if context_selector == :section && b.context != :section # optimization
          b.find_by_internal selector, result, &block
        end
      end
    when :dlist
      # dlist has different structure than other blocks
      if any_context || context_selector != :section # optimization
        # NOTE the list item of a dlist can be nil, so we have to check
        @blocks.flatten.each {|b| b.find_by_internal selector, result, &block if b }
      end
    when :table
      if selector[:traverse_documents]
        rows.head.each {|r| r.each {|c| c.find_by_internal selector, result, &block } }
        selector = selector.merge context: :document if context_selector == :inner_document
        (rows.body + rows.foot).each do |r|
          r.each do |c|
            c.find_by_internal selector, result, &block
            c.inner_document.find_by_internal selector, result, &block if c.style == :asciidoc
          end
        end
      else
        (rows.head + rows.body + rows.foot).each {|r| r.each {|c| c.find_by_internal selector, result, &block } }
      end
    else
      @blocks.each do |b|
        next if context_selector == :section && b.context != :section # optimization
        b.find_by_internal selector, result, &block
      end
    end
    result
  end
end
end
