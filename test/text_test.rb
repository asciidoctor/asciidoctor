require 'test_helper'

context "Text" do
  test 'escaped text markup' do
    pending "Not done yet"
  end

  test "line breaks" do
    assert_xpath "//br", render_string("Well this is +\njust fine and dandy, isn't it?"), 1
  end

  test "single- and double-quoted text" do
    rendered = render_string("``Where?,'' she said, flipping through her copy of `The New Yorker.'")
    assert_match /&ldquo;Where\?,&rdquo;/, rendered
    assert_match /&lsquo;The New Yorker.&rsquo;/, rendered
  end

  test "separator" do
    assert_xpath "//hr", render_string("This is separated.\n\n'''\n\n...from this!"), 1
  end

  test "emphasized text" do
    assert_xpath "//em", render_string("An 'emphatic' no")
  end

  test "emphasized text with escaped single quote" do
    assert_xpath "//em[text()=\"Johnny's\"]", render_string("It's 'Johnny\'s' phone")
  end

  test "emphasized text at end of line" do
    assert_xpath "//em", render_string("This library is 'awesome'")
  end

  test "emphasized text at beginning of line" do
    assert_xpath "//em", render_string("'drop' it")
  end

  test "emphasized text across line" do
    assert_xpath "//em", render_string("'check it'")
  end

  test "unquoted text" do
    assert_no_match /#/, render_string("An #unquoted# word")
  end

  test "backtick-escaped text followed by single-quoted text" do
    assert_match /<tt>foo<\/tt>/, render_string(%Q(run `foo` 'dog'))
  end

  context "basic styling" do
    setup do
      @rendered = render_string("A *BOLD* word.  An _italic_ word.  A +mono+ word.  ^superscript!^ and some ~subscript~.")
    end

    test "strong" do
      assert_xpath "//strong", @rendered
    end

    test "italic" do
      assert_xpath "//em", @rendered
    end

    test "monospaced" do
      assert_xpath "//tt", @rendered
    end

    test "superscript" do
      assert_xpath "//sup", @rendered
    end

    test "subscript" do
      assert_xpath "//sub", @rendered
    end

    test "backticks" do
      assert_xpath "//tt", render_string("This is `totally cool`.")
    end

    test "nested styles" do
      rendered = render_string("Winning *big _time_* in the +city *boyeeee*+.")

      assert_xpath "//strong/em", rendered
      assert_xpath "//tt/strong", rendered
    end

    test "unconstrained quotes" do
      rendered_chars = render_string("**B**__I__++M++")
      assert_xpath "//strong", rendered_chars
      assert_xpath "//em", rendered_chars
      assert_xpath "//tt", rendered_chars
    end
  end
end
