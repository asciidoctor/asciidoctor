Feature: Inconsistent cell counts

  Scenario: minimalistic
    Given a data table with inconsistent cell count
      | foo | bar |
      | boz | 


  Scenario Outline: minimalistic
    Given the <what>

  Examples: 
    | what       |
    | minimalism | extra |
