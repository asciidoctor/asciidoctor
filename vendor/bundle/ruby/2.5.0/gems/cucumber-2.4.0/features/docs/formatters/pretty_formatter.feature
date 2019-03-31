Feature: Pretty output formatter

  Background:
    Given a file named "features/scenario_outline_with_undefined_steps.feature" with:
      """
      Feature:

        Scenario Outline:
          Given this step is undefined

        Examples:
          |foo|
          |bar|
      """

  Scenario: an scenario outline, one undefined step, one random example, expand flag on
    When I run `cucumber features/scenario_outline_with_undefined_steps.feature --format pretty --expand `
    Then it should pass

  Scenario: when using a profile the output should include 'Using the default profile...'
    And a file named "cucumber.yml" with:
    """
      default: -r features
    """
    When I run `cucumber --profile default --format pretty`
    Then it should pass
    And the output should contain:
    """
    Using the default profile...
    """
  Scenario: Hook output should be printed before hook exception
    Given the standard step definitions
    And a file named "features/test.feature" with:
      """
      Feature:
        Scenario:
          Given this step passes
      """
    And a file named "features/step_definitions/output_steps.rb" with:
      """
      Before do
        puts "Before hook"
       end

      AfterStep do
        puts "AfterStep hook"
      end

      After do
        puts "After hook"
	raise "error"
      end
      """
    When I run `cucumber -q -f pretty features/test.feature`
    Then the stderr should not contain anything
    Then it should fail with:
      """
      Feature: 
 
        Scenario: 
            Before hook
          Given this step passes
            AfterStep hook
            After hook
            error (RuntimeError)
            ./features/step_definitions/output_steps.rb:11:in `After'
      
      Failing Scenarios:
      cucumber features/test.feature:2
      
      1 scenario (1 failed)
      1 step (1 passed)
      """
