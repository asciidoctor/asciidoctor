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

    # value of attributes option for inline nodes may be nil
    if (attrs = opts[:attributes])
      @attributes = attrs.dup
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
  alias render convert

  # Public: Returns the converted alt text for this inline image.
  #
  # Returns the [String] value of the alt attribute.
  def alt
    attr 'alt'
  end

  # (see AbstractNode#reftext?)
  def reftext?
    @text && (@type == :ref || @type == :bibref)
  end

  # (see AbstractNode#reftext)
  def reftext
    (val = @text) ? (apply_reftext_subs val) : nil
  end

  # Public: Generate cross reference text (xreftext) that can be used to refer
  # to this inline node.
  #
  # Use the explicit reftext for this inline node, if specified, retrieved by
  # calling the reftext method. Otherwise, returns nil.
  #
  # xrefstyle - Not currently used (default: nil).
  #
  # Returns the [String] reftext to refer to this inline node or nothing if no
  # reftext is defined.
  def xreftext xrefstyle = nil
    reftext
  end
end
end
