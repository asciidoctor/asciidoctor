# frozen_string_literal: true
module Asciidoctor
# A built-in {Converter} implementation that generates HTML 5 output
# consistent with the html5 backend from AsciiDoc Python.
class Converter::Html5Converter < Converter::Base
  register_for 'html5'

  (QUOTE_TAGS = {
    monospaced:  ['<code>', '</code>', true],
    emphasis:    ['<em>', '</em>', true],
    strong:      ['<strong>', '</strong>', true],
    double:      ['&#8220;', '&#8221;'],
    single:      ['&#8216;', '&#8217;'],
    mark:        ['<mark>', '</mark>', true],
    superscript: ['<sup>', '</sup>', true],
    subscript:   ['<sub>', '</sub>', true],
    asciimath:   ['\$', '\$'],
    latexmath:   ['\(', '\)'],
    # Opal can't resolve these constants when referenced here
    #asciimath:  INLINE_MATH_DELIMITERS[:asciimath] + [false],
    #latexmath:  INLINE_MATH_DELIMITERS[:latexmath] + [false],
  }).default = ['', '']

  DropAnchorRx = /<(?:a[^>+]+|\/a)>/
  StemBreakRx = / *\\\n(?:\\?\n)*|\n\n+/
  if RUBY_ENGINE == 'opal'
    # NOTE In JavaScript, ^ matches the start of the string when the m flag is not set
    SvgPreambleRx = /^#{CC_ALL}*?(?=<svg\b)/
    SvgStartTagRx = /^<svg[^>]*>/
  else
    SvgPreambleRx = /\A.*?(?=<svg\b)/m
    SvgStartTagRx = /\A<svg[^>]*>/
  end
  DimensionAttributeRx = /\s(?:width|height|style)=(["'])#{CC_ANY}*?\1/

  def initialize backend, opts = {}
    @backend = backend
    if opts[:htmlsyntax] == 'xml'
      syntax = 'xml'
      @xml_mode = true
      @void_element_slash = '/'
    else
      syntax = 'html'
      @xml_mode = nil
      @void_element_slash = ''
    end
    init_backend_traits basebackend: 'html', filetype: 'html', htmlsyntax: syntax, outfilesuffix: '.html', supports_templates: true
  end

  def convert node, transform = node.node_name, opts = nil
    if transform == 'inline_quoted'; return convert_inline_quoted node
    elsif transform == 'paragraph'; return convert_paragraph node
    elsif transform == 'inline_anchor'; return convert_inline_anchor node
    elsif transform == 'section'; return convert_section node
    elsif transform == 'listing'; return convert_listing node
    elsif transform == 'literal'; return convert_literal node
    elsif transform == 'ulist'; return convert_ulist node
    elsif transform == 'olist'; return convert_olist node
    elsif transform == 'dlist'; return convert_dlist node
    elsif transform == 'admonition'; return convert_admonition node
    elsif transform == 'colist'; return convert_colist node
    elsif transform == 'embedded'; return convert_embedded node
    elsif transform == 'example'; return convert_example node
    elsif transform == 'floating_title'; return convert_floating_title node
    elsif transform == 'image'; return convert_image node
    elsif transform == 'inline_break'; return convert_inline_break node
    elsif transform == 'inline_button'; return convert_inline_button node
    elsif transform == 'inline_callout'; return convert_inline_callout node
    elsif transform == 'inline_footnote'; return convert_inline_footnote node
    elsif transform == 'inline_image'; return convert_inline_image node
    elsif transform == 'inline_indexterm'; return convert_inline_indexterm node
    elsif transform == 'inline_kbd'; return convert_inline_kbd node
    elsif transform == 'inline_menu'; return convert_inline_menu node
    elsif transform == 'open'; return convert_open node
    elsif transform == 'page_break'; return convert_page_break node
    elsif transform == 'preamble'; return convert_preamble node
    elsif transform == 'quote'; return convert_quote node
    elsif transform == 'sidebar'; return convert_sidebar node
    elsif transform == 'stem'; return convert_stem node
    elsif transform == 'table'; return convert_table node
    elsif transform == 'thematic_break'; return convert_thematic_break node
    elsif transform == 'verse'; return convert_verse node
    elsif transform == 'video'; return convert_video node
    elsif transform == 'document'; return convert_document node
    elsif transform == 'toc'; return convert_toc node
    elsif transform == 'pass'; return convert_pass node
    elsif transform == 'audio'; return convert_audio node
    else; return super
    end
  end

  def convert_document node
    br = %(<br#{slash = @void_element_slash}>)
    unless (asset_uri_scheme = (node.attr 'asset-uri-scheme', 'https')).empty?
      asset_uri_scheme = %(#{asset_uri_scheme}:)
    end
    cdn_base_url = %(#{asset_uri_scheme}//cdnjs.cloudflare.com/ajax/libs)
    linkcss = node.attr? 'linkcss'
    result = ['<!DOCTYPE html>']
    lang_attribute = (node.attr? 'nolang') ? '' : %( lang="#{node.attr 'lang', 'en'}")
    result << %(<html#{@xml_mode ? ' xmlns="http://www.w3.org/1999/xhtml"' : ''}#{lang_attribute}>)
    result << %(<head>
<meta charset="#{node.attr 'encoding', 'UTF-8'}"#{slash}>
<meta http-equiv="X-UA-Compatible" content="IE=edge"#{slash}>
<meta name="viewport" content="width=device-width, initial-scale=1.0"#{slash}>
<meta name="generator" content="Asciidoctor #{node.attr 'asciidoctor-version'}"#{slash}>)
    result << %(<meta name="application-name" content="#{node.attr 'app-name'}"#{slash}>) if node.attr? 'app-name'
    result << %(<meta name="description" content="#{node.attr 'description'}"#{slash}>) if node.attr? 'description'
    result << %(<meta name="keywords" content="#{node.attr 'keywords'}"#{slash}>) if node.attr? 'keywords'
    result << %(<meta name="author" content="#{((authors = node.sub_replacements node.attr 'authors').include? '<') ? (authors.gsub XmlSanitizeRx, '') : authors}"#{slash}>) if node.attr? 'authors'
    result << %(<meta name="copyright" content="#{node.attr 'copyright'}"#{slash}>) if node.attr? 'copyright'
    if node.attr? 'favicon'
      if (icon_href = node.attr 'favicon').empty?
        icon_href = 'favicon.ico'
        icon_type = 'image/x-icon'
      elsif (icon_ext = Helpers.extname icon_href, nil)
        icon_type = icon_ext == '.ico' ? 'image/x-icon' : %(image/#{icon_ext.slice 1, icon_ext.length})
      else
        icon_type = 'image/x-icon'
      end
      result << %(<link rel="icon" type="#{icon_type}" href="#{icon_href}"#{slash}>)
    end
    result << %(<title>#{node.doctitle sanitize: true, use_fallback: true}</title>)

    if DEFAULT_STYLESHEET_KEYS.include?(node.attr 'stylesheet')
      if (webfonts = node.attr 'webfonts')
        result << %(<link rel="stylesheet" href="#{asset_uri_scheme}//fonts.googleapis.com/css?family=#{webfonts.empty? ? 'Open+Sans:300,300italic,400,400italic,600,600italic%7CNoto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700' : webfonts}"#{slash}>)
      end
      if linkcss
        result << %(<link rel="stylesheet" href="#{node.normalize_web_path DEFAULT_STYLESHEET_NAME, (node.attr 'stylesdir', ''), false}"#{slash}>)
      else
        result << %(<style>
#{Stylesheets.instance.primary_stylesheet_data}
</style>)
      end
    elsif node.attr? 'stylesheet'
      if linkcss
        result << %(<link rel="stylesheet" href="#{node.normalize_web_path((node.attr 'stylesheet'), (node.attr 'stylesdir', ''))}"#{slash}>)
      else
        result << %(<style>
#{node.read_asset node.normalize_system_path((node.attr 'stylesheet'), (node.attr 'stylesdir', '')), warn_on_failure: true, label: 'stylesheet'}
</style>)
      end
    end

    if node.attr? 'icons', 'font'
      if node.attr? 'iconfont-remote'
        result << %(<link rel="stylesheet" href="#{node.attr 'iconfont-cdn', %[#{cdn_base_url}/font-awesome/#{FONT_AWESOME_VERSION}/css/font-awesome.min.css]}"#{slash}>)
      else
        iconfont_stylesheet = %(#{node.attr 'iconfont-name', 'font-awesome'}.css)
        result << %(<link rel="stylesheet" href="#{node.normalize_web_path iconfont_stylesheet, (node.attr 'stylesdir', ''), false}"#{slash}>)
      end
    end

    if (syntax_hl = node.syntax_highlighter) && (syntax_hl.docinfo? :head)
      result << (syntax_hl.docinfo :head, node, cdn_base_url: cdn_base_url, linkcss: linkcss, self_closing_tag_slash: slash)
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
    classes << node.role if node.role?
    body_attrs << %(class="#{classes.join ' '}")
    body_attrs << %(style="max-width: #{node.attr 'max-width'};") if node.attr? 'max-width'
    result << %(<body #{body_attrs.join ' '}>)

    unless (docinfo_content = node.docinfo :header).empty?
      result << docinfo_content
    end

    unless node.noheader
      result << '<div id="header">'
      if node.doctype == 'manpage'
        result << %(<h1>#{node.doctitle} Manual Page</h1>)
        if sectioned && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
          result << %(<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{convert_outline node}
</div>)
        end
        result << (generate_manname_section node) if node.attr? 'manpurpose'
      else
        if node.header?
          result << %(<h1>#{node.header.title}</h1>) unless node.notitle
          details = []
          idx = 1
          node.authors.each do |author|
            details << %(<span id="author#{idx > 1 ? idx : ''}" class="author">#{node.sub_replacements author.name}</span>#{br})
            details << %(<span id="email#{idx > 1 ? idx : ''}" class="email">#{node.sub_macros author.email}</span>#{br}) if author.email
            idx += 1
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
#{convert_outline node}
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

    # JavaScript (and auxiliary stylesheets) loaded at the end of body for performance reasons
    # See http://www.html5rocks.com/en/tutorials/speed/script-loading/

    if syntax_hl && (syntax_hl.docinfo? :footer)
      result << (syntax_hl.docinfo :footer, node, cdn_base_url: cdn_base_url, linkcss: linkcss, self_closing_tag_slash: slash)
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
})
MathJax.Hub.Register.StartupHook("AsciiMath Jax Ready", function () {
  MathJax.InputJax.AsciiMath.postfilterHooks.Add(function (data, node) {
    if ((node = data.script.parentNode) && (node = node.parentNode) && node.classList.contains('stemblock')) {
      data.math.root.display = "block"
    }
    return data
  })
})
</script>
<script src="#{cdn_base_url}/mathjax/#{MATHJAX_VERSION}/MathJax.js?config=TeX-MML-AM_HTMLorMML"></script>)
    end

    unless (docinfo_content = node.docinfo :footer).empty?
      result << docinfo_content
    end

    result << '</body>'
    result << '</html>'
    result.join LF
  end

  def convert_embedded node
    result = []
    if node.doctype == 'manpage'
      # QUESTION should notitle control the manual page title?
      unless node.notitle
        id_attr = node.id ? %( id="#{node.id}") : ''
        result << %(<h1#{id_attr}>#{node.doctitle} Manual Page</h1>)
      end
      result << (generate_manname_section node) if node.attr? 'manpurpose'
    elsif node.header? && !node.notitle
      id_attr = node.id ? %( id="#{node.id}") : ''
      result << %(<h1#{id_attr}>#{node.header.title}</h1>)
    end

    if node.sections? && (node.attr? 'toc') && (toc_p = node.attr 'toc-placement') != 'macro' && toc_p != 'preamble'
      result << %(<div id="toc" class="toc">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{convert_outline node}
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

  def convert_outline node, opts = {}
    return unless node.sections?
    sectnumlevels = opts[:sectnumlevels] || (node.document.attributes['sectnumlevels'] || 3).to_i
    toclevels = opts[:toclevels] || (node.document.attributes['toclevels'] || 2).to_i
    sections = node.sections
    # FIXME top level is incorrect if a multipart book starts with a special section defined at level 0
    result = [%(<ul class="sectlevel#{sections[0].level}">)]
    sections.each do |section|
      slevel = section.level
      if section.caption
        stitle = section.captioned_title
      elsif section.numbered && slevel <= sectnumlevels
        if slevel < 2 && node.document.doctype == 'book'
          if section.sectname == 'chapter'
            stitle =  %(#{(signifier = node.document.attributes['chapter-signifier']) ? "#{signifier} " : ''}#{section.sectnum} #{section.title})
          elsif section.sectname == 'part'
            stitle =  %(#{(signifier = node.document.attributes['part-signifier']) ? "#{signifier} " : ''}#{section.sectnum nil, ':'} #{section.title})
          else
            stitle = %(#{section.sectnum} #{section.title})
          end
        else
          stitle = %(#{section.sectnum} #{section.title})
        end
      else
        stitle = section.title
      end
      stitle = stitle.gsub DropAnchorRx, '' if stitle.include? '<a'
      if slevel < toclevels && (child_toc_level = convert_outline section, toclevels: toclevels, sectnumlevels: sectnumlevels)
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

  def convert_section node
    doc_attrs = node.document.attributes
    level = node.level
    if node.caption
      title = node.captioned_title
    elsif node.numbered && level <= (doc_attrs['sectnumlevels'] || 3).to_i
      if level < 2 && node.document.doctype == 'book'
        if node.sectname == 'chapter'
          title = %(#{(signifier = doc_attrs['chapter-signifier']) ? "#{signifier} " : ''}#{node.sectnum} #{node.title})
        elsif node.sectname == 'part'
          title = %(#{(signifier = doc_attrs['part-signifier']) ? "#{signifier} " : ''}#{node.sectnum nil, ':'} #{node.title})
        else
          title = %(#{node.sectnum} #{node.title})
        end
      else
        title = %(#{node.sectnum} #{node.title})
      end
    else
      title = node.title
    end
    if node.id
      id_attr = %( id="#{id = node.id}")
      if doc_attrs['sectlinks']
        title = %(<a class="link" href="##{id}">#{title}</a>)
      end
      if doc_attrs['sectanchors']
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
    if level == 0
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

  def convert_admonition node
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

  def convert_audio node
    xml = @xml_mode
    id_attribute = node.id ? %( id="#{node.id}") : ''
    classes = ['audioblock', node.role].compact
    class_attribute = %( class="#{classes.join ' '}")
    title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
    start_t = node.attr 'start'
    end_t = node.attr 'end'
    time_anchor = (start_t || end_t) ? %(#t=#{start_t || ''}#{end_t ? ",#{end_t}" : ''}) : ''
    %(<div#{id_attribute}#{class_attribute}>
#{title_element}<div class="content">
<audio src="#{node.media_uri(node.attr 'target')}#{time_anchor}"#{(node.option? 'autoplay') ? (append_boolean_attribute 'autoplay', xml) : ''}#{(node.option? 'nocontrols') ? '' : (append_boolean_attribute 'controls', xml)}#{(node.option? 'loop') ? (append_boolean_attribute 'loop', xml) : ''}>
Your browser does not support the audio tag.
</audio>
</div>
</div>)
  end

  def convert_colist node
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

  def convert_dlist node
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
        terms.each do |dt|
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
        first_term = true
        terms.each do |dt|
          result << %(<br#{slash}>) unless first_term
          result << dt.text
          first_term = nil
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
        terms.each do |dt|
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

  def convert_example node
    id_attribute = node.id ? %( id="#{node.id}") : ''
    if node.option? 'collapsible'
      class_attribute = node.role ? %( class="#{node.role}") : ''
      summary_element = node.title? ? %(<summary class="title">#{node.title}</summary>) : '<summary class="title">Details</summary>'
      %(<details#{id_attribute}#{class_attribute}#{(node.option? 'open') ? ' open' : ''}>
#{summary_element}
<div class="content">
#{node.content}
</div>
</details>)
    else
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : ''
      %(<div#{id_attribute} class="exampleblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{node.content}
</div>
</div>)
    end
  end

  def convert_floating_title node
    tag_name = %(h#{node.level + 1})
    id_attribute = node.id ? %( id="#{node.id}") : ''
    classes = [node.style, node.role].compact
    %(<#{tag_name}#{id_attribute} class="#{classes.join ' '}">#{node.title}</#{tag_name}>)
  end

  def convert_image node
    target = node.attr 'target'
    width_attr = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : ''
    height_attr = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : ''
    if ((node.attr? 'format', 'svg') || (target.include? '.svg')) && node.document.safe < SafeMode::SECURE &&
        ((svg = (node.option? 'inline')) || (obj = (node.option? 'interactive')))
      if svg
        img = (read_svg_contents node, target) || %(<span class="alt">#{node.alt}</span>)
      elsif obj
        fallback = (node.attr? 'fallback') ? %(<img src="#{node.image_uri(node.attr 'fallback')}" alt="#{encode_attribute_value node.alt}"#{width_attr}#{height_attr}#{@void_element_slash}>) : %(<span class="alt">#{node.alt}</span>)
        img = %(<object type="image/svg+xml" data="#{node.image_uri target}"#{width_attr}#{height_attr}>#{fallback}</object>)
      end
    end
    img ||= %(<img src="#{node.image_uri target}" alt="#{encode_attribute_value node.alt}"#{width_attr}#{height_attr}#{@void_element_slash}>)
    if node.attr? 'link'
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

  def convert_listing node
    nowrap = (node.option? 'nowrap') || !(node.document.attr? 'prewrap')
    if node.style == 'source'
      lang = node.attr 'language'
      if (syntax_hl = node.document.syntax_highlighter)
        opts = syntax_hl.highlight? ? {
          css_mode: ((doc_attrs = node.document.attributes)[%(#{syntax_hl.name}-css)] || :class).to_sym,
          style: doc_attrs[%(#{syntax_hl.name}-style)],
        } : {}
        opts[:nowrap] = nowrap
      else
        pre_open = %(<pre class="highlight#{nowrap ? ' nowrap' : ''}"><code#{lang ? %[ class="language-#{lang}" data-lang="#{lang}"] : ''}>)
        pre_close = '</code></pre>'
      end
    else
      pre_open = %(<pre#{nowrap ? ' class="nowrap"' : ''}>)
      pre_close = '</pre>'
    end
    id_attribute = node.id ? %( id="#{node.id}") : ''
    title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : ''
    %(<div#{id_attribute} class="listingblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{syntax_hl ? (syntax_hl.format node, lang, opts) : pre_open + (node.content || '') + pre_close}
</div>
</div>)
  end

  def convert_literal node
    id_attribute = node.id ? %( id="#{node.id}") : ''
    title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
    nowrap = !(node.document.attr? 'prewrap') || (node.option? 'nowrap')
    %(<div#{id_attribute} class="literalblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
<pre#{nowrap ? ' class="nowrap"' : ''}>#{node.content}</pre>
</div>
</div>)
  end

  def convert_stem node
    id_attribute = node.id ? %( id="#{node.id}") : ''
    title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
    open, close = BLOCK_MATH_DELIMITERS[style = node.style.to_sym]
    if (equation = node.content)
      if style == :asciimath && (equation.include? LF)
        br = %(<br#{@void_element_slash}>#{LF})
        equation = equation.gsub(StemBreakRx) { %(#{close}#{br * ($&.count LF)}#{open}) }
      end
      unless (equation.start_with? open) && (equation.end_with? close)
        equation = %(#{open}#{equation}#{close})
      end
    else
      equation = ''
    end
    %(<div#{id_attribute} class="stemblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{equation}
</div>
</div>)
  end

  def convert_olist node
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
      if item.id
        result << %(<li id="#{item.id}"#{item.role ? %[ class="#{item.role}"] : ''}>)
      elsif item.role
        result << %(<li class="#{item.role}">)
      else
        result << '<li>'
      end
      result << %(<p>#{item.text}</p>)
      result << item.content if item.blocks?
      result << '</li>'
    end

    result << '</ol>'
    result << '</div>'
    result.join LF
  end

  def convert_open node
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

  def convert_page_break node
    '<div style="page-break-after: always;"></div>'
  end

  def convert_paragraph node
    if node.role
      attributes = %(#{node.id ? %[ id="#{node.id}"] : ''} class="paragraph #{node.role}")
    elsif node.id
      attributes = %( id="#{node.id}" class="paragraph")
    else
      attributes = ' class="paragraph"'
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

  alias convert_pass content_only

  def convert_preamble node
    if (doc = node.document).attr?('toc-placement', 'preamble') && doc.sections? && (doc.attr? 'toc')
      toc = %(
<div id="toc" class="#{doc.attr 'toc-class', 'toc'}">
<div id="toctitle">#{doc.attr 'toc-title'}</div>
#{convert_outline doc}
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

  def convert_quote node
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

  def convert_thematic_break node
    %(<hr#{@void_element_slash}>)
  end

  def convert_sidebar node
    id_attribute = node.id ? %( id="#{node.id}") : ''
    title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
    %(<div#{id_attribute} class="sidebarblock#{(role = node.role) ? " #{role}" : ''}">
<div class="content">
#{title_element}#{node.content}
</div>
</div>)
  end

  def convert_table node
    result = []
    id_attribute = node.id ? %( id="#{node.id}") : ''
    classes = ['tableblock', %(frame-#{node.attr 'frame', 'all', 'table-frame'}), %(grid-#{node.attr 'grid', 'all', 'table-grid'})]
    if (stripes = node.attr 'stripes', nil, 'table-stripes')
      classes << %(stripes-#{stripes})
    end
    styles = []
    if (autowidth = node.option? 'autowidth') && !(node.attr? 'width')
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
          result << ((col.option? 'autowidth') ? %(<col#{slash}>) : %(<col style="width: #{col.attr 'colpcwidth'}%;"#{slash}>))
        end
      end
      result << '</colgroup>'
      node.rows.to_h.each do |tsec, rows|
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

  def convert_toc node
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
#{convert_outline doc, toclevels: levels}
</div>)
  end

  def convert_ulist node
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
      elsif node.document.attr? 'icons', 'font'
        marker_checked = '<i class="fa fa-check-square-o"></i> '
        marker_unchecked = '<i class="fa fa-square-o"></i> '
      else
        marker_checked = '&#10003; '
        marker_unchecked = '&#10063; '
      end
    else
      ul_class_attribute = node.style ? %( class="#{node.style}") : ''
    end
    result << %(<div#{id_attribute} class="#{div_classes.join ' '}">)
    result << %(<div class="title">#{node.title}</div>) if node.title?
    result << %(<ul#{ul_class_attribute}>)

    node.items.each do |item|
      if item.id
        result << %(<li id="#{item.id}"#{item.role ? %[ class="#{item.role}"] : ''}>)
      elsif item.role
        result << %(<li class="#{item.role}">)
      else
        result << '<li>'
      end
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

  def convert_verse node
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

  def convert_video node
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
      start_anchor = (node.attr? 'start') ? %(#at=#{node.attr 'start'}) : ''
      delimiter = ['?']
      autoplay_param = (node.option? 'autoplay') ? %(#{delimiter.pop || '&amp;'}autoplay=1) : ''
      loop_param = (node.option? 'loop') ? %(#{delimiter.pop || '&amp;'}loop=1) : ''
      muted_param = (node.option? 'muted') ? %(#{delimiter.pop || '&amp;'}muted=1) : ''
      %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="#{asset_uri_scheme}//player.vimeo.com/video/#{node.attr 'target'}#{autoplay_param}#{loop_param}#{muted_param}#{start_anchor}" frameborder="0"#{(node.option? 'nofullscreen') ? '' : (append_boolean_attribute 'allowfullscreen', xml)}></iframe>
</div>
</div>)
    when 'youtube'
      unless (asset_uri_scheme = (node.document.attr 'asset-uri-scheme', 'https')).empty?
        asset_uri_scheme = %(#{asset_uri_scheme}:)
      end
      rel_param_val = (node.option? 'related') ? 1 : 0
      # NOTE start and end must be seconds (t parameter allows XmYs where X is minutes and Y is seconds)
      start_param = (node.attr? 'start') ? %(&amp;start=#{node.attr 'start'}) : ''
      end_param = (node.attr? 'end') ? %(&amp;end=#{node.attr 'end'}) : ''
      autoplay_param = (node.option? 'autoplay') ? '&amp;autoplay=1' : ''
      loop_param = (has_loop_param = node.option? 'loop') ? '&amp;loop=1' : ''
      mute_param = (node.option? 'muted') ? '&amp;mute=1' : ''
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
      theme_param = (node.attr? 'theme') ? %(&amp;theme=#{node.attr 'theme'}) : ''
      hl_param = (node.attr? 'lang') ? %(&amp;hl=#{node.attr 'lang'}) : ''

      # parse video_id/list_id syntax where list_id (i.e., playlist) is optional
      target, list = (node.attr 'target').split '/', 2
      if (list ||= (node.attr 'list'))
        list_param = %(&amp;list=#{list})
      else
        # parse dynamic playlist syntax: video_id1,video_id2,...
        target, playlist = target.split ',', 2
        if (playlist ||= (node.attr 'playlist'))
          # INFO playlist bar doesn't appear in Firefox unless showinfo=1 and modestbranding=1
          list_param = %(&amp;playlist=#{playlist})
        else
          # NOTE for loop to work, playlist must be specified; use VIDEO_ID if there's no explicit playlist
          list_param = has_loop_param ? %(&amp;playlist=#{target}) : ''
        end
      end

      %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="#{asset_uri_scheme}//www.youtube.com/embed/#{target}?rel=#{rel_param_val}#{start_param}#{end_param}#{autoplay_param}#{loop_param}#{mute_param}#{controls_param}#{list_param}#{fs_param}#{modest_param}#{theme_param}#{hl_param}" frameborder="0"#{fs_attribute}></iframe>
</div>
</div>)
    else
      poster_attribute = (val = node.attr 'poster').nil_or_empty? ? '' : %( poster="#{node.media_uri val}")
      preload_attribute = (val = node.attr 'preload').nil_or_empty? ? '' : %( preload="#{val}")
      start_t = node.attr 'start'
      end_t = node.attr 'end'
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

  def convert_inline_anchor node
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
            text = (ref.xreftext node.attr('xrefstyle', nil, true)) || %([#{refid}])
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
      attrs << %( title="#{node.attr 'title'}") if node.attr? 'title'
      %(<a href="#{node.target}"#{(append_link_constraint_attrs node, attrs).join}>#{node.text}</a>)
    when :bibref
      %(<a id="#{node.id}"></a>[#{node.reftext || node.id}])
    else
      logger.warn %(unknown anchor type: #{node.type.inspect})
      nil
    end
  end

  def convert_inline_break node
    %(#{node.text}<br#{@void_element_slash}>)
  end

  def convert_inline_button node
    %(<b class="button">#{node.text}</b>)
  end

  def convert_inline_callout node
    if node.document.attr? 'icons', 'font'
      %(<i class="conum" data-value="#{node.text}"></i><b>(#{node.text})</b>)
    elsif node.document.attr? 'icons'
      src = node.icon_uri("callouts/#{node.text}")
      %(<img src="#{src}" alt="#{node.text}"#{@void_element_slash}>)
    else
      %(#{node.attributes['guard']}<b class="conum">(#{node.text})</b>)
    end
  end

  def convert_inline_footnote node
    if (index = node.attr 'index')
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

  def convert_inline_image node
    if (type = node.type || 'image') == 'icon' && (node.document.attr? 'icons', 'font')
      class_attr_val = %(fa fa-#{node.target})
      { 'size' => 'fa-', 'rotate' => 'fa-rotate-', 'flip' => 'fa-flip-' }.each do |key, prefix|
        class_attr_val = %(#{class_attr_val} #{prefix}#{node.attr key}) if node.attr? key
      end
      title_attr = (node.attr? 'title') ? %( title="#{node.attr 'title'}") : ''
      img = %(<i class="#{class_attr_val}"#{title_attr}></i>)
    elsif type == 'icon' && !(node.document.attr? 'icons')
      img = %([#{node.alt}])
    else
      target = node.target
      attrs = ['width', 'height', 'title'].map {|name| (node.attr? name) ? %( #{name}="#{node.attr name}") : '' }.join
      if type != 'icon' && ((node.attr? 'format', 'svg') || (target.include? '.svg')) &&
          node.document.safe < SafeMode::SECURE && ((svg = (node.option? 'inline')) || (obj = (node.option? 'interactive')))
        if svg
          img = (read_svg_contents node, target) || %(<span class="alt">#{node.alt}</span>)
        elsif obj
          fallback = (node.attr? 'fallback') ? %(<img src="#{node.image_uri(node.attr 'fallback')}" alt="#{encode_attribute_value node.alt}"#{attrs}#{@void_element_slash}>) : %(<span class="alt">#{node.alt}</span>)
          img = %(<object type="image/svg+xml" data="#{node.image_uri target}"#{attrs}>#{fallback}</object>)
        end
      end
      img ||= %(<img src="#{type == 'icon' ? (node.icon_uri target) : (node.image_uri target)}" alt="#{encode_attribute_value node.alt}"#{attrs}#{@void_element_slash}>)
    end
    if node.attr? 'link'
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

  def convert_inline_indexterm node
    node.type == :visible ? node.text : ''
  end

  def convert_inline_kbd node
    if (keys = node.attr 'keys').size == 1
      %(<kbd>#{keys[0]}</kbd>)
    else
      %(<span class="keyseq"><kbd>#{keys.join '</kbd>+<kbd>'}</kbd></span>)
    end
  end

  def convert_inline_menu node
    caret = (node.document.attr? 'icons', 'font') ? '&#160;<i class="fa fa-angle-right caret"></i> ' : '&#160;<b class="caret">&#8250;</b> '
    submenu_joiner = %(</b>#{caret}<b class="submenu">)
    menu = node.attr 'menu'
    if (submenus = node.attr 'submenus').empty?
      if (menuitem = node.attr 'menuitem')
        %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="menuitem">#{menuitem}</b></span>)
      else
        %(<b class="menuref">#{menu}</b>)
      end
    else
      %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="submenu">#{submenus.join submenu_joiner}</b>#{caret}<b class="menuitem">#{node.attr 'menuitem'}</b></span>)
    end
  end

  def convert_inline_quoted node
    open, close, tag = QUOTE_TAGS[node.type]
    if node.id
      class_attr = node.role ? %( class="#{node.role}") : ''
      if tag
        %(#{open.chop} id="#{node.id}"#{class_attr}>#{node.text}#{close})
      else
        %(<span id="#{node.id}"#{class_attr}>#{open}#{node.text}#{close}</span>)
      end
    elsif node.role
      if tag
        %(#{open.chop} class="#{node.role}">#{node.text}#{close})
      else
        %(<span class="#{node.role}">#{open}#{node.text}#{close}</span>)
      end
    else
      %(#{open}#{node.text}#{close})
    end
  end

  # NOTE expose read_svg_contents for Bespoke converter
  def read_svg_contents node, target
    if (svg = node.read_contents target, start: (node.document.attr 'imagesdir'), normalize: true, label: 'SVG')
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

  private

  def append_boolean_attribute name, xml
    xml ? %( #{name}="#{name}") : %( #{name})
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

  def encode_attribute_value val
    (val.include? '"') ? (val.gsub '"', '&quot;') : val
  end

  def generate_manname_section node
    manname_title = node.attr 'manname-title', 'Name'
    if (next_section = node.sections[0]) && (next_section_title = next_section.title) == next_section_title.upcase
      manname_title = manname_title.upcase
    end
    manname_id_attr = (manname_id = node.attr 'manname-id') ? %( id="#{manname_id}") : ''
    %(<h2#{manname_id_attr}>#{manname_title}</h2>
<div class="sectionbody">
<p>#{node.attr 'manname'} - #{node.attr 'manpurpose'}</p>
</div>)
  end

  # NOTE adapt to older converters that relied on unprefixed method names
  def method_missing id, *params
    !((name = id.to_s).start_with? 'convert_') && (handles? name) ? (send %(convert_#{name}), *params) : super
  end
end
end
