# Public: Methods for managing blocks of Asciidoc content in a section.
#
# Examples
#
#   block = Asciidoctor::Block.new(document, :paragraph, ["`This` is a <test>"])
#   block.content
#   => ["<em>This</em> is a &lt;test&gt;"]
class Asciidoctor::Block
  # Public: Get the Symbol context for this section block.
  attr_reader :context

  # Public: Create alias for context to be consistent w/ AsciiDoc
  alias :blockname :context

  # Public: Get the Hash of attributes for this block
  attr_reader :attributes

  # Public: Get the Array of sub-blocks for this section block.
  attr_reader :blocks

  # Public: Get/Set the original Array content for this section block.
  attr_accessor :buffer

  # Public: Get/Set the String section anchor name.
  attr_accessor :anchor
  alias :id :anchor

  # Public: Get/Set the Integer block level (for nested elements, like
  # list elements).
  attr_accessor :level

  # Public: Get/Set the String block title.
  attr_accessor :title

  # Public: Get/Set the String block caption.
  attr_accessor :caption

  # Public: Initialize an Asciidoctor::Block object.
  #
  # parent  - The parent Asciidoc Object.
  # context - The Symbol context name for the type of content.
  # buffer  - The Array buffer of source data.

  # TODO: Don't really need the parent, just the document (for access
  # both to its renderer, as well as its references and other defined
  # elements). Would probably be better to pass in just the document.
  def initialize(parent, context, buffer=nil)
    @parent = parent
    @document = @parent.is_a?(Asciidoctor::Document) ? @parent : @parent.document
    @context = context
    @buffer = buffer
    @attributes = {}
    @blocks = []
    @document = nil
  end

  # Public: Get the Asciidoctor::Document instance to which this Block belongs
  def document
    @document
  end

  def attr(name, default = nil)
    default.nil? ? @attributes.fetch(name.to_s, self.document.attr(name)) :
        @attributes.fetch(name.to_s, self.document.attr(name, default))
  end

  def attr?(name)
    @attributes.has_key?(name.to_s) || self.document.attr?(name)
  end

  def update_attributes(attributes)
    @attributes.update(attributes)
  end

  # Public: Get the Asciidoctor::Renderer instance being used for the ancestor
  # Asciidoctor::Document instance.
  def renderer
    # wouldn't @parent.renderer work here? I believe so
    document.renderer
  end

  # Public: Get the rendered String content for this Block.  If the block
  # has child blocks, the content method should cause them to be
  # rendered and returned as content that can be included in the
  # parent block's template.
  def render
    Asciidoctor.debug "Now attempting to render for #{context} my own bad #{self}"
    Asciidoctor.debug "Parent is #{@parent}"
    Asciidoctor.debug "Renderer is #{renderer}"
    renderer.render("block_#{context}", self)
  end

  def splain(parent_level = 0)
    parent_level += 1
    Asciidoctor.puts_indented(parent_level, "Block title: #{title}") unless self.title.nil?
    Asciidoctor.puts_indented(parent_level, "Block anchor: #{anchor}") unless self.anchor.nil?
    Asciidoctor.puts_indented(parent_level, "Block caption: #{caption}") unless self.caption.nil?
    Asciidoctor.puts_indented(parent_level, "Block level: #{level}") unless self.level.nil?
    Asciidoctor.puts_indented(parent_level, "Block context: #{context}") unless self.context.nil?

    Asciidoctor.puts_indented(parent_level, "Blocks: #{@blocks.count}")

    if buffer.is_a? Enumerable
      buffer.each_with_index do |buf, i|
        Asciidoctor.puts_indented(parent_level, "v" * (60 - parent_level*2))
        Asciidoctor.puts_indented(parent_level, "Buffer ##{i} is a #{buf.class}")
        Asciidoctor.puts_indented(parent_level, "Name is #{buf.title rescue 'n/a'}")

        if buf.respond_to? :splain
          buf.splain(parent_level)
        else
          Asciidoctor.puts_indented(parent_level, "Buffer: #{buf}")
        end
        Asciidoctor.puts_indented(parent_level, "^" * (60 - parent_level*2))
      end
    else
      if buffer.respond_to? :splain
        buffer.splain(parent_level)
      else
        Asciidoctor.puts_indented(parent_level, "Buffer: #{@buffer}")
      end
    end

    @blocks.each_with_index do |block, i|
      Asciidoctor.puts_indented(parent_level, "v" * (60 - parent_level*2))
      Asciidoctor.puts_indented(parent_level, "Block ##{i} is a #{block.class}")
      Asciidoctor.puts_indented(parent_level, "Name is #{block.title rescue 'n/a'}")

      block.splain(parent_level) if block.respond_to? :splain
      Asciidoctor.puts_indented(parent_level, "^" * (60 - parent_level*2))
    end
    nil
  end

  # Public: Get an HTML-ified version of the source buffer, with special
  # Asciidoc characters and entities converted to their HTML equivalents.
  #
  # Examples
  #
  #   doc = Asciidoctor::Document.new([])
  #   block = Asciidoctor::Block.new(doc, :paragraph,
  #             ['`This` is what happens when you <meet> a stranger in the <alps>!'])
  #   block.content
  #   => ["<em>This</em> is what happens when you &lt;meet&gt; a stranger in the &lt;alps&gt;!"]
  #
  # TODO:
  # * forced line breaks (partly done, at least in regular paragraphs)
  # * bold, mono
  # * double/single quotes
  # * super/sub script
  def content

    #Asciidoctor.debug "For the record, buffer is:"
    #Asciidoctor.debug @buffer.inspect

    case @context
    when :preamble, :oblock, :example, :sidebar
      blocks.map{|block| block.render}.join
    when :colist
      @buffer.map do |li|
        htmlify(li.text) + li.blocks.map{|block| block.render}.join
      end
    # lists get iterated in template
    # list items recurse into this block when their text and content methods are called
    when :ulist, :olist, :dlist
      @buffer
    when :listing
      sub_special_chars(@buffer.join).gsub(/&lt;(\d+)&gt;/, '<b>\1</b>')
    when :literal
      sub_special_chars(@buffer.join)
    when :quote, :verse, :admonition
      if !@buffer.nil?
        htmlify(sub_attributes(@buffer).map{ |l| l.strip }.join( "\n" ))
      else
        blocks.map{|block| block.render}.join
      end
    else
      lines = sub_attributes(@buffer).map do |line|
        line.strip
        line.gsub(Asciidoctor::REGEXP[:line_break], '\1{br-asciidoctor}')
      end
      lines = htmlify( lines.join )
      sub_html_attributes(lines)  # got to clean up the br-asciidoctor line-break
    end
  end

  # Attribute substitution
  #
  # TODO: Tom all the docs
  def sub_attributes(lines)
    Asciidoctor.debug "Entering #{__method__} from #{caller[0]}"
    if lines.is_a? String
      return_string = true
      lines = Array(lines)
    end

    result = lines.map do |line|
      Asciidoctor.debug "#{__method__} -> Processing line: #{line}"
      f = sub_special_chars(line)
      # gsub! doesn't have lookbehind, so we have to capture and re-insert
      f = f.gsub(/ (^|[^\\]) \{ (\w([\w\-]+)?\w) \} /x) do
        if self.document.attributes.has_key?($2)
          # Substitute from user attributes first
          $1 + self.document.attributes[$2]
        elsif Asciidoctor::INTRINSICS.has_key?($2)
          # Then do intrinsics
          $1 + Asciidoctor::INTRINSICS[$2]
        elsif Asciidoctor::HTML_ELEMENTS.has_key?($2)
          $1 + Asciidoctor::HTML_ELEMENTS[$2]
        else
          Asciidoctor.debug "Bailing on key: #{$2}"
          # delete the line if it has a bad attribute
          # TODO: According to AsciiDoc, we're supposed to delete any line
          # containing a bad attribute. Eek! Can't do that here via gsub!.
          # (See `subs_attrs` function in asciidoc.py for many gory details.)
          "{ZZZZZ}"
        end
      end
      Asciidoctor.debug "#{__method__} -> Processed line: #{f}"
      f
    end
    #Asciidoctor.debug "#{__method__} -> result looks like #{result.inspect}"
    result.reject! {|l| l =~ /\{ZZZZZ\}/}

    if return_string
      result = result.join
    end
    result
  end

  def sub_html_attributes(lines)
    Asciidoctor.debug "Entering #{__method__} from #{caller[0]}"
    if lines.is_a? String
      return_string = true
      lines = Array(lines)
    end

    result = lines.map do |line|
      Asciidoctor.debug "#{__method__} -> Processing line: #{line}"
      # gsub! doesn't have lookbehind, so we have to capture and re-insert
      line.gsub(/ (^|[^\\]) \{ (\w[\w\-]+\w) \} /x) do
        if Asciidoctor::HTML_ELEMENTS.has_key?($2)
          $1 + Asciidoctor::HTML_ELEMENTS[$2]
        else
          $1 + "{#{$2}}"
        end
      end
    end
    #Asciidoctor.debug "#{__method__} -> result looks like #{result.inspect}"
    result.reject! {|l| l =~ /\{ZZZZZ\}/}

    if return_string
      result = result.join
    end
    result
  end

  # Public: Append a sub-block to this section block
  #
  # block - The new sub-block.
  #
  #   block = Block.new(parent, :preamble)
  #
  #   block << Block.new(block, :paragraph, 'p1')
  #   block << Block.new(block, :paragraph, 'p2')
  #   block.blocks
  #   => ["p1", "p2"]
  def <<(block)
    @blocks << block
  end

  private

  # Private: Return a String HTML version of the source string, with
  # Asciidoc characters converted and HTML entities escaped.
  #
  # string - The String source string in Asciidoc format.
  #
  # Examples
  #
  #   asciidoc_string = "Make 'this' <emphasized>"
  #   htmlify(asciidoc_string)
  #   => "Make <em>this</em> &lt;emphasized&gt;"
  def htmlify(string)
    unless string.nil?
      html = string.dup

      # Convert reference links to "link:" asciidoc for later HTMLification.
      # This ensures that eg. "<<some reference>>" is turned into a link but
      # "`<<<<<` and `>>>>>` are conflict markers" is not.  This is much
      # easier before the HTML is escaped and <> are turned into entities.
      html.gsub!( /(^|[^<])<<([^<>,]+)(,([^>]*))?>>/ ) { "#{$1}link:##{$2}[" + ($4.nil? ? document.references[$2] : $4).to_s + "]" }

      # Do the same with URLs
      html.gsub!( /(^|[^(`|link:)])(https?:\/\/[^\[ ]+)(\[+[^\]]*\]+)?/ ) do
        pre = $1
        url = $2
        link = ( $3 || $2 ).gsub( /(^\[|\]$)/,'' )
        link = url if link.empty?

        "#{pre}link:#{url}[#{link}]"
      end

      html.gsub!(Asciidoctor::REGEXP[:biblio], '<a name="\1">[\1]</a>')
      html.gsub!(/``([^`']*)''/m, '&ldquo;\1&rdquo;')
      html.gsub!(/(?:\s|^)`([^`']*)'/m, '&lsquo;\1&rsquo;')

      # TODO: This text thus quoted is supposed to be rendered as an
      # "inline literal passthrough", meaning that it is rendered
      # in a monospace font, but also doesn't go through any further
      # text substitution, except for special character substitution.
      # So we need to technically pull this text out, sha it and store
      # a marker and replace it after the other gsub!s are done in here.
      # See:  http://www.methods.co.nz/asciidoc/userguide.html#X80
      html.gsub!(/`([^`]+)`/m) { "<tt>#{$1.gsub( '*', '{asterisk}' ).gsub( '\'', '{apostrophe}' )}</tt>" }
      html.gsub!(/(\W)#(.+?)#(\W)/, '\1\2\3')

      # "Unconstrained" quotes
      html.gsub!(/\_\_([^\_]+)\_\_/m, '<em>\1</em>')
      html.gsub!(/\*\*([^\*]+)\*\*/m, '<strong>\1</strong>')
      html.gsub!(/\+\+([^\+]+)\+\+/m, '<tt>\1</tt>')
      html.gsub!(/\^\^([^\^]+)\^\^/m, '<sup>\1</sup>')
      html.gsub!(/\~\~([^\~]+)\~\~/m, '<sub>\1</sub>')

      # "Constrained" quotes, which must be bounded by white space or
      # common punctuation characters
      html.gsub!(/(^|\s|\W)\*([^\*]+)\*(\s|\W|$)/m, '\1<strong>\2</strong>\3')
      html.gsub!(/(^|\s|\W)'(.+?)'(\s|\W|$)/m, '\1<em>\2</em>\3')
      # restore escaped single quotes after processing emphasis
      html.gsub!(/(\w)\\'(\w)/, '\1\'\2')
      html.gsub!(/(^|\s|\W)_([^_]+)_(\s|\W|$)/m, '\1<em>\2</em>\3')
      html.gsub!(/(^|\s|\W)\+([^\+]+)\+(\s|\W|$)/m, '\1<tt>\2</tt>\3')
      html.gsub!(/(^|\s|\W)\^([^\^]+)\^(\s|\W|$)/m, '\1<sup>\2</sup>\3')
      html.gsub!(/(^|\s|\W)\~([^\~]+)\~(\s|\W|$)/m, '\1<sub>\2</sub>\3')

      html.gsub!(/\\([\{\}\-])/, '\1')
      html.gsub!(/linkgit:([^\]]+)\[(\d+)\]/, '<a href="\1.html">\1(\2)</a>')
      html.gsub!(/link:([^\[]+)(\[+[^\]]*\]+)/ ) { "<a href=\"#{$1}\">#{$2.gsub( /(^\[|\]$)/,'' )}</a>" }
      html.gsub!(Asciidoctor::REGEXP[:line_break], '\1<br/>')
      html
    end
  end

  def sub_special_chars(str)
    str.gsub(/[#{Asciidoctor::SPECIAL_CHARS.keys.join}]/) {|match| Asciidoctor::SPECIAL_CHARS[match] }
  end
  # end private
end
