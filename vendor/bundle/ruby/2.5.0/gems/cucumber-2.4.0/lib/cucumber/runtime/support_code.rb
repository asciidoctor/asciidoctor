require 'cucumber/constantize'
require 'cucumber/runtime/for_programming_languages'
require 'cucumber/runtime/step_hooks'
require 'cucumber/runtime/before_hooks'
require 'cucumber/runtime/after_hooks'
require 'cucumber/events/step_match'
require 'cucumber/gherkin/steps_parser'
require 'cucumber/step_match_search'

module Cucumber

  class Runtime

    class SupportCode

      require 'forwardable'
      class StepInvoker

        def initialize(support_code)
          @support_code = support_code
        end

        def steps(steps)
          steps.each { |step| step(step) }
        end

        def step(step)
          location = Core::Ast::Location.of_caller
          @support_code.invoke_dynamic_step(step[:text], multiline_arg(step, location))
        end

        def multiline_arg(step, location)
          if argument = step[:argument]
            if argument[:type] == :DocString
              MultilineArgument.doc_string(argument[:content], argument[:content_type], location)
            else
              MultilineArgument::DataTable.from(argument[:rows].map { |row| row[:cells].map { |cell| cell[:value] } })
            end
          else
            MultilineArgument.from(nil)
          end
        end
      end

      include Constantize

      attr_reader :ruby
      def initialize(user_interface, configuration=Configuration.default)
        @configuration = configuration
        @runtime_facade = Runtime::ForProgrammingLanguages.new(self, user_interface)
        @ruby = Cucumber::RbSupport::RbLanguage.new(@runtime_facade, @configuration)
      end

      def configure(new_configuration)
        @configuration = Configuration.new(new_configuration)
      end

      # Invokes a series of steps +steps_text+. Example:
      #
      #   invoke(%Q{
      #     Given I have 8 cukes in my belly
      #     Then I should not be thirsty
      #   })
      def invoke_dynamic_steps(steps_text, i18n, location)
        parser = Cucumber::Gherkin::StepsParser.new(StepInvoker.new(self), i18n.iso_code)
        parser.parse(steps_text)
      end

      # @api private
      # This allows users to attempt to find, match and execute steps
      # from code as the features are running, as opposed to regular
      # steps which are compiled into test steps before execution.
      #
      # These are commonly called nested steps.
      def invoke_dynamic_step(step_name, multiline_argument, location=nil)
        matches = step_matches(step_name)
        raise UndefinedDynamicStep, step_name if matches.empty?
        matches.first.invoke(multiline_argument)
      end

      def load_files!(files)
        log.debug("Code:\n")
        files.each do |file|
          load_file(file)
        end
        log.debug("\n")
      end

      def load_files_from_paths(paths)
        files = paths.map { |path| Dir["#{path}/**/*.rb"] }.flatten
        load_files! files
      end

      def unmatched_step_definitions
        @ruby.unmatched_step_definitions
      end

      def fire_hook(name, *args)
        @ruby.send(name, *args)
      end

      def step_definitions
        @ruby.step_definitions
      end

      def find_after_step_hooks(test_case)
        scenario = RunningTestCase.new(test_case)
        hooks = @ruby.hooks_for(:after_step, scenario)
        StepHooks.new hooks
      end

      def apply_before_hooks(test_case)
        scenario = RunningTestCase.new(test_case)
        hooks = @ruby.hooks_for(:before, scenario)
        BeforeHooks.new(hooks, scenario).apply_to(test_case)
      end

      def apply_after_hooks(test_case)
        scenario = RunningTestCase.new(test_case)
        hooks = @ruby.hooks_for(:after, scenario)
        AfterHooks.new(hooks, scenario).apply_to(test_case)
      end

      def find_around_hooks(test_case)
        scenario = RunningTestCase.new(test_case)

        @ruby.hooks_for(:around, scenario).map do |hook|
          Hooks.around_hook(test_case.source) do |run_scenario|
            hook.invoke('Around', scenario, &run_scenario)
          end
        end
      end

      private

      def step_matches(step_name)
        StepMatchSearch.new(@ruby.method(:step_matches), @configuration).call(step_name)
      end

      def load_file(file)
        log.debug("  * #{file}\n")
        @ruby.load_code_file(file)
      end

      def log
        Cucumber.logger
      end

    end
  end
end
