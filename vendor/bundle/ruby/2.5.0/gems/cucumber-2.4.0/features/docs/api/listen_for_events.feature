Feature: Listen for events

  Scenario: Step Matched Event
    Given a file named "features/test.feature" with:
      """
      Feature:
        Scenario:
          Given matching
      """
    And a file named "features/step_definitions/steps.rb" with:
      """
      Given(/matching/) do
      end
      """
    And a file named "features/support/my_listener.rb" with:
      """
      AfterConfiguration do |config|
        io = config.out_stream
        config.on_event Cucumber::Events::StepMatch do |event|
          io.puts "Success!"
          io.puts "Event type:      #{event.class}"
          io.puts "Step name:       #{event.test_step.name}"
          io.puts "Source location: #{event.step_match.location}"
        end
      end
      """
    When I run `cucumber`
    Then it should pass with:
      """
      Success!
      Event type:      Cucumber::Events::StepMatch
      Step name:       matching
      Source location: features/step_definitions/steps.rb:1
      """

  Scenario: After Test Step event
    Given a file named "features/test.feature" with:
      """
      Feature:
        Scenario:
          Given passing
      """
    And the standard step definitions
    And a file named "features/support/my_listener.rb" with:
      """
      AfterConfiguration do |config|
        io = config.out_stream
        config.on_event Cucumber::Events::AfterTestStep do |event|
          io.puts "YO"
        end
      end
      """
    When I run `cucumber`
    Then it should pass with:
      """
      YO
      """

