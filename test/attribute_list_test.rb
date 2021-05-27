# frozen_string_literal: true
require_relative 'test_helper'

context 'AttributeList' do
  test 'collect unnamed attribute' do
    attributes = {}
    line = 'quote'
    expected = { 1 => 'quote' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attribute double-quoted' do
    attributes = {}
    line = '"quote"'
    expected = { 1 => 'quote' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect empty unnamed attribute double-quoted' do
    attributes = {}
    line = '""'
    expected = { 1 => '' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attribute double-quoted containing escaped quote' do
    attributes = {}
    line = '"ba\"zaar"'
    expected = { 1 => 'ba"zaar' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attribute single-quoted' do
    attributes = {}
    line = '\'quote\''
    expected = { 1 => 'quote' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect empty unnamed attribute single-quoted' do
    attributes = {}
    line = '\'\''
    expected = { 1 => '' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect isolated single quote positional attribute' do
    attributes = {}
    line = '\''
    expected = { 1 => '\'' }
    doc = empty_document
    def doc.apply_subs *args
      raise 'apply_subs should not be called'
    end
    Asciidoctor::AttributeList.new(line, doc).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect isolated single quote attribute value' do
    attributes = {}
    line = 'name=\''
    expected = { 'name' => '\'' }
    doc = empty_document
    def doc.apply_subs *args
      raise 'apply_subs should not be called'
    end
    Asciidoctor::AttributeList.new(line, doc).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect attribute value as is if it has only leading single quote' do
    attributes = {}
    line = 'name=\'{val}'
    expected = { 'name' => '\'{val}' }
    doc = empty_document attributes: { 'val' => 'val' }
    def doc.apply_subs *args
      raise 'apply_subs should not be called'
    end
    Asciidoctor::AttributeList.new(line, doc).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attribute single-quoted containing escaped quote' do
    attributes = {}
    line = '\'ba\\\'zaar\''
    expected = { 1 => 'ba\'zaar' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attribute with dangling delimiter' do
    attributes = {}
    line = 'quote , '
    expected = { 1 => 'quote', 2 => nil }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attribute in second position after empty attribute' do
    attributes = {}
    line = ', John Smith'
    expected = { 1 => nil, 2 => 'John Smith' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attributes' do
    attributes = {}
    line = 'first, second one, third'
    expected = { 1 => 'first', 2 => 'second one', 3 => 'third' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect blank unnamed attributes' do
    attributes = {}
    line = 'first,,third,'
    expected = { 1 => 'first', 2 => nil, 3 => 'third', 4 => nil }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect unnamed attribute enclosed in equal signs' do
    attributes = {}
    line = '=foo='
    expected = { 1 => '=foo=' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attribute' do
    attributes = {}
    line = 'foo=bar'
    expected = { 'foo' => 'bar' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attribute double-quoted' do
    attributes = {}
    line = 'foo="bar"'
    expected = { 'foo' => 'bar' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attribute with double-quoted empty value' do
    attributes = {}
    line = 'height=100,caption="",link="images/octocat.png"'
    expected = { 'height' => '100', 'caption' => '', 'link' => 'images/octocat.png' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attribute single-quoted' do
    attributes = {}
    line = 'foo=\'bar\''
    expected = { 'foo' => 'bar' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attribute with single-quoted empty value' do
    attributes = {}
    line = %(height=100,caption='',link='images/octocat.png')
    expected = { 'height' => '100', 'caption' => '', 'link' => 'images/octocat.png' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect single named attribute with empty value' do
    attributes = {}
    line = 'foo='
    expected = { 'foo' => '' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect single named attribute with empty value when followed by other attributes' do
    attributes = {}
    line = 'foo=,bar=baz'
    expected = { 'foo' => '', 'bar' => 'baz' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attributes unquoted' do
    attributes = {}
    line = 'first=value, second=two, third=3'
    expected = { 'first' => 'value', 'second' => 'two', 'third' => '3' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attributes quoted' do
    attributes = {}
    line = %(first='value', second="value two", third=three)
    expected = { 'first' => 'value', 'second' => 'value two', 'third' => 'three' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect named attributes quoted containing non-semantic spaces' do
    attributes = {}
    line = %(     first    =     'value', second     ="value two"     , third=       three      )
    expected = { 'first' => 'value', 'second' => 'value two', 'third' => 'three' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect mixed named and unnamed attributes' do
    attributes = {}
    line = %(first, second="value two", third=three, Sherlock Holmes)
    expected = { 1 => 'first', 'second' => 'value two', 'third' => 'three', 4 => 'Sherlock Holmes' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect mixed empty named and blank unnamed attributes' do
    attributes = {}
    line = 'first,,third=,,fifth=five'
    expected = { 1 => 'first', 2 => nil, 'third' => '', 4 => nil, 'fifth' => 'five' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect options attribute' do
    attributes = {}
    line = %(quote, options='opt1,,opt2 , opt3')
    expected = { 1 => 'quote', 'opt1-option' => '', 'opt2-option' => '', 'opt3-option' => '' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect opts attribute as options' do
    attributes = {}
    line = %(quote, opts='opt1,,opt2 , opt3')
    expected = { 1 => 'quote', 'opt1-option' => '', 'opt2-option' => '', 'opt3-option' => '' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'should ignore options attribute if empty' do
    attributes = {}
    line = %(quote, opts=)
    expected = { 1 => 'quote' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test 'collect and rekey unnamed attributes' do
    attributes = {}
    line = 'first, second one, third, fourth'
    expected = { 1 => 'first', 2 => 'second one', 3 => 'third', 4 => 'fourth', 'a' => 'first', 'b' => 'second one', 'c' => 'third' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes, ['a', 'b', 'c'])
    assert_equal expected, attributes
  end

  test 'should not assign nil to attribute mapped to missing positional attribute' do
    attributes = {}
    line = 'alt text,,100'
    expected = { 1 => 'alt text', 2 => nil, 3 => '100', 'alt' => 'alt text', 'height' => '100' }
    Asciidoctor::AttributeList.new(line).parse_into(attributes, %w(alt width height))
    assert_equal expected, attributes
  end

  test 'rekey positional attributes' do
    attributes = { 1 => 'source', 2 => 'java' }
    expected = { 1 => 'source', 2 => 'java', 'style' => 'source', 'language' => 'java' }
    Asciidoctor::AttributeList.rekey(attributes, ['style', 'language', 'linenums'])
    assert_equal expected, attributes
  end
end
