# frozen_string_literal: true
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

  # Public: Get/Set the flag to indicate whether this section should be numbered.
  # The sectnum method should only be called if this flag is true.
  attr_accessor :numbered

  # Public: Get the caption for this section (only relevant for appendices)
  attr_reader :caption

  # Public: Initialize an Asciidoctor::Section object.
  #
  # parent   - The parent AbstractBlock. If set, must be a Document or Section object (default: nil)
  # level    - The Integer level of this section (default: 1 more than parent level or 1 if parent not defined)
  # numbered - A Boolean indicating whether numbering is enabled for this Section (default: false)
  # opts     - An optional Hash of options (default: {})
  def initialize parent = nil, level = nil, numbered = false, opts = {}
    super parent, :section, opts
    if Section === parent
      @level, @special = level || (parent.level + 1), parent.special
    else
      @level, @special = level || 1, false
    end
    @numbered = numbered
    @index = 0
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
  # The section number is a dot-separated String that uniquely describes the position of this
  # Section in the document. Each entry represents a level of nesting. The value of each entry is
  # the 1-based outline number of the Section amongst its numbered sibling Sections.
  #
  # This method assumes that both the @level and @parent instance variables have been assigned.
  # The method also assumes that the value of @parent is either a Document or Section.
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
    @level > 1 && Section === @parent ? %(#{@parent.sectnum(delimiter, delimiter)}#{@numeral}#{append}) : %(#{@numeral}#{append})
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
            quoted_title = sub_placeholder (sub_quotes '_%s_'), title
          else
            quoted_title = sub_placeholder (sub_quotes @document.compat_mode ? %q(``%s'') : '"`%s`"'), title
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
          (type = @sectname) == 'chapter' || type == 'appendix' ? (sub_placeholder (sub_quotes '_%s_'), title) : title
        end
      else # apply basic styling
        (type = @sectname) == 'chapter' || type == 'appendix' ? (sub_placeholder (sub_quotes '_%s_'), title) : title
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
    assign_numeral block if block.context == :section
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
  # is an underscore (_) by default. Invalid characters are then removed and
  # spaces are replaced with the value of the 'idseparator' attribute, which is
  # an underscore (_) by default.
  #
  # If the generated ID is already in use in the document, a count is appended,
  # offset by the separator, until a unique ID is found.
  #
  # Section ID generation can be disabled by unsetting the 'sectids' document attribute.
  #
  # Examples
  #
  #   Section.generate_id 'Foo', document
  #   => "_foo"
  #
  # Returns the generated [String] ID.
  def self.generate_id title, document
    attrs = document.attributes
    pre = attrs['idprefix'] || '_'
    if (sep = attrs['idseparator'])
      if sep.length == 1 || (!(no_sep = sep.empty?) && (sep = attrs['idseparator'] = sep.chr))
        sep_sub = sep == '-' || sep == '.' ? ' .-' : %( #{sep}.-)
      end
    else
      sep, sep_sub = '_', ' _.-'
    end
    gen_id = %(#{pre}#{title.downcase.gsub InvalidSectionIdCharsRx, ''})
    if no_sep
      gen_id = gen_id.delete ' '
    else
      # replace space with separator and remove repeating and trailing separator characters
      gen_id = gen_id.tr_s sep_sub, sep
      gen_id = gen_id.chop if gen_id.end_with? sep
      # ensure id doesn't begin with idseparator if idprefix is empty (assuming idseparator is not empty)
      gen_id = gen_id.slice 1, gen_id.length if pre.empty? && (gen_id.start_with? sep)
    end
    if document.catalog[:refs].key? gen_id
      ids = document.catalog[:refs]
      cnt = Compliance.unique_id_start_index
      cnt += 1 while ids[candidate_id = %(#{gen_id}#{sep}#{cnt})]
      candidate_id
    else
      gen_id
    end
  end
end
end
