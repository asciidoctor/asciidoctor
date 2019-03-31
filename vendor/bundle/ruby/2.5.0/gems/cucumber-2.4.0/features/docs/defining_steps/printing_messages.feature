Feature: Pretty formatter - Printing messages

  When you want to print to Cucumber's output, just call `puts` from
  a step definition. Cucumber will grab the output and print it via
  the formatter that you're using.
  
  Your message will be printed out after the step has run.

  Background:
    Given the standard step definitions
    And a file named "features/step_definitions/puts_steps.rb" with:
      """
      Given /^I use puts with text "(.*)"$/ do |ann|
        puts(ann)
      end

      Given /^I use multiple putss$/ do
        puts("Multiple")
        puts("Announce","Me")
      end

      Given /^I use message (.+) in line (.+) (?:with result (.+))$/ do |ann, line, result|
        puts("Last message") if line == "3"
        puts("Line: #{line}: #{ann}")
        fail if result =~ /fail/i
      end

      Given /^I use puts and step fails$/ do
        puts("Announce with fail")
        fail
      end

      Given /^I puts the world$/ do
        puts(self)
      end
      """
    And a file named "features/f.feature" with:
      """
      Feature:

        Scenario:
          Given I use puts with text "Ann"
          And this step passes

        Scenario:
          Given I use multiple putss
          And this step passes

        Scenario Outline:
          Given I use message <ann> in line <line>

          Examples:
            | line | ann   |
            | 1    | anno1 |
            | 2    | anno2 |
            | 3    | anno3 |

        Scenario:
          Given I use puts and step fails
          And this step passes

        Scenario Outline:
          Given I use message <ann> in line <line> with result <result>

          Examples:
            | line | ann   | result |
            | 1    | anno1 | fail   |
            | 2    | anno2 | pass   |
      """

    And a file named "features/puts_world.feature" with:
      """
      Feature: puts_world
        Scenario: puts_world
          Given I puts the world
      """

    # Don't know why, but we need to spawn this for JRuby otherwise it gives wierd errors
    @spawn
    Scenario: Delayed messages feature
      When I run `cucumber --quiet --format pretty features/f.feature`
      Then the stderr should not contain anything
      And the output should contain:
      """
      Feature: 

        Scenario: 
          Given I use puts with text "Ann"
            Ann
          And this step passes

        Scenario: 
          Given I use multiple putss
            Multiple
            Announce
            Me
          And this step passes

        Scenario Outline: 
          Given I use message <ann> in line <line>

          Examples: 
            | line | ann   |
            | 1    | anno1 |
            | 2    | anno2 |
            | 3    | anno3 |

        Scenario: 
          Given I use puts and step fails
            Announce with fail
             (RuntimeError)
            ./features/step_definitions/puts_steps.rb:18:in `/^I use puts and step fails$/'
            features/f.feature:21:in `Given I use puts and step fails'
          And this step passes

        Scenario Outline: 
          Given I use message <ann> in line <line> with result <result>

          Examples: 
            | line | ann   | result |
            | 1    | anno1 | fail   |  Line: 1: anno1
             (RuntimeError)
            ./features/step_definitions/puts_steps.rb:13:in `/^I use message (.+) in line (.+) (?:with result (.+))$/'
            features/f.feature:29:in `Given I use message anno1 in line 1 with result fail'
            features/f.feature:25:in `Given I use message <ann> in line <line> with result <result>'
            | 2    | anno2 | pass   |  Line: 2: anno2
      """

    Scenario: Non-delayed messages feature (progress formatter)
      When I run `cucumber --format progress features/f.feature`
      Then the output should contain:
        """
        Ann
        ..
        Multiple
        
        Announce
        
        Me
        ..UUU
        Announce with fail
        F-
        Line: 1: anno1
        F
        Line: 2: anno2
        .
        """

