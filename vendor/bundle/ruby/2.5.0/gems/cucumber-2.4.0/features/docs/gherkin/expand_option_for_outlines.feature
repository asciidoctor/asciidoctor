Feature: Scenario outlines --expand option

  In order to make it easier to write certain editor plugins and also
  for some people to understand scenarios, Cucumber will expand examples
  in outlines if you add the `--expand` option when running them.

  Scenario:
    Given a file named "features/test.feature" with:
      """
      Feature:
        Scenario Outline:
          Given the secret code is <code>
          When I guess <guess>
          Then I am <verdict>

        Examples:
          | code | guess | verdict |
          | blue | blue  | right   |
          | red  | blue  | wrong   |
      """
    When I run `cucumber -i -q --expand`
    Then the stderr should not contain anything
    And it should pass with:
      """
      Feature: 

        Scenario Outline: 
          Given the secret code is <code>
          When I guess <guess>
          Then I am <verdict>

          Examples: 

            Scenario: | blue | blue | right |
              Given the secret code is blue
              When I guess blue
              Then I am right

            Scenario: | red | blue | wrong |
              Given the secret code is red
              When I guess blue
              Then I am wrong

      2 scenarios (2 undefined)
      6 steps (6 undefined)
      """
