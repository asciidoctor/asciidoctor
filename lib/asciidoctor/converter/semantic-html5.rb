# frozen_string_literal: true
module Asciidoctor
# A built-in {Converter} implementation that generates HTML 5 output
# that maximizes the use of semantic constructs.
class Converter::SemanticHtml5Converter < Converter::Base
  register_for 'semantic-html5', 'sem-html5'

  def initialize backend, opts = {}
    @backend = backend
    if opts[:htmlsyntax] == 'xml'
      syntax = 'xml'
    else
      syntax = 'html'
    end
    init_backend_traits basebackend: 'html', filetype: 'html', htmlsyntax: syntax, outfilesuffix: '.html', supports_templates: true
  end

  def convert_embedded node
    node.content
  end

  def convert_paragraph node
    attributes = html_attributes node.id, node.role, 'paragraph'
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

  def html_attributes id, role, default_role
    roles = []
    roles << default_role if default_role
    roles << role if role
    %(#{id ? %( id="#{id}") : ''}#{roles.empty? ? '' : %( class="#{roles.join(' ')}") })
  end
end
end
