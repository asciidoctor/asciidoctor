@spawn
Feature: Fail fast

  The --fail-fast flag causes Cucumber to exit immediately after the first 
  scenario fails.

  Scenario: When a scenario fails
    Given a file named "features/bad.feature" with:
      """
      Feature: Bad
        Scenario: Failing
          Given this step fails
      """
    And a file named "features/good.feature" with:
    """
    Feature: Good
      Scenario: Passing
        Given this step passes
    """
    And the standard step definitions
    When I run `cucumber --fail-fast`
    Then it should fail
    And the output should contain:
    """
    1 scenario (1 failed)
    """

  Scenario: When all the scenarios pass
    Given a file named "features/first.feature" with:
      """
      Feature: first feature
        Scenario: foo first
          Given this step passes
        Scenario: bar first
          Given this step passes
      """
    And a file named "features/second.feature" with:
      """
      Feature: second
        Scenario: foo second
          Given this step passes
        Scenario: bar second
          Given this step passes
      """
    When I run `cucumber --fail-fast`
    Then it should pass
