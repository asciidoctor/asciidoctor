Feature: Rerun formatter

  The rerun formatter writes an output that's perfect for
  passing to Cucumber when you want to rerun only the 
  scenarios that prevented the exit code to be zero.

  You can save off the rerun output to a file by using it like this:

  `cucumber -f rerun --out .cucumber.rerun`

  Now you can pass that file's content to Cucumber to tell it
  which scenarios to run:

  `cucumber \`cat .cucumber.rerun\``

  This is useful when debugging in a large suite of features.

  Background:
    Given the standard step definitions

  Scenario: Exit code is zero
    Given a file named "features/mixed.feature" with:
      """
      Feature: Mixed

        Scenario:
          Given this step is undefined

        Scenario:
          Given this step is pending

        Scenario:
          Given this step passes

      """

    When I run `cucumber -f rerun`
    Then it should pass with exactly:
      """
      """

  Scenario: Exit code is zero in the dry-run mode
    Given a file named "features/mixed.feature" with:
      """
      Feature: Mixed

        Scenario:
          Given this step fails

        Scenario:
          Given this step is undefined

        Scenario:
          Given this step is pending

        Scenario:
          Given this step passes

      """
    And a file named "features/all_good.feature" with:
      """
      Feature: All good

        Scenario:
          Given this step passes
      """

    When I run `cucumber -f rerun --dry-run`
    Then it should pass with exactly:
      """
      """

  Scenario: Exit code is not zero, regular scenario
    Given a file named "features/mixed.feature" with:
      """
      Feature: Mixed

        Scenario:
          Given this step fails

        Scenario:
          Given this step is undefined

        Scenario:
          Given this step is pending

        Scenario:
          Given this step passes

      """
    And a file named "features/all_good.feature" with:
      """
      Feature: All good

        Scenario:
          Given this step passes
      """

    When I run `cucumber -f rerun --strict`
    Then it should fail with exactly:
      """
      features/mixed.feature:3:6:9
      """

  Scenario: Exit code is not zero, scenario outlines
    For details see https://github.com/cucumber/cucumber/issues/57
    Given a file named "features/one_passing_one_failing.feature" with:
      """
      Feature: One passing example, one failing example

        Scenario Outline:
          Given this step <status>
        
        Examples:
          | status |
          | passes |
          | fails  |

      """
    When I run `cucumber -f rerun`
    Then it should fail with:
    """
    features/one_passing_one_failing.feature:9
    """

  Scenario: Exit code is not zero, failing background
    Given a file named "features/failing_background.feature" with:
      """
      Feature: Failing background sample

        Background:
          Given this step fails

        Scenario: failing background
          Then this step passes

        Scenario: another failing background
          Then this step passes
      """
    When I run `cucumber -f rerun`
    Then it should fail with:
    """
    features/failing_background.feature:6:9
    """

  Scenario: Exit code is not zero, failing background with scenario outline
    Given a file named "features/failing_background_outline.feature" with:
      """
      Feature: Failing background sample with scenario outline

        Background:
          Given this step fails

        Scenario Outline:
          Then this step <status>

        Examples:
          | status |
          | passes |
          | passes |
      """
    When I run `cucumber features/failing_background_outline.feature -r features -f rerun`
    Then it should fail with:
    """
    features/failing_background_outline.feature:11:12
    """

  Scenario: Exit code is not zero, scenario outlines with expand
    For details see https://github.com/cucumber/cucumber/issues/503

    Given a file named "features/one_passing_one_failing.feature" with:
    """
      Feature: One passing example, one failing example

        Scenario Outline:
          Given this step <status>

        Examples:
          | status |
          | passes |
          | fails  |

      """
    When I run `cucumber --expand -f rerun`
    Then it should fail with:
    """
    features/one_passing_one_failing.feature:9
    """
