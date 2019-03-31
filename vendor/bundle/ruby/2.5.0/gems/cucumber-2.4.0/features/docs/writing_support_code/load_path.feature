Feature: Set up a default load path

  When you're developing a gem, it's convenient if your project's `lib` directory
  is already in the load path. Cucumber does this for you.

  Scenario: ./lib is included in the $LOAD_PATH
    Given a file named "features/support/env.rb" with:
      """
      require 'something'
      """
    And a file named "lib/something.rb" with:
      """
      class Something
      end
      """
    When I run `cucumber`
    Then it should pass
