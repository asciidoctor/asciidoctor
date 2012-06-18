require 'test_helper'

context "Substitions" do
  test "defines" do
    html = render_string(":greeting:    Yo!\n\nA frog says, '{greeting}'")
    result = Nokogiri::HTML(html)
    assert_equal("A frog says, 'Yo!'", result.css("p").first.content.strip)
  end

  test "Intrinsics" do
    html = render_string("Look, a {caret}")
    result = Nokogiri::HTML(html)
    assert_equal("Look, a ^", result.css("p").first.content.strip)
  end

  test "Unknowns" do
    html = render_string("Look, a {gobbledygook}")
    result = Nokogiri::HTML(html)
    assert_equal("Look, a {gobbledygook}", result.css("p").first.content.strip)
  end
end