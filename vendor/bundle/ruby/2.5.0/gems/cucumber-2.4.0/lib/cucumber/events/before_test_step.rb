module Cucumber
  module Events

    # Event fired before a test step is executed
    class BeforeTestStep

      # The test case currently being executed.
      #
      # @return [Cucumber::Core::Test::Case]
      attr_reader :test_case

      # The test step about to be executed.
      #
      # @return [Cucumber::Core::Test::Step]
      attr_reader :test_step

      # @private
      def initialize(test_case, test_step)
        @test_case, @test_step = test_case, test_step
      end
    end
  end
end
