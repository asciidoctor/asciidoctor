require 'test_helper'

context "Attributes" do
  test "render properly with simple names" do
    output = render_string(":frog: Tanglefoot\nYo, {frog}!")
    results = Nokogiri::HTML::DocumentFragment.parse(output).xpath(".//p")
    assert_equal 'Yo, Tanglefoot!', results[0].content
  end

  test "convert multi-word names and render" do
    output = render_string("Main Header\n===========\n:My frog: Tanglefoot\nYo, {myfrog}!")
    results = Nokogiri::HTML::DocumentFragment.parse(output).xpath(".//p")
    assert_equal 'Yo, Tanglefoot!', results[0].content
  end
end
