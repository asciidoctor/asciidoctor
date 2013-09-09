require 'test_helper'

class ReaderTest < Test::Unit::TestCase
  DIRNAME = File.expand_path(File.dirname(__FILE__))

  SAMPLE_DATA = <<-EOS.each_line.to_a
first line
second line
third line
  EOS

  context 'Reader' do
    context 'Prepare lines' do
      test 'should prepare lines from Array data' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'should prepare lines from String data' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA, reader.lines
      end
    end

    context 'With empty data' do
      test 'has_more_lines? should return false with empty data' do
        assert !Asciidoctor::Reader.new.has_more_lines?
      end

      test 'empty? should return true with empty data' do
        assert Asciidoctor::Reader.new.empty?
        assert Asciidoctor::Reader.new.eof?
      end

      test 'next_line_empty? should return true with empty data' do
        assert Asciidoctor::Reader.new.next_line_empty?
      end

      test 'peek_line should return nil with empty data' do
        assert_nil Asciidoctor::Reader.new.peek_line
      end

      test 'peek_lines should return empty Array with empty data' do
        assert_equal [], Asciidoctor::Reader.new.peek_lines
      end

      test 'read_line should return nil with empty data' do
        assert_nil Asciidoctor::Reader.new.read_line
        #assert_nil Asciidoctor::Reader.new.get_line
      end

      test 'read_lines should return empty Array with empty data' do
        assert_equal [], Asciidoctor::Reader.new.read_lines
        #assert_equal [], Asciidoctor::Reader.new.get_lines
      end
    end

    context 'With data' do
      test 'has_more_lines? should return true if there are lines remaining' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert reader.has_more_lines?
      end

      test 'empty? should return false if there are lines remaining' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert !reader.empty?
        assert !reader.eof?
      end

      test 'next_line_empty? should return false if next line is not blank' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert !reader.next_line_empty?
      end

      test 'next_line_empty? should return true if next line is blank' do
        reader = Asciidoctor::Reader.new ["\n", "second line\n"]
        assert reader.next_line_empty?
      end

      test 'peek_line should return next line if there are lines remaining' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA.first, reader.peek_line
      end

      test 'peek_line should not consume line or increment line number' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA.first, reader.peek_line
        assert_equal SAMPLE_DATA.first, reader.peek_line
        assert_equal 1, reader.lineno
      end

      test 'peek_line should return next lines if there are lines remaining' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA[0..1], reader.peek_lines(2)
      end

      test 'peek_lines should not consume lines or increment line number' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA[0..1], reader.peek_lines(2)
        assert_equal SAMPLE_DATA[0..1], reader.peek_lines(2)
        assert_equal 1, reader.lineno
      end

      test 'peek_lines should not invert order of lines' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA, reader.lines
        reader.peek_lines 3
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'read_line should return next line if there are lines remaining' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA.first, reader.read_line
      end

      test 'read_line should consume next line and increment line number' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA[0], reader.read_line
        assert_equal SAMPLE_DATA[1], reader.read_line
        assert_equal 3, reader.lineno
      end

      test 'advance should consume next line and return a Boolean indicating if a line was consumed' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert reader.advance
        assert reader.advance
        assert reader.advance
        assert !reader.advance
      end

      test 'read_lines should return all lines' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA, reader.read_lines
      end

      test 'read should return all lines joined as String' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA.join, reader.read
      end

      test 'has_more_lines? should return false after read_lines is invoked' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.read_lines
        assert !reader.has_more_lines?
      end

      test 'unshift puts line onto Reader as next line to read' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.unshift "line zero\n"
        assert_equal "line zero\n", reader.peek_line
        assert_equal "line zero\n", reader.read_line
        assert_equal 1, reader.lineno
      end

      test 'terminate should consume all lines and update line number' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.terminate
        assert reader.eof?
        assert_equal 4, reader.lineno
      end

      test 'skip_blank_lines should skip blank lines' do
        reader = Asciidoctor::Reader.new ["", "\n"].concat(SAMPLE_DATA)
        reader.skip_blank_lines
        assert_equal SAMPLE_DATA.first, reader.peek_line
      end

      test 'lines should return remaining lines' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.read_line
        assert_equal SAMPLE_DATA[1..-1], reader.lines
      end

      test 'source_lines should return copy of original data Array' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.read_lines
        assert_equal SAMPLE_DATA, reader.source_lines 
      end

      test 'source should return original data Array joined as String' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.read_lines
        assert_equal SAMPLE_DATA.join, reader.source
      end

    end

    context 'Line context' do
      test 'to_s should return file name and line number of current line' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, 'sample.ad'
        reader.read_line
        assert_equal 'sample.ad: line 2', reader.to_s
      end

      test 'line_info should return file name and line number of current line' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, 'sample.ad'
        reader.read_line
        assert_equal 'sample.ad: line 2', reader.line_info
        assert_equal 'sample.ad: line 2', reader.next_line_info
      end

      test 'prev_line_info should return file name and line number of previous line read' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, 'sample.ad'
        reader.read_line
        assert_equal 'sample.ad: line 1', reader.prev_line_info
      end
    end

    context 'Read lines until' do
      test 'Read lines until until end' do
        lines = <<-EOS.each_line.to_a
This is one paragraph.

This is another paragraph.
        EOS

        reader = Asciidoctor::Reader.new lines
        result = reader.read_lines_until
        assert_equal 3, result.size
        assert_equal lines, result
        assert !reader.has_more_lines?
        assert reader.eof?
      end

      test 'Read lines until until blank line' do
        lines = <<-EOS.each_line.to_a
This is one paragraph.

This is another paragraph.
        EOS

        reader = Asciidoctor::Reader.new lines
        result = reader.read_lines_until :break_on_blank_lines => true
        assert_equal 1, result.size
        assert_equal lines.first.chomp, result.first
        assert_equal lines.last, reader.peek_line
      end

      test 'Read lines until until blank line preserving last line' do
        lines = <<-EOS.each_line.to_a
This is one paragraph.

This is another paragraph.
        EOS

        reader = Asciidoctor::Reader.new lines
        result = reader.read_lines_until :break_on_blank_lines => true, :preserve_last_line => true
        assert_equal 1, result.size
        assert_equal lines.first.chomp, result.first
        assert reader.next_line_empty?
      end

      test 'Read lines until until condition is true' do
        lines = <<-EOS.each_line.to_a
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
        EOS

        reader = Asciidoctor::Reader.new lines
        reader.read_line
        result = reader.read_lines_until {|line| line.chomp == '--' }
        assert_equal 3, result.size
        assert_equal lines[1, 3], result
        assert reader.next_line_empty?
      end

      test 'Read lines until until condition is true, taking last line' do
        lines = <<-EOS.each_line.to_a
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
        EOS

        reader = Asciidoctor::Reader.new lines
        reader.read_line
        result = reader.read_lines_until(:read_last_line => true) {|line| line.chomp == '--' }
        assert_equal 4, result.size
        assert_equal lines[1, 4], result
        assert reader.next_line_empty?
      end

      test 'Read lines until until condition is true, taking and preserving last line' do
        lines = <<-EOS.each_line.to_a
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
        EOS

        reader = Asciidoctor::Reader.new lines
        reader.read_line
        result = reader.read_lines_until(:read_last_line => true, :preserve_last_line => true) {|line| line.chomp == '--' }
        assert_equal 4, result.size
        assert_equal lines[1, 4], result
        assert_equal "--\n", reader.peek_line
      end
    end
  end

  context 'PreprocessorReader' do
    context 'Type hierarchy' do
      test 'PreprocessorReader should extend from Reader' do
        doc = Asciidoctor::Document.new
        reader = Asciidoctor::PreprocessorReader.new doc
        assert reader.is_a?(Asciidoctor::Reader)
      end

      test 'PreprocessorReader should invoke or emulate Reader initializer' do
        doc = Asciidoctor::Document.new
        reader = Asciidoctor::PreprocessorReader.new doc, SAMPLE_DATA
        assert_equal SAMPLE_DATA, reader.lines
        assert_equal 1, reader.lineno
      end
    end

    context 'Prepare lines' do
      test 'should prepare and normalize lines from Array data' do
        doc = Asciidoctor::Document.new
        data = SAMPLE_DATA.map {|line| line.chomp}
        data.unshift ''
        data.push ''
        reader = Asciidoctor::PreprocessorReader.new doc, data
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'should prepare and normalize lines from String data' do
        doc = Asciidoctor::Document.new
        data = SAMPLE_DATA.map {|line| line.chomp}
        data.unshift ' '
        data.push ' '
        data_as_string = data * "\n"
        reader = Asciidoctor::PreprocessorReader.new doc, data_as_string
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'should clean CRLF from end of lines' do
        input = <<-EOS
source\r
with\r
CRLF\r
endlines\r
      EOS

        doc = Asciidoctor::Document.new
        [input, input.lines, input.split("\n"), input.split("\n").join].each do |lines|
          reader = Asciidoctor::PreprocessorReader.new doc, lines
          reader.lines.each do |line|
            assert !line.end_with?("\r"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
            assert !line.end_with?("\r\n"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
            assert line.end_with?("\n"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
          end
        end
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
        reader = Asciidoctor::PreprocessorReader.new doc, input
        assert_equal '---', reader.peek_line.chomp
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

        doc = Asciidoctor::Document.new [], :attributes => {'skip-front-matter' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        assert_equal '= Document Title', reader.peek_line.chomp
        assert_equal front_matter, doc.attributes['front-matter']
      end
    end

    context 'Include Macro' do
      test 'include macro is disabled by default and becomes a link' do
        input = <<-EOS
include::include-file.asciidoc[]
        EOS
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        assert_equal 'link:include-file.asciidoc[]', reader.read_line.chomp
      end
  
      test 'include macro is enabled when safe mode is less than SECURE' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[]
        EOS
  
        doc = document_from_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        output = doc.render
        assert_match(/included content/, output)
      end

      test 'include macro should resolve file relative to current include' do
        input = <<-EOS
include::fixtures/parent-include.adoc[]
        EOS

        pseudo_docfile = File.join DIRNAME, 'include-master.adoc'
        fixtures_dir = File.join DIRNAME, 'fixtures'
        parent_include_docfile = File.join fixtures_dir, 'parent-include.adoc'
        child_include_docfile = File.join fixtures_dir, 'child-include.adoc'
        grandchild_include_docfile = File.join fixtures_dir, 'grandchild-include.adoc'

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input, pseudo_docfile

        assert_equal pseudo_docfile, reader.file
        assert_equal DIRNAME, reader.dir
        assert_equal 'include-master.adoc', reader.path

        assert_equal "first line of parent\n", reader.read_line

        assert_equal 'fixtures/parent-include.adoc: line 1', reader.prev_line_info
        assert_equal parent_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/parent-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal "first line of child\n", reader.read_line

        assert_equal 'fixtures/child-include.adoc: line 1', reader.prev_line_info
        assert_equal child_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/child-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal "first line of grandchild\n", reader.read_line

        assert_equal 'fixtures/grandchild-include.adoc: line 1', reader.prev_line_info
        assert_equal grandchild_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/grandchild-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal "last line of grandchild\n", reader.read_line

        reader.skip_blank_lines

        assert_equal "last line of child\n", reader.read_line

        reader.skip_blank_lines

        assert_equal "last line of parent\n", reader.read_line

        assert_equal 'fixtures/parent-include.adoc: line 5', reader.prev_line_info
        assert_equal parent_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/parent-include.adoc', reader.path
      end
  
      test 'missing file referenced by include macro does not crash processor' do
        input = <<-EOS
include::fixtures/no-such-file.ad[]
        EOS
  
        begin
          doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
          assert_equal 0, doc.blocks.size
        rescue
          flunk 'include macro should not raise exception on missing file'
        end
      end
  
      test 'include macro can retrieve data from uri' do
        input = <<-EOS
....
include::http://asciidoctor.org/humans.txt[]
....
        EOS
  
        output = render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
        assert_match(/Asciidoctor/, output)
      end
  
      test 'inaccessible uri referenced by include macro does not crash processor' do
        input = <<-EOS
....
include::http://127.0.0.1:0[]
....
        EOS
  
        begin
          output = render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
          assert_css 'pre:empty', output, 1
        rescue
          flunk 'include macro should not raise exception on inaccessible uri'
        end
      end
  
      test 'include macro supports line selection' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1;3..4;6..-1]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
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
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
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
include::fixtures/include-file.asciidoc[tag=snippetA]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        assert_match(/snippetA content/, output)
        assert_no_match(/snippetB content/, output)
        assert_no_match(/non-tagged content/, output)
        assert_no_match(/included content/, output)
      end
  
      test 'include macro supports multiple tagged selection' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[tags=snippetA;snippetB]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        assert_match(/snippetA content/, output)
        assert_match(/snippetB content/, output)
        assert_no_match(/non-tagged content/, output)
        assert_no_match(/included content/, output)
      end
  
      test 'lines attribute takes precedence over tags attribute in include macro' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1, tags=snippetA;snippetB]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
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
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        result = xmlnodes_at_xpath('//pre', output, 1).text
        assert_equal "<year>2013</year>\n<holder>Acme, Inc.</holder>", result
      end
  
      test 'include processor is called to process include directive' do
        input = <<-EOS
first line

include::include-file.asciidoc[]

last line
        EOS

        include_processor = Class.new {
          def initialize document
          end

          def handles? target
            true
          end

          def process reader, target, attributes
            content = ["include target:: #{target}\n", "\n", "middle line\n"]
            reader.push_include content, target, target, 1, attributes
          end
        }

        # Safe Mode is not required
        document = empty_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new document, input
        reader.instance_variable_set '@include_processors', [include_processor.new(document)]
        lines = []
        lines << reader.read_line
        lines << reader.read_line
        lines << reader.read_line
        assert_equal "include target:: include-file.asciidoc\n", lines.last
        assert_equal 'include-file.asciidoc: line 2', reader.line_info
        while reader.has_more_lines?
          lines << reader.read_line
        end
        source = lines.join
        assert_match(/^include target:: include-file.asciidoc$/, source)
        assert_match(/^middle line$/, source)
      end

      test 'should fall back to built-in include macro behavior when not handled by include processor' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[]
        EOS
  
        include_processor = Class.new {
          def initialize document
          end
  
          def handles? target
            false
          end
  
          def process reader, target, attributes
            raise 'TestIncludeHandler should not have been invoked'
          end
        }
  
        document = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new document, input
        reader.instance_variable_set '@include_processors', [include_processor.new(document)]
        lines = reader.read_lines
        source = lines.join
        assert_match(/included content/, source)
      end
  
      test 'attributes are substituted in target of include macro' do
        input = <<-EOS
:fixturesdir: fixtures
:ext: asciidoc

include::{fixturesdir}/include-file.{ext}[]
        EOS
  
        doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
        output = doc.render
        assert_match(/included content/, output)
      end
  
      test 'line is skipped by default if target of include macro resolves to empty' do
        input = <<-EOS
include::{foodir}/include-file.asciidoc[]
        EOS
  
        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input
        assert_equal "include::{foodir}/include-file.asciidoc[]\n", reader.read_line
      end

      test 'line is dropped if target of include macro resolves to empty and attribute-missing attribute is not skip' do
        input = <<-EOS
include::{foodir}/include-file.asciidoc[]
        EOS
  
        doc = empty_safe_document :base_dir => DIRNAME, :attributes => {'attribute-missing' => 'drop'}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        assert_nil reader.read_line
      end
  
      test 'line following dropped include is not dropped' do
        input = <<-EOS
include::{foodir}/include-file.asciidoc[]
yo
        EOS
  
        doc = empty_safe_document :base_dir => DIRNAME, :attributes => {'attribute-missing' => 'drop'}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        assert_equal "yo\n", reader.read_line
      end
  
      test 'escaped include macro is left unprocessed' do
        input = <<-EOS
\\include::fixtures/include-file.asciidoc[]
\\escape preserved here
        EOS
        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input
        # we should be able to peek it multiple times and still have the backslash preserved
        # this is the test for @unescape_next_line
        assert_equal 'include::fixtures/include-file.asciidoc[]', reader.peek_line.chomp
        assert_equal 'include::fixtures/include-file.asciidoc[]', reader.peek_line.chomp
        assert_equal 'include::fixtures/include-file.asciidoc[]', reader.read_line.chomp
        assert_equal '\\escape preserved here', reader.read_line.chomp
      end
  
      test 'include macro not at start of line is ignored' do
        input = <<-EOS
 include::include-file.asciidoc[]
        EOS
        para = block_from_string input
        assert_equal 1, para.lines.size
        # NOTE the space gets stripped because the line is treated as an inline literal
        assert_equal :literal, para.context
        assert_equal 'include::include-file.asciidoc[]', para.source
      end
  
      test 'include macro is disabled when max-include-depth attribute is 0' do
        input = <<-EOS
include::include-file.asciidoc[]
        EOS
        para = block_from_string input, :safe => :safe, :attributes => { 'max-include-depth' => 0 }
        assert_equal 1, para.lines.size
        assert_equal 'include::include-file.asciidoc[]', para.source
      end
  
      test 'max-include-depth cannot be set by document' do
        input = <<-EOS
:max-include-depth: 1
 
include::include-file.asciidoc[]
        EOS
        para = block_from_string input, :safe => :safe, :attributes => { 'max-include-depth' => 0 }
        assert_equal 1, para.lines.size
        assert_equal 'include::include-file.asciidoc[]', para.source
      end

      test 'include macro should be disabled if max include depth has been exceeded' do
        input = <<-EOS
include::fixtures/parent-include.adoc[depth=1]
        EOS

        pseudo_docfile = File.join DIRNAME, 'include-master.adoc'

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input, Asciidoctor::Reader::Cursor.new(pseudo_docfile)

        lines = reader.readlines
        assert lines.include?("include::child-include.adoc[]\n")
      end

      test 'include macro should be disabled if max include depth set in nested context has been exceeded' do
        input = <<-EOS
include::fixtures/parent-include-restricted.adoc[depth=3]
        EOS

        pseudo_docfile = File.join DIRNAME, 'include-master.adoc'

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input, Asciidoctor::Reader::Cursor.new(pseudo_docfile)

        lines = reader.readlines
        assert lines.include?("first line of child\n")
        assert lines.include?("include::grandchild-include.adoc[]\n")
      end

      test 'read_lines_until should not process lines if process option is false' do
        lines = <<-EOS.each_line.to_a
////
include::fixtures/no-such-file.asciidoc[]
////
        EOS

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, lines
        reader.read_line
        result = reader.read_lines_until(:terminator => '////', :skip_processing => true)
        assert_equal lines[1..1], result
      end

      test 'skip_comment_lines should not process lines read' do
        lines = <<-EOS.each_line.to_a
////
include::fixtures/no-such-file.asciidoc[]
////
        EOS

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, lines
        result = reader.skip_comment_lines
        assert_equal lines, result
      end
    end

    context 'Conditional Inclusions' do
      #test 'process_line returns next line of content' do
      test 'process_line returns nil if cursor advanced' do
        input = <<-EOS
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS
  
        reader = Asciidoctor::PreprocessorReader.new empty_document, input
        #assert_equal "Asciidoctor!\n", reader.process_line(reader.lines.first)
        assert_nil reader.process_line(reader.lines.first)
      end

      test 'peek_line advances cursor to next conditional line of content' do
        input = <<-EOS
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS
  
        reader = Asciidoctor::PreprocessorReader.new empty_document, input
        assert_equal 1, reader.lineno
        assert_equal "Asciidoctor!\n", reader.peek_line
        assert_equal 2, reader.lineno
      end
  
      test 'process_line returns line if cursor not advanced' do
        input = <<-EOS
content
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS
  
        reader = Asciidoctor::PreprocessorReader.new empty_document, input
        assert_not_nil reader.process_line(reader.lines.first)
      end

      test 'peek_line does not advance cursor when on a regular content line' do
        input = <<-EOS
content
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS
  
        reader = Asciidoctor::PreprocessorReader.new empty_document, input
        assert_equal 1, reader.lineno
        assert_equal "content\n", reader.peek_line
        assert_equal 1, reader.lineno
      end
  
      test 'peek_line returns nil if cursor advances past end of source' do
        input = <<-EOS
ifdef::foobar[]
swallowed content
endif::foobar[]
        EOS
  
        reader = Asciidoctor::PreprocessorReader.new empty_document, input
        assert_equal 1, reader.lineno
        assert_nil reader.peek_line
        assert_equal 4, reader.lineno
      end
  
      test 'ifdef with defined attribute includes content' do
        input = <<-EOS
ifdef::holygrail[]
There is a holy grail!
endif::holygrail[]
        EOS
         
        doc = empty_document :attributes => {'holygrail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'There is a holy grail!', lines.join.chomp
      end
  
      test 'ifdef with defined attribute includes text in brackets' do
        input = <<-EOS
On our quest we go...
ifdef::holygrail[There is a holy grail!]
There was much rejoicing.
        EOS
         
        doc = empty_document :attributes => {'holygrail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "On our quest we go...\nThere is a holy grail!\nThere was much rejoicing.", lines.join.chomp
      end
  
      test 'ifndef with defined attribute does not include text in brackets' do
        input = <<-EOS
On our quest we go...
ifndef::hardships[There is a holy grail!]
There was no rejoicing.
        EOS
         
        doc = empty_document :attributes => {'hardships' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "On our quest we go...\nThere was no rejoicing.", lines.join.chomp
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
         
        doc = empty_document :attributes => {'grail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "holy\ngrail", lines.join.chomp
      end
  
      test 'nested excludes with same condition' do
        input = <<-EOS
ifndef::grail[]
ifndef::grail[]
not here
endif::grail[]
endif::grail[]
        EOS
         
        doc = empty_document :attributes => {'grail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', lines.join.chomp
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
         
        doc = empty_document :attributes => {'grail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "holy\ngrail", lines.join.chomp
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
         
        doc = empty_document :attributes => {'grail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "poof\ngone", lines.join.chomp
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
         
        doc = empty_document :attributes => {'grail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "poof\ngone", lines.join.chomp
      end
  
      test 'ifdef with one alternative attribute set includes content' do
        input = <<-EOS
ifdef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS
  
        doc = empty_document :attributes => {'swallow' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', lines.join.chomp
      end
  
      test 'ifdef with no alternative attributes set does not include content' do
        input = <<-EOS
ifdef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', lines.join.chomp
      end
  
      test 'ifdef with all required attributes set includes content' do
        input = <<-EOS
ifdef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS
  
        doc = empty_document :attributes => {'holygrail' => '', 'swallow' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', lines.join.chomp
      end
  
      test 'ifdef with missing required attributes does not include content' do
        input = <<-EOS
ifdef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS
  
        doc = empty_document :attributes => {'holygrail' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', lines.join.chomp
      end
  
      test 'ifndef with undefined attribute includes block' do
        input = <<-EOS
ifndef::holygrail[]
Our quest continues to find the holy grail!
endif::holygrail[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest continues to find the holy grail!', lines.join.chomp
      end
  
      test 'ifndef with one alternative attribute set includes content' do
        input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS
  
        doc = empty_document :attributes => {'swallow' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', lines.join.chomp
      end
  
      test 'ifndef with no alternative attributes set includes content' do
        input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', lines.join.chomp
      end
  
      test 'ifndef with any required attributes set does not include content' do
        input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS
  
        doc = empty_document :attributes => {'swallow' => ''}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', lines.join.chomp
      end
  
      test 'ifndef with no required attributes set includes content' do
        input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', lines.join.chomp
      end
  
      test 'escaped ifdef is unescaped and ignored' do
        input = <<-EOS
\\ifdef::holygrail[]
content
\\endif::holygrail[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "ifdef::holygrail[]\ncontent\nendif::holygrail[]", lines.join.chomp
      end
  
      test 'ifeval comparing double-quoted attribute to matching string is included' do
        input = <<-EOS
ifeval::["{gem}" == "asciidoctor"]
Asciidoctor it is!
endif::[]
        EOS
  
        doc = empty_document :attributes => {'gem' => 'asciidoctor'}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Asciidoctor it is!', lines.join.chomp
      end
  
      test 'ifeval comparing single-quoted attribute to matching string is included' do
        input = <<-EOS
ifeval::['{gem}' == 'asciidoctor']
Asciidoctor it is!
endif::[]
        EOS
  
        doc = empty_document :attributes => {'gem' => 'asciidoctor'}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Asciidoctor it is!', lines.join.chomp
      end
  
      test 'ifeval comparing quoted attribute to non-matching string is ignored' do
        input = <<-EOS
ifeval::['{gem}' == 'asciidoctor']
Asciidoctor it is!
endif::[]
        EOS
  
        doc = empty_document :attributes => {'gem' => 'tilt'}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', lines.join.chomp
      end
  
      test 'ifeval comparing attribute to lower version number is included' do
        input = <<-EOS
ifeval::['{asciidoctor-version}' >= '0.1.0']
That version will do!
endif::[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'That version will do!', lines.join.chomp
      end
  
      test 'ifeval comparing attribute to self is included' do
        input = <<-EOS
ifeval::['{asciidoctor-version}' == '{asciidoctor-version}']
Of course it's the same!
endif::[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Of course it\'s the same!', lines.join.chomp
      end
  
      test 'ifeval arguments can be transposed' do
        input = <<-EOS
ifeval::["0.1.0" <= "{asciidoctor-version}"]
That version will do!
endif::[]
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'That version will do!', lines.join.chomp
      end
  
      test 'ifeval matching numeric comparison is included' do
        input = <<-EOS
ifeval::[{rings} == 1]
One ring to rule them all!
endif::[]
        EOS
  
        doc = empty_document :attributes => {'rings' => 1}
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'One ring to rule them all!', lines.join.chomp
      end
  
      test 'ifdef with no target is ignored' do
        input = <<-EOS
ifdef::[]
content
        EOS
  
        doc = empty_document
        reader = Asciidoctor::PreprocessorReader.new doc, input
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "ifdef::[]\ncontent", lines.join.chomp
      end
    end
  end
end
