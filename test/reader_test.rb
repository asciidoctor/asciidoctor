require 'test_helper'

class ReaderTest < Test::Unit::TestCase
  # setup for test
  def setup
    @src_data = File.readlines(sample_doc_path(:asciidoc_index))
    @reader = Asciidoctor::Reader.new @src_data
  end

  context "has_more_lines?" do
    test "returns false for empty document" do
      assert !Asciidoctor::Reader.new.has_more_lines?
    end

    test "returns true with lines remaining" do
      assert @reader.has_more_lines?, "Yo, didn't work"
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
      assert !reader.has_more_lines?
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
    test 'include macro is disabled by default and becomes a link' do
      input = <<-EOS
include::include-file.asciidoc[]
      EOS
      para = block_from_string input, :attributes => { 'include-depth' => 0 }
      assert_equal 1, para.buffer.size
      #assert_equal 'include::include-file.asciidoc[]', para.buffer.join
      assert_equal 'link:include-file.asciidoc[include-file.asciidoc]', para.buffer.join
    end

    test 'include macro is enabled when safe mode is less than SECURE' do
      input = <<-EOS
include::fixtures/include-file.asciidoc[]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      output = doc.render
      assert_match(/included content/, output)
    end

    test 'missing file referenced by include macro does not crash processor' do
      input = <<-EOS
include::fixtures/no-such-file.ad[]
      EOS

      begin
        doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
        assert_equal 0, doc.blocks.size
      rescue
        flunk 'include macro should not raise exception on missing file'
      end
    end

    test 'include macro can retrieve data from uri' do
      input = <<-EOS
....
include::https://raw.github.com/asciidoctor/asciidoctor/master/LICENSE[]
....
      EOS

      output = render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
      assert_match(/MIT/, output)
    end

    test 'inaccessible uri referenced by include macro does not crash processor' do
      input = <<-EOS
....
include::http://localhost:0[]
....
      EOS

      begin
        output = render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
        assert_css 'pre', output, 1
        assert_css 'pre *', output, 0
      rescue
        flunk 'include macro should not raise exception on inaccessible uri'
      end
    end

    test 'include macro supports line selection' do
      input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1;3..4;6..-1]
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :header_footer => false, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_match(/first line/, output)
      assert_no_match(/second line/, output)
      assert_match(/third line/, output)
      assert_match(/fourth line/, output)
      assert_no_match(/fifth line/, output)
      assert_match(/sixth line/, output)
      assert_match(/seventh line/, output)
      assert_match(/eighth line/, output)
      assert_match(/last line of included content/, output)
    end

    test 'include macro supports line selection using quoted attribute value' do
      input = <<-EOS
include::fixtures/include-file.asciidoc[lines="1, 3..4 , 6 .. -1"]
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :header_footer => false, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_match(/first line/, output)
      assert_no_match(/second line/, output)
      assert_match(/third line/, output)
      assert_match(/fourth line/, output)
      assert_no_match(/fifth line/, output)
      assert_match(/sixth line/, output)
      assert_match(/seventh line/, output)
      assert_match(/eighth line/, output)
      assert_match(/last line of included content/, output)
    end

    test 'include macro supports tagged selection' do
      input = <<-EOS
include::fixtures/include-file.asciidoc[tags=snippetA;snippetB]
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :header_footer => false, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_match(/snippetA content/, output)
      assert_match(/snippetB content/, output)
      assert_no_match(/non-tagged content/, output)
      assert_no_match(/included content/, output)
    end

    test 'lines attribute takes precedence over tags attribute in include macro' do
      input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1, tags=snippetA;snippetB]
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :header_footer => false, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_match(/first line of included content/, output)
      assert_no_match(/snippetA content/, output)
      assert_no_match(/snippetB content/, output)
    end

    test 'indent of included file can be reset to size of indent attribute' do
      input = <<-EOS
[source, xml]
----
include::fixtures/basic-docinfo.xml[lines=2..3, indent=0]
----
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :header_footer => false, :attributes => {'docdir' => File.dirname(__FILE__)}
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal "<year>2013</year>\n<holder>Acme, Inc.</holder>", result
    end

    test "block is called to handle an include macro" do
      input = <<-EOS
first line

include::include-file.asciidoc[]

last line
      EOS
      document = Asciidoctor::Document.new [], :safe => Asciidoctor::SafeMode::SAFE
      reader = Asciidoctor::Reader.new(input.lines.entries, document, true) {|inc, doc|
        ":includefile: #{inc}\n\nmiddle line".lines.entries
      }
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_match(/^:includefile: include-file.asciidoc$/, lines.join)
    end

    test 'attributes are substituted in target of include macro' do
      input = <<-EOS
:fixturesdir: fixtures
:ext: asciidoc

include::{fixturesdir}/include-file.{ext}[]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      output = doc.render
      assert_match(/included content/, output)
    end

    test 'line is dropped if target of include macro resolves to empty' do
      input = <<-EOS
include::{foodir}/include-file.asciidoc[]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert output.strip.empty?
    end

    test 'line is dropped but not following line if target of include macro resolves to empty' do
      input = <<-EOS
include::{foodir}/include-file.asciidoc[]
yo
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//p', output, 1
      assert_xpath '//p[text()="yo"]', output, 1
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
      Asciidoctor::Reader.new([], doc, true)
      legit_path = Dir.pwd + "/foo"
      assert_equal legit_path, doc.normalize_asset_path(legit_path)
    end

    test "keeps naughty absolute paths from getting outside" do
      naughty_path = "#{disk_root}etc/passwd"
      doc = Asciidoctor::Document.new
      Asciidoctor::Reader.new([], doc, true)
      secure_path = doc.normalize_asset_path(naughty_path)
      assert naughty_path != secure_path
      assert_match(/^#{doc.base_dir}/, secure_path)
    end

    test "keeps naughty relative paths from getting outside" do
      naughty_path = "safe/ok/../../../../../etc/passwd"
      doc = Asciidoctor::Document.new
      Asciidoctor::Reader.new([], doc, true)
      secure_path = doc.normalize_asset_path(naughty_path)
      assert naughty_path != secure_path
      assert_match(/^#{doc.base_dir}/, secure_path)
    end
  end

  context 'Conditional Inclusions' do
    test 'preprocess_next_line returns true if cursor advanced' do
      input = <<-EOS
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      assert reader.preprocess_next_line == true
    end

    test 'preprocess_next_line returns false if cursor not advanced' do
      input = <<-EOS
content
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      assert reader.preprocess_next_line == false
    end

    test 'preprocess_next_line returns nil if cursor advanced past end of source' do
      input = <<-EOS
ifdef::foobar[]
swallowed content
endif::foobar[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      assert reader.preprocess_next_line.nil?
    end

    test 'ifdef with defined attribute includes block' do
      input = <<-EOS
ifdef::holygrail[]
There is a holy grail!
endif::holygrail[]
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'holygrail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'There is a holy grail!', lines.join.strip
    end

    test 'ifdef with defined attribute includes text in brackets' do
      input = <<-EOS
On our quest we go...
ifdef::holygrail[There is a holy grail!]
There was much rejoicing.
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'holygrail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "On our quest we go...\nThere is a holy grail!\nThere was much rejoicing.", lines.join.strip
    end

    test 'ifndef with defined attribute does not include text in brackets' do
      input = <<-EOS
On our quest we go...
ifndef::hardships[There is a holy grail!]
There was no rejoicing.
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'hardships' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "On our quest we go...\nThere was no rejoicing.", lines.join.strip
    end

    test 'include with non-matching nested exclude' do
      input = <<-EOS
ifdef::grail[]
holy
ifdef::swallow[]
swallow
endif::swallow[]
grail
endif::grail[]
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'grail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "holy\ngrail", lines.join.strip
    end

    test 'nested excludes with same condition' do
      input = <<-EOS
ifndef::grail[]
ifndef::grail[]
not here
endif::grail[]
endif::grail[]
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'grail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal '', lines.join.strip
    end

    test 'include with nested exclude of inverted condition' do
      input = <<-EOS
ifdef::grail[]
holy
ifndef::grail[]
not here
endif::grail[]
grail
endif::grail[]
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'grail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "holy\ngrail", lines.join.strip
    end

    test 'exclude with matching nested exclude' do
      input = <<-EOS
poof
ifdef::swallow[]
no
ifdef::swallow[]
swallow
endif::swallow[]
here
endif::swallow[]
gone
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'grail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "poof\ngone", lines.join.strip
    end

    test 'exclude with nested include using shorthand end' do
      input = <<-EOS
poof
ifndef::grail[]
no grail
ifndef::swallow[]
or swallow
endif::[]
in here
endif::[]
gone
      EOS
       
      doc = Asciidoctor::Document.new [], :attributes => {'grail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "poof\ngone", lines.join.strip
    end

    test 'ifdef with one alternative attribute set includes content' do
      input = <<-EOS
ifdef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'swallow' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Our quest is complete!', lines.join.strip
    end

    test 'ifdef with no alternative attributes set does not include content' do
      input = <<-EOS
ifdef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal '', lines.join.strip
    end

    test 'ifdef with all required attributes set includes content' do
      input = <<-EOS
ifdef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'holygrail' => '', 'swallow' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Our quest is complete!', lines.join.strip
    end

    test 'ifdef with missing required attributes does not include content' do
      input = <<-EOS
ifdef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'holygrail' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal '', lines.join.strip
    end

    test 'ifndef with undefined attribute includes block' do
      input = <<-EOS
ifndef::holygrail[]
Our quest continues to find the holy grail!
endif::holygrail[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Our quest continues to find the holy grail!', lines.join.strip
    end

    test 'ifndef with one alternative attribute set includes content' do
      input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'swallow' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Our quest is complete!', lines.join.strip
    end

    test 'ifndef with no alternative attributes set includes content' do
      input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Our quest is complete!', lines.join.strip
    end

    test 'ifndef with any required attributes set does not include content' do
      input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'swallow' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal '', lines.join.strip
    end

    test 'ifndef with no required attributes set includes content' do
      input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Our quest is complete!', lines.join.strip
    end

    test 'escaped ifdef is unescaped and ignored' do
      input = <<-EOS
\\ifdef::holygrail[]
content
\\endif::holygrail[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "ifdef::holygrail[]\ncontent\nendif::holygrail[]", lines.join.strip
    end

    test 'ifeval comparing double-quoted attribute to matching string is included' do
      input = <<-EOS
ifeval::["{gem}" == "asciidoctor"]
Asciidoctor it is!
endif::[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'gem' => 'asciidoctor'}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Asciidoctor it is!', lines.join.strip
    end

    test 'ifeval comparing single-quoted attribute to matching string is included' do
      input = <<-EOS
ifeval::['{gem}' == 'asciidoctor']
Asciidoctor it is!
endif::[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'gem' => 'asciidoctor'}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Asciidoctor it is!', lines.join.strip
    end

    test 'ifeval comparing quoted attribute to non-matching string is ignored' do
      input = <<-EOS
ifeval::['{gem}' == 'asciidoctor']
Asciidoctor it is!
endif::[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'gem' => 'tilt'}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal '', lines.join.strip
    end

    test 'ifeval comparing attribute to lower version number is included' do
      input = <<-EOS
ifeval::['{asciidoctor-version}' >= '0.1.0']
That version will do!
endif::[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'That version will do!', lines.join.strip
    end

    test 'ifeval comparing attribute to self is included' do
      input = <<-EOS
ifeval::['{asciidoctor-version}' == '{asciidoctor-version}']
Of course it's the same!
endif::[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'Of course it\'s the same!', lines.join.strip
    end

    test 'ifeval arguments can be mirrored' do
      input = <<-EOS
ifeval::["0.1.0" <= "{asciidoctor-version}"]
That version will do!
endif::[]
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'That version will do!', lines.join.strip
    end

    test 'ifeval matching numeric comparison is included' do
      input = <<-EOS
ifeval::[{rings} == 1]
One ring to rule them all!
endif::[]
      EOS

      doc = Asciidoctor::Document.new [], :attributes => {'rings' => 1}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal 'One ring to rule them all!', lines.join.strip
    end

    test 'ifdef with no target is ignored' do
      input = <<-EOS
ifdef::[]
content
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      lines = []
      while reader.has_more_lines?
        lines << reader.get_line
      end
      assert_equal "ifdef::[]\ncontent", lines.join.strip
    end
  end

  context 'Text processing' do
    test 'should clean CRLF from end of lines' do
      input = <<-EOS
source\r
with\r
CRLF\r
endlines\r
      EOS

      reader = Asciidoctor::Reader.new(input.lines.entries, Asciidoctor::Document.new, true)
      reader.lines.each do |line|
        assert !line.end_with?("\r\n")
      end
    end

    test 'sanitize attribute name' do
      assert_equal 'foobar', @reader.sanitize_attribute_name("Foo Bar")
      assert_equal 'foo', @reader.sanitize_attribute_name("foo")
      assert_equal 'foo3-bar', @reader.sanitize_attribute_name("Foo 3^ # - Bar[")
    end

    test 'should not skip front matter by default' do
      input = <<-EOS
---
layout: post
title: Document Title
author: username
tags: [ first, second ]
---
= Document Title
Author Name

preamble
      EOS

      doc = Asciidoctor::Document.new
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      assert_equal '---', reader.peek_line.rstrip
    end

    test 'should skip front matter if specified by skip-front-matter attribute' do
      front_matter = %(layout: post
title: Document Title
author: username
tags: [ first, second ])
      input = <<-EOS
---
#{front_matter}
---
= Document Title
Author Name

preamble
      EOS

      doc = Asciidoctor::Document.new nil, :attributes => {'skip-front-matter' => ''}
      reader = Asciidoctor::Reader.new(input.lines.entries, doc, true)
      assert_equal '= Document Title', reader.peek_line.rstrip
      assert_equal front_matter, doc.attributes['front-matter']
    end
  end
end
