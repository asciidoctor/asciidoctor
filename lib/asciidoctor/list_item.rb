module Asciidoctor
# Public: Methods for managing items for AsciiDoc olists, ulist, and dlists.
class ListItem < AbstractBlock

  # Public: Get/Set the String used to mark this list item
  attr_accessor :marker

  # Public: Initialize an Asciidoctor::ListItem object.
  #
  # parent - The parent list block for this list item
  # text - the String text (default nil)
  def initialize(parent, text = nil)
    super(parent, :list_item)
    @text = text
    @level = parent.level
  end

  def text?
    !@text.to_s.empty?
  end

  def text
    # this will allow the text to be processed
    Block.new(self, nil, [@text]).content
  end

  def content
    blocks? ? blocks.map {|b| b.render }.join : nil
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
    if !blocks.empty? && blocks.first.is_a?(Block) &&
        ((blocks.first.context == :paragraph && !continuation_connects_first_block) ||
        ((content_adjacent || !continuation_connects_first_block) && blocks.first.context == :literal &&
            blocks.first.attr('options', []).include?('listparagraph')))

      block = blocks.shift
      unless @text.to_s.empty?
        block.buffer.unshift("#@text\n")
      end

      @text = block.buffer.join
    end
    nil
  end

  def splain(parent_level = 0)
    parent_level += 1
    Debug.puts_indented(parent_level, "List Item anchor: #{@anchor}") unless @anchor.nil?
    Debug.puts_indented(parent_level, "Text: #{@text}") unless @text.nil?

    Debug.puts_indented(parent_level, "Blocks: #{@blocks.count}")

    if @blocks.any?
      Debug.puts_indented(parent_level, "Blocks content (#{@blocks.count}):")
      @blocks.each_with_index do |block, i|
        Debug.puts_indented(parent_level, "v" * (60 - parent_level*2))
        Debug.puts_indented(parent_level, "Block ##{i} is a #{block.class}")
        Debug.puts_indented(parent_level, "Name is #{block.title rescue 'n/a'}")
        Debug.puts_indented(parent_level, "=" * 40)
        block.splain(parent_level) if block.respond_to? :splain
        Debug.puts_indented(parent_level, "^" * (60 - parent_level*2))
      end
    end
    nil
  end

  def to_s
    "#{super.to_s} - #@context [text:#@text, blocks:#{(@blocks || []).size}]"
  end
end
end
