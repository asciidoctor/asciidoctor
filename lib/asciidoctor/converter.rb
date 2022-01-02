# frozen_string_literal: true
module Asciidoctor
# A module for defining converters that are used to convert {AbstractNode} objects in a parsed AsciiDoc document to an
# output (aka backend) format such as HTML or DocBook.
#
# A {Converter} is typically instantiated each time an AsciiDoc document is processed (i.e., parsed and converted).
# Implementing a custom converter entails:
#
# * Including the {Converter} module in a converter class and implementing the {Converter#convert} method or extending
#   the {Converter::Base Base} class and implementing the dispatch methods that map to each node.
# * Optionally registering the converter with one or more backend names statically using the +register_for+ DSL method
#   contributed by the {Converter::Config Config} module.
#
# Examples
#
#   class TextConverter
#     include Asciidoctor::Converter
#     register_for 'text'
#     def initialize *args
#       super
#       outfilesuffix '.txt'
#     end
#     def convert node, transform = node.node_name, opts = nil
#       case transform
#       when 'document', 'section'
#         [node.title, node.content].join %(\n\n)
#       when 'paragraph'
#         (node.content.tr ?\n, ' ') << ?\n
#       else
#         (transform.start_with? 'inline_') ? node.text : node.content
#       end
#     end
#   end
#   puts Asciidoctor.convert_file 'sample.adoc', backend: :text, safe: :safe
#
#   class Html5Converter < (Asciidoctor::Converter.for 'html5')
#     register_for 'html5'
#     def convert_paragraph node
#       %(<p>#{node.content}</p>)
#     end
#   end
#   puts Asciidoctor.convert_file 'sample.adoc', safe: :safe
module Converter
  autoload :CompositeConverter, %(#{__dir__}/converter/composite)
  autoload :TemplateConverter, %(#{__dir__}/converter/template) unless RUBY_ENGINE == 'opal'

  # Public: The String backend name that this converter is handling.
  attr_reader :backend

  # Public: Creates a new instance of this {Converter}.
  #
  # backend - The String backend name (aka format) to which this converter converts.
  # opts    - An options Hash (optional, default: {})
  #
  # Returns a new [Converter] instance.
  def initialize backend, opts = {}
    @backend = backend
  end

  # Public: Converts an {AbstractNode} using the given transform.
  #
  # This method must be implemented by a concrete converter class.
  #
  # node      - The concrete instance of AbstractNode to convert.
  # transform - An optional String transform that hints at which transformation should be applied to this node. If a
  #             transform is not given, the transform is often derived from the value of the {AbstractNode#node_name}
  #             property. (optional, default: nil)
  # opts      - An optional Hash of options hints about how to convert the node. (optional, default: nil)
  #
  # Returns the [String] result.
  def convert node, transform = nil, opts = nil
    raise ::NotImplementedError, %(#{self.class} (backend: #{@backend}) must implement the ##{__method__} method)
  end

  # Public: Reports whether the current converter is able to convert this node (by its transform name). Used by the
  # {CompositeConverter} to select which converter to use to handle a given node. Returns true by default.
  #
  # transform - the String name of the node transformation (typically the node name).
  #
  # Returns a [Boolean] indicating whether this converter can handle the specified transform.
  def handles? transform
    true
  end

  # Public: Derive backend traits (basebackend, filetype, outfilesuffix, htmlsyntax) from the given backend.
  #
  # backend - the String backend from which to derive the traits
  # basebackend - the String basebackend to use in favor of deriving one from the backend (optional, default: nil)
  #
  # Returns the backend traits for the given backend as a [Hash].
  def self.derive_backend_traits backend, basebackend = nil
    return {} unless backend
    if (outfilesuffix = DEFAULT_EXTENSIONS[(basebackend ||= backend.sub TrailingDigitsRx, '')])
      filetype = outfilesuffix.slice 1, outfilesuffix.length
    else
      outfilesuffix = %(.#{filetype = basebackend})
    end
    filetype == 'html' ?
      { basebackend: basebackend, filetype: filetype, htmlsyntax: 'html', outfilesuffix: outfilesuffix } :
      { basebackend: basebackend, filetype: filetype, outfilesuffix: outfilesuffix }
  end

  module BackendTraits
    def basebackend value = nil
      value ? ((backend_traits value)[:basebackend] = value) : backend_traits[:basebackend]
    end

    def filetype value = nil
      value ? (backend_traits[:filetype] = value) : backend_traits[:filetype]
    end

    def htmlsyntax value = nil
      value ? (backend_traits[:htmlsyntax] = value) : backend_traits[:htmlsyntax]
    end

    def outfilesuffix value = nil
      value ? (backend_traits[:outfilesuffix] = value) : backend_traits[:outfilesuffix]
    end

    def supports_templates value = true
      backend_traits[:supports_templates] = value
    end

    def supports_templates?
      backend_traits[:supports_templates]
    end

    def init_backend_traits value = nil
      @backend_traits = value || {}
    end

    def backend_traits basebackend = nil
      @backend_traits ||= Converter.derive_backend_traits @backend, basebackend
    end

    alias backend_info backend_traits

    # Deprecated: Use {Converter.derive_backend_traits} instead.
    def self.derive_backend_traits backend, basebackend = nil
      Converter.derive_backend_traits backend, basebackend
    end
  end

  # A module that contributes the +register_for+ method for registering a converter with the default registry.
  module Config
    # Public: Registers this {Converter} class with the default registry to handle the specified backend name(s).
    #
    # backends - One or more String backend names with which to associate this {Converter} class.
    #
    # Returns nothing.
    def register_for *backends
      Converter.register self, *(backends.map {|backend| backend.to_s })
    end
  end

  # A reusable module for registering and instantiating {Converter Converter} classes used to convert an {AbstractNode}
  # to an output (aka backend) format such as HTML or DocBook.
  #
  # {Converter Converter} objects are instantiated by passing a String backend name and, optionally, an options Hash to
  # the {Factory#create} method. The backend can be thought of as an intent to convert a document to a specified format.
  #
  # Applications interact with the factory either through the global, static registry mixed into the {Converter
  # Converter} module or a concrete class that includes this module such as {CustomFactory}. For example:
  #
  # Examples
  #
  #   converter = Asciidoctor::Converter.create 'html5', htmlsyntax: 'xml'
  module Factory
    # Public: Create an instance of DefaultProxyFactory or CustomFactory, depending on whether the proxy_default keyword
    # arg is set (true by default), and optionally seed it with the specified converters map. If proxy_default is set,
    # entries in the proxy registry are preferred over matching entries from the default registry.
    #
    # converters    - An optional Hash of converters to use in place of ones in the default registry. The keys are
    #                 backend names and the values are converter classes or instances.
    # proxy_default - A Boolean keyword arg indicating whether to proxy the default registry (optional, default: true).
    #
    # Returns a Factory instance (DefaultFactoryProxy or CustomFactory) seeded with the optional converters map.
    def self.new converters = nil, proxy_default: true
      proxy_default ? (DefaultFactoryProxy.new converters) : (CustomFactory.new converters)
    end

    # Deprecated: Maps the old default factory instance holder to the Converter module.
    def self.default *args
      Converter
    end

    # Deprecated: Maps the create method on the old default factory instance holder to the Converter module.
    def self.create backend, opts = {}
      default.create backend, opts
    end

    # Public: Register a custom converter with this factory to handle conversion for the specified backends. If the
    # backend is an asterisk (i.e., +*+), the converter will handle any backend for which a converter is not registered.
    #
    # converter - The Converter class to register.
    # backends  - One or more String backend names that this converter should be registered to handle.
    #
    # Returns nothing
    def register converter, *backends
      backends.each {|backend| backend == '*' ? (registry.default = converter) : (registry[backend] = converter) }
    end

    # Public: Lookup the custom converter registered with this factory to handle the specified backend.
    #
    # backend - The String backend name.
    #
    # Returns the [Converter] class registered to convert the specified backend or nil if no match is found.
    def for backend
      registry[backend]
    end

    # Public: Create a new Converter object that can be used to convert {AbstractNode}s to the format associated with
    # the backend. This method accepts an optional Hash of options that are passed to the converter's constructor.
    #
    # If a custom Converter is found to convert the specified backend, it's instantiated (if necessary) and returned
    # immediately. If a custom Converter is not found, an attempt is made to find a built-in converter. If the
    # +:template_dirs+ key is found in the Hash passed as the second argument, a {CompositeConverter} is created that
    # delegates to a {TemplateConverter} and, if found, the built-in converter. If the +:template_dirs+ key is not
    # found, the built-in converter is returned or nil if no converter is found.
    #
    # backend - the String backend name.
    # opts    - a Hash of options to customize creation; also passed to the converter's constructor:
    #           :template_dirs - a String Array of directories used to instantiate a {TemplateConverter} (optional).
    #           :delegate_backend - a backend String of the last converter in the {CompositeConverter} chain (optional).
    #
    # Returns the [Converter] instance.
    def create backend, opts = {}
      if (converter = self.for backend)
        converter = converter.new backend, opts if ::Class === converter
        if (template_dirs = opts[:template_dirs]) && BackendTraits === converter && converter.supports_templates?
          CompositeConverter.new backend, (TemplateConverter.new backend, template_dirs, opts), converter, backend_traits_source: converter
        else
          converter
        end
      elsif (template_dirs = opts[:template_dirs])
        if (delegate_backend = opts[:delegate_backend]) && (converter = self.for delegate_backend)
          converter = converter.new delegate_backend, opts if ::Class === converter
          CompositeConverter.new backend, (TemplateConverter.new backend, template_dirs, opts), converter, backend_traits_source: converter
        else
          TemplateConverter.new backend, template_dirs, opts
        end
      end
    end

    # Public: Get the Hash of Converter classes keyed by backend name. Intended for testing only.
    def converters
      registry.merge
    end

    private

    def registry
      raise ::NotImplementedError, %(#{Factory} subclass #{self.class} must implement the ##{__method__} method)
    end
  end

  class CustomFactory
    include Factory

    def initialize seed_registry = nil
      if seed_registry
        seed_registry.default = seed_registry.delete '*'
        @registry = seed_registry
      else
        @registry = {}
      end
    end

    # Public: Unregister all Converter classes that are registered with this factory. Intended for testing only.
    #
    # Returns nothing.
    def unregister_all
      registry.clear.default = nil
    end

    private

    attr_reader :registry
  end

  # Mixed into the {Converter} module to provide the global registry of converters that are registered statically.
  #
  # This registry includes built-in converters for {Html5Converter HTML 5}, {DocBook5Converter DocBook 5} and
  # {ManPageConverter man(ual) page}, as well as any custom converters that have been discovered or explicitly
  # registered. Converter registration is synchronized (where applicable) and is thus guaranteed to be thread safe.
  module DefaultFactory
    include Factory

    private

    @@registry = {}

    def registry
      @@registry
    end

    unless RUBY_ENGINE == 'opal' # the following block adds support for synchronization and lazy registration
      public

      def register converter, *backends
        if @@mutex.owned?
          backends.each {|backend| backend == '*' ? (@@catch_all = converter) : (@@registry = @@registry.merge backend => converter) }
        else
          @@mutex.synchronize { register converter, *backends }
        end
      end

      def unregister_all
        @@mutex.synchronize do
          @@registry = @@registry.select {|backend| PROVIDED[backend] }
          @@catch_all = nil
        end
      end

      def for backend
        @@registry.fetch backend do
          PROVIDED[backend] ? (@@mutex.synchronize do
            # require is thread-safe, so no reason to refetch
            require PROVIDED[backend]
            @@registry[backend]
          end) : catch_all
        end
      end

      PROVIDED = {
        'docbook5' => %(#{__dir__}/converter/docbook5),
        'html5' => %(#{__dir__}/converter/html5),
        'manpage' => %(#{__dir__}/converter/manpage),
      }

      private

      def catch_all
        @@catch_all
      end

      @@catch_all = nil
      @@mutex = ::Mutex.new
    end
  end

  class DefaultFactoryProxy < CustomFactory
    include DefaultFactory # inserts module into ancestors immediately after superclass

    unless RUBY_ENGINE == 'opal'
      def unregister_all
        super
        @registry.clear.default = nil
      end

      def for backend
        @registry.fetch(backend) { super }
      end

      private

      def catch_all
        @registry.default || super
      end
    end
  end

  # Internal: Mixes the {Config} module into any class that includes the {Converter} module. Additionally, mixes the
  # {BackendTraits} method into instances of this class.
  #
  # into - The Class into which the {Converter} module is being included.
  #
  # Returns nothing.
  def self.included into
    into.send :include, BackendTraits
    into.extend Config
  end
  private_class_method :included # use separate declaration for Ruby 2.0.x

  # An abstract base class for defining converters that can be used to convert {AbstractNode} objects in a parsed
  # AsciiDoc document to a backend format such as HTML or DocBook.
  class Base
    include Logging
    include Converter

    # Public: Converts an {AbstractNode} by delegating to a method that matches the transform value.
    #
    # This method looks for a method whose name matches the transform prefixed with "convert_" to dispatch to. If the
    # +opts+ argument is non-nil, this method assumes the dispatch method accepts two arguments, the node and an options
    # Hash. The options Hash may be used by converters to delegate back to the top-level converter. Currently, this
    # feature is used for the outline transform. If the +opts+ argument is nil, this method assumes the dispatch method
    # accepts the node as its only argument.
    #
    # See {Converter#convert} for details about the arguments and return value.
    def convert node, transform = node.node_name, opts = nil
      opts ? (send 'convert_' + transform, node, opts) : (send 'convert_' + transform, node)
    rescue
      raise unless ::NoMethodError === (ex = $!) && ex.receiver == self && ex.name.to_s == transform
      logger.warn %(missing convert handler for #{ex.name} node in #{@backend} backend (#{self.class}))
      nil
    end

    def handles? transform
      respond_to? %(convert_#{transform})
    end

    # Public: Converts the {AbstractNode} using only its converted content.
    #
    # Returns the converted [String] content.
    def content_only node
      node.content
    end

    # Public: Skips conversion of the {AbstractNode}.
    #
    # Returns nothing.
    def skip node; end
  end

  extend DefaultFactory # exports static methods
end
end
