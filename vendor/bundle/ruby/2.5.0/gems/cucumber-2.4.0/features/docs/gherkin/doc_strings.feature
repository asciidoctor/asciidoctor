Feature: Doc strings

  If you need to specify information in a scenario that won't fit on a single line,
  you can use a DocString.

  A DocString follows a step, and starts and ends with three double quotes, like this:

  ```gherkin
  When I ask to reset my password
  Then I should receive an email with:
    """
    Dear bozo,

    Please click this link to reset your password
    """
  ```

  It's possible to annotate the DocString with the type of content it contains. This is used by
  formatting tools like http://relishapp.com which will render the contents of the DocString
  appropriately. You specify the content type after the triple quote, like this:

  ```gherkin
  Given there is some Ruby code:
    """ruby
    puts "hello world"
    """
  ```

  You can read the content type from the argument passed into your step definition, as shown
  in the example below.

  Scenario: Plain text Docstring
    Given a scenario with a step that looks like this:
      """gherkin
      Given I have a lot to say:
        \"\"\"
        One
        Two
        Three
        \"\"\"
      """
    And a step definition that looks like this:
      """ruby
      Given /say/ do |text|
        puts text
      end
      """
    When I run the feature with the progress formatter
    Then the output should contain:
      """
      One
      Two
      Three
      """

  Scenario: DocString passed as String
    Given a scenario with a step that looks like this:
      """gherkin
      Given I have some code for you:
        \"\"\"
        hello
        \"\"\"
      """
    And a step definition that looks like this:
      """ruby
      Given /code/ do |text|
        puts text.class
      end
      """
    When I run the feature with the progress formatter
    Then the output should contain:
      """
      String
      """
