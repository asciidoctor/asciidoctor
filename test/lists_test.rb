require 'test_helper'

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
  end

  context "Lists with inline markup" do
    test "quoted text" do
      input = <<-EOS
List
====

- I am *strong*.
- I am 'stressed'.
- I am `flexible`.
      EOS
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]//strong', output, 1
      assert_xpath '(//ul/li)[2]//em', output, 1
      assert_xpath '(//ul/li)[3]//tt', output, 1
    end

    test "attribute substitutions" do
      input = <<-EOS
List
====
:foo: bar

- side a {brvbar} side b
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
      output = render_embedded_string input
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

    test "consecutive blocks in list continuation attach to list item" do
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
      output = render_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@class = "literalblock"]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[2][@class = "quoteblock"]', output, 1
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
  end
end

context "Labeled lists (:dlist)" do
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

    test "paragraph attached by a list continuation in a labeled list" do
      input = <<-EOS
term1:: def
+
more detail
+
term2:: def
      EOS
      output = render_string input
      assert_xpath '(//dl/dd)[1]//p', output, 2
      assert_xpath '(//dl/dd)[1]/p/following-sibling::*[@class="paragraph"]/p[text() = "more detail"]', output, 1
    end

    test "paragraph attached by a list continuation to a multi-line element in a labeled list" do
      input = <<-EOS
term1::
def
+
more detail
+
term2:: def
      EOS
      output = render_string input
      assert_xpath '(//dl/dd)[1]//p', output, 2
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
end

context 'Labeled lists redux' do

  context 'Item without text inline' do

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
      assert_xpath %(//*[@class="dlist"]//dd/p/em[text()="'"]), output, 1
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
      assert_xpath %(//*[@class="dlist"]//dd/p/em[text()="'"]), output, 1
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
      assert_xpath %(//*[@class="dlist"]//dd/p/em[text()="'"]), output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[normalize-space(text())="continued"]), output, 1
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
      # NOTE the extra endline is added as a result of whitespace in the ERB template
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued\n\ncontinued"]), output, 1
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
[source]
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
[source]
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
[source]
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
[source]
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
[source]
----
require 'asciidoctor' # <1>
----

.Use library
[source]
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
[source]
----
require 'asciidoctor' # <1>
----
<1> Describe the first line

.Use library
[source]
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
[source]
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
[source]
----
require 'asciidoctor' # \\<1>
----
    EOS
    output = render_string input, :attributes => {'backend' => 'docbook45'}
    assert_xpath '//co', output, 0
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
end
