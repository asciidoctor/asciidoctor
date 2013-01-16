require 'test_helper'

context "Blocks" do
  context "Rulers" do
    test "ruler" do
      output = render_string("'''")
      assert_xpath '//*[@id="content"]/hr', output, 1
      assert_xpath '//*[@id="content"]/*', output, 1
    end

    test "ruler between blocks" do
      output = render_string("Block above\n\n'''\n\nBlock below")
      assert_xpath '//*[@id="content"]/hr', output, 1
      assert_xpath '//*[@id="content"]/hr/preceding-sibling::*', output, 1
      assert_xpath '//*[@id="content"]/hr/following-sibling::*', output, 1
    end
  end

  context 'Comments' do
    test 'line comment between paragraphs offset by blank lines' do
      input = <<-EOS
first paragraph

// line comment

second paragraph
      EOS
      output = render_embedded_string input
      assert_no_match(/line comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent line comment between paragraphs' do
      input = <<-EOS
first line
// line comment
second line
      EOS
      output = render_embedded_string input
      assert_no_match(/line comment/, output)
      assert_xpath '//p', output, 1
      assert_xpath "//p[1][text()='first line\nsecond line']", output, 1
    end

    test 'comment block between paragraphs offset by blank lines' do
      input = <<-EOS
first paragraph

////
block comment
////

second paragraph
      EOS
      output = render_embedded_string input
      assert_no_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent comment block between paragraphs' do
      input = <<-EOS
first paragraph
////
block comment
////
second paragraph
      EOS
      output = render_embedded_string input
      assert_no_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test "can render with block comment at end of document with trailing endlines" do
      input = <<-EOS
paragraph

////
block comment
////


      EOS
      output = render_embedded_string input
      assert_no_match(/block comment/, output)
    end

    test "trailing endlines after block comment at end of document does not create paragraph" do
      input = <<-EOS
paragraph

////
block comment
////


      EOS
      d = document_from_string input
      assert_equal 1, d.blocks.size
      assert_xpath '//p', d.render, 1
    end
  end

  context "Example Blocks" do
    test "can render example block" do
      input = <<-EOS
====
This is an example of an example block.

How crazy is that?
====
      EOS

      output = render_string input
      assert_xpath '//*[@class="exampleblock"]//p', output, 2
    end
  end

  context "Preformatted Blocks" do
    test 'should separate adjacent paragraphs and listing into blocks' do
      input = <<-EOS
paragraph 1
----
listing content
----
paragraph 2
      EOS
      
      output = render_embedded_string input
      assert_xpath '/*[@class="paragraph"]/p', output, 2
      assert_xpath '/*[@class="listingblock"]', output, 1
      assert_xpath '(/*[@class="paragraph"]/following-sibling::*)[1][@class="listingblock"]', output, 1
    end

    test "should preserve endlines in literal block" do
      input = <<-EOS
....
line one

line two

line three
....
EOS
      [true, false].each {|compact|
        output = render_string input, :compact => compact
        assert_xpath '//pre', output, 1
        assert_xpath '//pre/text()', output, 1
        text = xmlnodes_at_xpath('//pre/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[[:blank:]]*\n/).size
        if compact
          assert_equal 2, blank_lines
        else
          assert blank_lines > 2
        end
      }
    end

    test "should preserve endlines in listing block" do
      input = <<-EOS
[source]
----
line one

line two

line three
----
EOS
      [true, false].each {|compact|
        output = render_string input, :compact => compact
        assert_xpath '//pre/code', output, 1
        assert_xpath '//pre/code/text()', output, 1
        text = xmlnodes_at_xpath('//pre/code/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[[:blank:]]*\n/).size
        if compact
          assert_equal 2, blank_lines
        else
          assert blank_lines > 2
        end
      }
    end

    test "should preserve endlines in verse block" do
      input = <<-EOS
[verse]
____
line one

line two

line three
____
EOS
      [true, false].each {|compact|
        output = render_string input, :compact => compact
        assert_xpath '//*[@class="verseblock"]/pre', output, 1
        assert_xpath '//*[@class="verseblock"]/pre/text()', output, 1
        text = xmlnodes_at_xpath('//*[@class="verseblock"]/pre/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[[:blank:]]*\n/).size
        if compact
          assert_equal 2, blank_lines
        else
          assert blank_lines > 2
        end
      }
    end
  end

  context "Open Blocks" do
    test "can render open block" do
      input = <<-EOS
--
This is an open block.

It can span multiple lines.
--
      EOS

      output = render_string input
      assert_xpath '//*[@class="openblock"]//p', output, 2
    end

    test "open block can contain another block" do
      input = <<-EOS
--
This is an open block.

It can span multiple lines.

____
It can hold great quotes like this one.
____
--
      EOS

      output = render_string input
      assert_xpath '//*[@class="openblock"]//p', output, 3
      assert_xpath '//*[@class="openblock"]//*[@class="quoteblock"]', output, 1
    end
  end

  context 'Passthrough Blocks' do
    test 'can parse a passthrough block' do
      input = <<-EOS
++++
This is a passthrough block.
++++
      EOS

      block = block_from_string input
      assert !block.nil?
      assert_equal 1, block.buffer.size
      assert_equal 'This is a passthrough block.', block.buffer.first
    end

    test 'performs passthrough subs on a passthrough block' do
      input = <<-EOS
:type: passthrough

++++
This is a '{type}' block.
http://asciidoc.org
++++
      EOS

      expected = %(This is a 'passthrough' block.\n<a href="http://asciidoc.org">http://asciidoc.org</a>)
      output = render_embedded_string input
      assert_equal expected, output.strip
    end

    test 'passthrough block honors explicit subs list' do
      input = <<-EOS
:type: passthrough

[subs="attributes, quotes"]
++++
This is a '{type}' block.
http://asciidoc.org
++++
      EOS

      expected = %(This is a <em>passthrough</em> block.\nhttp://asciidoc.org)
      output = render_embedded_string input
      assert_equal expected, output.strip
    end
  end

  context 'Metadata' do
    test 'block title above section gets carried over to first block in section' do
      input = <<-EOS
.Title
== Section

paragraph
      EOS
      output = render_string input
      assert_xpath '//*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="paragraph"]/*[@class="title"][text() = "Title"]', output, 1
      assert_xpath '//*[@class="paragraph"]/p[text() = "paragraph"]', output, 1
    end
  end

  context "Images" do
    test "can render block image with alt text" do
      input = <<-EOS
image::images/tiger.png[Tiger]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test "can render block image with auto-generated alt text" do
      input = <<-EOS
image::images/tiger.png[]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="tiger"]', output, 1
    end

    test "can render block image with alt text and height and width" do
      input = <<-EOS
image::images/tiger.png[Tiger, 200, 300]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"][@width="200"][@height="300"]', output, 1
    end

    test "can render block image with link" do
      input = <<-EOS
image::images/tiger.png[Tiger, link='http://en.wikipedia.org/wiki/Tiger']
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//a[@class="image"][@href="http://en.wikipedia.org/wiki/Tiger"]/img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test "can render block image with caption" do
      input = <<-EOS
.The AsciiDoc Tiger
image::images/tiger.png[Tiger]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
      assert_xpath '//*[@class="imageblock"]/*[@class="title"][text() = "The AsciiDoc Tiger"]', output, 1
    end

    test 'can resolve image relative to imagesdir' do
      input = <<-EOS
:imagesdir: images

image::tiger.png[Tiger]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'embeds base64-encoded data uri for image when data-uri attribute is set' do
      input = <<-EOS
:data-uri:
:imagesdir: fixtures

image::dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal 'fixtures', doc.attributes['imagesdir']
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    # this test will cause a warning to be printed to the console (until we have a message facility)
    test 'cleans reference to ancestor directories before reading image if safe mode level is at least SAFE' do
      input = <<-EOS
:data-uri:
:imagesdir: ../fixtures

image::dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal '../fixtures', doc.attributes['imagesdir']
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end
  end

  context 'Admonition icons' do
    test 'can resolve icon relative to default iconsdir' do
      input = <<-EOS
:icons:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input
      assert_xpath '//*[@class="admonitionblock"]//*[@class="icon"]/img[@src="images/icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'can resolve icon relative to custom iconsdir' do
      input = <<-EOS
:icons:
:iconsdir: icons

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input
      assert_xpath '//*[@class="admonitionblock"]//*[@class="icon"]/img[@src="icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'embeds base64-encoded data uri of icon when data-uri attribute is set and safe mode level is less than SECURE' do
      input = <<-EOS
:icons:
:iconsdir: fixtures
:iconstype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end

    test 'does not embed base64-encoded data uri of icon when safe mode level is at least SECURE' do
      input = <<-EOS
:icons:
:iconsdir: fixtures
:iconstype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input
      assert_xpath '//*[@class="admonitionblock"]//*[@class="icon"]/img[@src="fixtures/tip.gif"][@alt="Tip"]', output, 1
    end

    test 'cleans reference to ancestor directories before reading icon if safe mode level is at least SAFE' do
      input = <<-EOS
:icons:
:iconsdir: ../fixtures
:iconstype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end
  end

  context 'Image paths' do

    test 'restricts access to ancestor directories when safe mode level is at least SAFE' do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.dirname(__FILE__)
      block = block_from_string input, :attributes => {'docdir' => basedir}
      doc = block.document
      assert doc.safe >= Asciidoctor::SafeMode::SAFE

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      assert_equal File.join(basedir, 'etc/images'), block.normalize_asset_path('/etc/images')
      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('../../images')
    end

    test 'does not restrict access to ancestor directories when safe mode is disabled' do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.dirname(__FILE__)
      block = block_from_string input, :safe => Asciidoctor::SafeMode::UNSAFE, :attributes => {'docdir' => basedir}
      doc = block.document
      assert doc.safe == Asciidoctor::SafeMode::UNSAFE

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      assert_equal '/etc/images', block.normalize_asset_path('/etc/images')
      assert_equal File.expand_path(File.join(basedir, '../../images')), block.normalize_asset_path('../../images')
    end

  end

  context 'Source code' do
    test 'should highlight source if source-highlighter attribute is coderay' do
      input = <<-EOS
:source-highlighter: coderay

[source, ruby]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_xpath '//pre[@class="highlight CodeRay"]/code[@class="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
      assert_match(/\.CodeRay \{/, output)
    end

    test 'should highlight source inline if source-highlighter attribute is coderay and coderay-css is style' do
      input = <<-EOS
:source-highlighter: coderay
:coderay-css: style

[source, ruby]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_xpath '//pre[@class="highlight CodeRay"]/code[@class="ruby"]//span[@style = "color:#036;font-weight:bold"][text() = "CodeRay"]', output, 1
      assert_no_match(/\.CodeRay \{/, output)
    end

    test 'should include remote highlight.js assets if source-highlighter attribute is highlightjs' do
      input = <<-EOS
:source-highlighter: highlightjs

[source, javascript]
----
<link rel="stylesheet" href="styles/default.css">
<script src="highlight.pack.js"></script>
<script>hljs.initHighlightingOnLoad();</script>
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_match(/<link .*highlight\.js/, output)
      assert_match(/<script .*highlight\.js/, output)
      assert_match(/hljs.initHighlightingOnLoad/, output)
    end

    test 'document cannot turn on source highlighting if safe mode is at least SECURE' do
      input = <<-EOS
:source-highlighter: coderay
      EOS
      doc = document_from_string input
      assert doc.attributes['source-highlighter'].nil?
    end
  end

end
