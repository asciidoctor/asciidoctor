require 'cucumber/hooks'

module Cucumber
  class Runtime
    class BeforeHooks
      def initialize(hooks, scenario)
        @hooks = hooks
        @scenario = scenario
      end

      def apply_to(test_case)
        test_case.with_steps(
          before_hooks(test_case.source) + test_case.test_steps
        )
      end

      private

      def before_hooks(source)
        @hooks.map do |hook|
          action_block = ->(result) { hook.invoke('Before', @scenario.with_result(result)) }
          Hooks.before_hook(source, hook.location, &action_block)
        end
      end
    end
  end
end
