Feature: Requiring extra step files

  Cucumber allows you to require extra files using the `-r` option.

  Scenario:
    Given a file named "features/test.feature" with:
      """
      Feature: Sample
        Scenario: Sample
          Given found in extra file
      """
    And a file named "tmp/extras.rb" with:
      """
      Given(/^found in extra file$/) { }
      """
    When I run `cucumber -q -r tmp/extras.rb features/test.feature`
    Then it should pass with:
      """
      Feature: Sample

        Scenario: Sample
          Given found in extra file

      1 scenario (1 passed)
      1 step (1 passed)
      """

