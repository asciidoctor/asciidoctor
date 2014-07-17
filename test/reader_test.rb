# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

class ReaderTest < Minitest::Test
  DIRNAME = File.expand_path(File.dirname(__FILE__))

  SAMPLE_DATA = <<-EOS.chomp.split(::Asciidoctor::EOL)
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
        data = "\xef\xbb\xbf#{SAMPLE_DATA.join ::Asciidoctor::EOL}"
        reader = Asciidoctor::Reader.new data, nil, :normalize => true
        assert_equal 'f', reader.lines.first[0..0]
        assert_equal SAMPLE_DATA, reader.lines
      end

      test 'should remove UTF-8 BOM from first line of Array data' do
        data = SAMPLE_DATA.dup
        data[0] = "\xef\xbb\xbf#{data.first}"
        reader = Asciidoctor::Reader.new data, nil, :normalize => true
        assert_equal 'f', reader.lines.first[0..0]
        assert_equal SAMPLE_DATA, reader.lines
      end

      if Asciidoctor::COERCE_ENCODING
        test 'should encode UTF-16LE string to UTF-8 when BOM is found' do
          data = "\uFEFF#{SAMPLE_DATA.join ::Asciidoctor::EOL}".encode('UTF-16LE').force_encoding('UTF-8')
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first[0..0]
          assert_equal SAMPLE_DATA, reader.lines
        end

        test 'should encode UTF-16LE string array to UTF-8 when BOM is found' do
          data = "\uFEFF#{SAMPLE_DATA.join ::Asciidoctor::EOL}".encode('UTF-16LE').force_encoding('UTF-8').lines.to_a
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first[0..0]
          assert_equal SAMPLE_DATA, reader.lines
        end

        test 'should encode UTF-16BE string to UTF-8 when BOM is found' do
          data = "\uFEFF#{SAMPLE_DATA.join ::Asciidoctor::EOL}".encode('UTF-16BE').force_encoding('UTF-8')
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first[0..0]
          assert_equal SAMPLE_DATA, reader.lines
        end

        test 'should encode UTF-16BE string array to UTF-8 when BOM is found' do
          data = "\uFEFF#{SAMPLE_DATA.join ::Asciidoctor::EOL}".encode('UTF-16BE').force_encoding('UTF-8').lines.to_a
          reader = Asciidoctor::Reader.new data, nil, :normalize => true
          assert_equal 'f', reader.lines.first[0..0]
          assert_equal SAMPLE_DATA, reader.lines
        end
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
        assert_equal SAMPLE_DATA.join(::Asciidoctor::EOL), reader.read
      end

      test 'has_more_lines? should return false after read_lines is invoked' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA
        reader.read_lines
        assert !reader.has_more_lines?
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
        assert_equal SAMPLE_DATA.join(::Asciidoctor::EOL), reader.source
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
        assert_equal 'sample.adoc: line 2', reader.next_line_info
      end

      test 'prev_line_info should return file name and line number of previous line read' do
        reader = Asciidoctor::Reader.new SAMPLE_DATA, 'sample.adoc'
        reader.read_line
        assert_equal 'sample.adoc: line 1', reader.prev_line_info
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
        assert !reader.has_more_lines?
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
        lines = <<-EOS.chomp.split(::Asciidoctor::EOL)
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
        lines = <<-EOS.chomp.split(::Asciidoctor::EOL)
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
        lines = <<-EOS.chomp.split(::Asciidoctor::EOL)
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
        lines = <<-EOS.chomp.split(::Asciidoctor::EOL)
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
    end
  end

  context 'PreprocessorReader' do
    context 'Type hierarchy' do
      test 'PreprocessorReader should extend from Reader' do
        reader = empty_document.reader
        assert reader.is_a?(Asciidoctor::Reader)
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
        data_as_string = data * ::Asciidoctor::EOL
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

        [input, input.lines.to_a, input.split(::Asciidoctor::EOL), input.split(::Asciidoctor::EOL).join(::Asciidoctor::EOL)].each do |lines|
          doc = Asciidoctor::Document.new lines
          reader = doc.reader
          reader.lines.each do |line|
            assert !line.end_with?("\r"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
            assert !line.end_with?("\r\n"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
            assert !line.end_with?("\n"), "CRLF not properly cleaned for source lines: #{lines.inspect}"
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
        assert !doc.attributes.key?('front-matter')
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
      test 'PreprocessorReader#push_include method should return nil' do
        reader = empty_document.reader
        append_lines = %w(one two three)
        result = reader.push_include append_lines, '<stdin>', '<stdin>'
        assert_nil result
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
        output = doc.render
        assert_match(/included content/, output)
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
          output = doc.render
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
          output = doc.render
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
        reader = Asciidoctor::PreprocessorReader.new doc, input, pseudo_docfile

        assert_equal pseudo_docfile, reader.file
        assert_equal DIRNAME, reader.dir
        assert_equal 'include-master.adoc', reader.path

        assert_equal 'first line of parent', reader.read_line

        assert_equal 'fixtures/parent-include.adoc: line 1', reader.prev_line_info
        assert_equal parent_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/parent-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal 'first line of child', reader.read_line

        assert_equal 'fixtures/child-include.adoc: line 1', reader.prev_line_info
        assert_equal child_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/child-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal 'first line of grandchild', reader.read_line

        assert_equal 'fixtures/grandchild-include.adoc: line 1', reader.prev_line_info
        assert_equal grandchild_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/grandchild-include.adoc', reader.path

        reader.skip_blank_lines

        assert_equal 'last line of grandchild', reader.read_line

        reader.skip_blank_lines

        assert_equal 'last line of child', reader.read_line

        reader.skip_blank_lines

        assert_equal 'last line of parent', reader.read_line

        assert_equal 'fixtures/parent-include.adoc: line 5', reader.prev_line_info
        assert_equal parent_include_docfile, reader.file
        assert_equal fixtures_dir, reader.dir
        assert_equal 'fixtures/parent-include.adoc', reader.path
      end
  
      test 'missing file referenced by include directive does not crash processor' do
        input = <<-EOS
include::fixtures/no-such-file.adoc[]
        EOS
  
        begin
          doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
          assert_equal 1, doc.blocks.size
          assert_equal ['Unresolved directive in <stdin> - include::fixtures/no-such-file.adoc[]'], doc.blocks[0].lines
        rescue
          flunk 'include directive should not raise exception on missing file'
        end
      end
  
      test 'include directive can retrieve data from uri' do
        #url = 'http://echo.jsontest.com/name/asciidoctor'
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
  
      test 'inaccessible uri referenced by include directive does not crash processor' do
        url = %(http://#{resolve_localhost}:9876/no_such_file)
        input = <<-EOS
....
include::#{url}[]
....
        EOS

        output = begin
          using_test_webserver do
            render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
          end
        rescue
          flunk 'include directive should not raise exception on inaccessible uri'
        end
        refute_nil output
        assert_match(/Unresolved directive/, output)
      end
  
      test 'include directive supports line selection' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1;3..4;6..-1]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
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
  
      test 'include directive supports line selection using quoted attribute value' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines="1, 3..4 , 6 .. -1"]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
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
  
      test 'include directive supports tagged selection' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[tag=snippetA]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        assert_match(/snippetA content/, output)
        refute_match(/snippetB content/, output)
        refute_match(/non-tagged content/, output)
        refute_match(/included content/, output)
      end
  
      test 'include directive supports multiple tagged selection' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[tags=snippetA;snippetB]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        assert_match(/snippetA content/, output)
        assert_match(/snippetB content/, output)
        refute_match(/non-tagged content/, output)
        refute_match(/included content/, output)
      end

      test 'include directive does not select tagged lines inside tagged selection' do
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

      test 'should warn if tag is not found in include file' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[tag=snippetZ]
        EOS
  
        old_stderr = $stderr
        $stderr = StringIO.new
        begin
          render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
          warning = $stderr.tap(&:rewind).read
          refute_nil warning
          assert_match(/WARNING.*snippetZ/, warning)
        ensure
          $stderr = old_stderr
        end
      end
  
      test 'lines attribute takes precedence over tags attribute in include directive' do
        input = <<-EOS
include::fixtures/include-file.asciidoc[lines=1, tags=snippetA;snippetB]
        EOS
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
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
  
        output = render_string input, :safe => :safe, :header_footer => false, :base_dir => DIRNAME
        result = xmlnodes_at_xpath('//pre', output, 1).text
        assert_equal "<year>2013</year>\n<holder>Acme™, Inc.</holder>", result
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
        reader = Asciidoctor::PreprocessorReader.new document, input
        reader.instance_variable_set '@include_processors', [include_processor.new(document)]
        lines = reader.read_lines
        source = lines * ::Asciidoctor::EOL
        assert_match(/included content/, source)
      end

      test 'leveloffset attribute entries should be added to content if leveloffset attribute is specified' do
        input = <<-EOS
include::fixtures/master.adoc[]
        EOS

        expected = <<-EOS.chomp.split(::Asciidoctor::EOL)
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
        output = doc.render
        assert_match(/included content/, output)
      end
  
      test 'line is skipped by default if target of include directive resolves to empty' do
        input = <<-EOS
include::{foodir}/include-file.asciidoc[]
        EOS
  
        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input
        assert_equal 'Unresolved directive in <stdin> - include::{foodir}/include-file.asciidoc[]', reader.read_line
      end

      test 'line is dropped if target of include directive resolves to empty and attribute-missing attribute is not skip' do
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
        assert_equal 'yo', reader.read_line
      end
  
      test 'escaped include directive is left unprocessed' do
        input = <<-EOS
\\include::fixtures/include-file.asciidoc[]
\\escape preserved here
        EOS
        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input
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

        pseudo_docfile = File.join DIRNAME, 'include-master.adoc'

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input, Asciidoctor::Reader::Cursor.new(pseudo_docfile)

        lines = reader.readlines
        assert lines.include?('include::child-include.adoc[]')
      end

      test 'include directive should be disabled if max include depth set in nested context has been exceeded' do
        input = <<-EOS
include::fixtures/parent-include-restricted.adoc[depth=3]
        EOS

        pseudo_docfile = File.join DIRNAME, 'include-master.adoc'

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, input, Asciidoctor::Reader::Cursor.new(pseudo_docfile)

        lines = reader.readlines
        assert lines.include?('first line of child')
        assert lines.include?('include::grandchild-include.adoc[]')
      end

      test 'read_lines_until should not process lines if process option is false' do
        lines = <<-EOS.each_line.to_a
////
include::fixtures/no-such-file.adoc[]
////
        EOS

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, lines
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

        doc = empty_safe_document :base_dir => DIRNAME
        reader = Asciidoctor::PreprocessorReader.new doc, lines
        result = reader.skip_comment_lines
        assert_equal lines.map {|l| l.chomp}, result
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
        assert_equal 'There is a holy grail!', (lines * ::Asciidoctor::EOL)
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
        assert_equal "On our quest we go...\nThere is a holy grail!\nThere was much rejoicing.", (lines * ::Asciidoctor::EOL)
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
        assert_equal "On our quest we go...\nThere was no rejoicing.", (lines * ::Asciidoctor::EOL)
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
        assert_equal "holy\ngrail", (lines * ::Asciidoctor::EOL)
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
        assert_equal '', (lines * ::Asciidoctor::EOL)
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
        assert_equal "holy\ngrail", (lines * ::Asciidoctor::EOL)
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
        assert_equal "poof\ngone", (lines * ::Asciidoctor::EOL)
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
        assert_equal "poof\ngone", (lines * ::Asciidoctor::EOL)
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
        assert_equal 'Our quest is complete!', (lines * ::Asciidoctor::EOL)
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
        assert_equal '', (lines * ::Asciidoctor::EOL)
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
        assert_equal 'Our quest is complete!', (lines * ::Asciidoctor::EOL)
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
        assert_equal '', (lines * ::Asciidoctor::EOL)
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
        assert_equal 'Our quest continues to find the holy grail!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifndef with one alternative attribute set includes content' do
        input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS
  
        doc = Asciidoctor::Document.new input, :attributes => { 'swallow' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifndef with no alternative attributes set includes content' do
        input = <<-EOS
ifndef::holygrail,swallow[]
Our quest is complete!
endif::holygrail,swallow[]
        EOS
  
        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifndef with any required attributes set does not include content' do
        input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS
  
        doc = Asciidoctor::Document.new input, :attributes => { 'swallow' => '' }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal '', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifndef with no required attributes set includes content' do
        input = <<-EOS
ifndef::holygrail+swallow[]
Our quest is complete!
endif::holygrail+swallow[]
        EOS
  
        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'Our quest is complete!', (lines * ::Asciidoctor::EOL)
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
        assert_equal "ifdef::holygrail[]\ncontent\nendif::holygrail[]", (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifeval comparing double-quoted attribute to matching string is included' do
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
        assert_equal 'Asciidoctor it is!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifeval comparing single-quoted attribute to matching string is included' do
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
        assert_equal 'Asciidoctor it is!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifeval comparing quoted attribute to non-matching string is ignored' do
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
        assert_equal '', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifeval comparing attribute to lower version number is included' do
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
        assert_equal 'That version will do!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifeval comparing attribute to self is included' do
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
        assert_equal 'Of course it\'s the same!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifeval arguments can be transposed' do
        input = <<-EOS
ifeval::["0.1.0" <= "{asciidoctor-version}"]
That version will do!
endif::[]
        EOS
  
        doc = Asciidoctor::Document.new input
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'That version will do!', (lines * ::Asciidoctor::EOL)
      end
  
      test 'ifeval matching numeric comparison is included' do
        input = <<-EOS
ifeval::[{rings} == 1]
One ring to rule them all!
endif::[]
        EOS
  
        doc = Asciidoctor::Document.new input, :attributes => { 'rings' => 1 }
        reader = doc.reader
        lines = []
        while reader.has_more_lines?
          lines << reader.read_line
        end
        assert_equal 'One ring to rule them all!', (lines * ::Asciidoctor::EOL)
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
        assert_equal "ifdef::[]\ncontent", (lines * ::Asciidoctor::EOL)
      end
    end
  end
end
