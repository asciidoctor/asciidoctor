Feature: Invoke message

  Assuming a StepMatch was returned for a given step name, when it's time to
  invoke that step definition, Cucumber will send an invoke message.

  The invoke message contains the ID of the step definition, as returned by
  the wire server in response to the the step_matches call, along with the
  arguments that were parsed from the step name during the same step_matches
  call.

  The wire server will normally reply one of the following:

  * `success`
  * `fail`
  * `pending` - optionally takes a message argument

  This isn't quite the whole story: see also table_diffing.feature

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
  Scenario: Invoke a step definition which is pending
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                            |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]] |
      | ["begin_scenario"]                                   | ["success"]                         |
      | ["invoke",{"id":"1","args":[]}]                      | ["pending", "I'll do it later"]     |
      | ["end_scenario"]                                     | ["success"]                         |
    When I run `cucumber -f pretty -q`
    And it should pass with exactly:
      """
      Feature: High strung

        Scenario: Wired
          Given we're all wired
            I'll do it later (Cucumber::Pending)
            features/wired.feature:3:in `Given we're all wired'

      1 scenario (1 pending)
      1 step (1 pending)

      """

  Scenario: Invoke a step definition which passes
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                            |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]] |
      | ["begin_scenario"]                                   | ["success"]                         |
      | ["invoke",{"id":"1","args":[]}]                      | ["success"]                         |
      | ["end_scenario"]                                     | ["success"]                         |
    When I run `cucumber -f progress`
    And it should pass with:
      """
      .

      1 scenario (1 passed)
      1 step (1 passed)

      """

  @spawn
  Scenario: Invoke a step definition which fails

    If an invoked step definition fails, it can return details of the exception
    in the reply to invoke. This causes a Cucumber::WireSupport::WireException to be
    raised.

    Valid arguments are:

    - `message` (mandatory)
    - `exception`
    - `backtrace`

    See the specs for Cucumber::WireSupport::WireException for more details

    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                                                                            |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]]                                                 |
      | ["begin_scenario"]                                   | ["success"]                                                                         |
      | ["invoke",{"id":"1","args":[]}]                      | ["fail",{"message":"The wires are down", "exception":"Some.Foreign.ExceptionType"}] |
      | ["end_scenario"]                                     | ["success"]                                                                         |
    When I run `cucumber -f progress`
    Then the stderr should not contain anything
    And it should fail with:
      """
      F

      (::) failed steps (::)

      The wires are down (Some.Foreign.ExceptionType from localhost:54321)
      features/wired.feature:3:in `Given we're all wired'

      Failing Scenarios:
      cucumber features/wired.feature:2 # Scenario: Wired

      1 scenario (1 failed)
      1 step (1 failed)

      """

  Scenario: Invoke a step definition which takes string arguments (and passes)

    If the step definition at the end of the wire captures arguments, these are
    communicated back to Cucumber in the `step_matches` message.

    Cucumber expects these StepArguments to be returned in the StepMatch. The keys
    have the following meanings:

    - `val` - the value of the string captured for that argument from the step
      name passed in step_matches
    - `pos` - the position within the step name that the argument was matched
      (used for formatter highlighting)

    The argument values are then sent back by Cucumber in the `invoke` message.

    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                                                     |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[{"val":"wired", "pos":10}]}]] |
      | ["begin_scenario"]                                   | ["success"]                                                  |
      | ["invoke",{"id":"1","args":["wired"]}]               | ["success"]                                                  |
      | ["end_scenario"]                                     | ["success"]                                                  |
    When I run `cucumber -f progress`
    Then the stderr should not contain anything
    And it should pass with:
      """
      .

      1 scenario (1 passed)
      1 step (1 passed)

      """

  Scenario: Invoke a step definition which takes regular and table arguments (and passes)

    If the step has a multiline table argument, it will be passed with the
    invoke message as an array of array of strings.

    In this scenario our step definition takes two arguments - one
    captures the "we're" and the other takes the table.

    Given a file named "features/wired_on_tables.feature" with:
      """
      Feature: High strung
        Scenario: Wired and more
          Given we're all:
            | wired |
            | high  |
            | happy |
      """
    And there is a wire server running on port 54321 which understands the following protocol:
      | request                                                               | response                                                    |
      | ["step_matches",{"name_to_match":"we're all:"}]                       | ["success",[{"id":"1", "args":[{"val":"we're", "pos":0}]}]] |
      | ["begin_scenario"]                                                    | ["success"]                                                 |
      | ["invoke",{"id":"1","args":["we're",[["wired"],["high"],["happy"]]]}] | ["success"]                                                 |
      | ["end_scenario"]                                                      | ["success"]                                                 |
    When I run `cucumber -f progress features/wired_on_tables.feature`
    Then the stderr should not contain anything
    And it should pass with:
      """
      .

      1 scenario (1 passed)
      1 step (1 passed)

      """

  Scenario: Invoke a scenario outline step
    Given a file named "features/wired_in_an_outline.feature" with:
      """
      Feature:
        Scenario Outline:
          Given we're all <arg>

          Examples:
            | arg   |
            | wired |
      """
    And there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                            |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]] |
      | ["begin_scenario"]                                   | ["success"]                         |
      | ["invoke",{"id":"1","args":[]}]                      | ["success"]                         |
      | ["end_scenario"]                                     | ["success"]                         |
    When I run `cucumber -f progress features/wired_in_an_outline.feature`
    Then the stderr should not contain anything
    And it should pass with:
      """
      .

      1 scenario (1 passed)
      1 step (1 passed)

      """
    And the wire server should have received the following messages:
      | step_matches   |
      | begin_scenario |
      | invoke         |
      | end_scenario   |
