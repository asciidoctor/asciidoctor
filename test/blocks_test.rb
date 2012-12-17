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
end
