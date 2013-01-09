class Asciidoctor::AbstractBlock < Asciidoctor::AbstractNode
  # Public: Get the Array of Asciidoctor::AbstractBlock sub-blocks for this block
  attr_reader :blocks

  # Public: Get/Set the Integer section level in which this block resides
  # QUESTION should this be writable? and for Block, should it delegate to parent?
  attr_accessor :level

  def initialize(parent, context)
    super(parent, context)
    @blocks = []
    @id = nil
    @level = (context == :document ? 0 : nil)
    @next_section_index = 0 
  end

  # Public: Determine whether this Block contains block content
  #
  # returns Whether this Block has block content
  #
  #--
  # TODO we still need another method that answers
  # whether this Block *can* have block content
  # that should be the option 'sectionbody'
  def has_section_body?
    !blocks.empty?
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
    if block.is_a?(Asciidoctor::Section)
      assign_index(block)
    end
    @blocks << block
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
      collector << block if block.is_a?(Asciidoctor::Section)
      collector
    }
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
    @blocks.each {|block|
      if block.is_a?(Asciidoctor::Section)
        assign_index(block)
        block.reindex_sections
      end
    }
  end
end
