Feature: Exceptions in Around Hooks

  Around hooks are awkward beasts to handle internally.

  Right now, if there's an error in your Around hook before you call `block.call`,
  we won't even print the steps for the scenario.

  This is because that `block.call` invokes all the logic that would tell Cucumber's
  UI about the steps in your scenario. If we never reach that code, we'll never be
  told about them.

  There's another scenario to consider, where the exception occurs after the steps
  have been run. How would we want to report in that case?

  Scenario: Exception before the test case is run
    Given the standard step definitions
    And a file named "features/support/env.rb" with:
      """
      Around do |scenario, block|
        fail "this should be reported"
        block.call
      end
      """
    And a file named "features/test.feature" with:
      """
      Feature:
        Scenario:
          Given this step passes
      """
    When I run `cucumber -q`
    Then it should fail with exactly:
      """
      Feature: 

        Scenario: 
        this should be reported (RuntimeError)
        ./features/support/env.rb:2:in `Around'
      
      Failing Scenarios:
      cucumber features/test.feature:2
      
      1 scenario (1 failed)
      0 steps
      
      """

  Scenario: Exception after the test case is run
    Given the standard step definitions
    And a file named "features/support/env.rb" with:
      """
      Around do |scenario, block|
        block.call
        fail "this should be reported"
      end
      """
    And a file named "features/test.feature" with:
      """
      Feature:
        Scenario:
          Given this step passes
      """
    When I run `cucumber -q`
    Then it should fail with exactly:
      """
      Feature: 

        Scenario: 
          Given this step passes
            this should be reported (RuntimeError)
            ./features/support/env.rb:3:in `Around'
      
      Failing Scenarios:
      cucumber features/test.feature:2
      
      1 scenario (1 failed)
      1 step (1 passed)

      """
