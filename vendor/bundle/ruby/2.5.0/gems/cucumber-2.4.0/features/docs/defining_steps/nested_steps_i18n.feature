Feature: Nested Steps in I18n

  Background:
    Given a scenario with a step that looks like this in japanese:
      """gherkin
      前提 two turtles
      """
    And a step definition that looks like this:
      """ruby
      # -*- coding: utf-8 -*-
      前提 /a turtle/ do
        puts "turtle!"
      end
      """

  Scenario: Use #steps to call several steps at once
    Given a step definition that looks like this:
      """ruby
      # -*- coding: utf-8 -*-
      前提 /two turtles/ do
        steps %{
          前提 a turtle
          かつ a turtle
        }
      end
      """
    When I run the feature with the progress formatter
    Then the output should contain:
      """
      turtle!

      turtle!

      """
