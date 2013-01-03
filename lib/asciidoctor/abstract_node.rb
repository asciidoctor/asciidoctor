class Asciidoctor::AbstractNode
  include Asciidoctor::Substituters

  # Public: Get the element which is the parent of this node
  attr_reader :parent

  # Public: Get the Asciidoctor::Document to which this node belongs
  attr_reader :document

  # Public: Get the Symbol context for this node
  attr_reader :context

  # Public: Get the id of this node
  attr_accessor :id

  # Public: Get the Hash of attributes for this node
  attr_reader :attributes

  def initialize(parent, context)
    @parent = (context != :document ? parent : nil)
    if !parent.nil?
      @document = parent.is_a?(Asciidoctor::Document) ? parent : parent.document
    else
      @document = nil
    end
    @context = context
    @attributes = {}
    @passthroughs = []
  end

  def attr(name, default = nil)
    if self == @document
      default.nil? ? @attributes[name.to_s] : @attributes.fetch(name.to_s, default)
    else
      default.nil? ? @attributes.fetch(name.to_s, @document.attr(name)) :
          @attributes.fetch(name.to_s, @document.attr(name, default))
    end
  end

  def attr?(name)
    if self == @document
      @attributes.has_key? name.to_s
    else
      @attributes.has_key?(name.to_s) || @document.attr?(name)
    end
  end

  def update_attributes(attributes)
    @attributes.update(attributes)
  end

  # Public: Get the Asciidoctor::Renderer instance being used for the
  # Asciidoctor::Document to which this node belongs
  def renderer
    @document.renderer
  end

end
