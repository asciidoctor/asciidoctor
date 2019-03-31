Feature: JUnit output formatter
  In order for developers to create test reports with ant
  Cucumber should be able to output JUnit xml files
  
  Background:
    Given the standard step definitions
    And a file named "features/one_passing_one_failing.feature" with:
      """
      Feature: One passing scenario, one failing scenario

        Scenario: Passing
          Given this step passes

        Scenario: Failing
          Given this step fails
      """
    And a file named "features/some_subdirectory/one_passing_one_failing.feature" with:
      """
      Feature: Subdirectory - One passing scenario, one failing scenario

        Scenario: Passing
          Given this step passes

        Scenario: Failing
          Given this step fails
      """
    And a file named "features/pending.feature" with:
      """
      Feature: Pending step

        Scenario: Pending
          Given this step is pending

        Scenario: Undefined
          Given this step is undefined
      """
    And a file named "features/pending.feature" with:
      """
      Feature: Pending step

        Scenario: Pending
          Given this step is pending

        Scenario: Undefined
          Given this step is undefined
      """
    And a file named "features/scenario_outline.feature" with:
      """
      Feature: Scenario outlines

        Scenario Outline: Using scenario outlines
          Given this step <type>

          Examples:
            | type         |
            | passes       |
            | fails        |
            | is pending   |
            | is undefined |
      """

  @spawn
  Scenario: one feature, one passing scenario, one failing scenario
    When I run `cucumber --format junit --out tmp/ features/one_passing_one_failing.feature`
    Then it should fail with:
      """

      """
    And the junit output file "tmp/TEST-features-one_passing_one_failing.xml" should contain:
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite failures="1" errors="0" skipped="0" tests="2" time="0.05" name="One passing scenario, one failing scenario">
      <testcase classname="One passing scenario, one failing scenario" name="Passing" time="0.05">
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="One passing scenario, one failing scenario" name="Failing" time="0.05">
        <failure message="failed Failing" type="failed">
          <![CDATA[Scenario: Failing

      Given this step fails

      Message:
	]]>
          <![CDATA[ (RuntimeError)
	./features/step_definitions/steps.rb:4:in `/^this step fails$/'
	features/one_passing_one_failing.feature:7:in `Given this step fails']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      </testsuite>

      """

  @spawn
  Scenario: one feature in a subdirectory, one passing scenario, one failing scenario
    When I run `cucumber --format junit --out tmp/ features/some_subdirectory/one_passing_one_failing.feature --require features`
    Then it should fail with:
      """

      """
    And the junit output file "tmp/TEST-features-some_subdirectory-one_passing_one_failing.xml" should contain:
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite failures="1" errors="0" skipped="0" tests="2" time="0.05" name="Subdirectory - One passing scenario, one failing scenario">
      <testcase classname="Subdirectory - One passing scenario, one failing scenario" name="Passing" time="0.05">
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Subdirectory - One passing scenario, one failing scenario" name="Failing" time="0.05">
        <failure message="failed Failing" type="failed">
          <![CDATA[Scenario: Failing

      Given this step fails

      Message:
	]]>
          <![CDATA[ (RuntimeError)
	./features/step_definitions/steps.rb:4:in `/^this step fails$/'
	features/some_subdirectory/one_passing_one_failing.feature:7:in `Given this step fails']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      </testsuite>

      """

  Scenario: pending and undefined steps are reported as skipped
    When I run `cucumber --format junit --out tmp/ features/pending.feature`
    Then it should pass with:
      """
      
      """
    And the junit output file "tmp/TEST-features-pending.xml" should contain:
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite failures="0" errors="0" skipped="2" tests="2" time="0.05" name="Pending step">
      <testcase classname="Pending step" name="Pending" time="0.05">
        <skipped/>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Pending step" name="Undefined" time="0.05">
        <skipped/>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      </testsuite>
      
      """

  Scenario: pending and undefined steps with strict option should fail
    When I run `cucumber --format junit --out tmp/ features/pending.feature --strict`
    Then it should fail with:
      """

      """
    And the junit output file "tmp/TEST-features-pending.xml" should contain:
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite failures="2" errors="0" skipped="0" tests="2" time="0.05" name="Pending step">
      <testcase classname="Pending step" name="Pending" time="0.05">
        <failure message="pending Pending" type="pending">
          <![CDATA[Scenario: Pending

      Given this step is pending

      Message:
      ]]>
          <![CDATA[TODO (Cucumber::Pending)
      ./features/step_definitions/steps.rb:3:in `/^this step is pending$/'
      features/pending.feature:4:in `Given this step is pending']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Pending step" name="Undefined" time="0.05">
        <failure message="undefined Undefined" type="undefined">
          <![CDATA[Scenario: Undefined
      
      Given this step is undefined

      Message:
      ]]>
          <![CDATA[Undefined step: "this step is undefined" (Cucumber::Core::Test::Result::Undefined)
      features/pending.feature:7:in `Given this step is undefined']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      </testsuite>

      """
    
  Scenario: run all features
    When I run `cucumber --format junit --out tmp/ features`
    Then it should fail with:
      """
      
      """
    And a file named "tmp/TEST-features-one_passing_one_failing.xml" should exist
    And a file named "tmp/TEST-features-pending.xml" should exist
  
  Scenario: show correct error message if no --out is passed
    When I run `cucumber --format junit features`
    Then the stderr should not contain:
      """
can't convert .* into String \(TypeError\)
      """
    And the stderr should contain:
      """
You *must* specify --out DIR for the junit formatter
      """

  @spawn
  Scenario: strict mode, one feature, one scenario outline, four examples: one passing, one failing, one pending, one undefined
    When I run `cucumber --strict --format junit --out tmp/ features/scenario_outline.feature`
    Then it should fail with:
      """

      """
    And the junit output file "tmp/TEST-features-scenario_outline.xml" should contain:
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite failures="3" errors="0" skipped="0" tests="4" time="0.05" name="Scenario outlines">
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | passes |)" time="0.05">
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | fails |)" time="0.05">
        <failure message="failed Using scenario outlines (outline example : | fails |)" type="failed">
          <![CDATA[Scenario Outline: Using scenario outlines
      
      Example row: | fails |
      
      Message:
      ]]>
          <![CDATA[ (RuntimeError)
      ./features/step_definitions/steps.rb:4:in `/^this step fails$/'
      features/scenario_outline.feature:9:in `Given this step fails'
      features/scenario_outline.feature:4:in `Given this step <type>']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | is pending |)" time="0.05">
        <failure message="pending Using scenario outlines (outline example : | is pending |)" type="pending">
          <![CDATA[Scenario Outline: Using scenario outlines

      Example row: | is pending |

      Message:
      ]]>
          <![CDATA[TODO (Cucumber::Pending)
      ./features/step_definitions/steps.rb:3:in `/^this step is pending$/'
      features/scenario_outline.feature:10:in `Given this step is pending'
      features/scenario_outline.feature:4:in `Given this step <type>']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | is undefined |)" time="0.05">
        <failure message="undefined Using scenario outlines (outline example : | is undefined |)" type="undefined">
          <![CDATA[Scenario Outline: Using scenario outlines

      Example row: | is undefined |

      Message:
      ]]>
          <![CDATA[Undefined step: "this step is undefined" (Cucumber::Core::Test::Result::Undefined)
      features/scenario_outline.feature:11:in `Given this step is undefined'
      features/scenario_outline.feature:4:in `Given this step <type>']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      </testsuite>

      """ 

  @spawn
  Scenario: strict mode with --expand option, one feature, one scenario outline, four examples: one passing, one failing, one pending, one undefined
    When I run `cucumber --strict --expand --format junit --out tmp/ features/scenario_outline.feature`
    Then it should fail with exactly:
      """

      """
    And the junit output file "tmp/TEST-features-scenario_outline.xml" should contain:
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite failures="3" errors="0" skipped="0" tests="4" time="0.05" name="Scenario outlines">
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | passes |)" time="0.05">
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | fails |)" time="0.05">
        <failure message="failed Using scenario outlines (outline example : | fails |)" type="failed">
          <![CDATA[Scenario Outline: Using scenario outlines
      
      Example row: | fails |
      
      Message:
      ]]>
          <![CDATA[ (RuntimeError)
      ./features/step_definitions/steps.rb:4:in `/^this step fails$/'
      features/scenario_outline.feature:9:in `Given this step fails'
      features/scenario_outline.feature:4:in `Given this step <type>']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | is pending |)" time="0.05">
        <failure message="pending Using scenario outlines (outline example : | is pending |)" type="pending">
          <![CDATA[Scenario Outline: Using scenario outlines

      Example row: | is pending |

      Message:
      ]]>
          <![CDATA[TODO (Cucumber::Pending)
      ./features/step_definitions/steps.rb:3:in `/^this step is pending$/'
      features/scenario_outline.feature:10:in `Given this step is pending'
      features/scenario_outline.feature:4:in `Given this step <type>']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="Scenario outlines" name="Using scenario outlines (outline example : | is undefined |)" time="0.05">
        <failure message="undefined Using scenario outlines (outline example : | is undefined |)" type="undefined">
          <![CDATA[Scenario Outline: Using scenario outlines

      Example row: | is undefined |

      Message:
      ]]>
          <![CDATA[Undefined step: "this step is undefined" (Cucumber::Core::Test::Result::Undefined)
      features/scenario_outline.feature:11:in `Given this step is undefined'
      features/scenario_outline.feature:4:in `Given this step <type>']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      </testsuite>

      """ 

  @spawn
  Scenario: run test cases from different features interweaved
    When I run `cucumber --format junit --out tmp/ features/one_passing_one_failing.feature:3 features/pending.feature:3 features/one_passing_one_failing.feature:6`
    Then it should fail with:
      """

      """
    And the junit output file "tmp/TEST-features-one_passing_one_failing.xml" should contain:
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite failures="1" errors="0" skipped="0" tests="2" time="0.05" name="One passing scenario, one failing scenario">
      <testcase classname="One passing scenario, one failing scenario" name="Passing" time="0.05">
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      <testcase classname="One passing scenario, one failing scenario" name="Failing" time="0.05">
        <failure message="failed Failing" type="failed">
          <![CDATA[Scenario: Failing

      Given this step fails

      Message:
	]]>
          <![CDATA[ (RuntimeError)
	./features/step_definitions/steps.rb:4:in `/^this step fails$/'
	features/one_passing_one_failing.feature:7:in `Given this step fails']]>
        </failure>
        <system-out>
          <![CDATA[]]>
        </system-out>
        <system-err>
          <![CDATA[]]>
        </system-err>
      </testcase>
      </testsuite>

      """
    And a file named "tmp/TEST-features-pending.xml" should exist
