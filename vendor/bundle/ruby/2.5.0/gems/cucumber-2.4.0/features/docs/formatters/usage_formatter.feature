Feature: Usage formatter

  In order to see where step definitions are used
  Developers should be able to see a list of step definitions and their use

  Background:
    Given a file named "features/f.feature" with:
      """
      Feature: F
        Background: A
          Given A
        Scenario: B
          Given B
        Scenario Outline: CA
          Given <x>
          And B
          Examples:
            |x|
            |C|
            |A|
        Scenario: AC
          Given A
          Given C
      """
    And a file named "features/step_definitions/steps.rb" with:
      """
      Given(/A/) { }
      Given(/B/) { }
      Given(/C/) { }
      Given(/D/) { }
      """

  Scenario: Run with --format usage
    When I run `cucumber -f usage --dry-run`
    Then it should pass with exactly:
      """
      -----------
      
      /A/       # features/step_definitions/steps.rb:1
        Given A # features/f.feature:3
        Given A # features/f.feature:12
        Given A # features/f.feature:14
      /B/       # features/step_definitions/steps.rb:2
        Given B # features/f.feature:5
        And B   # features/f.feature:11
        And B   # features/f.feature:12
      /C/       # features/step_definitions/steps.rb:3
        Given C # features/f.feature:11
        Given C # features/f.feature:15
      /D/       # features/step_definitions/steps.rb:4
        NOT MATCHED BY ANY STEPS
      
      4 scenarios (4 skipped)
      11 steps (11 skipped)

      """

  Scenario: Run with --expand --format usage
    When I run `cucumber -x -f usage --dry-run`
    Then it should pass with exactly:
      """
      -----------
      
      /A/       # features/step_definitions/steps.rb:1
        Given A # features/f.feature:3
        Given A # features/f.feature:12
        Given A # features/f.feature:14
      /B/       # features/step_definitions/steps.rb:2
        Given B # features/f.feature:5
        And B   # features/f.feature:11
        And B   # features/f.feature:12
      /C/       # features/step_definitions/steps.rb:3
        Given C # features/f.feature:11
        Given C # features/f.feature:15
      /D/       # features/step_definitions/steps.rb:4
        NOT MATCHED BY ANY STEPS
      
      4 scenarios (4 skipped)
      11 steps (11 skipped)

      """

    Scenario: Run with --format stepdefs
      When I run `cucumber -f stepdefs --dry-run`
      Then it should pass with exactly:
        """
        -----------
        
        /A/   # features/step_definitions/steps.rb:1
        /B/   # features/step_definitions/steps.rb:2
        /C/   # features/step_definitions/steps.rb:3
        /D/   # features/step_definitions/steps.rb:4
          NOT MATCHED BY ANY STEPS
        
        4 scenarios (4 skipped)
        11 steps (11 skipped)

        """
