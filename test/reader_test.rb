require 'test_helper'

class ReaderTest < Test::Unit::TestCase
  # setup for test
  def setup
    @src_data = File.readlines(sample_doc_path(:asciidoc_index))
    @reader = Asciidoctor::Reader.new @src_data
  end

  context "has_lines?" do
    test "returns false for empty document" do
      assert !Asciidoctor::Reader.new.has_lines?
    end

    test "returns true with lines remaining" do
      assert @reader.has_lines?, "Yo, didn't work"
    end
  end

  context "with source data loaded" do
    test "get_line returns next line" do
      assert_equal @src_data[0], @reader.get_line
    end

    test "get_line consumes the line it returns" do
      reader = Asciidoctor::Reader.new(["foo", "bar"])
      _ = reader.get_line
      second = reader.get_line
      assert_equal "bar", second
    end

    test "peek_line does not consume the line it returns" do
      reader = Asciidoctor::Reader.new(["foo", "bar"])
      _ = reader.peek_line
      second = reader.peek_line
      assert_equal "foo", second
    end

    test "unshift puts line onto Reader instance for the next get_line" do
      reader = Asciidoctor::Reader.new(["foo"])
      reader.unshift("bar")
      assert_equal "bar", reader.get_line
      assert_equal "foo", reader.get_line
    end
  end

  context "Grab lines" do
    test "Grab until end" do
      input = <<-EOS
This is one paragraph.

This is another paragraph.
      EOS

      lines = input.lines.entries
      reader = Asciidoctor::Reader.new(lines)
      result = reader.grab_lines_until
      assert_equal 3, result.size
      assert_equal lines, result
      assert !reader.has_lines?
      assert reader.empty?
    end

    test "Grab until blank line" do
      input = <<-EOS
This is one paragraph.

This is another paragraph.
      EOS

      lines = input.lines.entries
      reader = Asciidoctor::Reader.new(lines)
      result = reader.grab_lines_until :break_on_blank_lines => true
      assert_equal 1, result.size
      assert_equal lines.first, result.first
      assert_equal lines.last, reader.peek_line
    end

    test "Grab until blank line preserving last line" do
      input = <<-EOS
This is one paragraph.

This is another paragraph.
      EOS

      lines = input.lines.entries
      reader = Asciidoctor::Reader.new(lines)
      result = reader.grab_lines_until :break_on_blank_lines => true, :preserve_last_line => true
      assert_equal 1, result.size
      assert_equal lines.first, result.first
      assert_equal "\n", reader.peek_line
    end

    test "Grab until condition" do
      input = <<-EOS
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
      EOS

      lines = input.lines.entries
      reader = Asciidoctor::Reader.new(lines)
      reader.get_line
      result = reader.grab_lines_until {|line| line.chomp == '--' }
      assert_equal 3, result.size
      assert_equal lines[1, 3], result
      assert_equal "\n", reader.peek_line
    end

    test "Grab until condition with last line" do
      input = <<-EOS
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
      EOS

      lines = input.lines.entries
      reader = Asciidoctor::Reader.new(lines)
      reader.get_line
      result = reader.grab_lines_until(:grab_last_line => true) {|line| line.chomp == '--' }
      assert_equal 4, result.size
      assert_equal lines[1, 4], result
      assert_equal "\n", reader.peek_line
    end

    test "Grab until condition with last line and preserving last line" do
      input = <<-EOS
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
      EOS

      lines = input.lines.entries
      reader = Asciidoctor::Reader.new(lines)
      reader.get_line
      result = reader.grab_lines_until(:grab_last_line => true, :preserve_last_line => true) {|line| line.chomp == '--' }
      assert_equal 4, result.size
      assert_equal lines[1, 4], result
      assert_equal "--\n", reader.peek_line
    end
  end

  context 'Include Macro' do
    test 'include macro is disabled by default' do
      input = <<-EOS
include::include-file.asciidoc[]
      EOS
      para = block_from_string input, :attributes => { 'include-depth' => 0 }
      assert_equal 1, para.buffer.size
      assert_equal 'include::include-file.asciidoc[]', para.buffer.join
    end

    test 'include macro is enabled when safe mode is less than SECURE' do
      input = <<-EOS
include::fixtures/include-file.asciidoc[]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      output = doc.render
      assert_match(/included content/, output)
    end

    test "block is called to handle an include macro" do
      input = <<-EOS
first line

include::include-file.asciidoc[]

last line
      EOS
      doc = Asciidoctor::Document.new [], :safe => Asciidoctor::SafeMode::SAFE
      Asciidoctor::Reader.new(input.lines.entries, doc) {|inc|
        ":file: #{inc}\n\nmiddle line".lines.entries
      }
      assert_equal 'include-file.asciidoc', doc.attributes['file']
    end

    test 'escaped include macro is left unprocessed' do
      input = <<-EOS
\\include::include-file.asciidoc[]
      EOS
      para = block_from_string input
      assert_equal 1, para.buffer.size
      assert_equal 'include::include-file.asciidoc[]', para.buffer.join
    end

    test 'include macro not at start of line is ignored' do
      input = <<-EOS
 include::include-file.asciidoc[]
      EOS
      para = block_from_string input
      assert_equal 1, para.buffer.size
      # NOTE the space gets stripped because the line is treated as an inline literal
      assert_equal :literal, para.context
      assert_equal 'include::include-file.asciidoc[]', para.buffer.join
    end

    test 'include macro is disabled when include-depth attribute is 0' do
      input = <<-EOS
include::include-file.asciidoc[]
      EOS
      para = block_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => { 'include-depth' => 0 }
      assert_equal 1, para.buffer.size
      assert_equal 'include::include-file.asciidoc[]', para.buffer.join
    end

    test 'include-depth cannot be set by document' do
      input = <<-EOS
:include-depth: 1

include::include-file.asciidoc[]
      EOS
      para = block_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => { 'include-depth' => 0 }
      assert_equal 1, para.buffer.size
      assert_equal 'include::include-file.asciidoc[]', para.buffer.join
    end
  end

  context 'build secure asset path' do
    test 'allows us to specify a path relative to the current dir' do
      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(["foo"], doc)
      legit_path = Dir.pwd + "/foo"
      assert_equal legit_path, doc.normalize_asset_path(legit_path)
    end

    test "keeps naughty absolute paths from getting outside" do
      naughty_path = "/etc/passwd"
      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(["foo"], doc)
      secure_path = doc.normalize_asset_path(naughty_path)
      assert naughty_path != secure_path
      assert_match(/^#{doc.base_dir}/, secure_path)
    end

    test "keeps naughty relative paths from getting outside" do
      naughty_path = "safe/ok/../../../../../etc/passwd"
      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(["foo"], doc)
      secure_path = doc.normalize_asset_path(naughty_path)
      assert naughty_path != secure_path
      assert_match(/^#{doc.base_dir}/, secure_path)
    end
  end

  # TODO these tests could be expanded
  context 'Conditional blocks' do
    test 'ifdef with defined attribute includes block' do
      input = <<-EOS
:holygrail:

ifdef::holygrail[]
There is a holy grail!
endif::holygrail[]
      EOS
       
      reader = Asciidoctor::Reader.new(input.lines.entries, Asciidoctor::Document.new)
      assert_match(/There is a holy grail!/, reader.lines.join)
    end

    test 'ifndef with undefined attribute includes block' do
      input = <<-EOS
ifndef::holygrail[]
Our quest continues to find the holy grail!
endif::holygrail[]
      EOS

      reader = Asciidoctor::Reader.new(input.lines.entries, Asciidoctor::Document.new)
      assert_match(/Our quest continues to find the holy grail!/, reader.lines.join)
    end
  end

  context 'Text processing' do
    test 'sanitize attribute name' do
      assert_equal 'foobar', @reader.sanitize_attribute_name("Foo Bar")
      assert_equal 'foo', @reader.sanitize_attribute_name("foo")
      assert_equal 'foo3-bar', @reader.sanitize_attribute_name("Foo 3^ # - Bar[")
    end
  end
end
