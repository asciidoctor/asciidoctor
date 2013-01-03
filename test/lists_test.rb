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

    # NOTE this differs from AsciiDoc behavior, but is more logical
    test "consecutive list continuation lines are folded" do
      return pending "Rework test to support more compliant behavior"
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

    # FIXME!
    test "paragraph attached by a list continuation to a multi-line element in a labeled list" do
      return pending "We're assuming the list continuation would be the first line after the term"
      input = <<-EOS
term1::
def
+
more detail
+
term2:: def
      EOS
      #output = render_string input
      #assert_xpath '(//dl/dd)[1]//p', output, 2
      #assert_xpath '(//dl/dd)[1]/p/following-sibling::*[@class="paragraph"]/p[text() = "more detail"]', output, 1
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

    test "should only grab one stray paragraph following last item" do
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

    test "should only grab one stray paragraph following last item when it has a paragraph literal" do
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

    test "multi-line nested elements seperated by blank line at nested level" do
      input = <<-EOS
term1::
def1
label1:::

detail1
label2:::
detail2

term:: def2
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
