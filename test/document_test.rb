require 'test_helper'

class DocumentTest < Test::Unit::TestCase
  # setup for test
  def setup
    @doc = example_document(:asciidoc_index)
  end

  def test_title
    assert_equal "AsciiDoc Home Page", @doc.title
    assert_equal 14, @doc.elements.size
    assert_equal :preamble, @doc.elements[0].context
    assert_true @doc.elements[1].is_a? ::Asciidoctor::Section
  end

  def test_with_no_title
    d = Asciidoctor::Document.new(["Snorf"])
    assert_nil d.title
  end
end
