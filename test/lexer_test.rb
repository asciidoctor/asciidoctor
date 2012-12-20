require 'test_helper'

context "Lexer" do

  test "test_is_section_heading" do
    assert Asciidoctor::Lexer.is_section_heading?("AsciiDoc Home Page", "==================")
    assert Asciidoctor::Lexer.is_section_heading?("=== AsciiDoc Home Page")
  end

  test "test_collect_unnamed_attributes" do
    attributes = {}
    line = "first, second one, third"
    Asciidoctor::Lexer.collect_attributes(line, attributes)
    assert_equal 3, attributes.length
    assert_equal 'first', attributes[0]
    assert_equal 'second one', attributes[1]
    assert_equal 'third', attributes[2]
  end

  test "test_collect_named_attributes" do
    attributes = {}
    line = "first='value', second=\"value two\", third=three"
    Asciidoctor::Lexer.collect_attributes(line, attributes)
    assert_equal 3, attributes.length
    assert_equal 'value', attributes['first']
    assert_equal 'value two', attributes['second']
    assert_equal 'three', attributes['third']
  end

  test "test_collect_mixed_named_and_unnamed_attributes" do
    attributes = {}
    line = "first, second=\"value two\", third=three"
    Asciidoctor::Lexer.collect_attributes(line, attributes)
    assert_equal 3, attributes.length
    assert_equal 'first', attributes[0]
    assert_equal 'value two', attributes['second']
    assert_equal 'three', attributes['third']
  end

  test "test_collect_and_rekey_unnamed_attributes" do
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

  test "test_rekey_positional_attributes" do
    attributes = {0 => 'source', 1 => 'java'}
    Asciidoctor::Lexer.rekey_positional_attributes(attributes, ['style', 'language', 'linenums'])
    assert_equal 4, attributes.length
    assert_equal 'source', attributes[0]
    assert_equal 'java', attributes[1]
    assert_equal 'source', attributes['style']
    assert_equal 'java', attributes['language']
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
