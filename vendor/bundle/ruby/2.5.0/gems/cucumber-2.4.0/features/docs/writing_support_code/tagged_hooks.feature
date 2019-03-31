Feature: Tagged hooks

  Background:
    Given the standard step definitions
    And a file named "features/support/hooks.rb" with:
      """
      Before('~@no-boom') do 
        raise 'boom'
      end
      """
    And a file named "features/f.feature" with:
      """
      Feature: With and without hooks
        Scenario: using hook
          Given this step passes

        @no-boom
        Scenario: omitting hook
          Given this step passes

        Scenario Outline: omitting hook on specified examples
          Given this step passes

          Examples:
          | Value       |
          | Irrelevant  |

          @no-boom
          Examples:
          | Value           |
          | Also Irrelevant |
      """

  Scenario: omit tagged hook
    When I run `cucumber features/f.feature:2`
    Then it should fail with exactly:
      """
      Feature: With and without hooks
      
        Scenario: using hook     # features/f.feature:2
        boom (RuntimeError)
        ./features/support/hooks.rb:2:in `Before'
          Given this step passes # features/step_definitions/steps.rb:1
      
      Failing Scenarios:
      cucumber features/f.feature:2 # Scenario: using hook
      
      1 scenario (1 failed)
      1 step (1 skipped)
      0m0.012s

      """

    Scenario: omit tagged hook
      When I run `cucumber features/f.feature:6`
      Then it should pass with exactly:
        """
        Feature: With and without hooks

          @no-boom
          Scenario: omitting hook  # features/f.feature:6
            Given this step passes # features/step_definitions/steps.rb:1

        1 scenario (1 passed)
        1 step (1 passed)
        0m0.012s

        """
    Scenario: Omit example hook
      When I run `cucumber features/f.feature:12`
      Then it should fail with exactly:
        """
        Feature: With and without hooks

          Scenario Outline: omitting hook on specified examples # features/f.feature:9
            Given this step passes                              # features/f.feature:10

            Examples: 
              | Value      |
              boom (RuntimeError)
              ./features/support/hooks.rb:2:in `Before'
              | Irrelevant |

        Failing Scenarios:
        cucumber features/f.feature:14 # Scenario Outline: omitting hook on specified examples, Examples (#1)

        1 scenario (1 failed)
        1 step (1 skipped)
        0m0.012s

      """
    Scenario: 
      When I run `cucumber features/f.feature:17`
      Then it should pass

