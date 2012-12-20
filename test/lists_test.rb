require 'test_helper'

context "Bulleted lists (:ulist)" do
  context "Simple lists" do
    test "dash elements with no blank lines" do
      output = render_string("Blah\n====\n\n- Foo\n- Boo\n- Blech")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "dash elements with blank lines" do
      output = render_string("Blah\n====\n\n- Foo\n\n- Boo\n\n- Blech")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "asterisk elements with no blank lines" do
      output = render_string("Blah\n====\n\n* Foo\n* Boo\n* Blech")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "asterisk elements with blank lines should merge lists" do
      output = render_string("Blah\n====\n\n* Foo\n\n* Boo\n\n* Blech")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "asterisk elements with blank lines separated by line comment should not merge lists" do
      output = render_string("Blah\n====\n\n* Foo\n* Boo\n\n//\n\n* Blech")
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end
  end

  context "Lists with inline markup" do
    test "Quoted text" do
      output = render_string("Blah\n====\n\n- I am *strong*.\n- I am 'stressed'.\n- I am `inflexible`.")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]//strong', output, 1
      assert_xpath '(//ul/li)[2]//em', output, 1
      assert_xpath '(//ul/li)[3]//tt', output, 1
    end

    test "Attribute substitutions" do
      output = render_string("Blah\n====\n:foo: bar\n\n- side a {brvbar} side b\n- Take me to a {foo}.")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '(//ul/li)[1]//p[text() = "side a | side b"]', output, 1
      assert_xpath '(//ul/li)[2]//p[text() = "Take me to a bar."]', output, 1
    end
  end

  context "Nested lists" do
    test "nested mixed elements (asterisk and dash)" do
      output = render_string("Blah\n====\n\n- Foo\n* Boo\n- Blech")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "nested elements (2) with asterisks" do
      output = render_string("* Foo\n** Boo\n* Blech")
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "nested elements (3) with asterisks" do
      output = render_string("Blah\n====\n\n* Foo\n** Boo\n*** Snoo\n* Blech")
      assert_xpath '//ul', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test "nested elements (4) with asterisks" do
      output = render_string("Blah\n====\n\n* Foo\n** Boo\n*** Snoo\n**** Froo\n* Blech")
      assert_xpath '//ul', output, 4
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test "nested elements (5) with asterisks" do
      output = render_string("Blah\n====\n\n* Foo\n** Boo\n*** Snoo\n**** Froo\n***** Groo\n* Blech")
      assert_xpath '//ul', output, 5
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end
  end

  context "List continuations" do
    test "Adjacent list continuation line attaches following paragraph" do
      input = <<-EOS
Lists
=====

* Item one, paragraph one
+
Item one, paragraph two
+
* Item two
      EOS
      output = render_string(input)
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '//ul/li[1]//p', output, 2
      assert_xpath '//ul/li[1]//p[text() = "Item one, paragraph one"]', output, 1
      assert_xpath '//ul/li[1]//p[text() = "Item one, paragraph two"]', output, 1
    end

    test "Adjacent list continuation line attaches following block" do
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
      output = render_string(input)
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@class = "literalblock"]', output, 1
    end

    test "Consecutive blocks in list continuation attach to list item" do
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
      output = render_string(input)
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@class = "literalblock"]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[2][@class = "quoteblock"]', output, 1
    end

    # NOTE this differs from AsciiDoc behavior, but is more logical
    test "Consecutive list continuation lines are folded" do
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
      output = render_string(input)
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
      output = render_string("Blah\n\n====\n\n. Foo\n. Boo\n. Blech")
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end
  end
end

context "Labeled lists (:dlist)" do
  context "Simple lists" do
    test "single-line adjacent elements" do
      output = render_string("term1:: def1\nterm2:: def2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line indented adjacent elements" do
      output = render_string("term1:: def1\n term2:: def2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line elements separated by blank line" do
      output = render_string("term1:: def1\n\nterm2:: def2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
    end

    test "multi-line elements with paragraph content" do
      output = render_string("term1::\ndef1\nterm2::\ndef2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with indented paragraph content" do
      output = render_string("term1::\n def1\nterm2::\n  def2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with blank line before paragraph content" do
      output = render_string("term1::\n\ndef1\nterm2::\n\ndef2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with paragraph and literal content" do
      output = render_string("term1::\n  def1\n\n  literal\nterm2::\n  def2")
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
      output = render_string("term1:: def1\nterm2::\ndef2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "element with anchor" do
      output = render_string("[[term1]]term1:: def1\n[[term2]]term2:: def2")
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '(//dl/dt)[1]/a[@id = "term1"]', output, 1
      assert_xpath '(//dl/dt)[2]/a[@id = "term2"]', output, 1
    end

    test "missing space before term does not produce labeled list" do
      output = render_string("term1::def1\nterm2::def2")
      assert_xpath '//dl', output, 0
    end
  end

  context "Nested lists" do
    test "single-line adjacent nested elements" do
      output = render_string("term1:: def1\nlabel1::: detail1\nterm2:: def2")
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
      output = render_string("term1:: def1\nlabel1::: detail1\nname1:::: value1\nitem1;; price1\nterm2:: def2")
      assert_xpath '//dl', output, 4
      assert_xpath '//dl//dl//dl//dl', output, 1
    end

    test "single-line nested elements seperated by blank line at top level" do
      output = render_string("term1:: def1\n\nlabel1::: detail1\n\nterm2:: def2")
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    # FIXME test pending, haven't fixed lexer to allow blank line at nested level
    #test "single-line nested elements seperated by blank line at nested level" do
    #  output = render_string("term1:: def1\nlabel1::: detail1\n\nlabel2::: detail2\nterm2:: def2")
    #  assert_xpath '//dl', output, 2
    #  assert_xpath '//dl//dl', output, 1
    #  assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
    #  assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
    #  assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
    #  assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
    #  assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
    #  assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    #end

    test "single-line adjacent nested elements with alternate delimiters" do
      output = render_string("term1:: def1\nlabel1;; detail1\nterm2:: def2")
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
      output = render_string("term1::\ndef1\nlabel1:::\ndetail1\nterm2::\ndef2")
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    # FIXME test pending, haven't fixed lexer to allow blank line at nested level
    #test "multi-line nested elements seperated by blank line at nested level" do
    #  output = render_string("term1::\ndef1\nlabel1:::\n\ndetail1\nlabel2:::\ndetail2\n\nterm2:: def2")
    #  assert_xpath '//dl', output, 2
    #  assert_xpath '//dl//dl', output, 1
    #  assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
    #  assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
    #  assert_xpath '(//dl//dl/dt)[1][normalize-space(text()) = "label1"]', output, 1
    #  assert_xpath '(//dl//dl/dt)[1]/following-sibling::dd/p[text() = "detail1"]', output, 1
    #  assert_xpath '(//dl//dl/dt)[2][normalize-space(text()) = "label2"]', output, 1
    #  assert_xpath '(//dl//dl/dt)[2]/following-sibling::dd/p[text() = "detail2"]', output, 1
    #end

    test "mixed single and multi-line elements with indented nested elements" do
      output = render_string("term1:: def1\n  label1:::\n    detail1\nterm2:: def2")
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
      output = render_string("term1:: def1\ncontinued\nlabel1:::\ndetail1")
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
