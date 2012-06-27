require 'test_helper'

context "Bulleted lists (:ulist)" do
  context "Simple lists" do
    test "dash elements with no blank lines" do
      output = render_string("Blah\n====\n- Foo\n- Boo\n- Blech")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
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

  context "Nested lists" do
    test "nested mixed elements (asterisk and dash)" do
      output = render_string("Blah\n====\n- Foo\n* Boo\n- Blech")
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "nested elements (2) with asterisks" do
      output = render_string("* Foo\n** Boo\n* Blech")
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
    end

    test "nested elements (3) with asterisks" do
      output = render_string("Blah\n====\n* Foo\n** Boo\n*** Snoo\n* Blech")
      assert_xpath '//ul', output, 3
      assert_xpath '//ul/li', output, 4
    end

    test "nested elements (4) with asterisks" do
      output = render_string("Blah\n====\n* Foo\n** Boo\n*** Snoo\n**** Froo\n* Blech")
      assert_xpath '//ul', output, 4
      assert_xpath '//ul/li', output, 5
    end

    test "nested elements (5) with asterisks" do
      output = render_string("Blah\n====\n* Foo\n** Boo\n*** Snoo\n**** Froo\n***** Groo\n* Blech")
      assert_xpath '//ul', output, 5
      assert_xpath '//ul/li', output, 6
    end
  end
end
