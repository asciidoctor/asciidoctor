# frozen_string_literal: true
module Asciidoctor
# Public: Methods for managing AsciiDoc lists (ordered, unordered and description lists)
class List < AbstractBlock

  # Public: Create alias for blocks
  alias items blocks
  # Public: Get the items in this list as an Array
  alias content blocks
  # Public: Create alias to check if this list has blocks
  alias items? blocks?

  def initialize parent, context, opts = {}
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

  # Deprecated: Use {List#convert} instead.
  alias render convert

  def to_s
    %(#<#{self.class}@#{object_id} {context: #{@context.inspect}, style: #{@style.inspect}, items: #{items.size}}>)
  end

end

# Public: Methods for managing items for AsciiDoc olists, ulist, and dlists.
#
# In a description list (dlist), each item is a tuple that consists of a 2-item Array of ListItem terms and a ListItem
# description (i.e., [[term, term, ...], desc]. If a description is not set, then the second entry in the tuple is nil.
class ListItem < AbstractBlock

  # A contextual alias for the list parent node; counterpart to the items alias on List
  alias list parent

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
    @subs = NORMAL_SUBS.drop 0
  end

  # Public: A convenience method that checks whether the text of this list item
  # is not blank (i.e., not nil or empty string).
  def text?
    @text.nil_or_empty? ? false : true
  end

  # Public: Get the String text of this ListItem with substitutions applied.
  #
  # By default, normal substitutions are applied to the text. The substitutions
  # can be modified by altering the subs property of this object.
  #
  # Returns the converted String text for this ListItem
  def text
    # NOTE @text can be nil if dd node only has block content
    @text && (apply_subs @text, @subs)
  end

  # Public: Set the String text.
  #
  # Returns the new String text assigned to this ListItem
  def text= val
    @text = val
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

  # Internal: Fold the adjacent paragraph block into the list item text
  #
  # Returns nothing
  def fold_first
    @text = @text.nil_or_empty? ? @blocks.shift.source : %(#{@text}#{LF}#{@blocks.shift.source})
    nil
  end

  def to_s
    %(#<#{self.class}@#{object_id} {list_context: #{parent.context.inspect}, text: #{@text.inspect}, blocks: #{(@blocks || []).size}}>)
  end
end
end
