require 'asciidoctor/cli/options'
require 'asciidoctor/document'

module Asciidoctor
  module Cli
    # Public Invocation class for starting Asciidoctor via CLI
    class Invoker
      attr_reader :options

      def initialize(*options)
        options = options.flatten
        if (!options.empty?) && (options.first === Asciidoctor::Cli::Options)
          @options = options.first
        elsif options.first.is_a? Hash
          @options = Asciidoctor::Cli::Options.new(options)
        else
          @options = Asciidoctor::Cli::Options.parse!(options)
        end
      end

      def invoke!
        data = File.new(@options[:input_file]).readlines
        Asciidoctor::Document.new(data, @options).render
      end
    end
  end
end
