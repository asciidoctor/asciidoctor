Feature: Getting started

  To get started, just open a command prompt in an empty directory and run 
  `cucumber`. You'll be prompted for what to do next.

  @spawn
  Scenario: Run Cucumber in an empty directory
    Given a directory without standard Cucumber project directory structure
    When I run `cucumber`
    Then it should fail with:
      """
      No such file or directory - features. You can use `cucumber --init` to get started.
      """

  Scenario: Accidentally run Cucumber in a folder with Ruby files in it.
    Given a directory without standard Cucumber project directory structure
    And a file named "should_not_load.rb" with:
      """
      puts 'this will not be shown'
      """
    When I run `cucumber`
    Then the exit status should be 2
    And the output should not contain:
      """
      this will not be shown

      """
