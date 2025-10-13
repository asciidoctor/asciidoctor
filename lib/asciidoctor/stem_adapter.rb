module Asciidoctor
  module StemAdapter
  
    StemBreakRx = / *\\\n(?:\\?\n)*|\n\n+/
    
    module PluginBase
      def self.included(klass)
        klass.extend(ClassMethods)
      end
    end

    module SharedObjects
      def self.setup_class
        @@registry = {}
        @@registry_mutex = Mutex.new
      end
      setup_class

      def registry
        @@registry
      end
      def registry_mutex
        @@registry_mutex
      end
    end

    module ClassMethods
      include SharedObjects

      def register_for fmt_in, fmt_out, backend
        register_plugin "#{fmt_in}-#{fmt_out}-#{backend}".to_sym
      end

      def register_plugin(name)
        registry_mutex.synchronize do
          registry[name] = self
        end
      end

      def unregister_plugin(name)
        registry_mutex.synchronize do
          plugins.delete(name)
        end
      end
    end

    class TransformStubHtml5
      include Asciidoctor::StemAdapter::PluginBase
      #register_for :asciimath, :mathml, :html5

      public

      def convert node
        '<p><b>Unable to convert</b></p>'
      end

      def docinfo? location
        false
      end

      def docinfo location, doc, opts
        nil
      end

    end

    class Factory
      include SharedObjects
      def make type
        registry_mutex.synchronize do
          converter = registry[type]
          if converter.nil?
            TransformStubHtml5.new
          else
            converter.new
          end
        end
      end
    end
  end
end

require_relative 'stem_adapters/stem_latexmath_mathjax_html5'
require_relative 'stem_adapters/stem_asciimath_mathml_html5'
require_relative 'stem_adapters/stem_asciimath_mathjax_html5'