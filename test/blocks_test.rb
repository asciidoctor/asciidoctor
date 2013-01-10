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
      output = render_string(input)
      assert_xpath '//pre', output, 1
      assert_xpath '//pre/text()', output, 1
      text = node_from_string(output, '//pre/text()').content
      lines = text.lines.entries
      assert_equal 5, lines.size
      expected = "line one\n\nline two\n\nline three".lines.entries
      assert_equal expected, lines
    end

    test "should preserve endlines in listing block" do
      input = <<-EOS
----
line one

line two

line three
----
EOS
      output = render_string(input)
      assert_xpath '//pre/code', output, 1
      assert_xpath '//pre/code/text()', output, 1
      text = node_from_string(output, '//pre/code/text()').content
      lines = text.lines.entries
      assert_equal 5, lines.size
      expected = "line one\n\nline two\n\nline three".lines.entries
      assert_equal expected, lines
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
      output = render_string(input)
      assert_xpath '//*[@class="verseblock"]/pre', output, 1
      assert_xpath '//*[@class="verseblock"]/pre/text()', output, 1
      text = node_from_string(output, '//*[@class="verseblock"]/pre/text()').content
      lines = text.lines.entries
      assert_equal 5, lines.size
      expected = "line one\n\nline two\n\nline three".lines.entries
      assert_equal expected, lines
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

      expected = %(This is a 'passthrough' block.\n<a href="http://asciidoc.org">http://asciidoc.org</a>\n)
      output = render_embedded_string input
      assert_equal expected, output
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

      expected = %(This is a <em>passthrough</em> block.\nhttp://asciidoc.org\n)
      output = render_embedded_string input
      assert_equal expected, output
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

      doc = document_from_string input, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal 'fixtures', doc.attributes['imagesdir']
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    # this test will cause a warning to be printed to the console (until we have a message facility)
    test 'does not allow access to ancestor directories to read image if safepaths attribute is set' do
      input = <<-EOS
:data-uri:
:imagesdir: ../fixtures

image::dot.gif[Dot]
      EOS

      doc = document_from_string input, :attributes => {'docdir' => File.dirname(__FILE__)}
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

    test 'embeds base64-encoded data uri for icon when data-uri attribute is set' do
      input = <<-EOS
:icons:
:iconsdir: fixtures
:iconstype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end

    test 'does not allow access to ancestor directories to read icon if safepaths attribute is set' do
      input = <<-EOS
:icons:
:iconsdir: ../fixtures
:iconstype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end
  end

  context 'Image paths' do

    test 'restricts access to ancestor directories when safepaths is enabled' do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.dirname(__FILE__)
      block = block_from_string input, :attributes => {'docdir' => basedir}
      doc = block.document
      assert doc.attr('safe-paths') == true

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      assert_equal File.join(basedir, 'etc/images'), block.normalize_asset_path('/etc/images')
      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('../../images')
    end

    test "doesn't restrict access to ancestor directories when safepaths is disabled" do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.dirname(__FILE__)
      block = block_from_string input, :attributes => {'docdir' => basedir, 'safepaths' => false}
      doc = block.document
      assert doc.attr('safepaths') == false

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      assert_equal '/etc/images', block.normalize_asset_path('/etc/images')
      assert_equal File.expand_path(File.join(basedir, '../../images')), block.normalize_asset_path('../../images')
    end

  end
end
