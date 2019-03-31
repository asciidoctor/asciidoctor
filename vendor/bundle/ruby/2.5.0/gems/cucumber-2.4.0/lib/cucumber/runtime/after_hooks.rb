module Cucumber
  class Runtime
    class AfterHooks
      def initialize(hooks, scenario)
        @hooks = hooks
        @scenario = scenario
      end

      def apply_to(test_case)
        test_case.with_steps(
          test_case.test_steps + after_hooks(test_case.source).reverse
        )
      end

      private

      def after_hooks(source)
        @hooks.map do |hook|
          action = ->(result) { hook.invoke('After', @scenario.with_result(result)) }
          Hooks.after_hook(source, hook.location, &action)
        end          
      end
    end
  end
end
