# encoding: UTF-8
module Asciidoctor
  module Cli
    FS = '/'
    RS = '\\'

    # Public: List of options that can be specified on the command line
    class Options < ::Hash

      def initialize(options = {})
        self[:attributes] = options[:attributes] || {}
        self[:input_files] = options[:input_files] || nil
        self[:output_file] = options[:output_file] || nil
        self[:safe] = options[:safe] || SafeMode::UNSAFE
        self[:header_footer] = options[:header_footer] || true
        self[:template_dirs] = options[:template_dirs] || nil
        self[:template_engine] = options[:template_engine] || nil
        if options[:doctype]
          self[:attributes]['doctype'] = options[:doctype]
        end
        if options[:backend]
          self[:attributes]['backend'] = options[:backend]
        end
        self[:eruby] = options[:eruby] || nil
        self[:verbose] = options[:verbose] || 1
        self[:load_paths] = options[:load_paths] || nil
        self[:requires] = options[:requires] || nil
        self[:base_dir] = options[:base_dir]
        self[:source_dir] = options[:source_dir] || nil
        self[:destination_dir] = options[:destination_dir] || nil
        self[:failure_level] = ::Logger::Severity::FATAL
        self[:trace] = false
        self[:timings] = false
      end

      def self.parse!(args)
        Options.new.parse! args
      end

      def parse!(args)
        opts_parser = ::OptionParser.new do |opts|
          opts.banner = <<-EOS
Usage: asciidoctor [OPTION]... FILE...
Translate the AsciiDoc source FILE or FILE(s) into the backend output format (e.g., HTML 5, DocBook 4.5, etc.)
By default, the output is written to a file with the basename of the source file and the appropriate extension.
Example: asciidoctor -b html5 source.asciidoc

          EOS

          opts.on('-b', '--backend BACKEND', 'set output format backend: [html5, xhtml5, docbook5, docbook45, manpage] (default: html5)',
                  'additional backends are supported via extensions (e.g., pdf, latex)') do |backend|
            self[:attributes]['backend'] = backend
          end
          opts.on('-d', '--doctype DOCTYPE', ['article', 'book', 'manpage', 'inline'],
                  'document type to use when converting document: [article, book, manpage, inline] (default: article)') do |doc_type|
            self[:attributes]['doctype'] = doc_type
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
          opts.on('-s', '--no-header-footer', 'suppress output of header and footer (default: false)') do
            self[:header_footer] = false
          end
          opts.on('-n', '--section-numbers', 'auto-number section titles in the HTML backend; disabled by default') do
            self[:attributes]['sectnums'] = ''
          end
          opts.on('-e', '--eruby ERUBY', ['erb', 'erubis'],
                  'specify eRuby implementation to use when rendering custom ERB templates: [erb, erubis] (default: erb)') do |eruby|
            self[:eruby] = eruby
          end
          opts.on('-a', '--attribute key[=value]', 'a document attribute to set in the form of key, key! or key=value pair',
                  'unless @ is appended to the value, this attributes takes precedence over attributes',
                  'defined in the source document') do |attr|
            key, val = attr.split '=', 2
            val = val ? (FORCE_ENCODING ? (val.force_encoding ::Encoding::UTF_8) : val) : ''
            # move leading ! to end for internal processing
            #if !val && key.start_with?('!')
            #  key = %(#{key[1..-1]}!)
            #end
            self[:attributes][key] = val
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
          opts.on('--failure-level LEVEL', %w(warning WARNING error ERROR), 'set minimum logging level that triggers a non-zero exit code: [WARN, ERROR] (default: FATAL)') do |level|
            level = 'WARN' if (level = level.upcase) == 'WARNING'
            self[:failure_level] = ::Logger::Severity.const_get level
          end
          opts.on('-q', '--quiet', 'suppress warnings (default: false)') do |verbose|
            self[:verbose] = 0
          end
          opts.on('--trace', 'include backtrace information on errors (default: false)') do |trace|
            self[:trace] = true
          end
          opts.on('-v', '--verbose', 'enable verbose mode (default: false)') do |verbose|
            self[:verbose] = 2
          end
          opts.on('-t', '--timings', 'enable timings mode (default: false)') do |timing|
            self[:timings] = true
          end

          opts.on_tail('-h', '--help [TOPIC]', 'print the help message',
              'show the command usage if TOPIC is not specified (or not recognized)',
              'dump the Asciidoctor man page (in troff/groff format) if TOPIC is manpage') do |topic|
            if topic == 'manpage'
              if (manpage_path = ENV['ASCIIDOCTOR_MANPAGE_PATH'])
                if ::File.exist? manpage_path
                  if manpage_path.end_with? '.gz'
                    require 'zlib' unless defined? ::Zlib::GzipReader
                    $stdout.puts ::Zlib::GzipReader.open(manpage_path) {|gz| gz.read }
                  else
                    $stdout.puts ::IO.read manpage_path
                  end
                else
                  $stderr.puts %(asciidoctor: FAILED: manual page not found: #{manpage_path})
                  return 1
                end
              elsif ::File.exist?(manpage_path = (::File.join ::Asciidoctor::ROOT_PATH, 'man', 'asciidoctor.1'))
                $stdout.puts ::IO.read manpage_path
              else
                require 'open3' unless defined? ::Open3.popen3
                manpage_path = ::Open3.popen3('man -w asciidoctor') {|_, out| out.read }.chop rescue ''
                if manpage_path.empty?
                  $stderr.puts 'asciidoctor: FAILED: manual page not found; try `man asciidoctor`'
                  return 1
                elsif manpage_path.end_with? '.gz'
                  require 'zlib' unless defined? ::Zlib::GzipReader
                  $stdout.puts ::Zlib::GzipReader.open(manpage_path) {|gz| gz.read }
                else
                  $stdout.puts ::IO.read manpage_path
                end
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

        infiles = []
        opts_parser.parse! args

        if args.empty?
          if self[:verbose] == 2
            return print_version $stdout
          else
            $stderr.puts opts_parser
            return 1
          end
        end

        # shave off the file to process so that options errors appear correctly
        if args.size == 1 && args[0] == '-'
          infiles << args.pop
        elsif
          args.each do |file|
            if file == '-' || (file.start_with? '-')
              # warn, but don't panic; we may have enough to proceed, so we won't force a failure
              $stderr.puts %(asciidoctor: WARNING: extra arguments detected (unparsed arguments: '#{args.join "', '"}') or incorrect usage of stdin)
            else
              if ::File.file? file
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

        self.delete(:attributes) if self[:attributes].empty?

        if self[:template_dirs]
          begin
            require 'tilt' unless defined? ::Tilt::VERSION
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
          (self[:load_paths] = load_paths.uniq).reverse_each do |path|
            $:.unshift ::File.expand_path(path)
          end
        end

        if (requires = self[:requires])
          (self[:requires] = requires.uniq).each do |path|
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
      end

      def print_version os = $stdout
        os.puts %(Asciidoctor #{::Asciidoctor::VERSION} [https://asciidoctor.org])
        if ::RUBY_MIN_VERSION_1_9
          encoding_info = { 'lc' => 'locale', 'fs' => 'filesystem', 'in' => 'internal', 'ex' => 'external' }.map do |k, v|
            %(#{k}:#{v == 'internal' ? (::File.open(__FILE__) {|f| f.getc }).encoding : (::Encoding.find v)})
          end
          os.puts %(Runtime Environment (#{::RUBY_DESCRIPTION}) (#{encoding_info.join ' '}))
        else
          os.puts %(Runtime Environment (#{::RUBY_DESCRIPTION}))
        end
        0
      end
    end
  end
end
