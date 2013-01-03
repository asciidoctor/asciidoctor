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
class Asciidoctor::Section < Asciidoctor::AbstractBlock

  # Public: Set the String section title.
  attr_writer :title

  # Public: Initialize an Asciidoctor::Section object.
  #
  # parent - The parent Asciidoc Object.
  def initialize(parent)
    super(parent, :section)
    @title = nil
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
    # prevent from rendering multiple times
    if defined?(@processed_title)
      @processed_title
    elsif @title
      @processed_title = apply_title_subs(@title)
    else
      @title
    end
  end

  # Public: The name of this section, an alias of the section title
  def name
    title
  end

  # Public: Get the String section id prefixed with value of idprefix attribute, otherwise an underscore
  #
  # Section ID synthesis can be disabled by undefining the sectids attribute.
  #
  # TODO document the substitutions
  #
  # Examples
  #
  #   section = Section.new(parent)
  #   section.title = "Foo"
  #   section.generate_id
  #   => "_foo"
  def generate_id
    if self.document.attributes.has_key? 'sectids'
      (self.document.attributes.fetch('idprefix', '_') +
          (title ? title.downcase.gsub(/&#[0-9]+;/, '_').gsub(/\W+/, '_').trim('_').tr_s('_', '_') : ''))
    else
      nil
    end
  end

  # Public: Get the rendered String content for this Section and all its child
  # Blocks.
  def render
    Asciidoctor.debug "Now rendering section for #{self}"
    renderer.render(@context.to_s, self)
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
