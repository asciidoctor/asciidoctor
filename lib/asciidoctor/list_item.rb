# Public: Methods for managing items for Asciidoc olists, ulist, and dlists.
class Asciidoctor::ListItem
  # Public: Get the Array of Blocks from the list item's continuation.
  attr_reader :blocks

  # Public: Get/Set the String content.
  attr_accessor :content

  # Public: Get/Set the String list item anchor name.
  attr_accessor :anchor

  # Public: Initialize an Asciidoctor::ListItem object.
  #
  # content - the String content (default '')
  def initialize(content='')
    @content = content
    @blocks  = []
  end

  def splain(parent_level = 0)
    parent_level += 1
    Asciidoctor.puts_indented(parent_level, "List Item anchor: #{anchor}") unless self.anchor.nil?
    Asciidoctor.puts_indented(parent_level, "Content: #{content}") unless self.content.nil?

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
