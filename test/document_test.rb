require 'test_helper'

context "Document" do

  context "Example document" do
    setup do
      @doc = example_document(:asciidoc_index)
    end

    test "test_title" do
      assert_equal "AsciiDoc Home Page", @doc.doctitle
      assert_equal "AsciiDoc Home Page", @doc.name
      assert_equal 14, @doc.elements.size
      assert_equal :preamble, @doc.elements[0].context
      assert @doc.elements[1].is_a? ::Asciidoctor::Section
    end
  end

  test "test_with_no_title" do
    d = document_from_string("Snorf")
    assert_nil d.doctitle
    assert_nil d.name
    assert !d.has_header
    assert_nil d.header
  end

  test "test_with_explicit_title" do
   d = document_from_string("= Title\n:title: Document Title\n\npreamble\n\n== Section") 
   assert_equal 'Document Title', d.doctitle
   assert_equal 'Document Title', d.title
   assert d.has_header
   assert_equal 'Title', d.header.title
   assert_equal 'Title', d.first_section.title
  end

  test "test_empty_document" do
    d = document_from_string('')
    assert d.elements.empty?
    assert_nil d.doctitle
    assert !d.has_header
    assert_nil d.header
  end

  test "test_with_metadata" do
    input = <<-EOS
= AsciiDoc
Stuart Rackham <founder@asciidoc.org>
v8.6.8, 2012-07-12: See changelog.

== Version 8.6.8

more info...
    EOS
    output = render_string input
    assert_xpath '//*[@id="header"]/span[@id="author"][text() = "Stuart Rackham"]', output, 1
    assert_xpath '//*[@id="header"]/span[@id="email"][contains(text(), "founder@asciidoc.org")]', output, 1
    assert_xpath '//*[@id="header"]/span[@id="revnumber"][text() = "version 8.6.8,"]', output, 1
    assert_xpath '//*[@id="header"]/span[@id="revdate"][text() = "2012-07-12"]', output, 1
    assert_xpath '//*[@id="header"]/span[@id="revremark"][text() = "See changelog."]', output, 1
  end

  test "test_with_header_footer" do
    result = render_string("= Title\n\npreamble")
    assert_xpath '/html', result, 1
    assert_xpath '//*[@id="header"]', result, 1
    assert_xpath '//*[@id="footer"]', result, 1
    assert_xpath '//*[@id="preamble"]', result, 1
  end

  test "test_with_no_header_footer" do
    result = render_string("= Title\n\npreamble", :header_footer => false)
    assert_xpath '/html', result, 0
    assert_xpath '/*[@id="header"]', result, 0
    assert_xpath '/*[@id="footer"]', result, 0
    assert_xpath '/*[@id="preamble"]', result, 1
  end
end
