Feature: Snippets

  Cucumber helpfully prints out any undefined step definitions as a code
  snippet suggestion, which you can then paste into a step definitions
  file of your choosing.

  Scenario: Snippet for undefined step with a pystring
    Given a file named "features/undefined_steps.feature" with:
      """
      Feature:
      Scenario: pystring
        Given a pystring
        \"\"\"
          example with <html> entities
        \"\"\"
        When a simple when step
        And another when step
        Then a simple then step
      """
    When I run `cucumber features/undefined_steps.feature -s`
    Then the output should contain:
      """
      Given(/^a pystring$/) do |string|
        pending # Write code here that turns the phrase above into concrete actions
      end

      When(/^a simple when step$/) do
        pending # Write code here that turns the phrase above into concrete actions
      end

      When(/^another when step$/) do
        pending # Write code here that turns the phrase above into concrete actions
      end

      Then(/^a simple then step$/) do
        pending # Write code here that turns the phrase above into concrete actions
      end
      """

  Scenario: Snippet for undefined step with a step table
    Given a file named "features/undefined_steps.feature" with:
      """
      Feature:
      Scenario: table
        Given a table
          | table |
          |example|
      """
    When I run `cucumber features/undefined_steps.feature -s`
    Then the output should contain:
      """
      Given(/^a table$/) do |table|
        # table is a Cucumber::MultilineArgument::DataTable
        pending # Write code here that turns the phrase above into concrete actions
      end
      """
