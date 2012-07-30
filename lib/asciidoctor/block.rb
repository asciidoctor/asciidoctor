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

  # Public: Get the Array of sub-blocks for this section block.
  attr_reader :blocks

  # Public: Get/Set the original Array content for this section block.
  attr_accessor :buffer

  # Public: Get/Set the String section anchor name.
  attr_accessor :anchor

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
    @context = context
    @buffer = buffer

    @blocks = []
  end

  # Public: Get the Asciidoctor::Document instance to which this Block belongs
  def document
    return @document if @document
    @document = (@parent.is_a?(Asciidoctor::Document) ? @parent : @parent.document)
  end

  # Public: Get the Asciidoctor::Renderer instance being used for the ancestor
  # Asciidoctor::Document instance.
  def renderer
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
    renderer.render("section_#{context}", self)
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
        Asciidoctor.puts_indented(parent_level, "Name is #{buf.name rescue 'n/a'}")

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
      Asciidoctor.puts_indented(parent_level, "Name is #{block.name rescue 'n/a'}")

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

    puts "For the record, buffer is:"
    puts @buffer.inspect

    case @context
    when :dlist
      @buffer.map do |dt, dd|
        if !dt.anchor.nil? && !dt.anchor.empty?
          html_dt = "<a id=#{dt.anchor}></a>" + htmlify(dt.content)
        else
          html_dt = htmlify(dt.content)
        end
        if dd.content.empty?
          html_dd = ''
        else
          html_dd = "<p>#{htmlify(dd.content)}</p>"
        end
        html_dd += dd.blocks.map{|block| block.render}.join

        [html_dt, html_dd]
      end
    when :oblock, :quote
      blocks.map{|block| block.render}.join
    when :olist, :colist
      @buffer.map do |li|
        htmlify(li.content) + li.blocks.map{|block| block.render}.join
      end
    when :ulist
      @buffer.map do |element|
        if element.is_a? Asciidoctor::ListItem
          element.content = sub_attributes(element.content)
        end
        # TODO - not sure why tests work the same whether or not this is commented out.
        # I think that I am likely not yet testing unordered list items with no block
        # content. Still and all, it seems like this should be all done by list_item.render .
        element.render # + element.blocks.map{|block| block.render}.join
      end
    when :listing
      @buffer.map{|l| CGI.escapeHTML(l).gsub(/(<\d+>)/,'<b>\1</b>')}.join
    when :literal
      htmlify( @buffer.join.gsub( '*', '{asterisk}' ).gsub( '\'', '{apostrophe}' ))
    when :verse
      htmlify( sub_attributes(@buffer).map{ |l| l.strip }.join( "\n" ) )
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
    puts "Entering #{__method__} from #{caller[0]}"
    if lines.is_a? String
      return_string = true
      lines = Array(lines)
    end

    result = lines.map do |line|
      puts "#{__method__} -> Processing line: #{line}"
      # gsub! doesn't have lookbehind, so we have to capture and re-insert
      f = line.gsub(/ (^|[^\\]) \{ (\w[\w\-_]+\w) \} /x) do
        if self.document.defines.has_key?($2)
          # Substitute from user defines first
          $1 + self.document.defines[$2]
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
      puts "#{__method__} -> Processed line: #{f}"
      f
    end
    puts "#{__method__} -> result looks like #{result.inspect}"
    result.reject! {|l| l =~ /\{ZZZZZ\}/}

    if return_string
      result = result.join
    end
    result
  end

  def sub_html_attributes(lines)
    puts "Entering #{__method__} from #{caller[0]}"
    if lines.is_a? String
      return_string = true
      lines = Array(lines)
    end

    result = lines.map do |line|
      puts "#{__method__} -> Processing line: #{line}"
      # gsub! doesn't have lookbehind, so we have to capture and re-insert
      line.gsub(/ (^|[^\\]) \{ (\w[\w\-_]+\w) \} /x) do
        if Asciidoctor::HTML_ELEMENTS.has_key?($2)
          $1 + Asciidoctor::HTML_ELEMENTS[$2]
        else
          $1 + "{#{$2}}"
        end
      end
    end
    puts "#{__method__} -> result looks like #{result.inspect}"
    result.reject! {|l| l =~ /\{ZZZZZ\}/}

    if return_string
      result = result.join
    end
    result
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
      html.gsub!( /(^|[^`])(https?:\/\/[^\[ ]+)(\[+[^\]]*\]+)?/ ) do
        pre = $1
        url = $2
        link = ( $3 || $2 ).gsub( /(^\[|\]$)/,'' )
        link = url if link.empty?

        "#{pre}link:#{url}[#{link}]"
      end

      html = CGI.escapeHTML(html)
      html.gsub!(Asciidoctor::REGEXP[:biblio], '<a name="\1">[\1]</a>')
      html.gsub!(Asciidoctor::REGEXP[:ruler], '<hr>\n')
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
      html.gsub!(/([\s\W])#(.+?)#([\s\W])/, '\1\2\3')

      # "Unconstrained" quotes
      html.gsub!(/\_\_([^\_]+)\_\_/m, '<em>\1</em>')
      html.gsub!(/\*\*([^\*]+)\*\*/m, '<strong>\1</strong>')
      html.gsub!(/\+\+([^\+]+)\+\+/m, '<tt>\1</tt>')
      html.gsub!(/\^\^([^\^]+)\^\^/m, '<sup>\1</sup>')
      html.gsub!(/\~\~([^\~]+)\~\~/m, '<sub>\1</sub>')

      # "Constrained" quotes, which must be bounded by white space or
      # common punctuation characters
      html.gsub!(/([\s\W])\*([^\*]+)\*([\s\W])/m, '\1<strong>\2</strong>\3')
      html.gsub!(/([\s\W])'(.+?)'([\s\W])/m, '\1<em>\2</em>\3')
      html.gsub!(/([\s\W])_([^_]+)_([\s\W])/m, '\1<em>\2</em>\3')
      html.gsub!(/([\s\W])\+([^\+]+)\+([\s\W])/m, '\1<tt>\2</tt>\3')
      html.gsub!(/([\s\W])\^([^\^]+)\^([\s\W])/m, '\1<sup>\2</sup>\3')
      html.gsub!(/([\s\W])\~([^\~]+)\~([\s\W])/m, '\1<sub>\2</sub>\3')

      html.gsub!(/\\([\{\}\-])/, '\1')
      html.gsub!(/linkgit:([^\]]+)\[(\d+)\]/, '<a href="\1.html">\1(\2)</a>')
      html.gsub!(/link:([^\[]+)(\[+[^\]]*\]+)/ ) { "<a href=\"#{$1}\">#{$2.gsub( /(^\[|\]$)/,'' )}</a>" }
      html.gsub!(Asciidoctor::REGEXP[:line_break], '\1<br/>')
      html
    end
  end
  # end private
end
