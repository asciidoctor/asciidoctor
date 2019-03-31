Feature: Loading the steps users expect
  As a User
  In order to run features in subdirectories without having to pass extra options
  I want cucumber to load all step files

  Scenario:
    Given a file named "features/nesting/test.feature" with:
      """
      Feature: Feature in Subdirectory
        Scenario: A step not in the subdirectory
          Given not found in subdirectory
      """
    And a file named "features/step_definitions/steps_no_in_subdirectory.rb" with:
      """
      Given(/^not found in subdirectory$/) { }
      """
    When I run `cucumber -q features/nesting/test.feature`
    Then it should pass with:
      """
      Feature: Feature in Subdirectory

        Scenario: A step not in the subdirectory
          Given not found in subdirectory

      1 scenario (1 passed)
      1 step (1 passed)
      """

