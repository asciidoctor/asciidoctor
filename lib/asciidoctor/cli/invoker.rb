module Asciidoctor
  module Cli
    # Public Invocation class for starting Asciidoctor via CLI
    class Invoker
      attr_reader :options

      def initialize(*options)
        options = options.flatten
        if (!options.empty?) && (options.first === Asciidoctor::Cli::Options)
          @options = options.first
        elsif options.first.is_a? Hash
          @options = Asciidoctor::Cli::Options.new(options)
        else
          @options = Asciidoctor::Cli::Options.parse!(options)
        end
      end

      def invoke!
        begin
          attrs = @options[:attributes]
          attrs['asciidoctor-file'] = File.expand_path($PROGRAM_NAME)
          attrs['asciidoctor-dir'] = File.expand_path(File.join(File.dirname(__FILE__), '../../..'))
          attrs['asciidoctor-args'] = ARGV * ' '
          infile = @options[:input_file]
          infile_mtime = File.mtime(infile)
          attrs['docfile'] = attrs['infile'] = File.expand_path(infile)
          attrs['docdir'] = attrs['indir'] = File.expand_path(File.dirname(infile))
          attrs['docname'] = File.basename(infile, File.extname(infile))
          attrs['docdate'] = infile_mtime.strftime('%Y-%m-%d')
          attrs['doctime'] = infile_mtime.strftime('%H:%m:%S %Z')
          doc = Asciidoctor::Document.new(File.new(infile).readlines, @options)
          output = doc.render
          outfile = @options[:output_file]
          if outfile.nil? || outfile.empty?
            outfile = File.join(doc.attributes['docdir'], "#{doc.attributes['docname']}#{doc.attributes['outfilesuffix']}")
          end

          if outfile == '-'
            outstream = $stdout
          else
            outstream = File.new(outfile, 'w')
          end
          outstream.puts output
        rescue Exception => e
          raise e if @options[:trace] || SystemExit === e
          $stderr.print "#{e.class}: " if e.class != RuntimeError
          $stderr.puts e.message
          $stderr.puts '  Use --trace for backtrace'
          exit 1
        end
      end
    end
  end
end
