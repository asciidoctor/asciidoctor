# language: en
Feature: Cross References
  In order to create links to other sections
  As a writer
  I want to be able to use a cross reference macro


  Scenario: Create a cross reference from an AsciiDoc cell to a section
  Given the AsciiDoc source
    """
    |===
    a|See <<_install>>
    |===
    
    == Install
    
    Instructions go here.
    """
  When it is converted to html
  Then the result should match the HTML structure
    """
    table.tableblock.frame-all.grid-all.spread
      colgroup
        col style='width: 100%;'
      tbody
        tr
          td.tableblock.halign-left.valign-top
            div
              .paragraph: p
                'See
                a href='#_install' Install
    .sect1
      h2#_install Install
      .sectionbody
        .paragraph: p Instructions go here.
    """


    Scenario: Create a cross reference using the target section title
    Given the AsciiDoc source
      """
      == Section One

      content

      == Section Two

      refer to <<Section One>>
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          'refer to
          a href='#_section_one' Section One
      """


    Scenario: Create a cross reference using the target reftext
    Given the AsciiDoc source
      """
      [reftext="the first section"]
      == Section One

      content

      == Section Two

      refer to <<the first section>>
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          'refer to
          a href='#_section_one' the first section
      """


    Scenario: Create a cross reference using the formatted target title
    Given the AsciiDoc source
      """
      == Section *One*

      content

      == Section Two

      refer to <<Section *One*>>
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_strong_one_strong
          'Section
          strong One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          'refer to
          a href='#_section_strong_one_strong'
            'Section
            strong One
      """
