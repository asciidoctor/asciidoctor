require 'test_helper'

context "Headers" do
  test "main header" do
    assert_xpath "//h1", render_string("My Title\n=======")
  end

  context "level 1" do 
    test "with multiline syntax" do
      assert_xpath "//h2", render_string("My Section\n-----------")
    end

    test "with single line syntax" do
      assert_xpath "//h2", render_string("== My Title")
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