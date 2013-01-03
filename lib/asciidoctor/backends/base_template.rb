class Asciidoctor::BaseTemplate
  BLANK_LINES_PATTERN = /^\s*\n/
  LINE_FEED_ENTITY = '&#10;' # or &#x0A;

  attr_reader :view

  def initialize(view)
    @view = view
  end

  def self.inherited(klass)
    @template_classes ||= []
    @template_classes << klass
  end

  def self.template_classes
    @template_classes
  end

  # We're ignoring locals for now. Shut up.
  def render(obj = Object.new, locals = {})
    output = template.result(obj.instance_eval { binding })
    (view == 'document' || view == 'embedded') ? output.gnuke(BLANK_LINES_PATTERN).gsub(LINE_FEED_ENTITY, "\n") : output
  end

  def template
    raise "You chilluns need to make your own template"
  end

  # create template matter to insert an attribute if the variable has a value
  def attribute(name, key)
    type = key.is_a?(Symbol) ? :attr : :var
    key = key.to_s
    if type == :attr
      # example: <% if attr? 'foo' %> bar="<%= attr 'foo' %>"<% end %>
      '<% if attr? \'' + key + '\' %> ' + name + '="<%= attr \'' + key.to_s + '\' %>"<% end %>'
    else
      # example: <% if foo %> bar="<%= foo %>"<% end %>
      '<% if ' + key + ' %> ' + name + '="<%= ' + key + ' %>"<% end %>'
    end
  end

  # create template matter to insert a style class if the variable has a value
  def attrvalue(key, sibling = true)
    delimiter = sibling ? ' ' : ''
    # example: <% if attr? 'foo' %><%= attr 'foo' %><% end %>
    '<% if attr? \'' + key.to_s + '\' %>' + delimiter + '<%= attr \'' + key.to_s + '\' %><% end %>'
  end

  # create template matter to insert an id if one is specified for the block
  def id
    attribute('id', 'id')
  end
end
