require 'test_helper'

context "Headers" do
  test "document title with multiline syntax" do
    assert_xpath "//h1[text() = 'My Title']", render_string("My Title\n=======")
  end

  test "document title with single-line syntax" do
    assert_xpath "//h1[text() = 'My Title']", render_string("= My Title")
  end

  test "document title with symmetric syntax" do
    assert_xpath "//h1[text() = 'My Title']", render_string("= My Title =")
  end

  context "level 1" do 
    test "with multiline syntax" do
      assert_xpath "//h2[@id='_my_section'][text() = 'My Section']", render_string("My Section\n-----------")
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
      assert_xpath "//h2[@id='_where_s_the_love'][text() = \"Where's the love?\"]", render_string("== Where's the love?")
    end

    test "with sequential non-word characters" do
      assert_xpath "//h2[@id='_what_the_is_this'][text() = 'What the \#@$ is this?']", render_string('== What the #@$ is this?')
    end

    test "with trailing whitespace" do
      assert_xpath "//h2[@id='_my_title'][text() = 'My Title']", render_string("== My Title ")
    end
  end

  context "level 2" do 
    test "with multiline syntax" do
      assert_xpath "//h3[@id='_my_section'][text() = 'My Section']", render_string("My Section\n~~~~~~~~~~~")
    end

    test "with single line syntax" do
      assert_xpath "//h3[@id='_my_title'][text() = 'My Title']", render_string("=== My Title")
    end
  end  

  context "level 3" do 
    test "with multiline syntax" do
      assert_xpath "//h4[@id='_my_section'][text() = 'My Section']", render_string("My Section\n^^^^^^^^^^")
    end

    test "with single line syntax" do
      assert_xpath "//h4[@id='_my_title'][text() = 'My Title']", render_string("==== My Title")
    end
  end

  context "level 4" do 
    test "with multiline syntax" do
      assert_xpath "//h5[@id='_my_section'][text() = 'My Section']", render_string("My Section\n++++++++++")
    end

    test "with single line syntax" do
      assert_xpath "//h5[@id='_my_title'][text() = 'My Title']", render_string("===== My Title")
    end
  end  
end
