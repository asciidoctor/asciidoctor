@spawn
Feature: Unicode in tables

  You are free to use unicode in your tables: we've taken care to
  ensure that the tables are properly aligned so that your output is as
  readable as possible.

  Scenario:
    Given a file named "features/unicode.feature" with:
      """
      Feature: Featuring unicode

        Scenario: table with unicode
          Given passing
            | Brüno | abc |
            | Bruno | æøå |
      """
    When I run `cucumber -q --dry-run features/unicode.feature`
    Then it should pass with:
      """
      Feature: Featuring unicode

        Scenario: table with unicode
          Given passing
            | Brüno | abc |
            | Bruno | æøå |

      1 scenario (1 undefined)
      1 step (1 undefined)

      """

