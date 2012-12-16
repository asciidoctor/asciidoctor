# Public: Methods for managing items for AsciiDoc olists, ulist, and dlists.
class Asciidoctor::ListItem
  # Public: Get the Array of Blocks from the list item's continuation.
  attr_reader :blocks

  # Public: Get/Set the String list item anchor name.
  attr_accessor :anchor

  # Public: Get/Set the Integer list level (for nesting list elements).
  attr_accessor :level

  # Public: Initialize an Asciidoctor::ListItem object.
  #
  # parent - The parent list block for this list item
  # text - the String text (default '')
  def initialize(parent, text='')
    @parent = parent
    @text = text
    @blocks = []
  end

  def text=(new_text)
    @text = new_text
  end

  def text
    # this will allow the text to be processed
    ::Asciidoctor::Block.new(self, nil, [@text]).content
  end

  def document
    @parent.document
  end

  def content
    # create method for !blocks.empty?
    if !blocks.empty?
      blocks.map{|block| block.render}.join
    else
      nil
    end
  end

  # Public: Fold the first paragraph block into the text
  def fold_first
    # looking for :literal here allows indentation of paragraph content, then strip indent
    if !blocks.empty? && blocks.first.is_a?(Asciidoctor::Block) &&
        (blocks.first.context == :paragraph || blocks.first.context == :literal)
      block = blocks.shift
      if !@text.nil? && !@text.empty?
        block.buffer.unshift(@text)
      end

      if block.context == :literal
        @text = block.buffer.map {|l| l.lstrip}.join("\n")
      else
        @text = block.buffer.join("\n")
      end
    end
  end

  def splain(parent_level = 0)
    parent_level += 1
    Asciidoctor.puts_indented(parent_level, "List Item anchor: #{@anchor}") unless @anchor.nil?
    Asciidoctor.puts_indented(parent_level, "Text: #{@text}") unless @text.nil?

    Asciidoctor.puts_indented(parent_level, "Blocks: #{@blocks.count}")

    if @blocks.any?
      Asciidoctor.puts_indented(parent_level, "Blocks content (#{@blocks.count}):")
      @blocks.each_with_index do |block, i|
        Asciidoctor.puts_indented(parent_level, "v" * (60 - parent_level*2))
        Asciidoctor.puts_indented(parent_level, "Block ##{i} is a #{block.class}")
        Asciidoctor.puts_indented(parent_level, "Name is #{block.name rescue 'n/a'}")
        Asciidoctor.puts_indented(parent_level, "=" * 40)
        block.splain(parent_level) if block.respond_to? :splain
        Asciidoctor.puts_indented(parent_level, "^" * (60 - parent_level*2))
      end
    end
    nil
  end
end
