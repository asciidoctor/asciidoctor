Feature: Debug formatter

  In order to help you easily visualise the listener API, you can use
  the `debug` formatter that prints the calls to the listener as a
  feature is run.

  Background:
    Given the standard step definitions

  Scenario: title
    Given a file named "features/test.feature" with:
      """
      Feature:
        Scenario:
          Given this step passes
      """
    When I run `cucumber -f debug`
    Then the stderr should not contain anything
    Then it should pass with:
      """
      before_test_case
      before_features
      before_feature
      before_tags
      after_tags
      feature_name
      before_test_step
      after_test_step
      before_test_step
      before_feature_element
      before_tags
      after_tags
      scenario_name
      before_steps
      before_step
      before_step_result
      step_name
      after_step_result
      after_step
      after_test_step
      after_steps
      after_feature_element
      after_test_case
      after_feature
      after_features
      done
      """
