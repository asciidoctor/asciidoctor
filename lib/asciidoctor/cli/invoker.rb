module Asciidoctor
  module Cli
    # Public Invocation class for starting Asciidoctor via CLI
    class Invoker
      attr_reader :options
      attr_reader :document
      attr_reader :code

      def initialize(*options)
        @document = nil
        @out = nil
        @err = nil
        @code = 0
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
          opts = {}
          monitor = {}
          infile = nil
          outfile = nil
          @options.map {|k, v|
            case k
            when :input_file
              infile = v
            when :output_file
              outfile = v
            when :destination_dir
              #opts[:to_dir] = File.expand_path(v) unless v.nil?
              opts[:to_dir] = v unless v.nil?
            when :attributes
              opts[:attributes] = v.dup
            when :verbose
              opts[:monitor] = monitor if v
            when :trace
              # currently, nothing
            else
              opts[k] = v unless v.nil?
            end
          }

          if infile == '-'
            # allow use of block to supply stdin, particularly useful for tests
            input = block_given? ? yield : STDIN
          else
            input = File.new(infile)
          end

          if outfile == '-' || (infile == '-' && (outfile.to_s.empty? || outfile != '/dev/null'))
            opts[:to_file] = (@out || $stdout)
          elsif !outfile.nil?
            opts[:to_file] = outfile
          else
            opts[:in_place] = true unless opts.has_key? :to_dir
          end

          @document = Asciidoctor.render(input, opts)

          # FIXME this should be :monitor, :profile or :timings rather than :verbose
          if @options[:verbose]
            puts "Time to read and parse source: #{'%05.5f' % monitor[:parse]}"
            puts "Time to render document: #{'%05.5f' % monitor[:render]}"
            puts "Total time to read, parse and render: #{'%05.5f' % monitor[:load_render]}"
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
