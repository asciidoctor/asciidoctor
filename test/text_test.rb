require 'test_helper'

context "Text" do
  test "line breaks" do
    assert_xpath "//br", render_string("Well this is +\njust fine and dandy, isn't it?"), 1
  end

  test "quotes" do
    rendered = render_string("``Where?,'' she said, flipping through her copy of `The New Yorker.'")
    assert_match /&rdquo;/, rendered
    assert_match /&ldquo;/, rendered
    assert_match /&rsquo;/, rendered
    assert_match /&lsquo;/, rendered
  end

  test "separator" do
    assert_xpath "//hr", render_string("This is separated.\n\n''''\n\n...from this!"), 1
  end

  context "basic styling" do 
    setup do
      @rendered = render_string("A *BOLD* word.  An _italic_ word.  A +mono+ word.  ^superscript!^ and some ~subscript~.")
    end

    test "bold" do
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

    test "combined styles" do
      rendered = render_string("Winning *big _time_* in the +city *boyeeee*+.")
      
      assert_xpath "//strong/em", rendered
      assert_xpath "//tt/strong", rendered
    end

    test "characters" do
      rendered_chars = render_string("**B**__I__++M++")
      assert_xpath "//strong", rendered_chars 
      assert_xpath "//em", rendered_chars 
      assert_xpath "//tt", rendered_chars 
    end
  end  
end