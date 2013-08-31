module Asciidoctor
class AbstractBlock < AbstractNode
  # Public: The types of content that this block can accomodate
  attr_accessor :content_model

  # Public: Substitutions to be applied to content in this block
  attr_reader :subs

  # Public: Get/Set the String name of the render template
  attr_accessor :template_name

  # Public: Get the Array of Asciidoctor::AbstractBlock sub-blocks for this block
  attr_reader :blocks

  # Public: Set the Integer level of this Section or the Section level in which this Block resides
  attr_accessor :level

  # Public: Set the String block title.
  attr_writer :title

  # Public: Get/Set the String style (block type qualifier) for this block.
  attr_accessor :style

  # Public: Get/Set the caption for this block
  attr_accessor :caption

  def initialize(parent, context)
    super(parent, context)
    @content_model = :compound
    @subs = []
    @template_name = "block_#{context}"
    @blocks = []
    @id = nil
    @title = nil
    @caption = nil
    @style = nil
    if context == :document
      @level = 0
    elsif !parent.nil? && !self.is_a?(Section)
      @level = parent.level
    else
      @level = nil
    end
    @next_section_index = 0
    @next_section_number = 1
  end

  # Public: Get the rendered String content for this Block.  If the block
  # has child blocks, the content method should cause them to be
  # rendered and returned as content that can be included in the
  # parent block's template.
  def render
    @document.playback_attributes @attributes
    renderer.render(@template_name, self)
  end

  # Public: Get an rendered version of the block content, rendering the
  # children appropriate to content model that this block supports.
  def content
    @blocks.map {|b| b.render } * EOL
  end

  # Public: A convenience method that checks whether the specified
  # substitution is enabled for this block.
  #
  # name - The Symbol substitution name
  #
  # Returns A Boolean indicating whether the specified substitution is
  # enabled for this block
  def sub? name
    @subs.include? name
  end

  # Public: A convenience method that indicates whether the title instance
  # variable is blank (nil or empty)
  def title?
    !@title.to_s.empty?
  end

  # Public: Get the String title of this Block with title substitions applied
  #
  # The following substitutions are applied to block and section titles:
  #
  # :specialcharacters, :quotes, :replacements, :macros, :attributes and :post_replacements
  #
  # Examples
  #
  #   block.title = "Foo 3^ # {two-colons} Bar(1)"
  #   block.title
  #   => "Foo 3^ # :: Bar(1)"
  #
  # Returns the String title of this Block
  def title
    # prevent substitutions from being applied multiple times
    if defined?(@subbed_title)
      @subbed_title
    elsif @title
      @subbed_title = apply_title_subs(@title)
    else
      @title
    end
  end

  # Public: Convenience method that returns the interpreted title of the Block
  # with the caption prepended.
  #
  # Concatenates the value of this Block's caption instance variable and the
  # return value of this Block's title method. No space is added between the
  # two values. If the Block does not have a caption, the interpreted title is
  # returned.
  #
  # Returns the String title prefixed with the caption, or just the title if no
  # caption is set
  def captioned_title
    %(#{@caption}#{title})
  end

  # Public: Determine whether this Block contains block content
  #
  # Returns A Boolean indicating whether this Block has block content
  def blocks?
    !@blocks.empty?
  end

  # Public: Append a content block to this block's list of blocks.
  #
  # block - The new child block.
  #
  # Examples
  #
  #   block = Block.new(parent, :preamble, :content_model => :compound)
  #
  #   block << Block.new(block, :paragraph, :source => 'p1')
  #   block << Block.new(block, :paragraph, :source => 'p2')
  #   block.blocks?
  #   # => true
  #   block.blocks.size
  #   # => 2
  #
  # Returns nothing.
  def <<(block)
    # parent assignment pending refactor
    #block.parent = self
    @blocks << block
  end

  # Public: Get the Array of child Section objects
  #
  # Only applies to Document and Section instances
  #
  # Examples
  # 
  #   section = Section.new(parent)
  #   section << Block.new(section, :paragraph, :source => 'paragraph 1')
  #   section << Section.new(parent)
  #   section << Block.new(section, :paragraph, :source => 'paragraph 2')
  #   section.blocks?
  #   # => true
  #   section.blocks.size
  #   # => 3
  #   section.sections.size
  #   # => 1
  #
  # returns an Array of Section objects
  def sections
    @blocks.inject([]) {|collector, block|
      collector << block if block.is_a?(Section)
      collector
    }
  end

  # Internal: Lock-in the substitutions for this block
  #
  # Looks for an attribute named "subs". If present, resolves the
  # substitutions and assigns it to the subs property on this block.
  # Otherwise, assigns a set of default substitutions based on the
  # content model of the block.
  #
  # Returns nothing
  def lock_in_subs
    default_subs = []
    case @content_model
    when :simple
      default_subs = SUBS[:normal]
    when :verbatim
      if @context == :listing || (@context == :literal && !(option? 'listparagraph'))
        default_subs = SUBS[:verbatim]
      else
        default_subs = SUBS[:basic]
      end
    when :raw
      default_subs = SUBS[:pass]
    else
      return
    end

    if (custom_subs = @attributes['subs'])
      @subs = resolve_block_subs custom_subs, @context
    else
      @subs = default_subs.dup
    end

    # QUESION delegate this logic to method?
    if @context == :listing && @style == 'source' && (@document.basebackend? 'html') &&
      ((highlighter = @document.attributes['source-highlighter']) == 'coderay' ||
      highlighter == 'pygments') && (attr? 'language')
      @subs = @subs.map {|sub| sub == :specialcharacters ? :highlight : sub }
    end
  end

  # Public: Remove a substitution from this block
  #
  # sub  - The Symbol substitution name
  #
  # Returns nothing
  def remove_sub sub
    @subs.delete sub
    nil
  end

  # Public: Generate a caption and assign it to this block if one
  # is not already assigned.
  #
  # If the block has a title and a caption prefix is available
  # for this block, then build a caption from this information,
  # assign it a number and store it to the caption attribute on
  # the block.
  #
  # If an explicit caption has been specified on this block, then
  # do nothing.
  #
  # key         - The prefix of the caption and counter attribute names.
  #               If not provided, the name of the context for this block
  #               is used. (default: nil).
  #
  # returns nothing
  def assign_caption(caption = nil, key = nil)
    unless title? || @caption.nil?
      return nil
    end

    if caption.nil?
      if @document.attributes.has_key? 'caption'
        @caption = @document.attributes['caption']
      elsif title?
        key ||= @context.to_s
        caption_key = "#{key}-caption"
        if @document.attributes.has_key? caption_key
          caption_title = @document.attributes["#{key}-caption"]
          caption_num = @document.counter_increment("#{key}-number", self)
          @caption = "#{caption_title} #{caption_num}. "
        end
      else
        @caption = caption
      end
    else
      @caption = caption
    end
    nil
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
    if section.numbered
      section.number = @next_section_number
      @next_section_number += 1
    end
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
    @next_section_number = 0
    @blocks.each {|block|
      if block.is_a?(Section)
        assign_index(block)
        block.reindex_sections
      end
    }
  end
end
end
