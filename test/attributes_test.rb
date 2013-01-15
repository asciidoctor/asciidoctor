require 'test_helper'

context 'Attributes' do
  context 'Assignment' do
    test 'creates an attribute' do
      doc = document_from_string(':frog: Tanglefoot')
      assert_equal 'Tanglefoot', doc.attributes['frog']
    end

    test 'creates an attribute by fusing a multi-line value' do
      str = <<-EOS
:description: This is the first +
              Ruby implementation of +
              AsciiDoc.
      EOS
      doc = document_from_string(str)
      assert_equal 'This is the first Ruby implementation of AsciiDoc.', doc.attributes['description']
    end

    test 'deletes an attribute' do
      doc = document_from_string(":frog: Tanglefoot\n:frog!:")
      assert_equal nil, doc.attributes['frog']
    end

    test "doesn't choke when deleting a non-existing attribute" do
      doc = document_from_string(':frog!:')
      assert_equal nil, doc.attributes['frog']
    end

    test "replaces special characters in attribute value" do
      doc = document_from_string(":xml-busters: <>&")
      assert_equal '&lt;&gt;&amp;', doc.attributes['xml-busters']
    end

    test "performs attribute substitution on attribute value" do
      doc = document_from_string(":version: 1.0\n:release: Asciidoctor {version}")
      assert_equal 'Asciidoctor 1.0', doc.attributes['release']
    end

    test "assigns attribute to empty string if substitution fails to resolve attribute" do
      doc = document_from_string(":release: Asciidoctor {version}")
      assert_equal '', doc.attributes['release']
    end

    test "assigns multi-line attribute to empty string if substitution fails to resolve attribute" do
      doc = document_from_string(":release: Asciidoctor +\n          {version}")
      assert_equal '', doc.attributes['release']
    end

    test "apply custom substitutions to text in passthrough macro and assign to attribute" do
      doc = document_from_string(":xml-busters: pass:[<>&]")
      assert_equal '<>&', doc.attributes['xml-busters']
      doc = document_from_string(":xml-busters: pass:none[<>&]")
      assert_equal '<>&', doc.attributes['xml-busters']
      doc = document_from_string(":xml-busters: pass:specialcharacters[<>&]")
      assert_equal '&lt;&gt;&amp;', doc.attributes['xml-busters']
    end

    test "attribute is treated as defined until it's not" do
      input = <<-EOS
:holygrail:
ifdef::holygrail[]
The holy grail has been found!
endif::holygrail[]

:holygrail!:
ifndef::holygrail[]
Buggers! What happened to the grail?
endif::holygrail[]
      EOS
      output = render_string input
      assert_xpath '//p', output, 2
      assert_xpath '(//p)[1][text() = "The holy grail has been found!"]', output, 1
      assert_xpath '(//p)[2][text() = "Buggers! What happened to the grail?"]', output, 1
    end

    # Validates requirement: "Header attributes are overridden by command-line attributes."
    test 'attribute defined in document options overrides attribute in document' do
      doc = document_from_string(':cash: money', :attributes => {'cash' => 'heroes'})
      assert_equal 'heroes', doc.attributes['cash']
    end

    test 'attribute defined in document options cannot be unassigned in document' do
      doc = document_from_string(':cash!:', :attributes => {'cash' => 'heroes'})
      assert_equal 'heroes', doc.attributes['cash']
    end

    test 'attribute undefined in document options cannot be assigned in document' do
      doc = document_from_string(':cash: money', :attributes => {'cash!' => 1 })
      assert_equal nil, doc.attributes['cash']
      doc = document_from_string(':cash: money', :attributes => {'cash' => nil })
      assert_equal nil, doc.attributes['cash']
    end

    test 'backend attributes are updated if backend attribute is defined in document' do
      doc = document_from_string(':backend: docbook45')
      assert_equal 'docbook45', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-docbook45'
      assert_equal 'docbook', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-docbook'
    end

    test 'backend attributes defined in document options overrides backend attribute in document' do
      doc = document_from_string(':backend: docbook45', :attributes => {'backend' => 'html5'})
      assert_equal 'html5', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-html5'
      assert_equal 'html', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-html'
    end

  end

  context 'Interpolation' do

    test "render properly with simple names" do
      html = render_string(":frog: Tanglefoot\n:my_super-hero: Spiderman\n\nYo, {frog}!\nBeat {my_super-hero}!")
      result = Nokogiri::HTML(html)
      assert_equal "Yo, Tanglefoot!\nBeat Spiderman!", result.css("p").first.content.strip
    end

    test "render properly with single character name" do
      html = render_string(":r: Ruby\n\nR is for {r}!")
      result = Nokogiri::HTML(html)
      assert_equal 'R is for Ruby!', result.css("p").first.content.strip
    end

    test "convert multi-word names and render" do
      html = render_string("Main Header\n===========\n:My frog: Tanglefoot\n\nYo, {myfrog}!")
      result = Nokogiri::HTML(html)
      assert_equal 'Yo, Tanglefoot!', result.css("p").first.content.strip
    end

    test "ignores lines with bad attributes" do
      html = render_string("This is\nblah blah {foobarbaz}\nall there is.")
      result = Nokogiri::HTML(html)
      assert_no_match(/blah blah/m, result.css("p").first.content.strip)
    end

    test "attribute value gets interpretted when rendering" do
      doc = document_from_string(":google: http://google.com[Google]\n\n{google}")
      assert_equal 'http://google.com[Google]', doc.attributes['google']
      output = doc.render
      assert_xpath '//a[@href="http://google.com"][text() = "Google"]', output, 1
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
      assert_match(/snort at the bar/, result.css("li").first.content.strip)
    end

    test 'substitutes inside section title' do
      output = render_string(":prefix: Cool\n\n== {prefix} Title\n\ncontent")
      result = Nokogiri::HTML(output)
      assert_match(/Cool Title/, result.css('h2').first.content)
      assert_match(/_cool_title/, result.css('h2').first.attr('id'))
    end

    test 'substitutes inside block title' do
      input = <<-EOS
:gem_name: asciidoctor

.Require the +{gem_name}+ gem
To use {gem_name}, the first thing to do is to import it in your Ruby source file.
      EOS
      output = render_embedded_string input
      assert_xpath '//*[@class="title"]/tt[text()="asciidoctor"]', output, 1
    end

    test 'renders attribute until it is deleted' do
      pending 'This requires that we consume attributes as the document is being lexed, not up front'
      #output = render_string(":foo: bar\n\nCrossing the {foo}\n\n:foo!:\nBelly up to the {foo}")
      # result = Nokogiri::HTML(html)
      # assert_match /Crossing the bar/, result.css("p").first.content.strip
      # assert_no_match /Belly up to the bar/, result.css("p").last.content.strip
    end

    test 'does not disturb attribute-looking things escaped with backslash' do
      html = render_string(":foo: bar\nThis is a \\{foo} day.")
      result = Nokogiri::HTML(html)
      assert_equal 'This is a {foo} day.', result.css('p').first.content.strip
    end

    test 'does not disturb attribute-looking things escaped with literals' do
      html = render_string(":foo: bar\nThis is a +++{foo}+++ day.")
      result = Nokogiri::HTML(html)
      assert_equal 'This is a {foo} day.', result.css('p').first.content.strip
    end

    test 'does not substitute attributes inside listing blocks' do
      input = <<-EOS
:forecast: snow 

----
puts 'The forecast for today is {forecast}'
----
      EOS
      output = render_string(input)
      assert_match(/\{forecast\}/, output)
    end

    test 'does not substitute attributes inside literal blocks' do
       input = <<-EOS
:foo: bar

....
You insert the text {foo} to expand the value
of the attribute named foo in your document.
....
       EOS
      output = render_string(input)
      assert_match(/\{foo\}/, output)
    end
  end

  context "Intrinsic attributes" do

    test "substitute intrinsics" do
      Asciidoctor::INTRINSICS.each_pair do |key, value|
        html = render_string("Look, a {#{key}} is here")
        # can't use Nokogiri because it interprets the HTML entities and we can't match them
        assert_match(/Look, a #{Regexp.escape(value)} is here/, html)
      end
    end

    test "don't escape intrinsic substitutions" do
      html = render_string('happy{nbsp}together')
      assert_match(/happy&#160;together/, html)
    end

    test "escape special characters" do
      html = render_string('<node>&</node>')
      assert_match(/&lt;node&gt;&amp;&lt;\/node&gt;/, html)
    end
    
  end

  context "Block attributes" do
    test "Position attributes assigned to block" do
      input = <<-EOS
[quote, Name, Source]
____
A famous quote.
____
      EOS
      doc = document_from_string(input)
      qb = doc.blocks.first
      assert_equal 'quote', qb.attributes['style']
      assert_equal 'quote', qb.attr(:style)
      assert_equal 'Name', qb.attributes['attribution']
      assert_equal 'Source', qb.attributes['citetitle']
    end

    test "Normal substitutions are performed on single-quoted attributes" do
      input = <<-EOS
[quote, Name, 'http://wikipedia.org[Source]']
____
A famous quote.
____
      EOS
      doc = document_from_string(input)
      qb = doc.blocks.first
      assert_equal 'quote', qb.attributes['style']
      assert_equal 'quote', qb.attr(:style)
      assert_equal 'Name', qb.attributes['attribution']
      assert_equal '<a href="http://wikipedia.org">Source</a>', qb.attributes['citetitle']
    end

    test "Attribute substitutions are performed on attribute list before parsing attributes" do
      input = <<-EOS
:lead: role="lead"

[{lead}]
A paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal 'lead', para.attributes['role']
    end

    test "Block attributes are additive" do
      input = <<-EOS
[id='foo']
[role='lead']
A paragraph.
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal 'foo', para.id
      assert_equal 'lead', para.attributes['role']
    end

    test "Last wins for id attribute" do
      input = <<-EOS
[[bar]]
[[foo]]
== Section

paragraph

[[baz]]
[id='coolio']
=== Section
      EOS
      doc = document_from_string(input)
      sec = doc.first_section
      assert_equal 'foo', sec.id
      subsec = sec.blocks.last
      assert_equal 'coolio', subsec.id
    end

    test "trailing block attributes tranfer to the following section" do
      input = <<-EOS
[[one]]

== Section One

paragraph

[[sub]]
// try to mess this up!

=== Sub-section

paragraph

[role='classy']

////
block comment
////

== Section Two

content
      EOS
      doc = document_from_string(input)
      section_one = doc.blocks.first
      assert_equal 'one', section_one.id
      subsection = section_one.blocks.last
      assert_equal 'sub', subsection.id
      section_two = doc.blocks.last
      assert_equal 'classy', section_two.attr(:role)
    end
  end

end
