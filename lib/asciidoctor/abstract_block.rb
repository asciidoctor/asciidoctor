# encoding: UTF-8
module Asciidoctor
class AbstractBlock < AbstractNode
  # Public: Get the Array of Asciidoctor::AbstractBlock sub-blocks for this block
  attr_reader :blocks

  # Public: Set the caption for this block
  attr_writer :caption

  # Public: The types of content that this block can accomodate
  attr_accessor :content_model

  # Public: Set the Integer level of this Section or the Section level in which this Block resides
  attr_accessor :level

  # Public: Get/Set the number of this block (if section, relative to parent, otherwise absolute)
  # Only assigned to section if automatic section numbering is enabled
  # Only assigned to formal block (block with title) if corresponding caption attribute is present
  attr_accessor :number

  # Public: Gets/Sets the location in the AsciiDoc source where this block begins
  attr_accessor :source_location

  # Public: Get/Set the String style (block type qualifier) for this block.
  attr_accessor :style

  # Public: Substitutions to be applied to content in this block
  attr_reader :subs

  def initialize parent, context, opts = {}
    super
    @content_model = :compound
    @blocks = []
    @subs = []
    @id = @title = @title_converted = @caption = @number = @style = @default_subs = @source_location = nil
    if context == :document
      @level = 0
    elsif parent && context != :section
      @level = parent.level
    else
      @level = nil
    end
    @next_section_index = 0
    @next_section_number = 1
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

  # Alias render to convert to maintain backwards compatibility
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
  # Returns the new context Symbol assigned to this block
  def context= context
    @node_name = (@context = context).to_s
  end

  # Public: Append a content block to this block's list of blocks.
  #
  # block - The new child block.
  #
  # Examples
  #
  #   block = Block.new(parent, :preamble, :content_model => :compound)
  #
  #   block << Block.new(block, :paragraph, :source => 'p1')
  #   block << Block.new(block, :paragraph, :source => 'p2')
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
    !@blocks.empty?
  end

  # Public: Check whether this block has any child Section objects.
  #
  # Only applies to Document and Section instances
  #
  # Returns A [Boolean] to indicate whether this block has child Section objects
  def sections?
    @next_section_index > 0
  end

  # Public: Query for all descendant block-level nodes in the document tree
  # that match the specified selector (context, style, id, and/or role). If a
  # Ruby block is given, it's used as an additional filter. If no selector or
  # Ruby block is supplied, all block-level nodes in the tree are returned.
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
    result = []

    if ((any_context = !(context_selector = selector[:context])) || context_selector == @context) &&
        (!(style_selector = selector[:style]) || style_selector == @style) &&
        (!(role_selector = selector[:role]) || (has_role? role_selector)) &&
        (!(id_selector = selector[:id]) || id_selector == @id)
      if id_selector
        if block_given?
          return (yield self) ? [self] : result
        else
          return [self]
        end
      elsif block_given?
        result << self if (yield self)
      else
        result << self
      end
    end

    # process document header as a section if present
    if @context == :document && (any_context || context_selector == :section) && header?
      result.concat(@header.find_by selector, &block)
    end

    unless context_selector == :document # optimization
      # yuck, dlist is a special case
      if @context == :dlist
        if any_context || context_selector != :section # optimization
          @blocks.flatten.each do |li|
            # NOTE the list item of a dlist can be nil, so we have to check
            result.concat(li.find_by selector, &block) if li
          end
        end
      elsif
        @blocks.each do |b|
          next if (context_selector == :section && b.context != :section) # optimization
          result.concat(b.find_by selector, &block)
        end
      end
    end
    result
  end

  alias query find_by

  # Move to the next adjacent block in document order. If the current block is the last
  # item in a list, this method will return the following sibling of the list block.
  def next_adjacent_block
    (sib = (p = parent).blocks[(p.blocks.find_index self) + 1]) ? sib : p.next_adjacent_block unless @context == :document
  end

  # Public: Get the Array of child Section objects
  #
  # Only applies to Document and Section instances
  #
  # Examples
  #
  #   doc << (sect1 = Section.new doc, 1)
  #   sect1.title = 'Section 1'
  #   para1 = Block.new sect1, :paragraph, :source => 'Paragraph 1'
  #   para2 = Block.new sect1, :paragraph, :source => 'Paragraph 2'
  #   sect1 << para1 << para2
  #   sect1 << (sect1_1 = Section.new sect1, 2)
  #   sect1_1.title = 'Section 1.1'
  #   sect1_1 << (Block.new sect1_1, :paragraph, :source => 'Paragraph 3')
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

  # Public: Get the String title of this Block with title substitions applied
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
    @title_converted ? @converted_title : (@converted_title = (@title_converted = true) && @title && (apply_title_subs @title))
  end

  # Public: A convenience method that checks whether the title of this block is defined.
  #
  # Returns a [Boolean] indicating whether this block has a title.
  def title?
    @title ? true : false
  end

  # Public: Set the String block title.
  #
  # Returns the new String title assigned to this Block
  def title= val
    @title, @title_converted = val, nil
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
    elsif xrefstyle && @title && @caption
      case xrefstyle
      when 'full'
        quoted_title = sprintf sub_quotes(@document.compat_mode ? %q(``%s'') : '"`%s`"'), title
        if @number && (prefix = @document.attributes[@context == :image ? 'figure-caption' : %(#{@context}-caption)])
          %(#{prefix} #{@number}, #{quoted_title})
        else
          %(#{@caption.chomp '. '}, #{quoted_title})
        end
      when 'short'
        if @number && (prefix = @document.attributes[@context == :image ? 'figure-caption' : %(#{@context}-caption)])
          %(#{prefix} #{@number})
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
  # value - The explicit String caption to assign to this block (default: nil).
  # key   - The String prefix for the caption and counter attribute names.
  #         If not provided, the name of the context for this block is used.
  #         (default: nil)
  #
  # Returns nothing.
  def assign_caption value = nil, key = nil
    unless @caption || !@title || (@caption = value || @document.attributes['caption'])
      if (prefix = @document.attributes[%(#{key ||= @context}-caption)])
        @caption = %(#{prefix} #{@number = @document.increment_and_store_counter "#{key}-number", self}. )
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
        section.number = @document.counter 'appendix-number', 'A'
        if (caption = @document.attributes['appendix-caption'])
          section.caption = %(#{caption} #{section.number}: )
        else
          section.caption = %(#{section.number}. )
        end
      # NOTE currently chapters in a book doctype are sequential even for multi-part books (see #979)
      elsif sectname == 'chapter' || like == :chapter
        section.number = @document.counter 'chapter-number', 1
      else
        @next_section_number = (section.number = @next_section_number) + 1
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
    @next_section_number = 1
    @blocks.each do |block|
      if block.context == :section
        assign_numeral block
        block.reindex_sections
      end
    end
  end

# stage the Enumerable mixin until we're sure we've got it right
=begin
  include ::Enumerable

  # Public: Yield the block on this block node and all its descendant
  # block node children to satisfy the Enumerable contract.
  #
  # Returns nothing
  def each &block
    # yucky, dlist is a special case
    if @context == :dlist
      @blocks.flatten.each &block
    else
      #yield self.header if @context == :document && header?
      @blocks.each &block
    end
  end

  #--
  # TODO is there a way to make this lazy?
  def each_recursive &block
    block = lambda {|node| node } unless block_given?
    results = []
    self.each do |node|
      results << block.call(node)
      results.concat(node.each_recursive(&block)) if ::Enumerable === node
    end
    block_given? ? results : results.to_enum
  end
=end
end
end
