require 'test_helper'

class DocumentTest < Test::Unit::TestCase
  # setup for test
  def setup
    @doc = example_document(:asciidoc_index)
  end

  def test_title
    assert_equal "AsciiDoc Home Page", @doc.doctitle
    assert_equal 14, @doc.elements.size
    assert_equal :preamble, @doc.elements[0].context
    assert @doc.elements[1].is_a? ::Asciidoctor::Section
  end

  def test_with_no_title
    d = Asciidoctor::Document.new(["Snorf"])
    assert_nil d.doctitle
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
