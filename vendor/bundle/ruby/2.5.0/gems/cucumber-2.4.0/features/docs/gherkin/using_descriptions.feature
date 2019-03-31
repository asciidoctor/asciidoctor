Feature: Using descriptions to give features context

  When writing your feature files its very helpful to use description
  text at the beginning of the feature file, to write a preamble to the
  feature describing clearly exactly what the feature does.

  You can also write descriptions attached to individual scenarios - see
  the examples below for how this can be used.

  It's possible to have your descriptions run over more than one line,
  and you can have blank lines too. As long as you don't start a line
  with a Given, When, Then, Background:, Scenario: or similar, you're
  fine: otherwise Gherkin will start to pay attention.

  Background:
    Given the standard step definitions

  Scenario: Everything with a description
    Given a file named "features/test.feature" with:
    """
    Feature: descriptions everywhere

      We can put a useful description here of the feature, which can
      span multiple lines.

      Background:

        We can also put in descriptions showing what the background is
        doing.

        Given this step passes

      Scenario: I'm a scenario with a description

        You can also put descriptions in front of individual scenarios.

        Given this step passes

      Scenario Outline: I'm a scenario outline with a description

        Scenario outlines can have descriptions.

        Given this step <state>
        Examples: Examples

          Specific examples for an outline are allowed to have
          descriptions, too.

          |  state |
          | passes |
    """
    When I run `cucumber -q`
    Then the stderr should not contain anything
    Then it should pass with exactly:
    """
    Feature: descriptions everywhere
      We can put a useful description here of the feature, which can
      span multiple lines.

      Background: 
        We can also put in descriptions showing what the background is
        doing.
        Given this step passes

      Scenario: I'm a scenario with a description
        You can also put descriptions in front of individual scenarios.
        Given this step passes

      Scenario Outline: I'm a scenario outline with a description
        Scenario outlines can have descriptions.
        Given this step <state>

        Examples: Examples
          Specific examples for an outline are allowed to have
          descriptions, too.
          | state  |
          | passes |

    2 scenarios (2 passed)
    4 steps (4 passed)

    """
