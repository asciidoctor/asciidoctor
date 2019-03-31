module Cucumber
  module Events

    # Event fired before a test case is executed
    class BeforeTestCase

      # The test case about to be executed.
      #
      # @return [Cucumber::Core::Test::Case]
      attr_reader :test_case

      # @private
      def initialize(test_case)
        @test_case = test_case
      end
    end
  end
end
