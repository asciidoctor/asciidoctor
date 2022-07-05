# frozen_string_literal: true
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

  def generate_header node
    if node.header? && !node.noheader
      result = ['<header>']
      if (doctitle = generate_document_title node)
        result << doctitle
      end
      if (authors = generate_authors node)
        result << authors
      end
      result << '</header>'
      result.join LF
    end
  end

  def generate_document_title node
    unless node.notitle
      doctitle = node.doctitle partition: true, sanitize: true
      attributes = common_html_attributes node.id, node.role
      %(<h1#{attributes}>#{doctitle.main}#{doctitle.subtitle? ? %( <small class="subtitle">#{doctitle.subtitle}</small>) : ''}</h1>)
    end
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
    %(#{id ? %( id="#{id}") : ''}#{roles.empty? ? '' : %( class="#{roles.join(' ')}") })
  end

  def append_link_constraint_attrs node, attrs = []
    link_types = []
    link_types << 'author' if (@convert_context || []).last == 'author'
    link_types << 'nofollow' if node.option? 'nofollow'
    if (window = node.attributes['window'])
      attrs << %( target="#{window}")
      link_types << "noopener" if window == '_blank' || (node.option? 'noopener')
    end
    attrs << %( rel="#{link_types.join ' '}") unless link_types.empty?
    attrs
  end
end
end
