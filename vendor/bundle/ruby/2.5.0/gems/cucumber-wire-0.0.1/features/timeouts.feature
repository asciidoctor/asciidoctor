Feature: Wire protocol timeouts

  We don't want Cucumber to hang forever on a wire server that's not even there,
  but equally we need to give the user the flexibility to allow step definitions
  to take a while to execute, if that's what they need.

  Background:
    Given a file named "features/wired.feature" with:
      """
      Feature: Telegraphy
        Scenario: Wired
          Given we're all wired

      """

  Scenario: Try to talk to a server that's not there
    Given a file named "features/step_definitions/some_remote_place.wire" with:
      """
      host: localhost
      port: 54321

      """
    When I run `cucumber -f progress`
    Then the stderr should contain:
      """
      Unable to contact the wire server at localhost:54321
      """

  @spawn
  Scenario: Invoke a step definition that takes longer than its timeout
    Given a file named "features/step_definitions/some_remote_place.wire" with:
      """
      host: localhost
      port: 54321
      timeout:
        invoke: 0.1

      """
    And there is a wire server on port 54321 which understands the following protocol:
      | request                                              | response                                                     |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[{"val":"wired", "pos":10}]}]] |
      | ["begin_scenario"]                                   | ["success"]                                                  |
      | ["invoke",{"id":"1","args":["wired"]}]               | ["success"]                                                  |
      | ["end_scenario"]                                     | ["success"]                                                  |
    And the wire server takes 0.2 seconds to respond to the invoke message
    When I run `cucumber -f pretty -q`
    Then the stderr should not contain anything
    And it should fail with exactly:
      """
      Feature: Telegraphy

        Scenario: Wired
          Given we're all wired
            Timed out calling wire server with message 'invoke' (Timeout::Error)
            features/wired.feature:3:in `Given we're all wired'

      Failing Scenarios:
      cucumber features/wired.feature:2

      1 scenario (1 failed)
      1 step (1 failed)

      """
