require 'cucumber/constantize'
require 'cucumber/cli/rerun_file'
require 'cucumber/events'
require 'forwardable'
require 'cucumber/core/gherkin/tag_expression'

module Cucumber
  # The base class for configuring settings for a Cucumber run.
  class Configuration
    include Constantize
    extend Forwardable

    def self.default
      new
    end

    # Subscribe to an event.
    #
    # See {Cucumber::Events} for the list of possible events.
    #
    # @param event_id [Symbol, Class, String] Identifier for the type of event to subscribe to
    # @param handler_object [Object optional] an object to be called when the event occurs
    # @yield [Object] Block to be called when th event occurs
    # @method on_event
    def_instance_delegator :event_bus, :register, :on_event

    # @private
    def_instance_delegator :event_bus, :notify

    def initialize(user_options = {})
      @options = default_options.merge(Cucumber::Hash(user_options))
    end

    def with_options(new_options)
      self.class.new(@options.merge(new_options))
    end

    # TODO: Actually Deprecate???
    def options
      warn("Deprecated: Configuration#options will be removed from the next release of Cucumber. Please use the configuration object directly instead.")
      Marshal.load(Marhal.dump(@options))
    end

    def out_stream
      @options[:out_stream]
    end

    def error_stream
      @options[:error_stream]
    end

    def randomize?
      @options[:order] == 'random'
    end

    def seed
      Integer(@options[:seed] || rand(0xFFFF))
    end

    def dry_run?
      @options[:dry_run]
    end

    def fail_fast?
      @options[:fail_fast]
    end

    def retry_attempts
      @options[:retry]
    end

    def guess?
      @options[:guess]
    end

    def strict?
      @options[:strict]
    end

    def wip?
      @options[:wip]
    end

    def expand?
      @options[:expand]
    end

    def paths
      @options[:paths]
    end

    def formats
      @options[:formats]
    end

    def autoload_code_paths
      @options[:autoload_code_paths]
    end

    def snippet_type
      @options[:snippet_type]
    end

    def feature_dirs
      dirs = paths.map { |f| File.directory?(f) ? f : File.dirname(f) }.uniq
      dirs.delete('.') unless paths.include?('.')
      with_default_features_path(dirs)
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
      @options[:filters]
    end

    def feature_files
      potential_feature_files = with_default_features_path(paths).map do |path|
        path = path.gsub(/\\/, '/') # In case we're on windows. Globs don't work with backslashes.
        path = path.chomp('/')

        # TODO: Move to using feature loading strategies stored in
        # options[:feature_loaders]
        if File.directory?(path)
          Dir["#{path}/**/*.feature"].sort
        elsif Cli::RerunFile.can_read?(path)
          Cli::RerunFile.new(path).features
        else
          path
        end
      end.flatten.uniq
      remove_excluded_files_from(potential_feature_files)
      potential_feature_files
    end

    def support_to_load
      support_files = all_files_to_load.select {|f| f =~ %r{/support/} }
      env_files = support_files.select {|f| f =~ %r{/support/env\..*} }
      other_files = support_files - env_files
      @options[:dry_run] ? other_files : env_files + other_files
    end

    def all_files_to_load
      files = require_dirs.map do |path|
        path = path.gsub(/\\/, '/') # In case we're on windows. Globs don't work with backslashes.
        path = path.gsub(/\/$/, '') # Strip trailing slash.
        File.directory?(path) ? Dir["#{path}/**/*"] : path
      end.flatten.uniq
      remove_excluded_files_from(files)
      files.reject! {|f| !File.file?(f)}
      files.reject! {|f| File.extname(f) == '.feature' }
      files.reject! {|f| f =~ /^http/}
      files.sort
    end

    def step_defs_to_load
      all_files_to_load.reject {|f| f =~ %r{/support/} }
    end

    def formatter_factories
      @options[:formats].map do |format_and_out|
        format = format_and_out[0]
        path_or_io = format_and_out[1]
        begin
          factory = formatter_class(format)
          yield factory, path_or_io, Cli::Options.new(STDOUT, STDERR, @options)
        rescue Exception => e
          e.message << "\nError creating formatter: #{format}"
          raise e
        end
      end
    end

    def formatter_class(format)
      if(builtin = Cli::Options::BUILTIN_FORMATS[format])
        constantize(builtin[0])
      else
        constantize(format)
      end
    end

    def to_hash
      @options
    end

    # An array of procs that can generate snippets for undefined steps. These procs may be called if a
    # formatter wants to display snippets to the user.
    #
    # Each proc should take the following arguments:
    # 
    #  - keyword
    #  - step text
    #  - multiline argument
    #  - snippet type
    #
    def snippet_generators
      @options[:snippet_generators] ||= []
    end

    def register_snippet_generator(generator)
      snippet_generators << generator
      self
    end

  private

    def default_options
      {
        :autoload_code_paths => ['features/support', 'features/step_definitions'],
        :filters             => [],
        :strict              => false,
        :require             => [],
        :dry_run             => false,
        :fail_fast           => false,
        :formats             => [],
        :excludes            => [],
        :tag_expressions     => [],
        :name_regexps        => [],
        :env_vars            => {},
        :diff_enabled        => true,
        :snippets            => true,
        :source              => true,
        :duration            => true,
        :event_bus           => Events::Bus.new(Cucumber::Events)
      }
    end

    def event_bus
      @options[:event_bus]
    end


    def default_features_paths
      ["features"]
    end

    def with_default_features_path(paths)
      return default_features_paths if paths.empty?
      paths
    end

    def remove_excluded_files_from(files)
      files.reject! {|path| @options[:excludes].detect {|pattern| path =~ pattern } }
    end

    def require_dirs
      if @options[:require].empty?
        default_features_paths + Dir['vendor/{gems,plugins}/*/cucumber']
      else
        @options[:require]
      end
    end
  end
end
