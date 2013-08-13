module Asciidoctor
# An abstract base class that provides methods for definining and rendering the
# backend templates. Concrete subclasses must implement the template method.
#
# NOTE we must use double quotes for attribute values in the HTML/XML output to
# prevent quote processing. This requirement seems hackish, but AsciiDoc has
# this same issue.
class BaseTemplate

  attr_reader :view
  attr_reader :backend
  attr_reader :eruby

  def initialize(view, backend, eruby)
    @view = view
    @backend = backend
    @eruby = eruby
  end

  def self.inherited(klass)
    if self == BaseTemplate
      @template_classes ||= []
      @template_classes << klass
    else
      self.superclass.inherited(klass)
    end
  end

  def self.template_classes
    @template_classes
  end

  # Public: Render this template in the execution context of
  # the supplied concrete instance of Asciidoctor::AbstractNode.
  #
  # This method invokes the template method on this instance to retrieve the
  # template data and then evaluates that template in the context of the
  # supplied concrete instance of Asciidoctor::AbstractNode. This instance is
  # accessible to the template data via the local variable named 'template'.
  #
  # If the compact flag on the document's renderer is true and the view context is
  # document or embedded, then blank lines in the output are compacted. Otherwise,
  # the rendered output is returned unprocessed.
  #
  # node   - The concrete instance of AsciiDoctor::AbstractNode to render
  # locals - A Hash of additional variables. Not currently in use.
  def render(node = Object.new, locals = {})
    tmpl = template
    case tmpl
    when :invoke_result
      return result(node)
    when :content
      result = node.content
    else
      result = tmpl.result(node.get_binding(self))
    end

    if (@view == 'document' || @view == 'embedded') &&
        node.renderer.compact && !node.document.nested?
      compact result
    else
      result
    end
  end

  # Public: Compact blank lines in the provided text. This method also restores
  # every HTML line feed entity found with an endline character.
  #
  # text  - the String to process
  #
  # returns the text with blank lines removed and HTML line feed entities
  # converted to an endline character.
  def compact(str)
    str.gsub(BLANK_LINE_PATTERN, '').gsub(LINE_FEED_ENTITY, EOL)
  end

  # Public: Preserve endlines by replacing them with the HTML line feed entity.
  #
  # If the compact flag on the document's renderer is true, perform the
  # replacement. Otherwise, return the text unprocessed.
  #
  # text  - the String to process
  # node  - the concrete instance of Asciidoctor::AbstractNode being rendered
  def preserve_endlines(str, node)
    node.renderer.compact ? str.gsub(EOL, LINE_FEED_ENTITY) : str
  end

  def template
    raise "You chilluns need to make your own template"
  end

  # create template matter to insert an attribute if the variable has a value
  def attribute(name, key)
    type = key.is_a?(Symbol) ? :attr : :var
    if type == :attr
      # example: <% if attr? 'foo' %> bar="<%= attr 'foo' %>"<% end %>
      %(<% if attr? '#{key}' %> #{name}="<%= attr '#{key}' %>"<% end %>)
    else
      # example: <% if foo %> bar="<%= foo %>"<% end %>
      %(<% if #{key} %> #{name}="<%= #{key} %>"<% end %>)
    end
  end
end

module EmptyTemplate
  def result(node)
    ''
  end

  def template
    :invoke_result
  end
end
end
