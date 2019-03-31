module Cucumber
  module Formatter

    # Adapter between Cucumber::Core::Test::Runner's Report API and 
    # Cucumber's event bus
    class EventBusReport
      attr_reader :config
      private :config

      def initialize(config)
        @config = config
      end

      def before_test_case(test_case)
        @config.notify Events::BeforeTestCase.new(test_case)
        @test_case = test_case
      end

      def before_test_step(test_step)
        @config.notify Events::BeforeTestStep.new(@test_case, test_step)
      end

      def after_test_step(test_step, result)
        @config.notify Events::AfterTestStep.new(@test_case, test_step, result)
      end

      def after_test_case(test_case, result)
        @config.notify Events::AfterTestCase.new(test_case, result)
      end

      def done
        @config.notify Events::FinishedTesting.new
      end
    end

  end
end

