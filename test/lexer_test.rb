require 'test_helper'

class LexerTest < Test::Unit::TestCase
  # setup for test
  def setup
  end

  def test_is_section_heading
    assert Asciidoctor::Lexer.is_section_heading?("AsciiDoc Home Page", "==================")
    assert Asciidoctor::Lexer.is_section_heading?("=== AsciiDoc Home Page")
  end

  def test_collect_unnamed_attributes
    attributes = {}
    line = "first, second one, third"
    Asciidoctor::Lexer.collect_attributes(line, attributes)
    assert_equal 3, attributes.length
    assert_equal 'first', attributes[0]
    assert_equal 'second one', attributes[1]
    assert_equal 'third', attributes[2]
  end

  def test_collect_named_attributes
    attributes = {}
    line = "first='value', second=\"value two\", third=three"
    Asciidoctor::Lexer.collect_attributes(line, attributes)
    assert_equal 3, attributes.length
    assert_equal 'value', attributes['first']
    assert_equal 'value two', attributes['second']
    assert_equal 'three', attributes['third']
  end

  def test_collect_mixed_named_and_unnamed_attributes
    attributes = {}
    line = "first, second=\"value two\", third=three"
    Asciidoctor::Lexer.collect_attributes(line, attributes)
    assert_equal 3, attributes.length
    assert_equal 'first', attributes[0]
    assert_equal 'value two', attributes['second']
    assert_equal 'three', attributes['third']
  end

  def test_collect_and_rekey_unnamed_attributes
    attributes = {}
    line = "first, second one, third, fourth"
    Asciidoctor::Lexer.collect_attributes(line, attributes, ['a', 'b', 'c'])
    assert_equal 7, attributes.length
    assert_equal 'first', attributes['a']
    assert_equal 'second one', attributes['b']
    assert_equal 'third', attributes['c']
    assert_equal 'first', attributes[0]
    assert_equal 'second one', attributes[1]
    assert_equal 'third', attributes[2]
    assert_equal 'fourth', attributes[3]
  end

  def test_rekey_positional_attributes
    attributes = {0 => 'source', 1 => 'java'}
    Asciidoctor::Lexer.rekey_positional_attributes(attributes, ['style', 'language', 'linenums'])
    assert_equal 4, attributes.length
    assert_equal 'source', attributes[0]
    assert_equal 'java', attributes[1]
    assert_equal 'source', attributes['style']
    assert_equal 'java', attributes['language']
  end
end
