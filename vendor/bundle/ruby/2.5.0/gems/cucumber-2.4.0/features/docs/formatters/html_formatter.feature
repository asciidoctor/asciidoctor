Feature: HTML output formatter

  Background:
    Given the standard step definitions
    And a file named "features/scenario_outline_with_undefined_steps.feature" with:
      """
      Feature:

        Scenario Outline:
          Given this step is undefined

        Examples:
          |foo|
          |bar|
      """
    And a file named "features/scenario_outline_with_pending_step.feature" with:
      """
      Feature: Outline

        Scenario Outline: Will it blend?
          Given this step is pending
          And other step
          When I do something with <example>
          Then I should see something
          Examples:
            | example |
            | one     |
            | two     |
            | three   |
      """
    And a file named "features/failing_background_step.feature" with:
      """
      Feature: Feature with failing background step

        Background:
          Given this step fails

        Scenario:
          When I do something
          Then I should see something
      """

  Scenario: an scenario outline, one undefined step, one random example, expand flag on
    When I run `cucumber features/scenario_outline_with_undefined_steps.feature --format html --expand `
    Then it should pass

  Scenario Outline: an scenario outline, one pending step
    When I run `cucumber <file> --format html <flag>`
    Then it should pass
    And the output should contain:
    """
    makeYellow('scenario_1')
    """
    And the output should not contain:
    """
    makeRed('scenario_1')
    """

    Examples:
      | file                                                   | flag     |
      | features/scenario_outline_with_pending_step.feature    | --expand |
      | features/scenario_outline_with_pending_step.feature    |          |

    Examples:
      | file                                                   | flag     |
      | features/scenario_outline_with_undefined_steps.feature | --expand |
      | features/scenario_outline_with_undefined_steps.feature |          |

  Scenario: when using a profile the html shouldn't include 'Using the default profile...'
    And a file named "cucumber.yml" with:
    """
      default: -r features
    """
    When I run `cucumber features/scenario_outline_with_undefined_steps.feature --profile default --format html`
    Then it should pass
    And the output should not contain:
    """
    Using the default profile...
    """

  Scenario: a feature with a failing background step
    When I run `cucumber features/failing_background_step.feature --format html`
    Then the output should not contain:
    """
    makeRed('scenario_0')
    """
    And the output should contain:
    """
    makeRed('background_0')
    """

