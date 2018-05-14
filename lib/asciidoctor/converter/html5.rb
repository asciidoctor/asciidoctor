# encoding: UTF-8
module Asciidoctor
  # A built-in {Converter} implementation that generates HTML 5 output
  # consistent with the html5 backend from AsciiDoc Python.
  class Converter::Html5Converter < Converter::BuiltIn
    (QUOTE_TAGS = {
      :monospaced  => ['<code>',   '</code>',   true],
      :emphasis    => ['<em>',     '</em>',     true],
      :strong      => ['<strong>', '</strong>', true],
      :double      => ['&#8220;',  '&#8221;',   false],
      :single      => ['&#8216;',  '&#8217;',   false],
      :mark        => ['<mark>',   '</mark>',   true],
      :superscript => ['<sup>',    '</sup>',    true],
      :subscript   => ['<sub>',    '</sub>',    true],
      :asciimath   => ['\$',       '\$',        false],
      :latexmath   => ['\(',       '\)',        false]
      # Opal can't resolve these constants when referenced here
      #:asciimath   => INLINE_MATH_DELIMITERS[:asciimath] + [false],
      #:latexmath   => INLINE_MATH_DELIMITERS[:latexmath] + [false]
    }).default = ['', '', false]

    DropAnchorRx = /<(?:a[^>+]+|\/a)>/
    StemBreakRx = / *\\\n(?:\\?\n)*|\n\n+/
    SvgPreambleRx = /\A.*?(?=<svg\b)/m
    SvgStartTagRx = /\A<svg[^>]*>/
    DimensionAttributeRx = /\s(?:width|height|style)=(["']).*?\1/

    def initialize backend, opts = {}
      @xml_mode = opts[:htmlsyntax] == 'xml'
      @void_element_slash = @xml_mode ? '/' : nil
      @stylesheets = Stylesheets.instance
    end

    def document node
      slash = @void_element_slash
      br = %(<br#{slash}>)
      unless (asset_uri_scheme = (node.attr 'asset-uri-scheme', 'https')).empty?
        asset_uri_scheme = %(#{asset_uri_scheme}:)
      end
      cdn_base = %(#{asset_uri_scheme}//cdnjs.cloudflare.com/ajax/libs)
      linkcss = node.attr? 'linkcss'
      result = ['<!DOCTYPE html>']
      lang_attribute = (node.attr? 'nolang') ? '' : %( lang="#{node.attr 'lang', 'en'}")
      result << %(<html#{@xml_mode ? ' xmlns="http://www.w3.org/1999/xhtml"' : ''}#{lang_attribute}>)
      result << %(<head>
<meta charset="#{node.attr 'encoding', 'UTF-8'}"#{slash}>
<!--[if IE]><meta http-equiv="X-UA-Compatible" content="IE=edge"#{slash}><![endif]-->
<meta name="viewport" content="width=device-width, initial-scale=1.0"#{slash}>
<meta name="generator" content="Asciidoctor #{node.attr 'asciidoctor-version'}"#{slash}>)
      result << %(<meta name="application-name" content="#{node.attr 'app-name'}"#{slash}>) if node.attr? 'app-name'
      result << %(<meta name="description" content="#{node.attr 'description'}"#{slash}>) if node.attr? 'description'
      result << %(<meta name="keywords" content="#{node.attr 'keywords'}"#{slash}>) if node.attr? 'keywords'
      result << %(<meta name="author" content="#{((authors = node.attr 'authors').include? '<') ? (authors.gsub XmlSanitizeRx, '') : authors}"#{slash}>) if node.attr? 'authors'
      result << %(<meta name="copyright" content="#{node.attr 'copyright'}"#{slash}>) if node.attr? 'copyright'
      if node.attr? 'favicon'
        if (icon_href = node.attr 'favicon').empty?
          icon_href, icon_type = 'favicon.ico', 'image/x-icon'
        else
          icon_type = (icon_ext = ::File.extname icon_href) == '.ico' ? 'image/x-icon' : %(image/#{icon_ext[1..-1]})
        end
        result << %(<link rel="icon" type="#{icon_type}" href="#{icon_href}"#{slash}>)
      end
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
#{node.read_asset node.normalize_system_path((node.attr 'stylesheet'), (node.attr 'stylesdir', '')), :warn_on_failure => true, :label => 'stylesheet'}
</style>)
        end
      end

      if node.attr? 'icons', 'font'
        if node.attr? 'iconfont-remote'
          result << %(<link rel="stylesheet" href="#{node.attr 'iconfont-cdn', %[#{cdn_base}/font-awesome/#{FONT_AWESOME_VERSION}/css/font-awesome.min.css]}"#{slash}>)
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
      body_attrs = node.id ? [%(id="#{node.id}")] : []
      if (sectioned = node.sections?) && (node.attr? 'toc-class') && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
        classes = [node.doctype, (node.attr 'toc-class'), %(toc-#{node.attr 'toc-position', 'header'})]
      else
        classes = [node.doctype]
      end
      classes << (node.attr 'docrole') if node.attr? 'docrole'
      body_attrs << %(class="#{classes.join ' '}")
      body_attrs << %(style="max-width: #{node.attr 'max-width'};") if node.attr? 'max-width'
      result << %(<body #{body_attrs.join ' '}>)

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
          result << (generate_manname_section node) if node.attr? 'manpurpose'
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
          result << %(<div class="footnote" id="_footnotedef_#{footnote.index}">
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
        highlightjs_path = node.attr 'highlightjsdir', %(#{cdn_base}/highlight.js/9.12.0)
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
<script src="#{cdn_base}/mathjax/#{MATHJAX_VERSION}/MathJax.js?config=TeX-MML-AM_HTMLorMML"></script>)
      end

      result << '</body>'
      result << '</html>'
      result.join LF
    end

    def embedded node
      result = []
      if node.doctype == 'manpage'
        # QUESTION should notitle control the manual page title?
        unless node.notitle
          id_attr = node.id ? %( id="#{node.id}") : ''
          result << %(<h1#{id_attr}>#{node.doctitle} Manual Page</h1>)
        end
        result << (generate_manname_section node) if node.attr? 'manpurpose'
      else
        if node.has_header? && !node.notitle
          id_attr = node.id ? %( id="#{node.id}") : ''
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
          result << %(<div class="footnote" id="_footnotedef_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a>. #{footnote.text}
</div>)
        end
        result << '</div>'
      end

      result.join LF
    end

    def outline node, opts = {}
      return unless node.sections?
      sectnumlevels = opts[:sectnumlevels] || (node.document.attr 'sectnumlevels', 3).to_i
      toclevels = opts[:toclevels] || (node.document.attr 'toclevels', 2).to_i
      sections = node.sections
      # FIXME top level is incorrect if a multipart book starts with a special section defined at level 0
      result = [%(<ul class="sectlevel#{sections[0].level}">)]
      sections.each do |section|
        slevel = section.level
        if section.caption
          stitle = section.captioned_title
        elsif section.numbered && slevel <= sectnumlevels
          stitle = %(#{section.sectnum} #{section.title})
        else
          stitle = section.title
        end
        stitle = stitle.gsub DropAnchorRx, '' if stitle.include? '<a'
        if slevel < toclevels && (child_toc_level = outline section, :toclevels => toclevels, :secnumlevels => sectnumlevels)
          result << %(<li><a href="##{section.id}">#{stitle}</a>)
          result << child_toc_level
          result << '</li>'
        else
          result << %(<li><a href="##{section.id}">#{stitle}</a></li>)
        end
      end
      result << '</ul>'
      result.join LF
    end

    def section node
      if (level = node.level) == 0
        sect0 = true
        title = node.numbered && level <= (node.document.attr 'sectnumlevels', 3).to_i ? %(#{node.sectnum} #{node.title}) : node.title
      else
        title = node.numbered && !node.caption && level <= (node.document.attr 'sectnumlevels', 3).to_i ? %(#{node.sectnum} #{node.title}) : node.captioned_title
      end
      if node.id
        id_attr = %( id="#{id = node.id}")
        if (doc_attrs = node.document.attributes).key? 'sectlinks'
          title = %(<a class="link" href="##{id}">#{title}</a>)
        end
        if doc_attrs.key? 'sectanchors'
          # QUESTION should we add a font-based icon in anchor if icons=font?
          if doc_attrs['sectanchors'] == 'after'
            title = %(#{title}<a class="anchor" href="##{id}"></a>)
          else
            title = %(<a class="anchor" href="##{id}"></a>#{title})
          end
        end
      else
        id_attr = ''
      end

      if sect0
        %(<h1#{id_attr} class="sect0#{(role = node.role) ? " #{role}" : ''}">#{title}</h1>
#{node.content})
      else
        %(<div class="sect#{level}#{(role = node.role) ? " #{role}" : ''}">
<h#{level + 1}#{id_attr}>#{title}</h#{level + 1}>
#{level == 1 ? %[<div class="sectionbody">
#{node.content}
</div>] : node.content}
</div>)
      end
    end

    def admonition node
      id_attr = node.id ? %( id="#{node.id}") : ''
      name = node.attr 'name'
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
      if node.document.attr? 'icons'
        if (node.document.attr? 'icons', 'font') && !(node.attr? 'icon')
          label = %(<i class="fa icon-#{name}" title="#{node.attr 'textlabel'}"></i>)
        else
          label = %(<img src="#{node.icon_uri name}" alt="#{node.attr 'textlabel'}"#{@void_element_slash}>)
        end
      else
        label = %(<div class="title">#{node.attr 'textlabel'}</div>)
      end
      %(<div#{id_attr} class="admonitionblock #{name}#{(role = node.role) ? " #{role}" : ''}">
<table>
<tr>
<td class="icon">
#{label}
</td>
<td class="content">
#{title_element}#{node.content}
</td>
</tr>
</table>
</div>)
    end

    def audio node
      xml = @xml_mode
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = ['audioblock', node.role].compact
      class_attribute = %( class="#{classes.join ' '}")
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
      start_t = node.attr 'start', nil, false
      end_t = node.attr 'end', nil, false
      time_anchor = (start_t || end_t) ? %(#t=#{start_t || ''}#{end_t ? ",#{end_t}" : ''}) : ''
      %(<div#{id_attribute}#{class_attribute}>
#{title_element}<div class="content">
<audio src="#{node.media_uri(node.attr 'target')}#{time_anchor}"#{(node.option? 'autoplay') ? (append_boolean_attribute 'autoplay', xml) : ''}#{(node.option? 'nocontrols') ? '' : (append_boolean_attribute 'controls', xml)}#{(node.option? 'loop') ? (append_boolean_attribute 'loop', xml) : ''}>
Your browser does not support the audio tag.
</audio>
</div>
</div>)
    end

    def colist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = ['colist', node.style, node.role].compact
      class_attribute = %( class="#{classes.join ' '}")

      result << %(<div#{id_attribute}#{class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?

      if node.document.attr? 'icons'
        result << '<table>'
        font_icons, num = (node.document.attr? 'icons', 'font'), 0
        node.items.each do |item|
          num += 1
          if font_icons
            num_label = %(<i class="conum" data-value="#{num}"></i><b>#{num}</b>)
          else
            num_label = %(<img src="#{node.icon_uri "callouts/#{num}"}" alt="#{num}"#{@void_element_slash}>)
          end
          result << %(<tr>
<td>#{num_label}</td>
<td>#{item.text}#{item.blocks? ? LF + item.content : ''}</td>
</tr>)
        end
        result << '</table>'
      else
        result << '<ol>'
        node.items.each do |item|
          result << %(<li>
<p>#{item.text}</p>#{item.blocks? ? LF + item.content : ''}
</li>)
        end
        result << '</ol>'
      end

      result << '</div>'
      result.join LF
    end

    def dlist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : ''

      classes = case node.style
      when 'qanda'
        ['qlist', 'qanda', node.role]
      when 'horizontal'
        ['hdlist', node.role]
      else
        ['dlist', node.style, node.role]
      end.compact

      class_attribute = %( class="#{classes.join ' '}")

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
          col_style_attribute = (node.attr? 'labelwidth') ? %( style="width: #{(node.attr 'labelwidth').chomp '%'}%;") : ''
          result << %(<col#{col_style_attribute}#{slash}>)
          col_style_attribute = (node.attr? 'itemwidth') ? %( style="width: #{(node.attr 'itemwidth').chomp '%'}%;") : ''
          result << %(<col#{col_style_attribute}#{slash}>)
          result << '</colgroup>'
        end
        node.items.each do |terms, dd|
          result << '<tr>'
          result << %(<td class="hdlist1#{(node.option? 'strong') ? ' strong' : ''}">)
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
        dt_style_attribute = node.style ? '' : ' class="hdlist1"'
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
      result.join LF
    end

    def example node
      id_attribute = node.id ? %( id="#{node.id}") : ''
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : ''

      %(<div#{id_attribute} class="exampleblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{node.content}
</div>
</div>)
    end

    def floating_title node
      tag_name = %(h#{node.level + 1})
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = [node.style, node.role].compact
      %(<#{tag_name}#{id_attribute} class="#{classes.join ' '}">#{node.title}</#{tag_name}>)
    end

    def image node
      target = node.attr 'target'
      width_attr = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : ''
      height_attr = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : ''
      if ((node.attr? 'format', 'svg', false) || (target.include? '.svg')) && node.document.safe < SafeMode::SECURE &&
          ((svg = (node.option? 'inline')) || (obj = (node.option? 'interactive')))
        if svg
          img = (read_svg_contents node, target) || %(<span class="alt">#{node.alt}</span>)
        elsif obj
          fallback = (node.attr? 'fallback') ? %(<img src="#{node.image_uri(node.attr 'fallback')}" alt="#{encode_quotes node.alt}"#{width_attr}#{height_attr}#{@void_element_slash}>) : %(<span class="alt">#{node.alt}</span>)
          img = %(<object type="image/svg+xml" data="#{node.image_uri target}"#{width_attr}#{height_attr}>#{fallback}</object>)
        end
      end
      img ||= %(<img src="#{node.image_uri target}" alt="#{encode_quotes node.alt}"#{width_attr}#{height_attr}#{@void_element_slash}>)
      if node.attr? 'link', nil, false
        img = %(<a class="image" href="#{node.attr 'link'}"#{(append_link_constraint_attrs node).join}>#{img}</a>)
      end
      id_attr = node.id ? %( id="#{node.id}") : ''
      classes = ['imageblock']
      classes << (node.attr 'float') if node.attr? 'float'
      classes << %(text-#{node.attr 'align'}) if node.attr? 'align'
      classes << node.role if node.role
      class_attr = %( class="#{classes.join ' '}")
      title_el = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : ''
      %(<div#{id_attr}#{class_attr}>
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
          code_attrs = ''
        end
        case node.document.attr 'source-highlighter'
        when 'coderay'
          pre_class = %( class="CodeRay highlight#{nowrap ? ' nowrap' : ''}")
        when 'pygments'
          if (node.document.attr? 'pygments-css', 'inline')
            @pygments_bg = @stylesheets.pygments_background(node.document.attr 'pygments-style') unless defined? @pygments_bg
            pre_class = %( class="pygments highlight#{nowrap ? ' nowrap' : ''}" style="background: #{@pygments_bg}")
          else
            pre_class = %( class="pygments highlight#{nowrap ? ' nowrap' : ''}")
          end
        when 'highlightjs', 'highlight.js'
          pre_class = %( class="highlightjs highlight#{nowrap ? ' nowrap' : ''}")
          code_attrs = %( class="language-#{language} hljs"#{code_attrs}) if language
        when 'prettify'
          pre_class = %( class="prettyprint highlight#{nowrap ? ' nowrap' : ''}#{(node.attr? 'linenums', nil, false) ? ' linenums' : ''}")
          code_attrs = %( class="language-#{language}"#{code_attrs}) if language
        when 'html-pipeline'
          pre_class = language ? %( lang="#{language}") : ''
          code_attrs = ''
        else
          pre_class = %( class="highlight#{nowrap ? ' nowrap' : ''}")
          code_attrs = %( class="language-#{language}"#{code_attrs}) if language
        end
        pre_start = %(<pre#{pre_class}><code#{code_attrs}>)
        pre_end = '</code></pre>'
      else
        pre_start = %(<pre#{nowrap ? ' class="nowrap"' : ''}>)
        pre_end = '</pre>'
      end

      id_attribute = node.id ? %( id="#{node.id}") : ''
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : ''
      %(<div#{id_attribute} class="listingblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{pre_start}#{node.content}#{pre_end}
</div>
</div>)
    end

    def literal node
      id_attribute = node.id ? %( id="#{node.id}") : ''
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
      nowrap = !(node.document.attr? 'prewrap') || (node.option? 'nowrap')
      %(<div#{id_attribute} class="literalblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
<pre#{nowrap ? ' class="nowrap"' : ''}>#{node.content}</pre>
</div>
</div>)
    end

    def stem node
      id_attribute = node.id ? %( id="#{node.id}") : ''
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
      open, close = BLOCK_MATH_DELIMITERS[style = node.style.to_sym]
      equation = node.content

      if style == :asciimath && (equation.include? LF)
        br = %(<br#{@void_element_slash}>#{LF})
        equation = equation.gsub(StemBreakRx) { %(#{close}#{br * ($&.count LF)}#{open}) }
      end

      unless (equation.start_with? open) && (equation.end_with? close)
        equation = %(#{open}#{equation}#{close})
      end

      %(<div#{id_attribute} class="stemblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{equation}
</div>
</div>)
    end

    def olist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = ['olist', node.style, node.role].compact
      class_attribute = %( class="#{classes.join ' '}")

      result << %(<div#{id_attribute}#{class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?

      type_attribute = (keyword = node.list_marker_keyword) ? %( type="#{keyword}") : ''
      start_attribute = (node.attr? 'start') ? %( start="#{node.attr 'start'}") : ''
      reversed_attribute = (node.option? 'reversed') ? (append_boolean_attribute 'reversed', @xml_mode) : ''
      result << %(<ol class="#{node.style}"#{type_attribute}#{start_attribute}#{reversed_attribute}>)

      node.items.each do |item|
        result << '<li>'
        result << %(<p>#{item.text}</p>)
        result << item.content if item.blocks?
        result << '</li>'
      end

      result << '</ol>'
      result << '</div>'
      result.join LF
    end

    def open node
      if (style = node.style) == 'abstract'
        if node.parent == node.document && node.document.doctype == 'book'
          logger.warn 'abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
          ''
        else
          id_attr = node.id ? %( id="#{node.id}") : ''
          title_el = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
          %(<div#{id_attr} class="quoteblock abstract#{(role = node.role) ? " #{role}" : ''}">
#{title_el}<blockquote>
#{node.content}
</blockquote>
</div>)
        end
      elsif style == 'partintro' && (node.level > 0 || node.parent.context != :section || node.document.doctype != 'book')
        logger.error 'partintro block can only be used when doctype is book and must be a child of a book part. Excluding block content.'
        ''
      else
          id_attr = node.id ? %( id="#{node.id}") : ''
          title_el = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
        %(<div#{id_attr} class="openblock#{style && style != 'open' ? " #{style}" : ''}#{(role = node.role) ? " #{role}" : ''}">
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
        toc = ''
      end

      %(<div id="preamble">
<div class="sectionbody">
#{node.content}
</div>#{toc}
</div>)
    end

    def quote node
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = ['quoteblock', node.role].compact
      class_attribute = %( class="#{classes.join ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : ''
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil
      if attribution || citetitle
        cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : ''
        attribution_text = attribution ? %(&#8212; #{attribution}#{citetitle ? "<br#{@void_element_slash}>\n" : ''}) : ''
        attribution_element = %(\n<div class="attribution">\n#{attribution_text}#{cite_element}\n</div>)
      else
        attribution_element = ''
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
      id_attribute = node.id ? %( id="#{node.id}") : ''
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
      %(<div#{id_attribute} class="sidebarblock#{(role = node.role) ? " #{role}" : ''}">
<div class="content">
#{title_element}#{node.content}
</div>
</div>)
    end

    def table node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = ['tableblock', %(frame-#{node.attr 'frame', 'all'}), %(grid-#{node.attr 'grid', 'all'})]
      if (stripes = node.attr 'stripes')
        classes << %(stripes-#{stripes})
      end
      styles = []
      if (autowidth = node.attributes['autowidth-option']) && !(node.attr? 'width', nil, false)
        classes << 'fit-content'
      elsif (tablewidth = node.attr 'tablepcwidth') == 100
        classes << 'stretch'
      else
        styles << %(width: #{tablewidth}%;)
      end
      classes << (node.attr 'float') if node.attr? 'float'
      if (role = node.role)
        classes << role
      end
      class_attribute = %( class="#{classes.join ' '}")
      style_attribute = styles.empty? ? '' : %( style="#{styles.join ' '}")

      result << %(<table#{id_attribute}#{class_attribute}#{style_attribute}>)
      result << %(<caption class="title">#{node.captioned_title}</caption>) if node.title?
      if (node.attr 'rowcount') > 0
        slash = @void_element_slash
        result << '<colgroup>'
        if autowidth
          result += (Array.new node.columns.size, %(<col#{slash}>))
        else
          node.columns.each do |col|
            result << (col.attributes['autowidth-option'] ? %(<col#{slash}>) : %(<col style="width: #{col.attr 'colpcwidth'}%;"#{slash}>))
          end
        end
        result << '</colgroup>'
        node.rows.by_section.each do |tsec, rows|
          next if rows.empty?
          result << %(<t#{tsec}>)
          rows.each do |row|
            result << '<tr>'
            row.each do |cell|
              if tsec == :head
                cell_content = cell.text
              else
                case cell.style
                when :asciidoc
                  cell_content = %(<div class="content">#{cell.content}</div>)
                when :verse
                  cell_content = %(<div class="verse">#{cell.text}</div>)
                when :literal
                  cell_content = %(<div class="literal"><pre>#{cell.text}</pre></div>)
                else
                  cell_content = (cell_content = cell.content).empty? ? '' : %(<p class="tableblock">#{cell_content.join '</p>
<p class="tableblock">'}</p>)
                end
              end

              cell_tag_name = (tsec == :head || cell.style == :header ? 'th' : 'td')
              cell_class_attribute = %( class="tableblock halign-#{cell.attr 'halign'} valign-#{cell.attr 'valign'}")
              cell_colspan_attribute = cell.colspan ? %( colspan="#{cell.colspan}") : ''
              cell_rowspan_attribute = cell.rowspan ? %( rowspan="#{cell.rowspan}") : ''
              cell_style_attribute = (node.document.attr? 'cellbgcolor') ? %( style="background-color: #{node.document.attr 'cellbgcolor'};") : ''
              result << %(<#{cell_tag_name}#{cell_class_attribute}#{cell_colspan_attribute}#{cell_rowspan_attribute}#{cell_style_attribute}>#{cell_content}</#{cell_tag_name}>)
            end
            result << '</tr>'
          end
          result << %(</t#{tsec}>)
        end
      end
      result << '</table>'
      result.join LF
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
      id_attribute = node.id ? %( id="#{node.id}") : ''
      div_classes = ['ulist', node.style, node.role].compact
      marker_checked = marker_unchecked = ''
      if (checklist = node.option? 'checklist')
        div_classes.unshift div_classes.shift, 'checklist'
        ul_class_attribute = ' class="checklist"'
        if node.option? 'interactive'
          if @xml_mode
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
        ul_class_attribute = node.style ? %( class="#{node.style}") : ''
      end
      result << %(<div#{id_attribute} class="#{div_classes.join ' '}">)
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
      result.join LF
    end

    def verse node
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = ['verseblock', node.role].compact
      class_attribute = %( class="#{classes.join ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : ''
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil
      if attribution || citetitle
        cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : ''
        attribution_text = attribution ? %(&#8212; #{attribution}#{citetitle ? "<br#{@void_element_slash}>\n" : ''}) : ''
        attribution_element = %(\n<div class="attribution">\n#{attribution_text}#{cite_element}\n</div>)
      else
        attribution_element = ''
      end

      %(<div#{id_attribute}#{class_attribute}>#{title_element}
<pre class="content">#{node.content}</pre>#{attribution_element}
</div>)
    end

    def video node
      xml = @xml_mode
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = ['videoblock']
      classes << (node.attr 'float') if node.attr? 'float'
      classes << %(text-#{node.attr 'align'}) if node.attr? 'align'
      classes << node.role if node.role
      class_attribute = %( class="#{classes.join ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : ''
      width_attribute = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : ''
      height_attribute = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : ''
      case node.attr 'poster'
      when 'vimeo'
        unless (asset_uri_scheme = (node.document.attr 'asset-uri-scheme', 'https')).empty?
          asset_uri_scheme = %(#{asset_uri_scheme}:)
        end
        start_anchor = (node.attr? 'start', nil, false) ? %(#at=#{node.attr 'start'}) : ''
        delimiter = '?'
        if node.option? 'autoplay'
          autoplay_param = %(#{delimiter}autoplay=1)
          delimiter = '&amp;'
        else
          autoplay_param = ''
        end
        loop_param = (node.option? 'loop') ? %(#{delimiter}loop=1) : ''
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="#{asset_uri_scheme}//player.vimeo.com/video/#{node.attr 'target'}#{start_anchor}#{autoplay_param}#{loop_param}" frameborder="0"#{(node.option? 'nofullscreen') ? '' : (append_boolean_attribute 'allowfullscreen', xml)}></iframe>
</div>
</div>)
      when 'youtube'
        unless (asset_uri_scheme = (node.document.attr 'asset-uri-scheme', 'https')).empty?
          asset_uri_scheme = %(#{asset_uri_scheme}:)
        end
        rel_param_val = (node.option? 'related') ? 1 : 0
        # NOTE start and end must be seconds (t parameter allows XmYs where X is minutes and Y is seconds)
        start_param = (node.attr? 'start', nil, false) ? %(&amp;start=#{node.attr 'start'}) : ''
        end_param = (node.attr? 'end', nil, false) ? %(&amp;end=#{node.attr 'end'}) : ''
        autoplay_param = (node.option? 'autoplay') ? '&amp;autoplay=1' : ''
        loop_param = (has_loop_param = node.option? 'loop') ? '&amp;loop=1' : ''
        controls_param = (node.option? 'nocontrols') ? '&amp;controls=0' : ''
        # cover both ways of controlling fullscreen option
        if node.option? 'nofullscreen'
          fs_param = '&amp;fs=0'
          fs_attribute = ''
        else
          fs_param = ''
          fs_attribute = append_boolean_attribute 'allowfullscreen', xml
        end
        modest_param = (node.option? 'modest') ? '&amp;modestbranding=1' : ''
        theme_param = (node.attr? 'theme', nil, false) ? %(&amp;theme=#{node.attr 'theme'}) : ''
        hl_param = (node.attr? 'lang') ? %(&amp;hl=#{node.attr 'lang'}) : ''

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
            list_param = has_loop_param ? %(&amp;playlist=#{target}) : ''
          end
        end

        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="#{asset_uri_scheme}//www.youtube.com/embed/#{target}?rel=#{rel_param_val}#{start_param}#{end_param}#{autoplay_param}#{loop_param}#{controls_param}#{list_param}#{fs_param}#{modest_param}#{theme_param}#{hl_param}" frameborder="0"#{fs_attribute}></iframe>
</div>
</div>)
      else
        poster_attribute = (val = node.attr 'poster', nil, false).nil_or_empty? ? '' : %( poster="#{node.media_uri val}")
        preload_attribute = (val = node.attr 'preload', nil, false).nil_or_empty? ? '' : %( preload="#{val}")
        start_t = node.attr 'start', nil, false
        end_t = node.attr 'end', nil, false
        time_anchor = (start_t || end_t) ? %(#t=#{start_t || ''}#{end_t ? ",#{end_t}" : ''}) : ''
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<video src="#{node.media_uri(node.attr 'target')}#{time_anchor}"#{width_attribute}#{height_attribute}#{poster_attribute}#{(node.option? 'autoplay') ? (append_boolean_attribute 'autoplay', xml) : ''}#{(node.option? 'nocontrols') ? '' : (append_boolean_attribute 'controls', xml)}#{(node.option? 'loop') ? (append_boolean_attribute 'loop', xml) : ''}#{preload_attribute}>
Your browser does not support the video tag.
</video>
</div>
</div>)
      end
    end

    def inline_anchor node
      case node.type
      when :xref
        if (path = node.attributes['path'])
          attrs = (append_link_constraint_attrs node, node.role ? [%( class="#{node.role}")] : []).join
          text = node.text || path
        else
          attrs = node.role ? %( class="#{node.role}") : ''
          unless (text = node.text)
            refid = node.attributes['refid']
            if AbstractNode === (ref = (@refs ||= node.document.catalog[:refs])[refid])
              text = (ref.xreftext node.attr('xrefstyle')) || %([#{refid}])
            else
              text = %([#{refid}])
            end
          end
        end
        %(<a href="#{node.target}"#{attrs}>#{text}</a>)
      when :ref
        %(<a id="#{node.id}"></a>)
      when :link
        attrs = node.id ? [%( id="#{node.id}")] : []
        attrs << %( class="#{node.role}") if node.role
        attrs << %( title="#{node.attr 'title'}") if node.attr? 'title', nil, false
        %(<a href="#{node.target}"#{(append_link_constraint_attrs node, attrs).join}>#{node.text}</a>)
      when :bibref
        # NOTE technically node.text should be node.reftext, but subs have already been applied to text
        %(<a id="#{node.id}"></a>#{node.text})
      else
        logger.warn %(unknown anchor type: #{node.type.inspect})
        nil
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
      if (index = node.attr 'index', nil, false)
        if node.type == :xref
          %(<sup class="footnoteref">[<a class="footnote" href="#_footnotedef_#{index}" title="View footnote.">#{index}</a>]</sup>)
        else
          id_attr = node.id ? %( id="_footnote_#{node.id}") : ''
          %(<sup class="footnote"#{id_attr}>[<a id="_footnoteref_#{index}" class="footnote" href="#_footnotedef_#{index}" title="View footnote.">#{index}</a>]</sup>)
        end
      elsif node.type == :xref
        %(<sup class="footnoteref red" title="Unresolved footnote reference.">[#{node.text}]</sup>)
      end
    end

    def inline_image node
      if (type = node.type) == 'icon' && (node.document.attr? 'icons', 'font')
        class_attr_val = %(fa fa-#{node.target})
        {'size' => 'fa-', 'rotate' => 'fa-rotate-', 'flip' => 'fa-flip-'}.each do |key, prefix|
          class_attr_val = %(#{class_attr_val} #{prefix}#{node.attr key}) if node.attr? key
        end
        title_attr = (node.attr? 'title') ? %( title="#{node.attr 'title'}") : ''
        img = %(<i class="#{class_attr_val}"#{title_attr}></i>)
      elsif type == 'icon' && !(node.document.attr? 'icons')
        img = %([#{node.alt}])
      else
        target = node.target
        attrs = ['width', 'height', 'title'].map {|name| (node.attr? name) ? %( #{name}="#{node.attr name}") : '' }.join
        if type != 'icon' && ((node.attr? 'format', 'svg', false) || (target.include? '.svg')) &&
            node.document.safe < SafeMode::SECURE && ((svg = (node.option? 'inline')) || (obj = (node.option? 'interactive')))
          if svg
            img = (read_svg_contents node, target) || %(<span class="alt">#{node.alt}</span>)
          elsif obj
            fallback = (node.attr? 'fallback') ? %(<img src="#{node.image_uri(node.attr 'fallback')}" alt="#{encode_quotes node.alt}"#{attrs}#{@void_element_slash}>) : %(<span class="alt">#{node.alt}</span>)
            img = %(<object type="image/svg+xml" data="#{node.image_uri target}"#{attrs}>#{fallback}</object>)
          end
        end
        img ||= %(<img src="#{type == 'icon' ? (node.icon_uri target) : (node.image_uri target)}" alt="#{encode_quotes node.alt}"#{attrs}#{@void_element_slash}>)
      end
      if node.attr? 'link', nil, false
        img = %(<a class="image" href="#{node.attr 'link'}"#{(append_link_constraint_attrs node).join}>#{img}</a>)
      end
      if (role = node.role)
        if node.attr? 'float'
          class_attr_val = %(#{type} #{node.attr 'float'} #{role})
        else
          class_attr_val = %(#{type} #{role})
        end
      elsif node.attr? 'float'
        class_attr_val = %(#{type} #{node.attr 'float'})
      else
        class_attr_val = type
      end
      %(<span class="#{class_attr_val}">#{img}</span>)
    end

    def inline_indexterm node
      node.type == :visible ? node.text : ''
    end

    def inline_kbd node
      if (keys = node.attr 'keys').size == 1
        %(<kbd>#{keys[0]}</kbd>)
      else
        %(<span class="keyseq"><kbd>#{keys.join '</kbd>+<kbd>'}</kbd></span>)
      end
    end

    def inline_menu node
      caret = (node.document.attr? 'icons', 'font') ? '&#160;<i class="fa fa-angle-right caret"></i> ' : '&#160;<b class="caret">&#8250;</b> '
      submenu_joiner = %(</b>#{caret}<b class="submenu">)
      menu = node.attr 'menu'
      if (submenus = node.attr 'submenus').empty?
        if (menuitem = node.attr 'menuitem', nil, false)
          %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="menuitem">#{menuitem}</b></span>)
        else
          %(<b class="menuref">#{menu}</b>)
        end
      else
        %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="submenu">#{submenus.join submenu_joiner}</b>#{caret}<b class="menuitem">#{node.attr 'menuitem'}</b></span>)
      end
    end

    def inline_quoted node
      open, close, is_tag = QUOTE_TAGS[node.type]
      class_attr = %( class="#{node.role}") if node.role
      id_attr = %( id="#{node.id}") if node.id
      if class_attr || id_attr
        if is_tag
          %(#{open.chop}#{id_attr || ''}#{class_attr || ''}>#{node.text}#{close})
        else
          %(<span#{id_attr || ''}#{class_attr || ''}>#{open}#{node.text}#{close}</span>)
        end
      else
        %(#{open}#{node.text}#{close})
      end
    end

    def append_boolean_attribute name, xml
      xml ? %( #{name}="#{name}") : %( #{name})
    end

    def encode_quotes val
      (val.include? '"') ? (val.gsub '"', '&quot;') : val
    end

    def generate_manname_section node
      manname_title = (node.attr 'manname-title') || 'Name'
      if (next_section = node.sections[0]) && (next_section_title = next_section.title) == next_section_title.upcase
        manname_title = manname_title.upcase
      end
      manname_id_attr = (manname_id = node.attr 'manname-id') ? %( id="#{manname_id}") : ''
      %(<h2#{manname_id_attr}>#{manname_title}</h2>
<div class="sectionbody">
<p>#{node.attr 'manname'} - #{node.attr 'manpurpose'}</p>
</div>)
    end

    def append_link_constraint_attrs node, attrs = []
      rel = 'nofollow' if node.option? 'nofollow'
      if (window = node.attributes['window'])
        attrs << %( target="#{window}")
        attrs << (rel ? %( rel="#{rel} noopener") : ' rel="noopener"') if window == '_blank' || (node.option? 'noopener')
      elsif rel
        attrs << %( rel="#{rel}")
      end
      attrs
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
