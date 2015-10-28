# encoding: UTF-8
module Asciidoctor
# Public: Methods for managing AsciiDoc lists (ordered, unordered and description lists)
class List < AbstractBlock

  # Public: Create alias for blocks
  alias :items :blocks
  # Public: Get the items in this list as an Array
  alias :content :blocks
  # Public: Create alias to check if this list has blocks
  alias :items? :blocks?

  def initialize parent, context
    super
  end

  # Check whether this list is an outline list (unordered or ordered).
  #
  # Return true if this list is an outline list. Otherwise, return false.
  def outline?
    @context == :ulist || @context == :olist
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

  # Check whether this list item has simple content (no nested blocks aside from a single outline list).
  # Primarily relevant for outline lists.
  #
  # Return true if the list item contains no blocks or it contains a single outline list. Otherwise, return false.
  def simple?
    @blocks.empty? || (@blocks.size == 1 && List === (blk = @blocks[0]) && blk.outline?)
  end

  # Check whether this list item has compound content (nested blocks aside from a single outline list).
  # Primarily relevant for outline lists.
  #
  # Return true if the list item contains blocks other than a single outline list. Otherwise, return false.
  def compound?
    !simple?
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
    if (first_block = @blocks[0]) && Block === first_block &&
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
