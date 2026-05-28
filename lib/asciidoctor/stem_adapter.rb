# frozen_string_literal: true

module Asciidoctor
# Public: A pluggable adapter for integrating a STEM processor into AsciiDoc processing.
#
# There are two types of STEM adapters. The first performs STEM processing during the convert phase.
# This adapter type must define a convert method to process the content, including adding delimiters,
# and a format method to generate the enclosing block element. The second assumes STEM processing is
# performed on the client (e.g., when the HTML document is loaded). This adapter type must define a
# docinfo? method that returns true. The companion docinfo method will then be called to insert markup
# into the output document. The docinfo functionality is available to both adapter types.
#
# Asciidoctor provides a built-in MathJax adapter. Additional adapters can be registered using
# StemAdapter.register or by supplying a custom factory.
module StemAdapter
  # Public: Returns the String name of this STEM adapter.
  attr_reader :name

  def initialize name, backend = 'html5', opts = {}
    @name = name
  end

  # Public: Indicates whether this STEM adapter has docinfo (i.e., markup) to insert into the output
  # document at the specified location. Should be called by converter after main content has been converted.
  #
  # location - The Symbol representing the location slot (:head or :footer).
  #
  # Returns a [Boolean] indicating whether the docinfo method should be called for this location.
  def docinfo? location; end

  # Public: Generates docinfo markup for this STEM adapter to insert at the specified location in the
  # output document. Should be called by converter after main content has been converted.
  #
  # location - The Symbol representing the location slot (:head or :footer).
  # doc      - The Document in which this STEM adapter is being used.
  # opts     - A Hash of options:
  #            :cdn_base_url - The String base URL for assets loaded from the CDN.
  #            :self_closing_tag_slash - The String '/' if the converter emits self-closing tags.
  #
  # Returns the [String] markup to insert.
  def docinfo location, doc, opts
    raise ::NotImplementedError, %(#{StemAdapter} subclass #{self.class} must implement the ##{__method__} method since #docinfo? returns true)
  end

  # Public: Converts the STEM content for the specified node, including adding delimiters.
  # Called for both inline STEM nodes (Inline) and block STEM nodes (Block).
  #
  # node - The STEM Block or Inline node being converted.
  # opts - An optional Hash of options.
  #
  # Returns the converted STEM content [String].
  def convert node, opts = {}
    raise ::NotImplementedError, %(#{StemAdapter} subclass #{self.class} must implement the ##{__method__} method)
  end

  # Public: Formats the enclosing element for a STEM block node.
  #
  # node - The STEM Block node being formatted.
  # opts - An optional Hash of options.
  #
  # Returns the formatted STEM block [String] including the enclosing element and converted content.
  def format node, opts = {}
    raise ::NotImplementedError, %(#{StemAdapter} subclass #{self.class} must implement the ##{__method__} method)
  end

  def self.included into
    into.extend Config
  end
  private_class_method :included # use separate declaration for Ruby 2.0.x

  module Config
    # Public: Statically register the current class in the registry for the specified names.
    #
    # names - one or more String or Symbol names with which to register the current class as a STEM
    #         adapter implementation. Symbol arguments are coerced to Strings.
    #
    # Returns nothing.
    def register_for *names
      StemAdapter.register self, *(names.map {|name| name.to_s })
    end
  end

  module Factory
    # Public: Associates the STEM adapter class or object with the specified names.
    #
    # stem_adapter - the STEM adapter implementation to register
    # names        - one or more String names with which to register this STEM adapter implementation.
    #
    # Returns nothing.
    def register stem_adapter, *names
      names.each {|name| registry[name] = stem_adapter }
    end

    # Public: Retrieves the STEM adapter class or object registered for the specified name.
    #
    # name - The String name of the STEM adapter to retrieve.
    #
    # Returns the StemAdapter Class or Object instance registered for this name.
    def for name
      registry[name]
    end

    # Public: Resolves the name to a STEM adapter instance, if found in the registry.
    #
    # name    - The String name of the STEM adapter to create.
    # backend - The String name of the backend for which this STEM adapter is being used (default: 'html5').
    # opts    - A Hash of options providing information about the context in which this STEM adapter is used:
    #           :document - The Document for which this STEM adapter was created.
    #
    # Returns a [StemAdapter] instance for the specified name.
    def create name, backend = 'html5', opts = {}
      return unless (stem_adpt = self.for name)
      stem_adpt = stem_adpt.new name, backend, opts if ::Class === stem_adpt
      raise ::NameError, %(#{stem_adpt.class} must specify a value for `name') unless stem_adpt.name
      stem_adpt
    end

    private

    def registry
      raise ::NotImplementedError, %(#{Factory} subclass #{self.class} must implement the ##{__method__} method)
    end
  end

  class CustomFactory
    include Factory

    def initialize seed_registry = nil
      @registry = seed_registry || {}
    end

    private

    attr_reader :registry
  end

  module DefaultFactory
    include Factory

    @@registry = {}

    private

    def registry
      @@registry
    end
    unless RUBY_ENGINE == 'opal'

      public

      def register stem_adapter, *names
        @@mutex.owned? ? names.each {|name| @@registry = @@registry.merge name => stem_adapter } :
            @@mutex.synchronize { register stem_adapter, *names }
      end

      # This method will lazy require and register additional built-in implementations.
      # Refer to {Factory#for} for parameters and return value.
      def for name
        @@registry.fetch name do
          @@mutex.synchronize do
            @@registry.fetch name do
              if (require_path = PROVIDED[name])
                require require_path
                @@registry[name]
              else
                @@registry = @@registry.merge name => nil
                nil
              end
            end
          end
        end
      end

      PROVIDED = {}

      @@mutex = ::Mutex.new
    end
  end

  class DefaultFactoryProxy < CustomFactory
    include DefaultFactory # inserts module into ancestors immediately after superclass

    def for name
      @registry.fetch(name) { super }
    end unless RUBY_ENGINE == 'opal'
  end

  extend DefaultFactory # exports static methods
end
end

require_relative 'stem_adapter/mathjax'
