require 'test_helper'

context "Bulleted lists (:ulist)" do
  test "dash elements with no blank lines" do
    assert_xpath '//ul/li', render_string("Blah\n====\n- Foo\n- Boo\n- Blech"), 3
  end

  test "dash elements with blank lines" do
    assert_xpath '//ul/li', render_string("Blah\n====\n- Foo\n\n- Boo\n\n- Blech"), 3
  end

  test "asterisk elements with no blank lines" do
    assert_xpath '//ul/li', render_string("Blah\n====\n* Foo\n* Boo\n* Blech"), 3
  end

  test "asterisk elements with blank lines" do
    assert_xpath '//ul/li', render_string("Blah\n====\n* Foo\n\n* Boo\n\n* Blech"), 3
  end
end
