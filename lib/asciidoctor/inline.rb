module Asciidoctor
# Public: Methods for managing inline elements in AsciiDoc block
class Inline < AbstractNode
  # Public: Get/Set the String name of the render template
  attr_accessor :template_name

  # Public: Get the text of this inline element
  attr_reader :text

  # Public: Get the type (qualifier) of this inline element
  attr_reader :type

  # Public: Get/Set the target (e.g., uri) of this inline element
  attr_accessor :target

  def initialize(parent, context, text = nil, opts = {})
    super(parent, context)
    @template_name = "inline_#{context}"

    @text = text 

    @id = opts[:id]
    @type = opts[:type]
    @target = opts[:target]
    
    if opts.has_key?(:attributes) && (attributes = opts[:attributes]).is_a?(Hash)
      update_attributes(opts[:attributes]) unless attributes.empty?
    end
  end

  def render
    renderer.render(@template_name, self).chomp
  end

end
end
