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

  def generate_header node
    if node.header? && !node.noheader
      result = ['<header>']
      if (doctitle = generate_document_title node)
        result << doctitle
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

  def common_html_attributes id, role, default_role = nil
    roles = default_role ? [default_role] : []
    roles << role if role
    %(#{id ? %( id="#{id}") : ''}#{roles.empty? ? '' : %( class="#{roles.join(' ')}") })
  end
end
end
