# Public: Methods for managing sections of AsciiDoc content in a document.
# The section responds as an Array of content blocks by delegating
# block-related methods to its @blocks Array.
#
# Examples
#
#   section = Asciidoctor::Section.new
#   section.title = 'DESCRIPTION'
#   section.anchor = 'DESCRIPTION'
#
#   section.size
#   => 0
#
#   section.id
#   => "description"
#
#   section << new_block
#   section.size
#   => 1
class Asciidoctor::Section
  # Public: Get/Set the Integer section level.
  attr_accessor :level

  # Public: Set the String section title.
  attr_writer :title

  # Public: Get/Set the String section caption.
  attr_accessor :caption

  # Public: Get/Set the String section anchor name.
  attr_accessor :anchor
  alias :id :anchor

  # Public: Get the Hash of attributes for this block
  attr_accessor :attributes

  # Public: Get the Array of section blocks.
  attr_reader :blocks

  # Public: Get the parent (Section or Document) of this Section
  attr_reader :parent

  # Public: Initialize an Asciidoctor::Section object.
  #
  # parent - The parent Asciidoc Object.
  def initialize(parent)
    @parent = parent
    @document = @parent.is_a?(Asciidoctor::Document) ? @parent : @parent.document
    @attributes = {}
    @blocks = []
    @name = nil
  end

  # Public: Get the String section title with intrinsics converted
  #
  # Examples
  #
  #   section.title = "Foo 3^ # {litdd} Bar(1)"
  #   section.title
  #   => "Foo 3^ # -- Bar(1)"
  #
  # Returns the String section title
  def title
    @title && 
    @title.gsub(/(^|[^\\])\{(\w[\w\-]+\w)\}/) { $1 + (attr?($2) ? attr($2) : Asciidoctor::INTRINSICS[$2]) }.
          gsub( /`([^`]+)`/, '<tt>\1</tt>' )
  end

  # Public: The name of this section, an alias of the section title
  def name
    title
  end

  # Public: Get the String section id prefixed with value of idprefix attribute, otherwise an underscore
  #
  # Section ID synthesis can be disabled by undefining the sectids attribute.
  #
  # Examples
  #
  #   section = Section.new(parent)
  #   section.title = "Foo"
  #   section.generate_id
  #   => "_foo"
  def generate_id
    if self.document.attributes.has_key? 'sectids'
      self.document.attributes.fetch('idprefix', '_') + "#{title && title.downcase.gsub(/\W+/,'_').gsub(/_+$/, '')}".tr_s('_', '_')
    else
      nil
    end
  end

  # Public: Get the Asciidoctor::Document instance to which this Block belongs
  def document
    @document
  end

  def attr(name, default = nil)
    default.nil? ? @attributes.fetch(name.to_s, self.document.attr(name)) :
        @attributes.fetch(name.to_s, self.document.attr(name, default))
  end

  def attr?(name)
    @attributes.has_key?(name.to_s) || self.document.attr?(name)
  end

  def update_attributes(attributes)
    @attributes.update(attributes)
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
      Asciidoctor.debug "Begin rendering block #{block.is_a?(Asciidoctor::Section) ? block.title : 'n/a'} #{block} (context: #{block.is_a?(Asciidoctor::Block) ? block.context : 'n/a' })"
      poo = block.render
      Asciidoctor.debug "===> Done rendering block #{block.is_a?(Asciidoctor::Section) ? block.title : 'n/a'} #{block} (context: #{block.is_a?(Asciidoctor::Block) ? block.context : 'n/a' })"
      poo
    end.join
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
