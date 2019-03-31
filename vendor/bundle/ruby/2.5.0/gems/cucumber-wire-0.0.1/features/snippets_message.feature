Feature: Snippets message

  If a step doesn't match, Cucumber will ask the wire server to return a snippet of code for a
  step definition.

  Background:
    Given a file named "features/wired.feature" with:
      """
      Feature: High strung
        Scenario: Wired
          Given we're all wired

      """
    And a file named "features/step_definitions/some_remote_place.wire" with:
      """
      host: localhost
      port: 54321

      """

  @spawn
  Scenario: Wire server returns snippets for a step that didn't match
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                                                                          | response                         |
      | ["step_matches",{"name_to_match":"we're all wired"}]                                             | ["success",[]]                   |
      | ["snippet_text",{"step_keyword":"Given","multiline_arg_class":"","step_name":"we're all wired"}] | ["success","foo()\n  bar;\nbaz"] |
      | ["begin_scenario"]                                                                               | ["success"]                      |
      | ["end_scenario"]                                                                                 | ["success"]                      |
    When I run `cucumber -f pretty`
    Then the stderr should not contain anything
    And it should pass with:
      """
      Feature: High strung

        Scenario: Wired         # features/wired.feature:2
          Given we're all wired # features/wired.feature:3

      1 scenario (1 undefined)
      1 step (1 undefined)
      """
    And the output should contain:
      """
      foo()
        bar;
      baz

      """
