module Cucumber
  module Events

    # Event fired after a test case has finished executing
    class AfterTestCase

      # The test case that was just executed.
      #
      # @return [Cucumber::Core::Test::Case]
      attr_reader :test_case

      # The result of executing the test case.
      #
      # @return [Cucumber::Core::Test::Result]
      attr_reader :result

      # @private
      def initialize(test_case, result)
        @test_case, @result = test_case, result
      end

    end

  end
end
