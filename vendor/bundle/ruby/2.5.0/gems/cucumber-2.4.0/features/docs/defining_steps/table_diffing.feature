Feature: Table diffing

  To allow you to more easily compare data in tables, you are able
  to easily diff a table with expected data and see the diff in your
  output.

  Scenario: Extra row
    Given a file named "features/tables.feature" with:
      """
      Feature: Tables
        Scenario: Extra row
          Then the table should be:
            | x | y |
            | a | b |
      """
    And a file named "features/step_definitions/steps.rb" with:
      """
      Then /the table should be:/ do |expected| x=1
        expected.diff!(table(%{
          | x | y |
          | a | c |
        }))
      end
      """
    When I run `cucumber features/tables.feature`
    Then it should fail with exactly:
      """
      Feature: Tables

        Scenario: Extra row         # features/tables.feature:2
          Then the table should be: # features/step_definitions/steps.rb:1
            | x | y |
            | a | b |
            Tables were not identical:
            
              |     x |     y |
              | (-) a | (-) b |
              | (+) a | (+) c |
             (Cucumber::MultilineArgument::DataTable::Different)
            ./features/step_definitions/steps.rb:2:in `/the table should be:/'
            features/tables.feature:3:in `Then the table should be:'

      Failing Scenarios:
      cucumber features/tables.feature:2 # Scenario: Extra row

      1 scenario (1 failed)
      1 step (1 failed)
      0m0.012s

      """
