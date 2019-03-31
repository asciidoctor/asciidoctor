Feature: Dry Run

  Dry run gives you a way to quickly scan your features without actually running them.

  - Invokes formatters without executing the steps.
  - This also omits the loading of your support/env.rb file if it exists.

  Scenario: With a failing step
    Given a file named "features/test.feature" with:
      """
      Feature: test
        Scenario:
          Given this step fails
      """
    And the standard step definitions
    When I run `cucumber --dry-run`
    Then it should pass with exactly:
      """
      Feature: test

        Scenario:               # features/test.feature:2
          Given this step fails # features/step_definitions/steps.rb:4

      1 scenario (1 skipped)
      1 step (1 skipped)

      """

  Scenario: In strict mode
    Given a file named "features/test.feature" with:
      """
      Feature: test
        Scenario:
          Given this step fails
      """
    And the standard step definitions
    When I run `cucumber --dry-run --strict`
    Then it should pass with exactly:
      """
      Feature: test

        Scenario:               # features/test.feature:2
          Given this step fails # features/step_definitions/steps.rb:4

      1 scenario (1 skipped)
      1 step (1 skipped)

      """

  Scenario: In strict mode with an undefined step
    Given a file named "features/test.feature" with:
      """
      Feature: test
        Scenario:
          Given this step is undefined
      """
    When I run `cucumber --dry-run --strict`
    Then it should fail with:
      """
      Feature: test

        Scenario:                      # features/test.feature:2
          Given this step is undefined # features/test.feature:3
            Undefined step: "this step is undefined" (Cucumber::Undefined)
            features/test.feature:3:in `Given this step is undefined'

      1 scenario (1 undefined)
      1 step (1 undefined)

      """
