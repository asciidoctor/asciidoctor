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
    @template_name = 'section'
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
  #
  #   yet_another_section = Section.new(parent)
  #   yet_another_section.title = "Ben & Jerry"
  #   yet_another_section.generate_id
  #   => "_ben_jerry"
  def generate_id
    if @document.attributes.has_key? 'sectids'
      sep = @document.attributes['idseparator'] || '_'
      pre = @document.attributes['idprefix'] || '_'
      base_id = %(#{pre}#{title.downcase.gsub(REGEXP[:illegal_sectid_chars], sep).tr_s(sep, sep).chomp(sep)})
      # ensure id doesn't begin with idprefix if requested it doesn't
      if pre.empty? && base_id.start_with?(sep)
        base_id = base_id[1..-1]
        base_id = base_id[1..-1] while base_id.start_with?(sep)
      end
      gen_id = base_id
      cnt = 2
      while @document.references[:ids].has_key? gen_id
        gen_id = "#{base_id}#{sep}#{cnt}"
        cnt += 1
      end 
      gen_id
    else
      nil
    end
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

  # Public: Append a content block to this block's list of blocks.
  #
  # If the child block is a Section, assign an index to it.
  #
  # block - The child Block to append to this parent Block
  #
  # Returns nothing.
  def <<(block)
    super
    if block.context == :section
      assign_index block
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
