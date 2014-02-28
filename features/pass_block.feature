# language: en
Feature: Open Blocks
  In order to pass content through unprocessed
  As a writer
  I want to be able to mark passthrough content using a pass block


  Scenario: Render a pass block without performing substitutions by default to HTML
  Given the AsciiDoc source
    """
    :name: value

    ++++
    <p>{name}</p>

    image:tiger.png[]
    ++++
    """
  When it is converted to html
  Then the result should match the HTML source
    """
    <p>{name}</p>

    image:tiger.png[]
    """


  Scenario: Render a pass block without performing substitutions by default to DocBook
  Given the AsciiDoc source
    """
    :name: value

    ++++
    <simpara>{name}</simpara>

    image:tiger.png[]
    ++++
    """
  When it is converted to docbook
  Then the result should match the XML source
    """
    <simpara>{name}</simpara>

    image:tiger.png[]
    """


  Scenario: Render a pass block performing explicit substitutions to HTML
  Given the AsciiDoc source
    """
    :name: value

    [subs="attributes,macros"]
    ++++
    <p>{name}</p>

    image:tiger.png[]
    ++++
    """
  When it is converted to html
  Then the result should match the HTML source
    """
    <p>value</p>

    <span class="image"><img src="tiger.png" alt="tiger"></span>
    """
