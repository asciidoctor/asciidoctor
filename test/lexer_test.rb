require 'test_helper'

context "Lexer" do

  test "test_is_section_title" do
    assert Asciidoctor::Lexer.is_section_title?('AsciiDoc Home Page', '==================')
    assert Asciidoctor::Lexer.is_section_title?('=== AsciiDoc Home Page')
  end

  test "collect unnamed attribute" do
    attributes = {}
    line = 'quote'
    expected = {1 => 'quote'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect unnamed attribute double-quoted" do
    attributes = {}
    line = '"quote"'
    expected = {1 => 'quote'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect unnamed attribute double-quoted containing escaped quote" do
    attributes = {}
    line = '"ba\"zaar"'
    expected = {1 => 'ba"zaar'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect unnamed attribute single-quoted" do
    attributes = {}
    line = '\'quote\''
    expected = {1 => 'quote'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect unnamed attribute single-quoted containing escaped quote" do
    attributes = {}
    line = '\'ba\\\'zaar\''
    expected = {1 => 'ba\'zaar'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect unnamed attribute with dangling delimiter" do
    attributes = {}
    line = 'quote , '
    expected = {1 => 'quote'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect unnamed attributes" do
    attributes = {}
    line = "first, second one, third"
    expected = {1 => 'first', 2 => 'second one', 3 => 'third'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect named attribute" do
    attributes = {}
    line = 'foo=bar'
    expected = {'foo' => 'bar'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect named attribute double-quoted" do
    attributes = {}
    line = 'foo="bar"'
    expected = {'foo' => 'bar'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect named attribute single-quoted" do
    attributes = {}
    line = 'foo=\'bar\''
    expected = {'foo' => 'bar'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect named attributes unquoted" do
    attributes = {}
    line = "first=value, second=two, third=3"
    expected = {'first' => 'value', 'second' => 'two', 'third' => '3'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect named attributes quoted" do
    attributes = {}
    line = "first='value', second=\"value two\", third=three"
    expected = {'first' => 'value', 'second' => 'value two', 'third' => 'three'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect named attributes quoted containing non-semantic spaces" do
    attributes = {}
    line = "     first    =     'value', second     =\"value two\"     , third=       three      "
    expected = {'first' => 'value', 'second' => 'value two', 'third' => 'three'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect mixed named and unnamed attributes" do
    attributes = {}
    line = "first, second=\"value two\", third=three, Sherlock Holmes"
    expected = {1 => 'first', 'second' => 'value two', 'third' => 'three', 4 => 'Sherlock Holmes'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect options attribute" do
    attributes = {}
    line = "quote, options='opt1,opt2 , opt3'"
    expected = {1 => 'quote', 'options' => 'opt1,opt2 , opt3', 'opt1-option' => nil, 'opt2-option' => nil, 'opt3-option' => nil}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect and rekey unnamed attributes" do
    attributes = {}
    line = "first, second one, third, fourth"
    expected = {1 => 'first', 2 => 'second one', 3 => 'third', 4 => 'fourth', 'a' => 'first', 'b' => 'second one', 'c' => 'third'}
    Asciidoctor::AttributeList.new(line).parse_into(attributes, ['a', 'b', 'c'])
    assert_equal expected, attributes
  end

  test "rekey positional attributes" do
    attributes = {1 => 'source', 2 => 'java'}
    expected = {1 => 'source', 2 => 'java', 'style' => 'source', 'language' => 'java'}
    Asciidoctor::AttributeList.rekey(attributes, ['style', 'language', 'linenums'])
    assert_equal expected, attributes
  end

  test "test_parse_author_first" do
    metadata, = parse_header_metadata 'Stuart'
    assert_equal 3, metadata.size
    assert_equal 'Stuart', metadata['author']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'S', metadata['authorinitials']
  end

  test "test_parse_author_first_last" do
    metadata, = parse_header_metadata 'Yukihiro Matsumoto'
    assert_equal 4, metadata.size
    assert_equal 'Yukihiro Matsumoto', metadata['author']
    assert_equal 'Yukihiro', metadata['firstname']
    assert_equal 'Matsumoto', metadata['lastname']
    assert_equal 'YM', metadata['authorinitials']
  end

  test "test_parse_author_first_middle_last" do
    metadata, = parse_header_metadata 'David Heinemeier Hansson'
    assert_equal 5, metadata.size
    assert_equal 'David Heinemeier Hansson', metadata['author']
    assert_equal 'David', metadata['firstname']
    assert_equal 'Heinemeier', metadata['middlename']
    assert_equal 'Hansson', metadata['lastname']
    assert_equal 'DHH', metadata['authorinitials']
  end

  test "test_parse_author_first_middle_last_email" do
    metadata, = parse_header_metadata 'David Heinemeier Hansson <rails@ruby-lang.org>'
    assert_equal 6, metadata.size
    assert_equal 'David Heinemeier Hansson', metadata['author']
    assert_equal 'David', metadata['firstname']
    assert_equal 'Heinemeier', metadata['middlename']
    assert_equal 'Hansson', metadata['lastname']
    assert_equal 'rails@ruby-lang.org', metadata['email']
    assert_equal 'DHH', metadata['authorinitials']
  end

  test "test_parse_author_first_email" do
    metadata, = parse_header_metadata 'Stuart <founder@asciidoc.org>'
    assert_equal 4, metadata.size
    assert_equal 'Stuart', metadata['author']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'founder@asciidoc.org', metadata['email']
    assert_equal 'S', metadata['authorinitials']
  end

  test "test_parse_author_first_last_email" do
    metadata, = parse_header_metadata 'Stuart Rackham <founder@asciidoc.org>'
    assert_equal 5, metadata.size
    assert_equal 'Stuart Rackham', metadata['author']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'Rackham', metadata['lastname']
    assert_equal 'founder@asciidoc.org', metadata['email']
    assert_equal 'SR', metadata['authorinitials']
  end

  test "test_parse_author_with_hyphen" do
    metadata, = parse_header_metadata 'Tim Berners-Lee <founder@www.org>'
    assert_equal 5, metadata.size
    assert_equal 'Tim Berners-Lee', metadata['author']
    assert_equal 'Tim', metadata['firstname']
    assert_equal 'Berners-Lee', metadata['lastname']
    assert_equal 'founder@www.org', metadata['email']
    assert_equal 'TB', metadata['authorinitials']
  end

  test "test_parse_author_with_underscore" do
    metadata, = parse_header_metadata 'Tim_E Fella'
    assert_equal 4, metadata.size
    assert_equal 'Tim E Fella', metadata['author']
    assert_equal 'Tim E', metadata['firstname']
    assert_equal 'Fella', metadata['lastname']
    assert_equal 'TF', metadata['authorinitials']
  end

  test "test_parse_author_condenses_whitespace" do
    metadata, = parse_header_metadata '   Stuart       Rackham     <founder@asciidoc.org>'
    assert_equal 5, metadata.size
    assert_equal 'Stuart Rackham', metadata['author']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'Rackham', metadata['lastname']
    assert_equal 'founder@asciidoc.org', metadata['email']
    assert_equal 'SR', metadata['authorinitials']
  end

  test "test_parse_invalid_author_line_becomes_author" do
    metadata, = parse_header_metadata '   Stuart       Rackham, founder of AsciiDoc   <founder@asciidoc.org>'
    assert_equal 3, metadata.size
    assert_equal 'Stuart Rackham, founder of AsciiDoc <founder@asciidoc.org>', metadata['author']
    assert_equal 'Stuart Rackham, founder of AsciiDoc <founder@asciidoc.org>', metadata['firstname']
    assert_equal 'S', metadata['authorinitials']
  end

  test "test_parse_rev_number_date_remark" do
    metadata, = parse_header_metadata "Ryan Waldron\nv0.0.7, 2013-12-18: The first release you can stand on"
    assert_equal 7, metadata.size
    assert_equal '0.0.7', metadata['revnumber']
    assert_equal '2013-12-18', metadata['revdate']
    assert_equal 'The first release you can stand on', metadata['revremark']
  end

  test "test_parse_rev_date" do
    metadata, = parse_header_metadata "Ryan Waldron\n2013-12-18"
    assert_equal 5, metadata.size
    assert_equal '2013-12-18', metadata['revdate']
  end

  test "test_parse_rev_date_remark" do
    metadata, = parse_header_metadata "Ryan Waldron\n2013-12-18:  The first release you can stand on"
    assert_equal 6, metadata.size
    assert_equal '2013-12-18', metadata['revdate']
    assert_equal 'The first release you can stand on', metadata['revremark']
  end

  test "test_skip_line_comments_before_author" do
    metadata, = parse_header_metadata "// Asciidoctor\n// release artist\nRyan Waldron"
    assert_equal 4, metadata.size
    assert_equal 'Ryan Waldron', metadata['author']
    assert_equal 'Ryan', metadata['firstname']
    assert_equal 'Waldron', metadata['lastname']
    assert_equal 'RW', metadata['authorinitials']
  end

  test "test_skip_block_comment_before_author" do
    metadata, = parse_header_metadata "////\nAsciidoctor\nrelease artist\n////\nRyan Waldron"
    assert_equal 4, metadata.size
    assert_equal 'Ryan Waldron', metadata['author']
    assert_equal 'Ryan', metadata['firstname']
    assert_equal 'Waldron', metadata['lastname']
    assert_equal 'RW', metadata['authorinitials']
  end

  test "test_skip_block_comment_before_rev" do
    metadata, = parse_header_metadata "Ryan Waldron\n////\nAsciidoctor\nrelease info\n////\nv0.0.7, 2013-12-18"
    assert_equal 6, metadata.size
    assert_equal 'Ryan Waldron', metadata['author']
    assert_equal '0.0.7', metadata['revnumber']
    assert_equal '2013-12-18', metadata['revdate']
  end

end
