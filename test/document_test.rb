require 'test_helper'

class DocumentTest < Test::Unit::TestCase
  # setup for test
  def setup
    @doc = example_document(:asciidoc_index)
  end

  def test_title
    assert_equal "AsciiDoc Home Page", @doc.doctitle
    assert_equal "AsciiDoc Home Page", @doc.name
    assert_equal 14, @doc.elements.size
    assert_equal :preamble, @doc.elements[0].context
    assert @doc.elements[1].is_a? ::Asciidoctor::Section
  end

  def test_with_no_title
    d = document_from_string("Snorf")
    assert_nil d.doctitle
    assert_nil d.name
    assert !d.has_header
    assert_nil d.header
  end

  def test_with_explicit_title
   d = document_from_string("= Title\n:title: Document Title\n\npreamble\n\n== Section") 
   assert_equal 'Document Title', d.doctitle
   assert_equal 'Document Title', d.title
   assert d.has_header
   assert_equal 'Title', d.header.title
   assert_equal 'Title', d.first_section.title
  end

  def test_empty_document
    d = document_from_string('')
    assert d.elements.empty?
    assert_nil d.doctitle
    assert !d.has_header
    assert_nil d.header
  end

  def test_with_header_footer
    result = render_string("= Title\n\npreamble")
    assert_xpath '/html', result, 1
    assert_xpath '//*[@id="header"]', result, 1
    assert_xpath '//*[@id="footer"]', result, 1
    assert_xpath '//*[@id="preamble"]', result, 1
  end

  def test_with_no_header_footer
    result = render_string("= Title\n\npreamble", :header_footer => false)
    assert_xpath '/html', result, 0
    assert_xpath '/*[@id="header"]', result, 0
    assert_xpath '/*[@id="footer"]', result, 0
    assert_xpath '/*[@id="preamble"]', result, 1
  end
end
