class Asciidoctor::AbstractBlock < Asciidoctor::AbstractNode
  # Public: Get/Set the String list item anchor name.
  # deprecated, use id instead
  alias :anchor :id

  # Public: Get the Array of Asciidoctor::AbstractBlock sub-blocks for this block
  attr_reader :blocks

  # Public: Get/Set the Integer section level in which this block resides
  # QUESTION should this be writable? and for Block, should it delegate to parent?
  attr_accessor :level

  # Public: Get/Set the caption for this block
  attr_accessor :caption

  def initialize(parent, context)
    super(parent, context)
    @blocks = []
    @id = nil
    @level = nil
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
    @blocks << block
  end
end
