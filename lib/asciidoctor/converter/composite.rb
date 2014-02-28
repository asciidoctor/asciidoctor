module Asciidoctor
  # A {Converter} implementation that delegates to the chain of {Converter}
  # objects passed to the constructor. Selects the first {Converter} that
  # identifies itself as the handler for a given transform.
  class Converter::CompositeConverter < Converter::Base

    # Get the Array of Converter objects in the chain
    attr_reader :converters

    def initialize backend, *converters
      @backend = backend
      (@converters = converters.flatten.compact).each do |converter|
        converter.composed self if converter.respond_to? :composed
      end
      @converter_map = {}
    end

    # Public: Delegates to the first converter that identifies itself as the
    # handler for the given transform.
    #
    # node      - the AbstractNode to convert
    # transform - the optional String transform, or the name of the node if no
    #             transform is specified. (default: nil)
    #
    # Returns the String result returned from the delegate's convert method
    def convert node, transform = nil
      transform ||= node.node_name
      # QUESTION is there a way we can control whether to use convert or send?
      (converter_for transform).convert node, transform
    end

    # Public: Delegates to the first converter that identifies itself as the
    # handler for the given transform. The optional Hash is passed as the last
    # option to the delegate's convert method.
    #
    # node      - the AbstractNode to convert
    # transform - the optional String transform, or the name of the node if no
    #             transform is specified. (default: nil)
    # opts      - a optional Hash that is passed to the delegate's convert method. (default: {})
    #
    # Returns the String result returned from the delegate's convert method
    def convert_with_options node, transform = nil, opts = {}
      transform ||= node.node_name
      # QUESTION should we check arity, or perhaps do a rescue ::ArgumentError?
      (converter_for transform).convert_with_options node, transform, opts
    end

    # Public: Retrieve the converter for the specified transform.
    #
    # Returns the matching [Converter] object
    def converter_for transform
      @converter_map[transform] ||= find_converter transform
    end

    # Internal: Find the converter for the specified transform.
    # Raise an exception if no converter is found.
    #
    # Returns the matching [Converter] object
    def find_converter transform
      @converters.each do |candidate|
        return candidate if candidate.handles? transform
      end
      raise %(Could not find a converter to handle transform: #{transform})
    end
  end
end
