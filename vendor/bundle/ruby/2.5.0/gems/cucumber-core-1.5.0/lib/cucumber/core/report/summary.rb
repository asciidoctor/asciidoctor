module Cucumber
  module Core
    module Report
      class Summary
        attr_reader :test_cases, :test_steps

        def initialize
          @test_cases = Test::Result::Summary.new
          @test_steps = Test::Result::Summary.new
        end

        def after_test_case(test_case, result)
          result.describe_to test_cases
        end

        def after_test_step(test_step, result)
          result.describe_to test_steps
        end

        def method_missing(*)
        end

      end
    end
  end
end
