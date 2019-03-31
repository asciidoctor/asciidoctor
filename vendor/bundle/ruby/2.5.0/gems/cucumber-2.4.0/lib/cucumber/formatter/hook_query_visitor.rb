module Cucumber
  module Formatter
    class HookQueryVisitor
      attr_reader :type

      def initialize(test_step)
        @hook = false
        @type = :no_hook
        test_step.source.last.describe_to(self)
      end

      def hook?
        @hook
      end

      def step(*)
      end

      def before_hook(*)
        @hook = true
        @type = :before
      end

      def after_hook(*)
        @hook = true
        @type = :after
      end

      def after_step_hook(*)
        @hook = true
        @type = :after_step
      end

      def around_hook(*)
        @hook = true
        @type = :around
      end
    end
  end
end
