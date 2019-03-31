Feature: Run feature elements matching a name with --name/-n

  The `--name NAME` option runs only scenarios which match a certain
  name. The NAME can be a substring of the names of Features, Scenarios,
  Scenario Outlines or Example blocks.

  Background:
    Given a file named "features/first.feature" with:
      """
      Feature: first feature
        Scenario: foo first
          Given missing
        Scenario: bar first
          Given missing
      """
    Given a file named "features/second.feature" with:
      """
      Feature: second
        Scenario: foo second
          Given missing
        Scenario: bar second
          Given missing
      """
    Given a file named "features/outline.feature" with:
      """
      Feature: outline
        Scenario Outline: baz outline
          Given outline step <name>

          Examples: quux example
            | name |
            | a    |
            | b    |
      """

  Scenario: Matching Feature names
    When I run `cucumber -q --name feature`
    Then it should pass with:
      """
      Feature: first feature

        Scenario: foo first
          Given missing

        Scenario: bar first
          Given missing

      2 scenarios (2 undefined)
      2 steps (2 undefined)
      """

  Scenario: Matching Scenario names
    When I run `cucumber -q --name foo`
    Then it should pass with:
      """
      Feature: first feature

        Scenario: foo first
          Given missing

      Feature: second

        Scenario: foo second
          Given missing

      2 scenarios (2 undefined)
      2 steps (2 undefined)
      """

  Scenario: Matching Scenario Outline names
    When I run `cucumber -q --name baz`
    Then it should pass with:
      """
      Feature: outline

        Scenario Outline: baz outline
          Given outline step <name>

          Examples: quux example
            | name |
            | a    |
            | b    |

      2 scenarios (2 undefined)
      2 steps (2 undefined)
      """

  Scenario: Matching Example block names
    When I run `cucumber -q --name quux`
    Then it should pass with:
      """
      Feature: outline

        Scenario Outline: baz outline
          Given outline step <name>

          Examples: quux example
            | name |
            | a    |
            | b    |

      2 scenarios (2 undefined)
      2 steps (2 undefined)
      """
