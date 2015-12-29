# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context "Parser" do

  test "is_section_title?" do
    assert Asciidoctor::Parser.is_section_title?('AsciiDoc Home Page', '==================')
    assert Asciidoctor::Parser.is_section_title?('=== AsciiDoc Home Page')
  end

  test 'sanitize attribute name' do
    assert_equal 'foobar', Asciidoctor::Parser.sanitize_attribute_name("Foo Bar")
    assert_equal 'foo', Asciidoctor::Parser.sanitize_attribute_name("foo")
    assert_equal 'foo3-bar', Asciidoctor::Parser.sanitize_attribute_name("Foo 3^ # - Bar[")
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

  test "collect empty unnamed attribute double-quoted" do
    attributes = {}
    line = '""'
    expected = {1 => ''}
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

  test "collect empty unnamed attribute single-quoted" do
    attributes = {}
    line = '\'\''
    expected = {1 => ''}
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

  test "collect unnamed attribute in second position after empty attribute" do
    attributes = {}
    line = ', John Smith'
    expected = {1 => nil, 2 => 'John Smith'}
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

  test 'collect named attribute with double-quoted empty value' do
    attributes = {}
    line = 'height=100,caption="",link="images/octocat.png"'
    expected = {'height' => '100', 'caption' => '', 'link' => 'images/octocat.png'}
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

  test 'collect named attribute with single-quoted empty value' do
    attributes = {}
    line = "height=100,caption='',link='images/octocat.png'"
    expected = {'height' => '100', 'caption' => '', 'link' => 'images/octocat.png'}
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
    expected = {1 => 'quote', 'options' => 'opt1,opt2 , opt3', 'opt1-option' => '', 'opt2-option' => '', 'opt3-option' => ''}
    Asciidoctor::AttributeList.new(line).parse_into(attributes)
    assert_equal expected, attributes
  end

  test "collect opts attribute as options" do
    attributes = {}
    line = "quote, opts='opt1,opt2 , opt3'"
    expected = {1 => 'quote', 'options' => 'opt1,opt2 , opt3', 'opt1-option' => '', 'opt2-option' => '', 'opt3-option' => ''}
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

  test 'parse style attribute with id and role' do
    attributes = {1 => 'style#id.role'}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_equal 'style', style
    assert_nil original_style
    assert_equal 'style', attributes['style']
    assert_equal 'id', attributes['id']
    assert_equal 'role', attributes['role']
    assert_equal 'style#id.role', attributes[1]
  end

  test 'parse style attribute with style, role, id and option' do
    attributes = {1 => 'style.role#id%fragment'}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_equal 'style', style
    assert_nil original_style
    assert_equal 'style', attributes['style']
    assert_equal 'id', attributes['id']
    assert_equal 'role', attributes['role']
    assert_equal '', attributes['fragment-option']
    assert_equal 'fragment', attributes['options']
    assert_equal 'style.role#id%fragment', attributes[1]
  end

  test 'parse style attribute with style, id and multiple roles' do
    attributes = {1 => 'style#id.role1.role2'}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_equal 'style', style
    assert_nil original_style
    assert_equal 'style', attributes['style']
    assert_equal 'id', attributes['id']
    assert_equal 'role1 role2', attributes['role']
    assert_equal 'style#id.role1.role2', attributes[1]
  end

  test 'parse style attribute with style, multiple roles and id' do
    attributes = {1 => 'style.role1.role2#id'}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_equal 'style', style
    assert_nil original_style
    assert_equal 'style', attributes['style']
    assert_equal 'id', attributes['id']
    assert_equal 'role1 role2', attributes['role']
    assert_equal 'style.role1.role2#id', attributes[1]
  end

  test 'parse style attribute with positional and original style' do
    attributes = {1 => 'new_style', 'style' => 'original_style'}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_equal 'new_style', style
    assert_equal 'original_style', original_style
    assert_equal 'new_style', attributes['style']
    assert_equal 'new_style', attributes[1]
  end

  test 'parse style attribute with id and role only' do
    attributes = {1 => '#id.role'}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_nil style
    assert_nil original_style
    assert_equal 'id', attributes['id']
    assert_equal 'role', attributes['role']
    assert_equal '#id.role', attributes[1]
  end

  test 'parse empty style attribute' do
    attributes = {1 => nil}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_nil style
    assert_nil original_style
    assert_nil attributes['id']
    assert_nil attributes['role']
    assert_nil attributes[1]
  end

  test 'parse style attribute with option should preserve existing options' do
    attributes = {1 => '%header', 'options' => 'footer', 'footer-option' => ''}
    style, original_style = Asciidoctor::Parser.parse_style_attribute(attributes)
    assert_nil style
    assert_nil original_style
    assert_equal 'header,footer', attributes['options']
    assert_equal '', attributes['header-option']
    assert_equal '', attributes['footer-option']
  end

  test "parse author first" do
    metadata, _ = parse_header_metadata 'Stuart'
    assert_equal 5, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'S', metadata['authorinitials']
  end

  test "parse author first last" do
    metadata, _ = parse_header_metadata 'Yukihiro Matsumoto'
    assert_equal 6, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Yukihiro Matsumoto', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Yukihiro', metadata['firstname']
    assert_equal 'Matsumoto', metadata['lastname']
    assert_equal 'YM', metadata['authorinitials']
  end

  test "parse author first middle last" do
    metadata, _ = parse_header_metadata 'David Heinemeier Hansson'
    assert_equal 7, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'David Heinemeier Hansson', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'David', metadata['firstname']
    assert_equal 'Heinemeier', metadata['middlename']
    assert_equal 'Hansson', metadata['lastname']
    assert_equal 'DHH', metadata['authorinitials']
  end

  test "parse author first middle last email" do
    metadata, _ = parse_header_metadata 'David Heinemeier Hansson <rails@ruby-lang.org>'
    assert_equal 8, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'David Heinemeier Hansson', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'David', metadata['firstname']
    assert_equal 'Heinemeier', metadata['middlename']
    assert_equal 'Hansson', metadata['lastname']
    assert_equal 'rails@ruby-lang.org', metadata['email']
    assert_equal 'DHH', metadata['authorinitials']
  end

  test "parse author first email" do
    metadata, _ = parse_header_metadata 'Stuart <founder@asciidoc.org>'
    assert_equal 6, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Stuart', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'founder@asciidoc.org', metadata['email']
    assert_equal 'S', metadata['authorinitials']
  end

  test "parse author first last email" do
    metadata, _ = parse_header_metadata 'Stuart Rackham <founder@asciidoc.org>'
    assert_equal 7, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Stuart Rackham', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'Rackham', metadata['lastname']
    assert_equal 'founder@asciidoc.org', metadata['email']
    assert_equal 'SR', metadata['authorinitials']
  end

  test "parse author with hyphen" do
    metadata, _ = parse_header_metadata 'Tim Berners-Lee <founder@www.org>'
    assert_equal 7, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Tim Berners-Lee', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Tim', metadata['firstname']
    assert_equal 'Berners-Lee', metadata['lastname']
    assert_equal 'founder@www.org', metadata['email']
    assert_equal 'TB', metadata['authorinitials']
  end

  test "parse author with single quote" do
    metadata, _ = parse_header_metadata 'Stephen O\'Grady <founder@redmonk.com>'
    assert_equal 7, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Stephen O\'Grady', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Stephen', metadata['firstname']
    assert_equal 'O\'Grady', metadata['lastname']
    assert_equal 'founder@redmonk.com', metadata['email']
    assert_equal 'SO', metadata['authorinitials']
  end

  test "parse author with dotted initial" do
    metadata, _ = parse_header_metadata 'Heiko W. Rupp <hwr@example.de>'
    assert_equal 8, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Heiko W. Rupp', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Heiko', metadata['firstname']
    assert_equal 'W.', metadata['middlename']
    assert_equal 'Rupp', metadata['lastname']
    assert_equal 'hwr@example.de', metadata['email']
    assert_equal 'HWR', metadata['authorinitials']
  end

  test "parse author with underscore" do
    metadata, _ = parse_header_metadata 'Tim_E Fella'
    assert_equal 6, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Tim E Fella', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Tim E', metadata['firstname']
    assert_equal 'Fella', metadata['lastname']
    assert_equal 'TF', metadata['authorinitials']
  end

  test 'parse author name with letters outside basic latin' do
    metadata, _ = parse_header_metadata 'Stéphane Brontë'
    assert_equal 6, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Stéphane Brontë', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Stéphane', metadata['firstname']
    assert_equal 'Brontë', metadata['lastname']
    assert_equal 'SB', metadata['authorinitials']
  end if ::RUBY_MIN_VERSION_1_9

  test 'parse ideographic author names' do
    metadata, _ = parse_header_metadata '李 四 <si.li@example.com>'
    assert_equal 7, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal '李 四', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal '李', metadata['firstname']
    assert_equal '四', metadata['lastname']
    assert_equal 'si.li@example.com', metadata['email']
    assert_equal '李四', metadata['authorinitials']
  end if ::RUBY_MIN_VERSION_1_9

  test "parse author condenses whitespace" do
    metadata, _ = parse_header_metadata '   Stuart       Rackham     <founder@asciidoc.org>'
    assert_equal 7, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Stuart Rackham', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Stuart', metadata['firstname']
    assert_equal 'Rackham', metadata['lastname']
    assert_equal 'founder@asciidoc.org', metadata['email']
    assert_equal 'SR', metadata['authorinitials']
  end

  test "parse invalid author line becomes author" do
    metadata, _ = parse_header_metadata '   Stuart       Rackham, founder of AsciiDoc   <founder@asciidoc.org>'
    assert_equal 5, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Stuart Rackham, founder of AsciiDoc <founder@asciidoc.org>', metadata['author']
    assert_equal metadata['author'], metadata['authors']
    assert_equal 'Stuart Rackham, founder of AsciiDoc <founder@asciidoc.org>', metadata['firstname']
    assert_equal 'S', metadata['authorinitials']
  end

  test 'parse multiple authors' do
    metadata, _ = parse_header_metadata 'Doc Writer <doc.writer@asciidoc.org>; John Smith <john.smith@asciidoc.org>'
    assert_equal 2, metadata['authorcount']
    assert_equal 'Doc Writer, John Smith', metadata['authors']
    assert_equal 'Doc Writer', metadata['author']
    assert_equal 'Doc Writer', metadata['author_1']
    assert_equal 'John Smith', metadata['author_2']
  end

  test "parse rev number date remark" do
    input = <<-EOS
Ryan Waldron
v0.0.7, 2013-12-18: The first release you can stand on
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 9, metadata.size
    assert_equal '0.0.7', metadata['revnumber']
    assert_equal '2013-12-18', metadata['revdate']
    assert_equal 'The first release you can stand on', metadata['revremark']
  end

  test "parse rev date" do
    input = <<-EOS
Ryan Waldron
2013-12-18
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 7, metadata.size
    assert_equal '2013-12-18', metadata['revdate']
  end

  test 'parse rev number with trailing comma' do
    input = <<-EOS
Stuart Rackham
v8.6.8,
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 7, metadata.size
    assert_equal '8.6.8', metadata['revnumber']
    assert !metadata.has_key?('revdate')
  end

  # Asciidoctor recognizes a standalone revision without a trailing comma
  test 'parse rev number' do
    input = <<-EOS
Stuart Rackham
v8.6.8
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 7, metadata.size
    assert_equal '8.6.8', metadata['revnumber']
    assert !metadata.has_key?('revdate')
  end

  # while compliant w/ AsciiDoc, this is just sloppy parsing
  test "treats arbitrary text on rev line as revdate" do
    input = <<-EOS
Ryan Waldron
foobar
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 7, metadata.size
    assert_equal 'foobar', metadata['revdate']
  end

  test "parse rev date remark" do
    input = <<-EOS
Ryan Waldron
2013-12-18:  The first release you can stand on
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 8, metadata.size
    assert_equal '2013-12-18', metadata['revdate']
    assert_equal 'The first release you can stand on', metadata['revremark']
  end

  test "should not mistake attribute entry as rev remark" do
    input = <<-EOS
Joe Cool
:page-layout: post
    EOS
    metadata, _ = parse_header_metadata input
    refute_equal 'page-layout: post', metadata['revremark']
    assert !metadata.has_key?('revdate')
  end

  test "parse rev remark only" do
    input = <<-EOS
Joe Cool
 :Must start revremark-only line with space
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 'Must start revremark-only line with space', metadata['revremark']
    assert !metadata.has_key?('revdate')
  end

  test "skip line comments before author" do
    input = <<-EOS
// Asciidoctor
// release artist
Ryan Waldron
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 6, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Ryan Waldron', metadata['author']
    assert_equal 'Ryan', metadata['firstname']
    assert_equal 'Waldron', metadata['lastname']
    assert_equal 'RW', metadata['authorinitials']
  end

  test "skip block comment before author" do
    input = <<-EOS
////
Asciidoctor
release artist
////
Ryan Waldron
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 6, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Ryan Waldron', metadata['author']
    assert_equal 'Ryan', metadata['firstname']
    assert_equal 'Waldron', metadata['lastname']
    assert_equal 'RW', metadata['authorinitials']
  end

  test "skip block comment before rev" do
    input = <<-EOS
Ryan Waldron
////
Asciidoctor
release info
////
v0.0.7, 2013-12-18
    EOS
    metadata, _ = parse_header_metadata input
    assert_equal 8, metadata.size
    assert_equal 1, metadata['authorcount']
    assert_equal 'Ryan Waldron', metadata['author']
    assert_equal '0.0.7', metadata['revnumber']
    assert_equal '2013-12-18', metadata['revdate']
  end

  test "attribute entry overrides generated author initials" do
    blankdoc = Asciidoctor::Document.new
    reader = Asciidoctor::Reader.new "Stuart Rackham <founder@asciidoc.org>\n:Author Initials: SJR".lines.entries
    metadata = Asciidoctor::Parser.parse_header_metadata(reader, blankdoc)
    assert_equal 'SR', metadata['authorinitials']
    assert_equal 'SJR', blankdoc.attributes['authorinitials']
  end

  test 'adjust indentation to 0' do
    input = <<-EOS.chomp
    def names

      @name.split ' '

    end
    EOS

    expected = <<-EOS.chomp
def names

  @name.split ' '

end
    EOS

    lines = input.split("\n")
    Asciidoctor::Parser.adjust_indentation! lines
    assert_equal expected, (lines * "\n")
  end

  test 'adjust indentation mixed with tabs and spaces to 0' do
    input = <<-EOS.chomp
    def names

\t  @name.split ' '

    end
    EOS

    expected = <<-EOS.chomp
def names

  @name.split ' '

end
    EOS

    lines = input.split("\n")
    Asciidoctor::Parser.adjust_indentation! lines, 0, 4
    assert_equal expected, (lines * "\n")
  end

  test 'expands tabs to spaces' do
    input = <<-EOS.chomp
Filesystem				Size	Used	Avail	Use%	Mounted on
Filesystem              Size    Used    Avail   Use%    Mounted on
devtmpfs				3.9G	   0	 3.9G	  0%	/dev
/dev/mapper/fedora-root	 48G	 18G	  29G	 39%	/
    EOS

    expected = <<-EOS.chomp
Filesystem              Size    Used    Avail   Use%    Mounted on
Filesystem              Size    Used    Avail   Use%    Mounted on
devtmpfs                3.9G       0     3.9G     0%    /dev
/dev/mapper/fedora-root  48G     18G      29G    39%    /
    EOS

    lines = input.split("\n")
    Asciidoctor::Parser.adjust_indentation! lines, 0, 4
    assert_equal expected, (lines * "\n")
  end

  test 'adjust indentation to non-zero' do
    input = <<-EOS.chomp
    def names

      @name.split ' '

    end
    EOS

    expected = <<-EOS.chomp
  def names

    @name.split ' '

  end
    EOS

    lines = input.split("\n")
    Asciidoctor::Parser.adjust_indentation! lines, 2
    assert_equal expected, (lines * "\n")
  end

  test 'preserve block indent if indent is -1' do
    input = <<-EOS
    def names

      @name.split ' '

    end
    EOS

    expected = input

    lines = input.lines.entries
    Asciidoctor::Parser.adjust_indentation! lines, -1
    assert_equal expected, lines.join
  end

  test 'adjust indentation handles empty lines gracefully' do
    input = []
    expected = input

    lines = input.dup
    Asciidoctor::Parser.adjust_indentation! lines
    assert_equal expected, lines
  end

end
