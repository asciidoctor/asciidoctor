require 'optparse'
require 'asciidoctor/version'

module Asciidoctor
  module Cli

    # Public: List of options that can be specified on the command line
    class Options < Hash

      def initialize(options = {})
        self[:input_file] = options[:input_file]
        self[:output_file] = options[:output_file]
        self[:header_footer] = options.fetch(:header_footer, true)
        self[:template_directory] = options[:template_directory]
        self[:doctype] = options[:doctype] || :article
        self[:verbose] = options.fetch(:verbose, false)
        self[:attributes] = options[:attributes] || {}
        self[:backend] = options[:backend] || :html5
        self[:base_dir] = options[:base_dir] || Dir.pwd
        self[:destination_dir] = options[:destination_dir]
      end

      def self.parse!(args)
        Options.new.parse! args
      end

      def parse!(args)
        opts = OptionParser.new do |opts|
          opts.banner = "Usage: asciidoctor [options] input_file"

          opts.on('-v', '--verbose', 'Enable verbose mode') do |verbose|
            self[:verbose] = true
          end
          opts.on('-d', '--doctype [DOCTYPE]', [:article, :book, :manpage],
                  'Document type to be used when rendering docbook: article, book, manpage. Default is article') do |doc_type|
            self[:doctype] = doc_type
            self[:backend] = :docbook
          end
          opts.on('-o', '--output-file FILE', 'Output file') do |output_file|
            self[:output_file] = output_file
          end
          opts.on('-s', '--no-headers-footer', 'Suppress the output of headers and footers') do |suppress_header_footer|
            self[:header_footer] = false
          end
          opts.on('-a', '--attribute key1=value,key2=value,keyN=value', Array,
                  'A list of attributes, key value pair separated by =, to override in the document') do |attribs|
            attribs.each do |attrib|
              tokens = attrib.split("=")
              self[:attributes][tokens[0].to_sym] = tokens[1]
            end
          end
          opts.on('-t', '--template-dir DIR', 'Directory containing a non built in template to be used') do |template_dir|
            self[:template_directory] = template_dir
          end
          opts.on('--base-dir DIR', 'Base directory containing the document and resources') do |base_dir|
            self[:base_dir] = base_dir
          end
          opts.on('-D', '--destination-dir DIR', 'Destination output directory') do |dest_dir|
            self[:destination_dir] = dest_dir
          end

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
          self[:input_file] = args[0] # TODO: this will have to change somehow if we start supporting STDIN
          if self[:input_file].nil? or self[:input_file].empty?
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
