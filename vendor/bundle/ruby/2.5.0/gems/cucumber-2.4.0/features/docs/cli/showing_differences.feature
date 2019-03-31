Feature: Showing differences to expected output

  Cucumber will helpfully show you the expectation error that your
  testing library gives you, in the context of the failing scenario.
  When using RSpec, for example, this will show the difference between
  the expected and the actual output.

  Scenario: Run single failing scenario with default diff enabled
    Given a file named "features/failing_expectation.feature" with:
      """
      Feature: Failing expectation

        Scenario: Failing expectation
          Given failing expectation
      """
    And a file named "features/step_definitions/steps.rb" with:
      """
      Given /^failing expectation$/ do x=1
        expect('this').to eq 'that'
      end
      """
    When I run `cucumber -q features/failing_expectation.feature`
    Then it should fail with:
      """
      Feature: Failing expectation
      
        Scenario: Failing expectation
          Given failing expectation
            
            expected: "that"
                 got: "this"
            
            (compared using ==)
             (RSpec::Expectations::ExpectationNotMetError)
            ./features/step_definitions/steps.rb:2:in `/^failing expectation$/'
            features/failing_expectation.feature:4:in `Given failing expectation'

      Failing Scenarios:
      cucumber features/failing_expectation.feature:3

      1 scenario (1 failed)
      1 step (1 failed)
      """
