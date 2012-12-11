require 'test_helper'

context "Links" do

  test "absolute url with link prefix" do
    assert_xpath "//a[@href='http://asciidoc.org']", render_string("We're parsing link:http://asciidoc.org[AsciiDoc] markup")
  end

end
