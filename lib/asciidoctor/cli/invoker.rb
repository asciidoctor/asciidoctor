# encoding: UTF-8
module Asciidoctor
  module Cli
    # Public Invocation class for starting Asciidoctor via CLI
    class Invoker

      attr_reader :options
      attr_reader :documents
      attr_reader :code

      def initialize *options
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
        return unless @options

        old_verbose = $VERBOSE
        old_logger = old_logger_level = nil
        opts = {}
        infiles = []
        outfile = nil
        abs_srcdir_posix = nil
        non_posix_env = ::File::ALT_SEPARATOR == RS
        err = @err || $stderr
        show_timings = false

        @options.map do |key, val|
          case key
          when :input_files
            infiles = val
          when :output_file
            outfile = val
          when :source_dir
            if val
              abs_srcdir_posix = ::File.expand_path val
              abs_srcdir_posix = abs_srcdir_posix.tr RS, FS if non_posix_env && (abs_srcdir_posix.include? RS)
            end
          when :destination_dir
            opts[:to_dir] = val if val
          when :attributes
            # NOTE processor will dup attributes internally
            opts[:attributes] = val
          when :timings
            show_timings = val
          when :trace
            # currently does nothing
          when :verbose
            case val
            when 0
              $VERBOSE = nil
              old_logger = LoggerManager.logger
              LoggerManager.logger = NullLogger.new
            when 1
              $VERBOSE = false
            when 2
              $VERBOSE = true
              old_logger_level, LoggerManager.logger.level = LoggerManager.logger.level, ::Logger::Severity::DEBUG
            end
          else
            opts[key] = val unless val.nil?
          end
        end

        if infiles.size == 1
          if (infile0 = infiles[0]) == '-'
            outfile ||= infile0
            stdin = true
          elsif ::File.pipe? infile0
            outfile ||= '-'
          end
        end

        if outfile == '-'
          tofile = @out || $stdout
        elsif outfile
          opts[:mkdirs] = true
          tofile = outfile
        else
          opts[:mkdirs] = true
          # automatically calculate outfile based on infile
        end

        if stdin
          # allows use of block to supply stdin, particularly useful for tests
          input = block_given? ? yield : STDIN
          input_opts = opts.merge :to_file => tofile
          if show_timings
            @documents << (::Asciidoctor.convert input, (input_opts.merge :timings => (timings = Timings.new)))
            timings.print_report err, '-'
          else
            @documents << (::Asciidoctor.convert input, input_opts)
          end
        else
          infiles.each do |infile|
            input_opts = opts.merge :to_file => tofile
            if abs_srcdir_posix && (input_opts.key? :to_dir)
              abs_indir = ::File.dirname ::File.expand_path infile
              if non_posix_env
                abs_indir_posix = (abs_indir.include? RS) ? (abs_indir.tr RS, FS) : abs_indir
              else
                abs_indir_posix = abs_indir
              end
              if abs_indir_posix.start_with? %(#{abs_srcdir_posix}/)
                input_opts[:to_dir] += abs_indir.slice abs_srcdir_posix.length, abs_indir.length
              end
            end
            if show_timings
              @documents << (::Asciidoctor.convert_file infile, (input_opts.merge :timings => (timings = Timings.new)))
              timings.print_report err, infile
            else
              @documents << (::Asciidoctor.convert_file infile, input_opts)
            end
          end
        end
        @code = 1 if ((logger = LoggerManager.logger).respond_to? :max_severity) && logger.max_severity && logger.max_severity >= opts[:failure_level]
      rescue ::Exception => e
        if ::SignalException === e
          @code = e.signo
          # add extra endline if Ctrl+C is used
          err.puts if ::Interrupt === e
        else
          @code = (e.respond_to? :status) ? e.status : 1
          if @options[:trace]
            raise e
          else
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
        $VERBOSE = old_verbose
        if old_logger
          LoggerManager.logger = old_logger
        elsif old_logger_level
          LoggerManager.logger.level = old_logger_level
        end
      end

      def document
        @documents[0]
      end

      def redirect_streams out, err = nil
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
