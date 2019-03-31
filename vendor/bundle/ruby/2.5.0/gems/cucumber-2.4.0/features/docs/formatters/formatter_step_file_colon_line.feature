Feature: Formatter API: Step file path and line number (Issue #179)
  To all reporter to understand location of current executing step let's fetch this information
  from step/step_invocation and pass to reporters

  Scenario: my own formatter
    Given a file named "features/f.feature" with:
      """
      Feature: I'll use my own
        because I'm worth it
        Scenario: just print step current line and feature file name
          Given step at line 4
          Given step at line 5
      """
    And a file named "features/step_definitions/steps.rb" with:
      """
      Given(/^step at line (.*)$/) {|line| }
      """
    And a file named "features/support/jb/formatter.rb" with:
      """
      module Jb
        class Formatter
          def initialize(runtime, io, options)
            @io = io
          end

          def before_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background, file_colon_line)
            @io.puts "step result event: #{file_colon_line}"
          end

          def step_name(keyword, step_match, status, source_indent, background, file_colon_line)
            @io.puts "step name event: #{file_colon_line}"
          end
        end
      end
      """
    When I run `cucumber features/f.feature --format Jb::Formatter`
    Then it should pass with exactly:
      """
      step result event: features/f.feature:4
      step name event: features/f.feature:4
      step result event: features/f.feature:5
      step name event: features/f.feature:5

      """
