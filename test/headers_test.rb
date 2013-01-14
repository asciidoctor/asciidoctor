# encoding: UTF-8
require 'test_helper'

context "Headers" do
  context "document title (level 0)" do
    test "document title with multiline syntax" do
      title = "My Title"
      chars = "=" * title.length
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string(title + "\n" + chars)
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string(title + "\n" + chars + "\n")
    end

    test "document title with multiline syntax, give a char" do
      title = "My Title"
      chars = "=" * (title.length + 1)
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string(title + "\n" + chars)
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string(title + "\n" + chars + "\n")
    end

    test "document title with multiline syntax, take a char" do
      title = "My Title"
      chars = "=" * (title.length - 1)
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string(title + "\n" + chars)
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string(title + "\n" + chars + "\n")
    end

    test "not enough chars for a multiline document title" do
      title = "My Title"
      chars = "=" * (title.length - 2)
      assert_xpath '//h1', render_string(title + "\n" + chars), 0
      assert_xpath '//h1', render_string(title + "\n" + chars + "\n"), 0
    end

    test "too many chars for a multiline document title" do
      title = "My Title"
      chars = "=" * (title.length + 2)
      assert_xpath '//h1', render_string(title + "\n" + chars), 0
      assert_xpath '//h1', render_string(title + "\n" + chars + "\n"), 0
    end

    test "document title with multiline syntax cannot begin with a dot" do
      title = ".My Title"
      chars = "=" * title.length
      assert_xpath '//h1', render_string(title + "\n" + chars), 0
    end

    test "document title with single-line syntax" do
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string("= My Title")
    end

    test "document title with symmetric syntax" do
      assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string("= My Title =")
    end
  end

  context "level 1" do 
    test "with multiline syntax" do
      assert_xpath "//h2[@id='_my_section'][text() = 'My Section']", render_string("My Section\n-----------")
    end

    test "heading title with multiline syntax cannot begin with a dot" do
      title = ".My Title"
      chars = "-" * title.length
      assert_xpath '//h2', render_string(title + "\n" + chars), 0
    end

    test "with single-line syntax" do
      assert_xpath "//h2[@id='_my_title'][text() = 'My Title']", render_string("== My Title")
    end

    test "with single-line symmetric syntax" do
      assert_xpath "//h2[@id='_my_title'][text() = 'My Title']", render_string("== My Title ==")
    end

    test "with single-line non-matching symmetric syntax" do
      assert_xpath "//h2[@id='_my_title'][text() = 'My Title ===']", render_string("== My Title ===")
    end

    test "with non-word character" do
      assert_xpath "//h2[@id='_where_s_the_love'][text() = \"Where#{[8217].pack('U*')}s the love?\"]", render_string("== Where's the love?")
    end

    test "with sequential non-word characters" do
      assert_xpath "//h2[@id='_what_the_is_this'][text() = 'What the \#@$ is this?']", render_string('== What the #@$ is this?')
    end

    test "with trailing whitespace" do
      assert_xpath "//h2[@id='_my_title'][text() = 'My Title']", render_string("== My Title ")
    end

    test "with custom blank idprefix" do
      assert_xpath "//h2[@id='my_title'][text() = 'My Title']", render_string(":idprefix:\n\n== My Title ")
    end

    test "with custom non-blank idprefix" do
      assert_xpath "//h2[@id='ref_my_title'][text() = 'My Title']", render_string(":idprefix: ref_\n\n== My Title ")
    end

    test 'with multibyte characters' do
      input = <<-EOS
== Asciidoctor in 中文
      EOS
      output = render_string input
      assert_xpath '//h2[@id="_asciidoctor_in"][text()="Asciidoctor in 中文"]', output
    end
  end

  context "level 2" do 
    test "with multiline syntax" do
      assert_xpath "//h3[@id='_my_section'][text() = 'My Section']", render_string(":fragment:\nMy Section\n~~~~~~~~~~~")
    end

    test "with single line syntax" do
      assert_xpath "//h3[@id='_my_title'][text() = 'My Title']", render_string(":fragment:\n=== My Title")
    end
  end  

  context "level 3" do 
    test "with multiline syntax" do
      assert_xpath "//h4[@id='_my_section'][text() = 'My Section']", render_string(":fragment:\nMy Section\n^^^^^^^^^^")
    end

    test "with single line syntax" do
      assert_xpath "//h4[@id='_my_title'][text() = 'My Title']", render_string(":fragment:\n==== My Title")
    end
  end

  context "level 4" do 
    test "with multiline syntax" do
      assert_xpath "//h5[@id='_my_section'][text() = 'My Section']", render_string(":fragment:\nMy Section\n++++++++++")
    end

    test "with single line syntax" do
      assert_xpath "//h5[@id='_my_title'][text() = 'My Title']", render_string(":fragment:\n===== My Title")
    end
  end

  context 'Section Numbering' do
    test 'should create section number with one entry for level 1' do
      sect1 = Asciidoctor::Section.new(nil)
      sect1.level = 1
      assert_equal '1.', sect1.sectnum
    end

    test 'should create section number with two entries for level 2' do
      sect1 = Asciidoctor::Section.new(nil)
      sect1.level = 1
      sect1_1 = Asciidoctor::Section.new(sect1)
      sect1 << sect1_1
      assert_equal '1.1.', sect1_1.sectnum
    end

    test 'should create section number with three entries for level 3' do
      sect1 = Asciidoctor::Section.new(nil)
      sect1.level = 1
      sect1_1 = Asciidoctor::Section.new(sect1)
      sect1 << sect1_1
      sect1_1_1 = Asciidoctor::Section.new(sect1_1)
      sect1_1 << sect1_1_1
      assert_equal '1.1.1.', sect1_1_1.sectnum
    end

    test 'should create section number for second section in level' do
      sect1 = Asciidoctor::Section.new(nil)
      sect1.level = 1
      sect1_1 = Asciidoctor::Section.new(sect1)
      sect1 << sect1_1
      sect1_2 = Asciidoctor::Section.new(sect1)
      sect1 << sect1_2
      assert_equal '1.2.', sect1_2.sectnum
    end

    test 'sectnum should use specified delimiter and append string' do
      sect1 = Asciidoctor::Section.new(nil)
      sect1.level = 1
      sect1_1 = Asciidoctor::Section.new(sect1)
      sect1 << sect1_1
      sect1_1_1 = Asciidoctor::Section.new(sect1_1)
      sect1_1 << sect1_1_1
      assert_equal '1,1,1,', sect1_1_1.sectnum(',')
      assert_equal '1:1:1', sect1_1_1.sectnum(':', false)
    end

    test 'should render section numbers when numbered attribute is set' do
      input = <<-EOS
= Title
:numbered:

== Section_1 

text

=== Section_1_1

text

==== Section_1_1_1

text

== Section_2

text

=== Section_2_1

text

=== Section_2_2

text
      EOS
    
      output = render_string input
      assert_xpath '//h2[@id="_section_1"][starts-with(text(), "1. ")]', output, 1
      assert_xpath '//h3[@id="_section_1_1"][starts-with(text(), "1.1. ")]', output, 1
      assert_xpath '//h4[@id="_section_1_1_1"][starts-with(text(), "1.1.1. ")]', output, 1
      assert_xpath '//h2[@id="_section_2"][starts-with(text(), "2. ")]', output, 1
      assert_xpath '//h3[@id="_section_2_1"][starts-with(text(), "2.1. ")]', output, 1
      assert_xpath '//h3[@id="_section_2_2"][starts-with(text(), "2.2. ")]', output, 1
    end

    test 'blocks should have level' do
      input = <<-EOS
= Title

preamble

== Section 1

paragraph

=== Section 1.1

paragraph
      EOS
      doc = document_from_string input
      assert_equal 0, doc.blocks[0].level
      assert_equal 1, doc.blocks[1].level
      assert_equal 1, doc.blocks[1].blocks[0].level
      assert_equal 2, doc.blocks[1].blocks[1].level
      assert_equal 2, doc.blocks[1].blocks[1].blocks[0].level
    end
  end

  context "heading patterns in blocks" do
    test "should not interpret a listing block as a heading" do
      input = <<-EOS
Section
-------

----
code
----

fin.
      EOS
      output = render_string input
      assert_xpath "//h2", output, 1
    end

    test "should not interpret an open block as a heading" do
      input = <<-EOS
Section
-------

--
ha
--

fin.
      EOS
      output = render_string input
      assert_xpath "//h2", output, 1
    end

    test "should not interpret an attribute list as a heading" do
      input = <<-EOS
Section
=======

preamble

[TIP]
====
This should be a tip, not a heading.
====
      EOS
      output = render_string input
      assert_xpath "//*[@class='admonitionblock']//p[text() = 'This should be a tip, not a heading.']", output, 1
    end

    test "should not match a heading in a labeled list" do
      input = <<-EOS
Section
-------

term1::
+
----
list = [1, 2, 3];
----
term2::
== not a heading
term3:: def

//

fin.
      EOS
      output = render_string input
      assert_xpath "//h2", output, 1
      assert_xpath "//dl", output, 1
    end

    test "should not match a heading in a bulleted list" do
      input = <<-EOS
Section
-------

* first
+
----
list = [1, 2, 3];
----
+
* second
== not a heading
* third

fin.
      EOS
      output = render_string input
      assert_xpath "//h2", output, 1
      assert_xpath "//ul", output, 1
    end

    test "should not match a heading in a block" do
      input = <<-EOS
====

== not a heading

====
      EOS
      output = render_string input
      assert_xpath "//h2", output, 0
      assert_xpath "//*[@class='exampleblock']//p[text() = '== not a heading']", output, 1
    end
  end

  context "book doctype" do
    test "document title with level 0 headings" do
      input = <<-EOS
Book
====
:doctype: book

= Chapter One

It was a dark and stormy night...

= Chapter Two

They couldn't believe their eyes when...

== Interlude

While they were waiting...

= Chapter Three

That's all she wrote!
      EOS

      output = render_string(input)
      assert_xpath '//h1', output, 4
      assert_xpath '//h2', output, 1
      assert_xpath '//h1[@id="_chapter_one"][text() = "Chapter One"]', output, 1
      assert_xpath '//h1[@id="_chapter_two"][text() = "Chapter Two"]', output, 1
      assert_xpath '//h1[@id="_chapter_three"][text() = "Chapter Three"]', output, 1
    end
  end
end
