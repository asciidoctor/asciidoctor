# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

class ReaderTest < Minitest::Test
  DIRNAME = File.expand_path File.dirname __FILE__

  SAMPLE_DATA = <<-EOS.chomp.split(::Asciidoctor::LF)
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

      test 'should remove UTF-8 BOM from first line of String data' do
        data = "\xef\xbb\xbf#{SAMPLE_DATA.join ::Asciidoctor::LF}"
        reader = Asciidoctor::Reader.new data, nil, :normalize => true
        assert_equal 'f', reader.lines.first.chr
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'should remove UTF-8 BOM from first line of Array data' do
        data = SAMPLE_DATA.dup
        data[0] = "\xef\xbb\xbf#{data.first}"
        reader = Asciidoctor::Reader.new data, nil, :normalize => true
        assert_equal 'f', reader.lines.first.chr
        assert_equal SAMPLE_DATA, reader.lines
      end

      if Asciidoctor::COERCE_ENCODING
        test 'should encode UTF-16LE string to UTF-8 when BOM is found' do
          data = "\ufeff#{SAMPLE_DATA.join ::Asciidoctor::LF}".encode('UTF-16LE').force_encoding('UTF-8')
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first.chr
          assert_equal SAMPLE_DATA, reader.lines
        end

        test 'should encode UTF-16LE string array to UTF-8 when BOM is found' do
          data = "\ufeff#{SAMPLE_DATA.join ::Asciidoctor::LF}".encode('UTF-16LE').force_encoding('UTF-8').lines.to_a
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first.chr
          assert_equal SAMPLE_DATA, reader.lines
        end

        test 'should encode UTF-16BE string to UTF-8 when BOM is found' do
          data = "\ufeff#{SAMPLE_DATA.join ::Asciidoctor::LF}".encode('UTF-16BE').force_encoding('UTF-8')
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first.chr
          assert_equal SAMPLE_DATA, reader.lines
        end

        test 'should encode UTF-16BE string array to UTF-8 when BOM is found' do
          data = "\ufeff#{SAMPLE_DATA.join ::Asciidoctor::LF}".encode('UTF-16BE').force_encoding('UTF-8').lines.to_a
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first.chr
          assert_equal SAMPLE_DATA, reader.lines
        end
      end
    end

    context 'With empty data' do
      test 'has_more_lines? should return false with empty data' do
        refute Asciidoctor::Reader.new.has_more_lines?
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
        assert_equal [], Asciidoctor::Reader.new.peek_lines(1)
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
        refute reader.empty?
        refute reader.eof?
      end

      test 'next_line_empty? should return false if next line is not blank' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        refute reader.next_line_empty?
      end

      test 'next_line_empty? should return true if next line is blank' do
        reader = Asciidoctor::Reader.new ['', 'second line']
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

      test 'peek_lines should not increment line number if reader overruns buffer' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA, (reader.peek_lines SAMPLE_DATA.size * 2)
        assert_equal 1, reader.lineno
      end

      test 'peek_lines should peek all lines if no arguments are given' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA, reader.peek_lines
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
        refute reader.advance
      end

      test 'read_lines should return all lines' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA, reader.read_lines
      end

      test 'read should return all lines joined as String' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        assert_equal SAMPLE_DATA.join(::Asciidoctor::LF), reader.read
      end

      test 'has_more_lines? should return false after read_lines is invoked' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.read_lines
        refute reader.has_more_lines?
      end

      test 'unshift puts line onto Reader as next line to read' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, nil, :normalize => true
        reader.unshift 'line zero'
        assert_equal 'line zero', reader.peek_line
        assert_equal 'line zero', reader.read_line
        assert_equal 1, reader.lineno
      end

      test 'terminate should consume all lines and update line number' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.terminate
        assert reader.eof?
        assert_equal 4, reader.lineno
      end

      test 'skip_blank_lines should skip blank lines' do
        reader = Asciidoctor::Reader.new ['', ''].concat(SAMPLE_DATA)
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
        assert_equal SAMPLE_DATA.join(::Asciidoctor::LF), reader.source
      end

    end

    context 'Line context' do
      test 'to_s should return file name and line number of current line' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, 'sample.adoc'
        reader.read_line
        assert_equal 'sample.adoc: line 2', reader.to_s
      end

      test 'line_info should return file name and line number of current line' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, 'sample.adoc'
        reader.read_line
        assert_equal 'sample.adoc: line 2', reader.line_info
        assert_equal 'sample.adoc: line 2', reader.cursor.to_s
      end

      test 'cursor_at_prev_line should return file name and line number of previous line read' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, 'sample.adoc'
        reader.read_line
        assert_equal 'sample.adoc: line 1', reader.cursor_at_prev_line.to_s
      end
    end

    context 'Read lines until' do
      test 'Read lines until until end' do
        lines = <<-EOS.lines.entries
This is one paragraph.

This is another paragraph.
        EOS

        reader = Asciidoctor::Reader.new lines, nil, :normalize => true
        result = reader.read_lines_until
        assert_equal 3, result.size
        assert_equal lines.map {|l| l.chomp }, result
        refute reader.has_more_lines?
        assert reader.eof?
      end

      test 'Read lines until until blank line' do
        lines = <<-EOS.lines.entries
This is one paragraph.

This is another paragraph.
        EOS

        reader = Asciidoctor::Reader.new lines, nil, :normalize => true
        result = reader.read_lines_until :break_on_blank_lines => true
        assert_equal 1, result.size
        assert_equal lines.first.chomp, result.first
        assert_equal lines.last.chomp, reader.peek_line
      end

      test 'Read lines until until blank line preserving last line' do
        lines = <<-EOS.chomp.split(::Asciidoctor::LF)
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
        lines = <<-EOS.chomp.split(::Asciidoctor::LF)
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
        EOS

        reader = Asciidoctor::Reader.new lines
        reader.read_line
        result = reader.read_lines_until {|line| line == '--' }
        assert_equal 3, result.size
        assert_equal lines[1, 3], result
        assert reader.next_line_empty?
      end

      test 'Read lines until until condition is true, taking last line' do
        lines = <<-EOS.chomp.split(::Asciidoctor::LF)
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
        EOS

        reader = Asciidoctor::Reader.new lines
        reader.read_line
        result = reader.read_lines_until(:read_last_line => true) {|line| line == '--' }
        assert_equal 4, result.size
        assert_equal lines[1, 4], result
        assert reader.next_line_empty?
      end

      test 'Read lines until until condition is true, taking and preserving last line' do
        lines = <<-EOS.chomp.split(::Asciidoctor::LF)
--
This is one paragraph inside the block.

This is another paragraph inside the block.
--

This is a paragraph outside the block.
        EOS

        reader = Asciidoctor::Reader.new lines
        reader.read_line
        result = reader.read_lines_until(:read_last_line => true, :preserve_last_line => true) {|line| line == '--' }
        assert_equal 4, result.size
        assert_equal lines[1, 4], result
        assert_equal '--', reader.peek_line
      end

      test 'read lines until terminator' do
        lines = <<-EOS.each_line.to_a
****
captured

also captured
****

not captured
        EOS

        expected = ['captured', '', 'also captured']

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, lines, nil, :normalize => true
        terminator = reader.read_line
        result = reader.read_lines_until :terminator => terminator, :skip_processing => true
        assert_equal expected, result
        refute reader.unterminated
      end

      test 'should flag reader as unterminated if reader reaches end of source without finding terminator' do
        lines = <<-EOS.each_line.to_a
****
captured

also captured

captured yet again
        EOS

        expected = lines[1..-1].map {|l| l.chomp }

        using_memory_logger do |logger|
          doc = empty_safe_document :base_dir => DIRNAME
          reader = Asciidoctor::PreprocessorReader.new doc, lines, nil, :normalize => true
          terminator = reader.peek_line
          result = reader.read_lines_until :terminator => terminator, :skip_first_line => true, :skip_processing => true
          assert_equal expected, result
          assert reader.unterminated
          assert_message logger, :WARN, '<stdin>: line 1: unterminated **** block', Hash
        end
      end
    end
  end

  context 'PreprocessorReader' do
    context 'Type hierarchy' do
      test 'PreprocessorReader should extend from Reader' do
        reader = empty_document.reader
        assert_kind_of Asciidoctor::PreprocessorReader, reader
      end

      test 'PreprocessorReader should invoke or emulate Reader initializer' do
        doc = Asciidoctor::Document.new SAMPLE_DATA
        reader = doc.reader
        assert_equal SAMPLE_DATA, reader.lines
        assert_equal 1, reader.lineno
      end
    end

    context 'Prepare lines' do
      test 'should prepare and normalize lines from Array data' do
        data = SAMPLE_DATA.map {|line| line.chomp}
        data.unshift ''
        data.push ''
        doc = Asciidoctor::Document.new data
        reader = doc.reader
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'should prepare and normalize lines from String data' do
        data = SAMPLE_DATA.map {|line| line.chomp}
        data.unshift ' '
        data.push ' '
        data_as_string = data * ::Asciidoctor::LF
        doc = Asciidoctor::Document.new data_as_string
        reader = doc.reader
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'should clean CRLF from end of lines' do
        input = <<-EOS
source\r
with\r
CRLF\r
endlines\r
      EOS

        [input, input.lines.to_a, input.split(::Asciidoctor::LF), input.split(::Asciidoctor::LF).join(::Asciidoctor::LF)].each do |lines|
          doc = Asciidoctor::Document.new lines
          reader = doc.reader
          reader.lines.each do |line|
            refute line.end_with?("\r"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
            refute line.end_with?("\r\n"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
            refute line.end_with?("\n"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
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

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        refute doc.attributes.key?('front-matter')
        assert_equal '---', reader.peek_line
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

        doc = Asciidoctor::Document.new input, :attributes => {'skip-front-matter' => ''}
        reader = doc.reader
        assert_equal '= Document Title', reader.peek_line
        assert_equal front_matter, doc.attributes['front-matter']
      end
    end

    context 'Include Stack' do
      test 'PreprocessorReader#push_include method should return reader' do
        reader = empty_document.reader
        append_lines = %w(one two three)
        result = reader.push_include append_lines, '<stdin>', '<stdin>'
        assert_equal reader, result
      end

      test 'PreprocessorReader#push_include method should put lines on top of stack' do
        lines = %w(a b c)
        doc = Asciidoctor::Document.new lines
        reader = doc.reader
        append_lines = %w(one two three)
        reader.push_include append_lines, '', '<stdin>'
        assert_equal 1, reader.include_stack.size
        assert_equal 'one', reader.read_line.rstrip
      end

      test 'PreprocessorReader#push_include method should gracefully handle file and path' do
        lines = %w(a b c)
        doc = Asciidoctor::Document.new lines
        reader = doc.reader
        append_lines = %w(one two three)
        reader.push_include append_lines
        assert_equal 1, reader.include_stack.size
        assert_equal 'one', reader.read_line.rstrip
        assert_nil reader.file
        assert_equal '<stdin>', reader.path
      end

      test 'PreprocessorReader#push_include method should set path from file automatically if not specified' do
        lines = %w(a b c)
        doc = Asciidoctor::Document.new lines
        reader = doc.reader
        append_lines = %w(one two three)
        reader.push_include append_lines, '/tmp/lines.adoc'
        assert_equal '/tmp/lines.adoc', reader.file
        assert_equal 'lines.adoc', reader.path
      end

      test 'PreprocessorReader#push_include method should accept file as a URI and compute dir and path' do
        file_uri = ::URI.parse 'http://example.com/docs/file.adoc'
        dir_uri = ::URI.parse 'http://example.com/docs'
        reader = empty_document.reader
        reader.push_include %w(one two three), file_uri
        assert_same file_uri, reader.file
        assert_equal dir_uri, reader.dir
        assert_equal 'file.adoc', reader.path
      end

      test 'PreprocessorReader#push_include method should accept file as a top-level URI and compute dir and path' do
        file_uri = ::URI.parse 'http://example.com/index.adoc'
        dir_uri = ::URI.parse 'http://example.com'
        reader = empty_document.reader
        reader.push_include %w(one two three), file_uri
        assert_same file_uri, reader.file
        assert_equal dir_uri, reader.dir
        assert_equal 'index.adoc', reader.path
      end
    end

    context 'Include Directive' do
      test 'include directive is disabled by default and becomes a link' do
        input = <<-EOS
include::include-file.asciidoc[]
        EOS
        doc = Asciidoctor::Document.new input
        reader = doc.reader
        assert_equal 'link:include-file.asciidoc[]', reader.read_line
      end

      test 'include directive is enabled when safe mode is less than SECURE' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[]
        EOS

        doc = document_from_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        output = doc.convert
        assert_match(/included content/, output)
        assert doc.catalog[:includes]['fixtures/include-file']
      end

      test 'should not track include in catalog for non-AsciiDoc include files' do
        input = <<-EOS
----
include::fixtures/circle.svg[]
----
        EOS

        doc = document_from_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        assert doc.catalog[:includes].empty?
      end

      test 'include directive should resolve file with spaces in name' do
        input = <<-EOS
include::fixtures/include file.asciidoc[]
        EOS

        include_file = File.join DIRNAME, 'fixtures', 'include-file.asciidoc'
        include_file_with_sp = File.join DIRNAME, 'fixtures', 'include file.asciidoc'
        begin
          FileUtils.cp include_file, include_file_with_sp
          doc = document_from_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
          output = doc.convert
          assert_match(/included content/, output)
        ensure
          FileUtils.rm include_file_with_sp
        end
      end

      test 'include directive should resolve file with {sp} in name' do
        input = <<-EOS
include::fixtures/include{sp}file.asciidoc[]
        EOS

        include_file = File.join DIRNAME, 'fixtures', 'include-file.asciidoc'
        include_file_with_sp = File.join DIRNAME, 'fixtures', 'include file.asciidoc'
        begin
          FileUtils.cp include_file, include_file_with_sp
          doc = document_from_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
          output = doc.convert
          assert_match(/included content/, output)
        ensure
          FileUtils.rm include_file_with_sp
        end
      end

      test 'include directive should resolve file relative to current include' do
        input = <<-EOS
include::fixtures/parent-include.adoc[]
        EOS

        pseudo_docfile = File.join DIRNAME, 'include-master.adoc'
        fixtures_dir = File.join DIRNAME, 'fixtures'
        parent_include_docfile = File.join fixtures_dir, 'parent-include.adoc'
        child_include_docfile = File.join fixtures_dir, 'child-include.adoc'
        grandchild_include_docfile = File.join fixtures_dir, 'grandchild-include.adoc'

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input, pseudo_docfile, :normalize => true

        assert_equal pseudo_docfile, reader.file
        assert_equal DIRNAME, reader.dir
        assert_equal 'include-master.adoc', reader.path

        assert_equal 'first line of parent', reader.read_line

        assert_equal 'fixtures/parent-include.adoc: line 1', reader.cursor_at_prev_line.to_s
        assert_equal parent_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/parent-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal 'first line of child', reader.read_line

        assert_equal 'fixtures/child-include.adoc: line 1', reader.cursor_at_prev_line.to_s
        assert_equal child_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/child-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal 'first line of grandchild', reader.read_line

        assert_equal 'fixtures/grandchild-include.adoc: line 1', reader.cursor_at_prev_line.to_s
        assert_equal grandchild_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/grandchild-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal 'last line of grandchild', reader.read_line

        reader.skip_blank_lines

        assert_equal 'last line of child', reader.read_line

        reader.skip_blank_lines

        assert_equal 'last line of parent', reader.read_line

        assert_equal 'fixtures/parent-include.adoc: line 5', reader.cursor_at_prev_line.to_s
        assert_equal parent_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/parent-include.adoc', reader.path
      end

      test 'missing file referenced by include directive is skipped when optional option is set' do
        input = <<-EOS
include::fixtures/no-such-file.adoc[opts=optional]

trailing content
        EOS

        begin
          using_memory_logger do |logger|
            doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
            assert_equal 1, doc.blocks.size
            assert_equal ['trailing content'], doc.blocks[0].lines
            assert logger.empty?
          end
        rescue
          flunk 'include directive should not raise exception on missing file'
        end
      end

      test 'missing file referenced by include directive is replaced by warning' do
        input = <<-EOS
include::fixtures/no-such-file.adoc[]

trailing content
        EOS

        begin
          using_memory_logger do |logger|
            doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
            assert_equal 2, doc.blocks.size
            assert_equal ['Unresolved directive in <stdin> - include::fixtures/no-such-file.adoc[]'], doc.blocks[0].lines
            assert_equal ['trailing content'], doc.blocks[1].lines
            assert_message logger, :ERROR, '~<stdin>: line 1: include file not found', Hash
          end
        rescue
          flunk 'include directive should not raise exception on missing file'
        end
      end

      test 'unreadable file referenced by include directive is replaced by warning' do
        include_file = File.join DIRNAME, 'fixtures', 'chapter-a.adoc'
        FileUtils.chmod 0000, include_file
        input = <<-EOS
include::fixtures/chapter-a.adoc[]

trailing content
        EOS

        begin
          using_memory_logger do |logger|
            doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
            assert_equal 2, doc.blocks.size
            assert_equal ['Unresolved directive in <stdin> - include::fixtures/chapter-a.adoc[]'], doc.blocks[0].lines
            assert_equal ['trailing content'], doc.blocks[1].lines
            assert_message logger, :ERROR, '~<stdin>: line 1: include file not readable', Hash
          end
        rescue
          flunk 'include directive should not raise exception on missing file'
        ensure
          FileUtils.chmod 0644, include_file
        end
      end unless windows?

      # IMPORTANT this test needs to be run on Windows to verify proper behavior in Windows
      test 'can resolve include directive with absolute path' do
        include_path = ::File.join DIRNAME, 'fixtures', 'chapter-a.adoc'
        input = <<-EOS
include::#{include_path}[]
        EOS
        result = document_from_string input, :safe => :safe
        assert_equal 'Chapter A', result.doctitle

        result = document_from_string input, :safe => :unsafe, :base_dir => ::Dir.tmpdir
        assert_equal 'Chapter A', result.doctitle
      end

      test 'include directive can retrieve data from uri' do
        url = %(http://#{resolve_localhost}:9876/name/asciidoctor)
        input = <<-EOS
....
include::#{url}[]
....
        EOS
        expect = /\{"name": "asciidoctor"\}/
        output = using_test_webserver do
          render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
        end

        refute_nil output
        assert_match(expect, output)
      end

      test 'nested include directives are resolved relative to current file' do
        input = <<-EOS
....
include::fixtures/outer-include.adoc[]
....
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = 'first line of outer

first line of middle

first line of inner

last line of inner

last line of middle

last line of outer'
        assert_includes output, expected
      end

      test 'nested remote include directive is resolved relative to uri of current file' do
        url = %(http://#{resolve_localhost}:9876/fixtures/outer-include.adoc)
        input = <<-EOS
....
include::#{url}[]
....
        EOS
        output = using_test_webserver do
          render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
        end

        expected = 'first line of outer

first line of middle

first line of inner

last line of inner

last line of middle

last line of outer'
        assert_includes output, expected
      end

      test 'nested remote include directive that cannot be resolved does not crash processor' do
        include_url = %(http://#{resolve_localhost}:9876/fixtures/file-with-missing-include.adoc)
        nested_include_url = 'no-such-file.adoc'
        input = <<-EOS
....
include::#{include_url}[]
....
        EOS
        begin
          using_memory_logger do |logger|
            result = using_test_webserver do
              render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
            end
            assert_includes result, %(Unresolved directive in #{include_url} - include::#{nested_include_url}[])
            assert_message logger, :ERROR, %(#{include_url}: line 1: include uri not readable: http://#{resolve_localhost}:9876/fixtures/#{nested_include_url}), Hash
          end
        rescue
          flunk 'include directive should not raise exception on missing file'
        end
      end

      test 'tag filtering is supported for remote includes' do
        url = %(http://#{resolve_localhost}:9876/fixtures/tagged-class.rb)
        input = <<-EOS
[source,ruby]
----
include::#{url}[tag=init,indent=0]
----
        EOS
        output = using_test_webserver do
          render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
        end

        expected = '<code class="language-ruby" data-lang="ruby">def initialize breed
  @breed = breed
end</code>'
        assert_includes output, expected
      end

      test 'inaccessible uri referenced by include directive does not crash processor' do
        url = %(http://#{resolve_localhost}:9876/no_such_file)
        input = <<-EOS
....
include::#{url}[]
....
        EOS

        begin
          using_memory_logger do |logger|
            output = using_test_webserver do
              render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
            end
            refute_nil output
            assert_match(/Unresolved directive/, output)
            assert_message logger, :ERROR, %(<stdin>: line 2: include uri not readable: #{url}), Hash
          end
        rescue
          flunk 'include directive should not raise exception on inaccessible uri'
        end
      end

      test 'include directive supports selecting lines by line number' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1;3..4;6..-1]
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        assert_match(/first line/, output)
        refute_match(/second line/, output)
        assert_match(/third line/, output)
        assert_match(/fourth line/, output)
        refute_match(/fifth line/, output)
        assert_match(/sixth line/, output)
        assert_match(/seventh line/, output)
        assert_match(/eighth line/, output)
        assert_match(/last line of included content/, output)
      end

      test 'include directive supports line ranges specified in quoted attribute value' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines="1, 3..4 , 6 .. -1"]
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        assert_match(/first line/, output)
        refute_match(/second line/, output)
        assert_match(/third line/, output)
        assert_match(/fourth line/, output)
        refute_match(/fifth line/, output)
        assert_match(/sixth line/, output)
        assert_match(/seventh line/, output)
        assert_match(/eighth line/, output)
        assert_match(/last line of included content/, output)
      end

      test 'include directive ignores empty lines attribute' do
        input = <<-EOS
++++
include::fixtures/include-file.asciidoc[lines=]
++++
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        assert_includes output, 'first line of included content'
        assert_includes output, 'last line of included content'
      end

      test 'include directive supports selecting lines by tag' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[tag=snippetA]
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        assert_match(/snippetA content/, output)
        refute_match(/snippetB content/, output)
        refute_match(/non-tagged content/, output)
        refute_match(/included content/, output)
      end

      test 'include directive supports selecting lines by tags' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[tags=snippetA;snippetB]
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        assert_match(/snippetA content/, output)
        assert_match(/snippetB content/, output)
        refute_match(/non-tagged content/, output)
        refute_match(/included content/, output)
      end

      test 'include directive supports selecting lines by tag in language that uses circumfix comments' do
        {
          'include-file.xml' => '<snippet>content</snippet>',
          'include-file.ml' => 'let s = SS.empty;;',
          'include-file.jsx' => '<p>Welcome to the club.</p>'
        }.each do |filename, expect|
          input = <<-EOS
[source,xml]
----
include::fixtures/#{filename}[tag=snippet,indent=0]
----
          EOS

          doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
          assert_equal expect, doc.blocks[0].source
        end
      end

      test 'include directive supports selecting tagged lines in file that has CRLF endlines' do
        begin
          tmp_include = Tempfile.new %w(include- .adoc)
          tmp_include_dir, tmp_include_path = File.split tmp_include.path
          tmp_include.write %(do not include\r\ntag::include-me[]\r\nincluded line\r\nend::include-me[]\r\ndo not include\r\n)
          tmp_include.close
          input = <<-EOS
include::#{tmp_include_path}[tag=include-me]
          EOS
          output = render_embedded_string input, :safe => :safe, :base_dir => tmp_include_dir
          assert_includes output, 'included line'
          refute_includes output, 'do not include'
        ensure
          tmp_include.close!
        end 
      end

      test 'include directive does not select lines with tag directives within selected tag region' do
        input = <<-EOS
++++
include::fixtures/include-file.asciidoc[tags=snippet]
++++
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expect = %(snippetA content

non-tagged content

snippetB content)
        assert_equal expect, output
      end

      test 'include directive skips lines marked with negated tags' do
        input = <<-EOS
----
include::fixtures/tagged-class-enclosed.rb[tags=all;!bark]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = %(class Dog
  def initialize breed
    @breed = breed
  end
end)
        assert_includes output, expected
      end

      test 'include directive takes all lines without tag directives when value is double asterisk' do
        input = <<-EOS
----
include::fixtures/tagged-class.rb[tags=**]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = %(class Dog
  def initialize breed
    @breed = breed
  end

  def bark
    if @breed == 'beagle'
      'woof woof woof woof woof'
    else
      'woof woof'
    end
  end
end)
        assert_includes output, expected
      end

      test 'include directive takes all lines except negated tags when value contains double asterisk' do
        input = <<-EOS
----
include::fixtures/tagged-class.rb[tags=**;!bark]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = %(class Dog
  def initialize breed
    @breed = breed
  end
end)
        assert_includes output, expected
      end

      test 'include directive selects lines for all tags when value of tags attribute is wildcard' do
        input = <<-EOS
----
include::fixtures/tagged-class-enclosed.rb[tags=*]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = %(class Dog
  def initialize breed
    @breed = breed
  end

  def bark
    if @breed == 'beagle'
      'woof woof woof woof woof'
    else
      'woof woof'
    end
  end
end)
        assert_includes output, expected
      end

      test 'include directive selects lines for all tags except exclusions when value of tags attribute is wildcard' do
        input = <<-EOS
----
include::fixtures/tagged-class-enclosed.rb[tags=*;!init]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = %(class Dog

  def bark
    if @breed == 'beagle'
      'woof woof woof woof woof'
    else
      'woof woof'
    end
  end
end)
        assert_includes output, expected
      end

      test 'include directive skips lines all tagged lines when value of tags attribute is negated wildcard' do
        input = <<-EOS
----
include::fixtures/tagged-class.rb[tags=!*]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = %(class Dog
end)
        assert_includes output, expected
      end

      test 'include directive selects specified tagged lines and ignores the other tag directives' do
        input = <<-EOS
[indent=0]
----
include::fixtures/tagged-class.rb[tags=bark;!bark-other]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        expected = %(def bark
  if @breed == 'beagle'
    'woof woof woof woof woof'
  end
end)
        assert_includes output, expected
      end

      test 'should warn if specified tag is not found in include file' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[tag=no-such-tag]
        EOS

        using_memory_logger do |logger|
          render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
          assert_message logger, :WARN, %(~<stdin>: line 1: tag 'no-such-tag' not found in include file), Hash
        end
      end

      test 'should warn if specified tags are not found in include file' do
        input = <<-EOS
++++
include::fixtures/include-file.asciidoc[tags=no-such-tag-b;no-such-tag-a]
++++
        EOS

        using_memory_logger do |logger|
          render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
          # NOTE Ruby 1.8 swaps the order of the list for some silly reason
          expected_tags = ::RUBY_MIN_VERSION_1_9 ? 'no-such-tag-b, no-such-tag-a' : 'no-such-tag-a, no-such-tag-b'
          assert_message logger, :WARN, %(~<stdin>: line 2: tags '#{expected_tags}' not found in include file), Hash
        end
      end

      test 'should warn if specified tag in include file is not closed' do
        input = <<-EOS
++++
include::fixtures/unclosed-tag.adoc[tag=a]
++++
        EOS

        using_memory_logger do |logger|
          result = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
          assert_equal 'a', result
          assert_message logger, :WARN, %(~<stdin>: line 2: detected unclosed tag 'a' starting at line 2 of include file), Hash
          refute_nil logger.messages[0][:message][:include_location]
        end
      end

      test 'should warn if end tag in included file is mismatched' do
        input = <<-EOS
++++
include::fixtures/mismatched-end-tag.adoc[tags=a;b]
++++
        EOS

        inc_path = File.join DIRNAME, 'fixtures/mismatched-end-tag.adoc'
        using_memory_logger do |logger|
          result = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
          assert_equal %(a\nb), result
          assert_message logger, :WARN, %(<stdin>: line 2: mismatched end tag (expected 'b' but found 'a') at line 5 of include file: #{inc_path}), Hash
          refute_nil logger.messages[0][:message][:include_location]
        end
      end

      test 'should warn if unexpected end tag is found in included file' do
        input = <<-EOS
++++
include::fixtures/unexpected-end-tag.adoc[tags=a]
++++
        EOS

        inc_path = File.join DIRNAME, 'fixtures/unexpected-end-tag.adoc'
        using_memory_logger do |logger|
          result = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
          assert_equal 'a', result
          assert_message logger, :WARN, %(<stdin>: line 2: unexpected end tag 'a' at line 4 of include file: #{inc_path}), Hash
          refute_nil logger.messages[0][:message][:include_location]
        end
      end

      test 'include directive ignores tags attribute when empty' do
        ['tag', 'tags'].each do |attr_name|
          input = <<-EOS
++++
include::fixtures/include-file.xml[#{attr_name}=]
++++
          EOS

          output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
          assert_match(/(?:tag|end)::/, output, 2)
        end
      end

      test 'lines attribute takes precedence over tags attribute in include directive' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1, tags=snippetA;snippetB]
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        assert_match(/first line of included content/, output)
        refute_match(/snippetA content/, output)
        refute_match(/snippetB content/, output)
      end

      test 'indent of included file can be reset to size of indent attribute' do
        input = <<-EOS
[source, xml]
----
include::fixtures/basic-docinfo.xml[lines=2..3, indent=0]
----
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        result = xmlnodes_at_xpath('//pre', output, 1).text
        assert_equal "<year>2013</year>\n<holder>Acme™, Inc.</holder>", result
      end

      test 'should substitute attribute references in attrlist' do
        input = <<-EOS
:name-of-tag: snippetA
include::fixtures/include-file.asciidoc[tag={name-of-tag}]
        EOS

        output = render_embedded_string input, :safe => :safe, :base_dir => DIRNAME
        assert_match(/snippetA content/, output)
        refute_match(/snippetB content/, output)
        refute_match(/non-tagged content/, output)
        refute_match(/included content/, output)
      end

      test 'should fall back to built-in include directive behavior when not handled by include processor' do
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
        reader = Asciidoctor::PreprocessorReader.new document, input, nil, :normalize => true
        reader.instance_variable_set '@include_processors', [include_processor.new(document)]
        lines = reader.read_lines
        source = lines * ::Asciidoctor::LF
        assert_match(/included content/, source)
      end

      test 'leveloffset attribute entries should be added to content if leveloffset attribute is specified' do
        input = <<-EOS
include::fixtures/master.adoc[]
        EOS

        expected = <<-EOS.chomp.split(::Asciidoctor::LF)
= Master Document

preamble

:leveloffset: +1

= Chapter A

content

:leveloffset!:
        EOS

        document = Asciidoctor.load input, :safe => :safe, :base_dir => DIRNAME, :parse => false
        assert_equal expected, document.reader.read_lines
      end

      test 'attributes are substituted in target of include directive' do
        input = <<-EOS
:fixturesdir: fixtures
:ext: asciidoc

include::{fixturesdir}/include-file.{ext}[]
        EOS

        doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
        output = doc.convert
        assert_match(/included content/, output)
      end

      test 'line is skipped by default if target of include directive resolves to empty' do
        input = <<-EOS
include::{foodir}/include-file.asciidoc[]
        EOS

        using_memory_logger do |logger|
          doc = empty_safe_document :base_dir => DIRNAME
          reader = Asciidoctor::PreprocessorReader.new doc, input, nil, :normalize => true
          line = reader.read_line
          assert_equal 'Unresolved directive in <stdin> - include::{foodir}/include-file.asciidoc[]', line
          assert_message logger, :WARN, 'dropping line containing reference to missing attribute: foodir'
        end
      end

      test 'line is dropped if target of include directive resolves to empty and attribute-missing attribute is not skip' do
        input = <<-EOS
include::{foodir}/include-file.asciidoc[]
        EOS

        using_memory_logger do |logger|
          doc = empty_safe_document :base_dir => DIRNAME, :attributes => {'attribute-missing' => 'drop'}
          reader = Asciidoctor::PreprocessorReader.new doc, input, nil, :normalize => true
          line = reader.read_line
          assert_nil line
          assert_message logger, :WARN, 'dropping line containing reference to missing attribute: foodir'
        end
      end

      test 'line following dropped include is not dropped' do
        input = <<-EOS
include::{foodir}/include-file.asciidoc[]
yo
        EOS

        using_memory_logger do |logger|
          doc = empty_safe_document :base_dir => DIRNAME, :attributes => {'attribute-missing' => 'drop'}
          reader = Asciidoctor::PreprocessorReader.new doc, input, nil, :normalize => true
          line = reader.read_line
          assert_equal 'yo', line
          assert_message logger, :WARN, 'dropping line containing reference to missing attribute: foodir'
        end
      end

      test 'escaped include directive is left unprocessed' do
        input = <<-EOS
\\include::fixtures/include-file.asciidoc[]
\\escape preserved here
        EOS
        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input, nil, :normalize => true
        # we should be able to peek it multiple times and still have the backslash preserved
        # this is the test for @unescape_next_line
        assert_equal 'include::fixtures/include-file.asciidoc[]', reader.peek_line
        assert_equal 'include::fixtures/include-file.asciidoc[]', reader.peek_line
        assert_equal 'include::fixtures/include-file.asciidoc[]', reader.read_line
        assert_equal '\\escape preserved here', reader.read_line
      end

      test 'include directive not at start of line is ignored' do
        input = <<-EOS
 include::include-file.asciidoc[]
        EOS
        para = block_from_string input
        assert_equal 1, para.lines.size
        # NOTE the space gets stripped because the line is treated as an inline literal
        assert_equal :literal, para.context
        assert_equal 'include::include-file.asciidoc[]', para.source
      end

      test 'include directive is disabled when max-include-depth attribute is 0' do
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

      test 'include directive should be disabled if max include depth has been exceeded' do
        input = <<-EOS
include::fixtures/parent-include.adoc[depth=1]
        EOS

        using_memory_logger do |logger|
          pseudo_docfile = File.join DIRNAME, 'include-master.adoc'
          doc = empty_safe_document :base_dir => DIRNAME
          reader = Asciidoctor::PreprocessorReader.new doc, input, Asciidoctor::Reader::Cursor.new(pseudo_docfile), :normalize => true
          lines = reader.readlines
          assert_includes lines, 'include::child-include.adoc[]'
          assert_message logger, :ERROR, 'fixtures/parent-include.adoc: line 3: maximum include depth of 1 exceeded', Hash
        end
      end

      test 'include directive should be disabled if max include depth set in nested context has been exceeded' do
        input = <<-EOS
include::fixtures/parent-include-restricted.adoc[depth=3]
        EOS

        using_memory_logger do |logger|
          pseudo_docfile = File.join DIRNAME, 'include-master.adoc'
          doc = empty_safe_document :base_dir => DIRNAME
          reader = Asciidoctor::PreprocessorReader.new doc, input, Asciidoctor::Reader::Cursor.new(pseudo_docfile), :normalize => true
          lines = reader.readlines
          assert_includes lines, 'first line of child'
          assert_includes lines, 'include::grandchild-include.adoc[]'
          assert_message logger, :ERROR, 'fixtures/child-include.adoc: line 3: maximum include depth of 1 exceeded', Hash
        end
      end

      test 'read_lines_until should not process lines if process option is false' do
        lines = <<-EOS.each_line.to_a
////
include::fixtures/no-such-file.adoc[]
////
        EOS

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, lines, nil, :normalize => true
        reader.read_line
        result = reader.read_lines_until(:terminator => '////', :skip_processing => true)
        assert_equal lines.map {|l| l.chomp}[1..1], result
      end

      test 'skip_comment_lines should not process lines read' do
        lines = <<-EOS.each_line.to_a
////
include::fixtures/no-such-file.adoc[]
////
        EOS

        using_memory_logger do |logger|
          doc = empty_safe_document :base_dir => DIRNAME
          reader = Asciidoctor::PreprocessorReader.new doc, lines, nil, :normalize => true
          reader.skip_comment_lines
          assert reader.empty?
          assert logger.empty?
        end
      end
    end

    context 'Conditional Inclusions' do
      test 'process_line returns nil if cursor advanced' do
        input = <<-EOS
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        assert_nil reader.process_line(reader.lines.first)
      end

      test 'peek_line advances cursor to next conditional line of content' do
        input = <<-EOS
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        assert_equal 1, reader.lineno
        assert_equal 'Asciidoctor!', reader.peek_line
        assert_equal 2, reader.lineno
      end

      test 'peek_lines should preprocess lines if direct is false' do
        input = <<-EOS
The Asciidoctor
ifdef::asciidoctor[is in.]
        EOS
        doc = Asciidoctor::Document.new input
        reader = doc.reader
        result = reader.peek_lines 2, false
        assert_equal ['The Asciidoctor', 'is in.'], result
      end

      test 'peek_lines should not preprocess lines if direct is true' do
        input = <<-EOS
The Asciidoctor
ifdef::asciidoctor[is in.]
        EOS
        doc = Asciidoctor::Document.new input
        reader = doc.reader
        result = reader.peek_lines 2, true
        assert_equal ['The Asciidoctor', 'ifdef::asciidoctor[is in.]'], result
      end

      test 'peek_lines should not prevent subsequent preprocessing of peeked lines' do
        input = <<-EOS
The Asciidoctor
ifdef::asciidoctor[is in.]
        EOS
        doc = Asciidoctor::Document.new input
        reader = doc.reader
        result = reader.peek_lines 2, true
        result = reader.peek_lines 2, false
        assert_equal ['The Asciidoctor', 'is in.'], result
      end

      test 'process_line returns line if cursor not advanced' do
        input = <<-EOS
content
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        refute_nil reader.process_line(reader.lines.first)
      end

      test 'peek_line does not advance cursor when on a regular content line' do
        input = <<-EOS
content
ifdef::asciidoctor[]
Asciidoctor!
endif::asciidoctor[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        assert_equal 1, reader.lineno
        assert_equal 'content', reader.peek_line
        assert_equal 1, reader.lineno
      end

      test 'peek_line returns nil if cursor advances past end of source' do
        input = <<-EOS
ifdef::foobar[]
swallowed content
endif::foobar[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
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

        doc = Asciidoctor::Document.new input, :attributes => { 'holygrail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'There is a holy grail!', (lines * ::Asciidoctor::LF)
      end

      test 'ifdef with defined attribute includes text in brackets' do
        input = <<-EOS
On our quest we go...
ifdef::holygrail[There is a holy grail!]
There was much rejoicing.
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'holygrail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "On our quest we go...\nThere is a holy grail!\nThere was much rejoicing.", (lines * ::Asciidoctor::LF)
      end

      test 'ifdef with defined attribute processes include directive in brackets' do
        input = <<-EOS
ifdef::asciidoctor-version[include::fixtures/include-file.asciidoc[tag=snippetA]]
        EOS

        doc = Asciidoctor::Document.new input, :safe => :safe, :base_dir => DIRNAME
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'snippetA content', lines[0]
      end

      test 'ifdef attribute name is not case sensitive' do
        input = <<-EOS
ifdef::showScript[]
The script is shown!
endif::showScript[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'showscript' => '' }
        result = doc.reader.read
        assert_equal 'The script is shown!', result
      end

      test 'ifndef with defined attribute does not include text in brackets' do
        input = <<-EOS
On our quest we go...
ifndef::hardships[There is a holy grail!]
There was no rejoicing.
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'hardships' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "On our quest we go...\nThere was no rejoicing.", (lines * ::Asciidoctor::LF)
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

        doc = Asciidoctor::Document.new input, :attributes => { 'grail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "holy\ngrail", (lines * ::Asciidoctor::LF)
      end

      test 'nested excludes with same condition' do
        input = <<-EOS
ifndef::grail[]
ifndef::grail[]
not here
endif::grail[]
endif::grail[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'grail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', (lines * ::Asciidoctor::LF)
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

        doc = Asciidoctor::Document.new input, :attributes => { 'grail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "holy\ngrail", (lines * ::Asciidoctor::LF)
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

        doc = Asciidoctor::Document.new input, :attributes => { 'grail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "poof\ngone", (lines * ::Asciidoctor::LF)
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

        doc = Asciidoctor::Document.new input, :attributes => { 'grail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "poof\ngone", (lines * ::Asciidoctor::LF)
      end

      test 'ifdef with one alternative attribute set includes content' do
        input = <<-EOS
ifdef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'swallow' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', (lines * ::Asciidoctor::LF)
      end

      test 'ifdef with no alternative attributes set does not include content' do
        input = <<-EOS
ifdef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', (lines * ::Asciidoctor::LF)
      end

      test 'ifdef with all required attributes set includes content' do
        input = <<-EOS
ifdef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'holygrail' => '', 'swallow' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', (lines * ::Asciidoctor::LF)
      end

      test 'ifdef with missing required attributes does not include content' do
        input = <<-EOS
ifdef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'holygrail' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', (lines * ::Asciidoctor::LF)
      end

      test 'ifdef should permit leading, trailing, and repeat operators' do
        {
          'asciidoctor,' => 'content',
          ',asciidoctor' => 'content',
          'asciidoctor+' => '',
          '+asciidoctor' => '',
          'asciidoctor,,asciidoctor-version' => 'content',
          'asciidoctor++asciidoctor-version' => ''
        }.each do |condition, expected|
          input = <<-EOS
ifdef::#{condition}[]
content
endif::[]
          EOS
          assert_equal expected, (document_from_string input, :parse => false).reader.read
        end
      end

      test 'ifndef with undefined attribute includes block' do
        input = <<-EOS
ifndef::holygrail[]
Our quest continues to find the holy grail!
endif::holygrail[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest continues to find the holy grail!', (lines * ::Asciidoctor::LF)
      end

      test 'ifndef with one alternative attribute set does not include content' do
        input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS

        result = (Asciidoctor::Document.new input, :attributes => { 'swallow' => '' }).reader.read
        assert_empty result
      end

      test 'ifndef with both alternative attributes set does not include content' do
        input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS

        result = (Asciidoctor::Document.new input, :attributes => { 'swallow' => '', 'holygrail' => '' }).reader.read
        assert_empty result
      end

      test 'ifndef with no alternative attributes set includes content' do
        input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS

        result = (Asciidoctor::Document.new input).reader.read
        assert_equal 'Our quest is complete!', result
      end

      test 'ifndef with no required attributes set includes content' do
        input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS

        result = (Asciidoctor::Document.new input).reader.read
        assert_equal 'Our quest is complete!', result
      end

      test 'ifndef with all required attributes set does not include content' do
        input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS

        result = (Asciidoctor::Document.new input, :attributes => { 'swallow' => '', 'holygrail' => '' }).reader.read
        assert_empty result
      end

      test 'ifndef with at least one required attributes set does not include content' do
        input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS

        result = (Asciidoctor::Document.new input, :attributes => { 'swallow' => '' }).reader.read
        assert_equal 'Our quest is complete!', result
      end

      test 'escaped ifdef is unescaped and ignored' do
        input = <<-EOS
\\ifdef::holygrail[]
content
\\endif::holygrail[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "ifdef::holygrail[]\ncontent\nendif::holygrail[]", (lines * ::Asciidoctor::LF)
      end

      test 'ifeval comparing missing attribute to nil includes content' do
        input = <<-EOS
ifeval::['{foo}' == '']
No foo for you!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'No foo for you!', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval comparing missing attribute to 0 drops content' do
        input = <<-EOS
ifeval::[{leveloffset} == 0]
I didn't make the cut!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval comparing double-quoted attribute to matching string includes content' do
        input = <<-EOS
ifeval::["{gem}" == "asciidoctor"]
Asciidoctor it is!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'gem' => 'asciidoctor' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Asciidoctor it is!', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval comparing single-quoted attribute to matching string includes content' do
        input = <<-EOS
ifeval::['{gem}' == 'asciidoctor']
Asciidoctor it is!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'gem' => 'asciidoctor' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Asciidoctor it is!', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval comparing quoted attribute to non-matching string drops content' do
        input = <<-EOS
ifeval::['{gem}' == 'asciidoctor']
Asciidoctor it is!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'gem' => 'tilt' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval comparing attribute to lower version number includes content' do
        input = <<-EOS
ifeval::['{asciidoctor-version}' >= '0.1.0']
That version will do!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'That version will do!', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval comparing attribute to self includes content' do
        input = <<-EOS
ifeval::['{asciidoctor-version}' == '{asciidoctor-version}']
Of course it's the same!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Of course it\'s the same!', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval arguments can be transposed' do
        input = <<-EOS
ifeval::['0.1.0' <= '{asciidoctor-version}']
That version will do!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'That version will do!', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval matching numeric equality includes content' do
        input = <<-EOS
ifeval::[{rings} == 1]
One ring to rule them all!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'rings' => '1' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'One ring to rule them all!', (lines * ::Asciidoctor::LF)
      end

      test 'ifeval matching numeric inequality includes content' do
        input = <<-EOS
ifeval::[{rings} != 0]
One ring to rule them all!
endif::[]
        EOS

        doc = Asciidoctor::Document.new input, :attributes => { 'rings' => '1' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'One ring to rule them all!', (lines * ::Asciidoctor::LF)
      end

      test 'ifdef with no target is ignored' do
        input = <<-EOS
ifdef::[]
content
        EOS

        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal "ifdef::[]\ncontent", (lines * ::Asciidoctor::LF)
      end
    end
  end
end
