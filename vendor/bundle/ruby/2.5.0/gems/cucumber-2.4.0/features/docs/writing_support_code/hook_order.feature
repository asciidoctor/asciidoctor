  @spawn
  Feature: Hooks execute in defined order

  Background:
    Given a file named "features/step_definitions/steps.rb" with:
      """
      Given /^background step$/ do; $EventOrder.push(:background_step) end
      Given /^scenario step$/ do; $EventOrder.push(:scenario_step) end
      """
    And a file named "features/support/hooks.rb" with:
      """
      $EventOrder = []
      Around('@around') do |scenario,block|
        $EventOrder.push :around_begin
        block.call
        $EventOrder.push :around_end
      end
      Before('@before') do
        $EventOrder.push :before
      end
      After('@after') do |scenario|
        $EventOrder.push :after
      end
      at_exit {
        puts "Event order: #{$EventOrder.join(' ')}"
      }
      """
    And a file named "features/around_hook_covers_background.feature" with:
      """
      @around
      Feature: Around hooks cover background steps
        Background:
          Given background step
        Scenario:
          Given scenario step
      """
    And a file named "features/all_hook_order.feature" with:
      """
      @around
      @before
      @after
      Feature: All hooks execute in expected order
        Background:
          Given background step
        Scenario:
          Given scenario step
      """

  Scenario: Around hooks cover background steps
    When I run `cucumber -o /dev/null features/around_hook_covers_background.feature`
    Then the output should contain:
      """
      Event order: around_begin background_step scenario_step around_end
      """

  Scenario: All hooks execute in expected order
    When I run `cucumber -o /dev/null features/all_hook_order.feature`
    Then the output should contain:
      """
      Event order: around_begin before background_step scenario_step after around_end
      """