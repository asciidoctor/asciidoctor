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

  # Public: Get/Set the original Array content for this section block.
  attr_accessor :buffer

  # Public: Initialize an Asciidoctor::Block object.
  #
  # parent  - The parent Asciidoc Object.
  # context - The Symbol context name for the type of content.
  # buffer  - The Array buffer of source data (default: nil).

  def initialize(parent, context, buffer = nil)
    super(parent, context)
    @buffer = buffer
  end

  # Public: Get an rendered version of the block content, performing
  # any substitutions on the content.
  #
  # Examples
  #
  #   doc = Asciidoctor::Document.new
  #   block = Asciidoctor::Block.new(doc, :paragraph,
  #             ['`This` is what happens when you <meet> a stranger in the <alps>!'])
  #   block.content
  #   => ["<em>This</em> is what happens when you &lt;meet&gt; a stranger in the &lt;alps&gt;!"]
  def content
    case @context
    when :paragraph
      apply_para_subs(@buffer)
    when :preamble
      @blocks.map {|b| b.render }.join
    when :listing, :literal
      apply_literal_subs(@buffer)
    when :pass
      apply_passthrough_subs(@buffer)
    else
      if @blocks.size > 0
        @blocks.map {|b| b.render }.join
      elsif !@buffer.nil?
        apply_para_subs(@buffer)
      else
        nil
      end
    end
  end

  def to_s
    "#@context [blocks:#{(@blocks || []).size}]"
  end
end
end
