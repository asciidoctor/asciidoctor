# Public: Methods for managing inline elements in AsciiDoc block
class Asciidoctor::Inline < Asciidoctor::AbstractNode
  # Public: Get the text of this inline element
  attr_reader :text

  # Public: Get the type (qualifier) of this inline element
  attr_reader :type

  # Public: Get/Set the target (e.g., uri) of this inline element
  attr_accessor :target

  def initialize(parent, context, text = nil, opts = {})
    super(parent, context)

    @text = text 
    @id = opts[:id] if opts.has_key?(:id)
    @type = opts[:type] if opts.has_key?(:type)
    @target = opts[:target] if opts.has_key?(:target)
    
    if opts.has_key?(:attributes) && (attributes = opts[:attributes]).is_a?(Hash)
      update_attributes(opts[:attributes]) unless attributes.empty?
    end
  end

  def render
    renderer.render("inline_#{@context}", self).chomp
  end

end
