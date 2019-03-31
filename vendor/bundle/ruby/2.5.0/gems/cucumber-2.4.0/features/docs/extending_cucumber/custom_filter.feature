Feature: Custom filter

  Scenario: Add a custom filter via AfterConfiguration hook
    Given a file named "features/test.feature" with:
      """
      Feature:
        Scenario:
          Given my special step
      """
    And a file named "features/support/my_filter.rb" with:
      """
      require 'cucumber/core/filter'

      MakeAnythingPass = Cucumber::Core::Filter.new do
        def test_case(test_case)
          activated_steps = test_case.test_steps.map do |test_step|
            test_step.with_action { }
          end
          test_case.with_steps(activated_steps).describe_to receiver
        end
      end

      AfterConfiguration do |config|
        config.filters << MakeAnythingPass.new
      end
      """
    When I run `cucumber --strict`
    Then it should pass

