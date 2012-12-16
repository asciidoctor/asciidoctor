require 'test_helper'

context "Headers" do
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

  test "document title with single-line syntax" do
    assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string("= My Title")
  end

  test "document title with symmetric syntax" do
    assert_xpath "//h1[not(@id)][text() = 'My Title']", render_string("= My Title =")
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

    test "with custom blank idprefix" do
      assert_xpath "//h2[@id='my_title'][text() = 'My Title']", render_string(":idprefix:\n\n== My Title ")
    end

    test "with custom non-blank idprefix" do
      assert_xpath "//h2[@id='ref_my_title'][text() = 'My Title']", render_string(":idprefix: ref_\n\n== My Title ")
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
