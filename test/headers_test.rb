require 'test_helper'

context "Headers" do
  test "main header" do
    assert_xpath "//h1", render_string("My Title\n=======")
  end

  context "level 1" do 
    test "with multiline syntax" do
      assert_xpath "//h2[@id='_my_section']", render_string("My Section\n-----------")
    end

    test "with single line syntax" do
      assert_xpath "//h2[@id='_my_title']", render_string("== My Title")
    end

    test "with non-word character" do
      assert_xpath "//h2[@id='_where_s_the_love']", render_string("== Where's the love?")
    end

    test "with sequential non-word characters" do
      assert_xpath "//h2[@id='_what_the_is_that']", render_string('== What the #@$ is that')
    end
  end

  context "level 2" do 
    test "with multiline syntax" do
      assert_xpath "//h3", render_string("My Section\n~~~~~~~~~~~")
    end

    test "with single line syntax" do
      assert_xpath "//h3", render_string("=== My Title")
    end
  end  

  context "level 3" do 
    test "with multiline syntax" do
      assert_xpath "//h4", render_string("My Section\n^^^^^^^^^^")
    end

    test "with single line syntax" do
      assert_xpath "//h4", render_string("==== My Title")
    end
  end

  context "level 4" do 
    test "with multiline syntax" do
      assert_xpath "//h5", render_string("My Section\n++++++++++")
    end

    test "with single line syntax" do
      assert_xpath "//h5", render_string("===== My Title")
    end
  end  
end
