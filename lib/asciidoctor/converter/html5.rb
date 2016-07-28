# encoding: UTF-8
module Asciidoctor
  # A built-in {Converter} implementation that generates HTML 5 output
  # consistent with the html5 backend from AsciiDoc Python.
  class Converter::Html5Converter < Converter::BuiltIn
    (QUOTE_TAGS = {
      :emphasis    => ['<em>',     '</em>',     true],
      :strong      => ['<strong>', '</strong>', true],
      :monospaced  => ['<code>',   '</code>',   true],
      :superscript => ['<sup>',    '</sup>',    true],
      :subscript   => ['<sub>',    '</sub>',    true],
      :double      => ['&#8220;',  '&#8221;',   false],
      :single      => ['&#8216;',  '&#8217;',   false],
      :mark        => ['<mark>',   '</mark>',   true],
      :asciimath   => ['\\$',      '\\$',       false],
      :latexmath   => ['\\(',      '\\)',       false]
      # Opal can't resolve these constants when referenced here
      #:asciimath   => INLINE_MATH_DELIMITERS[:asciimath] + [false],
      #:latexmath   => INLINE_MATH_DELIMITERS[:latexmath] + [false]
    }).default = [nil, nil, nil]

    SvgPreambleRx = /\A.*?(?=<svg\b)/m
    SvgStartTagRx = /\A<svg[^>]*>/
    DimensionAttributeRx = /\s(?:width|height|style)=(["']).*?\1/

    def initialize backend, opts = {}
      @xml_mode = opts[:htmlsyntax] == 'xml'
      @void_element_slash = @xml_mode ? '/' : nil
      @stylesheets = Stylesheets.instance
    end

    def document node
      result = []
      slash = @void_element_slash
      br = %(<br#{slash}>)
      unless (asset_uri_scheme = (node.attr 'asset-uri-scheme', 'https')).empty?
        asset_uri_scheme = %(#{asset_uri_scheme}:)
      end
      cdn_base = %(#{asset_uri_scheme}//cdnjs.cloudflare.com/ajax/libs)
      linkcss = node.safe >= SafeMode::SECURE || (node.attr? 'linkcss')
      result << '<!DOCTYPE html>'
      lang_attribute = (node.attr? 'nolang') ? nil : %( lang="#{node.attr 'lang', 'en'}")
      result << %(<html#{@xml_mode ? ' xmlns="http://www.w3.org/1999/xhtml"' : nil}#{lang_attribute}>)
      result << %(<head>
<meta charset="#{node.attr 'encoding', 'UTF-8'}"#{slash}>
<!--[if IE]><meta http-equiv="X-UA-Compatible" content="IE=edge"#{slash}><![endif]-->
<meta name="viewport" content="width=device-width, initial-scale=1.0"#{slash}>
<meta name="generator" content="Asciidoctor #{node.attr 'asciidoctor-version'}"#{slash}>)
      result << %(<meta name="application-name" content="#{node.attr 'app-name'}"#{slash}>) if node.attr? 'app-name'
      result << %(<meta name="description" content="#{node.attr 'description'}"#{slash}>) if node.attr? 'description'
      result << %(<meta name="keywords" content="#{node.attr 'keywords'}"#{slash}>) if node.attr? 'keywords'
      result << %(<meta name="author" content="#{node.attr 'authors'}"#{slash}>) if node.attr? 'authors'
      result << %(<meta name="copyright" content="#{node.attr 'copyright'}"#{slash}>) if node.attr? 'copyright'
      result << %(<title>#{node.doctitle :sanitize => true, :use_fallback => true}</title>)

      if DEFAULT_STYLESHEET_KEYS.include?(node.attr 'stylesheet')
        if (webfonts = node.attr 'webfonts')
          result << %(<link rel="stylesheet" href="#{asset_uri_scheme}//fonts.googleapis.com/css?family=#{webfonts.empty? ? 'Open+Sans:300,300italic,400,400italic,600,600italic%7CNoto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700' : webfonts}"#{slash}>)
        end
        if linkcss
          result << %(<link rel="stylesheet" href="#{node.normalize_web_path DEFAULT_STYLESHEET_NAME, (node.attr 'stylesdir', ''), false}"#{slash}>)
        else
          result << @stylesheets.embed_primary_stylesheet
        end
      elsif node.attr? 'stylesheet'
        if linkcss
          result << %(<link rel="stylesheet" href="#{node.normalize_web_path((node.attr 'stylesheet'), (node.attr 'stylesdir', ''))}"#{slash}>)
        else
          result << %(<style>
#{node.read_asset node.normalize_system_path((node.attr 'stylesheet'), (node.attr 'stylesdir', '')), :warn_on_failure => true}
</style>)
        end
      end

      if node.attr? 'icons', 'font'
        if node.attr? 'iconfont-remote'
          result << %(<link rel="stylesheet" href="#{node.attr 'iconfont-cdn', %[#{cdn_base}/font-awesome/4.6.3/css/font-awesome.min.css]}"#{slash}>)
        else
          iconfont_stylesheet = %(#{node.attr 'iconfont-name', 'font-awesome'}.css)
          result << %(<link rel="stylesheet" href="#{node.normalize_web_path iconfont_stylesheet, (node.attr 'stylesdir', ''), false}"#{slash}>)
        end
      end

      case (highlighter = node.attr 'source-highlighter')
      when 'coderay'
        if (node.attr 'coderay-css', 'class') == 'class'
          if linkcss
            result << %(<link rel="stylesheet" href="#{node.normalize_web_path @stylesheets.coderay_stylesheet_name, (node.attr 'stylesdir', ''), false}"#{slash}>)
          else
            result << @stylesheets.embed_coderay_stylesheet
          end
        end
      when 'pygments'
        if (node.attr 'pygments-css', 'class') == 'class'
          pygments_style = node.attr 'pygments-style'
          if linkcss
            result << %(<link rel="stylesheet" href="#{node.normalize_web_path @stylesheets.pygments_stylesheet_name(pygments_style), (node.attr 'stylesdir', ''), false}"#{slash}>)
          else
            result << (@stylesheets.embed_pygments_stylesheet pygments_style)
          end
        end
      end

      unless (docinfo_content = node.docinfo).empty?
        result << docinfo_content
      end

      result << '</head>'
      body_attrs = []
      body_attrs << %(id="#{node.id}") if node.id
      if (sectioned = node.sections?) && (node.attr? 'toc-class') && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
        body_attrs << %(class="#{node.doctype} #{node.attr 'toc-class'} toc-#{node.attr 'toc-position', 'header'}")
      else
        body_attrs << %(class="#{node.doctype}")
      end
      body_attrs << %(style="max-width: #{node.attr 'max-width'};") if node.attr? 'max-width'
      result << %(<body #{body_attrs * ' '}>)

      unless node.noheader
        result << '<div id="header">'
        if node.doctype == 'manpage'
          result << %(<h1>#{node.doctitle} Manual Page</h1>)
          if sectioned && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
            result << %(<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{outline node}
</div>)
          end
          # QUESTION should this h2 have an auto-generated id?
          result << %(<h2>#{node.attr 'manname-title'}</h2>
<div class="sectionbody">
<p>#{node.attr 'manname'} - #{node.attr 'manpurpose'}</p>
</div>)
        else
          if node.has_header?
            result << %(<h1>#{node.header.title}</h1>) unless node.notitle
            details = []
            if node.attr? 'author'
              details << %(<span id="author" class="author">#{node.attr 'author'}</span>#{br})
              if node.attr? 'email'
                details << %(<span id="email" class="email">#{node.sub_macros(node.attr 'email')}</span>#{br})
              end
              if (authorcount = (node.attr 'authorcount').to_i) > 1
                (2..authorcount).each do |idx|
                  details << %(<span id="author#{idx}" class="author">#{node.attr "author_#{idx}"}</span>#{br})
                  if node.attr? %(email_#{idx})
                    details << %(<span id="email#{idx}" class="email">#{node.sub_macros(node.attr "email_#{idx}")}</span>#{br})
                  end
                end
              end
            end
            if node.attr? 'revnumber'
              details << %(<span id="revnumber">#{((node.attr 'version-label') || '').downcase} #{node.attr 'revnumber'}#{(node.attr? 'revdate') ? ',' : ''}</span>)
            end
            if node.attr? 'revdate'
              details << %(<span id="revdate">#{node.attr 'revdate'}</span>)
            end
            if node.attr? 'revremark'
              details << %(#{br}<span id="revremark">#{node.attr 'revremark'}</span>)
            end
            unless details.empty?
              result << '<div class="details">'
              result.concat details
              result << '</div>'
            end
          end

          if sectioned && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
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
<hr#{slash}>)
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
        result << %(#{node.attr 'version-label'} #{node.attr 'revnumber'}#{br}) if node.attr? 'revnumber'
        result << %(#{node.attr 'last-update-label'} #{node.attr 'docdatetime'}) if (node.attr? 'last-update-label') && !(node.attr? 'reproducible')
        result << '</div>'
        result << '</div>'
      end

      unless (docinfo_content = node.docinfo :footer).empty?
        result << docinfo_content
      end

      # Load Javascript at the end of body for performance
      # See http://www.html5rocks.com/en/tutorials/speed/script-loading/
      case highlighter
      when 'highlightjs', 'highlight.js'
        highlightjs_path = node.attr 'highlightjsdir', %(#{cdn_base}/highlight.js/8.9.1)
        result << %(<link rel="stylesheet" href="#{highlightjs_path}/styles/#{node.attr 'highlightjs-theme', 'github'}.min.css"#{slash}>)
        result << %(<script src="#{highlightjs_path}/highlight.min.js"></script>
<script>hljs.initHighlighting()</script>)
      when 'prettify'
        prettify_path = node.attr 'prettifydir', %(#{cdn_base}/prettify/r298)
        result << %(<link rel="stylesheet" href="#{prettify_path}/#{node.attr 'prettify-theme', 'prettify'}.min.css"#{slash}>)
        result << %(<script src="#{prettify_path}/prettify.min.js"></script>
<script>prettyPrint()</script>)
      end

      if node.attr? 'stem'
        eqnums_val = node.attr 'eqnums', 'none'
        eqnums_val = 'AMS' if eqnums_val.empty?
        eqnums_opt = %( equationNumbers: { autoNumber: "#{eqnums_val}" } )
        # IMPORTANT inspect calls on delimiter arrays are intentional for JavaScript compat (emulates JSON.stringify)
        result << %(<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  messageStyle: "none",
  tex2jax: {
    inlineMath: [#{INLINE_MATH_DELIMITERS[:latexmath].inspect}],
    displayMath: [#{BLOCK_MATH_DELIMITERS[:latexmath].inspect}],
    ignoreClass: "nostem|nolatexmath"
  },
  asciimath2jax: {
    delimiters: [#{BLOCK_MATH_DELIMITERS[:asciimath].inspect}],
    ignoreClass: "nostem|noasciimath"
  },
  TeX: {#{eqnums_opt}}
});
</script>
<script src="#{cdn_base}/mathjax/2.6.0/MathJax.js?config=TeX-MML-AM_HTMLorMML"></script>)
      end

      result << '</body>'
      result << '</html>'
      result * EOL
    end

    def embedded node
      result = []
      if node.doctype == 'manpage'
        # QUESTION should notitle control the manual page title?
        unless node.notitle
          id_attr = node.id ? %( id="#{node.id}") : nil
          result << %(<h1#{id_attr}>#{node.doctitle} Manual Page</h1>)
        end
        # QUESTION should this h2 have an auto-generated id?
        result << %(<h2>#{node.attr 'manname-title'}</h2>
<div class="sectionbody">
<p>#{node.attr 'manname'} - #{node.attr 'manpurpose'}</p>
</div>)
      else
        if node.has_header? && !node.notitle
          id_attr = node.id ? %( id="#{node.id}") : nil
          result << %(<h1#{id_attr}>#{node.header.title}</h1>)
        end
      end

      if node.sections? && (node.attr? 'toc') && (toc_p = node.attr 'toc-placement') != 'macro' && toc_p != 'preamble'
        result << %(<div id="toc" class="toc">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{outline node}
</div>)
      end

      result << node.content

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << %(<div id="footnotes">
<hr#{@void_element_slash}>)
        node.footnotes.each do |footnote|
          result << %(<div class="footnote" id="_footnote_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a>. #{footnote.text}
</div>)
        end
        result << '</div>'
      end

      result * EOL
    end

    def outline node, opts = {}
      return unless node.sections?
      sectnumlevels = opts[:sectnumlevels] || (node.document.attr 'sectnumlevels', 3).to_i
      toclevels = opts[:toclevels] || (node.document.attr 'toclevels', 2).to_i
      result = []
      sections = node.sections
      # FIXME the level for special sections should be set correctly in the model
      # slevel will only be 0 if we have a book doctype with parts
      slevel = (first_section = sections[0]).level
      slevel = 1 if slevel == 0 && first_section.special
      result << %(<ul class="sectlevel#{slevel}">)
      sections.each do |section|
        section_num = (section.numbered && !section.caption && section.level <= sectnumlevels) ? %(#{section.sectnum} ) : nil
        if section.level < toclevels && (child_toc_level = outline section, :toclevels => toclevels, :secnumlevels => sectnumlevels)
          result << %(<li><a href="##{section.id}">#{section_num}#{section.captioned_title}</a>)
          result << child_toc_level
          result << '</li>'
        else
          result << %(<li><a href="##{section.id}">#{section_num}#{section.captioned_title}</a></li>)
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
          #  anchor = %(<a class="anchor" href="##{node.id}"><i class="fa fa-anchor"></i></a>)
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
        if (node.document.attr? 'icons', 'font') && !(node.attr? 'icon')
          %(<i class="fa icon-#{name}" title="#{node.caption}"></i>)
        else
          %(<img src="#{node.icon_uri name}" alt="#{node.caption}"#{@void_element_slash}>)
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
            %(<img src="#{node.icon_uri "callouts/#{num}"}" alt="#{num}"#{@void_element_slash}>)
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
        slash = @void_element_slash
        result << '<table>'
        if (node.attr? 'labelwidth') || (node.attr? 'itemwidth')
          result << '<colgroup>'
          col_style_attribute = (node.attr? 'labelwidth') ? %( style="width: #{(node.attr 'labelwidth').chomp '%'}%;") : nil
          result << %(<col#{col_style_attribute}#{slash}>)
          col_style_attribute = (node.attr? 'itemwidth') ? %( style="width: #{(node.attr 'itemwidth').chomp '%'}%;") : nil
          result << %(<col#{col_style_attribute}#{slash}>)
          result << '</colgroup>'
        end
        node.items.each do |terms, dd|
          result << '<tr>'
          result << %(<td class="hdlist1#{(node.option? 'strong') ? ' strong' : nil}">)
          terms_array = [*terms]
          last_term = terms_array[-1]
          terms_array.each do |dt|
            result << dt.text
            result << %(<br#{slash}>) if dt != last_term
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
      target = node.attr 'target'
      width_attr = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
      height_attr = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : nil
      if ((node.attr? 'format', 'svg', false) || (target.include? '.svg')) && node.document.safe < SafeMode::SECURE &&
          ((svg = (node.option? 'inline')) || (obj = (node.option? 'interactive')))
        if svg
          img = (read_svg_contents node, target) || %(<span class="alt">#{node.attr 'alt'}</span>)
        elsif obj
          fallback = (node.attr? 'fallback') ? %(<img src="#{node.image_uri(node.attr 'fallback')}" alt="#{node.attr 'alt'}"#{width_attr}#{height_attr}#{@void_element_slash}>) : %(<span class="alt">#{node.attr 'alt'}</span>)
          img = %(<object type="image/svg+xml" data="#{node.image_uri target}"#{width_attr}#{height_attr}>#{fallback}</object>)
        end
      end
      img ||= %(<img src="#{node.image_uri target}" alt="#{node.attr 'alt'}"#{width_attr}#{height_attr}#{@void_element_slash}>)
      if (link = node.attr 'link')
        img = %(<a class="image" href="#{link}">#{img}</a>)
      end
      id_attr = node.id ? %( id="#{node.id}") : nil
      classes = ['imageblock', node.style, node.role].compact
      class_attr = %( class="#{classes * ' '}")
      styles = []
      styles << %(text-align: #{node.attr 'align'}) if node.attr? 'align'
      styles << %(float: #{node.attr 'float'}) if node.attr? 'float'
      style_attr = styles.empty? ? nil : %( style="#{styles * ';'}")
      title_el = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : nil
      %(<div#{id_attr}#{class_attr}#{style_attr}>
<div class="content">
#{img}
</div>#{title_el}
</div>)
    end

    def listing node
      nowrap = !(node.document.attr? 'prewrap') || (node.option? 'nowrap')
      if node.style == 'source'
        if (language = node.attr 'language', nil, false)
          code_attrs = %( data-lang="#{language}")
        else
          code_attrs = nil
        end
        case node.document.attr 'source-highlighter'
        when 'coderay'
          pre_class = %( class="CodeRay highlight#{nowrap ? ' nowrap' : nil}")
        when 'pygments'
          pre_class = %( class="pygments highlight#{nowrap ? ' nowrap' : nil}")
        when 'highlightjs', 'highlight.js'
          pre_class = %( class="highlightjs highlight#{nowrap ? ' nowrap' : nil}")
          code_attrs = %( class="language-#{language}"#{code_attrs}) if language
        when 'prettify'
          pre_class = %( class="prettyprint highlight#{nowrap ? ' nowrap' : nil}#{(node.attr? 'linenums') ? ' linenums' : nil}")
          code_attrs = %( class="language-#{language}"#{code_attrs}) if language
        when 'html-pipeline'
          pre_class = language ? %( lang="#{language}") : nil
          code_attrs = nil
        else
          pre_class = %( class="highlight#{nowrap ? ' nowrap' : nil}")
          code_attrs = %( class="language-#{language}"#{code_attrs}) if language
        end
        pre_start = %(<pre#{pre_class}><code#{code_attrs}>)
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

    def stem node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
      open, close = BLOCK_MATH_DELIMITERS[node.style.to_sym]

      unless ((equation = node.content).start_with? open) && (equation.end_with? close)
        equation = %(#{open}#{equation}#{close})
      end

      %(<div#{id_attribute} class="#{(role = node.role) ? ['stemblock', role] * ' ' : 'stemblock'}">
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
          title_el = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
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
          title_el = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
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
      class_attribute = node.role ? %(class="paragraph #{node.role}") : 'class="paragraph"'
      attributes = node.id ? %(id="#{node.id}" #{class_attribute}) : class_attribute

      if node.title?
        %(<div #{attributes}>
<div class="title">#{node.title}</div>
<p>#{node.content}</p>
</div>)
      else
        %(<div #{attributes}>
<p>#{node.content}</p>
</div>)
      end
    end

    def preamble node
      if (doc = node.document).attr?('toc-placement', 'preamble') && doc.sections? && (doc.attr? 'toc')
        toc = %(
<div id="toc" class="#{doc.attr 'toc-class', 'toc'}">
<div id="toctitle">#{doc.attr 'toc-title'}</div>
#{outline doc}
</div>)
      else
        toc = nil
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
        attribution_text = attribution ? %(&#8212; #{attribution}#{citetitle ? "<br#{@void_element_slash}>\n" : nil}) : nil
        attribution_element = %(\n<div class="attribution">\n#{attribution_text}#{cite_element}\n</div>)
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
      %(<hr#{@void_element_slash}>)
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
      styles = []
      unless node.option? 'autowidth'
        if (tablepcwidth = node.attr 'tablepcwidth') == 100
          classes << 'spread'
        else
          styles << %(width: #{tablepcwidth}%;)
        end
      end
      if (role = node.role)
        classes << role
      end
      class_attribute = %( class="#{classes * ' '}")
      styles << %(float: #{node.attr 'float'};) if node.attr? 'float'
      style_attribute = styles.empty? ? nil : %( style="#{styles * ' '}")

      result << %(<table#{id_attribute}#{class_attribute}#{style_attribute}>)
      result << %(<caption class="title">#{node.captioned_title}</caption>) if node.title?
      if (node.attr 'rowcount') > 0
        slash = @void_element_slash
        result << '<colgroup>'
        if node.option? 'autowidth'
          tag = %(<col#{slash}>)
          node.columns.size.times do
            result << tag
          end
        else
          node.columns.each do |col|
            result << %(<col style="width: #{col.attr 'colpcwidth'}%;"#{slash}>)
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
      result << '</table>'
      result * EOL
    end

    def toc node
      unless (doc = node.document).attr?('toc-placement', 'macro') && doc.sections? && (doc.attr? 'toc')
        return '<!-- toc disabled -->'
      end

      if node.id
        id_attr = %( id="#{node.id}")
        title_id_attr = %( id="#{node.id}title")
      else
        id_attr = ' id="toc"'
        title_id_attr = ' id="toctitle"'
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
            marker_checked = '<i class="fa fa-check-square-o"></i> '
            marker_unchecked = '<i class="fa fa-square-o"></i> '
          else
            marker_checked = '&#10003; '
            marker_unchecked = '&#10063; '
          end
        end
      else
        ul_class_attribute = node.style ? %( class="#{node.style}") : nil
      end
      result << %(<div#{id_attribute} class="#{div_classes * ' '}">)
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
        attribution_text = attribution ? %(&#8212; #{attribution}#{citetitle ? "<br#{@void_element_slash}>\n" : nil}) : nil
        attribution_element = %(\n<div class="attribution">\n#{attribution_text}#{cite_element}\n</div>)
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
        unless (asset_uri_scheme = (node.document.attr 'asset-uri-scheme', 'https')).empty?
          asset_uri_scheme = %(#{asset_uri_scheme}:)
        end
        start_anchor = (node.attr? 'start', nil, false) ? %(#at=#{node.attr 'start'}) : nil
        delimiter = '?'
        autoplay_param = (node.option? 'autoplay') ? %(#{delimiter}autoplay=1) : nil
        delimiter = '&amp;' if autoplay_param
        loop_param = (node.option? 'loop') ? %(#{delimiter}loop=1) : nil
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="#{asset_uri_scheme}//player.vimeo.com/video/#{node.attr 'target'}#{start_anchor}#{autoplay_param}#{loop_param}" frameborder="0"#{(node.option? 'nofullscreen') ? nil : (append_boolean_attribute 'allowfullscreen', xml)}></iframe>
</div>
</div>)
      when 'youtube'
        unless (asset_uri_scheme = (node.document.attr 'asset-uri-scheme', 'https')).empty?
          asset_uri_scheme = %(#{asset_uri_scheme}:)
        end
        rel_param_val = (node.option? 'related') ? 1 : 0
        # NOTE start and end must be seconds (t parameter allows XmYs where X is minutes and Y is seconds)
        start_param = (node.attr? 'start', nil, false) ? %(&amp;start=#{node.attr 'start'}) : nil
        end_param = (node.attr? 'end', nil, false) ? %(&amp;end=#{node.attr 'end'}) : nil
        autoplay_param = (node.option? 'autoplay') ? '&amp;autoplay=1' : nil
        loop_param = (node.option? 'loop') ? '&amp;loop=1' : nil
        controls_param = (node.option? 'nocontrols') ? '&amp;controls=0' : nil
        # cover both ways of controlling fullscreen option
        if node.option? 'nofullscreen'
          fs_param = '&amp;fs=0'
          fs_attribute = nil
        else
          fs_param = nil
          fs_attribute = append_boolean_attribute 'allowfullscreen', xml
        end
        modest_param = (node.option? 'modest') ? '&amp;modestbranding=1' : nil
        theme_param = (node.attr? 'theme', nil, false) ? %(&amp;theme=#{node.attr 'theme'}) : nil
        hl_param = (node.attr? 'lang') ? %(&amp;hl=#{node.attr 'lang'}) : nil

        # parse video_id/list_id syntax where list_id (i.e., playlist) is optional
        target, list = (node.attr 'target').split '/', 2
        if (list ||= (node.attr 'list', nil, false))
          list_param = %(&amp;list=#{list})
        else
          # parse dynamic playlist syntax: video_id1,video_id2,...
          target, playlist = target.split ',', 2
          if (playlist ||= (node.attr 'playlist', nil, false))
            # INFO playlist bar doesn't appear in Firefox unless showinfo=1 and modestbranding=1
            list_param = %(&amp;playlist=#{playlist})
          else
            # NOTE for loop to work, playlist must be specified; use VIDEO_ID if there's no explicit playlist
            list_param = loop_param ? %(&amp;playlist=#{target}) : nil
          end
        end

        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="#{asset_uri_scheme}//www.youtube.com/embed/#{target}?rel=#{rel_param_val}#{start_param}#{end_param}#{autoplay_param}#{loop_param}#{controls_param}#{list_param}#{fs_param}#{modest_param}#{theme_param}#{hl_param}" frameborder="0"#{fs_attribute}></iframe>
</div>
</div>)
      else
        poster_attribute = %(#{poster = node.attr 'poster'}).empty? ? nil : %( poster="#{node.media_uri poster}")
        start_t = node.attr 'start', nil, false
        end_t = node.attr 'end', nil, false
        time_anchor = (start_t || end_t) ? %(#t=#{start_t}#{end_t ? ',' : nil}#{end_t}) : nil
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
        refid = node.attributes['refid'] || target
        # NOTE we lookup text in converter because DocBook doesn't need this logic
        text = node.text || (node.document.references[:ids][refid] || %([#{refid}]))
        # FIXME shouldn't target be refid? logic seems confused here
        %(<a href="#{target}">#{text}</a>)
      when :ref
        %(<a id="#{target}"></a>)
      when :link
        attrs = []
        attrs << %( id="#{node.id}") if node.id
        if (role = node.role)
          attrs << %( class="#{role}")
        end
        attrs << %( title="#{node.attr 'title'}") if node.attr? 'title', nil, false
        attrs << %( target="#{node.attr 'window'}") if node.attr? 'window', nil, false
        %(<a href="#{target}"#{attrs.join}>#{node.text}</a>)
      when :bibref
        %(<a id="#{target}"></a>[#{target}])
      else
        warn %(asciidoctor: WARNING: unknown anchor type: #{node.type.inspect})
      end
    end

    def inline_break node
      %(#{node.text}<br#{@void_element_slash}>)
    end

    def inline_button node
      %(<b class="button">#{node.text}</b>)
    end

    def inline_callout node
      if node.document.attr? 'icons', 'font'
        %(<i class="conum" data-value="#{node.text}"></i><b>(#{node.text})</b>)
      elsif node.document.attr? 'icons'
        src = node.icon_uri("callouts/#{node.text}")
        %(<img src="#{src}" alt="#{node.text}"#{@void_element_slash}>)
      else
        %(<b class="conum">(#{node.text})</b>)
      end
    end

    def inline_footnote node
      if (index = node.attr 'index')
        if node.type == :xref
          %(<sup class="footnoteref">[<a class="footnote" href="#_footnote_#{index}" title="View footnote.">#{index}</a>]</sup>)
        else
          id_attr = node.id ? %( id="_footnote_#{node.id}") : nil
          %(<sup class="footnote"#{id_attr}>[<a id="_footnoteref_#{index}" class="footnote" href="#_footnote_#{index}" title="View footnote.">#{index}</a>]</sup>)
        end
      elsif node.type == :xref
        %(<sup class="footnoteref red" title="Unresolved footnote reference.">[#{node.text}]</sup>)
      end
    end

    def inline_image node
      if (type = node.type) == 'icon' && (node.document.attr? 'icons', 'font')
        class_attr_val = %(fa fa-#{node.target})
        {'size' => 'fa-', 'rotate' => 'fa-rotate-', 'flip' => 'fa-flip-'}.each do |(key, prefix)|
          class_attr_val = %(#{class_attr_val} #{prefix}#{node.attr key}) if node.attr? key
        end
        title_attr = (node.attr? 'title') ? %( title="#{node.attr 'title'}") : nil
        img = %(<i class="#{class_attr_val}"#{title_attr}></i>)
      elsif type == 'icon' && !(node.document.attr? 'icons')
        img = %([#{node.attr 'alt'}])
      else
        target = node.target
        attrs = ['width', 'height', 'title'].map {|name| (node.attr? name) ? %( #{name}="#{node.attr name}") : nil }.join
        if type != 'icon' && ((node.attr? 'format', 'svg', false) || (target.include? '.svg')) &&
            node.document.safe < SafeMode::SECURE && ((svg = (node.option? 'inline')) || (obj = (node.option? 'interactive')))
          if svg
            img = (read_svg_contents node, target) || %(<span class="alt">#{node.attr 'alt'}</span>)
          elsif obj
            fallback = (node.attr? 'fallback') ? %(<img src="#{node.image_uri(node.attr 'fallback')}" alt="#{node.attr 'alt'}"#{attrs}#{@void_element_slash}>) : %(<span class="alt">#{node.attr 'alt'}</span>)
            img = %(<object type="image/svg+xml" data="#{node.image_uri target}"#{attrs}>#{fallback}</object>)
          end
        end
        img ||= %(<img src="#{type == 'icon' ? (node.icon_uri target) : (node.image_uri target)}" alt="#{node.attr 'alt'}"#{attrs}#{@void_element_slash}>)
      end
      if node.attr? 'link'
        window_attr = (node.attr? 'window') ? %( target="#{node.attr 'window'}") : nil
        img = %(<a class="image" href="#{node.attr 'link'}"#{window_attr}>#{img}</a>)
      end
      class_attr_val = (role = node.role) ? %(#{type} #{role}) : type
      style_attr = (node.attr? 'float') ? %( style="float: #{node.attr 'float'}") : nil
      %(<span class="#{class_attr_val}"#{style_attr}>#{img}</span>)
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
      if (role = node.role)
        if is_tag
          quoted_text = %(#{open.chop} class="#{role}">#{node.text}#{close})
        else
          quoted_text = %(<span class="#{role}">#{open}#{node.text}#{close}</span>)
        end
      else
        quoted_text = %(#{open}#{node.text}#{close})
      end

      node.id ? %(<a id="#{node.id}"></a>#{quoted_text}) : quoted_text
    end

    def append_boolean_attribute name, xml
      xml ? %( #{name}="#{name}") : %( #{name})
    end

    def read_svg_contents node, target
      if (svg = node.read_contents target, :start => (node.document.attr 'imagesdir'), :normalize => true, :label => 'SVG')
        svg = svg.sub SvgPreambleRx, '' unless svg.start_with? '<svg'
        old_start_tag = new_start_tag = nil
        # NOTE width, height and style attributes are removed if either width or height is specified
        ['width', 'height'].each do |dim|
          if node.attr? dim
            new_start_tag = (old_start_tag = (svg.match SvgStartTagRx)[0]).gsub DimensionAttributeRx, '' unless new_start_tag
            # QUESTION should we add px since it's already the default?
            new_start_tag = %(#{new_start_tag.chop} #{dim}="#{node.attr dim}px">)
          end
        end
        svg = %(#{new_start_tag}#{svg[old_start_tag.length..-1]}) if new_start_tag
      end
      svg
    end
  end
end
