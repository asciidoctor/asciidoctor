Feature: Step matches message

  When the features have been parsed, Cucumber will send a `step_matches`
  message to ask the wire server if it can match a step name. This happens for
  each of the steps in each of the features.

  The wire server replies with an array of StepMatch objects.

  When each StepMatch is returned, it contains the following data:

  * `id` - identifier for the step definition to be used later when if it
  needs to be invoked. The identifier can be any string value and
  is simply used for the wire server's own reference.
  * `args` - any argument values as captured by the wire end's own regular
  expression (or other argument matching) process.

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

  Scenario: Dry run finds no step match
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response       |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[]] |
    When I run `cucumber --dry-run --no-snippets -f progress`
    And it should pass with:
      """
      U

      1 scenario (1 undefined)
      1 step (1 undefined)

      """

  Scenario: Dry run finds a step match
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                            |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]] |
    When I run `cucumber --dry-run -f progress`
    And it should pass with:
      """
      -

      1 scenario (1 skipped)
      1 step (1 skipped)

      """

  Scenario: Step matches returns details about the remote step definition

    Optionally, the StepMatch can also contain a source reference, and a native
    regexp string which will be used by some formatters.

    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                                                                           |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[], "source":"MyApp.MyClass:123", "regexp":"we.*"}]] |
    When I run `cucumber -f stepdefs --dry-run`
    Then it should pass with:
      """
      -

      we.*   # MyApp.MyClass:123

      1 scenario (1 skipped)
      1 step (1 skipped)

      """
    And the stderr should not contain anything
