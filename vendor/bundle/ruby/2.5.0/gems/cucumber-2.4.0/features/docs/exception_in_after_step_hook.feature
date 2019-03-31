Feature: Exception in AfterStep Block
  In order to use custom assertions at the end of each step
  As a developer
  I want exceptions raised in AfterStep blocks to be handled gracefully and reported by the formatters

  Background:
    Given the standard step definitions
    And a file named "features/step_definitions/naughty_steps.rb" with:
      """
      Given /^this step does something naughty$/ do x=1
        @naughty = true
      end
      """
    And a file named "features/support/env.rb" with:
      """
      class NaughtyStepException < Exception; end
      AfterStep do
        if @naughty
          raise NaughtyStepException.new("This step has been very very naughty")
        end
      end
      """

  Scenario: Handle Exception in standard scenario step and carry on
    Given a file named "features/naughty_step_in_scenario.feature" with:
      """
      Feature: Sample

        Scenario: Naughty Step
          Given this step does something naughty

        Scenario: Success
          Given this step passes
      """
    When I run `cucumber features`
    Then it should fail with:
      """
      Feature: Sample

        Scenario: Naughty Step                   # features/naughty_step_in_scenario.feature:3
          Given this step does something naughty # features/step_definitions/naughty_steps.rb:1
            This step has been very very naughty (NaughtyStepException)
            ./features/support/env.rb:4:in `AfterStep'
            features/naughty_step_in_scenario.feature:4:in `Given this step does something naughty'

        Scenario: Success        # features/naughty_step_in_scenario.feature:6
          Given this step passes # features/step_definitions/steps.rb:1

      Failing Scenarios:
      cucumber features/naughty_step_in_scenario.feature:3 # Scenario: Naughty Step

      2 scenarios (1 failed, 1 passed)
      2 steps (2 passed)

      """

  Scenario: Handle Exception in scenario outline table row and carry on
    Given a file named "features/naughty_step_in_scenario_outline.feature" with:
      """
      Feature: Sample

        Scenario Outline: Naughty Step
          Given this step <Might Work>

          Examples:
          | Might Work             |
          | passes                 |
          | does something naughty |
          | passes                 |

        Scenario: Success
          Given this step passes

      """
    When I run `cucumber features`
    Then it should fail with:
      """
      Feature: Sample

        Scenario Outline: Naughty Step # features/naughty_step_in_scenario_outline.feature:3
          Given this step <Might Work> # features/naughty_step_in_scenario_outline.feature:4

          Examples: 
            | Might Work             |
            | passes                 |
            | does something naughty |
            This step has been very very naughty (NaughtyStepException)
            ./features/support/env.rb:4:in `AfterStep'
            features/naughty_step_in_scenario_outline.feature:9:in `Given this step does something naughty'
            features/naughty_step_in_scenario_outline.feature:4:in `Given this step <Might Work>'
            | passes                 |

        Scenario: Success        # features/naughty_step_in_scenario_outline.feature:12
          Given this step passes # features/step_definitions/steps.rb:1

      Failing Scenarios:
      cucumber features/naughty_step_in_scenario_outline.feature:9 # Scenario Outline: Naughty Step, Examples (#2)

      4 scenarios (1 failed, 3 passed)
      4 steps (4 passed)

      """
