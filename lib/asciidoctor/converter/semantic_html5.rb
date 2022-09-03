# frozen_string_literal: true

autoload :Date, 'date' unless RUBY_ENGINE == 'opal'

module Asciidoctor
# A built-in {Converter} implementation that generates HTML 5 output
# that maximizes the use of semantic constructs.
class Converter::SemanticHtml5Converter < Converter::Base
  register_for 'semantic-html5'

  def initialize backend, opts = {}
    @backend = backend
    syntax = opts[:htmlsyntax] == 'xml' ? 'xml' : 'html'
    init_backend_traits basebackend: 'html', filetype: 'html', htmlsyntax: syntax, outfilesuffix: '.html', supports_templates: true
  end

  def convert_embedded node
    result = []
    if (header = generate_header node)
      result << header
    end
    result << node.content
    result.join LF
  end

  def convert_section node
    doc_attrs = node.document.attributes
    if node.caption
      title = node.captioned_title
    elsif (section_numbering = generate_section_numbering node)
      title = %(#{section_numbering} #{node.title})
    else
      title = node.title
    end
    id = node.id
    if doc_attrs['sectlinks']
      title = %(<a class="link" href="##{id}">#{title}</a>)
    end
    if doc_attrs['sectanchors']
      if doc_attrs['sectanchors'] == 'after'
        title = %(#{title}<a class="anchor" href="##{id}"></a>)
      else
        title = %(<a class="anchor" href="##{id}"></a>#{title})
      end
    end
    attributes = common_html_attributes id, node.role
    level = node.level
    result = []
    result << %(<section#{attributes}>)
    result << %(<h#{level + 1}>#{title}</h#{level + 1}>)
    result << node.content if node.blocks?
    result << '</section>'
    result.join LF
  end

  def convert_paragraph node
    attributes = common_html_attributes node.id, node.role
    if node.title?
      %(<p#{attributes}>
<strong class="title">#{node.title}</strong>
#{node.content}
</p>)
    else
      %(<p#{attributes}>
#{node.content}
</p>)
    end
  end

  def convert_listing node
    caption = (caption = node.caption) ? %(<span class="label">#{caption}</span> ) : ''
    title = node.title? ? %(<figcaption>#{caption}#{node.title}</figcaption>\n) : ''
    attributes = common_html_attributes node.id, node.role, 'listing'
    nowrap = (node.option? 'nowrap') || !(node.document.attr? 'prewrap')
    if node.style == 'source'
      lang = node.attr 'language'
      if (syntax_hl = node.document.syntax_highlighter)
        opts = syntax_hl.highlight? ? {
          css_mode: ((doc_attrs = node.document.attributes)[%(#{syntax_hl.name}-css)] || :class).to_sym,
          style: doc_attrs[%(#{syntax_hl.name}-style)],
        } : {}
        opts[:nowrap] = nowrap
        content = syntax_hl.format node, lang, opts
      else
        content = %(<code#{lang ? %( data-lang="#{lang}") : ''}>#{node.content || ''}</code>)
      end
    else
      content = node.content || ''
    end
    %(<figure#{attributes}>
#{title}<pre#{nowrap ? ' class="nowrap"' : ''}>#{content}</pre>
</figure>)
  end

  def convert_thematic_break node
    '<hr>'
  end

  def convert_image node
    roles = []
    roles << node.role if node.role
    roles << %(text-#{node.attr 'align'}) if node.attr? 'align'
    roles << (node.attr 'float').to_s if node.attr? 'float'
    role = roles.join ' '
    attributes = common_html_attributes node.id, role.empty? ? nil : role
    size = []
    size << %( width="#{node.attr 'width'}") if node.attr? 'width'
    size << %( height="#{node.attr 'height'}") if node.attr? 'height'
    size = size.join
    target = node.attr 'target'
    link_start = %(<a href="#{node.attr 'link'}">) if node.attr? 'link'
    link_end = %(</a>) if node.attr? 'link'

    if node.title?
      %(<figure#{attributes}>
#{link_start}<img src="#{target}" alt="#{encode_attribute_value node.alt}"#{size} />#{link_end}
<figcaption>#{node.captioned_title}</figcaption>
</figure>)
    else
      %(#{link_start}<img src="#{target}" alt="#{encode_attribute_value node.alt}"#{attributes}#{size} />#{link_end})
    end
  end

  def convert_inline_image node
    roles = []
    roles << node.role if node.role
    roles << %(text-#{node.attr 'align'}) if node.attr? 'align'
    roles << (node.attr 'float').to_s if node.attr? 'float'
    role = roles.join ' '
    attributes = common_html_attributes node.id, role.empty? ? nil : role
    size = []
    size << %( width="#{node.attr 'width'}") if node.attr? 'width'
    size << %( height="#{node.attr 'height'}") if node.attr? 'height'
    size = size.join
    target = node.target
    title = %( title="#{node.attr 'title'}") if node.attr? 'title'
    %(<img src="#{target}" alt="#{encode_attribute_value node.alt}"#{title}#{attributes}#{size} />)
  end

  def convert_inline_anchor node
    case node.type
    when :link
      attrs = node.id ? [%( id="#{node.id}")] : []
      attrs << %( class="#{node.role}") if node.role
      attrs << %( title="#{node.attr 'title'}") if node.attr? 'title'
      %(<a href="#{node.target}"#{(append_link_constraint_attrs node, attrs).join}>#{node.text}</a>)
    else
      logger.warn %(unknown anchor type: #{node.type.inspect})
      nil
    end
  end

  def convert_inline_kbd node
    if (keys = node.attr 'keys').size == 1
      %(<kbd>#{keys[0]}</kbd>)
    else
      %(<span class="keyseq"><kbd>#{keys.join '</kbd>+<kbd>'}</kbd></span>)
    end
  end

  def convert_inline_quoted node
    attributes = common_html_attributes node.id, node.role
    case node.type
    when :strong
      %(<strong#{attributes}>#{node.text}</strong>)
    when :emphasis
      %(<em#{attributes}>#{node.text}</em>)
    when :monospaced
      %(<code#{attributes}>#{node.text}</code>)
    when :mark
      %(<mark#{attributes}>#{node.text}</mark>)
    when :superscript
      %(<sup#{attributes}>#{node.text}</sup>)
    when :subscript
      %(<sub#{attributes}>#{node.text}</sub>)
    when :single
      attributes = common_html_attributes node.id, node.role, 'singlequote'
      %(<span#{attributes}>&#8216;#{node.text}&#8217;</span>)
    when :double
      attributes = common_html_attributes node.id, node.role, 'doublequote'
      %(<span#{attributes}>&#8220;#{node.text}&#8221;</span>)
    else
      %(<span#{attributes}>#{node.text}</span>)
    end
  end

  def convert_inline_break node
    %(#{node.text}<br>)
  end

  def convert_inline_button node
    %(<span class="button">#{node.text}</span>)
  end

  def convert_inline_menu node
    caret = '&#160;<b class="caret">&#8250;</b> '
    submenu_joiner = %(</b>#{caret}<b class="submenu">)
    menu = node.attr 'menu'
    if (submenus = node.attr 'submenus').empty?
      if (menuitem = node.attr 'menuitem')
        %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="menuitem">#{menuitem}</b></span>)
      else
        %(<span class="menuseq"><b class="menu">#{menu}</b></span>)
      end
    else
      %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="submenu">#{submenus.join submenu_joiner}</b>#{caret}<b class="menuitem">#{node.attr 'menuitem'}</b></span>)
    end
  end

  def generate_section_numbering node
    level = node.level
    doc_attrs = node.document.attributes

    return unless node.numbered && level <= (doc_attrs['sectnumlevels'] || 3).to_i

    if level < 2 && node.document.doctype == 'book'
      case node.sectname
      when 'chapter'
        %(#{(signifier = doc_attrs['chapter-signifier']) ? "#{signifier} " : ''}<span class="sectnum">#{node.sectnum}</span>)
      when 'part'
        %(#{(signifier = doc_attrs['part-signifier']) ? "#{signifier} " : ''}<span class="sectnum">#{node.sectnum nil, ':'}</span>)
      else
        %(<span class="sectnum">#{node.sectnum}</span>)
      end
    else
      %(<span class="sectnum">#{node.sectnum}</span>)
    end
  end

  def generate_header node
    return unless node.header? && !node.noheader

    result = ['<header>']
    if (doctitle = generate_document_title node)
      result << doctitle
    end
    if (authors = generate_authors node)
      result << authors
    end
    if (revision = generate_revision node)
      result << revision
    end
    result << '</header>'
    result.join LF
  end

  def generate_document_title node
    return if node.notitle

    doctitle = node.doctitle partition: true, sanitize: true
    attributes = common_html_attributes node.id, node.role
    %(<h1#{attributes}>#{doctitle.main}#{doctitle.subtitle? ? %( <small class="subtitle">#{doctitle.subtitle}</small>) : ''}</h1>)
  end

  def generate_authors node
    return if node.authors.empty?

    if node.authors.length == 1
      %(<p class="byline">
#{format_author node, node.authors.first}
</p>)
    else
      result = ['<ul class="byline">']
      node.authors.each do |author|
        result << "<li>#{format_author node, author}</li>"
      end
      result << '</ul>'
      result.join LF
    end
  end

  def generate_revision node
    return unless (node.attr? 'revnumber') || (node.attr? 'revdate') || (node.attr? 'revremark')

    revision_date = if (revdate = node.attr 'revdate')
                      date = ::Date._parse revdate
                      if (date.key? :year) || (date.key? :mon) || (date.key? :mday)
                        date_parts = []
                        date_parts << (date[:year]).to_s if date.key? :year
                        date_parts << (date[:mon].to_s.rjust 2, '0').to_s if date.key? :mon
                        date_parts << (date[:mday].to_s.rjust 2, '0').to_s if date.key? :mday
                        %(<time datetime="#{date_parts.join '-'}">#{revdate}</time>)
                      else
                        revdate
                      end
                    else
                      ''
                    end
    %(<table class="revision">
<thead>
<tr>
<th>Version</th>
<th>Date</th>
<th>Remark</th>
</tr>
</thead>
<tbody>
<tr>
<td data-title="#{node.attr 'version-label'}">#{node.attr 'revnumber'}</td>
<td data-title="Date">#{revision_date}</td>
<td data-title="Remark">#{node.attr 'revremark'}</td>
</tr>
</tbody>
</table>)
  end

  def format_author node, author
    in_context 'author' do
      %(<span class="author">#{node.sub_replacements author.name}#{author.email ? %( #{node.sub_macros author.email}) : ''}</span>)
    end
  end

  def in_context name
    (@convert_context ||= []).push name
    result = yield
    @convert_context.pop
    result
  end

  def common_html_attributes id, role, default_role = nil
    roles = default_role ? [default_role] : []
    roles << role if role
    %(#{id ? %( id="#{id}") : ''}#{roles.empty? ? '' : %( class="#{roles.join ' '}")})
  end

  def append_link_constraint_attrs node, attrs = []
    link_types = []
    link_types << 'author' if (@convert_context || []).last == 'author'
    link_types << 'nofollow' if node.option? 'nofollow'
    if (window = node.attributes['window'])
      attrs << %( target="#{window}")
      link_types << 'noopener' if window == '_blank' || (node.option? 'noopener')
    end
    attrs << %( rel="#{link_types.join ' '}") unless link_types.empty?
    attrs
  end

  def encode_attribute_value val
    (val.include? '"') ? (val.gsub '"', '&quot;') : val
  end
end
end
