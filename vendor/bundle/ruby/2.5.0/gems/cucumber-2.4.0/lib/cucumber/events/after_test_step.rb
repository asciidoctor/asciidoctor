module Cucumber
  module Events

    # Event fired after each test step has been executed
    class AfterTestStep

      # The test case currently being executed.
      #
      # @return [Cucumber::Core::Test::Case]
      attr_reader :test_case

      # The test step that was just executed.
      #
      # @return [Cucumber::Core::Test::Step]
      attr_reader :test_step

      # The result of executing the test step.
      #
      # @return [Cucumber::Core::Test::Result]
      attr_reader :result

      # @private
      def initialize(test_case, test_step, result)
        @test_case, @test_step, @result = test_case, test_step, result
      end

    end

  end
end
