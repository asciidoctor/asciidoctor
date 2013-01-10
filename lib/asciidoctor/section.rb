# Public: Methods for managing sections of AsciiDoc content in a document.
# The section responds as an Array of content blocks by delegating
# block-related methods to its @blocks Array.
#
# Examples
#
#   section = Asciidoctor::Section.new
#   section.title = 'Section 1'
#   section.id = 'sect1'
#
#   section.size
#   => 0
#
#   section.id
#   => "sect1"
#
#   section << new_block
#   section.size
#   => 1
class Asciidoctor::Section < Asciidoctor::AbstractBlock

  # Public: Set the String section title.
  attr_writer :title

  # Public: Get/Set the Integer index of this section within the parent block
  attr_accessor :index

  # Public: Initialize an Asciidoctor::Section object.
  #
  # parent - The parent Asciidoc Object.
  def initialize(parent = nil, level = nil)
    super(parent, :section)
    @title = nil
    if level.nil? && !parent.nil?
      @level = parent.level + 1
    end
    @index = 0
  end

  # Public: Get the String section title with intrinsics converted
  #
  # Examples
  #
  #   section.title = "Foo 3^ # {two-colons} Bar(1)"
  #   section.title
  #   => "Foo 3^ # :: Bar(1)"
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
    if !title.to_s.empty? && document.attr?('sectids')
      document.attr('idprefix', '_') + title.downcase.gsub(/&#[0-9]+;/, '_').
          gsub(/\W+/, '_').tr_s('_', '_').gsub(/^_?(.*?)_?$/, '\1')
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
      block_content = block.render
      Asciidoctor.debug "===> Done rendering block #{block.is_a?(Asciidoctor::Section) ? block.title : 'n/a'} #{block} (context: #{block.is_a?(Asciidoctor::Block) ? block.context : 'n/a' })"
      block_content
    end.join
  end

  # Public: Get the section number for the current Section
  #
  # The section number is a unique, dot separated String
  # where each entry represents one level of nesting and
  # the value of each entry is the 1-based index of
  # the Section amongst its sibling Sections
  #
  # delimiter - the delimiter to separate the number for each level
  # append    - the String to append at the end of the section number
  #             or Boolean to indicate the delimiter should not be
  #             appended to the final level
  #             (default: nil)
  #
  # Examples
  #
  #   sect1 = Section.new(document)
  #   sect1.level = 1
  #   sect1_1 = Section.new(sect1)
  #   sect1_1.level = 2
  #   sect1_2 = Section.new(sect1)
  #   sect1_2.level = 2
  #   sect1 << sect1_1
  #   sect1 << sect1_2
  #   sect1_1_1 = Section.new(sect1_1)
  #   sect1_1_1.level = 3
  #   sect1_1 << sect1_1_1
  #
  #   sect1.sectnum
  #   # => 1.
  #
  #   sect1_1.sectnum
  #   # => 1.1.
  #
  #   sect1_2.sectnum
  #   # => 1.2.
  #
  #   sect1_1_1.sectnum
  #   # => 1.1.1.
  #
  #   sect1_1_1.sectnum(',', false)
  #   # => 1,1,1
  #
  # Returns the section number as a String
  def sectnum(delimiter = '.', append = nil)
    append ||= (append == false ? '' : delimiter)
    if !@level.nil? && @level > 1 && @parent.is_a?(::Asciidoctor::Section)
      "#{@parent.sectnum(delimiter)}#{@index + 1}#{append}"
    else
      "#{@index + 1}#{append}"
    end
  end

  def to_s
    if @title
      if @level && @index
        %[#{super.to_s} - #{sectnum} #@title [blocks:#{@blocks.size}]]
      else
        %[#{super.to_s} - #@title [blocks:#{@blocks.size}]]
      end
    else
      super.to_s
    end
  end
end
