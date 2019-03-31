Feature: Nested Steps

  Background:
    Given a scenario with a step that looks like this:
      """gherkin
      Given two turtles
      """
    And a step definition that looks like this:
      """ruby
      Given /a turtle/ do
        puts "turtle!"
      end
      """

  Scenario: Use #steps to call several steps at once
    Given a step definition that looks like this:
      """ruby
      Given /two turtles/ do
        steps %{
          Given a turtle
          And a turtle
        }
      end
      """
    When I run the feature with the progress formatter
    Then the output should contain:
      """
      turtle!

      turtle!

      """

  Scenario: Use #step to call a single step
    Given a step definition that looks like this:
      """ruby
      Given /two turtles/ do
        step "a turtle"
        step "a turtle"
      end
      """
    When I run the feature with the progress formatter
    Then the output should contain:
      """
      turtle!

      turtle!

      """

  Scenario: Use #steps to call a table
    Given a step definition that looks like this:
      """ruby
      Given /turtles:/ do |table|
        table.hashes.each do |row|
          puts row[:name]
        end
      end
      """
    And a step definition that looks like this:
      """ruby
      Given /two turtles/ do
        steps %{
          Given turtles:
            | name      |
            | Sturm     |
            | Liouville |
        }
      end
      """
    When I run the feature with the progress formatter
    Then the output should contain:
      """
      Sturm

      Liouville

      """

  Scenario: Use #steps to call a multi-line string
    Given a step definition that looks like this:
      """ruby
        Given /two turtles/ do
          steps %Q{
            Given turtles:
               \"\"\"
               Sturm
               Liouville
               \"\"\"
          }
        end
      """
    And a step definition that looks like this:
      """ruby
      Given /turtles:/ do |string|
        puts string
      end
      """
    When I run the feature with the progress formatter
    Then the output should contain:
      """
      Sturm
      Liouville
      """

  @spawn
  Scenario: Backtrace doesn't skip nested steps
    Given a step definition that looks like this:
      """ruby
      Given /two turtles/ do
        step "I have a couple turtles"
      end

      When(/I have a couple turtles/) { raise 'error' }
      """
    When I run the feature with the progress formatter
    Then it should fail with:
      """
      error (RuntimeError)
      ./features/step_definitions/steps2.rb:5:in `/I have a couple turtles/'
      ./features/step_definitions/steps2.rb:2:in `/two turtles/'
      features/test_feature_1.feature:3:in `Given two turtles'

      Failing Scenarios:
      cucumber features/test_feature_1.feature:2 # Scenario: Test Scenario 1

      1 scenario (1 failed)
      1 step (1 failed)
      """

  Scenario: Undefined nested step
    Given a file named "features/call_undefined_step_from_step_def.feature" with:
      """
      Feature: Calling undefined step

        Scenario: Call directly
          Given a step that calls an undefined step

        Scenario: Call via another
          Given a step that calls a step that calls an undefined step
      """
    And a file named "features/step_definitions/steps.rb" with:
      """
      Given /^a step that calls an undefined step$/ do
        step 'this does not exist'
      end

      Given /^a step that calls a step that calls an undefined step$/ do
        step 'a step that calls an undefined step'
      end
      """
    When I run `cucumber -q features/call_undefined_step_from_step_def.feature`
    Then it should fail with exactly:
      """
      Feature: Calling undefined step

        Scenario: Call directly
          Given a step that calls an undefined step
            Undefined dynamic step: "this does not exist" (Cucumber::UndefinedDynamicStep)
            ./features/step_definitions/steps.rb:2:in `/^a step that calls an undefined step$/'
            features/call_undefined_step_from_step_def.feature:4:in `Given a step that calls an undefined step'

        Scenario: Call via another
          Given a step that calls a step that calls an undefined step
            Undefined dynamic step: "this does not exist" (Cucumber::UndefinedDynamicStep)
            ./features/step_definitions/steps.rb:2:in `/^a step that calls an undefined step$/'
            ./features/step_definitions/steps.rb:6:in `/^a step that calls a step that calls an undefined step$/'
            features/call_undefined_step_from_step_def.feature:7:in `Given a step that calls a step that calls an undefined step'

      Failing Scenarios:
      cucumber features/call_undefined_step_from_step_def.feature:3
      cucumber features/call_undefined_step_from_step_def.feature:6

      2 scenarios (2 failed)
      2 steps (2 failed)

      """
