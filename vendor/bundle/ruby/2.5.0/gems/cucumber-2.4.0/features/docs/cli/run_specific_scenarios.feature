Feature: Run specific scenarios

  You can choose to run a specific scenario using the file:line format,
  or you can pass in a file with a list of scenarios using @-notation.

  The line number can fall anywhere within the body of a scenario, including
  steps, tags, comments, description, data tables or doc strings.

  For scenario outlines, if the line hits one example row, just that one
  will be run. Otherwise all examples in the table or outline will be run.

  Background:
    Given the standard step definitions

  Scenario: Two scenarios, run just one of them
    Given a file named "features/test.feature" with:
      """
      Feature: 

        Scenario: Miss
          Given this step is undefined

        Scenario: Hit
          Given this step passes
      """
    When I run `cucumber features/test.feature:7 --format pretty --quiet`
    Then it should pass with exactly:
      """
      Feature: 

        Scenario: Hit
          Given this step passes

      1 scenario (1 passed)
      1 step (1 passed)
      
      """

  Scenario: Use @-notation to specify a file containing feature file list
    Given a file named "features/test.feature" with:
      """
      Feature: Sample
        Scenario: Passing
          Given this step passes
      """
    And a file named "list-of-features.txt" with:
      """
      features/test.feature:2
      """
    When I run `cucumber -q @list-of-features.txt`
    Then it should pass with:
      """
      Feature: Sample

        Scenario: Passing
          Given this step passes

      1 scenario (1 passed)
      1 step (1 passed)
      """

  Scenario: Specify order of scenarios
    Given a file named "features/test.feature" with:
      """
      Feature: 
        Scenario:
          Given this step passes

        Scenario:
          Given this step fails
      """
    When I run `cucumber features/test.feature:5 features/test.feature:3 -f progress`
    Then it should fail with:
      """
      F.
      """

