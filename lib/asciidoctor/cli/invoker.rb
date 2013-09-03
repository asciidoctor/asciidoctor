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
          profile = false
          infiles = []
          outfile = nil
          tofile = nil
          @options.map {|k, v|
            case k
            when :input_files
              infiles = v
            when :output_file
              outfile = v
            when :destination_dir
              #opts[:to_dir] = File.expand_path(v) unless v.nil?
              opts[:to_dir] = v unless v.nil?
            when :attributes
              opts[:attributes] = v.dup
            when :verbose
              profile = true if v
            when :trace
              # currently, nothing
            else
              opts[k] = v unless v.nil?
            end
          }

          if infiles.size == 1 && infiles.first == '-'
             # allows use of block to supply stdin, particularly useful for tests
             inputs = [block_given? ? yield : STDIN]
          else
             inputs = infiles.map {|infile| File.new infile}
          end

          # NOTE: if infile is stdin, default to outfile as stout
          if outfile == '-' || (infiles.size == 1 && infiles.first == '-' && outfile.to_s.empty?)
            tofile = (@out || $stdout)
          elsif !outfile.nil?
            tofile = outfile
            opts[:mkdirs] = true
          else
            tofile = nil
            # automatically calculate outfile based on infile
            opts[:in_place] = true unless opts.has_key? :to_dir
            opts[:mkdirs] = true
          end

          original_opts = opts
          inputs.each do |input|
            
            opts = Helpers.clone_options(original_opts) if inputs.size > 1
            opts[:to_file] = tofile unless tofile.nil?
            opts[:monitor] = {} if profile

            @documents ||= []
            @documents.push Asciidoctor.render(input, opts)

            if profile
              monitor = opts[:monitor]
              err = (@err || $stderr)
              err.puts "Input file: #{input.respond_to?(:path) ? input.path : '-'}"
              err.puts "  Time to read and parse source: #{'%05.5f' % monitor[:parse]}"
              err.puts "  Time to render document: #{monitor.has_key?(:render) ? '%05.5f' % monitor[:render] : 'n/a'}"
              err.puts "  Total time to read, parse and render: #{'%05.5f' % (monitor[:load_render] || monitor[:parse])}"
            end
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

      def document
        @documents.size > 0 ? @documents.first : nil
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
