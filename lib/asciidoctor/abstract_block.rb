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

  def initialize(parent, context)
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
  # Returns nothing.
  def <<(block)
    # parent assignment pending refactor
    #block.parent = self
    @blocks << block
  end

  # Public: Get the Array of child Section objects
  #
  # Only applies to Document and Section instances
  #
  # Examples
  # 
  #   section = Section.new(parent)
  #   section << Block.new(section, :paragraph, :source => 'paragraph 1')
  #   section << Section.new(parent)
  #   section << Block.new(section, :paragraph, :source => 'paragraph 2')
  #   section.blocks?
  #   # => true
  #   section.blocks.size
  #   # => 3
  #   section.sections.size
  #   # => 1
  #
  # Returns an [Array] of Section objects
  def sections
    @blocks.select {|block| block.context == :section }
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

  # Public: Calculates the reference text for this block.
  #
  # Use the value of the reftext attribute, if present.
  # Otherwise, use the title if specified, prefixed with the caption.
  # If neither the reftext attribute nor title are present, return nil.
  #
  # Returns a String Array containing the reference text and, if present, the formal reference text, for this block.
  #--
  # TODO sub reftext
  # FIXME admonition blocks abuse the caption field
  def resolve_reftext
    if (reftext = @attributes['reftext'])
      [reftext]
    elsif @title.nil_or_empty?
      []
    elsif @caption && @context != :admonition && (@document.attr? 'xrefstyle', 'formal')
      [(reftext = title), %(#{@caption.rstrip.chomp '.'}, &#8220;#{reftext}&#8221;)]
    else
      [title]
    end
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
      if (caption = @document.attr 'appendix-caption', '') != ''
        section.caption = %(#{caption} #{appendix_number}: )
      else
        section.caption = %(#{appendix_number}. )
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
