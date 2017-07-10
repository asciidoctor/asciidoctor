# encoding: UTF-8
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

  # Public: Get/Set the section name of this section
  attr_accessor :sectname

  # Public: Get/Set the flag to indicate whether this is a special section or a child of one
  attr_accessor :special

  # Public: Get the state of the numbered attribute at this section (need to preserve for creating TOC)
  attr_accessor :numbered

  # Public: Get the caption for this section (only relevant for appendices)
  attr_reader :caption

  # Public: Initialize an Asciidoctor::Section object.
  #
  # parent - The parent Asciidoc Object.
  def initialize parent = nil, level = nil, numbered = true, opts = {}
    super parent, :section, opts
    @level = level ? level : (parent ? (parent.level + 1) : 1)
    @numbered = numbered && @level > 0
    @special = parent && parent.context == :section && parent.special
    @index = 0
    @number = 1
  end

  # Public: The name of this section, an alias of the section title
  alias name title

  # Public: Generate a String ID from the title of this section.
  #
  # See Section.generate_id for details.
  def generate_id
    Section.generate_id title, @document
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
    if @level && @level > 1 && @parent && @parent.context == :section
      %(#{@parent.sectnum(delimiter)}#{@number}#{append})
    else
      %(#{@number}#{append})
    end
  end

  # (see AbstractBlock#xreftext)
  def xreftext xrefstyle = nil
    if (val = reftext) && !val.empty?
      val
    elsif xrefstyle
      if @numbered
        case xrefstyle
        when 'full'
          if (type = @sectname) == 'chapter' || type == 'appendix'
            quoted_title = sprintf sub_quotes('_%s_'), title
          else
            quoted_title = sprintf sub_quotes(@document.compat_mode ? %q(``%s'') : '"`%s`"'), title
          end
          if (signifier = @document.attributes[%(#{type}-refsig)])
            %(#{signifier} #{sectnum '.', ','} #{quoted_title})
          else
            %(#{sectnum '.', ','} #{quoted_title})
          end
        when 'short'
          if (signifier = @document.attributes[%(#{@sectname}-refsig)])
            %(#{signifier} #{sectnum '.', ''})
          else
            sectnum '.', ''
          end
        else # 'basic'
          (type = @sectname) == 'chapter' || type == 'appendix' ? (sprintf sub_quotes('_%s_'), title) : title
        end
      else # apply basic styling
        (type = @sectname) == 'chapter' || type == 'appendix' ? (sprintf sub_quotes('_%s_'), title) : title
      end
    else
      title
    end
  end

  # Public: Append a content block to this block's list of blocks.
  #
  # If the child block is a Section, assign an index to it.
  #
  # block - The child Block to append to this parent Block
  #
  # Returns The parent Block
  def << block
    enumerate_section block if block.context == :section
    super
  end

  def to_s
    if @title
      formal_title = @numbered ? %(#{sectnum} #{@title}) : @title
      %(#<#{self.class}@#{object_id} {level: #{@level}, title: #{formal_title.inspect}, blocks: #{@blocks.size}}>)
    else
      super
    end
  end

  # Public: Generate a String ID from the given section title.
  #
  # The generated ID is prefixed with value of the 'idprefix' attribute, which
  # is an underscore by default. Invalid characters are replaced with the
  # value of the 'idseparator' attribute, which is an underscore by default.
  #
  # If the generated ID is already in use in the document, a count is appended
  # until a unique id is found.
  #
  # Section ID generation can be disabled by undefining the 'sectids' attribute.
  #
  # Examples
  #
  #   Section.generate_id 'Foo', document
  #   => "_foo"
  #
  def self.generate_id title, document
    attrs = document.attributes
    sep = attrs['idseparator'] || '_'
    pre = attrs['idprefix'] || '_'
    gen_id = %(#{pre}#{title.downcase.gsub InvalidSectionIdCharsRx, sep})
    unless sep.empty?
      # remove repeat and trailing separator characters
      gen_id = gen_id.tr_s sep, sep
      gen_id = gen_id.chop if gen_id.end_with? sep
      # ensure id doesn't begin with idseparator if idprefix is empty and idseparator is not empty
      if pre.empty?
        gen_id = gen_id.slice 1, gen_id.length while gen_id.start_with? sep
      end
    end
    if document.catalog[:ids].key? gen_id
      ids, cnt = document.catalog[:ids], Compliance.unique_id_start_index
      cnt += 1 while ids.key?(candidate_id = %(#{gen_id}#{sep}#{cnt}))
      candidate_id
    else
      gen_id
    end
  end
end
end
