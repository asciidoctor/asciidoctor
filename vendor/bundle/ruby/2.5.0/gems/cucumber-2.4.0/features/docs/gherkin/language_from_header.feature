Feature: Choosing the language from the feature file header

  In order to simplify command line and settings in IDEs, Cucumber picks
  up the parser language from a `# language` comment at the beginning of
  any feature file. See the examples below for the exact syntax.

  Scenario: LOLCAT
    Given a file named "features/lolcat.feature" with:
      """
      # language: en-lol
      OH HAI: STUFFING
        B4: HUNGRY
          I CAN HAZ EMPTY BELLY
        MISHUN: CUKES
          DEN KTHXBAI
      """
    When I run `cucumber -i features/lolcat.feature -q`
    Then it should pass with:
      """
      # language: en-lol
      OH HAI: STUFFING

        B4: HUNGRY
          I CAN HAZ EMPTY BELLY

        MISHUN: CUKES
          DEN KTHXBAI

      1 scenario (1 undefined)
      2 steps (2 undefined)

      """
