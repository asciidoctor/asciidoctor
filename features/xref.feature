# language: en
Feature: Cross References
  In order to create cross references between sections and blocks in the current or neighboring document
  As a writer
  I want to be able to use the cross reference macro to compose these references

  Scenario: Create a cross reference to a block that has explicit reftext
  Given the AsciiDoc source
    """
    :xrefstyle: full

    See <<param-type-t>> to learn how it works.

    .Parameterized Type <T>
    [[param-type-t,that "<T>" thing]]
    ****
    This sidebar describes what that <T> thing is all about.
    ****
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#param-type-t' that "&lt;T&gt;" thing
    |to learn how it works.
    """
  When it is converted to docbook
  Then the result should match the XML structure
    """
    simpara
      |See
      xref<> linkend='param-type-t'/
      |to learn how it works.
    sidebar xml:id='param-type-t' xreflabel='that &quot;&lt;T&gt;&quot; thing'
      title Parameterized Type &lt;T&gt;
      simpara This sidebar describes what that &lt;T&gt; thing is all about.
    """

  Scenario: Create a cross reference to a block that has explicit reftext with formatting
  Given the AsciiDoc source
    """
    :xrefstyle: full

    There are cats, then there are the <<big-cats>>.

    [[big-cats,*big* cats]]
    == Big Cats

    So ferocious.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |There are cats, then there are the
    a< href='#big-cats' <strong>big</strong> cats
    |.
    """
  When it is converted to docbook
  Then the result should match the XML structure
    """
    simpara
      |There are cats, then there are the
      xref< linkend='big-cats'/
      |.
    section xml:id='big-cats' xreflabel='big cats'
      title Big Cats
      simpara So ferocious.
    """

  Scenario: Create a full cross reference to a numbered section
  Given the AsciiDoc source
    """
    :sectnums:
    :xrefstyle: full

    See <<sect-features>> to find a complete list of features.

    == About

    [#sect-features]
    === Features

    All the features are listed in this section.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#sect-features' Section 1.1, &#8220;Features&#8221;
    |to find a complete list of features.
    """

  Scenario: Create a short cross reference to a numbered section
  Given the AsciiDoc source
    """
    :sectnums:
    :xrefstyle: short

    See <<sect-features>> to find a complete list of features.

    [#sect-features]
    == Features

    All the features are listed in this section.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#sect-features' Section 1
    |to find a complete list of features.
    """

  Scenario: Create a basic cross reference to an unnumbered section
  Given the AsciiDoc source
    """
    :xrefstyle: full

    See <<sect-features>> to find a complete list of features.

    [#sect-features]
    == Features

    All the features are listed in this section.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#sect-features' Features
    |to find a complete list of features.
    """

  Scenario: Create a basic cross reference to a numbered section when the section reference signifier is disabled
  Given the AsciiDoc source
    """
    :sectnums:
    :xrefstyle: full
    :!section-refsig:

    See <<sect-features>> to find a complete list of features.

    [#sect-features]
    == Features

    All the features are listed in this section.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#sect-features' 1, &#8220;Features&#8221;
    |to find a complete list of features.
    """

  Scenario: Create a full cross reference to a numbered chapter
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :xrefstyle: full

    See <<chap-features>> to find a complete list of features.

    [#chap-features]
    == Features

    All the features are listed in this chapter.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#chap-features' Chapter 1, <em>Features</em>
    |to find a complete list of features.
    """

  Scenario: Create a short cross reference to a numbered chapter
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :xrefstyle: short

    See <<chap-features>> to find a complete list of features.

    [#chap-features]
    == Features

    All the features are listed in this chapter.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#chap-features' Chapter 1
    |to find a complete list of features.
    """

  Scenario: Create a basic cross reference to a numbered chapter
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :xrefstyle: basic

    See <<chap-features>> to find a complete list of features.

    [#chap-features]
    == Features

    All the features are listed in this chapter.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#chap-features' <em>Features</em>
    |to find a complete list of features.
    """

  Scenario: Create a basic cross reference to an unnumbered chapter
  Given the AsciiDoc source
    """
    :doctype: book
    :xrefstyle: full

    See <<chap-features>> to find a complete list of features.

    [#chap-features]
    == Features

    All the features are listed in this chapter.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#chap-features' <em>Features</em>
    |to find a complete list of features.
    """

  Scenario: Create a cross reference to a chapter using a custom chapter reference signifier
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :xrefstyle: full
    :chapter-refsig: Ch

    See <<chap-features>> to find a complete list of features.

    [#chap-features]
    == Features

    All the features are listed in this chapter.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#chap-features' Ch 1, <em>Features</em>
    |to find a complete list of features.
    """

  Scenario: Create a full cross reference to a numbered part
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :partnums:
    :xrefstyle: full

    [preface]
    = Preface

    See <<p1>> for an introduction to the language.

    [#p1]
    = Language

    == Syntax

    This chapter covers the syntax.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#p1' Part I, &#8220;Language&#8221;
    |for an introduction to the language.
    """

  Scenario: Create a short cross reference to a numbered part
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :partnums:
    :xrefstyle: short

    [preface]
    = Preface

    See <<p1>> for an introduction to the language.

    [#p1]
    = Language

    == Syntax

    This chapter covers the syntax.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#p1' Part I
    |for an introduction to the language.
    """

  Scenario: Create a basic cross reference to a numbered part
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :partnums:
    :xrefstyle: basic

    [preface]
    = Preface

    See <<p1>> for an introduction to the language.

    [#p1]
    = Language

    == Syntax

    This chapter covers the syntax.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#p1' Language
    |for an introduction to the language.
    """

  Scenario: Create a basic cross reference to an unnumbered part
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :xrefstyle: full

    [preface]
    = Preface

    See <<p1>> for an introduction to the language.

    [#p1]
    = Language

    == Syntax

    This chapter covers the syntax.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#p1' Language
    |for an introduction to the language.
    """

  @wip
  Scenario: Create a cross reference to a part using a custom part reference signifier
  Given the AsciiDoc source
    """
    :doctype: book
    :sectnums:
    :partnums:
    :xrefstyle: full
    :part-refsig: P

    [preface]
    = Preface

    See <<p1>> for an introduction to the language.

    [#p1]
    = Language

    == Syntax

    This chapter covers the syntax.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#p1' P I, &#8220;Language&#8221;
    |for an introduction to the language.
    """

  Scenario: Create a full cross reference to a numbered appendix
  Given the AsciiDoc source
    """
    :sectnums:
    :xrefstyle: full

    See <<app-features>> to find a complete list of features.

    [appendix#app-features]
    == Features

    All the features are listed in this appendix.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#app-features' Appendix A, <em>Features</em>
    |to find a complete list of features.
    """

  Scenario: Create a short cross reference to a numbered appendix
  Given the AsciiDoc source
    """
    :sectnums:
    :xrefstyle: short

    See <<app-features>> to find a complete list of features.

    [appendix#app-features]
    == Features

    All the features are listed in this appendix.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#app-features' Appendix A
    |to find a complete list of features.
    """

  Scenario: Create a full cross reference to an appendix even when section numbering is disabled
  Given the AsciiDoc source
    """
    :xrefstyle: full

    See <<app-features>> to find a complete list of features.

    [appendix#app-features]
    == Features

    All the features are listed in this appendix.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#app-features' Appendix A, <em>Features</em>
    |to find a complete list of features.
    """

  Scenario: Create a full cross reference to a numbered formal block
  Given the AsciiDoc source
    """
    :xrefstyle: full

    See <<tbl-features>> to find a table of features.

    .Features
    [#tbl-features%autowidth]
    |===
    |Text formatting |Formats text for display.
    |===
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#tbl-features' Table 1, &#8220;Features&#8221;
    |to find a table of features.
    """

  Scenario: Create a short cross reference to a numbered formal block
  Given the AsciiDoc source
    """
    :xrefstyle: short

    See <<tbl-features>> to find a table of features.

    .Features
    [#tbl-features%autowidth]
    |===
    |Text formatting |Formats text for display.
    |===
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#tbl-features' Table 1
    |to find a table of features.
    """

  Scenario: Create a basic cross reference to a numbered formal block when the caption prefix is disabled
  Given the AsciiDoc source
    """
    :xrefstyle: full
    :!table-caption:

    See <<tbl-features>> to find a table of features.

    .Features
    [#tbl-features%autowidth]
    |===
    |Text formatting |Formats text for display.
    |===
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#tbl-features' Features
    |to find a table of features.
    """

  Scenario: Create a cross reference to a numbered formal block with a custom caption prefix
  Given the AsciiDoc source
    """
    :xrefstyle: full
    :table-caption: Tbl

    See <<tbl-features>> to find a table of features.

    .Features
    [#tbl-features%autowidth]
    |===
    |Text formatting |Formats text for display.
    |===
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#tbl-features' Tbl 1, &#8220;Features&#8221;
    |to find a table of features.
    """

  Scenario: Create a full cross reference to a formal image block
  Given the AsciiDoc source
    """
    :xrefstyle: full

    Behold, <<tiger>>!

    .The ferocious Ghostscript tiger
    [#tiger]
    image::tiger.svg[Ghostscript tiger]
    """
  When it is converted to html
  Then the result should match the HTML structure
    """
    .paragraph: p
      |Behold,
      a< href='#tiger' Figure 1, &#8220;The ferocious Ghostscript tiger&#8221;
      |!
    #tiger.imageblock
      .content: img src='tiger.svg' alt='Ghostscript tiger'
      .title Figure 1. The ferocious Ghostscript tiger
    """

  Scenario: Create a short cross reference to a formal image block
  Given the AsciiDoc source
    """
    :xrefstyle: short

    Behold, <<tiger>>!

    .The ferocious Ghostscript tiger
    [#tiger]
    image::tiger.svg[Ghostscript tiger]
    """
  When it is converted to html
  Then the result should match the HTML structure
    """
    .paragraph: p
      |Behold,
      a< href='#tiger' Figure 1
      |!
    #tiger.imageblock
      .content: img src='tiger.svg' alt='Ghostscript tiger'
      .title Figure 1. The ferocious Ghostscript tiger
    """

  Scenario: Create a full cross reference to a block with an explicit caption
  Given the AsciiDoc source
    """
    :xrefstyle: full

    See <<diagram-1>> and <<diagram-2>>.

    .Managing Orders
    [#diagram-1,caption="Diagram {counter:diag-number}. "]
    image::managing-orders.png[Managing Orders]

    .Managing Inventory
    [#diagram-2,caption="Diagram {counter:diag-number}. "]
    image::managing-inventory.png[Managing Inventory]
    """
  When it is converted to html
  Then the result should match the HTML structure
    """
    .paragraph: p
      |See
      a<> href='#diagram-1' Diagram 1, &#8220;Managing Orders&#8221;
      |and
      a< href='#diagram-2' Diagram 2, &#8220;Managing Inventory&#8221;
      |.
    #diagram-1.imageblock
      .content: img src='managing-orders.png' alt='Managing Orders'
      .title Diagram 1. Managing Orders
    #diagram-2.imageblock
      .content: img src='managing-inventory.png' alt='Managing Inventory'
      .title Diagram 2. Managing Inventory
    """

  Scenario: Create a short cross reference to a block with an explicit caption
  Given the AsciiDoc source
    """
    :xrefstyle: short

    See <<diagram-1>> and <<diagram-2>>.

    .Managing Orders
    [#diagram-1,caption="Diagram {counter:diag-number}. "]
    image::managing-orders.png[Managing Orders]

    .Managing Inventory
    [#diagram-2,caption="Diagram {counter:diag-number}. "]
    image::managing-inventory.png[Managing Inventory]
    """
  When it is converted to html
  Then the result should match the HTML structure
    """
    .paragraph: p
      |See
      a<> href='#diagram-1' Diagram 1
      |and
      a< href='#diagram-2' Diagram 2
      |.
    #diagram-1.imageblock
      .content: img src='managing-orders.png' alt='Managing Orders'
      .title Diagram 1. Managing Orders
    #diagram-2.imageblock
      .content: img src='managing-inventory.png' alt='Managing Inventory'
      .title Diagram 2. Managing Inventory
    """

  Scenario: Create a basic cross reference to an unnumbered formal block
  Given the AsciiDoc source
    """
    :xrefstyle: full

    See <<data>> to find the data used in this report.

    .Data
    [#data]
    ....
    a
    b
    c
    ....
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |See
    a<> href='#data' Data
    |to find the data used in this report.
    """

  Scenario: Use title as cross reference text to refer to a formal admonition block
  Given the AsciiDoc source
    """
    :xrefstyle: full

    Recall in <<essential-tip-1>>, we told you how to speed up this process.

    .Essential tip #1
    [#essential-tip-1]
    TIP: You can speed up this process by pressing the turbo button.
    """
  When it is converted to html
  Then the result should contain the HTML structure
    """
    |Recall in
    a< href='#essential-tip-1' Essential tip #1
    |, we told you how to speed up this process.
    """

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
    table.tableblock.frame-all.grid-all.stretch
      colgroup
        col style='width: 100%;'
      tbody
        tr
          td.tableblock.halign-left.valign-top
            div.content
              .paragraph: p
                |See
                a< href='#_install' Install
    .sect1
      h2#_install Install
      .sectionbody
        .paragraph: p Instructions go here.
    """

    Scenario: Create a cross reference using the title of the target section
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
          |refer to
          a< href='#_section_one' Section One
      """

    Scenario: Create a cross reference using the reftext of the target section
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
          |refer to
          a< href='#_section_one' the first section
      """
    When it is converted to docbook
    Then the result should match the XML structure
      """
      section xml:id='_section_one' xreflabel='the first section'
        title Section One
        simpara content
      section xml:id='_section_two'
        title Section Two
        simpara
          |refer to
          xref< linkend='_section_one'/
      """

    Scenario: Create a cross reference using the formatted title of the target section
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
        h2#_section_one
          |Section <strong>One</strong>
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_section_one' Section <strong>One</strong>
      """

    Scenario: Does not process a natural cross reference in compat mode
    Given the AsciiDoc source
      """
      :compat-mode:

      == Section One

      content

      == Section Two

      refer to <<Section One>>
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one
          |Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          |refer to
          a< href='#Section One' [Section One]
      """

    Scenario: Parses text of xref macro as attributes if attribute signature found
    Given the AsciiDoc source
      """
      == Section One

      content

      == Section Two

      refer to xref:_section_one[role=next]
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one
          |Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_section_one' class='next' Section One
      """

    Scenario: Does not parse text of xref macro as attribute if attribute signature not found
    Given the AsciiDoc source
      """
      == Section One

      content

      == Section Two

      refer to xref:_section_one[One, Section One]
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one
          |Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_section_one' One, Section One
      """

    Scenario: Uses whole text of xref macro as link text if attribute signature found and text is enclosed in double quotes
    Given the AsciiDoc source
      """
      == Section One

      content

      == Section Two

      refer to xref:_section_one["Section One == Starting Point"]
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one
          |Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_section_one'
            |Section One == Starting Point
      """

    Scenario: Does not parse text of xref macro as text if enclosed in double quotes but attribute signature not found
    Given the AsciiDoc source
      """
      == Section One

      content

      == Section Two

      refer to xref:_section_one["The Premier Section"]
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one
          |Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_section_one' "The Premier Section"
      """

    Scenario: Can escape double quotes in text of xref macro using backslashes when text is parsed as attributes
    Given the AsciiDoc source
      """
      == Section One

      content

      == Section Two

      refer to xref:_section_one["\"The Premier Section\"",role=spotlight]
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_section_one
          |Section One
        .sectionbody: .paragraph: p content
      .sect1
        h2#_section_two Section Two
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_section_one' class='spotlight' "The Premier Section"
      """

    Scenario: Override xrefstyle for a given part of the document
    Given the AsciiDoc source
      """
      :xrefstyle: full
      :doctype: book
      :sectnums:

      == Foo

      refer to <<#_bar>>

      == Bar
      :xrefstyle: short

      refer to xref:#_foo[xrefstyle=short]
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_foo 1. Foo
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_bar' Chapter 2, <em>Bar</em>
      .sect1
        h2#_bar 2. Bar
        .sectionbody: .paragraph: p
          |refer to
          a< href='#_foo' Chapter 1
      """

    Scenario: Override xrefstyle for a specific reference by assigning the xrefstyle attribute on the xref macro
    Given the AsciiDoc source
      """
      :xrefstyle: full
      :doctype: book
      :sectnums:

      == Foo

      content

      == Bar

      refer to <<#_foo>>

      refer to xref:#_foo[xrefstyle=short]
      """
    When it is converted to html
    Then the result should match the HTML structure
      """
      .sect1
        h2#_foo 1. Foo
        .sectionbody: .paragraph: p content
      .sect1
        h2#_bar 2. Bar
        .sectionbody
          .paragraph: p
            |refer to
            a< href='#_foo' Chapter 1, <em>Foo</em>
          .paragraph: p
            |refer to
            a< href='#_foo' Chapter 1
      """
