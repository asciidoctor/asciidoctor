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
        begin
          data = File.new(@options[:input_file]).readlines
          rendered_output = Asciidoctor::Document.new(data, @options).render 
          output_stream = @options[:output_file] ? File.new(@options[:output_file], 'w') : $stdout
          output_stream.puts rendered_output
        rescue Exception => e
          raise e if @options[:trace] || SystemExit === ex
          $stderr.print "#{e.class}: " if e.class != RuntimeError
          $stderr.puts e.message
          $stderr.puts '  Use --trace for backtrace'
          exit 1
        end
      end
    end
  end
end
