module Asciidoctor
  # A built-in {Converter} implementation that generates HTML 5 output
  # consistent with the html5 backend from AsciiDoc Python.
  class Converter::Html5Converter < Converter::BuiltIn
    QUOTE_TAGS = {
      :emphasis    => ['<em>',     '</em>',     true],
      :strong      => ['<strong>', '</strong>', true],
      :monospaced  => ['<code>',   '</code>',   true],
      :superscript => ['<sup>',    '</sup>',    true],
      :subscript   => ['<sub>',    '</sub>',    true],
      :double      => ['&#8220;',  '&#8221;',   false],
      :single      => ['&#8216;',  '&#8217;',   false],
      :asciimath   => ['\\$',      '\\$',       false],
      :latexmath   => ['\\(',      '\\)',       false]
      # Opal can't resolve these constants when referenced here
      #:asciimath   => INLINE_MATH_DELIMITERS[:asciimath] + [false],
      #:latexmath   => INLINE_MATH_DELIMITERS[:latexmath] + [false]
    }
    QUOTE_TAGS.default = [nil, nil, nil]

    def initialize backend, opts = {}
      @short_tag_slash = ((@htmlsyntax = opts[:htmlsyntax]) == 'xml' ? '/' : nil)
      @stylesheets = Stylesheets.instance
    end

    def document node
      xml = node.document.attr? 'htmlsyntax', 'xml'
      result = []
      short_tag_slash_local = @short_tag_slash
      br = %(<br#{short_tag_slash_local}>)
      linkcss = node.safe >= SafeMode::SECURE || (node.attr? 'linkcss')
      result << '<!DOCTYPE html>'
      result << ((node.attr? 'nolang') ? '<html' : %(<html lang="#{node.attr 'lang', 'en'}")) + (xml ? %( xmlns="http://www.w3.org/1999/xhtml">) : ">")
      result << %(<head>
<meta http-equiv="Content-Type" content="text/html; charset=#{node.attr 'encoding'}"#{short_tag_slash_local}>
<meta name="generator" content="Asciidoctor #{node.attr 'asciidoctor-version'}"#{short_tag_slash_local}>
<meta name="viewport" content="width=device-width, initial-scale=1.0"#{short_tag_slash_local}>)

      ['description', 'keywords', 'author', 'copyright'].each do |key|
        result << %(<meta name="#{key}" content="#{node.attr key}"#{short_tag_slash_local}>) if node.attr? key
      end

      result << %(<title>#{node.doctitle(:sanitize => true) || node.attr('untitled-label')}</title>) 
      if DEFAULT_STYLESHEET_KEYS.include?(node.attr 'stylesheet')
        if linkcss
          result << %(<link rel="stylesheet" href="#{node.normalize_web_path DEFAULT_STYLESHEET_NAME, (node.attr 'stylesdir', '')}"#{short_tag_slash_local}>)
        else
          result << @stylesheets.embed_primary_stylesheet
        end
      elsif node.attr? 'stylesheet'
        if linkcss
          result << %(<link rel="stylesheet" href="#{node.normalize_web_path((node.attr 'stylesheet'), (node.attr 'stylesdir', ''))}"#{short_tag_slash_local}>)
        else
          result << %(<style>
#{node.read_asset node.normalize_system_path((node.attr 'stylesheet'), (node.attr 'stylesdir', '')), true}
</style>)
        end
      end

      if node.attr? 'icons', 'font'
        if !(node.attr 'iconfont-remote', '').nil?
          result << %(<link rel="stylesheet" href="#{node.attr 'iconfont-cdn', 'http://cdnjs.cloudflare.com/ajax/libs/font-awesome/3.2.1/css/font-awesome.min.css'}"#{short_tag_slash_local}>)
        else
          iconfont_stylesheet = %(#{node.attr 'iconfont-name', 'font-awesome'}.css)
          result << %(<link rel="stylesheet" href="#{node.normalize_web_path iconfont_stylesheet, (node.attr 'stylesdir', '')}"#{short_tag_slash_local}>)
        end
      end

      case node.attr 'source-highlighter'
      when 'coderay'
        if (node.attr 'coderay-css', 'class') == 'class'
          if linkcss
            result << %(<link rel="stylesheet" href="#{node.normalize_web_path @stylesheets.coderay_stylesheet_name, (node.attr 'stylesdir', '')}"#{short_tag_slash_local}>)
          else
            result << @stylesheets.embed_coderay_stylesheet
          end
        end
      when 'pygments'
        if (node.attr 'pygments-css', 'class') == 'class'
          pygments_style = (doc.attr 'pygments-style', 'pastie')
          if linkcss
            result << %(<link rel="stylesheet" href="#{node.normalize_web_path @stylesheets.pygments_stylesheet_name(pygments_style), (node.attr 'stylesdir', '')}"#{short_tag_slash_local}>)
          else
            result << (@stylesheets.instance.embed_pygments_stylesheet pygments_style)
          end
        end
      when 'highlightjs', 'highlight.js'
        result << %(<link rel="stylesheet" href="#{node.attr 'highlightjsdir', 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.4'}/styles/#{node.attr 'highlightjs-theme', 'googlecode'}.min.css"#{short_tag_slash_local}>
<script src="#{node.attr 'highlightjsdir', 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.4'}/highlight.min.js"></script>
<script src="#{node.attr 'highlightjsdir', 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.4'}/lang/common.min.js"></script>
<script>hljs.initHighlightingOnLoad()</script>)
      when 'prettify'
        result << %(<link rel="stylesheet" href="#{node.attr 'prettifydir', 'http://cdnjs.cloudflare.com/ajax/libs/prettify/r298'}/#{node.attr 'prettify-theme', 'prettify'}.min.css"#{short_tag_slash_local}>
<script src="#{node.attr 'prettifydir', 'http://cdnjs.cloudflare.com/ajax/libs/prettify/r298'}/prettify.min.js"></script>
<script>document.addEventListener('DOMContentLoaded', prettyPrint)</script>)
      end

      if node.attr? 'math'
        result << %(<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  tex2jax: {
    inlineMath: [#{INLINE_MATH_DELIMITERS[:latexmath]}],
    displayMath: [#{BLOCK_MATH_DELIMITERS[:latexmath]}],
    ignoreClass: "nomath|nolatexmath"
  },
  asciimath2jax: {
    delimiters: [#{BLOCK_MATH_DELIMITERS[:asciimath]}],
    ignoreClass: "nomath|noasciimath"
  }
});
</script>
<script type="text/javascript" src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-MML-AM_HTMLorMML"></script>
<script>document.addEventListener('DOMContentLoaded', MathJax.Hub.TypeSet)</script>)
      end

      unless (docinfo_content = node.docinfo).empty?
        result << docinfo_content
      end

      result << '</head>'
      body_attrs = []
      if node.id
        body_attrs << %(id="#{node.id}")
      end
      if (node.attr? 'toc-class') && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
        body_attrs << %(class="#{node.doctype} #{node.attr 'toc-class'} toc-#{node.attr 'toc-position', 'left'}")
      else
        body_attrs << %(class="#{node.doctype}")
      end
      if node.attr? 'max-width'
        body_attrs << %(style="max-width: #{node.attr 'max-width'};")
      end
      result << %(<body #{body_attrs * ' '}>)

      unless node.noheader
        result << '<div id="header">'
        if node.doctype == 'manpage'
          result << %(<h1>#{node.doctitle} Manual Page</h1>)
          if (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
            result << %(<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{outline node}
</div>)
          end
          result << %(<h2>#{node.attr 'manname-title'}</h2>
<div class="sectionbody">
<p>#{node.attr 'manname'} - #{node.attr 'manpurpose'}</p>
</div>)
        else
          if node.has_header?
            result << %(<h1>#{node.header.title}</h1>) unless node.notitle
            if node.attr? 'author'
              result << %(<span id="author" class="author">#{node.attr 'author'}</span>#{br})
              if node.attr? 'email'
                result << %(<span id="email" class="email">#{node.sub_macros(node.attr 'email')}</span>#{br})
              end
              if (authorcount = (node.attr 'authorcount').to_i) > 1
                (2..authorcount).each do |idx|
                  result << %(<span id="author#{idx}" class="author">#{node.attr "author_#{idx}"}</span>#{br})
                  if node.attr? %(email_#{idx})
                    result << %(<span id="email#{idx}" class="email">#{node.sub_macros(node.attr "email_#{idx}")}</span>#{br})
                  end
                end
              end
            end
            if node.attr? 'revnumber'
              result << %(<span id="revnumber">#{((node.attr 'version-label') || '').downcase} #{node.attr 'revnumber'}#{(node.attr? 'revdate') ? ',' : ''}</span>)
            end
            if node.attr? 'revdate'
              result << %(<span id="revdate">#{node.attr 'revdate'}</span>)
            end
            if node.attr? 'revremark'
              result << %(#{br}<span id="revremark">#{node.attr 'revremark'}</span>)
            end
          end

          if (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
            result << %(<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{outline node}
</div>)
          end
        end
        result << '</div>'
      end

      result << %(<div id="content">
#{node.content}
</div>)

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << %(<div id="footnotes">
<hr#{short_tag_slash_local}>)
        node.footnotes.each do |footnote|
          result << %(<div class="footnote" id="_footnote_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a>. #{footnote.text}
</div>)
        end
        result << '</div>'
      end
      unless node.nofooter
        result << '<div id="footer">'
        result << '<div id="footer-text">'
        if node.attr? 'revnumber'
          result << %(#{node.attr 'version-label'} #{node.attr 'revnumber'}#{br})
        end
        if node.attr? 'last-update-label'
          result << %(#{node.attr 'last-update-label'} #{node.attr 'docdatetime'})
        end
        result << '</div>'
        unless (docinfo_content = node.docinfo :footer).empty?
          result << docinfo_content
        end
        result << '</div>'
      end

      result << '</body>'
      result << '</html>'
      result * EOL
    end

    def embedded node
      result = []
      if !node.notitle && node.has_header?
        id_attr = node.id ? %( id="#{node.id}") : nil
        result << %(<h1#{id_attr}>#{node.header.title}</h1>)
      end

      result << node.content

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << %(<div id="footnotes">
<hr#{@short_tag_slash}>)
        node.footnotes.each do |footnote|
          result << %(<div class="footnote" id="_footnote_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a> #{footnote.text}
</div>)
        end

        result << '</div>'
      end

      result * EOL
    end

    def outline node, opts = {}
      return if (sections = node.sections).empty?
      sectnumlevels = opts[:sectnumlevels] || (node.document.attr 'sectnumlevels', 3).to_i
      toclevels = opts[:toclevels] || (node.document.attr 'toclevels', 2).to_i
      result = []
      # FIXME the level for special sections should be set correctly in the model
      # slevel will only be 0 if we have a book doctype with parts
      slevel = (first_section = sections[0]).level
      slevel = 1 if slevel == 0 && first_section.special
      result << %(<ul class="sectlevel#{slevel}">)
      sections.each do |section|
        section_num = (section.numbered && !section.caption && section.level <= sectnumlevels) ? %(#{section.sectnum} ) : nil
        result << %(<li><a href="##{section.id}">#{section_num}#{section.captioned_title}</a></li>)
        if section.level < toclevels && (child_toc_level = outline section, :toclevels => toclevels, :secnumlevels => sectnumlevels)
          result << '<li>'
          result << child_toc_level
          result << '</li>'
        end
      end
      result << '</ul>'
      result * EOL
    end

    def section node
      slevel = node.level
      # QUESTION should the check for slevel be done in section?
      slevel = 1 if slevel == 0 && node.special
      htag = %(h#{slevel + 1})
      id_attr = anchor = link_start = link_end = nil
      if node.id
        id_attr = %( id="#{node.id}")
        if node.document.attr? 'sectanchors'
          anchor = %(<a class="anchor" href="##{node.id}"></a>)
          # possible idea - anchor icons GitHub-style
          #if node.document.attr? 'icons', 'font'
          #  anchor = %(<a class="anchor" href="##{node.id}"><i class="icon-anchor"></i></a>)
          #else
        elsif node.document.attr? 'sectlinks'
          link_start = %(<a class="link" href="##{node.id}">)
          link_end = '</a>'
        end
      end

      if slevel == 0
        %(<h1#{id_attr} class="sect0">#{anchor}#{link_start}#{node.title}#{link_end}</h1>
#{node.content})
      else
        class_attr = (role = node.role) ? %( class="sect#{slevel} #{role}") : %( class="sect#{slevel}")
        sectnum = if node.numbered && !node.caption && slevel <= (node.document.attr 'sectnumlevels', 3).to_i
          %(#{node.sectnum} )
        end
        %(<div#{class_attr}>
<#{htag}#{id_attr}>#{anchor}#{link_start}#{sectnum}#{node.captioned_title}#{link_end}</#{htag}>
#{slevel == 1 ? %[<div class="sectionbody">\n#{node.content}\n</div>] : node.content}
</div>)
      end
    end

    def admonition node
      id_attr = node.id ? %( id="#{node.id}") : nil
      name = node.attr 'name'
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
      caption = if node.document.attr? 'icons'
        if node.document.attr? 'icons', 'font'
          %(<i class="icon-#{name}" title="#{node.caption}"></i>)
        else
          %(<img src="#{node.icon_uri name}" alt="#{node.caption}"#{@short_tag_slash}>)
        end
      else
        %(<div class="title">#{node.caption}</div>)
      end
      %(<div#{id_attr} class="admonitionblock #{name}#{(role = node.role) && " #{role}"}">
<table>
<tr>
<td class="icon">
#{caption}
</td>
<td class="content">
#{title_element}#{node.content}
</td>
</tr>
</table>
</div>)
    end

    def audio node
      xml = node.document.attr? 'htmlsyntax', 'xml'
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['audioblock', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : nil
      %(<div#{id_attribute}#{class_attribute}>
#{title_element}<div class="content">
<audio src="#{node.media_uri(node.attr 'target')}"#{(node.option? 'autoplay') ? (append_boolean_attribute 'autoplay', xml) : nil}#{(node.option? 'nocontrols') ? nil : (append_boolean_attribute 'controls', xml)}#{(node.option? 'loop') ? (append_boolean_attribute 'loop', xml) : nil}>
Your browser does not support the audio tag.
</audio>
</div>
</div>)
    end

    def colist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['colist', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")

      result << %(<div#{id_attribute}#{class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?

      if node.document.attr? 'icons'
        result << '<table>'

        font_icons = node.document.attr? 'icons', 'font'
        node.items.each_with_index do |item, i|
          num = i + 1
          num_element = if font_icons
            %(<i class="conum" data-value="#{num}"></i><b>#{num}</b>)
          else
            %(<img src="#{node.icon_uri "callouts/#{num}"}" alt="#{num}"#{@short_tag_slash}>)
          end
          result << %(<tr>
<td>#{num_element}</td>
<td>#{item.text}</td>
</tr>)
        end

        result << '</table>'
      else
        result << '<ol>'
        node.items.each do |item|
          result << %(<li>
<p>#{item.text}</p>
</li>)
        end
        result << '</ol>'
      end

      result << '</div>'
      result * EOL
    end

    def dlist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : nil

      classes = case node.style
      when 'qanda'
        ['qlist', 'qanda', node.role]
      when 'horizontal'
        ['hdlist', node.role]
      else
        ['dlist', node.style, node.role]
      end.compact

      class_attribute = %( class="#{classes * ' '}")

      result << %(<div#{id_attribute}#{class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?
      case node.style
      when 'qanda'
        result << '<ol>'
        node.items.each do |terms, dd|
          result << '<li>'
          [*terms].each do |dt|
            result << %(<p><em>#{dt.text}</em></p>)
          end
          if dd
            result << %(<p>#{dd.text}</p>) if dd.text?
            result << dd.content if dd.blocks?
          end
          result << '</li>'
        end
        result << '</ol>'
      when 'horizontal'
        short_tag_slash_local = @short_tag_slash
        result << '<table>'
        if (node.attr? 'labelwidth') || (node.attr? 'itemwidth')
          result << '<colgroup>'
          col_style_attribute = (node.attr? 'labelwidth') ? %( style="width: #{(node.attr 'labelwidth').chomp '%'}%;") : nil
          result << %(<col#{col_style_attribute}#{short_tag_slash_local}>)
          col_style_attribute = (node.attr? 'itemwidth') ? %( style="width: #{(node.attr 'itemwidth').chomp '%'}%;") : nil
          result << %(<col#{col_style_attribute}#{short_tag_slash_local}>)
          result << '</colgroup>'
        end
        node.items.each do |terms, dd|
          result << '<tr>'
          result << %(<td class="hdlist1#{(node.option? 'strong') ? ' strong' : nil}">)
          terms_array = [*terms]
          last_term = terms_array[-1]
          terms_array.each do |dt|
            result << dt.text
            result << %(<br#{short_tag_slash_local}>) if dt != last_term
          end
          result << '</td>'
          result << '<td class="hdlist2">'
          if dd
            result << %(<p>#{dd.text}</p>) if dd.text?
            result << dd.content if dd.blocks?
          end
          result << '</td>'
          result << '</tr>'
        end
        result << '</table>'
      else
        result << '<dl>'
        dt_style_attribute = node.style ? nil : ' class="hdlist1"'
        node.items.each do |terms, dd|
          [*terms].each do |dt|
            result << %(<dt#{dt_style_attribute}>#{dt.text}</dt>)
          end
          if dd
            result << '<dd>'
            result << %(<p>#{dd.text}</p>) if dd.text?
            result << dd.content if dd.blocks?
            result << '</dd>'
          end
        end
        result << '</dl>'
      end

      result << '</div>'
      result * EOL
    end

    def example node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : nil

      %(<div#{id_attribute} class="#{(role = node.role) ? ['exampleblock', role] * ' ' : 'exampleblock'}">
#{title_element}<div class="content">
#{node.content}
</div>
</div>)
    end

    def floating_title node
      tag_name = %(h#{node.level + 1})
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = [node.style, node.role].compact
      %(<#{tag_name}#{id_attribute} class="#{classes * ' '}">#{node.title}</#{tag_name}>)
    end

    def image node
      align = (node.attr? 'align') ? (node.attr 'align') : nil
      float = (node.attr? 'float') ? (node.attr 'float') : nil 
      style_attribute = if align || float
        styles = [align ? %(text-align: #{align}) : nil, float ? %(float: #{float}) : nil].compact
        %( style="#{styles * ';'}")
      end

      width_attribute = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
      height_attribute = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : nil

      img_element = %(<img src="#{node.image_uri node.attr('target')}" alt="#{node.attr 'alt'}"#{width_attribute}#{height_attribute}#{@short_tag_slash}>)
      if (link = node.attr 'link')
        img_element = %(<a class="image" href="#{link}">#{img_element}</a>)
      end
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['imageblock', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : nil

      %(<div#{id_attribute}#{class_attribute}#{style_attribute}>
<div class="content">
#{img_element}
</div>#{title_element}
</div>)
    end

    def listing node
      nowrap = !(node.document.attr? 'prewrap') || (node.option? 'nowrap')
      if node.style == 'source'
        language = node.attr 'language'
        language_classes = language ? %(#{language} language-#{language}) : nil
        case node.attr 'source-highlighter'
        when 'coderay'
          pre_class = nowrap ? ' class="CodeRay nowrap"' : ' class="CodeRay"'
          code_class = language ? %( class="#{language_classes}") : nil
        when 'pygments'
          pre_class = nowrap ? ' class="pygments highlight nowrap"' : ' class="pygments highlight"'
          code_class = language ? %( class="#{language_classes}") : nil
        when 'highlightjs', 'highlight.js'
          pre_class = nowrap ? ' class="highlight nowrap"' : ' class="highlight"'
          code_class = language ? %( class="#{language_classes}") : nil
        when 'prettify'
          pre_class = %( class="prettyprint#{nowrap ? ' nowrap' : nil}#{(node.attr? 'linenums') ? ' linenums' : nil})
          pre_class = language ? %(#{pre_class} #{language_classes}") : %(#{pre_class}")
          code_class = nil
        when 'html-pipeline'
          pre_class = language ? %( lang="#{language}") : nil
          code_class = nil
        else
          pre_class = nowrap ? ' class="highlight nowrap"' : ' class="highlight"'
          code_class = language ? %( class="#{language_classes}") : nil
        end
        pre_start = %(<pre#{pre_class}><code#{code_class}>)
        pre_end = '</code></pre>'
      else
        pre_start = %(<pre#{nowrap ? ' class="nowrap"' : nil}>)
        pre_end = '</pre>'
      end

      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : nil
      %(<div#{id_attribute} class="listingblock#{(role = node.role) && " #{role}"}">
#{title_element}<div class="content">
#{pre_start}#{node.content}#{pre_end}
</div>
</div>)
    end

    def literal node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
      nowrap = !(node.document.attr? 'prewrap') || (node.option? 'nowrap')
      %(<div#{id_attribute} class="literalblock#{(role = node.role) && " #{role}"}">
#{title_element}<div class="content">
<pre#{nowrap ? ' class="nowrap"' : nil}>#{node.content}</pre>
</div>
</div>)
    end

    def math node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
      open, close = BLOCK_MATH_DELIMITERS[node.style.to_sym]
      # QUESTION should the content be stripped already?
      equation = node.content.strip
      if node.subs.nil_or_empty? && !(node.attr? 'subs')
        equation = node.sub_specialcharacters equation
      end

      unless (equation.start_with? open) && (equation.end_with? close)
        equation = %(#{open}#{equation}#{close})
      end
      
      %(<div#{id_attribute} class="#{(role = node.role) ? ['mathblock', role] * ' ' : 'mathblock'}">
#{title_element}<div class="content">
#{equation}
</div>
</div>)
    end

    def olist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['olist', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")

      result << %(<div#{id_attribute}#{class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?

      type_attribute = (keyword = node.list_marker_keyword) ? %( type="#{keyword}") : nil
      start_attribute = (node.attr? 'start') ? %( start="#{node.attr 'start'}") : nil
      result << %(<ol class="#{node.style}"#{type_attribute}#{start_attribute}>)

      node.items.each do |item|
        result << '<li>'
        result << %(<p>#{item.text}</p>)
        result << item.content if item.blocks?
        result << '</li>'
      end

      result << '</ol>'
      result << '</div>'
      result * EOL
    end

    def open node
      if (style = node.style) == 'abstract'
        if node.parent == node.document && node.document.doctype == 'book'
          warn 'asciidoctor: WARNING: abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
          ''
        else
          id_attr = node.id ? %( id="#{node.id}") : nil
          title_el = node.title? ? %(<div class="title">#{node.title}</div>) : nil
          %(<div#{id_attr} class="quoteblock abstract#{(role = node.role) && " #{role}"}">
#{title_el}<blockquote>
#{node.content}
</blockquote>
</div>)
        end
      elsif style == 'partintro' && (node.level != 0 || node.parent.context != :section || node.document.doctype != 'book')
        warn 'asciidoctor: ERROR: partintro block can only be used when doctype is book and it\'s a child of a book part. Excluding block content.'
        ''
      else
          id_attr = node.id ? %( id="#{node.id}") : nil
          title_el = node.title? ? %(<div class="title">#{node.title}</div>) : nil
        %(<div#{id_attr} class="openblock#{style && style != 'open' ? " #{style}" : ''}#{(role = node.role) && " #{role}"}">
#{title_el}<div class="content">
#{node.content}
</div>
</div>)
      end
    end

    def page_break node
      '<div style="page-break-after: always;"></div>'
    end

    def paragraph node
      attributes = if node.id
        if node.role
          %( id="#{node.id}" class="paragraph #{node.role}")
        else
          %( id="#{node.id}" class="paragraph")
        end
      elsif node.role
        %( class="paragraph #{node.role}")
      else
        ' class="paragraph"'
      end

      if node.title?
        %(<div#{attributes}>
<div class="title">#{node.title}</div>
<p>#{node.content}</p>
</div>)
      else
        %(<div#{attributes}>
<p>#{node.content}</p>
</div>)
      end
    end

    def preamble node
      toc = if (node.attr? 'toc') && (node.attr? 'toc-placement', 'preamble')
        %(\n<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{outline node.document}
</div>)
      end

      %(<div id="preamble">
<div class="sectionbody">
#{node.content}
</div>#{toc}
</div>)
    end

    def quote node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['quoteblock', node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : nil
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil
      if attribution || citetitle
        cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : nil
        attribution_text = attribution ? %(#{citetitle ? "<br#{@short_tag_slash}>\n" : nil}&#8212; #{attribution}) : nil
        attribution_element = %(\n<div class="attribution">\n#{cite_element}#{attribution_text}\n</div>)
      else
        attribution_element = nil
      end

      %(<div#{id_attribute}#{class_attribute}>#{title_element}
<blockquote>
#{node.content}
</blockquote>#{attribution_element}
</div>)
    end

    def thematic_break node
      %(<hr#{@short_tag_slash}>)
    end

    def sidebar node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
      %(<div#{id_attribute} class="#{(role = node.role) ? ['sidebarblock', role] * ' ' : 'sidebarblock'}">
<div class="content">
#{title_element}#{node.content}
</div>
</div>)
    end

    def table node
      result = [] 
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['tableblock', %(frame-#{node.attr 'frame', 'all'}), %(grid-#{node.attr 'grid', 'all'})]
      if (role_class = node.role)
        classes << role_class
      end
      class_attribute = %( class="#{classes * ' '}")
      styles = [(node.option? 'autowidth') ? nil : %(width: #{node.attr 'tablepcwidth'}%;), (node.attr? 'float') ? %(float: #{node.attr 'float'};) : nil].compact
      style_attribute = styles.size > 0 ? %( style="#{styles * ' '}") : nil

      result << %(<table#{id_attribute}#{class_attribute}#{style_attribute}>)
      result << %(<caption class="title">#{node.captioned_title}</caption>) if node.title?
      if (node.attr 'rowcount') > 0
        short_tag_slash_local = @short_tag_slash
        result << '<colgroup>'
        if node.option? 'autowidth'
          tag = %(<col#{short_tag_slash_local}>)
          node.columns.size.times do
            result << tag
          end
        else
          node.columns.each do |col|
            result << %(<col style="width: #{col.attr 'colpcwidth'}%;"#{short_tag_slash_local}>)
          end
        end
        result << '</colgroup>'
        [:head, :foot, :body].select {|tsec| !node.rows[tsec].empty? }.each do |tsec|
          result << %(<t#{tsec}>)
          node.rows[tsec].each do |row|
            result << '<tr>'
            row.each do |cell|
              if tsec == :head
                cell_content = cell.text
              else
                case cell.style
                when :asciidoc
                  cell_content = %(<div>#{cell.content}</div>)
                when :verse
                  cell_content = %(<div class="verse">#{cell.text}</div>)
                when :literal
                  cell_content = %(<div class="literal"><pre>#{cell.text}</pre></div>)
                else
                  cell_content = ''
                  cell.content.each do |text|
                    cell_content = %(#{cell_content}<p class="tableblock">#{text}</p>)
                  end
                end
              end

              cell_tag_name = (tsec == :head || cell.style == :header ? 'th' : 'td')
              cell_class_attribute = %( class="tableblock halign-#{cell.attr 'halign'} valign-#{cell.attr 'valign'}")
              cell_colspan_attribute = cell.colspan ? %( colspan="#{cell.colspan}") : nil
              cell_rowspan_attribute = cell.rowspan ? %( rowspan="#{cell.rowspan}") : nil
              cell_style_attribute = (node.document.attr? 'cellbgcolor') ? %( style="background-color: #{node.document.attr 'cellbgcolor'};") : nil
              result << %(<#{cell_tag_name}#{cell_class_attribute}#{cell_colspan_attribute}#{cell_rowspan_attribute}#{cell_style_attribute}>#{cell_content}</#{cell_tag_name}>)
            end
            result << '</tr>'
          end
          result << %(</t#{tsec}>)
        end
      end
      result << %(</table>)
      result * EOL
    end

    def toc node
      return '<!-- toc disabled -->' unless (doc = node.document).attr? 'toc'

      if node.id
        id_attr = %( id="#{node.id}")
        title_id_attr = ''
      elsif doc.embedded? || !(doc.attr? 'toc-placement')
        id_attr = ' id="toc"'
        title_id_attr = ' id="toctitle"'
      else
        id_attr = nil
        title_id_attr = nil
      end
      title = node.title? ? node.title : (doc.attr 'toc-title')
      levels = (node.attr? 'levels') ? (node.attr 'levels').to_i : nil
      role = node.role? ? node.role : (doc.attr 'toc-class', 'toc')

      %(<div#{id_attr} class="#{role}">
<div#{title_id_attr} class="title">#{title}</div>
#{outline doc, :toclevels => levels}
</div>)
    end

    def ulist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : nil
      div_classes = ['ulist', node.style, node.role].compact
      marker_checked = nil
      marker_unchecked = nil
      if (checklist = node.option? 'checklist')
        div_classes.insert 1, 'checklist'
        ul_class_attribute = ' class="checklist"'
        if node.option? 'interactive'
          if node.document.attr? 'htmlsyntax', 'xml'
            marker_checked = '<input type="checkbox" data-item-complete="1" checked="checked"/> '
            marker_unchecked = '<input type="checkbox" data-item-complete="0"/> '
          else
            marker_checked = '<input type="checkbox" data-item-complete="1" checked> '
            marker_unchecked = '<input type="checkbox" data-item-complete="0"> '
          end
        else
          if node.document.attr? 'icons', 'font'
            marker_checked = '<i class="icon-check"></i> '
            marker_unchecked = '<i class="icon-check-empty"></i> '
          else
            marker_checked = '&#10003; '
            marker_unchecked = '&#10063; '
          end
        end
      else
        ul_class_attribute = node.style ? %( class="#{node.style}") : nil
      end
      div_class_attribute = %( class="#{div_classes * ' '}")
      result << %(<div#{id_attribute}#{div_class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?
      result << %(<ul#{ul_class_attribute}>)

      node.items.each do |item|
        result << '<li>'
        if checklist && (item.attr? 'checkbox')
          result << %(<p>#{(item.attr? 'checked') ? marker_checked : marker_unchecked}#{item.text}</p>)
        else
          result << %(<p>#{item.text}</p>)
        end
        result << item.content if item.blocks?
        result << '</li>'
      end

      result << '</ul>'
      result << '</div>'
      result * EOL
    end

    def verse node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['verseblock', node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : nil
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil
      if attribution || citetitle
        cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : nil
        attribution_text = attribution ? %(#{citetitle ? "<br#{@short_tag_slash}>\n" : nil}&#8212; #{attribution}) : nil
        attribution_element = %(\n<div class="attribution">\n#{cite_element}#{attribution_text}\n</div>)
      else
        attribution_element = nil
      end

      %(<div#{id_attribute}#{class_attribute}>#{title_element}
<pre class="content">#{node.content}</pre>#{attribution_element}
</div>)
    end

    def video node
      xml = node.document.attr? 'htmlsyntax', 'xml'
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['videoblock', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : nil
      width_attribute = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
      height_attribute = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : nil
      case node.attr 'poster'
      when 'vimeo'
        start_anchor = (node.attr? 'start') ? "#at=#{node.attr 'start'}" : nil
        delimiter = '?'
        autoplay_param = (node.option? 'autoplay') ? "#{delimiter}autoplay=1" : nil
        delimiter = '&amp;' if autoplay_param
        loop_param = (node.option? 'loop') ? "#{delimiter}loop=1" : nil
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="//player.vimeo.com/video/#{node.attr 'target'}#{start_anchor}#{autoplay_param}#{loop_param}" frameborder="0"#{append_boolean_attribute 'webkitAllowFullScreen', xml}#{append_boolean_attribute 'mozallowfullscreen', xml}#{append_boolean_attribute 'allowFullScreen', xml}></iframe>
</div>
</div>)
      when 'youtube'
        start_param = (node.attr? 'start') ? "&amp;start=#{node.attr 'start'}" : nil
        end_param = (node.attr? 'end') ? "&amp;end=#{node.attr 'end'}" : nil
        autoplay_param = (node.option? 'autoplay') ? '&amp;autoplay=1' : nil
        loop_param = (node.option? 'loop') ? '&amp;loop=1' : nil
        controls_param = (node.option? 'nocontrols') ? '&amp;controls=0' : nil
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="//www.youtube.com/embed/#{node.attr 'target'}?rel=0#{start_param}#{end_param}#{autoplay_param}#{loop_param}#{controls_param}" frameborder="0"#{(node.option? 'nofullscreen') ? nil : (append_boolean_attribute 'allowfullscreen', xml)}></iframe>
</div>
</div>)
      else 
        poster_attribute = %(#{poster = node.attr 'poster'}).empty? ? nil : %( poster="#{node.media_uri poster}")
        time_anchor = ((node.attr? 'start') || (node.attr? 'end')) ? %(#t=#{node.attr 'start'}#{(node.attr? 'end') ? ',' : nil}#{node.attr 'end'}) : nil
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<video src="#{node.media_uri(node.attr 'target')}#{time_anchor}"#{width_attribute}#{height_attribute}#{poster_attribute}#{(node.option? 'autoplay') ? (append_boolean_attribute 'autoplay', xml) : nil}#{(node.option? 'nocontrols') ? nil : (append_boolean_attribute 'controls', xml)}#{(node.option? 'loop') ? (append_boolean_attribute 'loop', xml) : nil}>
Your browser does not support the video tag.
</video>
</div>
</div>)
      end
    end

    def inline_anchor node
      target = node.target
      case node.type
      when :xref
        refid = (node.attr 'refid') || target
        # FIXME seems like text should be prepared already
        text = node.text || (node.document.references[:ids][refid] || %([#{refid}]))
        %(<a href="#{target}">#{text}</a>)
      when :ref
        %(<a id="#{target}"></a>)
      when :link
        class_attr = (role = node.role) ? %( class="#{role}") : nil
        window_attr = (node.attr? 'window') ? %( target="#{node.attr 'window'}") : nil
        %(<a href="#{target}"#{class_attr}#{window_attr}>#{node.text}</a>)
      when :bibref
        %(<a id="#{target}"></a>[#{target}])
      else
        warn %(asciidoctor: WARNING: unknown anchor type: #{node.type.inspect})
      end
    end

    def inline_break node
      %(#{node.text}<br#{@short_tag_slash}>)
    end

    def inline_button node
      %(<b class="button">#{node.text}</b>)
    end

    def inline_callout node
      if node.document.attr? 'icons', 'font'
        %(<i class="conum" data-value="#{node.text}"></i><b>(#{node.text})</b>)
      elsif node.document.attr? 'icons'
        src = node.icon_uri("callouts/#{node.text}")
        %(<img src="#{src}" alt="#{node.text}"#{@short_tag_slash}>)
      else
        %(<b>(#{node.text})</b>)
      end
    end

    def inline_footnote node
      if (index = node.attr 'index')
        if node.type == :xref
          %(<span class="footnoteref">[<a class="footnote" href="#_footnote_#{index}" title="View footnote.">#{index}</a>]</span>)
        else
          id_attr = node.id ? %( id="_footnote_#{node.id}") : nil
          %(<span class="footnote"#{id_attr}>[<a id="_footnoteref_#{index}" class="footnote" href="#_footnote_#{index}" title="View footnote.">#{index}</a>]</span>)
        end
      elsif node.type == :xref
        %(<span class="footnoteref red" title="Unresolved footnote reference.">[#{node.text}]</span>)
      end
    end

    def inline_image node
      if (type = node.type) == 'icon' && (node.document.attr? 'icons', 'font') 
        style_class = "icon-#{node.target}"
        if node.attr? 'size'
          style_class = %(#{style_class} icon-#{node.attr 'size'})
        end
        if node.attr? 'rotate'
          style_class = %(#{style_class} icon-rotate-#{node.attr 'rotate'})
        end
        if node.attr? 'flip'
          style_class = %(#{style_class} icon-flip-#{node.attr 'flip'})
        end
        title_attribute = (node.attr? 'title') ? %( title="#{node.attr 'title'}") : nil
        img = %(<i class="#{style_class}"#{title_attribute}></i>)
      elsif type == 'icon' && !(node.document.attr? 'icons')
        img = %([#{node.attr 'alt'}])
      else
        resolved_target = (type == 'icon') ? (node.icon_uri node.target) : (node.image_uri node.target)

        attrs = ['alt', 'width', 'height', 'title'].map {|name|
          (node.attr? name) ? %( #{name}="#{node.attr name}") : nil
        }.join

        img = %(<img src="#{resolved_target}"#{attrs}#{@short_tag_slash}>)
      end

      if node.attr? 'link'
        window_attr = (node.attr? 'window') ? %( target="#{node.attr 'window'}") : nil
        img = %(<a class="image" href="#{node.attr 'link'}"#{window_attr}>#{img}</a>)
      end

      style_classes = (role = node.role) ? %(#{type} #{role}) : type
      style_attr = (node.attr? 'float') ? %( style="float: #{node.attr 'float'}") : nil

      %(<span class="#{style_classes}"#{style_attr}>#{img}</span>)
    end

    def inline_indexterm node
      node.type == :visible ? node.text : ''
    end

    def inline_kbd node
      if (keys = node.attr 'keys').size == 1
        %(<kbd>#{keys[0]}</kbd>)
      else
        key_combo = keys.map {|key| %(<kbd>#{key}</kbd>+) }.join.chop
        %(<span class="keyseq">#{key_combo}</span>)
      end
    end

    def inline_menu node
      menu = node.attr 'menu'
      if !(submenus = node.attr 'submenus').empty?
        submenu_path = submenus.map {|submenu| %(<span class="submenu">#{submenu}</span>&#160;&#9656; ) }.join.chop
        %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; #{submenu_path} <span class="menuitem">#{node.attr 'menuitem'}</span></span>)
      elsif (menuitem = node.attr 'menuitem')
        %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; <span class="menuitem">#{menuitem}</span></span>)
      else
        %(<span class="menu">#{menu}</span>)
      end
    end

    def inline_quoted node
      open, close, is_tag = QUOTE_TAGS[node.type]
      quoted_text = if (role = node.role)
        is_tag ? %(#{open.chop} class="#{role}">#{node.text}#{close}) : %(<span class="#{role}">#{open}#{node.text}#{close}</span>)
      else
        %(#{open}#{node.text}#{close})
      end

      node.id ? %(<a id="#{node.id}"></a>#{quoted_text}) : quoted_text
    end

    def append_boolean_attribute name, xml
      xml ? %( #{name}="#{name}") : %( #{name})
    end
  end
end
