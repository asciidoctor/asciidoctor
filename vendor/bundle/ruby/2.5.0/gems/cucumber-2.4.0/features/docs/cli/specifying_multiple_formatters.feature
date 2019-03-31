@spawn
Feature: Running multiple formatters

  When running cucumber, you are able to using multiple different
  formatters and redirect the output to text files.
  Two formatters cannot both print to the same file (or to STDOUT)

  Background:
    Given a file named "features/test.feature" with:
    """
    Feature: Lots of undefined

      Scenario: Implement me
        Given it snows in Sahara
        Given it's 40 degrees in Norway
        And it's 40 degrees in Norway
        When I stop procrastinating
        And there is world peace
    """

  Scenario: Multiple formatters and outputs
    When I run `cucumber --no-color --format progress --out progress.txt --format pretty --out pretty.txt --no-source --dry-run --no-snippets features/test.feature`
    Then the stderr should not contain anything
    Then the file "progress.txt" should contain:
      """
      UUUUU

      1 scenario (1 undefined)
      5 steps (5 undefined)

      """
    And the file "pretty.txt" should contain:
      """
      Feature: Lots of undefined

        Scenario: Implement me
          Given it snows in Sahara
          Given it's 40 degrees in Norway
          And it's 40 degrees in Norway
          When I stop procrastinating
          And there is world peace

      1 scenario (1 undefined)
      5 steps (5 undefined)

      """

  Scenario: Two formatters to stdout
    When I run `cucumber -f progress -f pretty features/test.feature`
    Then it should fail with:
      """
      All but one formatter must use --out, only one can print to each stream (or STDOUT) (RuntimeError)
      """

  Scenario: Two formatters to stdout when using a profile
    Given the following profiles are defined:
      """
      default: -q
      """
    When I run `cucumber -f progress -f pretty features/test.feature`
    Then it should fail with:
      """
      All but one formatter must use --out, only one can print to each stream (or STDOUT) (RuntimeError)
      """

