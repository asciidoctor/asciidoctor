module Asciidoctor
  module Cli
    # Public Invocation class for starting Asciidoctor via CLI
    class Invoker
      attr_reader :options
      attr_reader :document
      attr_reader :code
      attr_reader :timings

      def initialize(*options)
        @document = nil
        @out = nil
        @err = nil
        @code = 0
        @timings = {}
        options = options.flatten
        if (!options.empty?) && (options.first === Asciidoctor::Cli::Options)
          @options = options.first
        elsif options.first.is_a? Hash
          @options = Asciidoctor::Cli::Options.new(options)
        else
          @options = Asciidoctor::Cli::Options.parse!(options)
          # hmmm
          if @options.is_a?(Integer)
            @code = @options
            @options = nil
          end
        end
      end

      def invoke!
        return if @options.nil?

        begin
          @timings = {}
          attrs = @options[:attributes]
          infile = @options[:input_file]
          # these three attributes just seem unsafe and pointless, so let's hold off on setting them
          #attrs['asciidoctor-file'] = File.expand_path($PROGRAM_NAME)
          #attrs['asciidoctor-dir'] = File.expand_path(File.join(File.dirname(__FILE__), '../../..'))
          #attrs['asciidoctor-args'] = ARGV * ' '
          start = Time.now
          if infile == '-'
            # allow use of block to supply stdin, particularly useful for tests
            if block_given?
              content = yield
              if content.is_a?(String)
                lines = content.lines.entries
              elsif content.is_a?(IO)
                lines = content.readlines
              else
                lines = content
              end
            else
              lines = STDIN.readlines
            end
          else
            infile_mtime = File.mtime(infile)
            # hold off on setting infile and indir until we get a better sense of their purpose
            attrs['docfile'] = File.expand_path(infile)
            attrs['docdir'] = File.expand_path(File.dirname(infile))
            attrs['docname'] = File.basename(infile, File.extname(infile))
            attrs['docdate'] = infile_mtime.strftime('%Y-%m-%d')
            attrs['doctime'] = infile_mtime.strftime('%H:%M:%S %Z')
            attrs['docdatetime'] = [attrs['docdate'], attrs['doctime']] * ' '
            lines = File.new(infile).readlines
          end
          timings[:read] = Time.now - start
          start = Time.now
          @document = Asciidoctor::Document.new(lines, @options)
          timings[:parse] = Time.now - start
          start = Time.now
          output = @document.render
          timings[:render] = Time.now - start
          if @options[:verbose]
            puts "Time to read source file: #{timings[:render]}"
            puts "Time to parse source: #{timings[:parse]}"
            puts "Time to render document: #{timings[:render]}"
            puts "Total time to read, parse and render: #{timings.reduce(0) {|sum, (k, v)| sum += v}}"
          end
          outfile = @options[:output_file]
          if outfile == '/dev/null'
            # output nothing
          elsif outfile == '-' || (infile == '-' && (outfile.nil? || outfile.empty?))
            (@out || $stdout).puts output
          else
            if outfile.nil? || outfile.empty?
              if @options[:destination_dir]
                destination_dir = File.expand_path(@options[:destination_dir])
              else
                destination_dir = @document.base_dir
              end
              outfile = File.join(destination_dir, "#{@document.attributes['docname']}#{@document.attributes['outfilesuffix']}")
            else
              outfile = File.expand_path outfile
            end

            # this assignment is primarily for testing or other post analysis
            @document.attributes['outfile'] = outfile
            @document.attributes['outdir'] = File.dirname(outfile)
            File.open(outfile, 'w') {|file| file.write output }
          end
        rescue Exception => e
          raise e if @options[:trace] || SystemExit === e
          err = (@err || $stderr)
          err.print "#{e.class}: " if e.class != RuntimeError
          err.puts e.message
          err.puts '  Use --trace for backtrace'
          @code = 1
        end
      end

      def redirect_streams(out, err = nil)
        @out = out
        @err = err
      end

      def read_output
        !@out.nil? ? @out.string : ''
      end

      def read_error
        !@err.nil? ? @err.string : ''
      end

      def reset_streams
        @out = nil
        @err = nil
      end
    end
  end
end
