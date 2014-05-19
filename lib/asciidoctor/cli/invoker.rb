module Asciidoctor
  module Cli
    # Public Invocation class for starting Asciidoctor via CLI
    class Invoker
      attr_reader :options
      attr_reader :documents
      attr_reader :code

      def initialize(*options)
        @documents = []
        @out = nil
        @err = nil
        @code = 0
        options = options.flatten
        if (first_option = options[0]).is_a?(Cli::Options)
          @options = first_option
        elsif first_option.is_a?(::Hash)
          @options = Cli::Options.new(options)
        else
          if (result = Cli::Options.parse! options).is_a? ::Integer
            @code = result
            @options = nil
          else
            @options = result
          end
        end
      end

      def invoke!
        old_verbose = -1
        return unless @options

        old_verbose = $VERBOSE
        case @options[:verbose]
        when 0
          $VERBOSE = nil
        when 1
          $VERBOSE = false
        when 2
          $VERBOSE = true
        end

        opts = {}
        infiles = []
        outfile = nil
        tofile = nil
        @options.map do |key, val|
          case key
          when :input_files
            infiles = val
          when :output_file
            outfile = val
          when :destination_dir
            opts[:to_dir] = val if val
          when :attributes
            # NOTE processor will dup attributes internally
            opts[:attributes] = val
          when :trace
            # currently, nothing
          else
            opts[key] = val unless val.nil?
          end
        end

        if infiles.size == 1 && infiles[0] == '-'
          # allows use of block to supply stdin, particularly useful for tests
          inputs = [block_given? ? yield : STDIN]
        else
          inputs = infiles.map {|infile| ::File.new infile, 'r'}
        end

        # NOTE if infile is stdin, default to outfile as stout
        if outfile == '-' || (!outfile && infiles.size == 1 && infiles[0] == '-')
          tofile = (@out || $stdout)
        elsif outfile
          tofile = outfile
          opts[:mkdirs] = true
        else
          # automatically calculate outfile based on infile unless to_dir is set
          tofile = nil
          opts[:mkdirs] = true
        end

        show_timings = @options[:timings]
        inputs.each do |input|
          # NOTE processor will dup options and attributes internally
          input_opts = tofile.nil? ? opts : opts.merge(:to_file => tofile)
          if show_timings
            timings = Timings.new
            @documents << ::Asciidoctor.convert(input, input_opts.merge(:timings => timings))
            timings.print_report((@err || $stderr), ((input.respond_to? :path) ? input.path : '-'))
          else
            @documents << ::Asciidoctor.convert(input, input_opts)
          end
        end
      rescue ::Exception => e
        if ::SignalException === e
          @code = e.signo
          # add extra endline if Ctrl+C is used
          (@err || $stderr).puts if ::Interrupt === e
        else
          @code = (e.respond_to? :status) ? e.status : 1
          if @options[:trace]
            raise e
          else
            err = (@err || $stderr)
            err.print %(#{e.class}: ) if ::RuntimeError === e
            err.puts e.message
            err.puts '  Use --trace for backtrace'
          end
        end
        nil
      ensure
        $VERBOSE = old_verbose unless old_verbose == -1
      end

      def document
        @documents[0]
      end

      def redirect_streams(out, err = nil)
        @out = out
        @err = err
      end

      def read_output
        @out ? @out.string : ''
      end

      def read_error
        @err ? @err.string : ''
      end

      def reset_streams
        @out = nil
        @err = nil
      end
    end
  end
end
