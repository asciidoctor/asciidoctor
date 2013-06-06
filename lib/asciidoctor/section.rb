module Asciidoctor
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
class Section < AbstractBlock

  # Public: Get/Set the 0-based index order of this section within the parent block
  attr_accessor :index

  # Public: Get/Set the number of this section within the parent block
  # Only relevant if the attribute numbered is true
  attr_accessor :number

  # Public: Get/Set the section name of this section
  attr_accessor :sectname

  # Public: Get/Set the flag to indicate whether this is a special section or a child of one
  attr_accessor :special

  # Public: Get the state of the numbered attribute at this section (need to preserve for creating TOC)
  attr_accessor :numbered

  # Public: Initialize an Asciidoctor::Section object.
  #
  # parent - The parent Asciidoc Object.
  def initialize(parent = nil, level = nil, numbered = true)
    super(parent, :section)
    if level.nil?
      if !parent.nil?
        @level = parent.level + 1
      elsif @level.nil?
        @level = 1
      end
    else
      @level = level
    end
    @numbered = numbered && @level > 0 && @level < 4
    @special = parent.is_a?(Section) && parent.special
    @index = 0
    @number = 1
  end

  # Public: The name of this section, an alias of the section title
  alias :name :title

  # Public: Generate a String id for this section.
  #
  # The generated id is prefixed with value of the 'idprefix' attribute, which
  # is an underscore by default.
  #
  # Section id synthesis can be disabled by undefining the 'sectids' attribute.
  #
  # If the generated id is already in use in the document, a count is appended
  # until a unique id is found.
  #
  # Examples
  #
  #   section = Section.new(parent)
  #   section.title = "Foo"
  #   section.generate_id
  #   => "_foo"
  #
  #   another_section = Section.new(parent)
  #   another_section.title = "Foo"
  #   another_section.generate_id
  #   => "_foo_1"
  def generate_id
    if @document.attr? 'sectids'
      separator = @document.attr('idseparator', '_')
      # FIXME define constants for these regexps
      base_id = @document.attr('idprefix', '_') + title.downcase.gsub(/&#[0-9]+;/, separator).
          gsub(/\W+/, separator).tr_s(separator, separator).chomp(separator)
      gen_id = base_id
      cnt = 2
      while @document.references[:ids].has_key? gen_id 
        gen_id = "#{base_id}#{separator}#{cnt}" 
        cnt += 1
      end 
      gen_id
    else
      nil
    end
  end

  # Public: Get the rendered String content for this Section and all its child
  # Blocks.
  def render
    @document.playback_attributes @attributes
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
    @blocks.map {|b| b.render }.join
  end

  # Public: Get the section number for the current Section
  #
  # The section number is a unique, dot separated String
  # where each entry represents one level of nesting and
  # the value of each entry is the 1-based outline number
  # of the Section amongst its numbered sibling Sections
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
    if !@level.nil? && @level > 1 && @parent.is_a?(Section)
      "#{@parent.sectnum(delimiter)}#{@number}#{append}"
    else
      "#{@number}#{append}"
    end
  end

  def to_s
    if @title
      if @numbered
        %[#{super.to_s} - #{sectnum} #@title [blocks:#{@blocks.size}]]
      else
        %[#{super.to_s} - #@title [blocks:#{@blocks.size}]]
      end
    else
      super.to_s
    end
  end
end
end
