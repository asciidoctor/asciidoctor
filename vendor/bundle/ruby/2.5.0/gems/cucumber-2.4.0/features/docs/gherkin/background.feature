Feature: Background

  Often you find that several scenarios in the same feature start with 
  a common context.
  
  Cucumber provides a mechanism for this, by providing a `Background` keyword
  where you can specify steps that should be run before each scenario in the
  feature. Typically these will be `Given` steps, but you can use any steps
  that you need to.
  
  **Hint:** if you find that some of the scenarios don't fit the background,
  consider splitting them into a separate feature.
  
  Background:
    Given a file named "features/passing_background.feature" with:
      """
      Feature: Passing background sample

        Background:
          Given '10' cukes

        Scenario: passing background
          Then I should have '10' cukes    

        Scenario: another passing background
          Then I should have '10' cukes
      """
    And a file named "features/scenario_outline_passing_background.feature" with:
      """
      Feature: Passing background with scenario outlines sample

        Background:
          Given '10' cukes

        Scenario Outline: passing background
          Then I should have '<count>' cukes
          Examples:
            |count|
            | 10  |

        Scenario Outline: another passing background
          Then I should have '<count>' cukes
          Examples:
            |count|
            | 10  |
      """
    And a file named "features/background_tagged_before_on_outline.feature" with:
      """
      @background_tagged_before_on_outline
      Feature: Background tagged Before on Outline

        Background: 
          Given this step passes

        Scenario Outline: passing background
          Then I should have '<count>' cukes

          Examples: 
            | count |
            | 888   |
      """
    And a file named "features/failing_background.feature" with:
      """
      Feature: Failing background sample

        Background:
          Given this step raises an error
          And '10' cukes

        Scenario: failing background
          Then I should have '10' cukes

        Scenario: another failing background
          Then I should have '10' cukes
      """
    And a file named "features/scenario_outline_failing_background.feature" with:
      """
      Feature: Failing background with scenario outlines sample

        Background:
          Given this step raises an error

        Scenario Outline: failing background
          Then I should have '<count>' cukes
          Examples:
            |count|
            | 10  |

        Scenario Outline: another failing background
          Then I should have '<count>' cukes
          Examples:
            |count|
            | 10  |
      """
    And a file named "features/pending_background.feature" with:
      """
      Feature: Pending background sample

        Background:
          Given this step is pending

        Scenario: pending background
          Then I should have '10' cukes

        Scenario: another pending background
          Then I should have '10' cukes
      """
    And a file named "features/failing_background_after_success.feature" with:
      """
      Feature: Failing background after previously successful background sample

        Background:
          Given this step passes
          And '10' global cukes

        Scenario: passing background
          Then I should have '10' global cukes

        Scenario: failing background
          Then I should have '10' global cukes
      """
    And a file named "features/failing_background_after_success_outline.feature" with:
      """
      Feature: Failing background after previously successful background sample

        Background:
          Given this step passes
          And '10' global cukes

        Scenario Outline: passing background
          Then I should have '<count>' global cukes

          Examples: 
            | count |
            | 10    |

        Scenario Outline: failing background
          Then I should have '<count>' global cukes

          Examples: 
            | count |
            | 10    |

      """
    And a file named "features/multiline_args_background.feature" with:
      """
      Feature: Passing background with multiline args

        Background:
          Given table
            |a|b|
            |c|d|
          And multiline string
            \"\"\"
            I'm a cucumber and I'm okay. 
            I sleep all night and I test all day
            \"\"\"

        Scenario: passing background
          Then the table should be
            |a|b|
            |c|d|
          Then the multiline string should be
            \"\"\"
            I'm a cucumber and I'm okay. 
            I sleep all night and I test all day
            \"\"\"

        Scenario: another passing background
          Then the table should be
            |a|b|
            |c|d|
          Then the multiline string should be
            \"\"\"
            I'm a cucumber and I'm okay. 
            I sleep all night and I test all day
            \"\"\"
      """
    And the standard step definitions
    And a file named "features/step_definitions/cuke_steps.rb" with:
      """
      Given /^'(.+)' cukes$/ do |cukes| x=1
        raise "We already have #{@cukes} cukes!" if @cukes
        @cukes = cukes
      end

      Given /^'(.+)' global cukes$/ do |cukes| x=1
        $scenario_runs ||= 0
        raise 'FAIL' if $scenario_runs >= 1
        $cukes = cukes
        $scenario_runs += 1
      end

      Then /^I should have '(.+)' global cukes$/ do |cukes| x=1
        expect($cukes).to eq cukes
      end

      Then /^I should have '(.+)' cukes$/ do |cukes| x=1
        expect(@cukes).to eq cukes
      end

      Before('@background_tagged_before_on_outline') do
        @cukes = '888'
      end

      After('@background_tagged_before_on_outline') do
        expect(@cukes).to eq '888'
      end
      """

  Scenario: run a specific scenario with a background
    When I run `cucumber -q features/passing_background.feature:9`
    Then it should pass with exactly:
    """
    Feature: Passing background sample
    
      Background: 
        Given '10' cukes

      Scenario: another passing background
        Then I should have '10' cukes

    1 scenario (1 passed)
    2 steps (2 passed)

    """
  
  Scenario: run a feature with a background that passes
    When I run `cucumber -q features/passing_background.feature`
    Then it should pass with exactly:
    """
    Feature: Passing background sample

      Background: 
        Given '10' cukes

      Scenario: passing background
        Then I should have '10' cukes

      Scenario: another passing background
        Then I should have '10' cukes

    2 scenarios (2 passed)
    4 steps (4 passed)

    """

  Scenario: run a feature with scenario outlines that has a background that passes
    When I run `cucumber -q features/scenario_outline_passing_background.feature`
    Then it should pass with exactly:
    """
    Feature: Passing background with scenario outlines sample

      Background: 
        Given '10' cukes

      Scenario Outline: passing background
        Then I should have '<count>' cukes

        Examples: 
          | count |
          | 10    |

      Scenario Outline: another passing background
        Then I should have '<count>' cukes

        Examples: 
          | count |
          | 10    |

    2 scenarios (2 passed)
    4 steps (4 passed)

    """

  Scenario: run a feature with scenario outlines that has a background that passes
    When I run `cucumber -q features/background_tagged_before_on_outline.feature`
    Then it should pass with exactly:
    """
    @background_tagged_before_on_outline
    Feature: Background tagged Before on Outline

      Background: 
        Given this step passes

      Scenario Outline: passing background
        Then I should have '<count>' cukes

        Examples: 
          | count |
          | 888   |

    1 scenario (1 passed)
    2 steps (2 passed)

    """

  @spawn
  Scenario: run a feature with a background that fails
    When I run `cucumber -q features/failing_background.feature`
    Then it should fail with exactly:
    """
    Feature: Failing background sample

      Background: 
        Given this step raises an error
          error (RuntimeError)
          ./features/step_definitions/steps.rb:2:in `/^this step raises an error$/'
          features/failing_background.feature:4:in `Given this step raises an error'
        And '10' cukes

      Scenario: failing background
        Then I should have '10' cukes

      Scenario: another failing background
        Then I should have '10' cukes

    Failing Scenarios:
    cucumber features/failing_background.feature:7
    cucumber features/failing_background.feature:10
    
    2 scenarios (2 failed)
    6 steps (2 failed, 4 skipped)
    
    """

  @spawn
  Scenario: run a feature with scenario outlines that has a background that fails
    When I run `cucumber -q features/scenario_outline_failing_background.feature`
    Then it should fail with exactly:
    """
    Feature: Failing background with scenario outlines sample

      Background: 
        Given this step raises an error
          error (RuntimeError)
          ./features/step_definitions/steps.rb:2:in `/^this step raises an error$/'
          features/scenario_outline_failing_background.feature:4:in `Given this step raises an error'

      Scenario Outline: failing background
        Then I should have '<count>' cukes

        Examples: 
          | count |
          | 10    |

      Scenario Outline: another failing background
        Then I should have '<count>' cukes

        Examples: 
          | count |
          | 10    |

    Failing Scenarios:
    cucumber features/scenario_outline_failing_background.feature:10
    cucumber features/scenario_outline_failing_background.feature:16

    2 scenarios (2 failed)
    4 steps (2 failed, 2 skipped)
    
    """

  Scenario: run a feature with a background that is pending
    When I run `cucumber -q features/pending_background.feature`
    Then it should pass with exactly:
    """
    Feature: Pending background sample

      Background: 
        Given this step is pending
          TODO (Cucumber::Pending)
          ./features/step_definitions/steps.rb:3:in `/^this step is pending$/'
          features/pending_background.feature:4:in `Given this step is pending'

      Scenario: pending background
        Then I should have '10' cukes

      Scenario: another pending background
        Then I should have '10' cukes

    2 scenarios (2 pending)
    4 steps (2 skipped, 2 pending)
    
    """

  @spawn
  Scenario: background passes with first scenario but fails with second
    When I run `cucumber -q features/failing_background_after_success.feature`
    Then it should fail with exactly:
    """
    Feature: Failing background after previously successful background sample

      Background: 
        Given this step passes
        And '10' global cukes

      Scenario: passing background
        Then I should have '10' global cukes

      Scenario: failing background
        And '10' global cukes
          FAIL (RuntimeError)
          ./features/step_definitions/cuke_steps.rb:8:in `/^'(.+)' global cukes$/'
          features/failing_background_after_success.feature:5:in `And '10' global cukes'
        Then I should have '10' global cukes

    Failing Scenarios:
    cucumber features/failing_background_after_success.feature:10

    2 scenarios (1 failed, 1 passed)
    6 steps (1 failed, 1 skipped, 4 passed)
    
    """

  @spawn
  Scenario: background passes with first outline scenario but fails with second
    When I run `cucumber -q features/failing_background_after_success_outline.feature`
    Then it should fail with exactly:
    """
    Feature: Failing background after previously successful background sample

      Background: 
        Given this step passes
        And '10' global cukes

      Scenario Outline: passing background
        Then I should have '<count>' global cukes

        Examples: 
          | count |
          | 10    |

      Scenario Outline: failing background
        Then I should have '<count>' global cukes

        Examples: 
          | count |
          | 10    |
          FAIL (RuntimeError)
          ./features/step_definitions/cuke_steps.rb:8:in `/^'(.+)' global cukes$/'
          features/failing_background_after_success_outline.feature:5:in `And '10' global cukes'

    Failing Scenarios:
    cucumber features/failing_background_after_success_outline.feature:19

    2 scenarios (1 failed, 1 passed)
    6 steps (1 failed, 1 skipped, 4 passed)
    
    """

  @spawn
  Scenario: background passes with first outline scenario but fails with second (--expand)
    When I run `cucumber -x -q features/failing_background_after_success_outline.feature`
    Then it should fail with exactly:
    """
    Feature: Failing background after previously successful background sample

      Background: 
        Given this step passes
        And '10' global cukes

      Scenario Outline: passing background
        Then I should have '<count>' global cukes

        Examples: 
 
          Scenario: | 10 |
            Then I should have '10' global cukes

      Scenario Outline: failing background
        Then I should have '<count>' global cukes

        Examples: 

          Scenario: | 10 |
            And '10' global cukes
          FAIL (RuntimeError)
          ./features/step_definitions/cuke_steps.rb:8:in `/^'(.+)' global cukes$/'
          features/failing_background_after_success_outline.feature:5:in `And '10' global cukes'
            Then I should have '10' global cukes

    Failing Scenarios:
    cucumber features/failing_background_after_success_outline.feature:19

    2 scenarios (1 failed, 1 passed)
    6 steps (1 failed, 1 skipped, 4 passed)
    
    """

  Scenario: background with multline args
    Given a file named "features/step_definitions/steps.rb" with:
      """
      Given /^table$/ do |table| x=1
        @table = table
      end

      Given /^multiline string$/ do |string| x=1
        @multiline = string
      end

      Then /^the table should be$/ do |table| x=1
        expect(@table.raw).to eq table.raw
      end

      Then /^the multiline string should be$/ do |string| x=1
        expect(@multiline).to eq string
      end
      """
    When I run `cucumber -q features/multiline_args_background.feature`
    Then it should pass with exactly:
      """
      Feature: Passing background with multiline args

        Background: 
          Given table
            | a | b |
            | c | d |
          And multiline string
            \"\"\"
            I'm a cucumber and I'm okay. 
            I sleep all night and I test all day
            \"\"\"

        Scenario: passing background
          Then the table should be
            | a | b |
            | c | d |
          Then the multiline string should be
            \"\"\"
            I'm a cucumber and I'm okay. 
            I sleep all night and I test all day
            \"\"\"

        Scenario: another passing background
          Then the table should be
            | a | b |
            | c | d |
          Then the multiline string should be
            \"\"\"
            I'm a cucumber and I'm okay. 
            I sleep all night and I test all day
            \"\"\"

      2 scenarios (2 passed)
      8 steps (8 passed)
    
      """

