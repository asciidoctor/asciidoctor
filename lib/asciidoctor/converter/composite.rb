# frozen_string_literal: true
module Asciidoctor
# A {Converter} implementation that delegates to the chain of {Converter}
# objects passed to the constructor. Selects the first {Converter} that
# identifies itself as the handler for a given transform.
class Converter::CompositeConverter < Converter::Base
  # Get the Array of Converter objects in the chain
  attr_reader :converters

  def initialize backend, *converters, backend_traits_source: nil
    @backend = backend
    (@converters = converters).each {|converter| converter.composed self if converter.respond_to? :composed }
    init_backend_traits backend_traits_source.backend_traits if backend_traits_source
    @converter_cache = ::Hash.new {|hash, key| hash[key] = find_converter key }
  end

  # Public: Delegates to the first converter that identifies itself as the
  # handler for the given transform. The optional Hash is passed as the last
  # option to the delegate's convert method.
  #
  # node      - the AbstractNode to convert
  # transform - the optional String transform, or the name of the node if no
  #             transform is specified. (default: nil)
  # opts      - an optional Hash that is passed to the delegate's convert method. (default: nil)
  #
  # Returns the String result returned from the delegate's convert method
  def convert node, transform = nil, opts = nil
    (converter_for transform ||= node.node_name).convert node, transform, opts
  end

  # Public: Retrieve the converter for the specified transform.
  #
  # Returns the matching [Converter] object
  def converter_for transform
    @converter_cache[transform]
  end

  # Public: Find the converter for the specified transform.
  # Raise an exception if no converter is found.
  #
  # Returns the matching [Converter] object
  def find_converter transform
    @converters.each {|candidate| return candidate if candidate.handles? transform }
    raise %(Could not find a converter to handle transform: #{transform})
  end
end
end
