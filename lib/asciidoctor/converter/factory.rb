# encoding: UTF-8
module Asciidoctor
  module Converter
    # A factory for instantiating converters that are used to convert a
    # {Document} (i.e., a parsed AsciiDoc tree structure) or {AbstractNode} to
    # a backend format such as HTML or DocBook. {Factory Converter::Factory} is
    # the primary entry point for creating, registering and accessing
    # converters.
    #
    # {Converter} objects are instantiated by passing a String backend name
    # and, optionally, an options Hash to the {Factory#create} method. The
    # backend can be thought of as an intent to convert a document to a
    # specified format. For example:
    #
    #   converter = Asciidoctor::Converter::Factory.create 'html5', :htmlsyntax => 'xml'
    #
    # Converter objects are thread safe. They only survive the lifetime of a single conversion.
    #
    # A singleton instance of {Factory Converter::Factory} can be accessed
    # using the {Factory.default} method. This instance maintains the global
    # registry of statically registered converters. The registery includes
    # built-in converters for {Html5Converter HTML 5}, {DocBook5Converter
    # DocBook 5} and {DocBook45Converter DocBook 4.5}, as well as any custom
    # converters that have been discovered or explicitly registered.
    #
    # If the {https://rubygems.org/gems/thread_safe thread_safe} gem is
    # installed, access to the default factory is guaranteed to be thread safe.
    # Otherwise, a warning is issued to the user.
    class Factory
      @__default__ = nil
      class << self

        # Public: Retrieves a singleton instance of {Factory Converter::Factory}.
        #
        # If the thread_safe gem is installed, the registry of converters is
        # initialized as a ThreadSafe::Cache. Otherwise, a warning is issued and
        # the registry of converters is initialized using a normal Hash.
        #
        # initialize_singleton - A Boolean to indicate whether the singleton should
        #                        be initialize if it has not already been created.
        #                        If false, and a singleton has not been previously
        #                        initialized, a fresh instance is returned.
        #
        # Returns the default [Factory] singleton instance
        def default initialize_singleton = true
          return @__default__ || new unless initialize_singleton
          # FIXME this assignment is not thread_safe, may need to use a ::Threadsafe helper here
          @__default__ ||= begin
            require 'thread_safe'.to_s unless defined? ::ThreadSafe
            new ::ThreadSafe::Cache.new
          rescue ::LoadError
            warn 'asciidoctor: WARNING: gem \'thread_safe\' is not installed. This gem is recommended when registering custom converters.'
            new
          end
        end

        # Public: Register a custom converter in the global converter factory to
        # handle conversion to the specified backends. If the backend value is an
        # asterisk, the converter is used to handle any backend that does not have
        # an explicit converter.
        #
        # converter - The Converter class to register
        # backends  - A String Array of backend names that this converter should
        #             be registered to handle (optional, default: ['*'])
        #
        # Returns nothing
        def register converter, backends = ['*']
          default.register converter, backends
        end

        # Public: Lookup the custom converter for the specified backend in the
        # global factory.
        #
        # This method does not resolve the built-in converters.
        #
        # backend - The String backend name
        #
        # Returns the [Converter] class registered to convert the specified backend
        # or nil if no match is found
        def resolve backend
          default.resolve backend
        end

        # Public: Lookup the converter for the specified backend in the global
        # factory and instantiate it, forwarding the Hash of options to the
        # constructor of the converter class.
        #
        # If the custom converter is not found, an attempt will be made to find
        # and instantiate a built-in converter.
        #
        #
        # backend - The String backend name
        # opts - A Hash of options to pass to the converter
        #
        # Returns an instance of [Converter] for converting the specified backend or
        # nil if no match is found.
        def create backend, opts = {}
          default.create backend, opts
        end

        # Public: Retrieve the global Hash of custom Converter classes keyed by backend.
        #
        # Returns the the global [Hash] of custom Converter classes
        def converters
          default.converters
        end

        # Public: Unregister all Converter classes in the global factory.
        #
        # Returns nothing
        def unregister_all
          default.unregister_all
        end
      end

      # Public: Get the Hash of Converter classes keyed by backend name
      attr_reader :converters

      def initialize converters = nil
        @converters = converters || {}
        @star_converter = nil
      end

      # Public: Register a custom converter with this factory to handle conversion
      # to the specified backends. If the backend value is an asterisk, the
      # converter is used to handle any backend that does not have an explicit
      # converter.
      #
      # converter - The Converter class to register
      # backends  - A String Array of backend names that this converter should
      #             be registered to handle (optional, default: ['*'])
      #
      # Returns nothing
      def register converter, backends = ['*']
        backends.each do |backend|
          @converters[backend] = converter
          if backend == '*'
            @star_converter = converter
          end
        end
        nil
      end

      # Public: Lookup the custom converter registered with this factory to handle
      # the specified backend.
      #
      # backend - The String backend name
      #
      # Returns the [Converter] class registered to convert the specified backend
      # or nil if no match is found
      def resolve backend
        @converters && (@converters[backend] || @star_converter)
      end

      # Public: Unregister all Converter classes that are registered with this
      # factory.
      #
      # Returns nothing
      def unregister_all
        @converters.clear
        @star_converter = nil
      end

      # Public: Create a new Converter object that can be used to convert the
      # {AbstractNode} (typically a {Document}) to the specified String backend.
      # This method accepts an optional Hash of options that are passed to the
      # converter's constructor.
      #
      # If a custom Converter is found to convert the specified backend, it is
      # instantiated (if necessary) and returned immediately. If a custom
      # Converter is not found, an attempt is made to resolve a built-in
      # converter. If the `:template_dirs` key is found in the Hash passed as the
      # second argument, a {CompositeConverter} is created that delegates to a
      # {TemplateConverter} and, if resolved, the built-in converter. If the
      # `:template_dirs` key is not found, the built-in converter is returned
      # or nil if no converter is resolved.
      #
      # backend - the String backend name
      # opts    - an optional Hash of options that get passed on to the converter's
      #           constructor. If the :template_dirs key is found in the options
      #           Hash, this method returns a {CompositeConverter} that delegates
      #           to a {TemplateConverter}. (optional, default: {})
      #
      # Returns the [Converter] object
      def create backend, opts = {}
        if (converter = resolve backend)
          if converter.is_a? ::Class
            return converter.new backend, opts
          else
            return converter
          end
        end

        base_converter = case backend
        when 'html5'
          unless defined? ::Asciidoctor::Converter::Html5Converter
            require 'asciidoctor/converter/html5'.to_s
          end
          Html5Converter.new backend, opts
        when 'docbook5'
          unless defined? ::Asciidoctor::Converter::DocBook5Converter
            require 'asciidoctor/converter/docbook5'.to_s
          end
          DocBook5Converter.new backend, opts
        when 'docbook45'
          unless defined? ::Asciidoctor::Converter::DocBook45Converter
            require 'asciidoctor/converter/docbook45'.to_s
          end
          DocBook45Converter.new backend, opts
        when 'manpage'
          unless defined? ::Asciidoctor::Converter::ManPageConverter
            require 'asciidoctor/converter/manpage'.to_s
          end
          ManPageConverter.new backend, opts
        end

        return base_converter unless opts.key? :template_dirs

        unless defined? ::Asciidoctor::Converter::TemplateConverter
          require 'asciidoctor/converter/template'.to_s
        end
        unless defined? ::Asciidoctor::Converter::CompositeConverter
          require 'asciidoctor/converter/composite'.to_s
        end
        template_converter = TemplateConverter.new backend, opts[:template_dirs], opts
        # QUESTION should we omit the composite converter if built_in_converter is nil?
        CompositeConverter.new backend, template_converter, base_converter
      end
    end
  end
end
