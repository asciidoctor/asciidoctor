Feature: Handle unexpected response

  When the server sends us back a message we don't understand, this is how Cucumber will behave.

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

  Scenario: Unexpected response
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                            |
      | ["begin_scenario"]                                   | ["yikes"]                           |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]] |
    When I run `cucumber -f pretty`
    Then the output should contain:
      """
      undefined method `handle_yikes'
      """
