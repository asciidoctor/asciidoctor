# Public: Methods for managing sections of Asciidoc content in a document.
# The section responds as an Array of content blocks by delegating
# block-related methods to its @blocks Array.
#
# Examples
#
#   section = Asciidoctor::Section.new
#   section.name = 'DESCRIPTION'
#   section.anchor = 'DESCRIPTION'
#
#   section.size
#   => 0
#
#   section.section_id
#   => "_description"
#
#   section << new_block
#   section.size
#   => 1
class Asciidoctor::Section
  # Public: Get/Set the Integer section level.
  attr_accessor :level

  # Public: Set the String section name.
  attr_writer :name

  # Public: Get/Set the String section caption.
  attr_accessor :caption

  # Public: Get/Set the String section anchor name.
  attr_accessor :anchor

  # Public: Get the Array of section blocks.
  attr_reader :blocks

  # Public: Initialize an Asciidoctor::Section object.
  #
  # parent - The parent Asciidoc Object.
  def initialize(parent)
    @parent = parent
    @blocks = []
  end

  # Public: Get the String section name with intrinsics converted
  #
  # Examples
  #
  #   section.name = "git-web{litdd}browse(1) Manual Page"
  #   section.name
  #   => "git-web--browse(1) Manual Page"
  #
  # Returns the String section name
  def name
    @name && 
    @name.gsub(/(^|[^\\])\{(\w[\w\-]+\w)\}/) { $1 + Asciidoctor::INTRINSICS[$2] }.
          gsub( /`([^`]+)`/, '<tt>\1</tt>' )
  end

  # Public: Get the String section id prefixed with value of idprefix attribute, otherwise an underscore
  #
  # Examples
  #
  #   section = Section.new(parent)
  #   section.name = "Foo"
  #   section.section_id
  #   => "_foo"
  def section_id
    self.document.attributes.fetch('idprefix', '_') + "#{name && name.downcase.gsub(/\W+/,'_').gsub(/_+$/, '')}".tr_s('_', '_')
  end

  # Public: Get the Asciidoctor::Document instance to which this Block belongs
  def document
    @parent.is_a?(Asciidoctor::Document) ? @parent : @parent.document
  end

  # Public: Get the Asciidoctor::Renderer instance being used for the ancestor
  # Asciidoctor::Document instance.
  def renderer
    Asciidoctor.debug "Section#renderer:  Looking for my renderer up in #{@parent}"
    @parent.renderer
  end

  # Public: Get the rendered String content for this Section and all its child
  # Blocks.
  def render
    Asciidoctor.debug "Now rendering section for #{self}"
    renderer.render('section', self)
  end

  # Public: Get the String section content by aggregating rendered section blocks.
  #
  # Examples
  #
  #   section = Section.new
  #   section << 'foo'
  #   section << 'bar'
  #   section << 'baz'
  #   section.content
  #   "<div class=\"paragraph\"><p>foo</p></div>\n<div class=\"paragraph\"><p>bar</p></div>\n<div class=\"paragraph\"><p>baz</p></div>"
  def content
    @blocks.map do |block|
      Asciidoctor.debug "Begin rendering block #{block.is_a?(Asciidoctor::Section) ? block.name : 'n/a'} #{block} (context: #{block.is_a?(Asciidoctor::Block) ? block.context : 'n/a' })"
      poo = block.render
      Asciidoctor.debug "===> Done rendering block #{block.is_a?(Asciidoctor::Section) ? block.name : 'n/a'} #{block} (context: #{block.is_a?(Asciidoctor::Block) ? block.context : 'n/a' })"
      poo
    end.join
  end

  # Public: The title of this section, an alias of the section name
  def title
    @name
  end

  # Public: Get the Integer number of blocks in the section.
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

  # Public: Get the element at i in the array of section blocks.
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

  # Public: Append a content block to this section's list of blocks.
  #
  # block - The new section block.
  #
  #   section = Section.new
  #
  #   section << 'foo'
  #   section << 'bar'
  #   section.blocks
  #   => ["foo", "bar"]
  def <<(block)
    @blocks << block
  end

  # Public: Clear this Section's list of blocks.
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

  # Public: Insert a content block at the specified index in this section's
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

  # Public: Get the Integer index number of the first content block element
  # for which the provided block returns true.  Returns nil if no match is
  # found.
  #
  # block - A block that can be used to determine whether a supplied element
  #         is a match.
  #
  #   section = Section.new
  #
  #   section << 'foo'
  #   section << 'bar'
  #   section << 'baz'
  #   section.index{|el| el =~ /^ba/}
  #   => 1
  def index(&block)
    @blocks.index(&block)
  end
end
