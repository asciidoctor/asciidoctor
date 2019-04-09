# frozen_string_literal: true
module Asciidoctor
  module Cli
    FS = ?/
    RS = ?\\

    # Public: List of options that can be specified on the command line
    class Options < ::Hash

      def initialize(options = {})
        self[:attributes] = options[:attributes] || {}
        self[:input_files] = options[:input_files]
        self[:output_file] = options[:output_file]
        self[:safe] = options[:safe] || SafeMode::UNSAFE
        self[:standalone] = options.fetch :standalone, true
        self[:template_dirs] = options[:template_dirs]
        self[:template_engine] = options[:template_engine]
        self[:attributes]['doctype'] = options[:doctype] if options[:doctype]
        self[:attributes]['backend'] = options[:backend] if options[:backend]
        self[:eruby] = options[:eruby]
        self[:verbose] = options.fetch :verbose, 1
        self[:warnings] = options.fetch :warnings, false
        self[:load_paths] = options[:load_paths]
        self[:requires] = options[:requires]
        self[:base_dir] = options[:base_dir]
        self[:source_dir] = options[:source_dir]
        self[:destination_dir] = options[:destination_dir]
        self[:failure_level] = ::Logger::Severity::FATAL
        self[:trace] = false
        self[:timings] = false
      end

      def self.parse!(args)
        Options.new.parse! args
      end

      def parse!(args)
        opts_parser = ::OptionParser.new do |opts|
          # NOTE don't use squiggly heredoc to maintain compatibility with Ruby < 2.3
          opts.banner = <<-'EOS'.gsub '          ', ''
          Usage: asciidoctor [OPTION]... FILE...
          Translate the AsciiDoc source FILE or FILE(s) into the backend output format (e.g., HTML 5, DocBook 5, etc.)
          By default, the output is written to a file with the basename of the source file and the appropriate extension.
          Example: asciidoctor -b html5 source.asciidoc

          EOS

          opts.on('-b', '--backend BACKEND', 'set output format backend: [html5, xhtml5, docbook5, manpage] (default: html5)',
                  'additional backends are supported via extensions (e.g., pdf, latex)') do |backend|
            self[:attributes]['backend'] = backend
          end
          opts.on('-d', '--doctype DOCTYPE', ['article', 'book', 'manpage', 'inline'],
                  'document type to use when converting document: [article, book, manpage, inline] (default: article)') do |doc_type|
            self[:attributes]['doctype'] = doc_type
          end
          opts.on('-e', '--embedded', 'suppress enclosing document structure and output an embedded document (default: false)') do
            self[:standalone] = false
          end
          opts.on('-o', '--out-file FILE', 'output file (default: based on path of input file); use - to output to STDOUT') do |output_file|
            self[:output_file] = output_file
          end
          opts.on('--safe',
                  'set safe mode level to safe (default: unsafe)',
                  'enables include directives, but prevents access to ancestor paths of source file',
                  'provided for compatibility with the asciidoc command') do
            self[:safe] = SafeMode::SAFE
          end
          opts.on('-S', '--safe-mode SAFE_MODE', (safe_mode_names = SafeMode.names),
                  %(set safe mode level explicitly: [#{safe_mode_names.join ', '}] (default: unsafe)),
                  'disables potentially dangerous macros in source files, such as include::[]') do |name|
            self[:safe] = SafeMode.value_for_name name
          end
          opts.on('-s', '--no-header-footer', 'suppress enclosing document structure and output an embedded document (default: false)') do
            self[:standalone] = false
          end
          opts.on('-n', '--section-numbers', 'auto-number section titles in the HTML backend; disabled by default') do
            self[:attributes]['sectnums'] = ''
          end
          opts.on('--eruby ERUBY', ['erb', 'erubis'],
                  'specify eRuby implementation to use when rendering custom ERB templates: [erb, erubis] (default: erb)') do |eruby|
            self[:eruby] = eruby
          end
          opts.on('-a', '--attribute name[=value]', 'a document attribute to set in the form of name, name!, or name=value pair',
                  'this attribute takes precedence over the same attribute defined in the source document',
                  'unless either the name or value ends in @ (i.e., name@=value or name=value@)') do |attr|
            next if (attr = attr.rstrip).empty? || attr == '='
            attr = attr.encode UTF_8 unless attr.encoding == UTF_8
            name, _, val = attr.partition '='
            self[:attributes][name] = val
          end
          opts.on('-T', '--template-dir DIR', 'a directory containing custom converter templates that override the built-in converter (requires tilt gem)',
                  'may be specified multiple times') do |template_dir|
            if self[:template_dirs].nil?
              self[:template_dirs] = [template_dir]
            elsif ::Array === self[:template_dirs]
              self[:template_dirs] << template_dir
            else
              self[:template_dirs] = [self[:template_dirs], template_dir]
            end
          end
          opts.on('-E', '--template-engine NAME', 'template engine to use for the custom converter templates (loads gem on demand)') do |template_engine|
            self[:template_engine] = template_engine
          end
          opts.on('-B', '--base-dir DIR', 'base directory containing the document and resources (default: directory of source file)') do |base_dir|
            self[:base_dir] = base_dir
          end
          opts.on('-R', '--source-dir DIR', 'source root directory (used for calculating path in destination directory)') do |src_dir|
            self[:source_dir] = src_dir
          end
          opts.on('-D', '--destination-dir DIR', 'destination output directory (default: directory of source file)') do |dest_dir|
            self[:destination_dir] = dest_dir
          end
          opts.on('-IDIRECTORY', '--load-path DIRECTORY', 'add a directory to the $LOAD_PATH',
              'may be specified more than once') do |path|
            (self[:load_paths] ||= []).concat(path.split ::File::PATH_SEPARATOR)
          end
          opts.on('-rLIBRARY', '--require LIBRARY', 'require the specified library before executing the processor (using require)',
              'may be specified more than once') do |path|
            (self[:requires] ||= []).concat(path.split ',')
          end
          opts.on('--failure-level LEVEL', %w(warning WARNING error ERROR info INFO), 'set minimum logging level that triggers non-zero exit code: [WARN, ERROR, INFO] (default: FATAL)') do |level|
            level = 'WARN' if (level = level.upcase) == 'WARNING'
            self[:failure_level] = ::Logger::Severity.const_get level, false
          end
          opts.on('-q', '--quiet', 'silence application log messages and script warnings (default: false)') do |verbose|
            self[:verbose] = 0
          end
          opts.on('--trace', 'include backtrace information when reporting errors (default: false)') do |trace|
            self[:trace] = true
          end
          opts.on('-v', '--verbose', 'enable verbose mode (default: false)') do |verbose|
            self[:verbose] = 2
          end
          opts.on('-w', '--warnings', 'turn on script warnings (default: false)') do |warnings|
            self[:warnings] = true
          end
          opts.on('-t', '--timings', 'print timings report (default: false)') do |timing|
            self[:timings] = true
          end
          opts.on_tail('-h', '--help [TOPIC]', 'print a help message',
              'show this usage if TOPIC is not specified or recognized',
              'show an overview of the AsciiDoc syntax if TOPIC is syntax',
              'dump the Asciidoctor man page (in troff/groff format) if TOPIC is manpage') do |topic|
            case topic
            # use `asciidoctor -h manpage | man -l -` to view with man pager
            when 'manpage'
              if (manpage_path = ::ENV['ASCIIDOCTOR_MANPAGE_PATH'])
                if ::File.exist? manpage_path
                  if manpage_path.end_with? '.gz'
                    require 'zlib' unless defined? ::Zlib::GzipReader
                    $stdout.puts ::Zlib::GzipReader.open(manpage_path) {|gz| gz.read }
                  else
                    $stdout.puts ::File.read manpage_path
                  end
                else
                  $stderr.puts %(asciidoctor: FAILED: manual page not found: #{manpage_path})
                  return 1
                end
              # Ruby 2.3 requires the extra brackets around the ::File.join method call
              elsif ::File.exist? (manpage_path = (::File.join ROOT_DIR, 'man', 'asciidoctor.1'))
                $stdout.puts ::File.read manpage_path
              else
                manpage_path = `man -w asciidoctor`.chop rescue ''
                if manpage_path.empty?
                  $stderr.puts 'asciidoctor: FAILED: manual page not found; try `man asciidoctor`'
                  return 1
                elsif manpage_path.end_with? '.gz'
                  require 'zlib' unless defined? ::Zlib::GzipReader
                  $stdout.puts ::Zlib::GzipReader.open(manpage_path) {|gz| gz.read }
                else
                  $stdout.puts ::File.read manpage_path
                end
              end
            when 'syntax'
              # Ruby 2.3 requires the extra brackets around the ::File.join method call
              if ::File.exist? (syntax_path = (::File.join ROOT_DIR, 'data', 'reference', 'syntax.adoc'))
                $stdout.puts ::File.read syntax_path
              else
                $stderr.puts 'asciidoctor: FAILED: syntax page not found; visit https://asciidoctor.org/docs'
                return 1
              end
            else
              $stdout.puts opts
            end
            return 0
          end
          opts.on_tail('-V', '--version', 'display the version and runtime environment (or -v if no other flags or arguments)') do
            return print_version $stdout
          end
        end

        old_verbose, $VERBOSE = $VERBOSE, (args.include? '-w')
        opts_parser.parse! args

        if args.empty?
          if self[:verbose] == 2 # -v flag was specified
            return print_version $stdout
          else
            $stderr.puts opts_parser
            return 1
          end
        end

        infiles = []
        # shave off the file to process so that options errors appear correctly
        if args.size == 1 && args[0] == '-'
          infiles << args.pop
        elsif
          args.each do |file|
            if file.start_with? '-'
              # warn, but don't panic; we may have enough to proceed, so we won't force a failure
              $stderr.puts %(asciidoctor: WARNING: extra arguments detected (unparsed arguments: '#{args.join "', '"}') or incorrect usage of stdin)
            elsif ::File.file? file
              infiles << file
            # NOTE only attempt to glob if file is not found
            else
              # Tilt backslashes in Windows paths the Ruby-friendly way
              if ::File::ALT_SEPARATOR == RS && (file.include? RS)
                file = file.tr RS, FS
              end
              if (matches = ::Dir.glob file).empty?
                # NOTE if no matches, assume it's just a missing file and proceed
                infiles << file
              else
                infiles.concat matches
              end
            end
          end
        end

        infiles.reject {|file| file == '-' }.each do |file|
          begin
            fstat = ::File.stat file
            if fstat.file? || fstat.pipe?
              unless fstat.readable?
                $stderr.puts %(asciidoctor: FAILED: input file #{file} is not readable)
                return 1
              end
            else
              $stderr.puts %(asciidoctor: FAILED: input path #{file} is a #{fstat.ftype}, not a file)
              return 1
            end
          rescue ::Errno::ENOENT
            $stderr.puts %(asciidoctor: FAILED: input file #{file} is missing)
            return 1
          end
        end

        self[:input_files] = infiles

        self.delete :attributes if self[:attributes].empty?

        if self[:template_dirs]
          begin
            require 'tilt' unless defined? ::Tilt.new
          rescue ::LoadError
            raise $! if self[:trace]
            $stderr.puts 'asciidoctor: FAILED: \'tilt\' could not be loaded'
            $stderr.puts '  You must have the tilt gem installed (gem install tilt) to use custom backend templates'
            $stderr.puts '  Use --trace for backtrace'
            return 1
          rescue ::SystemExit
            # not permitted here
          end
        end

        if (load_paths = self[:load_paths])
          load_paths.uniq!
          load_paths.reverse_each {|path| $:.unshift ::File.expand_path path }
        end

        if (requires = self[:requires])
          requires.uniq!
          requires.each do |path|
            begin
              require path
            rescue ::LoadError
              raise $! if self[:trace]
              $stderr.puts %(asciidoctor: FAILED: '#{path}' could not be loaded)
              $stderr.puts '  Use --trace for backtrace'
              return 1
            rescue ::SystemExit
              # not permitted here
            end
          end
        end

        self
      rescue ::OptionParser::MissingArgument
        $stderr.puts %(asciidoctor: option #{$!.message})
        $stdout.puts opts_parser
        return 1
      rescue ::OptionParser::InvalidOption, ::OptionParser::InvalidArgument
        $stderr.puts %(asciidoctor: #{$!.message})
        $stdout.puts opts_parser
        return 1
      ensure
        $VERBOSE = old_verbose
      end

      def print_version os = $stdout
        os.puts %(Asciidoctor #{::Asciidoctor::VERSION} [https://asciidoctor.org])
        encoding_info = { 'lc' => 'locale', 'fs' => 'filesystem', 'in' => 'internal', 'ex' => 'external' }.map do |k, v|
          %(#{k}:#{v == 'internal' ? (::File.open(__FILE__) {|f| f.getc.encoding }) : (::Encoding.find v)})
        end
        os.puts %(Runtime Environment (#{::RUBY_DESCRIPTION}) (#{encoding_info.join ' '}))
        0
      end
    end
  end
end
