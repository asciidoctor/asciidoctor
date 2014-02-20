# language: en
Feature: Open Blocks
  In order to group content in a generic container
  As a writer
  I want to be able to wrap content in an open block


  Scenario: Render an open block that contains a paragraph to HTML
  Given the AsciiDoc source
    """
    --
    A paragraph in an open block.
    --
    """
  When it is converted to html
  Then the result should match the HTML source
    """
    <div class="openblock">
    <div class="content">
    <div class="paragraph">
    <p>A paragraph in an open block.</p>
    </div>
    </div>
    </div>
    """


  Scenario: Render an open block that contains a paragraph to DocBook
  Given the AsciiDoc source
    """
    --
    A paragraph in an open block.
    --
    """
  When it is converted to docbook
  Then the result should match the XML source
    """
    <simpara>A paragraph in an open block.</simpara>
    """


  Scenario: Render an open block that contains a paragraph to HTML (alt)
  Given the AsciiDoc source
    """
    --
    A paragraph in an open block.
    --
    """
  When it is converted to html
  Then the result should match the HTML structure
    """
    .openblock
      .content
        .paragraph
          p A paragraph in an open block.
    """


  Scenario: Render an open block that contains a paragraph to DocBook (alt)
  Given the AsciiDoc source
    """
    --
    A paragraph in an open block.
    --
    """
  When it is converted to docbook
  Then the result should match the XML structure
    """
    simpara A paragraph in an open block.
    """


  Scenario: Render an open block that contains a list to HTML
  Given the AsciiDoc source
    """
    --
    * one
    * two
    * three
    --
    """
  When it is converted to html
  Then the result should match the HTML structure
    """
    .openblock
      .content
        .ulist
          ul
            li: p one
            li: p two
            li: p three
    """
