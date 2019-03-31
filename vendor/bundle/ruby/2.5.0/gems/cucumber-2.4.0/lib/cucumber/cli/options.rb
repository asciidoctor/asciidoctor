require 'cucumber/cli/profile_loader'
require 'cucumber/formatter/ansicolor'
require 'cucumber/rb_support/rb_language'
require 'cucumber/project_initializer'

module Cucumber
  module Cli

    class Options
      INDENT = ' ' * 53
      BUILTIN_FORMATS = {
        'html'        => ['Cucumber::Formatter::Html',        'Generates a nice looking HTML report.'],
        'pretty'      => ['Cucumber::Formatter::Pretty',      'Prints the feature as is - in colours.'],
        'progress'    => ['Cucumber::Formatter::Progress',    'Prints one character per scenario.'],
        'rerun'       => ['Cucumber::Formatter::Rerun',       'Prints failing files with line numbers.'],
        'usage'       => ['Cucumber::Formatter::Usage',       "Prints where step definitions are used.\n" +
                                                              "#{INDENT}The slowest step definitions (with duration) are\n" +
                                                              "#{INDENT}listed first. If --dry-run is used the duration\n" +
                                                              "#{INDENT}is not shown, and step definitions are sorted by\n" +
                                                              "#{INDENT}filename instead."],
        'stepdefs'    => ['Cucumber::Formatter::Stepdefs',    "Prints All step definitions with their locations. Same as\n" +
                                                              "#{INDENT}the usage formatter, except that steps are not printed."],
        'junit'       => ['Cucumber::Formatter::Junit',       'Generates a report similar to Ant+JUnit.'],
        'json'        => ['Cucumber::Formatter::Json',        'Prints the feature as JSON'],
        'json_pretty' => ['Cucumber::Formatter::JsonPretty',  'Prints the feature as prettified JSON'],
        'debug'       => ['Cucumber::Formatter::Debug',       'For developing formatters - prints the calls made to the listeners.']
      }
      max = BUILTIN_FORMATS.keys.map{|s| s.length}.max
      FORMAT_HELP = (BUILTIN_FORMATS.keys.sort.map do |key|
        "  #{key}#{' ' * (max - key.length)} : #{BUILTIN_FORMATS[key][1]}"
      end) + ["Use --format rerun --out rerun.txt to write out failing",
        "features. You can rerun them with cucumber @rerun.txt.",
        "FORMAT can also be the fully qualified class name of",
        "your own custom formatter. If the class isn't loaded,",
        "Cucumber will attempt to require a file with a relative",
        "file name that is the underscore name of the class name.",
        "Example: --format Foo::BarZap -> Cucumber will look for",
        "foo/bar_zap.rb. You can place the file with this relative",
        "path underneath your features/support directory or anywhere",
        "on Ruby's LOAD_PATH, for example in a Ruby gem."
      ]
      PROFILE_SHORT_FLAG = '-p'
      NO_PROFILE_SHORT_FLAG = '-P'
      PROFILE_LONG_FLAG = '--profile'
      NO_PROFILE_LONG_FLAG = '--no-profile'
      FAIL_FAST_FLAG = '--fail-fast'
      RETRY_FLAG = '--retry'
      OPTIONS_WITH_ARGS = ['-r', '--require', '--i18n', '-f', '--format', '-o', '--out',
                                  '-t', '--tags', '-n', '--name', '-e', '--exclude',
                                  PROFILE_SHORT_FLAG, PROFILE_LONG_FLAG, RETRY_FLAG,
                                  '-l', '--lines', '--port',
                                  '-I', '--snippet-type']
      ORDER_TYPES = %w{defined random}

      def self.parse(args, out_stream, error_stream, options = {})
        new(out_stream, error_stream, options).parse!(args)
      end

      def initialize(out_stream = STDOUT, error_stream = STDERR, options = {})
        @out_stream   = out_stream
        @error_stream = error_stream

        @default_profile = options[:default_profile]
        @profiles = options[:profiles] || []
        @overridden_paths = []
        @options = default_options.merge(options)
        @profile_loader = options[:profile_loader]
        @options[:skip_profile_information] = options[:skip_profile_information]

        @disable_profile_loading = nil
      end

      def [](key)
        @options[key]
      end

      def []=(key, value)
        @options[key] = value
      end

      def parse!(args)
        @args = args
        @expanded_args = @args.dup

        @args.extend(::OptionParser::Arguable)

        @args.options do |opts|
          opts.banner = ["Usage: cucumber [options] [ [FILE|DIR|URL][:LINE[:LINE]*] ]+", "",
            "Examples:",
            "cucumber examples/i18n/en/features",
            "cucumber @rerun.txt (See --format rerun)",
            "cucumber examples/i18n/it/features/somma.feature:6:98:113",
            "cucumber -s -i http://rubyurl.com/eeCl", "", "",
          ].join("\n")
          opts.on("-r LIBRARY|DIR", "--require LIBRARY|DIR",
            "Require files before executing the features. If this",
            "option is not specified, all *.rb files that are",
            "siblings or below the features will be loaded auto-",
            "matically. Automatic loading is disabled when this",
            "option is specified, and all loading becomes explicit.",
            "Files under directories named \"support\" are always",
            "loaded first.",
            "This option can be specified multiple times.") do |v|
            @options[:require] << v
            if(Cucumber::JRUBY && File.directory?(v))
              require 'java'
              $CLASSPATH << v
            end
          end

          if(Cucumber::JRUBY)
            opts.on("-j DIR", "--jars DIR",
            "Load all the jars under DIR") do |jars|
              Dir["#{jars}/**/*.jar"].each {|jar| require jar}
            end
          end

          opts.on("--i18n LANG",
            "List keywords for in a particular language",
            %{Run with "--i18n help" to see all languages}) do |lang|
            require 'gherkin/dialect'

            if lang == 'help'
              list_languages_and_exit
            elsif !::Gherkin::DIALECTS.keys.include? lang
              indicate_invalid_language_and_exit(lang)
            else
              list_keywords_and_exit(lang)
            end
          end
          opts.on(FAIL_FAST_FLAG, "Exit immediately following the first failing scenario") do |v|
            options[:fail_fast] = true
          end
          opts.on("-f FORMAT", "--format FORMAT",
            "How to format features (Default: pretty). Available formats:",
            *FORMAT_HELP) do |v|
            @options[:formats] << [v, @out_stream]
          end
          opts.on('--init',
            'Initializes folder structure and generates conventional files for',
            'a Cucumber project.') do |v|
            ProjectInitializer.new.run
            Kernel.exit(0)
          end
          opts.on("-o", "--out [FILE|DIR]",
            "Write output to a file/directory instead of STDOUT. This option",
            "applies to the previously specified --format, or the",
            "default format if no format is specified. Check the specific",
            "formatter's docs to see whether to pass a file or a dir.") do |v|
            @options[:formats] << ['pretty', nil] if @options[:formats].empty?
            @options[:formats][-1][1] = v
          end
          opts.on("-t TAG_EXPRESSION", "--tags TAG_EXPRESSION",
            "Only execute the features or scenarios with tags matching TAG_EXPRESSION.",
            "Scenarios inherit tags declared on the Feature level. The simplest",
            "TAG_EXPRESSION is simply a tag. Example: --tags @dev. When a tag in a tag",
            "expression starts with a ~, this represents boolean NOT. Example: --tags ~@dev.",
            "A tag expression can have several tags separated by a comma, which represents",
            "logical OR. Example: --tags @dev,@wip. The --tags option can be specified",
            "several times, and this represents logical AND. Example: --tags @foo,~@bar --tags @zap.",
            "This represents the boolean expression (@foo || !@bar) && @zap.",
            "\n",
            "Beware that if you want to use several negative tags to exclude several tags",
            "you have to use logical AND: --tags ~@fixme --tags ~@buggy.",
            "\n",
            "Positive tags can be given a threshold to limit the number of occurrences.",
            "Example: --tags @qa:3 will fail if there are more than 3 occurrences of the @qa tag.",
            "This can be practical if you are practicing Kanban or CONWIP.") do |v|
            @options[:tag_expressions] << v
          end
          opts.on("-n NAME", "--name NAME",
            "Only execute the feature elements which match part of the given name.",
            "If this option is given more than once, it will match against all the",
            "given names.") do |v|
            @options[:name_regexps] << /#{v}/
          end
          opts.on("-e", "--exclude PATTERN", "Don't run feature files or require ruby files matching PATTERN") do |v|
            @options[:excludes] << Regexp.new(v)
          end
          opts.on(PROFILE_SHORT_FLAG, "#{PROFILE_LONG_FLAG} PROFILE",
              "Pull commandline arguments from cucumber.yml which can be defined as",
              "strings or arrays.  When a 'default' profile is defined and no profile",
              "is specified it is always used. (Unless disabled, see -P below.)",
              "When feature files are defined in a profile and on the command line",
              "then only the ones from the command line are used.") do |v|
            @profiles << v
          end
          opts.on(NO_PROFILE_SHORT_FLAG, NO_PROFILE_LONG_FLAG,
            "Disables all profile loading to avoid using the 'default' profile.") do |v|
            @disable_profile_loading = true
          end
          opts.on("#{RETRY_FLAG} ATTEMPTS", "Specify the number of times to retry failing tests (default: 0)") do |v|
            @options[:retry] = v.to_i
          end
          opts.on("-c", "--[no-]color",
            "Whether or not to use ANSI color in the output. Cucumber decides",
            "based on your platform and the output destination if not specified.") do |v|
            Cucumber::Term::ANSIColor.coloring = v
          end
          opts.on("-d", "--dry-run", "Invokes formatters without executing the steps.",
            "This also omits the loading of your support/env.rb file if it exists.") do
            @options[:dry_run] = true
            @options[:duration] = false
          end
          opts.on("-m", "--no-multiline",
            "Don't print multiline strings and tables under steps.") do
            @options[:no_multiline] = true
          end
          opts.on("-s", "--no-source",
            "Don't print the file and line of the step definition with the steps.") do
            @options[:source] = false
          end
          opts.on("-i", "--no-snippets", "Don't print snippets for pending steps.") do
            @options[:snippets] = false
          end
          opts.on("-I", "--snippet-type TYPE",
                  "Use different snippet type (Default: regexp). Available types:",
                  *Cucumber::RbSupport::RbLanguage.cli_snippet_type_options) do |v|
            @options[:snippet_type] = v.to_sym
          end

          opts.on("-q", "--quiet", "Alias for --no-snippets --no-source.") do
            @options[:snippets] = false
            @options[:source] = false
            @options[:duration] = false
          end
          opts.on("--no-duration", "Don't print the duration at the end of the summary") do
            @options[:duration] = false
          end
          opts.on("-b", "--backtrace", "Show full backtrace for all errors.") do
            Cucumber.use_full_backtrace = true
          end
          opts.on("-S", "--strict", "Fail if there are any undefined or pending steps.") do
            @options[:strict] = true
          end
          opts.on("-w", "--wip", "Fail if there are any passing scenarios.") do
            @options[:wip] = true
          end
          opts.on("-v", "--verbose", "Show the files and features loaded.") do
            @options[:verbose] = true
          end
          opts.on("-g", "--guess", "Guess best match for Ambiguous steps.") do
            @options[:guess] = true
          end
          opts.on("-l", "--lines LINES", "Run given line numbers. Equivalent to FILE:LINE syntax") do |lines|
            @options[:lines] = lines
          end
          opts.on("-x", "--expand", "Expand Scenario Outline Tables in output.") do
            @options[:expand] = true
          end
          opts.on("--order TYPE[:SEED]", "Run examples in the specified order. Available types:",
            *<<-TEXT.split("\n")) do |order|
  [defined]     Run scenarios in the order they were defined (default).
  [random]      Shuffle scenarios before running.
Specify SEED to reproduce the shuffling from a previous run.
  e.g. --order random:5738
TEXT
            @options[:order], @options[:seed] = *order.split(":")
            unless ORDER_TYPES.include?(@options[:order])
              fail "'#{@options[:order]}' is not a recognised order type. Please use one of #{ORDER_TYPES.join(", ")}."
            end
          end
          opts.on_tail("--version", "Show version.") do
            @out_stream.puts Cucumber::VERSION
            Kernel.exit(0)
          end
          opts.on_tail("-h", "--help", "You're looking at it.") do
            @out_stream.puts opts.help
            Kernel.exit(0)
          end
        end.parse!

        @args.map! { |a| "#{a}:#{@options[:lines]}" } if @options[:lines]

        extract_environment_variables
        @options[:paths] = @args.dup #whatver is left over

        check_formatter_stream_conflicts()

        merge_profiles

        self
      end

      def custom_profiles
        @profiles - [@default_profile]
      end

      def filters
        @options[:filters] ||= []
      end

      def check_formatter_stream_conflicts()
        streams = @options[:formats].uniq.map { |(_, stream)| stream }
        if streams != streams.uniq
          raise "All but one formatter must use --out, only one can print to each stream (or STDOUT)"
        end
      end

      def to_hash
        Cucumber::Hash(@options)
      end

    protected

      attr_reader :options, :profiles, :expanded_args
      protected :options, :profiles, :expanded_args

    private

      def non_stdout_formats
        @options[:formats].select {|format, output| output != @out_stream }
      end

      def stdout_formats
        @options[:formats].select {|format, output| output == @out_stream }
      end

      def extract_environment_variables
        @args.delete_if do |arg|
          if arg =~ /^(\w+)=(.*)$/
            @options[:env_vars][$1] = $2
            true
          end
        end
      end

      def disable_profile_loading?
        @disable_profile_loading
      end

      def merge_profiles
        if @disable_profile_loading
          @out_stream.puts "Disabling profiles..."
          return
        end

        @profiles << @default_profile if default_profile_should_be_used?

        @profiles.each do |profile|
          merge_with_profile(profile)
        end

        @options[:profiles] = @profiles
      end

      def merge_with_profile(profile)
        profile_args = profile_loader.args_from(profile)
        profile_options = Options.parse(
          profile_args, @out_stream, @error_stream,
          :skip_profile_information => true,
          :profile_loader => profile_loader
        )
        reverse_merge(profile_options)
      end

      def default_profile_should_be_used?
        @profiles.empty? &&
          profile_loader.cucumber_yml_defined? &&
          profile_loader.has_profile?(@default_profile)
      end

      def profile_loader
        @profile_loader ||= ProfileLoader.new
      end

      def reverse_merge(other_options)
        @options = other_options.options.merge(@options)
        @options[:require] += other_options[:require]
        @options[:excludes] += other_options[:excludes]
        @options[:name_regexps] += other_options[:name_regexps]
        @options[:tag_expressions] += other_options[:tag_expressions]
        @options[:env_vars] = other_options[:env_vars].merge(@options[:env_vars])
        if @options[:paths].empty?
          @options[:paths] = other_options[:paths]
        else
          @overridden_paths += (other_options[:paths] - @options[:paths])
        end
        @options[:source] &= other_options[:source]
        @options[:snippets] &= other_options[:snippets]
        @options[:duration] &= other_options[:duration]
        @options[:strict] |= other_options[:strict]
        @options[:dry_run] |= other_options[:dry_run]

        @profiles += other_options.profiles
        @expanded_args += other_options.expanded_args

        if @options[:formats].empty?
          @options[:formats] = other_options[:formats]
        else
          @options[:formats] += other_options[:formats]
          @options[:formats] = stdout_formats[0..0] + non_stdout_formats
        end

        self
      end

      def indicate_invalid_language_and_exit(lang)
        @out_stream.write("Invalid language '#{lang}'. Available languages are:\n")
        list_languages_and_exit
      end

      def list_keywords_and_exit(lang)
        require 'gherkin/dialect'
        language = ::Gherkin::Dialect.for(lang)
        data = Cucumber::MultilineArgument::DataTable.from(
          [["feature", to_keywords_string(language.feature_keywords)],
          ["background", to_keywords_string(language.background_keywords)],
          ["scenario", to_keywords_string(language.scenario_keywords)],
          ["scenario_outline", to_keywords_string(language.scenario_outline_keywords)],
          ["examples", to_keywords_string(language.examples_keywords)],
          ["given", to_keywords_string(language.given_keywords)],
          ["when", to_keywords_string(language.when_keywords)],
          ["then", to_keywords_string(language.then_keywords)],
          ["and", to_keywords_string(language.and_keywords)],
          ["but", to_keywords_string(language.but_keywords)],
          ["given (code)", to_code_keywords_string(language.given_keywords)],
          ["when (code)", to_code_keywords_string(language.when_keywords)],
          ["then (code)", to_code_keywords_string(language.then_keywords)],
          ["and (code)", to_code_keywords_string(language.and_keywords)],
          ["but (code)", to_code_keywords_string(language.but_keywords)]])
        @out_stream.write(data.to_s({ color: false, prefixes: Hash.new('') }))
        Kernel.exit(0)
      end

      def list_languages_and_exit
        require 'gherkin/dialect'
        data = Cucumber::MultilineArgument::DataTable.from(
          ::Gherkin::DIALECTS.keys.map do |key|
            [key, ::Gherkin::DIALECTS[key].fetch('name'), ::Gherkin::DIALECTS[key].fetch('native')]
          end)
        @out_stream.write(data.to_s({ color: false, prefixes: Hash.new('') }))
        Kernel.exit(0)
      end

      def to_keywords_string(list)
        list.map { |item| "\"#{item}\"" }.join(', ')
      end

      def to_code_keywords_string(list)
        to_keywords_string(Cucumber::Gherkin::I18n.code_keywords_for(list))
      end

      def default_options
        {
          :strict       => false,
          :require      => [],
          :dry_run      => false,
          :formats      => [],
          :excludes     => [],
          :tag_expressions  => [],
          :name_regexps => [],
          :env_vars     => {},
          :diff_enabled => true,
          :snippets     => true,
          :source       => true,
          :duration     => true,
          :retry        => 0
        }
      end
    end

  end
end
