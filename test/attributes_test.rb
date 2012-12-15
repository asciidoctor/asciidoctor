require 'test_helper'

context "Attributes" do
  test "creates an attribute" do
    doc = document_from_string(":frog: Tanglefoot")
    assert_equal doc.attributes['frog'], 'Tanglefoot'
  end

  test "deletes an attribute" do
    doc = document_from_string(":frog: Tanglefoot\n:frog!:")
    assert_equal nil, doc.attributes['frog']
  end

  test "doesn't choke when deleting a non-existing attribute" do
    doc = document_from_string(":frog!:")
    assert_equal nil, doc.attributes['frog']
  end

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
    assert_no_match /blah blah/m, result.css("p").first.content.strip
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

  test "renders attribute until it's deleted" do
    pending "Not working yet (will require adding element-specific attributes or early attr substitution during parsing)"
    # html = render_string(":foo: bar\nCrossing the {foo}\n\n:foo!:\nBelly up to the {foo}")
    # result = Nokogiri::HTML(html)
    # assert_match /Crossing the bar/, result.css("p").first.content.strip
    # assert_no_match /Belly up to the bar/, result.css("p").last.content.strip
  end

  test "doesn't disturb attribute-looking things escaped with backslash" do
    html = render_string(":foo: bar\nThis is a \\{foo} day.")
    result = Nokogiri::HTML(html)
    assert_equal 'This is a {foo} day.', result.css('p').first.content.strip
  end

  test "doesn't disturb attribute-looking things escaped with literals" do
    html = render_string(":foo: bar\nThis is a +++{foo}+++ day.")
    result = Nokogiri::HTML(html)
    assert_equal 'This is a {foo} day.', result.css('p').first.content.strip
  end

  test "doesn't substitute attributes inside code blocks" do
    pending "whut?"
  end

  test "doesn't substitute attributes inside literal blocks" do
    pending "whut?"
  end

  context "intrinsics" do

    test "substitute intrinsics" do
      Asciidoctor::INTRINSICS.each_pair do |key, value|
        html = render_string("Look, a {#{key}} is here")
        # can't use Nokogiri because it interprets the HTML entities and we can't match them
        assert_match /Look, a #{Regexp.escape(value)} is here/, html
      end
    end

    test "don't escape intrinsic substitutions" do
      html = render_string('happy{nbsp}together')
      assert_match /happy&#160;together/, html
    end

    test "escape special characters" do
      html = render_string('<node>&</node>')
      assert_match /&lt;node&gt;&amp;&lt;\/node&gt;/, html
    end
    
  end

end
