@spawn
Feature: Scenario outlines

  Copying and pasting scenarios to use different values quickly
  becomes tedious and repetitive. Scenario outlines allow us to more
  concisely express these examples through the use of a template with
  placeholders, using Scenario Outline, Examples with tables and < >
  delimited parameters.

  The Scenario Outline steps provide a template which is never directly
  run. A Scenario Outline is run once for each row in the Examples section
  beneath it (not counting the first row).

  The way this works is via placeholders. Placeholders must be contained
  within < > in the Scenario Outline's steps - see the examples below.

  **IMPORTANT:** Your step definitions will never have to match a
  placeholder. They will need to match the values that will replace the
  placeholder.

  Background:
    Given a file named "features/outline_sample.feature" with:
      """
      Feature: Outline Sample

        Scenario: I have no steps

        Scenario Outline: Test state
          Given <state> without a table
          Given <other_state> without a table
        Examples: Rainbow colours
          | state    | other_state |
          | missing  | passing     |
          | passing  | passing     |
          | failing  | passing     |
      Examples:Only passing
          | state    | other_state |
          | passing  | passing     |
      """
    And a file named "features/step_definitions/steps.rb" with:
      """
      Given(/^passing without a table$/) { }
      Given(/^failing without a table$/) { raise RuntimeError }
      """

  Scenario: Run scenario outline with filtering on outline name
    When I run `cucumber -q features/outline_sample.feature`
    Then it should fail with:
      """
      Feature: Outline Sample

        Scenario: I have no steps

        Scenario Outline: Test state
          Given <state> without a table
          Given <other_state> without a table

          Examples: Rainbow colours
            | state   | other_state |
            | missing | passing     |
            | passing | passing     |
            | failing | passing     |
            RuntimeError (RuntimeError)
            ./features/step_definitions/steps.rb:2:in `/^failing without a table$/'
            features/outline_sample.feature:12:in `Given failing without a table'
            features/outline_sample.feature:6:in `Given <state> without a table'

          Examples: Only passing
            | state   | other_state |
            | passing | passing     |

      Failing Scenarios:
      cucumber features/outline_sample.feature:12

      5 scenarios (1 failed, 1 undefined, 3 passed)
      8 steps (1 failed, 2 skipped, 1 undefined, 4 passed)
      """

  Scenario: Run scenario outline steps only
    When I run `cucumber -q features/outline_sample.feature:7`
    Then it should fail with:
      """
      Feature: Outline Sample

        Scenario Outline: Test state
          Given <state> without a table
          Given <other_state> without a table

          Examples: Rainbow colours
            | state   | other_state |
            | missing | passing     |
            | passing | passing     |
            | failing | passing     |
            RuntimeError (RuntimeError)
            ./features/step_definitions/steps.rb:2:in `/^failing without a table$/'
            features/outline_sample.feature:12:in `Given failing without a table'
            features/outline_sample.feature:6:in `Given <state> without a table'

          Examples: Only passing
            | state   | other_state |
            | passing | passing     |

      Failing Scenarios:
      cucumber features/outline_sample.feature:12

      4 scenarios (1 failed, 1 undefined, 2 passed)
      8 steps (1 failed, 2 skipped, 1 undefined, 4 passed)

      """

  Scenario: Run single failing scenario outline table row
    When I run `cucumber -q features/outline_sample.feature:12`
    Then it should fail with:
      """
      Feature: Outline Sample

        Scenario Outline: Test state
          Given <state> without a table
          Given <other_state> without a table

          Examples: Rainbow colours
            | state   | other_state |
            | failing | passing     |
            RuntimeError (RuntimeError)
            ./features/step_definitions/steps.rb:2:in `/^failing without a table$/'
            features/outline_sample.feature:12:in `Given failing without a table'
            features/outline_sample.feature:6:in `Given <state> without a table'

      Failing Scenarios:
      cucumber features/outline_sample.feature:12

      1 scenario (1 failed)
      2 steps (1 failed, 1 skipped)

      """

  Scenario: Run all with progress formatter
    When I run `cucumber -q --format progress features/outline_sample.feature`
    Then it should fail with exactly:
      """
      U-..F-..

      (::) failed steps (::)

      RuntimeError (RuntimeError)
      ./features/step_definitions/steps.rb:2:in `/^failing without a table$/'
      features/outline_sample.feature:12:in `Given failing without a table'
      features/outline_sample.feature:6:in `Given <state> without a table'

      Failing Scenarios:
      cucumber features/outline_sample.feature:12

      5 scenarios (1 failed, 1 undefined, 3 passed)
      8 steps (1 failed, 2 skipped, 1 undefined, 4 passed)

      """
