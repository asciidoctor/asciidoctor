Feature: Wire protocol table diffing

  In order to use the amazing functionality in the Cucumber table object
  As a wire server
  I want to be able to ask for a table diff during a step definition invocation

  Background:
    Given a file named "features/wired.feature" with:
      """
      Feature: Hello
        Scenario: Wired
          Given we're all wired

      """
    And a file named "features/step_definitions/some_remote_place.wire" with:
      """
      host: localhost
      port: 54321

      """

  @spawn
  Scenario: Invoke a step definition tries to diff the table and fails
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                                                                                             |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]]                                                                  |
      | ["begin_scenario"]                                   | ["success"]                                                                                          |
      | ["invoke",{"id":"1","args":[]}]                      | ["diff",[[["a","b"],["c","d"]],[["x","y"],["z","z"]]]]                                               |
      | ["diff_failed"]                                      | ["fail",{"message":"Not same", "exception":"DifferentException", "backtrace":["a.cs:12","b.cs:34"]}] |
      | ["end_scenario"]                                     | ["success"]                                                                                          |
    When I run `cucumber -f progress --backtrace -q`
    Then the stderr should not contain anything
    And it should fail with exactly:
      """
      F

      (::) failed steps (::)

      Not same (DifferentException from localhost:54321)
      a.cs:12
      b.cs:34
      features/wired.feature:3:in `Given we're all wired'

      Failing Scenarios:
      cucumber features/wired.feature:2

      1 scenario (1 failed)
      1 step (1 failed)

      """

  Scenario: Invoke a step definition tries to diff the table and passes
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                               |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]]    |
      | ["begin_scenario"]                                   | ["success"]                            |
      | ["invoke",{"id":"1","args":[]}]                      | ["diff",[[["a"],["b"]],[["a"],["b"]]]] |
      | ["diff_ok"]                                          | ["success"]                            |
      | ["end_scenario"]                                     | ["success"]                            |
    When I run `cucumber -f progress -q`
    Then it should pass with exactly:
      """
      .

      1 scenario (1 passed)
      1 step (1 passed)

      """

  @spawn
  Scenario: Invoke a step definition which successfully diffs a table but then fails
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                                                      |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]]                           |
      | ["begin_scenario"]                                   | ["success"]                                                   |
      | ["invoke",{"id":"1","args":[]}]                      | ["diff",[[["a"],["b"]],[["a"],["b"]]]]                        |
      | ["diff_ok"]                                          | ["fail",{"message":"I wanted things to be different for us"}] |
      | ["end_scenario"]                                     | ["success"]                                                   |
    When I run `cucumber -f progress -q`
    Then it should fail with exactly:
      """
      F

      (::) failed steps (::)

      I wanted things to be different for us (Cucumber::Wire::Exception)
      features/wired.feature:3:in `Given we're all wired'

      Failing Scenarios:
      cucumber features/wired.feature:2

      1 scenario (1 failed)
      1 step (1 failed)

      """

  @spawn
  Scenario: Invoke a step definition which asks for an immediate diff that fails
    Given there is a wire server running on port 54321 which understands the following protocol:
      | request                                              | response                            |
      | ["step_matches",{"name_to_match":"we're all wired"}] | ["success",[{"id":"1", "args":[]}]] |
      | ["begin_scenario"]                                   | ["success"]                         |
      | ["invoke",{"id":"1","args":[]}]                      | ["diff!",[[["a"]],[["b"]]]]         |
      | ["end_scenario"]                                     | ["success"]                         |
    When I run `cucumber -f progress -q`
    And it should fail with exactly:
      """
      F

      (::) failed steps (::)

      Tables were not identical:

        | (-) a | (+) b |
       (Cucumber::MultilineArgument::DataTable::Different)
      features/wired.feature:3:in `Given we're all wired'

      Failing Scenarios:
      cucumber features/wired.feature:2

      1 scenario (1 failed)
      1 step (1 failed)

      """
