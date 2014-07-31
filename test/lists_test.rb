# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context "Bulleted lists (:ulist)" do
  context "Simple lists" do
    test "dash elements with no blank lines" do
      input = <<-EOS
List
====

- Foo
- Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented dash elements using spaces' do
      input = <<-EOS
 - Foo
 - Boo
 - Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented dash elements using tabs' do
      input = <<-EOS
\t-\tFoo
\t-\tBoo
\t-\tBlech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "dash elements separated by blank lines should merge lists" do
      input = <<-EOS
List
====

- Foo

- Boo


- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'dash elements with interspersed line comments should be skipped and not break list' do
      input = <<-EOS
== List

- Foo
// line comment
// another line comment
- Boo
// line comment
more text
// another line comment
- Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath %((//ul/li)[2]/p[text()="Boo\nmore text"]), output, 1
    end

    test "dash elements separated by a line comment offset by blank lines should not merge lists" do
      input = <<-EOS
List
====

- Foo
- Boo

//

- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test "dash elements separated by a block title offset by a blank line should not merge lists" do
      input = <<-EOS
List
====

- Foo
- Boo

.Also
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
      assert_xpath '(//ul)[2]/preceding-sibling::*[@class = "title"][text() = "Also"]', output, 1
    end

    test "dash elements separated by an attribute entry offset by a blank line should not merge lists" do
      input = <<-EOS
== List

- Foo
- Boo

:foo: bar
- Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test 'a non-indented wrapped line is folded into text of list item' do
      input = <<-EOS
List
====

- Foo
wrapped content
- Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\nwrapped content']", output, 1
    end

    test 'a non-indented wrapped line that resembles a block title is folded into text of list item' do
      input = <<-EOS
== List

- Foo
.wrapped content
- Boo
- Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\n.wrapped content']", output, 1
    end

    test 'a non-indented wrapped line that resembles an attribute entry is folded into text of list item' do
      input = <<-EOS
== List

- Foo
:foo: bar
- Boo
- Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\n:foo: bar']", output, 1
    end

    test 'a list item with a nested marker terminates non-indented paragraph for text of list item' do
      input = <<-EOS
- Foo
Bar
* Foo
      EOS

      output = render_embedded_string input
      assert_css 'ul ul', output, 1
      assert !output.include?('* Foo')
    end

    test 'a list item for a different list terminates non-indented paragraph for text of list item' do
      input = <<-EOS
== Example 1

- Foo
Bar
. Foo

== Example 2

* Item
text
term:: def
      EOS

      output = render_embedded_string input
      assert_css 'ul ol', output, 1
      assert !output.include?('* Foo')
      assert_css 'ul dl', output, 1
      assert !output.include?('term:: def')
    end

    test 'an indented wrapped line is unindented and folded into text of list item' do
      input = <<-EOS
List
====

- Foo
  wrapped content
- Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\nwrapped content']", output, 1
    end

    test 'wrapped list item with hanging indent followed by non-indented line' do
      input = <<-EOS
== Lists

- list item 1
  // not line comment
second wrapped line
- list item 2
      EOS
      output = render_embedded_string input
      assert_css 'ul', output, 1
      assert_css 'ul li', output, 2
      # NOTE for some reason, we're getting an extra line after the indented line
      lines = xmlnodes_at_xpath('(//ul/li)[1]/p', output, 1).text.gsub(/\n[[:space:]]*\n/, "\n").lines.entries
      assert_equal 3, lines.size
      assert_equal 'list item 1', lines[0].chomp
      assert_equal '  // not line comment', lines[1].chomp
      assert_equal 'second wrapped line', lines[2].chomp
    end

    test 'a list item with a nested marker terminates indented paragraph for text of list item' do
      input = <<-EOS
- Foo
  Bar
* Foo
      EOS

      output = render_embedded_string input
      assert_css 'ul ul', output, 1
      assert !output.include?('* Foo')
    end

    test 'a list item for a different list terminates indented paragraph for text of list item' do
      input = <<-EOS
== Example 1

- Foo
  Bar
. Foo

== Example 2

* Item
  text
term:: def
      EOS

      output = render_embedded_string input
      assert_css 'ul ol', output, 1
      assert !output.include?('* Foo')
      assert_css 'ul dl', output, 1
      assert !output.include?('term:: def')
    end

    test "a literal paragraph offset by blank lines in list content is appended as a literal block" do
      input = <<-EOS
List
====

- Foo

  literal

- Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text() = "literal"]', output, 1
    end

    test "a literal paragraph offset by a blank line in list content followed by line with continuation is appended as two blocks" do
      input = <<-EOS
List
====

- Foo

  literal
+
para

- Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text() = "literal"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'an admonition paragraph attached by a line continuation to a list item with wrapped text should produce admonition' do
      input = <<-EOS
- first-line text
  wrapped text
+
NOTE: This is a note.
      EOS

      output = render_embedded_string input
      assert_css 'ul', output, 1
      assert_css 'ul > li', output, 1
      assert_css 'ul > li > p', output, 1
      assert_xpath %(//ul/li/p[text()="first-line text\nwrapped text"]), output, 1
      assert_css 'ul > li > p + .admonitionblock.note', output, 1
      assert_xpath '//ul/li/*[@class="admonitionblock note"]//td[@class="content"][normalize-space(text())="This is a note."]', output, 1
    end

    test 'appends line as paragraph if attached by continuation following line comment' do
      input = <<-EOS
- list item 1
// line comment
+
paragraph in list item 1

- list item 2
      EOS
      output = render_embedded_string input 
      assert_css 'ul', output, 1
      assert_css 'ul li', output, 2
      assert_xpath '(//ul/li)[1]/p[text()="list item 1"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="paragraph"]/p[text()="paragraph in list item 1"]', output, 1
      assert_xpath '(//ul/li)[2]/p[text()="list item 2"]', output, 1
    end

    test "a literal paragraph with a line that appears as a list item that is followed by a continuation should create two blocks" do
      input = <<-EOS
* Foo
+
  literal
. still literal
+
para

* Bar
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath %(((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text() = "  literal\n. still literal"]), output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test "consecutive literal paragraph offset by blank lines in list content are appended as a literal blocks" do
      input = <<-EOS
List
====

- Foo

  literal

  more
  literal

- Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 2
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 2
      assert_xpath '((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text() = "literal"]', output, 1
      assert_xpath "((//ul/li)[1]/*[@class='literalblock'])[2]//pre[text() = 'more\nliteral']", output, 1
    end

    test "a literal paragraph without a trailing blank line consumes following list items" do
      input = <<-EOS
List
====

- Foo

  literal
- Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 1
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath "((//ul/li)[1]/*[@class='literalblock'])[1]//pre[text() = '  literal\n- Boo\n- Blech']", output, 1
    end

    test "asterisk elements with no blank lines" do
      input = <<-EOS
List
====

* Foo
* Boo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented asterisk elements using spaces' do
      input = <<-EOS
 * Foo
 * Boo
 * Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented asterisk elements using tabs' do
      input = <<-EOS
\t*\tFoo
\t*\tBoo
\t*\tBlech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'should represent block style as style class' do
      ['disc', 'square', 'circle'].each do |style|
        input = <<-EOS
[#{style}]
* a
* b
* c
        EOS
        output = render_embedded_string input
        assert_css ".ulist.#{style}", output, 1
        assert_css ".ulist.#{style} ul.#{style}", output, 1
      end
    end

    test "asterisk elements separated by blank lines should merge lists" do
      input = <<-EOS
List
====

* Foo

* Boo


* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'asterisk elements with interspersed line comments should be skipped and not break list' do
      input = <<-EOS
== List

* Foo
// line comment
// another line comment
* Boo
// line comment
more text
// another line comment
* Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath %((//ul/li)[2]/p[text()="Boo\nmore text"]), output, 1
    end

    test "asterisk elements separated by a line comment offset by blank lines should not merge lists" do
      input = <<-EOS
List
====

* Foo
* Boo

//

* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test "asterisk elements separated by a block title offset by a blank line should not merge lists" do
      input = <<-EOS
List
====

* Foo
* Boo

.Also
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
      assert_xpath '(//ul)[2]/preceding-sibling::*[@class = "title"][text() = "Also"]', output, 1
    end

    test "asterisk elements separated by an attribute entry offset by a blank line should not merge lists" do
      input = <<-EOS
== List

* Foo
* Boo

:foo: bar
* Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test "list should terminate before next lower section heading" do
      input = <<-EOS
List
====

* first
item
* second
item

== Section
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//h2[text() = "Section"]', output, 1
    end

    test "list should terminate before next lower section heading with implicit id" do
      input = <<-EOS
List
====

* first
item
* second
item

[[sec]]
== Section
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//h2[@id = "sec"][text() = "Section"]', output, 1
    end

    test 'should not find section title immediately below last list item' do
      input = <<-EOS
* first
* second
== Not a section
      EOS

      output = render_embedded_string input
      assert_css 'ul', output, 1
      assert_css 'ul > li', output, 2
      assert_css 'h2', output, 0
      assert output.include?('== Not a section')
      assert_xpath %((//li)[2]/p[text() = "second\n== Not a section"]), output, 1
    end
  end

  context "Lists with inline markup" do
    test "quoted text" do
      input = <<-EOS
List
====

- I am *strong*.
- I am _stressed_.
- I am `flexible`.
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]//strong', output, 1
      assert_xpath '(//ul/li)[2]//em', output, 1
      assert_xpath '(//ul/li)[3]//code', output, 1
    end

    test "attribute substitutions" do
      input = <<-EOS
List
====
:foo: bar

- side a {vbar} side b
- Take me to a {foo}.
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '(//ul/li)[1]//p[text() = "side a | side b"]', output, 1
      assert_xpath '(//ul/li)[2]//p[text() = "Take me to a bar."]', output, 1
    end

    test "leading dot is treated as text not block title" do
      input = <<-EOS
* .first
* .second
* .third
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      %w(.first .second .third).each_with_index do |text, index|
        assert_xpath "(//ul/li)[#{index + 1}]//p[text() = '#{text}']", output, 1
      end
    end

    test "word ending sentence on continuing line not treated as a list item" do
      input = <<-EOS
A. This is the story about
   AsciiDoc. It begins here.
B. And it ends here.
      EOS
      output = render_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 2
    end
  end

  context "Nested lists" do
    test "asterisk element mixed with dash elements should be nested" do
      input = <<-EOS
List
====

- Foo
* Boo
- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "dash element mixed with asterisks elements should be nested" do
      input = <<-EOS
List
====

* Foo
- Boo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "lines prefixed with alternating list markers separated by blank lines should be nested" do
      input = <<-EOS
List
====

- Foo

* Boo


- Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "nested elements (2) with asterisks" do
      input = <<-EOS
List
====

* Foo
** Boo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "nested elements (3) with asterisks" do
      input = <<-EOS
List
====

* Foo
** Boo
*** Snoo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test "nested elements (4) with asterisks" do
      input = <<-EOS
List
====

* Foo
** Boo
*** Snoo
**** Froo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 4
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test "nested elements (5) with asterisks" do
      input = <<-EOS
List
====

* Foo
** Boo
*** Snoo
**** Froo
***** Groo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 5
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test "nested ordered elements (2)" do
      input = <<-EOS
List
====

. Foo
.. Boo
. Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 2
      assert_xpath '//ol/li', output, 3
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[1]/li//ol/li', output, 1
    end

    test "nested ordered elements (3)" do
      input = <<-EOS
List
====

. Foo
.. Boo
... Snoo
. Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 3
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '((//ol)[1]/li//ol)[1]/li', output, 1
      assert_xpath '(((//ol)[1]/li//ol)[1]/li//ol)[1]/li', output, 1
    end

    test "nested unordered inside ordered elements" do
      input = <<-EOS
List
====

. Foo
* Boo
. Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ul', output, 1
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '((//ol)[1]/li//ul)[1]/li', output, 1
    end

    test "nested ordered inside unordered elements" do
      input = <<-EOS
List
====

* Foo
. Boo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ol', output, 1
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ol)[1]/li', output, 1
    end

    test 'three levels of alternating unordered and ordered elements' do
      input = <<-EOS
== Lists

* bullet 1
. numbered 1.1
** bullet 1.1.1
* bullet 2
      EOS

      output = render_embedded_string input
      assert_css '.ulist', output, 2
      assert_css '.olist', output, 1
      assert_css '.ulist > ul > li > p', output, 3
      assert_css '.ulist > ul > li > p + .olist', output, 1
      assert_css '.ulist > ul > li > p + .olist > ol > li > p', output, 1
      assert_css '.ulist > ul > li > p + .olist > ol > li > p + .ulist', output, 1
      assert_css '.ulist > ul > li > p + .olist > ol > li > p + .ulist > ul > li > p', output, 1
      assert_css '.ulist > ul > li + li > p', output, 1
    end

    test "lines with alternating markers of unordered and ordered list types separated by blank lines should be nested" do
      input = <<-EOS
List
====

* Foo

. Boo


* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ol', output, 1
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ol)[1]/li', output, 1
    end

    test 'list item with literal content should not consume nested list of different type' do
      input = <<-EOS
List
====

- bullet

  literal
  but not
  hungry

. numbered
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//li', output, 2
      assert_xpath '//ul//ol', output, 1
      assert_xpath '//ul/li/p', output, 1
      assert_xpath '//ul/li/p[text()="bullet"]', output, 1
      assert_xpath '//ul/li/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath %(//ul/li/p/following-sibling::*[@class="literalblock"]//pre[text()="literal\nbut not\nhungry"]), output, 1
      assert_xpath '//*[@class="literalblock"]/following-sibling::*[@class="olist arabic"]', output, 1
      assert_xpath '//*[@class="literalblock"]/following-sibling::*[@class="olist arabic"]//p[text()="numbered"]', output, 1
    end

    test 'nested list item does not eat the title of the following detached block' do
      input = <<-EOS
List
====

- bullet
  * nested bullet 1
  * nested bullet 2

.Title
....
literal
....
      EOS
      # use render_string so we can match all ulists easier
      output = render_string input
      assert_xpath '//*[@class="ulist"]/ul', output, 2
      assert_xpath '(//*[@class="ulist"])[1]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '(//*[@class="ulist"])[1]/following-sibling::*[@class="literalblock"]/*[@class="title"]', output, 1
    end

    test "lines with alternating markers of bulleted and labeled list types separated by blank lines should be nested" do
      input = <<-EOS
List
====

* Foo

term1:: def1

* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//dl', output, 1
      assert_xpath '//ul[1]/li', output, 2
      assert_xpath '//ul[1]/li//dl[1]/dt', output, 1
      assert_xpath '//ul[1]/li//dl[1]/dd', output, 1
    end

    test "nested ordered with attribute inside unordered elements" do
      input = <<-EOS
Blah
====

* Foo
[start=2]
. Boo
* Blech
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ol', output, 1
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ol)[1][@start = 2]/li', output, 1
    end
  end

  context "List continuations" do
    test "adjacent list continuation line attaches following paragraph" do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
Item one, paragraph two
+
* Item two
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '//ul/li[1]//p', output, 2
      assert_xpath '//ul/li[1]/p[text() = "Item one, paragraph one"]', output, 1
      assert_xpath '//ul/li[1]/*[@class = "paragraph"]/p[text() = "Item one, paragraph two"]', output, 1
    end

    test "adjacent list continuation line attaches following block" do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
....
Item one, literal block
....
+
* Item two
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@class = "literalblock"]', output, 1
    end

    test 'adjacent list continuation line attaches following block with block attributes' do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
:foo: bar
[[beck]]
.Read the following aloud to yourself
[source, ruby]
----
5.times { print "Odelay!" }
----
 
* Item two
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@id="beck"][@class = "listingblock"]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@id="beck"]/div[@class="title"][starts-with(text(),"Read")]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@id="beck"]//code[@class="ruby language-ruby"][starts-with(text(),"5.times")]', output, 1
    end

    test 'trailing block attribute line attached by continuation should not create block' do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
[source]
 
* Item two
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath '//ul/li//*[@class="listingblock"]', output, 0
    end

    test 'trailing block title line attached by continuation should not create block' do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
.Disappears into the ether
 
* Item two
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/*', output, 1
    end

    test 'consecutive blocks in list continuation attach to list item' do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
....
Item one, literal block
....
+
____
Item one, quote block
____
+
* Item two
      EOS
      output = render_embedded_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@class = "literalblock"]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[2][@class = "quoteblock"]', output, 1
    end

    test 'list item with hanging indent followed by block attached by list continuation' do
      input = <<-EOS
== Lists

. list item 1
  continued
+
--
open block in list item 1
--

. list item 2
      EOS
      output = render_embedded_string input
      assert_css 'ol', output, 1
      assert_css 'ol li', output, 2
      assert_xpath %((//ol/li)[1]/p[text()="list item 1\ncontinued"]), output, 1
      assert_xpath '(//ol/li)[1]/p/following-sibling::*[@class="openblock"]', output, 1
      assert_xpath '(//ol/li)[1]/p/following-sibling::*[@class="openblock"]//p[text()="open block in list item 1"]', output, 1
      assert_xpath %((//ol/li)[2]/p[text()="list item 2"]), output, 1
    end

    test 'list item paragraph in list item and nested list item' do
      input = <<-EOS
== Lists

. list item 1
+
list item 1 paragraph

* nested list item
+
nested list item paragraph

. list item 2
      EOS
      output = render_embedded_string input
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]/ul/li/p[text()="nested list item"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]/ul/li/p/following-sibling::div[@class="paragraph"]', output, 1
    end

    test 'trailing list continuations should attach to list items at respective levels' do
      input = <<-EOS
== Lists

. list item 1
+
* nested list item 1
* nested list item 2
+
paragraph for nested list item 2

+
paragraph for list item 1

. list item 2
      EOS
      output = render_embedded_string input 
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'trailing list continuations should attach to list items of different types at respective levels' do
      input = <<-EOS
== Lists

* bullet 1
. numbered 1.1
** bullet 1.1.1

+
numbered 1.1 paragraph

+
bullet 1 paragraph

* bullet 2
      EOS
      output = render_embedded_string input 

      assert_xpath '(//ul)[1]/li', output, 2

      assert_xpath '((//ul)[1]/li[1])/*', output, 3
      assert_xpath '(((//ul)[1]/li[1])/*)[1]/self::p[text()="bullet 1"]', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[2]/ol', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[3]/self::div[@class="paragraph"]/p[text()="bullet 1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div/ol/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/*', output, 3
      assert_xpath '(((//ul)[1]/li)[1]/div/ol/li/*)[1]/self::p[text()="numbered 1.1"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div/ol/li/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div/ol/li/*)[3]/self::div[@class="paragraph"]/p[text()="numbered 1.1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/div[@class="ulist"]/ul/li/*', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/div[@class="ulist"]/ul/li/p[text()="bullet 1.1.1"]', output, 1
    end

    test 'repeated list continuations should attach to list items at respective levels' do
      input = <<-EOS
== Lists

. list item 1

* nested list item 1
+
--
open block for nested list item 1
--
+
* nested list item 2
+
paragraph for nested list item 2

+
paragraph for list item 1

. list item 2
      EOS
      output = render_embedded_string input 
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/div[@class="openblock"]', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'repeated list continuations attached directly to list item should attach to list items at respective levels' do
      input = <<-EOS
== Lists

. list item 1
+
* nested list item 1
+
--
open block for nested list item 1
--
+
* nested list item 2
+
paragraph for nested list item 2

+
paragraph for list item 1

. list item 2
      EOS
      output = render_embedded_string input 
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/div[@class="openblock"]', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'repeated list continuations should attach to list items at respective levels ignoring blank lines' do
      input = <<-EOS
== Lists

. list item 1
+
* nested list item 1
+
--
open block for nested list item 1
--
+
* nested list item 2
+
paragraph for nested list item 2


+
paragraph for list item 1

. list item 2
      EOS
      output = render_embedded_string input 
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/div[@class="openblock"]', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'trailing list continuations should ignore preceding blank lines' do
      input = <<-EOS
== Lists

* bullet 1
** bullet 1.1
*** bullet 1.1.1
+
--
open block
--


+
bullet 1.1 paragraph


+
bullet 1 paragraph

* bullet 2
      EOS
      output = render_embedded_string input 

      assert_xpath '((//ul)[1]/li[1])/*', output, 3
      assert_xpath '(((//ul)[1]/li[1])/*)[1]/self::p[text()="bullet 1"]', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[3]/self::div[@class="paragraph"]/p[text()="bullet 1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*', output, 3
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*)[1]/self::p[text()="bullet 1.1"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*)[3]/self::div[@class="paragraph"]/p[text()="bullet 1.1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li/*', output, 2
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li/*)[1]/self::p', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li/*)[2]/self::div[@class="openblock"]', output, 1
    end

    test 'indented outline list item with different marker offset by a blank line should be recognized as a nested list' do
      input = <<-EOS
* item 1

  . item 1.1
+
attached paragraph

  . item 1.2
+
attached paragraph

* item 2
      EOS

      output = render_embedded_string input

      assert_css 'ul', output, 1
      assert_css 'ol', output, 1
      assert_css 'ul ol', output, 1
      assert_css 'ul > li', output, 2
      assert_xpath '((//ul/li)[1]/*)', output, 2
      assert_xpath '((//ul/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/ol', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/ol/li', output, 2
      (1..2).each do |idx|
        assert_xpath "(((//ul/li)[1]/*)[2]/self::div/ol/li)[#{idx}]/*", output, 2
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/ol/li)[#{idx}]/*)[1]/self::p", output, 1
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/ol/li)[#{idx}]/*)[2]/self::div[@class=\"paragraph\"]", output, 1
      end
    end

    test 'indented labeled list item inside outline list item offset by a blank line should be recognized as a nested list' do
      input = <<-EOS
* item 1

  term a:: definition a
+
attached paragraph

  term b:: definition b
+
attached paragraph

* item 2
      EOS

      output = render_embedded_string input

      assert_css 'ul', output, 1
      assert_css 'dl', output, 1
      assert_css 'ul dl', output, 1
      assert_css 'ul > li', output, 2
      assert_xpath '((//ul/li)[1]/*)', output, 2
      assert_xpath '((//ul/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/dl', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/dl/dt', output, 2
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/dl/dd', output, 2
      (1..2).each do |idx|
        assert_xpath "(((//ul/li)[1]/*)[2]/self::div/dl/dd)[#{idx}]/*", output, 2
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/dl/dd)[#{idx}]/*)[1]/self::p", output, 1
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/dl/dd)[#{idx}]/*)[2]/self::div[@class=\"paragraph\"]", output, 1
      end
    end

    # NOTE this is not consistent w/ AsciiDoc output, but this is some screwy input anyway
=begin
    test "consecutive list continuation lines are folded" do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
+
Item one, paragraph two
+
+
* Item two
+
+
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '//ul/li[1]//p', output, 2
      assert_xpath '//ul/li[1]//p[text() = "Item one, paragraph one"]', output, 1
      assert_xpath '//ul/li[1]//p[text() = "Item one, paragraph two"]', output, 1
    end
=end

  end
end

context "Ordered lists (:olist)" do
  context "Simple lists" do
    test "dot elements with no blank lines" do
      input = <<-EOS
List
====

. Foo
. Boo
. Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'indented dot elements using spaces' do
      input = <<-EOS
 . Foo
 . Boo
 . Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'indented dot elements using tabs' do
      input = <<-EOS
\t.\tFoo
\t.\tBoo
\t.\tBlech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'should represent explicit role attribute as style class' do
      input = <<-EOS
[role="dry"]
. Once
. Again
. Refactor!
      EOS

      output = render_embedded_string input 
      assert_css '.olist.arabic.dry', output, 1
      assert_css '.olist ol.arabic', output, 1
    end

    test 'should represent custom numbering and explicit role attribute as style classes' do
      input = <<-EOS
[loweralpha, role="dry"]
. Once
. Again
. Refactor!
      EOS

      output = render_embedded_string input 
      assert_css '.olist.loweralpha.dry', output, 1
      assert_css '.olist ol.loweralpha', output, 1
    end

    test 'should represent implicit role attribute as style class' do
      input = <<-EOS
[.dry]
. Once
. Again
. Refactor!
      EOS

      output = render_embedded_string input 
      assert_css '.olist.arabic.dry', output, 1
      assert_css '.olist ol.arabic', output, 1
    end

    test 'should represent custom numbering and implicit role attribute as style classes' do
      input = <<-EOS
[loweralpha.dry]
. Once
. Again
. Refactor!
      EOS

      output = render_embedded_string input 
      assert_css '.olist.loweralpha.dry', output, 1
      assert_css '.olist ol.loweralpha', output, 1
    end

    test "dot elements separated by blank lines should merge lists" do
      input = <<-EOS
List
====

. Foo

. Boo


. Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'dot elements with interspersed line comments should be skipped and not break list' do
      input = <<-EOS
== List

. Foo
// line comment
// another line comment
. Boo
// line comment
more text
// another line comment
. Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
      assert_xpath %((//ol/li)[2]/p[text()="Boo\nmore text"]), output, 1
    end

    test "dot elements separated by line comment offset by blank lines should not merge lists" do
      input = <<-EOS
List
====

. Foo
. Boo

//

. Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 2
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[2]/li', output, 1
    end

    test "dot elements separated by a block title offset by a blank line should not merge lists" do
      input = <<-EOS
List
====

. Foo
. Boo

.Also
. Blech
      EOS
      output = render_string input
      assert_xpath '//ol', output, 2
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[2]/li', output, 1
      assert_xpath '(//ol)[2]/preceding-sibling::*[@class = "title"][text() = "Also"]', output, 1
    end

    test "dot elements separated by an attribute entry offset by a blank line should not merge lists" do
      input = <<-EOS
== List

. Foo
. Boo

:foo: bar
. Blech
      EOS
      output = render_embedded_string input
      assert_xpath '//ol', output, 2
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[2]/li', output, 1
    end

    test 'should use start number in docbook4.5 backend' do
      input = <<-EOS
== List

[start=7]
. item 7
. item 8
      EOS

      output = render_embedded_string input, :backend => 'docbook45'
      assert_xpath '//orderedlist', output, 1
      assert_xpath '(//orderedlist)/listitem', output, 2
      assert_xpath '(//orderedlist/listitem)[1][@override = "7"]', output, 1
    end

    test 'should use start number in docbook5 backend' do
      input = <<-EOS
== List

[start=7]
. item 7
. item 8
      EOS

      output = render_embedded_string input, :backend => 'docbook5'
      assert_xpath '//orderedlist', output, 1
      assert_xpath '(//orderedlist)/listitem', output, 2
      assert_xpath '(//orderedlist)[@startingnumber = "7"]', output, 1
    end
  end
end

context "Description lists (:dlist)" do
  context "Simple lists" do
    test "single-line adjacent elements" do
      input = <<-EOS
term1:: def1
term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line indented adjacent elements" do
      input = <<-EOS
term1:: def1
 term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line indented adjacent elements with tabs" do
      input = <<-EOS
term1::\tdef1
\tterm2::\tdef2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line elements separated by blank line should create a single list" do
      input = <<-EOS
term1:: def1

term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
    end

    test "a line comment between elements should divide them into separate lists" do
      input = <<-EOS
term1:: def1

//

term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl/dt', output, 2
      assert_xpath '(//dl)[1]/dt', output, 1
      assert_xpath '(//dl)[2]/dt', output, 1
    end

    test "a ruler between elements should divide them into separate lists" do
      input = <<-EOS
term1:: def1

'''

term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl//hr', output, 0
      assert_xpath '(//dl)[1]/dt', output, 1
      assert_xpath '(//dl)[2]/dt', output, 1
    end

    test "a block title between elements should divide them into separate lists" do
      input = <<-EOS
term1:: def1

.Some more
term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl/dt', output, 2
      assert_xpath '(//dl)[1]/dt', output, 1
      assert_xpath '(//dl)[2]/dt', output, 1
      assert_xpath '(//dl)[2]/preceding-sibling::*[@class="title"][text() = "Some more"]', output, 1
    end

    test "multi-line elements with paragraph content" do
      input = <<-EOS
term1::
def1
term2::
def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with indented paragraph content" do
      input = <<-EOS
term1::
 def1
term2::
  def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test 'multi-line element with paragraph starting with multiple dashes should not be seen as list' do
      input = <<-EOS
term1::
  def1
  -- and a note

term2::
  def2
      EOS
      output = render_embedded_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath %((//dl/dt)[1]/following-sibling::dd/p[text() = "def1#{entity 8201}#{entity 8212}#{entity 8201}and a note"]), output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line element with multiple terms" do
      input = <<-EOS
term1::
term2::
def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dt', output, 1
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test 'consecutive terms share same varlistentry in docbook' do
      input = <<-EOS
term::
alt term::
definition

last::
      EOS
      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '//varlistentry', output, 2
      assert_xpath '(//varlistentry)[1]/term', output, 2
      assert_xpath '(//varlistentry)[2]/term', output, 1
      assert_xpath '(//varlistentry)[2]/listitem', output, 1
      assert_xpath '(//varlistentry)[2]/listitem[normalize-space(text())=""]', output, 1
    end

    test "multi-line elements with blank line before paragraph content" do
      input = <<-EOS
term1::

def1
term2::

def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with paragraph and literal content" do
      # blank line following literal paragraph is required or else it will gobble up the second term
      input = <<-EOS
term1::
def1

  literal

term2::
  def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '//dl/dt/following-sibling::dd//pre', output, 1
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "mixed single and multi-line adjacent elements" do
      input = <<-EOS
term1:: def1
term2::
def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "element with anchor" do
      input = <<-EOS
[[term1]]term1:: def1
[[term2]]term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '(//dl/dt)[1]/a[@id = "term1"]', output, 1
      assert_xpath '(//dl/dt)[2]/a[@id = "term2"]', output, 1
    end

    test "missing space before term does not produce labeled list" do
      input = <<-EOS
term1::def1
term2::def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 0
    end

    test "literal block inside labeled list" do
      input = <<-EOS
term::
+
....
literal, line 1

literal, line 2
....
anotherterm:: def
      EOS
      output = render_string input
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd//pre', output, 1
      assert_xpath '(//dl/dd)[1]/*[@class="literalblock"]//pre', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def"]', output, 1
    end

    test "literal block inside labeled list with trailing line continuation" do
      input = <<-EOS
term::
+
....
literal, line 1

literal, line 2
....
+
anotherterm:: def
      EOS
      output = render_string input
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd//pre', output, 1
      assert_xpath '(//dl/dd)[1]/*[@class="literalblock"]//pre', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def"]', output, 1
    end

    test "multiple listing blocks inside labeled list" do
      input = <<-EOS
term::
+
----
listing, line 1

listing, line 2
----
+
----
listing, line 1

listing, line 2
----
anotherterm:: def
      EOS
      output = render_string input
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd//pre', output, 2
      assert_xpath '(//dl/dd)[1]/*[@class="listingblock"]//pre', output, 2
      assert_xpath '(//dl/dd)[2]/p[text() = "def"]', output, 1
    end

    test "open block inside labeled list" do
      input = <<-EOS
term::
+
--
Open block as definition of term.

And some more detail...
--
anotherterm:: def
      EOS
      output = render_string input
      assert_xpath '//dl/dd//p', output, 3
      assert_xpath '(//dl/dd)[1]//*[@class="openblock"]//p', output, 2
    end

    test "paragraph attached by a list continuation on either side in a labeled list" do
      input = <<-EOS
term1:: def1
+
more detail
+
term2:: def2
      EOS
      output = render_string input
      assert_xpath '(//dl/dt)[1][normalize-space(text())="term1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text())="term2"]', output, 1
      assert_xpath '(//dl/dd)[1]//p', output, 2
      assert_xpath '((//dl/dd)[1]//p)[1][text()="def1"]', output, 1
      assert_xpath '(//dl/dd)[1]/p/following-sibling::*[@class="paragraph"]/p[text() = "more detail"]', output, 1
    end

    test "paragraph attached by a list continuation on either side to a multi-line element in a labeled list" do
      input = <<-EOS
term1::
def1
+
more detail
+
term2:: def2
      EOS
      output = render_string input
      assert_xpath '(//dl/dt)[1][normalize-space(text())="term1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text())="term2"]', output, 1
      assert_xpath '(//dl/dd)[1]//p', output, 2
      assert_xpath '((//dl/dd)[1]//p)[1][text()="def1"]', output, 1
      assert_xpath '(//dl/dd)[1]/p/following-sibling::*[@class="paragraph"]/p[text() = "more detail"]', output, 1
    end

    test "verse paragraph inside a labeled list" do
      input = <<-EOS
term1:: def
+
[verse]
la la la

term2:: def
      EOS
      output = render_string input
      assert_xpath '//dl/dd//p', output, 2
      assert_xpath '(//dl/dd)[1]/*[@class="verseblock"]/pre[text() = "la la la"]', output, 1
    end

    test "list inside a labeled list" do
      input = <<-EOS
term1::
* level 1
** level 2
* level 1
term2:: def
      EOS
      output = render_string input
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd/p', output, 1
      assert_xpath '(//dl/dd)[1]//ul', output, 2
      assert_xpath '((//dl/dd)[1]//ul)[1]//ul', output, 1
    end

    test "list inside a labeled list offset by blank lines" do
      input = <<-EOS
term1::

* level 1
** level 2
* level 1

term2:: def
      EOS
      output = render_string input
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd/p', output, 1
      assert_xpath '(//dl/dd)[1]//ul', output, 2
      assert_xpath '((//dl/dd)[1]//ul)[1]//ul', output, 1
    end

    test "should only grab one line following last item if item has no inline definition" do
      input = <<-EOS
term1::

def1

term2::

def2

A new paragraph

Another new paragraph
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def2"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 2
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[1]/p[text() = "A new paragraph"]', output, 1
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[2]/p[text() = "Another new paragraph"]', output, 1
    end

    test "should only grab one literal line following last item if item has no inline definition" do
      input = <<-EOS
term1::

def1

term2::

  def2

A new paragraph

Another new paragraph
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def2"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 2
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[1]/p[text() = "A new paragraph"]', output, 1
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[2]/p[text() = "Another new paragraph"]', output, 1
    end

    test "should append subsequent paragraph literals to list item as block content" do
      input = <<-EOS
term1::

def1

term2::

  def2

  literal

A new paragraph.
      EOS
      output = render_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def2"]', output, 1
      assert_xpath '(//dl/dd)[2]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '(//dl/dd)[2]/p/following-sibling::*[@class="literalblock"]//pre[text() = "literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[1]/p[text() = "A new paragraph."]', output, 1
    end

    test 'should not match comment line that looks like labeled list term' do
      input = <<-EOS
* item

//::
== Section

section text
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="ulist"]', output, 1
      assert_xpath '/*[@class="sect1"]', output, 1
      assert_xpath '/*[@class="sect1"]/h2[text()="Section"]', output, 1
      assert_xpath '/*[@class="ulist"]/following-sibling::*[@class="sect1"]', output, 1
    end
  end

  context "Nested lists" do
    test "single-line adjacent nested elements" do
      input = <<-EOS
term1:: def1
label1::: detail1
term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line adjacent maximum nested elements" do
      input = <<-EOS
term1:: def1
label1::: detail1
name1:::: value1
item1;; price1
term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 4
      assert_xpath '//dl//dl//dl//dl', output, 1
    end

    test "single-line nested elements seperated by blank line at top level" do
      input = <<-EOS
term1:: def1

label1::: detail1

term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line nested elements seperated by blank line at nested level" do
      input = <<-EOS
term1:: def1
label1::: detail1

label2::: detail2
term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line adjacent nested elements with alternate delimiters" do
      input = <<-EOS
term1:: def1
label1;; detail1
term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line adjacent nested elements" do
      input = <<-EOS
term1::
def1
label1:::
detail1
term2::
def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line nested elements seperated by blank line at nested level repeated" do
      input = <<-EOS
term1::
def1
label1:::

detail1
label2:::
detail2

term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl//dl/dt)[1][normalize-space(text()) = "label1"]', output, 1
      assert_xpath '(//dl//dl/dt)[1]/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl//dl/dt)[2][normalize-space(text()) = "label2"]', output, 1
      assert_xpath '(//dl//dl/dt)[2]/following-sibling::dd/p[text() = "detail2"]', output, 1
    end

    test "multi-line element with indented nested element" do
      input = <<-EOS
term1::
  def1
  label1;;
   detail1
term2::
  def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt', output, 2
      assert_xpath '(//dl)[1]/dd', output, 2
      assert_xpath '((//dl)[1]/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '((//dl)[1]/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '((//dl)[1]/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '((//dl)[1]/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "mixed single and multi-line elements with indented nested elements" do
      input = <<-EOS
term1:: def1
  label1:::
   detail1
term2:: def2
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with first paragraph folded to text with adjacent nested element" do
      input = <<-EOS
term1:: def1
continued
label1:::
detail1
      EOS
      output = render_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[starts-with(text(), "def1")]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[contains(text(), "continued")]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
    end
  end

  context 'Special lists' do
    test 'should render glossary list with proper semantics' do
      input = <<-EOS
[glossary]
term 1:: def 1
term 2:: def 2
      EOS
      output = render_embedded_string input
      assert_css '.dlist.glossary', output, 1
      assert_css '.dlist dt:not([class])', output, 2
    end

    test 'consecutive glossary terms should share same glossentry element in docbook' do
      input = <<-EOS
[glossary]
term::
alt term::
definition

last::
      EOS
      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '/glossentry', output, 2
      assert_xpath '(/glossentry)[1]/glossterm', output, 2
      assert_xpath '(/glossentry)[2]/glossterm', output, 1
      assert_xpath '(/glossentry)[2]/glossdef', output, 1
      assert_xpath '(/glossentry)[2]/glossdef[normalize-space(text())=""]', output, 1
    end

    test 'should render horizontal list with proper markup' do
      input = <<-EOS
[horizontal]
first term:: definition
+
more detail

second term:: definition
      EOS
      output = render_embedded_string input
      assert_css '.hdlist', output, 1
      assert_css '.hdlist table', output, 1
      assert_css '.hdlist table colgroup', output, 0
      assert_css '.hdlist table tr', output, 2
      assert_xpath '/*[@class="hdlist"]/table/tr[1]/td', output, 2
      assert_xpath '/*[@class="hdlist"]/table/tr[1]/td[@class="hdlist1"]', output, 1
      assert_xpath '/*[@class="hdlist"]/table/tr[1]/td[@class="hdlist2"]', output, 1
      assert_xpath '/*[@class="hdlist"]/table/tr[1]/td[@class="hdlist2"]/p', output, 1
      assert_xpath '/*[@class="hdlist"]/table/tr[1]/td[@class="hdlist2"]/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '((//tr)[1]/td)[1][normalize-space(text())="first term"]', output, 1
      assert_xpath '((//tr)[1]/td)[2]/p[normalize-space(text())="definition"]', output, 1

      assert_xpath '/*[@class="hdlist"]/table/tr[2]/td', output, 2
      assert_xpath '((//tr)[2]/td)[1][normalize-space(text())="second term"]', output, 1
      assert_xpath '((//tr)[2]/td)[2]/p[normalize-space(text())="definition"]', output, 1
    end

    test 'should set col widths of item and label if specified' do
      input = <<-EOS
[horizontal]
[labelwidth="25", itemwidth="75"]
term:: def
      EOS

      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_xpath '(//table/colgroup/col)[1][@style="width: 25%;"]', output, 1
      assert_xpath '(//table/colgroup/col)[2][@style="width: 75%;"]', output, 1
    end

    test 'should set col widths of item and label in docbook if specified' do
      input = <<-EOS
[horizontal]
[labelwidth="25", itemwidth="75"]
term:: def
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_css 'informaltable', output, 1
      assert_css 'informaltable > tgroup', output, 1
      assert_css 'informaltable > tgroup > colspec', output, 2
      assert_xpath '(/informaltable/tgroup/colspec)[1][@colwidth="25*"]', output, 1
      assert_xpath '(/informaltable/tgroup/colspec)[2][@colwidth="75*"]', output, 1
    end

    test 'should add strong class to label if strong option is set' do
      input = <<-EOS
[horizontal, options="strong"]
term:: def
      EOS

      output = render_embedded_string input
      assert_css '.hdlist', output, 1
      assert_css '.hdlist td.hdlist1.strong', output, 1
    end

    test 'consecutive terms in horizontal list should share same cell' do
      input = <<-EOS
[horizontal]
term::
alt term::
definition

last::
      EOS
      output = render_embedded_string input 
      assert_xpath '//tr', output, 2
      assert_xpath '(//tr)[1]/td[@class="hdlist1"]', output, 1
      # NOTE I'm trimming the trailing <br> in Asciidoctor
      #assert_xpath '(//tr)[1]/td[@class="hdlist1"]/br', output, 2
      assert_xpath '(//tr)[1]/td[@class="hdlist1"]/br', output, 1
      assert_xpath '(//tr)[2]/td[@class="hdlist2"]', output, 1
    end

    test 'consecutive terms in horizontal list should share same entry in docbook' do
      input = <<-EOS
[horizontal]
term::
alt term::
definition

last::
      EOS
      output = render_embedded_string input, :backend => 'docbook' 
      assert_xpath '//row', output, 2
      assert_xpath '(//row)[1]/entry', output, 2
      assert_xpath '((//row)[1]/entry)[1]/simpara', output, 2
      assert_xpath '(//row)[2]/entry', output, 2
      assert_xpath '((//row)[2]/entry)[2][normalize-space(text())=""]', output, 1
    end

    test 'should render horizontal list in docbook with proper markup' do
      input = <<-EOS
.Terms
[horizontal]
first term:: definition
+
more detail

second term:: definition
      EOS
      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '/table', output, 1
      assert_xpath '/table[@tabstyle="horizontal"]', output, 1
      assert_xpath '/table[@tabstyle="horizontal"]/title[text()="Terms"]', output, 1
      assert_xpath '/table//row', output, 2
      assert_xpath '(/table//row)[1]/entry', output, 2
      assert_xpath '(/table//row)[2]/entry', output, 2
      assert_xpath '((/table//row)[1]/entry)[2]/simpara', output, 2
    end

    test 'should render qanda list in HTML with proper semantics' do
      input = <<-EOS
[qanda]
Question 1::
        Answer 1.
Question 2::
        Answer 2.
+
NOTE: A note about Answer 2.
      EOS
      output = render_embedded_string input
      assert_css '.qlist.qanda', output, 1
      assert_css '.qanda > ol', output, 1
      assert_css '.qanda > ol > li', output, 2
      (1..2).each do |idx|
        assert_css ".qanda > ol > li:nth-child(#{idx}) > p", output, 2
        assert_css ".qanda > ol > li:nth-child(#{idx}) > p:first-child > em", output, 1
        assert_xpath "/*[@class = 'qlist qanda']/ol/li[#{idx}]/p[1]/em[normalize-space(text()) = 'Question #{idx}']", output, 1
        assert_css ".qanda > ol > li:nth-child(#{idx}) > p:last-child > *", output, 0
        assert_xpath "/*[@class = 'qlist qanda']/ol/li[#{idx}]/p[2][normalize-space(text()) = 'Answer #{idx}.']", output, 1
      end
      assert_xpath "/*[@class = 'qlist qanda']/ol/li[2]/p[2]/following-sibling::div[@class='admonitionblock note']", output, 1
    end

    test 'should render qanda list in DocBook with proper semantics' do
      input = <<-EOS
[qanda]
Question 1::
        Answer 1.
Question 2::
        Answer 2.
+
NOTE: A note about Answer 2.
      EOS
      output = render_embedded_string input, :backend => 'docbook'
      assert_css 'qandaset', output, 1
      assert_css 'qandaset > qandaentry', output, 2
      (1..2).each do |idx|
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > question", output, 1
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > question > simpara", output, 1
        assert_xpath "/qandaset/qandaentry[#{idx}]/question/simpara[normalize-space(text()) = 'Question #{idx}']", output, 1
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > answer", output, 1
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > answer > simpara", output, 1
        assert_xpath "/qandaset/qandaentry[#{idx}]/answer/simpara[normalize-space(text()) = 'Answer #{idx}.']", output, 1
      end
      assert_xpath "/qandaset/qandaentry[2]/answer/simpara/following-sibling::note", output, 1
    end

    test 'consecutive questions should share same question element in docbook' do
      input = <<-EOS
[qanda]
question::
follow-up question::
response

last question::
      EOS
      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '//qandaentry', output, 2
      assert_xpath '(//qandaentry)[1]/question', output, 1
      assert_xpath '(//qandaentry)[1]/question/simpara', output, 2
      assert_xpath '(//qandaentry)[2]/question', output, 1
      assert_xpath '(//qandaentry)[2]/answer', output, 1
      assert_xpath '(//qandaentry)[2]/answer[normalize-space(text())=""]', output, 1
    end

    test 'should render bibliography list with proper semantics' do
      input = <<-EOS
[bibliography]
- [[[taoup]]] Eric Steven Raymond. 'The Art of Unix
  Programming'. Addison-Wesley. ISBN 0-13-142901-9.
- [[[walsh-muellner]]] Norman Walsh & Leonard Muellner.
  'DocBook - The Definitive Guide'. O'Reilly & Associates. 1999.
  ISBN 1-56592-580-7.
      EOS
      output = render_embedded_string input
      assert_css '.ulist.bibliography', output, 1
      assert_css '.ulist.bibliography ul', output, 1
      assert_css '.ulist.bibliography ul li', output, 2
      assert_css '.ulist.bibliography ul li p', output, 2
      assert_css '.ulist.bibliography ul li:nth-child(1) p a#taoup', output, 1
      assert_xpath '//a/*', output, 0
      text = xmlnodes_at_xpath '(//a)[1]/following-sibling::text()', output, 1
      assert text.text.start_with?('[taoup] ')
    end

    test 'should render bibliography list with proper semantics to DocBook' do
      input = <<-EOS
[bibliography]
- [[[taoup]]] Eric Steven Raymond. 'The Art of Unix
  Programming'. Addison-Wesley. ISBN 0-13-142901-9.
- [[[walsh-muellner]]] Norman Walsh & Leonard Muellner.
  'DocBook - The Definitive Guide'. O'Reilly & Associates. 1999.
  ISBN 1-56592-580-7.
      EOS
      output = render_embedded_string input, :backend => 'docbook'
      assert_css 'bibliodiv', output, 1
      assert_css 'bibliodiv > bibliomixed', output, 2
      assert_css 'bibliodiv > bibliomixed > bibliomisc', output, 2
      assert_css 'bibliodiv > bibliomixed:nth-child(1) > bibliomisc > anchor', output, 1
      assert_css 'bibliodiv > bibliomixed:nth-child(1) > bibliomisc > anchor[xreflabel="[taoup]"]', output, 1
      assert_css 'bibliodiv > bibliomixed:nth-child(2) > bibliomisc > anchor', output, 1
      assert_css 'bibliodiv > bibliomixed:nth-child(2) > bibliomisc > anchor[xreflabel="[walsh-muellner]"]', output, 1
    end
  end
end

context 'Description lists redux' do

  context 'Label without text on same line' do

    test 'folds text from subsequent line' do
      input = <<-EOS
== Lists

term1::
def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end
  
    test 'folds text from first line after blank lines' do
      input = <<-EOS
== Lists

term1::


def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end
  
    test 'folds text from first line after blank line and immediately preceding next item' do
      input = <<-EOS
== Lists

term1::

def1
term2:: def2
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="def1"]', output, 1
    end

    test 'paragraph offset by blank lines does not break list if label does not have inline text' do
      input = <<-EOS
== Lists

term1::

def1

term2:: def2
      EOS
  
      output = render_embedded_string input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 2
      assert_css 'dl > dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text()="def1"]', output, 1
    end
  
    test 'folds text from first line after comment line' do
      input = <<-EOS
== Lists

term1::
// comment
def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end
  
    test 'folds text from line following comment line offset by blank line' do
      input = <<-EOS
== Lists

term1::

// comment
def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end
  
    test 'folds text from subsequent indented line' do
      input = <<-EOS
== Lists

term1::
  def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end
  
    test 'folds text from indented line after blank line' do
      input = <<-EOS
== Lists

term1::

  def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end
  
    test 'folds text that looks like ruler offset by blank line' do
      input = <<-EOS
== Lists

term1::

'''
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="'''"]), output, 1
    end
  
    test 'folds text that looks like ruler offset by blank line and line comment' do
      input = <<-EOS
== Lists

term1::

// comment
'''
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="'''"]), output, 1
    end
  
    test 'folds text that looks like ruler and the line following it offset by blank line' do
      input = <<-EOS
== Lists

term1::

'''
continued
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[normalize-space(text())="''' continued"]), output, 1
    end
  
    test 'folds text that looks like title offset by blank line' do
      input = <<-EOS
== Lists

term1::

.def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()=".def1"]', output, 1
    end
  
    test 'folds text that looks like title offset by blank line and line comment' do
      input = <<-EOS
== Lists

term1::

// comment
.def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()=".def1"]', output, 1
    end
  
    test 'folds text that looks like admonition offset by blank line' do
      input = <<-EOS
== Lists

term1::

NOTE: def1
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="NOTE: def1"]', output, 1
    end

    test 'folds text that looks like section title offset by blank line' do
      input = <<-EOS
== Lists

term1::

== Another Section
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="== Another Section"]', output, 1
      assert_xpath '//h2', output, 1
    end
  
    test 'folds text of first literal line offset by blank line appends subsequent literals offset by blank line as blocks' do
      input = <<-EOS
== Lists

term1::

  def1

  literal


  literal
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 2
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 2
    end
  
    test 'folds text of subsequent line and appends following literal line offset by blank line as block if term has no inline definition' do
      input = <<-EOS
== Lists

term1::
def1

  literal

term2:: def2
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="def1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end
  
    test 'appends literal line attached by continuation as block if item has no inline definition' do
      input = <<-EOS
== Lists

term1::
+
  literal
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end
  
    test 'appends literal line attached by continuation as block if item has no inline definition followed by ruler' do
      input = <<-EOS
== Lists

term1::
+
  literal

'''
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::hr', output, 1
    end
  
    test 'appends line attached by continuation as block if item has no inline definition followed by ruler' do
      input = <<-EOS
== Lists

term1::
+
para

'''
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::hr', output, 1
    end
  
    test 'appends line attached by continuation as block if item has no inline definition followed by block' do
      input = <<-EOS
== Lists

term1::
+
para

....
literal
....
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end
  
    test 'appends block attached by continuation but not subsequent block not attached by continuation' do
      input = <<-EOS
== Lists

term1::
+
....
literal
....
....
detached
....
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]//pre[text()="detached"]', output, 1
    end
  
    test 'appends list if item has no inline definition' do
      input = <<-EOS
== Lists

term1::

* one
* two
* three
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd//ul/li', output, 3
    end
  
    test 'appends list to first term when followed immediately by second term' do
      input = <<-EOS
== Lists

term1::

* one
* two
* three
term2:: def2
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p', output, 0
      assert_xpath '(//*[@class="dlist"]//dd)[1]//ul/li', output, 3
      assert_xpath '(//*[@class="dlist"]//dd)[2]/p[text()="def2"]', output, 1
    end

    test 'appends indented list to first term that is adjacent to second term' do
      input = <<-EOS
== Lists

label 1::
  definition 1

  * one
  * two
  * three
label 2::
  definition 2

paragraph
      EOS
      output = render_embedded_string input
      assert_css '.dlist > dl', output, 1
      assert_css '.dlist dt', output, 2
      assert_xpath '(//*[@class="dlist"]//dt)[1][normalize-space(text())="label 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dt)[2][normalize-space(text())="label 2"]', output, 1
      assert_css '.dlist dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="definition 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[2]/p[text()="definition 2"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]//li', output, 3
      assert_css '.dlist + .paragraph', output, 1
    end

    test 'appends indented list to first term that is attached by a continuation and adjacent to second term' do
      input = <<-EOS
== Lists

label 1::
  definition 1
+
  * one
  * two
  * three
label 2::
  definition 2

paragraph
      EOS
      output = render_embedded_string input
      assert_css '.dlist > dl', output, 1
      assert_css '.dlist dt', output, 2
      assert_xpath '(//*[@class="dlist"]//dt)[1][normalize-space(text())="label 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dt)[2][normalize-space(text())="label 2"]', output, 1
      assert_css '.dlist dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="definition 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[2]/p[text()="definition 2"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]//li', output, 3
      assert_css '.dlist + .paragraph', output, 1
    end
  
    test 'appends list and paragraph block when line following list attached by continuation' do
      input = <<-EOS
== Lists

term1::

* one
* two
* three

+
para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/ul/li', output, 3
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end
  
    test 'first continued line associated with nested list item and second continued line associated with term' do
      input = <<-EOS
== Lists

term1::
* one
+
nested list para

+
term1 para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/ul/li', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/ul/li/*[@class="paragraph"]/p[text()="nested list para"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]/p[text()="term1 para"]', output, 1
    end
  
    test 'literal line attached by continuation swallows adjacent line that looks like term' do
      input = <<-EOS
== Lists

term1::
+
  literal
notnestedterm:::
+
  literal
notnestedterm:::
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 2
      assert_xpath %(//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="  literal\nnotnestedterm:::"]), output, 2
    end
  
    test 'line attached by continuation is appended as paragraph if term has no inline definition' do
      input = <<-EOS
== Lists

term1::
+
para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'attached paragraph does not break on adjacent nested labeled list term' do
      input = <<-EOS
term1:: def
+
more definition
not a term::: def
      EOS

      output = render_embedded_string input
      assert_css '.dlist > dl > dt', output, 1
      assert_css '.dlist > dl > dd', output, 1
      assert_css '.dlist > dl > dd > .paragraph', output, 1
      assert output.include?('not a term::: def')
    end

    # FIXME pending
=begin
    test 'attached paragraph does not break on adjacent sibling labeled list term' do
      input = <<-EOS
term1:: def
+
more definition
not a term:: def
      EOS

      output = render_embedded_string input
      assert_css '.dlist > dl > dt', output, 1
      assert_css '.dlist > dl > dd', output, 1
      assert_css '.dlist > dl > dd > .paragraph', output, 1
      assert output.include?('not a term:: def')
    end
=end

    test 'attached styled paragraph does not break on adjacent nested labeled list term' do
      input = <<-EOS
term1:: def
+
[quote]
more definition
not a term::: def
      EOS

      output = render_embedded_string input
      assert_css '.dlist > dl > dt', output, 1
      assert_css '.dlist > dl > dd', output, 1
      assert_css '.dlist > dl > dd > .quoteblock', output, 1
      assert output.include?('not a term::: def')
    end
  
    test 'appends line as paragraph if attached by continuation following blank line and line comment when term has no inline definition' do
      input = <<-EOS
== Lists

term1::

// comment
+
para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
    end
  
    test 'line attached by continuation offset by blank line is appended as paragraph if term has no inline definition' do
      input = <<-EOS
== Lists

term1::

+
para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
    end
  
    test 'delimited block breaks list even when term has no inline definition' do
      input = <<-EOS
== Lists

term1::
====
detached
====
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 0
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="exampleblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="exampleblock"]//p[text()="detached"]', output, 1
    end
  
    test 'attribute line breaks list even when term has no inline definition' do
      input = <<-EOS
== Lists

term1::
[verse]
detached
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 0
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="verseblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="verseblock"]/pre[text()="detached"]', output, 1
    end
  
    test 'id line breaks list even when term has no inline definition' do
      input = <<-EOS
== Lists

term1::
[[id]]
detached
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 0
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]/p[text()="detached"]', output, 1
    end
  end

  context 'Item with text inline' do

    test 'folds text from inline definition and subsequent line' do
      input = <<-EOS
== Lists

term1:: def1
continued
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued"]), output, 1
    end
  
    test 'folds text from inline definition and subsequent lines' do
      input = <<-EOS
== Lists

term1:: def1
continued
continued
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued\ncontinued"]), output, 1
    end
  
    test 'folds text from inline definition and line following comment line' do
      input = <<-EOS
== Lists

term1:: def1
// comment
continued
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued"]), output, 1
    end
  
    test 'folds text from inline definition and subsequent indented line' do
      input = <<-EOS
== Lists

term1:: def1
  continued
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued"]), output, 1
    end
  
    test 'appends literal line offset by blank line as block if item has inline definition' do
      input = <<-EOS
== Lists

term1:: def1

  literal
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end
  
    test 'appends literal line offset by blank line as block and appends line after continuation as block if item has inline definition' do
      input = <<-EOS
== Lists

term1:: def1

  literal
+
para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end
  
    test 'appends line after continuation as block and literal line offset by blank line as block if item has inline definition' do
      input = <<-EOS
== Lists

term1:: def1
+
para

  literal
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end
  
    test 'appends list if item has inline definition' do
      input = <<-EOS
== Lists

term1:: def1

* one
* two
* three
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="ulist"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="ulist"]/ul/li', output, 3
    end
  
    test 'appends literal line attached by continuation as block if item has inline definition followed by ruler' do
      input = <<-EOS
== Lists

term1:: def1
+
  literal

'''
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::hr', output, 1
    end
  
    test 'line offset by blank line breaks list if term has inline definition' do
      input = <<-EOS
== Lists

term1:: def1

detached
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]/p[text()="detached"]', output, 1
    end

    test 'nested term with definition does not consume following heading' do
      input = <<-EOS
== Lists

term::
  def
  nestedterm;;
    nesteddef

Detached
~~~~~~~~
      EOS

      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '//*[@class="dlist"]/dl//dl', output, 1
      assert_xpath '//*[@class="dlist"]/dl//dl/dt', output, 1
      assert_xpath '((//*[@class="dlist"])[1]//dd)[1]/p[text()="def"]', output, 1
      assert_xpath '((//*[@class="dlist"])[1]//dd)[1]/p/following-sibling::*[@class="dlist"]', output, 1
      assert_xpath '((//*[@class="dlist"])[1]//dd)[1]/p/following-sibling::*[@class="dlist"]//dd/p[text()="nesteddef"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sect2"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sect2"]/h3[text()="Detached"]', output, 1
    end
  
    test 'line attached by continuation is appended as paragraph if term has inline definition followed by detached paragraph' do
      input = <<-EOS
== Lists

term1:: def1
+
para

detached
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]/p[text()="detached"]', output, 1
    end
  
    test 'line attached by continuation is appended as paragraph if term has inline definition followed by detached block' do
      input = <<-EOS
== Lists

term1:: def1
+
para

****
detached
****
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sidebarblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sidebarblock"]//p[text()="detached"]', output, 1
    end
  
    test 'line attached by continuation offset by line comment is appended as paragraph if term has inline definition' do
      input = <<-EOS
== Lists

term1:: def1
// comment
+
para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end
  
    test 'line attached by continuation offset by blank line is appended as paragraph if term has inline definition' do
      input = <<-EOS
== Lists

term1:: def1

+
para
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end
  
    test 'line comment offset by blank line divides lists because item has text' do
      input = <<-EOS
== Lists

term1:: def1

//

term2:: def2
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
    end
  
    test 'ruler offset by blank line divides lists because item has text' do
      input = <<-EOS
== Lists

term1:: def1

'''

term2:: def2
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
    end
  
    test 'block title offset by blank line divides lists and becomes title of second list because item has text' do
      input = <<-EOS
== Lists

term1:: def1

.title

term2:: def2
      EOS
  
      output = render_embedded_string input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
      assert_xpath '(//*[@class="dlist"])[2]/*[@class="title"][text()="title"]', output, 1
    end
  end
end

context 'Callout lists' do
  test 'listing block with sequential callouts followed by adjacent callout list' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' # <1>
doc = Asciidoctor::Document.new('Hello, World!') # <2>
puts doc.render # <3>
----
<1> Describe the first line
<2> Describe the second line
<3> Describe the third line
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@id = "CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@id = "CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@id = "CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 3
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-2"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[3][@arearefs = "CO1-3"]', output, 1
  end

  test 'listing block with sequential callouts followed by non-adjacent callout list' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' # <1>
doc = Asciidoctor::Document.new('Hello, World!') # <2>
puts doc.render # <3>
----

Paragraph.

<1> Describe the first line
<2> Describe the second line
<3> Describe the third line
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@id = "CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@id = "CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@id = "CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::*[1][self::simpara]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 3
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-2"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[3][@arearefs = "CO1-3"]', output, 1
  end

  test 'listing block with a callout that refers to two different lines' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' # <1>
doc = Asciidoctor::Document.new('Hello, World!') # <2>
puts doc.render # <2>
----
<1> Import the library
<2> Where the magic happens
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@id = "CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@id = "CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@id = "CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 2
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-2 CO1-3"]', output, 1
  end

  test 'listing block with non-sequential callouts followed by adjacent callout list' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' # <2>
doc = Asciidoctor::Document.new('Hello, World!') # <3>
puts doc.render # <1>
----
<1> Describe the first line
<2> Describe the second line
<3> Describe the third line
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@id = "CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@id = "CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@id = "CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 3
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-3"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[3][@arearefs = "CO1-2"]', output, 1
  end

  test 'two listing blocks can share the same callout list' do
    input = <<-EOS
.Import library
[source, ruby]
----
require 'asciidoctor' # <1>
----

.Use library
[source, ruby]
----
doc = Asciidoctor::Document.new('Hello, World!') # <2>
puts doc.render # <3>
----

<1> Describe the first line
<2> Describe the second line
<3> Describe the third line
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//programlisting', output, 2
    assert_xpath '(//programlisting)[1]//co', output, 1
    assert_xpath '(//programlisting)[1]//co[@id = "CO1-1"]', output, 1
    assert_xpath '(//programlisting)[2]//co', output, 2
    assert_xpath '((//programlisting)[2]//co)[1][@id = "CO1-2"]', output, 1
    assert_xpath '((//programlisting)[2]//co)[2][@id = "CO1-3"]', output, 1
    assert_xpath '(//calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//calloutlist/callout)[2][@arearefs = "CO1-2"]', output, 1
    assert_xpath '(//calloutlist/callout)[3][@arearefs = "CO1-3"]', output, 1
  end

  test 'two listing blocks each followed by an adjacent callout list' do
    input = <<-EOS
.Import library
[source, ruby]
----
require 'asciidoctor' # <1>
----
<1> Describe the first line

.Use library
[source, ruby]
----
doc = Asciidoctor::Document.new('Hello, World!') # <1>
puts doc.render # <2>
----
<1> Describe the second line
<2> Describe the third line
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//programlisting', output, 2
    assert_xpath '(//programlisting)[1]//co', output, 1
    assert_xpath '(//programlisting)[1]//co[@id = "CO1-1"]', output, 1
    assert_xpath '(//programlisting)[2]//co', output, 2
    assert_xpath '((//programlisting)[2]//co)[1][@id = "CO2-1"]', output, 1
    assert_xpath '((//programlisting)[2]//co)[2][@id = "CO2-2"]', output, 1
    assert_xpath '//calloutlist', output, 2
    assert_xpath '(//calloutlist)[1]/callout', output, 1
    assert_xpath '((//calloutlist)[1]/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//calloutlist)[2]/callout', output, 2
    assert_xpath '((//calloutlist)[2]/callout)[1][@arearefs = "CO2-1"]', output, 1
    assert_xpath '((//calloutlist)[2]/callout)[2][@arearefs = "CO2-2"]', output, 1
  end

  test 'callout list with block content' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' # <1>
doc = Asciidoctor::Document.new('Hello, World!') # <2>
puts doc.render # <3>
----
<1> Imports the library
as a RubyGem
<2> Creates a new document
* Scans the lines for known blocks
* Converts the lines into blocks
<3> Renders the document
+
You can write this to file rather than printing to stdout.
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//calloutlist', output, 1
    assert_xpath '//calloutlist/callout', output, 3
    assert_xpath '(//calloutlist/callout)[1]/*', output, 1
    assert_xpath '(//calloutlist/callout)[2]/para', output, 1
    assert_xpath '(//calloutlist/callout)[2]/itemizedlist', output, 1
    assert_xpath '(//calloutlist/callout)[3]/para', output, 1
    assert_xpath '(//calloutlist/callout)[3]/simpara', output, 1
  end

  test 'escaped callout should not be interpreted as a callout' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' # \\<1>
----
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//co', output, 0
  end

  test 'should not recognize callouts in middle of line' do
    input = <<-EOS
[source, ruby]
----
puts "The syntax <1> at the end of the line makes a code callout"
----
    EOS
    output = render_embedded_string input
    assert_xpath '//b', output, 0
  end

  test 'should allow multiple callouts on the same line' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' <1>
doc = Asciidoctor.load('Hello, World!') # <2> <3> <4>
puts doc.render <5><6>
exit 0
----
<1> Require library
<2> Load document from String
<3> Uses default backend and doctype
<4> One more for good luck
<5> Renders document to String
<6> Prints output to stdout
    EOS
    output = render_embedded_string input
    assert_xpath '//code/b', output, 6
    assert_match(/ <b class="conum">\(1\)<\/b>$/, output)
    assert_match(/ <b class="conum">\(2\)<\/b> <b class="conum">\(3\)<\/b> <b class="conum">\(4\)<\/b>$/, output)
    assert_match(/ <b class="conum">\(5\)<\/b><b class="conum">\(6\)<\/b>$/, output)
  end

  test 'should allow XML comment-style callouts' do
    input = <<-EOS
[source, xml]
----
<section>
  <title>Section Title</title> <!--1-->
  <simpara>Just a paragraph</simpara> <!--2-->
</section>
----
<1> The title is required
<2> The content isn't
    EOS
    output = render_embedded_string input
    assert_xpath '//b', output, 2
    assert_xpath '//b[text()="(1)"]', output, 1
    assert_xpath '//b[text()="(2)"]', output, 1
  end

  test 'should not allow callouts with half an XML comment' do
    input = <<-EOS
----
First line <1-->
Second line <2-->
----
    EOS
    output = render_embedded_string input
    assert_xpath '//b', output, 0
  end

  test 'should not recognize callouts in an indented labeled list paragraph' do
    input = <<-EOS
foo::
  bar <1>

<1> Not pointing to a callout
    EOS
    output = render_embedded_string input
    assert_xpath '//dl//b', output, 0
    assert_xpath '//dl/dd/p[text()="bar <1>"]', output, 1
    assert_xpath '//ol/li/p[text()="Not pointing to a callout"]', output, 1
  end

  test 'should not recognize callouts in an indented outline list paragraph' do
    input = <<-EOS
* foo
  bar <1>

<1> Not pointing to a callout
    EOS
    output = render_embedded_string input
    assert_xpath '//ul//b', output, 0
    assert_xpath %(//ul/li/p[text()="foo\nbar <1>"]), output, 1
    assert_xpath '//ol/li/p[text()="Not pointing to a callout"]', output, 1
  end

  test 'should remove leading line comment chars' do
    input = <<-EOS
----
puts 'Hello, world!' # <1>
----
<1> Ruby

----
println 'Hello, world!' // <1>
----
<1> Groovy

----
(def hello (fn [] "Hello, world!")) ;; <1>
(hello)
----
<1> Clojure
    EOS
    output = render_embedded_string input
    assert_xpath '//b', output, 3
    nodes = xmlnodes_at_css 'pre', output 
    assert_equal "puts 'Hello, world!' (1)", nodes[0].text
    assert_equal "println 'Hello, world!' (1)", nodes[1].text
    assert_equal %((def hello (fn [] "Hello, world!")) (1)\n(hello)), nodes[2].text
  end

  test 'literal block with callouts' do
    input = <<-EOS
....
Roses are red <1>
Violets are blue <2>
....


<1> And so is Ruby
<2> But violet is more like purple
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//literallayout', output, 1
    assert_xpath '//literallayout//co', output, 2
    assert_xpath '(//literallayout//co)[1][@id = "CO1-1"]', output, 1
    assert_xpath '(//literallayout//co)[2][@id = "CO1-2"]', output, 1
    assert_xpath '//literallayout/following-sibling::*[1][self::calloutlist]/callout', output, 2
    assert_xpath '(//literallayout/following-sibling::*[1][self::calloutlist]/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//literallayout/following-sibling::*[1][self::calloutlist]/callout)[2][@arearefs = "CO1-2"]', output, 1
  end

  test 'callout list with icons enabled' do
    input = <<-EOS
[source, ruby]
----
require 'asciidoctor' # <1>
doc = Asciidoctor::Document.new('Hello, World!') # <2>
puts doc.render # <3>
----
<1> Describe the first line
<2> Describe the second line
<3> Describe the third line
    EOS
    output = render_embedded_string input, :attributes => {'icons' => ''}
    assert_css '.listingblock code > img', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="listingblock"]//code/img)[#{i}][@src="./images/icons/callouts/#{i}.png"][@alt="#{i}"]), output, 1
    end
    assert_css '.colist table td img', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="colist arabic"]//td/img)[#{i}][@src="./images/icons/callouts/#{i}.png"][@alt="#{i}"]), output, 1
    end
  end

  test 'callout list with font-based icons enabled' do
    input = <<-EOS
[source]
----
require 'asciidoctor' # <1>
doc = Asciidoctor::Document.new('Hello, World!') #<2>
puts doc.render #<3>
----
<1> Describe the first line
<2> Describe the second line
<3> Describe the third line
    EOS
    output = render_embedded_string input, :attributes => {'icons' => 'font'}
    assert_css '.listingblock code > i', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="listingblock"]//code/i)[#{i}]), output, 1
      assert_xpath %((/div[@class="listingblock"]//code/i)[#{i}][@class="conum"][@data-value="#{i}"]), output, 1
      assert_xpath %((/div[@class="listingblock"]//code/i)[#{i}]/following-sibling::b[text()="(#{i})"]), output, 1
    end
    assert_css '.colist table td i', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="colist arabic"]//td/i)[#{i}]), output, 1
      assert_xpath %((/div[@class="colist arabic"]//td/i)[#{i}][@class="conum"][@data-value = "#{i}"]), output, 1
      assert_xpath %((/div[@class="colist arabic"]//td/i)[#{i}]/following-sibling::b[text() = "#{i}"]), output, 1
    end
  end
end

context 'Checklists' do
  test 'should create checklist if at least one item has checkbox syntax' do
    input = <<-EOS
- [ ] todo
- [x] done
- [ ] another todo
- [*] another done
- plain
    EOS

    output = render_embedded_string input
    assert_css '.ulist.checklist', output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[1]/p[text()="#{expand_entity 10063} todo"]), output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[2]/p[text()="#{expand_entity 10003} done"]), output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[3]/p[text()="#{expand_entity 10063} another todo"]), output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[4]/p[text()="#{expand_entity 10003} another done"]), output, 1
    assert_xpath '(/*[@class="ulist checklist"]/ul/li)[5]/p[text()="plain"]', output, 1
  end

  test 'should create checklist with font icons if at least one item has checkbox syntax and icons attribute is font' do
    input = <<-EOS
- [ ] todo
- [x] done
- plain
    EOS

    output = render_embedded_string input, :attributes => {'icons' => 'font'}
    assert_css '.ulist.checklist', output, 1
    assert_css '.ulist.checklist li i.fa-check-square-o', output, 1
    assert_css '.ulist.checklist li i.fa-square-o', output, 1
    assert_xpath '(/*[@class="ulist checklist"]/ul/li)[3]/p[text()="plain"]', output, 1
  end

  test 'should create interactive checklist if interactive option is set even with icons attribute is font' do
    input = <<-EOS
:icons: font

[options="interactive"]
- [ ] todo
- [x] done
    EOS

    output = render_embedded_string input
    assert_css '.ulist.checklist', output, 1
    assert_css '.ulist.checklist li input[type="checkbox"]', output, 2
    assert_css '.ulist.checklist li input[type="checkbox"][disabled]', output, 0
    assert_css '.ulist.checklist li input[type="checkbox"][checked]', output, 1
  end
end

context 'Lists model' do
  test 'content should return items in list' do
    input = <<-EOS
* one
* two
* three
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    assert list.is_a? Asciidoctor::List
    items = list.items
    assert_equal 3, items.size
    assert_equal list.items, list.content
  end
end
