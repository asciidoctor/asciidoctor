module Asciidoctor
  module Converter; end # required for Opal

  # An abstract base class for defining converters that can be used to convert
  # {AbstractNode} objects in a parsed AsciiDoc document to a backend format
  # such as HTML or DocBook.
  #
  # Concrete subclasses must implement the {#convert} method and, optionally,
  # the {#convert_with_options} method.
  class Converter::Base
    include Converter
  end

  # An abstract base class for built-in {Converter} classes.
  class Converter::BuiltIn
    def initialize backend, opts = {}
    end

    # Public: Converts the specified {AbstractNode} using the specified transform.
    #
    # See {Converter#convert} for more details.
    #
    # Returns the [String] result of conversion
    def convert node, transform = nil
      transform ||= node.node_name
      send transform, node
    end

    # Public: Converts the specified {AbstractNode} using the specified transform 
    # with additional options.
    #
    # See {Converter#convert_with_options} for more details.
    #
    # Returns the [String] result of conversion
    def convert_with_options node, transform = nil, opts = {}
      transform ||= node.node_name
      send transform, node, opts
    end

    alias :handles? :respond_to?

    # Public: Returns the converted content of the {AbstractNode}.
    #
    # Returns the converted [String] content of the {AbstractNode}.
    def content node
      node.content
    end

    alias :pass :content

    # Public: Skips conversion of the {AbstractNode}.
    #
    # Returns [NilClass]
    def skip node
      nil
    end
  end
end
