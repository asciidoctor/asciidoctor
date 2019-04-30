# frozen_string_literal: true
module Asciidoctor
# Public: Methods for managing inline elements in AsciiDoc block
class Inline < AbstractNode
  # Public: Get the text of this inline element
  attr_accessor :text

  # Public: Get the type (qualifier) of this inline element
  attr_reader :type

  # Public: Get/Set the target (e.g., uri) of this inline element
  attr_accessor :target

  def initialize(parent, context, text = nil, opts = {})
    super(parent, context, opts)
    @node_name = %(inline_#{context})
    @text = text
    @id = opts[:id]
    @type = opts[:type]
    @target = opts[:target]
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

  # Deprecated: Use {Inline#convert} instead.
  alias render convert

  # Public: Returns the converted alt text for this inline image.
  #
  # Returns the [String] value of the alt attribute.
  def alt
    (attr 'alt') || ''
  end

  # For a reference node (:ref or :bibref), the text is the reftext (and the reftext attribute is not set).
  #
  # (see AbstractNode#reftext?)
  def reftext?
    @text && (@type == :ref || @type == :bibref)
  end

  # For a reference node (:ref or :bibref), the text is the reftext (and the reftext attribute is not set).
  #
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
