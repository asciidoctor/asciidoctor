require 'cucumber/core/filter'
require 'cucumber/core/ast/location'
require 'cucumber/running_test_case'

module Cucumber
  module Filters

    class PrepareWorld < Core::Filter.new(:runtime)

      def test_case(test_case)
        CaseFilter.new(runtime, test_case).test_case.describe_to receiver
      end

      class CaseFilter
        def initialize(runtime, original_test_case)
          @runtime, @original_test_case = runtime, original_test_case
        end

        def test_case
          init_scenario = Cucumber::Hooks.around_hook(@original_test_case.source) do |continue|
            @runtime.begin_scenario(scenario)
            continue.call
            @runtime.end_scenario(scenario)
          end
          around_hooks = [init_scenario] + @original_test_case.around_hooks

          empty_hook = proc {} #no op - legacy format adapter expects a before hooks
          empty_hook_location = Cucumber::Core::Ast::Location.from_source_location(*empty_hook.source_location)
          default_hook = Cucumber::Hooks.before_hook(@original_test_case.source, empty_hook_location, &empty_hook)
          steps = [default_hook] + @original_test_case.test_steps

          @original_test_case.with_around_hooks(around_hooks).with_steps(steps)
        end

        private

        def scenario
          @scenario ||= RunningTestCase.new(test_case)
        end
      end

    end

  end
end
