Feature: Formatter API methods

  Some utility methods are provided to make it easier to write your own formatters.

  Here are some examples.

  Scenario: A formatter that uses `Cucumber::Formatter::Io#ensure_file`

    The ensure_file method is a little helper function that some formatters use,
    normally when given a CLI argument with `--out` to check that the file passed
    by the user actually exists.

    The second argument is the name of the formatter, used to print a useful
    error message if the file can't be created for some reason.

    Given a file named "features/f.feature" with:
      """
      Feature: Test
        Scenario: Test
      """
    And a directory named "my/special"
    And a file named "features/support/custom_formatter.rb" with:
      """
      require 'cucumber/formatter/io'
      module Cucumber
        module Formatter
          class Test
            include Io
            def initialize(runtime, path_or_io, options)
              ensure_file("my/special/output.file", "custom formatter")
            end
          end
        end
      end
      """
    When I run `cucumber features/f.feature --format Cucumber::Formatter::Test`
    Then it should pass
