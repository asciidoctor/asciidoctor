require 'test_helper'

context "Paragraphs" do
  test "rendered correctly" do
    assert_xpath "//p", render_string("Plain text for the win.\n\nYes, plainly."), 2
  end

  test "with title" do
    rendered = render_string(".Titled\nParagraph.\n\nWinning")
    
    assert_xpath "//div[@class='title']", rendered
    assert_xpath "//p", rendered, 2
  end

  test "no duplicate block before next section" do
    rendered = render_string("Title\n=====\n\nPreamble.\n\n== First Section\n\nParagraph 1\n\nParagraph 2\n\n\n== Second Section\n\nLast words")
    assert_xpath '//p[text()="Paragraph 2"]', rendered, 1
  end

  context "code" do
    test "literal paragraph" do
      assert_xpath "//pre/tt", render_string("    LITERALS\n\n    ARE LITERALLY\n\n    AWESOMMMME.")
    end

    test "listing paragraph" do
      assert_xpath "//div[@class='highlight']", render_string("----\nblah blah blah\n----")
    end

    test "source code paragraph" do
      assert_xpath "//div[@class='highlight']", render_string("[source, perl]\ndie 'zomg perl sucks';")
    end
  end

  context "special" do
    test "note multiline syntax" do
      assert_xpath "//div[@class='admonitionblock']", render_string("[NOTE]\nThis is a winner.")
    end

    test "note inline syntax" do
      assert_xpath "//div[@class='admonitionblock']", render_string("NOTE: This is important, fool!")
    end
  end
end
