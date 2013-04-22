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

  # Public: Get/Set the caption for this block
  attr_accessor :caption

  # Public: Initialize an Asciidoctor::Block object.
  #
  # parent  - The parent Asciidoc Object.
  # context - The Symbol context name for the type of content.
  # buffer  - The Array buffer of source data (default: nil).

  def initialize(parent, context, buffer = nil)
    super(parent, context)
    @buffer = buffer
    @caption = nil
  end

  # Public: Get the rendered String content for this Block.  If the block
  # has child blocks, the content method should cause them to be
  # rendered and returned as content that can be included in the
  # parent block's template.
  def render
    Debug.debug { "Now rendering #{@context} block for #{self}" }
    @document.playback_attributes @attributes
    out = renderer.render("block_#{@context}", self)
    @document.callouts.next_list if @context == :colist
    out
  end

  def splain(parent_level = 0)
    parent_level += 1
    Debug.puts_indented(parent_level, "Block id: #{id}") unless self.id.nil?
    Debug.puts_indented(parent_level, "Block title: #{title}") unless self.title.nil?
    Debug.puts_indented(parent_level, "Block caption: #{caption}") unless self.caption.nil?
    Debug.puts_indented(parent_level, "Block level: #{level}") unless self.level.nil?
    Debug.puts_indented(parent_level, "Block context: #{context}") unless self.context.nil?

    Debug.puts_indented(parent_level, "Blocks: #{@blocks.count}")

    if buffer.is_a? Enumerable
      buffer.each_with_index do |buf, i|
        Debug.puts_indented(parent_level, "v" * (60 - parent_level*2))
        Debug.puts_indented(parent_level, "Buffer ##{i} is a #{buf.class}")
        Debug.puts_indented(parent_level, "Name is #{buf.title rescue 'n/a'}")

        if buf.respond_to? :splain
          buf.splain(parent_level)
        else
          Debug.puts_indented(parent_level, "Buffer: #{buf}")
        end
        Debug.puts_indented(parent_level, "^" * (60 - parent_level*2))
      end
    else
      if buffer.respond_to? :splain
        buffer.splain(parent_level)
      else
        Debug.puts_indented(parent_level, "Buffer: #{@buffer}")
      end
    end

    @blocks.each_with_index do |block, i|
      Debug.puts_indented(parent_level, "v" * (60 - parent_level*2))
      Debug.puts_indented(parent_level, "Block ##{i} is a #{block.class}")
      Debug.puts_indented(parent_level, "Name is #{block.title rescue 'n/a'}")

      block.splain(parent_level) if block.respond_to? :splain
      Debug.puts_indented(parent_level, "^" * (60 - parent_level*2))
    end
    
    nil
  end

  # Public: Get an HTML-ified version of the source buffer, with special
  # Asciidoc characters and entities converted to their HTML equivalents.
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
    when :preamble, :open
      @blocks.map {|b| b.render }.join
    # lists get iterated in the template (for now)
    # list items recurse into this block when their text and content methods are called
    when :ulist, :olist, :dlist, :colist
      @buffer
    when :listing, :literal
      apply_literal_subs(@buffer)
    when :pass
      apply_passthrough_subs(@buffer)
    when :admonition, :example, :sidebar, :quote, :verse
      if !@buffer.nil?
        apply_para_subs(@buffer)
      else
        @blocks.map {|b| b.render }.join
      end
    else
      apply_para_subs(@buffer)
    end
  end

  def to_s
    "#{super.to_s} - #@context [blocks:#{(@blocks || []).size}]"
  end
end
end
