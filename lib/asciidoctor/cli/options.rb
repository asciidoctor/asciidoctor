module Asciidoctor
  module Cli

    # Public: List of options that can be specified on the command line
    class Options < Hash

      def initialize(options = {})
        self[:attributes] = options[:attributes] || {}
        self[:input_file] = options[:input_file] || nil
        self[:output_file] = options[:output_file] || nil
        self[:safe] = options[:safe] || nil
        self[:header_footer] = options[:header_footer] || true
        self[:template_dir] = options[:template_dir] || nil
        if options[:doctype]
          self[:attributes]['doctype'] = options[:doctype]
        end
        if options[:backend]
          self[:attributes]['backend'] = options[:backend]
        end
        self[:eruby] = options[:eruby] || nil
        self[:compact] = options[:compact] || false
        self[:verbose] = options[:verbose] || false
        self[:base_dir] = options[:base_dir] || nil
        self[:destination_dir] = options[:destination_dir] || nil
        self[:trace] = false
      end

      def self.parse!(args)
        Options.new.parse! args
      end

      def parse!(args)
        opts = OptionParser.new do |opts|
          opts.banner = 'Usage: asciidoctor [options] input_file'

          opts.on('-v', '--verbose', 'Enable verbose mode') do |verbose|
            self[:verbose] = true
          end
          opts.on('-b', '--backend [BACKEND]', ['html5', 'docbook45'], 'Backend output file format: html5, docbook45. Defaults to html5.') do |backend|
            self[:attributes]['backend'] = backend
          end
          opts.on('-d', '--doctype [DOCTYPE]', ['article', 'book'],
                  'Document type to be used when rendering the output: article or book. Defaults to article.') do |doc_type|
            self[:attributes]['doctype'] = doc_type
          end
          opts.on('-o', '--output-file FILE', 'Output file') do |output_file|
            self[:output_file] = output_file
          end
          opts.on('-S', '--safe [SAFE_MODE]', ['unsafe', 'safe', 'secure'],
                  'Set the safe model level: unsafe, safe or secure. Disables potentially dangerous macros in source files. Defaults to secure.') do |safe_mode|
            self[:safe] = Asciidoctor::SafeMode.const_get(safe_mode.upcase)
          end
          opts.on('-s', '--no-header-footer', 'Suppress the output of the header and footer') do
            self[:header_footer] = false
          end
          opts.on('-e', '--eruby [ERUBY]', ['erb', 'erubis'],
                  'Specify the eRuby implementation used to render the built-in templates. Defaults to erb.') do |eruby|
            self[:eruby] = eruby
          end
          opts.on('-C', '--compact', 'Compact the output by removing blank lines') do
            self[:compact] = true
          end
          opts.on('-a', '--attribute key1=value,key2=value,keyN=value', Array,
                  'A list of attributes, key value pair separated by =, to override in the document') do |attribs|
            attribs.each do |attrib|
              tokens = attrib.split("=")
              self[:attributes][tokens[0]] = tokens[1] || 1
            end
          end
          opts.on('-t', '--template-dir DIR', 'Directory containing the custom templates to be used for rendering.') do |template_dir|
            self[:template_dir] = template_dir
          end
          opts.on('--base-dir DIR', 'Base directory containing the document and resources. Defaults to source file directory.') do |base_dir|
            self[:base_dir] = base_dir
          end
          opts.on('-D', '--destination-dir DIR', 'Destination output directory') do |dest_dir|
            self[:destination_dir] = dest_dir
          end
          opts.on('--trace', 'Include backtrace information on errors') do |trace|
            self[:trace] = true
          end

          opts.on_tail('-h', '--help', 'Show this message') do
            puts opts
            exit
          end

          opts.on_tail('--version', 'Display the version') do
            puts "Asciidoctor #{Asciidoctor::VERSION} [http://asciidoctor.org]"
            exit
          end
        end

        begin
          opts.parse!(args)
          self[:input_file] = args[0]
          if self[:input_file].nil? or self[:input_file].empty?
            puts "Missing input file"
            puts opts
            exit
          end
          # TODO: support stdin, probably using ARGF and ARGF.to_io
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
