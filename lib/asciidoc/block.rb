# Public: Methods for managing blocks of Asciidoc content in a section.
#
# Examples
#
#   block = Asciidoc::Block.new(:paragraph, ["`This` is a <test>"])
#   block.content
#   => ["<em>This</em> is a &lt;test&gt;"]
class Asciidoc::Block
  # Public: Get the Symbol context for this section block.
  attr_reader :context

  # Public: Get the Array of sub-blocks for this section block.
  attr_reader :blocks

  # Public: Get/Set the original Array content for this section block.
  attr_accessor :buffer

  # Public: Get/Set the String section anchor name.
  attr_accessor :anchor

  # Public: Get/Set the String block title.
  attr_accessor :title

  # Public: Get/Set the String block caption.
  attr_accessor :caption

  # Public: Initialize an Asciidoc::Block object.
  #
  # parent  - The parent Asciidoc Object.
  # context - The Symbol context name for the type of content.
  # buffer  - The Array buffer of source data.
  def initialize(parent, context, buffer=nil)
    @parent = parent
    @context = context
    @buffer = buffer

    @blocks = []
  end

  # Public: Get the Asciidoc::Document instance to which this Block belongs
  def document
    @parent.is_a?(Document) ? @parent : @parent.document
  end

  # Public: Get the Asciidoc::Renderer instance being used for the ancestor
  # Asciidoc::Document instance.
  def renderer
    @parent.renderer
  end

  # Public: Get the rendered String content for this Block.  If the block
  # has child blocks, the content method should cause them to be
  # rendered and returned as content that can be included in the
  # parent block's template.
  def render
    puts "Now attempting to render for #{context} my own bad #{self}"
    puts "Parent is #{@parent}"
    puts "Renderer is #{renderer}"
    renderer.render("section_#{context}", self)
  end

  # Public: Get an HTML-ified version of the source buffer, with special
  # Asciidoc characters and entities converted to their HTML equivalents.
  #
  # Examples
  #
  #   block = Block.new(:paragraph, ['`This` is what happens when you <meet> a stranger in the <alps>!']
  #   block.content
  #   => ["<em>This</em> is what happens when you &lt;meet&gt; a stranger in the &lt;alps&gt;!"]
  #
  # TODO:
  # * forced line breaks
  # * bold, mono
  # * double/single quotes
  # * super/sub script
  def content
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
    when :olist, :ulist, :colist
      @buffer.map do |li|
        htmlify(li.content) + li.blocks.map{|block| block.render}.join
      end
    when :listing
      @buffer.map{|l| CGI.escapeHTML(l).gsub(/(<\d+>)/,'<b>\1</b>')}.join
    when :literal
      htmlify( @buffer.join.gsub( '*', '{asterisk}' ).gsub( '\'', '{apostrophe}' ))
    when :verse
      htmlify( @buffer.map{ |l| l.strip }.join( "\n" ) )
    else
      htmlify( @buffer.map{ |l| l.lstrip }.join )
    end
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
        pre=$1
        url=$2
        link=( $3 || $2 ).gsub( /(^\[|\]$)/,'' )
        link = url if link.empty?

        "#{pre}link:#{url}[#{link}]"
      end

      CGI.escapeHTML(html).
        gsub(Asciidoc::REGEXP[:biblio], '<a name="\1">[\1]</a>').
        gsub(/`([^`]+)`/m) { "<tt>#{$1.gsub( '*', '{asterisk}' ).gsub( '\'', '{apostrophe}' )}</tt>" }.
        gsub(/``(.*?)''/m, '&#147;\1&#148;').
        gsub(/(^|\W)'([^']+)'/m, '\1<em>\2</em>').
        gsub(/(^|\W)_([^_]+)_/m, '\1<em>\2</em>').
        gsub(/\*([^\*]+)\*/m, '<strong>\1</strong>').
        gsub(/(^|[^\\])\{(\w[\w\-]+\w)\}/) { $1 + Asciidoc::INTRINSICS[$2] }. # Don't have lookbehind so have to capture and re-insert
        gsub(/\\([\{\}\-])/, '\1').
        gsub(/linkgit:([^\]]+)\[(\d+)\]/, '<a href="\1.html">\1(\2)</a>').
        gsub(/link:([^\[]+)(\[+[^\]]*\]+)/ ) { "<a href=\"#{$1}\">#{$2.gsub( /(^\[|\]$)/,'' )}</a>" }
    end
  end
  # end private
end
