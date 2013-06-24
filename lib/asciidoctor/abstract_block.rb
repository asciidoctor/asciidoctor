module Asciidoctor
class AbstractBlock < AbstractNode
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
    super(parent, context)
    @blocks = []
    @id = nil
    @title = nil
    @caption = nil
    @style = nil
    if context == :document
      @level = 0
    elsif !parent.nil? && !self.is_a?(Section)
      @level = parent.level
    else
      @level = nil
    end
    @next_section_index = 0
    @next_section_number = 1
  end

  # Public: A convenience method that indicates whether the title instance
  # variable is blank (nil or empty)
  def title?
    !@title.to_s.empty?
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
  # returns Whether this Block has block content
  #
  #--
  # TODO we still need another method that answers
  # whether this Block *can* have block content
  # that should be the option 'sectionbody'
  def blocks?
    !@blocks.empty?
  end

  # Public: Get the element at i in the array of blocks.
  #
  # i - The Integer array index number.
  #
  #   section = Section.new
  #
  #   section << 'foo'
  #   section << 'bar'
  #   section[1]
  #   => "bar"
  def [](i)
    @blocks[i]
  end

  # Public: Append a content block to this block's list of blocks.
  #
  # block - The new child block.
  #
  # Examples
  #
  #   block = Block.new(parent, :preamble)
  #
  #   block << Block.new(block, :paragraph, 'p1')
  #   block << Block.new(block, :paragraph, 'p2')
  #   block.blocks
  #   # => ["p1", "p2"]
  #
  # Returns nothing.
  def <<(block)
    if block.is_a?(Section)
      assign_index(block)
    end
    @blocks << block
  end

  # Public: Insert a content block at the specified index in this block's
  # list of blocks.
  #
  # i - The Integer array index number.
  # val = The content block to insert.
  #
  #   section = Section.new
  #
  #   section << 'foo'
  #   section << 'baz'
  #   section.insert(1, 'bar')
  #   section.blocks
  #   ["foo", "bar", "baz"]
  def insert(i, block)
    @blocks.insert(i, block)
  end

  # Public: Delete the element at i in the array of section blocks,
  # returning that element or nil if i is out of range.
  #
  # i - The Integer array index number.
  #
  #   section = Section.new
  #
  #   section << 'foo'
  #   section << 'bar'
  #   section.delete_at(1)
  #   => "bar"
  #
  #   section.blocks
  #   => ["foo"]
  def delete_at(i)
    @blocks.delete_at(i)
  end

  # Public: Clear this Block's list of blocks.
  #
  #   section = Section.new
  #
  #   section << 'foo'
  #   section << 'bar'
  #   section.blocks
  #   => ["foo", "bar"]
  #   section.clear_blocks
  #   section.blocks
  #   => []
  def clear_blocks
    @blocks = []
  end

  # Public: Get the Integer number of blocks in this block
  #
  # Examples
  #
  #   section = Section.new
  #
  #   section.size
  #   => 0
  #
  #   section << 'foo'
  #   section << 'bar'
  #   section.size
  #   => 2
  def size
    @blocks.size
  end

  # Public: Get the Array of child Section objects
  #
  # Only applies to Document and Section instances
  #
  # Examples
  # 
  #   section = Section.new(parent)
  #   section << Block.new(section, :paragraph, 'paragraph 1')
  #   section << Section.new(parent)
  #   section << Block.new(section, :paragraph, 'paragraph 2')
  #   section.sections.size
  #   # => 1
  #
  # returns an Array of Section objects
  def sections
    @blocks.inject([]) {|collector, block|
      collector << block if block.is_a?(Section)
      collector
    }
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
  # returns nothing
  def assign_caption(caption = nil, key = nil)
    unless title? || @caption.nil?
      return nil
    end

    if caption.nil?
      if @document.attr?('caption')
        @caption = @document.attr('caption')
      elsif title?
        key ||= @context.to_s
        caption_key = "#{key}-caption"
        if @document.attributes.has_key?(caption_key)
          caption_title = @document.attributes["#{key}-caption"]
          caption_num = @document.counter_increment("#{key}-number", self)
          @caption = "#{caption_title} #{caption_num}. "
        end
      else
        @caption = caption
      end
    else
      @caption = caption
    end
    nil
  end

  # Internal: Assign the next index (0-based) to this section
  #
  # Assign the next index of this section within the parent
  # Block (in document order)
  #
  # returns nothing
  def assign_index(section)
    section.index = @next_section_index
    @next_section_index += 1
    if section.numbered
      section.number = @next_section_number
      @next_section_number += 1
    end
  end

  # Internal: Reassign the section indexes
  #
  # Walk the descendents of the current Document or Section
  # and reassign the section 0-based index value to each Section
  # as it appears in document order.
  # 
  # returns nothing
  def reindex_sections
    @next_section_index = 0
    @next_section_number = 0
    @blocks.each {|block|
      if block.is_a?(Section)
        assign_index(block)
        block.reindex_sections
      end
    }
  end
end
end
