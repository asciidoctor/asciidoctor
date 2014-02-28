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
    table.tableblock.frame-all.grid-all style='width: 100%;'
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
