@test_unit @config
Feature:

  Exit code should be non-zero if the overall coverage decreases.
  And last_run file should not be overwritten with new coverage value.

  Scenario: refuse_coverage_drop configured
    Given SimpleCov for Test/Unit is configured with:
      """
      require 'simplecov'
      SimpleCov.start do
        add_filter 'test.rb'
        refuse_coverage_drop
      end
      """

    When I run `bundle exec rake test`
    Then the exit status should be 0
    And a file named "coverage/.last_run.json" should exist
    And the file "coverage/.last_run.json" should contain:
      """
      {
        "result": {
          "covered_percent": 88.1
        }
      }
      """

    Given a file named "lib/faked_project/missed.rb" with:
      """
      class UncoveredSourceCode
        def foo
          never_reached
        rescue => err
          but no one cares about invalid ruby here
        end
      end
      """

    When I run `bundle exec rake test`
    Then the exit status should not be 0
    And the output should contain "Coverage has dropped by 3.32% since the last time (maximum allowed: 0.00%)."
    And a file named "coverage/.last_run.json" should exist
    And the file "coverage/.last_run.json" should contain:
      """
      {
        "result": {
          "covered_percent": 88.1
        }
      }
      """

  Scenario: refuse_coverage_drop not configured updates resultset
    Given SimpleCov for Test/Unit is configured with:
      """
      require 'simplecov'
      SimpleCov.start do
        add_filter 'test.rb'
      end
      """

    When I run `bundle exec rake test`
    Then the exit status should be 0
    And a file named "coverage/.last_run.json" should exist
    And the file "coverage/.last_run.json" should contain:
      """
      {
        "result": {
          "covered_percent": 88.1
        }
      }
      """

    Given a file named "lib/faked_project/missed.rb" with:
      """
      class UncoveredSourceCode
        def foo
          never_reached
        rescue => err
          but no one cares about invalid ruby here
        end
      end
      """

    When I run `bundle exec rake test`
    Then the exit status should be 0
    And a file named "coverage/.last_run.json" should exist
    And the file "coverage/.last_run.json" should contain:
      """
      {
        "result": {
          "covered_percent": 84.78
        }
      }
      """
