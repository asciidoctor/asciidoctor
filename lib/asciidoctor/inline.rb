# encoding: UTF-8
module Asciidoctor
# Public: Methods for managing inline elements in AsciiDoc block
class Inline < AbstractNode
  # Public: Get the text of this inline element
  attr_reader :text

  # Public: Get the type (qualifier) of this inline element
  attr_reader :type

  # Public: Get/Set the target (e.g., uri) of this inline element
  attr_accessor :target

  def initialize(parent, context, text = nil, opts = {})
    super(parent, context)
    @node_name = %(inline_#{context})

    @text = text

    @id = opts[:id]
    @type = opts[:type]
    @target = opts[:target]

    unless (more_attributes = opts[:attributes]).nil_or_empty?
      update_attributes more_attributes
    end
  end

  def block?
    false
  end

  def inline?
    true
  end

  def convert
    converter.convert self
  end

  # Alias render to convert to maintain backwards compatibility
  alias :render :convert
end
end
