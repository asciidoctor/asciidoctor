# encoding: UTF-8
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
        case (first_option = options[0])
        when Options
          @options = first_option
        when ::Hash
          @options = Options.new options
        else
          if ::Integer === (result = Options.parse! options)
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
        opts = {}
        infiles = []
        outfile = nil
        tofile = nil
        show_timings = false

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
          when :timings
            show_timings = val
          when :trace
            # currently, nothing
          when :verbose
            case val
            when 0
              $VERBOSE = nil
            when 1
              $VERBOSE = false
            when 2
              $VERBOSE = true
            end
          else
            opts[key] = val unless val.nil?
          end
        end

        stdin = infiles.size == 1 && infiles[0] == '-'
        # NOTE if infile is stdin, default to outfile as stout
        if outfile == '-' || (!outfile && stdin)
          tofile = @out || $stdout
        elsif outfile
          tofile = outfile
          opts[:mkdirs] = true
        else
          # automatically calculate outfile based on infile unless to_dir is set
          tofile = nil
          opts[:mkdirs] = true
        end

        if stdin
          # allows use of block to supply stdin, particularly useful for tests
          input = block_given? ? yield : STDIN
          # NOTE processor will dup options internally
          input_opts = tofile.nil? ? opts : opts.merge(:to_file => tofile)
          if show_timings
            @documents << ::Asciidoctor.convert(input, input_opts.merge(:timings => (timings = Timings.new)))
            timings.print_report((@err || $stderr), '-')
          else
            @documents << ::Asciidoctor.convert(input, input_opts)
          end
        else
          infiles.each do |infile|
            # NOTE processor will dup options internally
            input_opts = tofile.nil? ? opts : opts.merge(:to_file => tofile)
            if show_timings
              @documents << ::Asciidoctor.convert_file(infile, input_opts.merge(:timings => (timings = Timings.new)))
              timings.print_report((@err || $stderr), infile)
            else
              @documents << ::Asciidoctor.convert_file(infile, input_opts)
            end
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
            if ::RuntimeError === e
              err.puts %(#{e.message} (#{e.class}))
            else
              err.puts e.message
            end
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
