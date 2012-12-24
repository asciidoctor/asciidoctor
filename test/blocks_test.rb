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

  context "Comments" do
    test "line comment between paragraphs" do
      output = render_string("first paragraph\n\n//comment\n\nsecond paragraph")
      assert_no_match /comment/, output
      assert_xpath '//p', output, 2
    end

    test "comment block between paragraphs" do
      output = render_string("first paragraph\n\n////\ncomment\n////\n\nsecond paragraph")
      assert_no_match /comment/, output
      assert_xpath '//p', output, 2
    end

    test "can render with block comment at end of document with trailing endlines" do
      output = render_string("Paragraph\n\n////\nblock comment\n////\n\n")
      assert_no_match /block comment/, output
    end

    test "trailing endlines after block comment at end of document does not create paragraph" do
      d = document_from_string("Paragraph\n\n////\nblock comment\n////\n\n")
      assert_equal 1, d.elements.size
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
  end
end
