require 'optparse'
require 'asciidoctor/version'

module Asciidoctor
  module Cli

    # Public: List of options that can be specified on the command line
    class Options

      attr_accessor :input_file
      attr_accessor :output_file
      attr_accessor :suppress_header_footer
      attr_accessor :template_directory
      attr_accessor :doctype
      attr_accessor :help
      attr_accessor :verbose
      attr_accessor :attributes
      attr_accessor :backend

      def initialize()
        @input_file = nil
        @output_file = nil
        @suppress_header_footer = false
        @template_directory = nil
        @doctype = :article
        @verbose = false
        @attributes = {}
        @backend = :html5
      end

      def self.parse!(args)
        Options.new.parse! args
      end

      def parse!(args)
        opts = OptionParser.new do |opts|
          opts.banner = "Usage: asciidoctor [options] input_file"

          opts.on('-v', '--verbose', 'Enable verbose mode') do |verbose|
            self.verbose = true
          end
          opts.on('-d', '--doctype [DOCTYPE]', [:article, :book, :manpage],
                  'Document type to be used when rendering docbook: article, book, manpage. Default is article') do |doc_type|
            self.doctype = doc_type
            self.backend = :docbook
          end
          opts.on('-o', '--output-file FILE', 'Output file') do |output_file|
            self.output_file = output_file
          end
          opts.on('-s', '--no-headers-footer', 'Suppress the output of headers and footers') do |suppress_header_footer|
            self.suppress_header_footer = true
          end
          opts.on('-a', '--attribute key1=value,key2=value,keyN=value', Array,
                  'A list of attributes, key value pair separated by =, to override in the document') do |attribs|
            attribs.each do |attrib|
              tokens = attrib.split("=")
              @attributes[tokens[0].to_sym] = tokens[1]
            end
          end
          opts.on('-t', '--template-dir DIR', 'Directory containing a non built in template to be used') do |template_dir|
            self.template_directory = template_dir
          end

          opts.separator ''
          opts.separator "Common options:"

          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end

          opts.on_tail("--version", "Display the version") do
            puts "Asciidoctor: #{Asciidoctor::VERSION}"
            puts "https://https://github.com/erebor/asciidoctor/"
            exit
          end
        end

        begin
          opts.parse!(args)
          self.input_file = args[0]
          if self.input_file.nil? or self.input_file.empty?
            puts "Missing input file"
            puts opts
            exit
          end
        rescue OptionParser::InvalidOption, OptionParser::MissingArgument
          puts $!.to_s
          puts opts
          exit
        end
        self
      end # parse()

    end
  end
end
