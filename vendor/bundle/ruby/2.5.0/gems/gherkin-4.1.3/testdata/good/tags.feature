@feature_tag1 @feature_tag2
  @feature_tag3
Feature: Minimal Scenario Outline

@scenario_tag1 @scenario_tag2
  @scenario_tag3
Scenario: minimalistic
    Given the minimalism

@so_tag1  @so_tag2  
  @so_tag3
Scenario Outline: minimalistic outline
    Given the <what>

@ex_tag1 @ex_tag2
  @ex_tag3
Examples: 
  | what       |
  | minimalism |

@ex_tag4 @ex_tag5
  @ex_tag6
Examples: 
  | what            |
  | more minimalism |
