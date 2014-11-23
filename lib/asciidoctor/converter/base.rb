# encoding: UTF-8
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

    # Public: Converts the specified {AbstractNode} using the specified
    # transform and optionally additional options (when not empty).
    #
    # CAUTION: Method that handles the specified transform *may not* accept the
    # second argument with additional options, in which case an {ArgumentError}
    # is raised if the given +opts+ Hash is not nil. The additional options are
    # used in template-based backends to access convert helper methods such as
    # outline.
    #
    # See {Converter#convert} for more details.
    #
    # Returns the [String] result of conversion
    def convert node, transform = nil, opts = {}
      transform ||= node.node_name
      opts.empty? ? (send transform, node) : (send transform, node, opts)
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
