# encoding: UTF-8
module Asciidoctor
class AbstractBlock < AbstractNode
  # Public: The types of content that this block can accomodate
  attr_accessor :content_model

  # Public: Substitutions to be applied to content in this block
  attr_reader :subs

  # Public: Get the Array of Asciidoctor::AbstractBlock sub-blocks for this block
  attr_reader :blocks

  # Public: Set the Integer level of this Section or the Section level in which this Block resides
  attr_accessor :level

  # Public: Set the String block title.
  attr_writer :title

  # Public: Get/Set the String style (block type qualifier) for this block.
  attr_accessor :style

  # Public: Get/Set the caption for this block
  attr_accessor :caption

  # Public: Gets/Sets the location in the AsciiDoc source where this block begins
  attr_accessor :source_location

  def initialize parent, context, opts = {}
    super
    @content_model = :compound
    @subs = []
    @default_subs = nil
    @blocks = []
    @id = nil
    @title = nil
    @caption = nil
    @style = nil
    @level = if context == :document
      0
    elsif parent && context != :section
      parent.level
    end
    @next_section_index = 0
    @next_section_number = 1
    @source_location = nil
  end

  def block?
    true
  end

  def inline?
    false
  end

  # Public: Update the context of this block.
  #
  # This method changes the context of this block. It also
  # updates the node name accordingly.
  def context=(context)
    @context = context
    @node_name = context.to_s
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
  alias :render :convert

  # Public: Get the converted result of the child blocks by converting the
  # children appropriate to content model that this block supports.
  def content
    @blocks.map {|b| b.convert } * EOL
  end

  # Public: Get the source file where this block started
  def file
    @source_location ? @source_location.file : nil
  end

  # Public: Get the source line number where this block started
  def lineno
    @source_location ? @source_location.lineno : nil
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

  # Public: A convenience method that indicates whether the title instance
  # variable is blank (nil or empty)
  def title?
    !@title.nil_or_empty?
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
  # Returns the String title of this Block
  def title
    # prevent substitutions from being applied multiple times
    if defined?(@subbed_title)
      @subbed_title
    elsif @title
      @subbed_title = apply_title_subs(@title)
    else
      @title
    end
  end

  # Public: Convenience method that returns the interpreted title of the Block
  # with the caption prepended.
  #
  # Concatenates the value of this Block's caption instance variable and the
  # return value of this Block's title method. No space is added between the
  # two values. If the Block does not have a caption, the interpreted title is
  # returned.
  #
  # Returns the String title prefixed with the caption, or just the title if no
  # caption is set
  def captioned_title
    %(#{@caption}#{title})
  end

  # Public: Determine whether this Block contains block content
  #
  # Returns A Boolean indicating whether this Block has block content
  def blocks?
    !@blocks.empty?
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
    # parent assignment pending refactor
    #block.parent = self
    @blocks << block
    self
  end

  # NOTE append alias required for adapting to a Java API
  alias :append :<<

  # Public: Get the Array of child Section objects
  #
  # Only applies to Document and Section instances
  #
  # Examples
  #
  #   doc << (sect1 = Section.new doc, 1, false)
  #   sect1.title = 'Section 1'
  #   para1 = Block.new sect1, :paragraph, :source => 'Paragraph 1'
  #   para2 = Block.new sect1, :paragraph, :source => 'Paragraph 2'
  #   sect1 << para1 << para2
  #   sect1 << (sect1_1 = Section.new sect1, 2, false)
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

  # Public: Check whether this block has any child Section objects.
  #
  # Only applies to Document and Section instances
  #
  # Returns A [Boolean] to indicate whether this block has child Section objects
  def sections?
    @next_section_index > 0
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

  # Public: Query for all descendant block nodes in the document tree that
  # match the specified Symbol filter_context and, optionally, the style and/or
  # role specified in the options Hash. If a block is provided, it's used as an
  # additional filter. If no filters are specified, all block nodes in the tree
  # are returned.
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
  # Returns An Array of block nodes that match the given selector or an empty Array if no matches are found
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

    # yuck, dlist is a special case
    unless context_selector == :document # optimization
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
  alias :query :find_by

  # Public: Remove a substitution from this block
  #
  # sub  - The Symbol substitution name
  #
  # Returns nothing
  def remove_sub sub
    @subs.delete sub
    nil
  end

  # Public: Generate a caption and assign it to this block if one
  # is not already assigned.
  #
  # If the block has a title and a caption prefix is available
  # for this block, then build a caption from this information,
  # assign it a number and store it to the caption attribute on
  # the block.
  #
  # If an explicit caption has been specified on this block, then
  # do nothing.
  #
  # key         - The prefix of the caption and counter attribute names.
  #               If not provided, the name of the context for this block
  #               is used. (default: nil).
  #
  # Returns nothing
  def assign_caption(caption = nil, key = nil)
    return unless title? || !@caption

    if caption
      @caption = caption
    else
      if (value = @document.attributes['caption'])
        @caption = value
      elsif title?
        key ||= @context.to_s
        caption_key = "#{key}-caption"
        if (caption_title = @document.attributes[caption_key])
          caption_num = @document.counter_increment("#{key}-number", self)
          @caption = "#{caption_title} #{caption_num}. "
        end
      end
    end
    nil
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

  # Internal: Assign the next index (0-based) to this section
  #
  # Assign the next index of this section within the parent
  # Block (in document order)
  #
  # Returns nothing
  def assign_index(section)
    section.index = @next_section_index
    @next_section_index += 1

    if section.sectname == 'appendix'
      appendix_number = @document.counter 'appendix-number', 'A'
      section.number = appendix_number if section.numbered
      if (caption = @document.attr 'appendix-caption', '').empty?
        section.caption = %(#{appendix_number}. )
      else
        section.caption = %(#{caption} #{appendix_number}: )
      end
    elsif section.numbered
      # chapters in a book doctype should be sequential even when divided into parts
      if (section.level == 1 || (section.level == 0 && section.special)) && @document.doctype == 'book'
        section.number = @document.counter('chapter-number', 1)
      else
        section.number = @next_section_number
        @next_section_number += 1
      end
    end
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
    @next_section_number = 0
    @blocks.each {|block|
      if block.context == :section
        assign_index(block)
        block.reindex_sections
      end
    }
  end
end
end
