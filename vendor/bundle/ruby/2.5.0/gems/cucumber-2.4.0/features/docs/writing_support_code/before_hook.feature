Feature: Before Hook

  Scenario: Examine names of scenario and feature
    Given a file named "features/foo.feature" with:
      """
      Feature: Feature name

        Scenario: Scenario name
          Given a step
      """
    And a file named "features/support/hook.rb" with:
      """
      names = []
      Before do |scenario|
        expect(scenario).to_not respond_to(:scenario_outline)
        names << scenario.feature.name.split("\n").first
        names << scenario.name.split("\n").first
        if(names.size == 2)
          raise "NAMES:\n" + names.join("\n") + "\n"
        end
      end
      """
    When I run `cucumber`
    Then the output should contain:
      """
        NAMES:
        Feature name
        Scenario name

      """

  Scenario: Examine names of scenario outline and feature
    Given a file named "features/foo.feature" with:
      """
      Feature: Feature name

        Scenario Outline: Scenario Outline name
          Given a <placeholder>

          Examples: Examples Table name
            | <placeholder> |
            | step          |
      """
    And a file named "features/support/hook.rb" with:
      """
      names = []
      Before do |scenario|
        names << scenario.scenario_outline.feature.name.split("\n").first
        names << scenario.scenario_outline.name.split("\n").first
        names << scenario.name.split("\n").first
        if(names.size == 3)
          raise "NAMES:\n" + names.join("\n") + "\n"
        end
      end
      """
    When I run `cucumber`
    Then the output should contain:
      """
            NAMES:
            Feature name
            Scenario Outline name, Examples Table name (#1)
            Scenario Outline name, Examples Table name (#1)

      """

