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
        if !options.empty? && options.first.is_a?(Cli::Options)
          @options = options.first
        elsif options.first.is_a? Hash
          @options = Cli::Options.new(options)
        else
          @options = Cli::Options.parse!(options)
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
          infile = @options[:input_file]
          outfile = @options[:output_file]
          if infile == '-'
            # allow use of block to supply stdin, particularly useful for tests
            input = block_given? ? yield : STDIN
          else
            input = File.new(infile)
          end
          start = Time.now
          @document = Asciidoctor.load(input, @options)
          timings[:parse] = Time.now - start
          start = Time.now
          output = @document.render
          timings[:render] = Time.now - start
          if @options[:verbose]
            puts "Time to read and parse source: #{timings[:parse]}"
            puts "Time to render document: #{timings[:render]}"
            puts "Total time to read, parse and render: #{timings.reduce(0) {|sum, (_, v)| sum += v}}"
          end
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
              outfile = @document.normalize_asset_path outfile
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
