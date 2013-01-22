require 'optparse'

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
          opts.banner = <<-EOS
Usage: asciidoctor [OPTION]... [FILE]
Translate the AsciiDoc source FILE into the backend output format (e.g., HTML 5, DocBook 4.5, etc.)
By default, the output is written to a file with the basename of the source file and the appropriate extension.
Example: asciidoctor -b html5 source.asciidoc

          EOS

          opts.on('-v', '--verbose', 'enable verbose mode (default: false)') do |verbose|
            self[:verbose] = true
          end
          opts.on('-b', '--backend [BACKEND]', ['html5', 'docbook45'], 'set output format (i.e., backend): [html5, docbook45] (default: html5)') do |backend|
            self[:attributes]['backend'] = backend
          end
          opts.on('-d', '--doctype [DOCTYPE]', ['article', 'book'],
                  'document type to use when rendering output: [article, book] (default: article)') do |doc_type|
            self[:attributes]['doctype'] = doc_type
          end
          opts.on('-o', '--output-file FILE', 'output file (default: based on input file path); use - to output to STDOUT') do |output_file|
            self[:output_file] = output_file
          end
          opts.on('--safe',
                  'set safe mode to safe (default: secure)',
                  'enables include macros, but restricts access to ancestor paths of source file',
                  'provided for compatibility with the asciidoc command') do
            self[:safe] = Asciidoctor::SafeMode::SAFE
          end
          opts.on('-S', '--safe-mode [SAFE_MODE]', ['unsafe', 'safe', 'secure'],
                  'set safe mode level explicitly: [unsafe, safe, secure] (default: secure)',
                  'disables potentially dangerous macros in source files, such as include::[]') do |safe_mode|
            self[:safe] = Asciidoctor::SafeMode.const_get(safe_mode.upcase)
          end
          opts.on('-s', '--no-header-footer', 'suppress output of header and footer (default: false)') do
            self[:header_footer] = false
          end
          opts.on('-e', '--eruby [ERUBY]', ['erb', 'erubis'],
                  'specify eRuby implementation to render built-in templates: [erb, erubis] (default: erb)') do |eruby|
            self[:eruby] = eruby
          end
          opts.on('-C', '--compact', 'compact the output by removing blank lines (default: false)') do
            self[:compact] = true
          end
          opts.on('-a', '--attribute key1=value,key2=value2,...', Array,
                  'a list of attributes, in the form key or key=value pair, to set on the document',
                  'these attributes take precedence over attributes defined in the source file') do |attribs|
            attribs.each do |attrib|
              tokens = attrib.split('=')
              self[:attributes][tokens[0]] = tokens[1] || 1
            end
          end
          opts.on('-T', '--template-dir DIR', 'directory containing custom render templates the override the built-in set') do |template_dir|
            self[:template_dir] = template_dir
          end
          opts.on('-B', '--base-dir DIR', 'base directory containing the document and resources (default: directory of source file)') do |base_dir|
            self[:base_dir] = base_dir
          end
          opts.on('-D', '--destination-dir DIR', 'destination output directory (default: directory of source file)') do |dest_dir|
            self[:destination_dir] = dest_dir
          end
          opts.on('--trace', 'include backtrace information on errors (default: false)') do |trace|
            self[:trace] = true
          end

          opts.on_tail('-h', '--help', 'show this message') do
            $stdout.puts opts
            return 0
            #exit
          end

          opts.on_tail('-V', '--version', 'display the version') do
            $stdout.puts "Asciidoctor #{Asciidoctor::VERSION} [http://asciidoctor.org]"
            return 0
            #exit
          end
        end

        begin
          opts.parse!(args)
          if args.size > 1
            $stderr.puts 'asciidoctor: FAILED: too many arguments'
            return 1
          end

          self[:input_file] = args.first
          if self[:input_file].nil? || self[:input_file].empty?
            $stdout.puts opts
            return 0
            #exit
          # should we be doing this check in the options parser?
          elsif self[:input_file] != '-' && !File.exist?(self[:input_file])
            $stderr.puts "asciidoctor: FAILED: input file #{self[:input_file]} missing"
            return 1
            #exit
          end
        rescue OptionParser::InvalidOption, OptionParser::MissingArgument
          $stderr.puts $!.to_s
          $stdout.puts opts
          return 1
          #exit
        end
        self
      end # parse()

    end
  end
end
