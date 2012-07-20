require 'test_helper'

context "Attributes" do
  test "render properly with simple names" do
    html = render_string(":frog: Tanglefoot\nYo, {frog}!")
    result = Nokogiri::HTML(html)
    assert_equal 'Yo, Tanglefoot!', result.css("p").first.content.strip
  end

  test "convert multi-word names and render" do
    html = render_string("Main Header\n===========\n:My frog: Tanglefoot\nYo, {myfrog}!")
    result = Nokogiri::HTML(html)
    assert_equal 'Yo, Tanglefoot!', result.css("p").first.content.strip
  end

  test "ignores lines with bad attributes" do
    html = render_string("This is\nblah blah {foobarbaz}\nall there is.")
    result = Nokogiri::HTML(html)
    assert_equal 'This is all there is.', result.css("p").first.content.strip
  end

  # See above - AsciiDoc says we're supposed to delete lines with bad
  # attribute refs in them. AsciiDoc is strange.
  #
  # test "Unknowns" do
  #   html = render_string("Look, a {gobbledygook}")
  #   result = Nokogiri::HTML(html)
  #   assert_equal("Look, a {gobbledygook}", result.css("p").first.content.strip)
  # end

  test "substitutes inside unordered list items" do
    html = render_string(":foo: bar\n* snort at the {foo}\n* yawn")
    result = Nokogiri::HTML(html)
    assert_match /snort at the bar/, result.css("li").first.content.strip
  end

  test "deletes an existing attribute" do
    pending "Not done yet"
  end

  test "doesn't choke when deleting a non-existing attribute" do
    pending "Not done yet"
  end

  test "doesn't disturb escaped attribute-looking things" do
    pending "Not done yet"
  end

  test "doesn't subsitute attributes inside code blocks" do
    pending "whut?"
  end

  test "doesn't subsitute attributes inside literal blocks" do
    pending "whut?"
  end

  test "Intrinsics" do
    html = render_string("Look, a {caret}")
    result = Nokogiri::HTML(html)
    assert_equal("Look, a ^", result.css("p").first.content.strip)
  end

end
