require 'test_helper'

class ReaderTest < Test::Unit::TestCase
  # setup for test
  def setup
    @src_data = File.readlines(sample_doc_path(:asciidoc_index))
    @reader = Asciidoctor::Reader.new @src_data
  end

  context "has_lines?" do
    test "returns false for empty document" do
      assert ! Asciidoctor::Reader.new.has_lines?
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

  context "Include files" do
    test "block is called to handle an include macro" do
      input = <<-EOS
first line

include::include-file.asciidoc[]

last line
      EOS
      attributes = {}
      reader = Asciidoctor::Reader.new(input.lines.entries, attributes) {|inc|
        ":file: #{inc}\n\nmiddle line".lines.entries
      }
      expected = {'file' => 'include-file.asciidoc'}
      assert_equal expected, attributes
    end
  end

  def test_grab_lines_until
    pending "Not tested yet"
  end

  def test_sanitize_attribute_name
    assert_equal 'foobar', @reader.sanitize_attribute_name("Foo Bar")
    assert_equal 'foo', @reader.sanitize_attribute_name("foo")
    assert_equal 'foo3-bar', @reader.sanitize_attribute_name("Foo 3^ # - Bar[")
  end
end
