# encoding: UTF-8
module Asciidoctor
  # A base module for defining converters that can be used to convert {AbstractNode}
  # objects in a parsed AsciiDoc document to a backend format such as HTML or
  # DocBook.
  #
  # Implementing a converter involves:
  #
  # * including this module in a {Converter} implementation class
  # * overriding the {Converter#convert} method
  # * optionally associating the converter with one or more backends using
  #   the {#register_for} DSL method imported by the {Config Converter::Config} module
  #
  # Examples
  #
  #   class TextConverter
  #     include Asciidoctor::Converter
  #     register_for 'text'
  #     def initialize backend, opts
  #       super
  #       outfilesuffix '.txt'
  #     end
  #     def convert node, transform = nil
  #       case (transform ||= node.node_name)
  #       when 'document'
  #         node.content
  #       when 'section'
  #         [node.title, node.content] * "\n\n"
  #       when 'paragraph'
  #         node.content.tr("\n", ' ') << "\n"
  #       else
  #         if transform.start_with? 'inline_'
  #           node.text
  #         else
  #           %(<#{transform}>\n)
  #         end
  #       end
  #     end
  #   end
  #
  #   puts Asciidoctor.convert_file 'sample.adoc', backend: :text
  module Converter
    # A module that provides the {#register_for} method for statically
    # registering a converter with the default {Factory Converter::Factory} instance.
    module Config
      # Public: Statically registers the current {Converter} class with the default
      # {Factory Converter::Factory} to handle conversion to the specified backends.
      #
      # This method also defines the converts? method on the class which returns whether
      # the class is registered to convert a specified backend.
      #
      # backends - A String Array of backends with which to associate this {Converter} class.
      #
      # Returns nothing
      def register_for *backends
        Factory.register self, backends
        metaclass = class << self; self; end
        if backends == ['*']
          metaclass.send :define_method, :converts? do |name|
            true
          end
        else
          metaclass.send :define_method, :converts? do |name|
            backends.include? name
          end
        end
        nil
      end
    end

    module BackendInfo
      def backend_info
        @backend_info ||= setup_backend_info
      end

      def setup_backend_info
        raise ::ArgumentError, %(Cannot determine backend for converter: #{self.class}) unless @backend
        base = @backend.sub TrailingDigitsRx, ''
        if (ext = DEFAULT_EXTENSIONS[base])
          type = ext[1..-1]
        else
          # QUESTION should we be forcing the basebackend to html if unknown?
          base = 'html'
          ext = '.html'
          type = 'html'
          syntax = 'html'
        end
        {
          'basebackend' => base,
          'outfilesuffix' => ext,
          'filetype' => type,
          'htmlsyntax' => syntax
        }
      end

      def filetype value = nil
        if value
          backend_info['filetype'] = value
        else
          backend_info['filetype']
        end
      end

      def basebackend value = nil
        if value
          backend_info['basebackend'] = value
        else
          backend_info['basebackend']
        end
      end

      def outfilesuffix value = nil
        if value
          backend_info['outfilesuffix'] = value
        else
          backend_info['outfilesuffix']
        end
      end

      def htmlsyntax value = nil
        if value
          backend_info['htmlsyntax'] = value
        else
          backend_info['htmlsyntax']
        end
      end
    end

    class << self
      # Mixes the {Config Converter::Config} module into any class that includes the {Converter} module.
      #
      # converter - The Class that includes the {Converter} module
      #
      # Returns nothing
      def included converter
        converter.extend Config
      end
    end

    include Config
    include BackendInfo

    # Public: Creates a new instance of Converter
    #
    # backend - The String backend format to which this converter converts.
    # opts    - An options Hash (optional, default: {})
    #
    # Returns a new instance of [Converter]
    def initialize backend, opts = {}
      @backend = backend
      setup_backend_info
    end

=begin
    # Public: Invoked when this converter is added to the chain of converters in a {CompositeConverter}.
    #
    # owner - The CompositeConverter instance
    #
    # Returns nothing
    def composed owner
    end
=end

    # Public: Converts an {AbstractNode} using the specified transform along
    # with additional options. If a transform is not specified, implementations
    # typically derive one from the {AbstractNode#node_name} property.
    #
    # Implementations are free to decide how to carry out the conversion. In
    # the case of the built-in converters, the tranform value is used to
    # dispatch to a handler method. The {TemplateConverter} uses the value of
    # the transform to select a template to render.
    #
    # node      - The concrete instance of AbstractNode to convert
    # transform - An optional String transform that hints at which transformation
    #             should be applied to this node. If a transform is not specified,
    #             the transform is typically derived from the value of the
    #             node's node_name property. (optional, default: nil)
    # opts      - An optional Hash of options that provide additional hints about
    #             how to convert the node. (optional, default: {})
    #
    # Returns the [String] result
    def convert node, transform = nil, opts = {}
      raise ::NotImplementedError
    end

    # Alias for backward compatibility.
    alias :convert_with_options :convert
  end

  # A module that can be used to mix the {#write} method into a {Converter}
  # implementation to allow the converter to control how the output is written
  # to disk.
  module Writer
    # Public: Writes the output to the specified target file name or stream.
    #
    # output - The output String to write
    # target - The String file name or stream object to which the output should
    #          be written.
    #
    # Returns nothing
    def write output, target
      if target.respond_to? :write
        target.write output.chomp
        # ensure there's a trailing endline to be nice to terminals
        target.write EOL
      else
        ::File.open(target, 'w') {|f| f.write output }
      end
      nil
    end
  end

  module VoidWriter
    include Writer
    # Public: Does not write output
    def write output, target
    end
  end
end

require 'asciidoctor/converter/base'
require 'asciidoctor/converter/factory'
