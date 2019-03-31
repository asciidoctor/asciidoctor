@spawn
Feature: Cucumber --work-in-progress switch
  In order to ensure that feature scenarios do not pass until they are expected to
  Developers should be able to run cucumber in a mode that
            - will fail if any scenario passes completely
            - will not fail otherwise

  Background: A passing and a pending feature
    Given the standard step definitions
    And a file named "features/wip.feature" with:
      """
      Feature: WIP
        @failing
        Scenario: Failing
          Given this step raises an error

        @undefined
        Scenario: Undefined
          Given this step is undefined

        @pending
        Scenario: Pending
          Given this step is pending

        @passing
        Scenario: Passing
          Given this step passes
      """
    And a file named "features/passing_outline.feature" with:
      """
      Feature: Not WIP
        Scenario Outline: Passing
          Given this step <what>

          Examples:
            | what   |
            | passes |
      """

  Scenario: Pass with Failing Scenarios
    When I run `cucumber -q -w -t @failing features/wip.feature`
    Then the stderr should not contain anything
    Then it should pass with:
      """
      Feature: WIP

        @failing
        Scenario: Failing
          Given this step raises an error
            error (RuntimeError)
            ./features/step_definitions/steps.rb:2:in `/^this step raises an error$/'
            features/wip.feature:4:in `Given this step raises an error'

      Failing Scenarios:
      cucumber features/wip.feature:3

      1 scenario (1 failed)
      1 step (1 failed)
      """
    And the output should contain:
      """
      The --wip switch was used, so the failures were expected. All is good.

      """

  Scenario: Pass with Undefined Scenarios
    When I run `cucumber -q -w -t @undefined features/wip.feature`
    Then it should pass with:
      """
      Feature: WIP

        @undefined
        Scenario: Undefined
          Given this step is undefined

      1 scenario (1 undefined)
      1 step (1 undefined)
      """
    And the output should contain:
      """
      The --wip switch was used, so the failures were expected. All is good.

      """

  Scenario: Pass with Undefined Scenarios
    When I run `cucumber -q -w -t @pending features/wip.feature`
    Then it should pass with:
      """
      Feature: WIP

        @pending
        Scenario: Pending
          Given this step is pending
            TODO (Cucumber::Pending)
            ./features/step_definitions/steps.rb:3:in `/^this step is pending$/'
            features/wip.feature:12:in `Given this step is pending'

      1 scenario (1 pending)
      1 step (1 pending)
      """
    And the output should contain:
      """
      The --wip switch was used, so the failures were expected. All is good.

      """

  Scenario: Fail with Passing Scenarios
    When I run `cucumber -q -w -t @passing features/wip.feature`
    Then it should fail with:
      """
      Feature: WIP

        @passing
        Scenario: Passing
          Given this step passes

      1 scenario (1 passed)
      1 step (1 passed)
      """
    And the output should contain:
      """
      The --wip switch was used, so I didn't expect anything to pass. These scenarios passed:
      (::) passed scenarios (::)

      features/wip.feature:15:in `Scenario: Passing'


      """

  Scenario: Fail with Passing Scenario Outline
    When I run `cucumber -q -w features/passing_outline.feature`
    Then it should fail with:
      """
      Feature: Not WIP

        Scenario Outline: Passing
          Given this step <what>

          Examples: 
            | what   |
            | passes |

      1 scenario (1 passed)
      1 step (1 passed)
      """
    And the output should contain:
      """
      The --wip switch was used, so I didn't expect anything to pass. These scenarios passed:
      (::) passed scenarios (::)

      features/passing_outline.feature:7:in `Scenario Outline: Passing, Examples (#1)'


      """
