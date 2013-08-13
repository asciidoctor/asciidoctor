module Asciidoctor
# Public: Methods for managing blocks of Asciidoc content in a section.
#
# Examples
#
#   block = Asciidoctor::Block.new(document, :paragraph, ["`This` is a <test>"])
#   block.content
#   => ["<em>This</em> is a &lt;test&gt;"]
class Block < AbstractBlock

  # Public: Create alias for context to be consistent w/ AsciiDoc
  alias :blockname :context

  # Public: The types of content that this block can accomodate
  attr_accessor :content_model

  # Public: Get/Set the original Array content for this block, if applicable
  attr_accessor :lines

  # Public: Initialize an Asciidoctor::Block object.
  #
  # parent  - The parent Asciidoc Object.
  # context - The Symbol context name for the type of content.
  # buffer  - The Array buffer of source data (default: nil).
  #
  def initialize(parent, context, content_model = :compound, attributes = nil, lines = nil)
    super(parent, context)
    @content_model = content_model
    @attributes = attributes.nil? ? {} : attributes
    # QUESTION should we store lines for blocks with compound content models?
    if content_model != :compound && lines.nil?
      @lines = []
    else
      @lines = lines
    end
  end

  # Public: Get an rendered version of the block content, performing
  # any substitutions on the content.
  #
  # Examples
  #
  #   doc = Asciidoctor::Document.new
  #   block = Asciidoctor::Block.new(doc, :paragraph, :simple, nil,
  #             ['_This_ is what happens when you <meet> a stranger in the <alps>!'])
  #   block.content
  #   => ["<em>This</em> is what happens when you &lt;meet&gt; a stranger in the &lt;alps&gt;!"]
  def content
    case @content_model
    when :simple
      apply_para_subs(@lines)
    when :compound
      super
    when :verbatim
      apply_literal_subs(@lines)
    when :raw
      apply_passthrough_subs(@lines)
    else
      # QUESTION issue a warning?
      ''
    end
  end

  # Public: Returns the preprocessed source of this block
  #
  # Returns the a String containing the lines joined together or nil if there
  # are no lines
  def source
    @lines.nil? ? nil : @lines.join
  end

  def to_s
    "#@context [blocks:#{(@blocks || []).size}]"
  end
end
end
