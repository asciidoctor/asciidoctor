module Asciidoctor
# Public: Methods for managing AsciiDoc lists (ordered, unordered and labeled lists)
class List < AbstractBlock

  # Public: Create alias for blocks
  alias :items :blocks
  alias :items? :blocks?

  def initialize parent, context
    super
  end

  # Public: Get the items in this list as an Array
  def content
    @blocks
  end

  def convert
    if @context == :colist
      result = super
      @document.callouts.next_list
      result
    else
      super
    end
  end

  # Alias render to convert to maintain backwards compatibility
  alias :render :convert

  def to_s
    %(#<#{self.class}@#{object_id} {context: #{@context.inspect}, style: #{@style.inspect}, items: #{items.size}}>)
  end

end

# Public: Methods for managing items for AsciiDoc olists, ulist, and dlists.
class ListItem < AbstractBlock

  # Public: Get/Set the String used to mark this list item
  attr_accessor :marker

  # Public: Initialize an Asciidoctor::ListItem object.
  #
  # parent - The parent list block for this list item
  # text - the String text (default nil)
  def initialize parent, text = nil
    super parent, :list_item
    @text = text
    @level = parent.level
  end

  def text?
    !@text.nil_or_empty?
  end

  def text
    apply_subs @text
  end

  # Public: Fold the first paragraph block into the text
  #
  # Here are the rules for when a folding occurs:
  #
  # Given: this list item has at least one block
  # When: the first block is a paragraph that's not connected by a list continuation
  # Or: the first block is an indented paragraph that's adjacent (wrapped line)
  # Or: the first block is an indented paragraph that's not connected by a list continuation
  # Then: then drop the first block and fold it's content (buffer) into the list text
  #
  # Returns nothing
  def fold_first(continuation_connects_first_block = false, content_adjacent = false)
    if (first_block = @blocks[0]) && first_block.is_a?(Block) &&
        ((first_block.context == :paragraph && !continuation_connects_first_block) ||
        ((content_adjacent || !continuation_connects_first_block) && first_block.context == :literal &&
            first_block.option?('listparagraph')))

      block = blocks.shift
      block.lines.unshift @text unless @text.nil_or_empty?
      @text = block.source
    end
    nil
  end

  def to_s
    %(#<#{self.class}@#{object_id} {list_context: #{parent.context.inspect}, text: #{@text.inspect}, blocks: #{(@blocks || []).size}}>)
  end

end
end
