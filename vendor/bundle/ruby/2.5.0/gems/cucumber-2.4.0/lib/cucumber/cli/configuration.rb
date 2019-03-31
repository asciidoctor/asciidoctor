require 'logger'
require 'cucumber/cli/options'
require 'cucumber/cli/rerun_file'
require 'cucumber/constantize'
require 'cucumber/core/gherkin/tag_expression'

module Cucumber
  module Cli
    class YmlLoadError < StandardError; end
    class ProfilesNotDefinedError < YmlLoadError; end
    class ProfileNotFound < StandardError; end

    class Configuration
      include Constantize

      attr_reader :out_stream

      def initialize(out_stream = STDOUT, error_stream = STDERR)
        @out_stream   = out_stream
        @error_stream = error_stream
        @options = Options.new(@out_stream, @error_stream, :default_profile => 'default')
      end

      def parse!(args)
        @args = args
        @options.parse!(args)
        arrange_formats
        raise("You can't use both --strict and --wip") if strict? && wip?
        # todo: remove
        @options[:tag_expression] = Cucumber::Core::Gherkin::TagExpression.new(@options[:tag_expressions])
        set_environment_variables
      end

      def verbose?
        @options[:verbose]
      end

      def randomize?
        @options[:order] == 'random'
      end

      def seed
        Integer(@options[:seed] || rand(0xFFFF))
      end

      def strict?
        @options[:strict]
      end

      def wip?
        @options[:wip]
      end

      def guess?
        @options[:guess]
      end

      def dry_run?
        @options[:dry_run]
      end

      def expand?
        @options[:expand]
      end

      def fail_fast?
        !!@options[:fail_fast]
      end

      def retry_attempts
        @options[:retry]
      end

      def snippet_type
        @options[:snippet_type] || :regexp
      end

      def log
        logger = Logger.new(@out_stream)
        logger.formatter = LogFormatter.new
        logger.level = Logger::INFO
        logger.level = Logger::DEBUG if self.verbose?
        logger
      end

      # todo: remove
      def tag_expression
        Cucumber::Core::Gherkin::TagExpression.new(@options[:tag_expressions])
      end

      def tag_limits
        tag_expression.limits.to_hash
      end

      def tag_expressions
        @options[:tag_expressions]
      end

      def name_regexps
        @options[:name_regexps]
      end

      def filters
        @options.filters
      end

      def formats
        @options[:formats]
      end

      def options
        warn("Deprecated: Configuration#options will be removed from the next release of Cucumber. Please use the configuration object directly instead.")
        @options
      end

      def paths
        @options[:paths]
      end

      def to_hash
        Cucumber::Hash(@options).merge(out_stream: @out_stream, error_stream: @error_stream)
      end

      private

      class LogFormatter < ::Logger::Formatter
        def call(severity, time, progname, msg)
          msg
        end
      end

      def set_environment_variables
        @options[:env_vars].each do |var, value|
          ENV[var] = value
        end
      end

      def arrange_formats
        @options[:formats] << ['pretty', @out_stream] if @options[:formats].empty?
        @options[:formats] = @options[:formats].sort_by{|f| f[1] == @out_stream ? -1 : 1}
        @options[:formats].uniq!
        @options.check_formatter_stream_conflicts()
      end
    end
  end
end
