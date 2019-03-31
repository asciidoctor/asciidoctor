Feature: Using star notation instead of Given/When/Then

  Cucumber supports the star notation when writing features: instead of
  using Given/When/Then, you can simply use a star rather like you would
  use a bullet point.

  When you run the feature for the first time, you still get a nice
  message showing you the code snippet you need to use to implement the
  step.

  Scenario: Use some *
    Given a file named "features/f.feature" with:
      """
      Feature: Star-notation feature
        Scenario: S
          * I have some cukes
      """
    When I run `cucumber features/f.feature`
    Then the stderr should not contain anything
    And it should pass with:
      """
      Feature: Star-notation feature

        Scenario: S           # features/f.feature:2
          * I have some cukes # features/f.feature:3

      1 scenario (1 undefined)
      1 step (1 undefined)
      """
    And it should pass with:
      """
      You can implement step definitions for undefined steps with these snippets:

      Given(/^I have some cukes$/) do
        pending # Write code here that turns the phrase above into concrete actions
      end
      """
