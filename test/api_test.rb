# frozen_string_literal: true
require_relative 'test_helper'

context 'API' do
  context 'Load' do
    test 'should load input file' do
      sample_input_path = fixture_path('sample.adoc')
      doc = File.open(sample_input_path, Asciidoctor::FILE_READ_MODE) {|file| Asciidoctor.load file, safe: Asciidoctor::SafeMode::SAFE }
      assert_equal 'Document Title', doc.doctitle
      assert_equal File.expand_path(sample_input_path), doc.attr('docfile')
      assert_equal File.expand_path(File.dirname(sample_input_path)), doc.attr('docdir')
      assert_equal '.adoc', doc.attr('docfilesuffix')
    end

    test 'should load input file from filename' do
      sample_input_path = fixture_path('sample.adoc')
      doc = Asciidoctor.load_file(sample_input_path, safe: Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      assert_equal File.expand_path(sample_input_path), doc.attr('docfile')
      assert_equal File.expand_path(File.dirname(sample_input_path)), doc.attr('docdir')
      assert_equal '.adoc', doc.attr('docfilesuffix')
    end

    test 'should load input file from pathname' do
      sample_input_path = Pathname fixture_path 'sample.adoc'
      doc = Asciidoctor.load_file sample_input_path, safe: :safe
      assert_equal 'Document Title', doc.doctitle
      assert_equal sample_input_path.expand_path.to_s, (doc.attr 'docfile')
      assert_equal sample_input_path.expand_path.dirname.to_s, (doc.attr 'docdir')
      assert_equal '.adoc', (doc.attr 'docfilesuffix')
    end

    test 'should load input file with alternate file extension' do
      sample_input_path = fixture_path 'sample-alt-extension.asciidoc'
      doc = Asciidoctor.load_file sample_input_path, safe: :safe
      assert_equal 'Document Title', doc.doctitle
      assert_equal File.expand_path(sample_input_path), doc.attr('docfile')
      assert_equal File.expand_path(File.dirname(sample_input_path)), doc.attr('docdir')
      assert_equal '.asciidoc', doc.attr('docfilesuffix')
    end

    test 'should coerce encoding of file to UTF-8' do
      old_external = Encoding.default_external
      old_internal = Encoding.default_internal
      old_verbose = $VERBOSE
      begin
        $VERBOSE = nil # disable warnings since we have to modify constants
        input_path = fixture_path 'encoding.adoc'
        Encoding.default_external = Encoding.default_internal = Encoding::IBM437
        output = Asciidoctor.convert_file input_path, to_file: false, safe: :safe
        assert_equal Encoding::UTF_8, output.encoding
        assert_include 'Romé', output
      ensure
        Encoding.default_external = old_external
        Encoding.default_internal = old_internal
        $VERBOSE = old_verbose
      end
    end

    test 'should not load file with unrecognized encoding' do
      begin
        tmp_input = Tempfile.new %w(test- .adoc), encoding: Encoding::IBM437
        # NOTE using a character whose code differs between UTF-8 and IBM437
        tmp_input.write %(ƒ\n)
        tmp_input.close
        exception = assert_raises ArgumentError do
          Asciidoctor.load_file tmp_input.path, safe: :safe
        end
        expected_message = 'Failed to load AsciiDoc document - source is either binary or contains invalid Unicode data'
        assert_include expected_message, exception.message
      ensure
        tmp_input.close!
      end
    end

    test 'should not load invalid file' do
      sample_input_path = fixture_path('hello-asciidoctor.pdf')
      exception = assert_raises ArgumentError do
        Asciidoctor.load_file(sample_input_path, safe: Asciidoctor::SafeMode::SAFE)
      end
      expected_message = 'Failed to load AsciiDoc document - source is either binary or contains invalid Unicode data'
      assert_include expected_message, exception.message
      # verify we have the correct backtrace (should be at least in the first 5 lines)
      assert_match(/reader\.rb.*prepare_lines/, exception.backtrace[0..4].join(?\n))
    end

    # NOTE JRuby for Windows does not permit creating a file with non-Windows-1252 characters in the filename
    test 'should convert filename that contains non-ASCII characters independent of default encodings', unless: (jruby? && windows?) do
      old_external = Encoding.default_external
      old_internal = Encoding.default_internal
      old_verbose = $VERBOSE
      begin
        $VERBOSE = nil # disable warnings since we have to modify constants
        tmp_input = Tempfile.new %w(test-ＵＴＦ８- .adoc)
        tmp_input.write %(ＵＴＦ８\n)
        tmp_input.close
        Encoding.default_external = Encoding.default_internal = Encoding::IBM437
        tmp_output = tmp_input.path.sub '.adoc', '.html'
        Asciidoctor.convert_file tmp_input.path, safe: :safe, attributes: 'linkcss !copycss'
        assert File.exist? tmp_output
        output = File.binread tmp_output
        refute_empty output
        # force encoding to UTF-8 and we should see that the string is in fact UTF-8 encoded
        output = String.new output, encoding: Encoding::UTF_8
        assert_equal Encoding::UTF_8, output.encoding
        assert_include 'ＵＴＦ８', output
      ensure
        tmp_input.close!
        FileUtils.rm_f tmp_output
        Encoding.default_external = old_external
        Encoding.default_internal = old_internal
        $VERBOSE = old_verbose
      end
    end

    test 'should load input IO' do
      input = StringIO.new <<~'EOS'
      Document Title
      ==============

      preamble
      EOS
      doc = Asciidoctor.load(input, safe: Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      refute doc.attr?('docfile')
      assert_equal doc.base_dir, doc.attr('docdir')
    end

    test 'should load input string' do
      input = <<~'EOS'
      Document Title
      ==============

      preamble
      EOS
      doc = Asciidoctor.load(input, safe: Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      refute doc.attr?('docfile')
      assert_equal doc.base_dir, doc.attr('docdir')
    end

    test 'should load input string array' do
      input = <<~'EOS'
      Document Title
      ==============

      preamble
      EOS
      doc = Asciidoctor.load(input.lines, safe: Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      refute doc.attr?('docfile')
      assert_equal doc.base_dir, doc.attr('docdir')
    end

    test 'should load nil input' do
      doc = Asciidoctor.load nil, safe: :safe
      refute_nil doc
      assert_empty doc.blocks
    end

    test 'should ignore :to_file option if value is truthy but not a string' do
      sample_input_path = fixture_path 'sample.adoc'
      doc = Asciidoctor.load_file sample_input_path, safe: :safe, to_file: true
      refute_nil doc
      assert_equal 'Document Title', doc.doctitle
      assert_equal '.html', (doc.attr 'outfilesuffix')
      assert_equal doc.convert, (Asciidoctor.convert_file sample_input_path, safe: :safe, to_file: false)
    end

    test 'should set outfilesuffix attribute to file extension of value of :to_file option if value is a string' do
      sample_input_path = fixture_path 'sample.adoc'
      doc = Asciidoctor.load_file sample_input_path, safe: :safe, to_file: 'out.htm'
      refute_nil doc
      assert_equal 'Document Title', doc.doctitle
      assert_equal '.htm', (doc.attr 'outfilesuffix')
    end

    test 'should accept attributes as array' do
      # NOTE there's a tab character before idseparator
      doc = Asciidoctor.load('text', attributes: %w(toc sectnums   source-highlighter=coderay idprefix	idseparator=-))
      assert_kind_of Hash, doc.attributes
      assert doc.attr?('toc')
      assert_equal '', doc.attr('toc')
      assert doc.attr?('sectnums')
      assert_equal '', doc.attr('sectnums')
      assert doc.attr?('source-highlighter')
      assert_equal 'coderay', doc.attr('source-highlighter')
      assert doc.attr?('idprefix')
      assert_equal '', doc.attr('idprefix')
      assert doc.attr?('idseparator')
      assert_equal '-', doc.attr('idseparator')
    end

    test 'should accept attributes as empty array' do
      doc = Asciidoctor.load('text', attributes: [])
      assert_kind_of Hash, doc.attributes
    end

    test 'should accept attributes as string' do
      doc = Asciidoctor.load 'text', attributes: %(toc sectnums\nsource-highlighter=coderay\nidprefix\nidseparator=-)
      assert_kind_of Hash, doc.attributes
      assert doc.attr?('toc')
      assert_equal '', doc.attr('toc')
      assert doc.attr?('sectnums')
      assert_equal '', doc.attr('sectnums')
      assert doc.attr?('source-highlighter')
      assert_equal 'coderay', doc.attr('source-highlighter')
      assert doc.attr?('idprefix')
      assert_equal '', doc.attr('idprefix')
      assert doc.attr?('idseparator')
      assert_equal '-', doc.attr('idseparator')
    end

    test 'should accept values containing spaces in attributes string' do
      doc = Asciidoctor.load('text', attributes: %(idprefix idseparator=-   note-caption=Note\\ to\\\tself toc))
      assert_kind_of Hash, doc.attributes
      assert doc.attr?('idprefix')
      assert_equal '', doc.attr('idprefix')
      assert doc.attr?('idseparator')
      assert_equal '-', doc.attr('idseparator')
      assert doc.attr?('note-caption')
      assert_equal "Note to\tself", doc.attr('note-caption')
    end

    test 'should accept attributes as empty string' do
      doc = Asciidoctor.load('text', attributes: '')
      assert_kind_of Hash, doc.attributes
    end

    test 'should accept attributes as nil' do
      doc = Asciidoctor.load('text', attributes: nil)
      assert_kind_of Hash, doc.attributes
    end

    test 'should accept attributes if hash like' do
      class Hashlike
        def initialize
          @table = { 'toc' => '' }
        end

        def keys
          @table.keys
        end

        def [](key)
          @table[key]
        end
      end

      doc = Asciidoctor.load 'text', attributes: Hashlike.new
      assert_kind_of Hash, doc.attributes
      assert doc.attributes.key?('toc')
    end

    test 'should not expand value of docdir attribute if specified via API' do
      docdir = 'virtual/directory'
      doc = document_from_string '', safe: :safe, attributes: { 'docdir' => docdir }
      assert_equal docdir, (doc.attr 'docdir')
      assert_equal docdir, doc.base_dir
    end

    test 'converts block to output format when convert is called' do
      doc = Asciidoctor.load 'paragraph text'
      expected = <<~'EOS'.chop
      <div class="paragraph">
      <p>paragraph text</p>
      </div>
      EOS
      assert_equal 1, doc.blocks.length
      assert_equal :paragraph, doc.blocks[0].context
      assert_equal expected, doc.blocks[0].convert
    end

    test 'render method on node is aliased to convert method' do
      input = <<~'EOS'
      paragraph text

      * list item
      EOS
      doc = Asciidoctor.load input
      assert_equal 2, doc.blocks.length
      ([doc] + doc.blocks).each do |block|
        assert_equal block.method(:convert), block.method(:render)
      end
      inline = Asciidoctor::Inline.new doc.blocks[0], :image, nil, type: 'image', target: 'tiger.png'
      assert_equal inline.method(:convert), inline.method(:render)
    end

    test 'should output timestamps by default' do
      doc = document_from_string 'text', backend: :html5, attributes: nil
      result = doc.convert
      assert doc.attr?('docdate')
      refute doc.attr? 'reproducible'
      assert_xpath '//div[@id="footer-text" and contains(string(.//text()), "Last updated")]', result, 1
    end

    test 'should not output timestamps if reproducible attribute is set in HTML 5' do
      doc = document_from_string 'text', backend: :html5, attributes: { 'reproducible' => '' }
      result = doc.convert
      assert doc.attr?('docdate')
      assert doc.attr?('reproducible')
      assert_xpath '//div[@id="footer-text" and contains(string(.//text()), "Last updated")]', result, 0
    end

    test 'should not output timestamps if reproducible attribute is set in DocBook' do
      doc = document_from_string 'text', backend: :docbook, attributes: { 'reproducible' => '' }
      result = doc.convert
      assert doc.attr?('docdate')
      assert doc.attr?('reproducible')
      assert_xpath '/article/info/date', result, 0
    end

    test 'should not modify options argument' do
      options = { safe: Asciidoctor::SafeMode::SAFE }
      options.freeze
      sample_input_path = fixture_path('sample.adoc')
      begin
        Asciidoctor.load_file sample_input_path, options
      rescue
        flunk %(options argument should not be modified)
      end
    end

    test 'should not modify attributes Hash argument' do
      attributes = {}
      attributes.freeze
      options = {
        safe: Asciidoctor::SafeMode::SAFE,
        attributes: attributes,
      }
      sample_input_path = fixture_path('sample.adoc')
      begin
        Asciidoctor.load_file sample_input_path, options
      rescue
        flunk %(attributes argument should not be modified)
      end
    end

    test 'should be able to restore header attributes after call to convert' do
      input = <<~'EOS'
      = Document Title
      :foo: bar

      content

      :foo: baz

      content
      EOS
      doc = Asciidoctor.load input
      assert_equal 'bar', (doc.attr 'foo')
      doc.convert
      assert_equal 'baz', (doc.attr 'foo')
      doc.restore_attributes
      assert_equal 'bar', (doc.attr 'foo')
    end

    test 'should track file and line information with blocks if sourcemap option is set' do
      doc = Asciidoctor.load_file fixture_path('sample.adoc'), sourcemap: true

      refute_nil doc.source_location
      assert_equal 'sample.adoc', doc.file
      assert_equal 1, doc.lineno

      preamble = doc.blocks[0]
      refute_nil preamble.source_location
      assert_equal 'sample.adoc', preamble.file
      assert_equal 6, preamble.lineno

      section_1 = doc.sections[0]
      assert_equal 'Section A', section_1.title
      refute_nil section_1.source_location
      assert_equal 'sample.adoc', section_1.file
      assert_equal 10, section_1.lineno

      section_2 = doc.sections[1]
      assert_equal 'Section B', section_2.title
      refute_nil section_2.source_location
      assert_equal 'sample.adoc', section_2.file
      assert_equal 18, section_2.lineno

      table_block = section_2.blocks[1]
      assert_equal :table, table_block.context
      refute_nil table_block.source_location
      assert_equal 'sample.adoc', table_block.file
      assert_equal 22, table_block.lineno
      first_cell = table_block.rows.body[0][0]
      refute_nil first_cell.source_location
      assert_equal 'sample.adoc', first_cell.file
      assert_equal 23, first_cell.lineno
      second_cell = table_block.rows.body[0][1]
      refute_nil second_cell.source_location
      assert_equal 'sample.adoc', second_cell.file
      assert_equal 23, second_cell.lineno
      last_cell = table_block.rows.body[-1][-1]
      refute_nil last_cell.source_location
      assert_equal 'sample.adoc', last_cell.file
      assert_equal 24, last_cell.lineno

      last_block = section_2.blocks[-1]
      assert_equal :ulist, last_block.context
      refute_nil last_block.source_location
      assert_equal 'sample.adoc', last_block.file
      assert_equal 28, last_block.lineno

      list_items = last_block.blocks
      refute_nil list_items[0].source_location
      assert_equal 'sample.adoc', list_items[0].file
      assert_equal 28, list_items[0].lineno

      refute_nil list_items[1].source_location
      assert_equal 'sample.adoc', list_items[1].file
      assert_equal 29, list_items[1].lineno

      refute_nil list_items[2].source_location
      assert_equal 'sample.adoc', list_items[2].file
      assert_equal 30, list_items[2].lineno

      doc = Asciidoctor.load_file fixture_path('master.adoc'), sourcemap: true, safe: :safe

      section_1 = doc.sections[0]
      assert_equal 'Chapter A', section_1.title
      refute_nil section_1.source_location
      assert_equal fixture_path('chapter-a.adoc'), section_1.file
      assert_equal 1, section_1.lineno
    end

    test 'should track file and line information on list items if sourcemap option is set' do
      doc = Asciidoctor.load_file fixture_path('lists.adoc'), sourcemap: true

      first_section = doc.blocks[1]

      unordered_basic_list = first_section.blocks[0]
      assert_equal 11, unordered_basic_list.lineno

      unordered_basic_list_items = unordered_basic_list.find_by context: :list_item
      assert_equal 11, unordered_basic_list_items[0].lineno
      assert_equal 12, unordered_basic_list_items[1].lineno
      assert_equal 13, unordered_basic_list_items[2].lineno

      unordered_max_nesting = first_section.blocks[1]
      assert_equal 16, unordered_max_nesting.lineno
      unordered_max_nesting_items = unordered_max_nesting.find_by context: :list_item
      assert_equal 16, unordered_max_nesting_items[0].lineno
      assert_equal 17, unordered_max_nesting_items[1].lineno
      assert_equal 18, unordered_max_nesting_items[2].lineno
      assert_equal 19, unordered_max_nesting_items[3].lineno
      assert_equal 20, unordered_max_nesting_items[4].lineno
      assert_equal 21, unordered_max_nesting_items[5].lineno

      checklist = first_section.blocks[2]
      assert_equal 24, checklist.lineno
      checklist_list_items = checklist.find_by context: :list_item
      assert_equal 24, checklist_list_items[0].lineno
      assert_equal 25, checklist_list_items[1].lineno
      assert_equal 26, checklist_list_items[2].lineno
      assert_equal 27, checklist_list_items[3].lineno

      ordered_basic = first_section.blocks[3]
      assert_equal 30, ordered_basic.lineno
      ordered_basic_list_items = ordered_basic.find_by context: :list_item
      assert_equal 30, ordered_basic_list_items[0].lineno
      assert_equal 31, ordered_basic_list_items[1].lineno
      assert_equal 32, ordered_basic_list_items[2].lineno

      ordered_nested = first_section.blocks[4]
      assert_equal 35, ordered_nested.lineno
      ordered_nested_list_items = ordered_nested.find_by context: :list_item
      assert_equal 35, ordered_nested_list_items[0].lineno
      assert_equal 36, ordered_nested_list_items[1].lineno
      assert_equal 37, ordered_nested_list_items[2].lineno
      assert_equal 38, ordered_nested_list_items[3].lineno
      assert_equal 39, ordered_nested_list_items[4].lineno

      ordered_max_nesting = first_section.blocks[5]
      assert_equal 42, ordered_max_nesting.lineno
      ordered_max_nesting_items = ordered_max_nesting.find_by context: :list_item
      assert_equal 42, ordered_max_nesting_items[0].lineno
      assert_equal 43, ordered_max_nesting_items[1].lineno
      assert_equal 44, ordered_max_nesting_items[2].lineno
      assert_equal 45, ordered_max_nesting_items[3].lineno
      assert_equal 46, ordered_max_nesting_items[4].lineno
      assert_equal 47, ordered_max_nesting_items[5].lineno

      labeled_singleline = first_section.blocks[6]
      assert_equal 50, labeled_singleline.lineno
      labeled_singleline_items = labeled_singleline.find_by context: :list_item
      assert_equal 50, labeled_singleline_items[0].lineno
      assert_equal 50, labeled_singleline_items[1].lineno
      assert_equal 51, labeled_singleline_items[2].lineno
      assert_equal 51, labeled_singleline_items[3].lineno

      labeled_multiline = first_section.blocks[7]
      assert_equal 54, labeled_multiline.lineno
      labeled_multiline_items = labeled_multiline.find_by context: :list_item
      assert_equal 54, labeled_multiline_items[0].lineno
      assert_equal 55, labeled_multiline_items[1].lineno
      assert_equal 56, labeled_multiline_items[2].lineno
      assert_equal 57, labeled_multiline_items[3].lineno

      qanda = first_section.blocks[8]
      assert_equal 61, qanda.lineno
      qanda_items = qanda.find_by context: :list_item
      assert_equal 61, qanda_items[0].lineno
      assert_equal 62, qanda_items[1].lineno
      assert_equal 63, qanda_items[2].lineno
      assert_equal 63, qanda_items[3].lineno

      mixed = first_section.blocks[9]
      assert_equal 66, mixed.lineno
      mixed_items = mixed.find_by(context: :list_item) {|block| block.text? }
      assert_equal 66, mixed_items[0].lineno
      assert_equal 67, mixed_items[1].lineno
      assert_equal 68, mixed_items[2].lineno
      assert_equal 69, mixed_items[3].lineno
      assert_equal 70, mixed_items[4].lineno
      assert_equal 71, mixed_items[5].lineno
      assert_equal 72, mixed_items[6].lineno
      assert_equal 73, mixed_items[7].lineno
      assert_equal 74, mixed_items[8].lineno
      assert_equal 75, mixed_items[9].lineno
      assert_equal 77, mixed_items[10].lineno
      assert_equal 78, mixed_items[11].lineno
      assert_equal 79, mixed_items[12].lineno
      assert_equal 80, mixed_items[13].lineno
      assert_equal 81, mixed_items[14].lineno
      assert_equal 82, mixed_items[15].lineno
      assert_equal 83, mixed_items[16].lineno

      unordered_complex_list = first_section.blocks[10]
      assert_equal 86, unordered_complex_list.lineno
      unordered_complex_items = unordered_complex_list.find_by context: :list_item
      assert_equal 86, unordered_complex_items[0].lineno
      assert_equal 87, unordered_complex_items[1].lineno
      assert_equal 88, unordered_complex_items[2].lineno
      assert_equal 92, unordered_complex_items[3].lineno
      assert_equal 96, unordered_complex_items[4].lineno
    end

    # FIXME see #3966
    test 'should assign incorrect lineno for single-line paragraph inside a conditional preprocessor directive' do
      input = <<~'EOS'
      :conditional-attribute:

      before

      ifdef::conditional-attribute[]
      subject
      endif::[]

      after
      EOS

      doc = document_from_string input, sourcemap: true
      # FIXME the second line number should be 6 instead of 7
      assert_equal [3, 7, 9], (doc.find_by context: :paragraph).map(&:lineno)
    end

    test 'should assign correct lineno for multi-line paragraph inside a conditional preprocessor directive' do
      input = <<~'EOS'
      :conditional-attribute:

      before

      ifdef::conditional-attribute[]
      subject
      subject
      endif::[]

      after
      EOS

      doc = document_from_string input, sourcemap: true
      assert_equal [3, 6, 10], (doc.find_by context: :paragraph).map(&:lineno)
    end

    # NOTE this does not work for a list continuation that attached to a grandparent
    test 'should assign correct source location to blocks that follow a detached list continuation' do
      input = <<~'EOS'
      * parent
       ** child

      +
      paragraph attached to parent

      ****
      sidebar outside list
      ****
      EOS

      doc = document_from_string input, sourcemap: true
      assert_equal [5, 8], (doc.find_by context: :paragraph).map(&:lineno)
    end

    test 'should assign correct source location if section occurs on last line of input' do
      input = <<~'EOS'
      = Document Title

      == Section A

      content

      == Section B
      EOS

      doc = document_from_string input, sourcemap: true
      assert_equal [1, 3, 7], (doc.find_by context: :section).map(&:lineno)
    end

    test 'should allow sourcemap option on document to be modified before document is parsed' do
      doc = Asciidoctor.load_file fixture_path('sample.adoc'), parse: false
      doc.sourcemap = true
      refute doc.parsed?
      doc = doc.parse
      assert doc.parsed?

      section_1 = doc.sections[0]
      assert_equal 'Section A', section_1.title
      refute_nil section_1.source_location
      assert_equal 'sample.adoc', section_1.file
      assert_equal 10, section_1.lineno
    end

    test 'find_by should return Array of blocks anywhere in document tree that match criteria' do
      input = <<~'EOS'
      = Document Title

      preamble

      == Section A

      paragraph

      --
      Exhibit A::
      +
      [#tiger.animal]
      image::tiger.png[Tiger]
      --

      image::shoe.png[Shoe]

      == Section B

      paragraph
      EOS

      doc = Asciidoctor.load input
      result = doc.find_by context: :image
      assert_equal 2, result.size
      assert_equal :image, result[0].context
      assert_equal 'tiger.png', result[0].attr('target')
      assert_equal :image, result[1].context
      assert_equal 'shoe.png', result[1].attr('target')
    end

    test 'find_by should return an empty Array if no matches are found' do
      input = 'paragraph'
      doc = Asciidoctor.load input
      result = doc.find_by context: :section
      refute_nil result
      assert_equal 0, result.size
    end

    test 'should only return matched node when return value of block argument is :prune' do
      input = <<~'EOS'
      * foo
       ** yin
        *** zen
       ** yang
      * bar
      * baz
      EOS

      doc = Asciidoctor.load input
      result = doc.find_by context: :list_item do |it|
        it.text == 'yin' ? :prune : false
      end
      assert_equal 1, result.size
      assert_equal 'yin', result[0].text
    end

    test 'find_by should discover blocks inside AsciiDoc table cells if traverse_documents selector option is true' do
      input = <<~'EOS'
      paragraph in parent document (before)

      [%footer,cols=2*]
      |===
      a|
      paragraph in nested document (body)
      |normal table cell

      a|
      paragraph in nested document (foot)
      |normal table cell
      |===

      paragraph in parent document (after)
      EOS

      doc = Asciidoctor.load input
      result = doc.find_by context: :paragraph
      assert_equal 2, result.size
      result = doc.find_by context: :paragraph, traverse_documents: true
      assert_equal 4, result.size
    end

    test 'find_by should return inner document of AsciiDoc table cell if traverse_documents selector option is true' do
      input = <<~'EOS'
      |===
      a|paragraph in nested document
      |===
      EOS

      doc = Asciidoctor.load input
      inner_doc = doc.blocks[0].rows.body[0][0].inner_document
      result = doc.find_by traverse_documents: true
      assert_include inner_doc, result
      result = doc.find_by context: :inner_document, traverse_documents: true
      assert_equal 1, result.size
      assert_equal inner_doc, result[0]
    end

    test 'find_by should match table cells' do
      input = <<~'EOS'
      |===
      |a |b |c

      |1
      one
      a|NOTE: 2, as it goes.
      l|
      3
       you
        me
      |===
      EOS

      doc = document_from_string input
      table = doc.blocks[0]
      first_head_cell = table.rows.head[0][0]
      first_body_cell = table.rows.body[0][0]
      result = doc.find_by
      assert_include first_head_cell, result
      assert_include first_body_cell, result
      assert_equal 'a', first_head_cell.source
      assert_equal ['a'], first_head_cell.lines
      assert_equal %(1\none), first_body_cell.source
      assert_equal ['1', 'one'], first_body_cell.lines
      result = doc.find_by context: :table_cell, style: :asciidoc
      assert_equal 1, result.size
      assert_kind_of Asciidoctor::Table::Cell, result[0]
      assert_equal :asciidoc, result[0].style
      assert_equal 'NOTE: 2, as it goes.', result[0].source
    end

    test 'find_by should return Array of blocks that match style criteria' do
      input = <<~'EOS'
      [square]
      * one
      * two
      * three

      ---

      * apples
      * bananas
      * pears
      EOS

      doc = Asciidoctor.load input
      result = doc.find_by context: :ulist, style: 'square'
      assert_equal 1, result.size
      assert_equal :ulist, result[0].context
    end

    test 'find_by should return Array of blocks that match role criteria' do
      input = <<~'EOS'
      [#tiger.animal]
      image::tiger.png[Tiger]

      image::shoe.png[Shoe]
      EOS

      doc = Asciidoctor.load input
      result = doc.find_by context: :image, role: 'animal'
      assert_equal 1, result.size
      assert_equal :image, result[0].context
      assert_equal 'tiger.png', result[0].attr('target')
    end

    test 'find_by should return the document title section if context selector is :section' do
      input = <<~'EOS'
      = Document Title

      preamble

      == Section One

      content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by context: :section
      refute_nil result
      assert_equal 2, result.size
      assert_equal :section, result[0].context
      assert_equal 'Document Title', result[0].title
    end

    test 'find_by should only return results for which the block argument yields true' do
      input = <<~'EOS'
      == Section

      content

      === Subsection

      content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by(context: :section) {|sect| sect.level == 1 }
      refute_nil result
      assert_equal 1, result.size
      assert_equal :section, result[0].context
      assert_equal 'Section', result[0].title
    end

    test 'find_by should reject node and its children if block returns :reject' do
      input = <<~'EOS'
      paragraph 1

      ====
      paragraph 2

      term::
      +
      paragraph 3
      ====

      paragraph 4
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by do |candidate|
        case candidate.context
        when :example
          :reject
        when :paragraph
          true
        end
      end
      refute_nil result
      assert_equal 2, result.size
      assert_equal :paragraph, result[0].context
      assert_equal :paragraph, result[1].context
    end

    test 'find_by should reject node matched by ID selector if block returns :reject' do
      input = <<~'EOS'
      [.rolename]
      paragraph 1

      [.rolename#idname]
      paragraph 2
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by id: 'idname', role: 'rolename'
      refute_nil result
      assert_equal 1, result.size
      assert_equal doc.blocks[1], result[0]
      result = doc.find_by(id: 'idname', role: 'rolename') { :reject }
      refute_nil result
      assert_equal 0, result.size
    end

    test 'find_by should accept node matched by ID selector if block returns :prune' do
      input = <<~'EOS'
      [.rolename]
      paragraph 1

      [.rolename#idname]
      ====
      paragraph 2
      ====
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by id: 'idname', role: 'rolename'
      refute_nil result
      assert_equal 1, result.size
      assert_equal doc.blocks[1], result[0]
      result = doc.find_by(id: 'idname', role: 'rolename') { :prune }
      refute_nil result
      assert_equal 1, result.size
      assert_equal doc.blocks[1], result[0]
    end

    test 'find_by should accept node but reject its children if block returns :prune' do
      input = <<~'EOS'
      ====
      paragraph 2

      term::
      +
      paragraph 3
      ====
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by do |candidate|
        if candidate.context == :example
          :prune
        end
      end
      refute_nil result
      assert_equal 1, result.size
      assert_equal :example, result[0].context
    end

    test 'find_by should stop looking for blocks when StopIteration is raised' do
      input = <<~'EOS'
      paragraph 1

      ====
      paragraph 2

      ****
      paragraph 3
      ****
      ====

      paragraph 4

      * item
      +
      paragraph 5
      EOS
      doc = Asciidoctor.load input

      stop_at_next = false
      result = doc.find_by do |candidate|
        raise StopIteration if stop_at_next
        if candidate.context == :paragraph
          candidate.parent.context == :sidebar ? (stop_at_next = true) : true
        end
      end
      refute_nil result
      assert_equal 3, result.size
      assert_equal 'paragraph 1', result[0].content
      assert_equal 'paragraph 2', result[1].content
      assert_equal 'paragraph 3', result[2].content
    end

    test 'find_by should stop looking for blocks when filter block returns :stop directive' do
      input = <<~'EOS'
      paragraph 1

      ====
      paragraph 2

      ****
      paragraph 3
      ****
      ====

      paragraph 4

      * item
      +
      paragraph 5
      EOS
      doc = Asciidoctor.load input

      stop_at_next = false
      result = doc.find_by do |candidate|
        next :stop if stop_at_next
        if candidate.context == :paragraph
          candidate.parent.context == :sidebar ? (stop_at_next = true) : true
        end
      end
      refute_nil result
      assert_equal 3, result.size
      assert_equal 'paragraph 1', result[0].content
      assert_equal 'paragraph 2', result[1].content
      assert_equal 'paragraph 3', result[2].content
    end

    test 'find_by should only return one result when matching by id' do
      input = <<~'EOS'
      == Section

      content

      [#subsection]
      === Subsection

      content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by(context: :section, id: 'subsection')
      refute_nil result
      assert_equal 1, result.size
      assert_equal :section, result[0].context
      assert_equal 'Subsection', result[0].title
    end

    test 'find_by should stop seeking once match is found' do
      input = <<~'EOS'
      == Section

      content

      [#subsection]
      === Subsection

      [#last]
      content
      EOS
      doc = Asciidoctor.load input
      visited_last = false
      result = doc.find_by(id: 'subsection') do |candidate|
        visited_last = true if candidate.id == 'last'
        true
      end
      refute_nil result
      assert_equal 1, result.size
      refute visited_last
    end

    test 'find_by should return an empty Array if the id criteria matches but the block argument yields false' do
      input = <<~'EOS'
      == Section

      content

      [#subsection]
      === Subsection

      content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by(context: :section, id: 'subsection') {|sect| false }
      refute_nil result
      assert_equal 0, result.size
    end

    test 'find_by should not crash if dlist entry does not have description' do
      input = 'term without description::'
      doc = Asciidoctor.load input
      result = doc.find_by
      refute_nil result
      assert_equal 3, result.size
      assert_kind_of Asciidoctor::Document, result[0]
      assert_kind_of Asciidoctor::List, result[1]
      assert_kind_of Asciidoctor::ListItem, result[2]
    end

    test 'dlist item should always have two entries for terms and desc' do
      [
        'term w/o desc::',
        %(term::\nalias::),
        %(primary:: 1\nsecondary:: 2),
      ].each do |input|
        dlist = (Asciidoctor.load input).blocks[0]
        dlist.items.each do |item|
          assert_equal 2, item.size
          assert_kind_of ::Array, item[0]
          assert_kind_of Asciidoctor::ListItem, item[1] if item[1]
        end
      end
    end

    test 'timings are recorded for each step when load and convert are called separately' do
      sample_input_path = fixture_path 'asciidoc_index.txt'
      (Asciidoctor.load_file sample_input_path, timings: (timings = Asciidoctor::Timings.new)).convert
      refute_equal '0.00000', '%05.5f' % timings.read_parse.to_f
      refute_equal '0.00000', '%05.5f' % timings.convert.to_f
      refute_equal timings.read_parse, timings.total
    end

    test 'can disable syntax highlighter by setting value to nil in :syntax_highlighters option' do
      doc = Asciidoctor.load '', safe: :safe, syntax_highlighters: { 'coderay' => nil }, attributes: { 'source-highlighter' => 'coderay' }
      assert_nil doc.syntax_highlighter
    end

    test 'can substitute a custom syntax highlighter factory instance using the :syntax_highlighter_factory option' do
      input = <<~'EOS'
      [source,ruby]
      ----
      puts 'Hello, World!'
      ----
      EOS
      # NOTE this tests both the lazy loading and the custom factory
      syntax_hl_factory = Asciidoctor::SyntaxHighlighter::CustomFactory.new 'github' => (Asciidoctor::SyntaxHighlighter.for 'html-pipeline')
      doc = Asciidoctor.load input, safe: :safe, syntax_highlighter_factory: syntax_hl_factory, attributes: { 'source-highlighter' => 'github' }
      refute_nil doc.syntax_highlighter
      assert_kind_of Asciidoctor::SyntaxHighlighter::HtmlPipelineAdapter, doc.syntax_highlighter
      assert_include '<pre lang="ruby"><code>', doc.convert
    end

    test 'can substitute an extended syntax highlighter factory implementation using the :syntax_highlighters option' do
      input = <<~'EOS'
      [source,ruby]
      ----
      puts 'Hello, World!'
      ----
      EOS
      syntax_hl_factory_class = Class.new do
        include Asciidoctor::SyntaxHighlighter::DefaultFactory

        def for name
          super 'highlight.js'
        end
      end
      doc = Asciidoctor.load input, safe: :safe, syntax_highlighter_factory: syntax_hl_factory_class.new, attributes: { 'source-highlighter' => 'coderay' }
      refute_nil doc.syntax_highlighter
      output = doc.convert
      refute_include 'CodeRay', output
      assert_include 'hljs', output
    end
  end

  context 'Convert' do
    test 'render_file is aliased to convert_file' do
      assert_equal Asciidoctor.method(:convert_file), Asciidoctor.method(:render_file)
    end

    test 'render is aliased to convert' do
      assert_equal Asciidoctor.method(:convert), Asciidoctor.method(:render)
    end

    test 'should convert source document to embedded document when header_footer is false' do
      sample_input_path = fixture_path('sample.adoc')
      sample_output_path = fixture_path('sample.html')

      [{ header_footer: false }, { header_footer: false, to_file: sample_output_path }].each do |opts|
        begin
          Asciidoctor.convert_file sample_input_path, opts
          assert File.exist?(sample_output_path)
          output = File.read(sample_output_path, mode: Asciidoctor::FILE_READ_MODE)
          refute_empty output
          assert_xpath '/html', output, 0
          assert_css '#preamble', output, 1
        ensure
          FileUtils.rm(sample_output_path)
        end
      end
    end

    test 'should convert source document to standalone document string when to_file is false and standalone is true' do
      sample_input_path = fixture_path('sample.adoc')

      output = Asciidoctor.convert_file sample_input_path, standalone: true, to_file: false
      refute_empty output
      assert_xpath '/html', output, 1
      assert_xpath '/html/head', output, 1
      assert_xpath '/html/body', output, 1
      assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
      assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
    end

    test 'should convert source document to standalone document string when to_file is false and header_footer is true' do
      sample_input_path = fixture_path('sample.adoc')

      output = Asciidoctor.convert_file sample_input_path, header_footer: true, to_file: false
      refute_empty output
      assert_xpath '/html', output, 1
      assert_xpath '/html/head', output, 1
      assert_xpath '/html/body', output, 1
      assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
      assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
    end

    test 'lines in output should be separated by line feed' do
      sample_input_path = fixture_path('sample.adoc')

      output = Asciidoctor.convert_file sample_input_path, standalone: true, to_file: false
      refute_empty output
      lines = output.split("\n")
      assert_equal lines.size, output.split(/\r\n|\r|\n/).size
      assert_equal lines.map(&:length), lines.map(&:rstrip).map(&:length)
    end

    test 'should accept attributes as array' do
      sample_input_path = fixture_path('sample.adoc')
      output = Asciidoctor.convert_file sample_input_path, attributes: %w(sectnums idprefix idseparator=-), to_file: false
      assert_css '#section-a', output, 1
    end

    test 'should accept attributes as string' do
      sample_input_path = fixture_path('sample.adoc')
      output = Asciidoctor.convert_file sample_input_path, attributes: 'sectnums idprefix idseparator=-', to_file: false
      assert_css '#section-a', output, 1
    end

    test 'should link to default stylesheet by default when safe mode is SECURE or greater' do
      sample_input_path = fixture_path('basic.adoc')
      output = Asciidoctor.convert_file sample_input_path, standalone: true, to_file: false
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 1
    end

    test 'should embed default stylesheet by default if SafeMode is less than SECURE' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      output = Asciidoctor.convert input, safe: Asciidoctor::SafeMode::SERVER, standalone: true
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 0
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
    end

    test 'should embed remote stylesheet by default if SafeMode is less than SECURE and allow-uri-read is set' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      output = using_test_webserver do
        Asciidoctor.convert input, safe: Asciidoctor::SafeMode::SERVER, standalone: true, attributes: { 'allow-uri-read' => '', 'stylesheet' => %(http://#{resolve_localhost}:9876/fixtures/custom.css) }
      end
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
      assert_include 'color: green', styles
    end

    test 'should not allow linkcss be unset from document if SafeMode is SECURE or greater' do
      input = <<~'EOS'
      = Document Title
      :linkcss!:

      text
      EOS

      output = Asciidoctor.convert input, standalone: true
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 1
    end

    test 'should embed default stylesheet if linkcss is unset from API and SafeMode is SECURE or greater' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      [{ 'linkcss!' => '' }, { 'linkcss' => nil }, { 'linkcss' => false }].each do |attrs|
        output = Asciidoctor.convert input, standalone: true, attributes: attrs
        assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
        assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 0
        stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
        styles = stylenode.content
        refute_nil styles
        refute_empty styles.strip
      end
    end

    test 'should embed default stylesheet if safe mode is less than SECURE and linkcss is unset from API' do
      sample_input_path = fixture_path('basic.adoc')
      output = Asciidoctor.convert_file sample_input_path, standalone: true, to_file: false,
          safe: Asciidoctor::SafeMode::SAFE, attributes: { 'linkcss!' => '' }
      assert_css 'html:root > head > style', output, 1
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
    end

    test 'should not link to stylesheet if stylesheet is unset' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      output = Asciidoctor.convert input, standalone: true, attributes: { 'stylesheet!' => '' }
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 0
      assert_css 'html:root > head > link[rel="stylesheet"]', output, 0
    end

    test 'should link to custom stylesheet if specified in stylesheet attribute' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      output = Asciidoctor.convert input, standalone: true, attributes: { 'stylesheet' => './custom.css' }
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 0
      assert_css 'html:root > head > link[rel="stylesheet"][href="./custom.css"]', output, 1

      output = Asciidoctor.convert input, standalone: true, attributes: { 'stylesheet' => 'file:///home/username/custom.css' }
      assert_css 'html:root > head > link[rel="stylesheet"][href="file:///home/username/custom.css"]', output, 1
    end

    test 'should resolve custom stylesheet relative to stylesdir' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      output = Asciidoctor.convert input, standalone: true, attributes: { 'stylesheet' => 'custom.css', 'stylesdir' => './stylesheets' }
      assert_css 'html:root > head > link[rel="stylesheet"][href="./stylesheets/custom.css"]', output, 1
    end

    test 'should resolve custom stylesheet to embed relative to stylesdir' do
      sample_input_path = fixture_path('basic.adoc')
      output = Asciidoctor.convert_file sample_input_path, standalone: true, safe: Asciidoctor::SafeMode::SAFE, to_file: false,
          attributes: { 'stylesheet' => 'custom.css', 'stylesdir' => './stylesheets', 'linkcss!' => '' }
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
    end

    test 'should embed custom remote stylesheet if SafeMode is less than SECURE and allow-uri-read is set' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      output = using_test_webserver do
        Asciidoctor.convert input, safe: Asciidoctor::SafeMode::SERVER, standalone: true, attributes: { 'allow-uri-read' => '', 'stylesheet' => %(http://#{resolve_localhost}:9876/fixtures/custom.css) }
      end
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
      assert_include 'color: green', styles
    end

    test 'should embed custom stylesheet in remote stylesdir if SafeMode is less than SECURE and allow-uri-read is set' do
      input = <<~'EOS'
      = Document Title

      text
      EOS

      output = using_test_webserver do
        Asciidoctor.convert input, safe: Asciidoctor::SafeMode::SERVER, standalone: true, attributes: { 'allow-uri-read' => '', 'stylesdir' => %(http://#{resolve_localhost}:9876/fixtures), 'stylesheet' => 'custom.css' }
      end
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
      assert_include 'color: green', styles
    end

    test 'should copy custom stylesheet in folder to same folder in destination dir if copycss is set' do
      begin
        output_dir = fixture_path 'output'
        sample_input_path = fixture_path 'sample.adoc'
        sample_output_path = File.join output_dir, 'sample.html'
        custom_stylesheet_output_path = File.join output_dir, 'stylesheets', 'custom.css'
        Asciidoctor.convert_file sample_input_path, safe: :safe, to_dir: output_dir, mkdirs: true,
            attributes: { 'stylesheet' => 'stylesheets/custom.css', 'linkcss' => '', 'copycss' => '' }
        assert File.exist? sample_output_path
        assert File.exist? custom_stylesheet_output_path
        output = File.read sample_output_path, mode: Asciidoctor::FILE_READ_MODE
        assert_xpath '/html/head/link[@rel="stylesheet"][@href="./stylesheets/custom.css"]', output, 1
        assert_xpath 'style', output, 0
      ensure
        FileUtils.rm_r output_dir, force: true, secure: true
      end
    end

    test 'should copy custom stylesheet to destination dir if copycss is true' do
      begin
        output_dir = fixture_path 'output'
        sample_input_path = fixture_path 'sample.adoc'
        sample_output_path = File.join output_dir, 'sample.html'
        custom_stylesheet_output_path = File.join output_dir, 'custom.css'
        Asciidoctor.convert_file sample_input_path, safe: :safe, to_dir: output_dir, mkdirs: true,
            attributes: { 'stylesheet' => 'custom.css', 'linkcss' => true, 'copycss' => true }
        assert File.exist? sample_output_path
        assert File.exist? custom_stylesheet_output_path
        output = File.read sample_output_path, mode: Asciidoctor::FILE_READ_MODE
        assert_xpath '/html/head/link[@rel="stylesheet"][@href="./custom.css"]', output, 1
        assert_xpath 'style', output, 0
      ensure
        FileUtils.rm_r output_dir, force: true, secure: true
      end
    end

    test 'should convert source file and write result to adjacent file by default' do
      sample_input_path = fixture_path('sample.adoc')
      sample_output_path = fixture_path('sample.html')
      begin
        Asciidoctor.convert_file sample_input_path
        assert File.exist?(sample_output_path)
        output = File.read(sample_output_path, mode: Asciidoctor::FILE_READ_MODE)
        refute_empty output
        assert_xpath '/html', output, 1
        assert_xpath '/html/head', output, 1
        assert_xpath '/html/body', output, 1
        assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
        assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'should convert source file specified by pathname and write result to adjacent file by default' do
      sample_input_path = Pathname fixture_path 'sample.adoc'
      sample_output_path = Pathname fixture_path 'sample.html'
      begin
        doc = Asciidoctor.convert_file sample_input_path, safe: :safe
        assert_equal sample_output_path.expand_path.to_s, (doc.attr 'outfile')
        assert sample_output_path.file?
        output = sample_output_path.read mode: Asciidoctor::FILE_READ_MODE
        refute_empty output
        assert_xpath '/html', output, 1
        assert_xpath '/html/head', output, 1
        assert_xpath '/html/body', output, 1
        assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
        assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
      ensure
        sample_output_path.delete
      end
    end

    test 'should convert source file and write to specified file' do
      sample_input_path = fixture_path('sample.adoc')
      sample_output_path = fixture_path('result.html')
      begin
        Asciidoctor.convert_file sample_input_path, to_file: sample_output_path
        assert File.exist?(sample_output_path)
        output = File.read(sample_output_path, mode: Asciidoctor::FILE_READ_MODE)
        refute_empty output
        assert_xpath '/html', output, 1
        assert_xpath '/html/head', output, 1
        assert_xpath '/html/body', output, 1
        assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
        assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'should convert source file and write to specified file in base_dir' do
      sample_input_path = fixture_path('sample.adoc')
      sample_output_path = fixture_path('result.html')
      fixture_dir = fixture_path('')
      begin
        Asciidoctor.convert_file sample_input_path, to_file: 'result.html', base_dir: fixture_dir
        assert File.exist?(sample_output_path)
        output = File.read(sample_output_path, mode: Asciidoctor::FILE_READ_MODE)
        refute_empty output
        assert_xpath '/html', output, 1
        assert_xpath '/html/head', output, 1
        assert_xpath '/html/body', output, 1
        assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
        assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
      rescue => e
        flunk e.message
      ensure
        FileUtils.rm(sample_output_path, force: true)
      end
    end

    test 'should resolve :to_dir option correctly when both :to_dir and :to_file options are set to an absolute path' do
      begin
        sample_input_path = fixture_path 'sample.adoc'
        sample_output_file = Tempfile.new %w(out- .html)
        sample_output_path = sample_output_file.path
        sample_output_dir = File.dirname sample_output_path
        sample_output_file.close
        doc = Asciidoctor.convert_file sample_input_path, to_file: sample_output_path, to_dir: sample_output_dir, safe: :unsafe
        assert File.exist? sample_output_path
        assert_equal sample_output_path, doc.options[:to_file]
        assert_equal sample_output_dir, doc.options[:to_dir]
      ensure
        sample_output_file.close!
      end
    end

    test 'in_place option is ignored when to_file is specified' do
      sample_input_path = fixture_path('sample.adoc')
      sample_output_path = fixture_path('result.html')
      begin
        Asciidoctor.convert_file sample_input_path, to_file: sample_output_path, in_place: true
        assert File.exist?(sample_output_path)
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
      end
    end

    test 'in_place option is ignored when to_dir is specified' do
      sample_input_path = fixture_path('sample.adoc')
      sample_output_path = fixture_path('sample.html')
      begin
        Asciidoctor.convert_file sample_input_path, to_dir: File.dirname(sample_output_path), in_place: true
        assert File.exist?(sample_output_path)
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
      end
    end

    test 'should set outfilesuffix to match file extension of target file' do
      sample_input = '{outfilesuffix}'
      sample_output_path = fixture_path('result.htm')
      begin
        Asciidoctor.convert sample_input, to_file: sample_output_path
        assert File.exist?(sample_output_path)
        output = File.read(sample_output_path, mode: Asciidoctor::FILE_READ_MODE)
        refute_empty output
        assert_include '<p>.htm</p>', output
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'should respect outfilesuffix soft set from API' do
      sample_input_path = fixture_path('sample.adoc')
      sample_output_path = fixture_path('sample.htm')
      begin
        Asciidoctor.convert_file sample_input_path, to_dir: (File.dirname sample_input_path), attributes: { 'outfilesuffix' => '.htm@' }
        assert File.exist?(sample_output_path)
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'output should be relative to to_dir option' do
      sample_input_path = fixture_path('sample.adoc')
      output_dir = File.join(File.dirname(sample_input_path), 'test_output')
      Dir.mkdir output_dir unless File.exist? output_dir
      sample_output_path = File.join(output_dir, 'sample.html')
      begin
        Asciidoctor.convert_file sample_input_path, to_dir: output_dir
        assert File.exist? sample_output_path
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
        FileUtils.rmdir output_dir
      end
    end

    test 'missing directories should be created if mkdirs is enabled' do
      sample_input_path = fixture_path('sample.adoc')
      output_dir = File.join(File.join(File.dirname(sample_input_path), 'test_output'), 'subdir')
      sample_output_path = File.join(output_dir, 'sample.html')
      begin
        Asciidoctor.convert_file sample_input_path, to_dir: output_dir, mkdirs: true
        assert File.exist? sample_output_path
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
        FileUtils.rmdir output_dir
        FileUtils.rmdir File.dirname(output_dir)
      end
    end

    # TODO need similar test for when to_dir is specified
    test 'should raise exception if an attempt is made to overwrite input file' do
      sample_input_path = fixture_path('sample.adoc')

      assert_raises IOError do
        Asciidoctor.convert_file sample_input_path, attributes: { 'outfilesuffix' => '.adoc' }
      end
    end

    test 'to_file should be relative to to_dir when both given' do
      sample_input_path = fixture_path('sample.adoc')
      base_dir = File.dirname(sample_input_path)
      sample_rel_output_path = File.join('test_output', 'result.html')
      output_dir = File.dirname(File.join(base_dir, sample_rel_output_path))
      Dir.mkdir output_dir unless File.exist? output_dir
      sample_output_path = File.join(base_dir, sample_rel_output_path)
      begin
        Asciidoctor.convert_file sample_input_path, to_dir: base_dir, to_file: sample_rel_output_path
        assert File.exist? sample_output_path
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
        FileUtils.rmdir output_dir
      end
    end

    test 'should not modify options argument' do
      options = {
        safe: Asciidoctor::SafeMode::SAFE,
        to_file: false,
      }
      options.freeze
      sample_input_path = fixture_path('sample.adoc')
      begin
        Asciidoctor.convert_file sample_input_path, options
      rescue
        flunk %(options argument should not be modified)
      end
    end

    test 'should set to_dir option to parent directory of specified output file' do
      sample_input_path = fixture_path 'basic.adoc'
      sample_output_path = fixture_path 'basic.html'
      begin
        doc = Asciidoctor.convert_file sample_input_path, to_file: sample_output_path
        assert_equal File.dirname(sample_output_path), doc.options[:to_dir]
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'should set to_dir option to parent directory of specified output directory and file' do
      sample_input_path = fixture_path 'basic.adoc'
      sample_output_path = fixture_path 'basic.html'
      fixture_base_path = File.dirname sample_output_path
      fixture_parent_path = File.dirname fixture_base_path
      sample_output_relpath = File.join 'fixtures', 'basic.html'
      begin
        doc = Asciidoctor.convert_file sample_input_path, to_dir: fixture_parent_path, to_file: sample_output_relpath
        assert_equal fixture_base_path, doc.options[:to_dir]
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'timings are recorded for each step' do
      sample_input_path = fixture_path 'asciidoc_index.txt'
      Asciidoctor.convert_file sample_input_path, timings: (timings = Asciidoctor::Timings.new), to_file: false
      refute_equal '0.00000', '%05.5f' % timings.read_parse.to_f
      refute_equal '0.00000', '%05.5f' % timings.convert.to_f
      refute_equal timings.read_parse, timings.total
    end

    test 'can override syntax highlighter using syntax_highlighters option' do
      syntax_hl = Class.new Asciidoctor::SyntaxHighlighter::Base do
        def highlight?
          true
        end

        def highlight node, source, lang, opts
          'highlighted'
        end
      end
      input = <<~'EOS'
      [source,ruby]
      ----
      puts 'Hello, World!'
      ----
      EOS
      output = Asciidoctor.convert input, safe: :safe, syntax_highlighters: { 'coderay' => syntax_hl }, attributes: { 'source-highlighter' => 'coderay' }
      assert_css 'pre.highlight > code[data-lang="ruby"]', output, 1
      assert_xpath '//pre[@class="coderay highlight"]/code[text()="highlighted"]', output, 1
    end
  end

  context 'AST' do
    test 'with no author' do
      input = <<~'EOS'
      = Getting Real: The Smarter, Faster, Easier Way to Build a Successful Web Application

      Getting Real details the business, design, programming, and marketing principles of 37signals.
      EOS

      doc = document_from_string input
      assert_equal 0, doc.authors.size
    end

    test 'with one author' do
      input = <<~'EOS'
      = Getting Real: The Smarter, Faster, Easier Way to Build a Successful Web Application
      David Heinemeier Hansson <david@37signals.com>

      Getting Real details the business, design, programming, and marketing principles of 37signals.
      EOS

      doc = document_from_string input
      authors = doc.authors
      assert_equal 1, authors.size
      author_1 = authors[0]
      assert_equal 'david@37signals.com', author_1.email
      assert_equal 'David Heinemeier Hansson', author_1.name
      assert_equal 'David', author_1.firstname
      assert_equal 'Heinemeier', author_1.middlename
      assert_equal 'Hansson', author_1.lastname
      assert_equal 'DHH', author_1.initials
    end

    test 'with two authors' do
      input = <<~'EOS'
      = Getting Real: The Smarter, Faster, Easier Way to Build a Successful Web Application
      David Heinemeier Hansson <david@37signals.com>; Jason Fried <jason@37signals.com>

      Getting Real details the business, design, programming, and marketing principles of 37signals.
      EOS

      doc = document_from_string input
      authors = doc.authors
      assert_equal 2, authors.size
      author_1 = authors[0]
      assert_equal 'david@37signals.com', author_1.email
      assert_equal 'David Heinemeier Hansson', author_1.name
      assert_equal 'David', author_1.firstname
      assert_equal 'Heinemeier', author_1.middlename
      assert_equal 'Hansson', author_1.lastname
      assert_equal 'DHH', author_1.initials
      author_2 = authors[1]
      assert_equal 'jason@37signals.com', author_2.email
      assert_equal 'Jason Fried', author_2.name
      assert_equal 'Jason', author_2.firstname
      assert_nil author_2.middlename
      assert_equal 'Fried', author_2.lastname
      assert_equal 'JF', author_2.initials
    end

    test 'with authors as attributes' do
      input = <<~'EOS'
      = Getting Real: The Smarter, Faster, Easier Way to Build a Successful Web Application
      :author_1: David Heinemeier Hansson
      :email_1: david@37signals.com
      :author_2: Jason Fried
      :email_2: jason@37signals.com

      Getting Real details the business, design, programming, and marketing principles of 37signals.
      EOS

      doc = document_from_string input
      authors = doc.authors
      assert_equal 2, authors.size
      author_1 = authors[0]
      assert_equal 'david@37signals.com', author_1.email
      assert_equal 'David Heinemeier Hansson', author_1.name
      assert_equal 'David', author_1.firstname
      assert_equal 'Heinemeier', author_1.middlename
      assert_equal 'Hansson', author_1.lastname
      assert_equal 'DHH', author_1.initials
      author_2 = authors[1]
      assert_equal 'jason@37signals.com', author_2.email
      assert_equal 'Jason Fried', author_2.name
      assert_equal 'Jason', author_2.firstname
      assert_nil author_2.middlename
      assert_equal 'Fried', author_2.lastname
      assert_equal 'JF', author_2.initials
    end

    test 'should not crash if nil cell text is passed to Cell constructor' do
      input = <<~'EOS'
      |===
      |a
      |===
      EOS
      table = (document_from_string input).blocks[0]
      cell = Asciidoctor::Table::Cell.new table.rows.body[0][0].column, nil
      refute cell.style
      assert_same Asciidoctor::AbstractNode::NORMAL_SUBS, cell.subs
      assert_equal '', cell.text
    end

    test 'should set option on node when set_option is called' do
      input = <<~'EOS'
      . three
      . two
      . one
      EOS

      block = (document_from_string input).blocks[0]
      block.set_option('reversed')
      assert block.option? 'reversed'
      assert_equal '', block.attributes['reversed-option']
    end

    test 'enabled_options should return all options which are set' do
      input = <<~'EOS'
      [%interactive]
      * [x] code
      * [ ] test
      * [ ] profit
      EOS

      block = (document_from_string input).blocks[0]
      assert_equal %w(checklist interactive).to_set, block.enabled_options
    end

    test 'should append option to existing options' do
      input = <<~'EOS'
      [%fancy]
      . three
      . two
      . one
      EOS

      block = (document_from_string input).blocks[0]
      block.set_option('reversed')
      assert block.option? 'fancy'
      assert block.option? 'reversed'
    end

    test 'should not append option if option is already set' do
      input = <<~'EOS'
      [%reversed]
      . three
      . two
      . one
      EOS

      block = (document_from_string input).blocks[0]
      refute block.set_option('reversed')
      assert_equal '', block.attributes['reversed-option']
    end

    test 'should return set of option names' do
      input = <<~'EOS'
      [%compact%reversed]
      . three
      . two
      . one
      EOS

      block = (document_from_string input).blocks[0]
      assert_equal %w(compact reversed).to_set, block.enabled_options
    end

    test 'table column should not be a block or inline' do
      input = <<~'EOS'
      |===
      |a
      |===
      EOS

      col = (document_from_string input).blocks[0].columns[0]
      refute col.block?
      refute col.inline?
    end

    test 'table cell should be a block' do
      input = <<~'EOS'
      |===
      |a
      |===
      EOS

      cell = (document_from_string input).blocks[0].rows.body[0][0]
      assert_kind_of ::Asciidoctor::AbstractBlock, cell
      assert cell.block?
      refute cell.inline?
    end

    test 'next_adjacent_block should return next block' do
      input = <<~'EOS'
      first

      second
      EOS

      doc = document_from_string input
      assert_equal doc.blocks[1], doc.blocks[0].next_adjacent_block
    end

    test 'next_adjacent_block should return next sibling of parent if called on last sibling' do
      input = <<~'EOS'
      --
      first
      --

      second
      EOS

      doc = document_from_string input
      assert_equal doc.blocks[1], doc.blocks[0].blocks[0].next_adjacent_block
    end

    test 'next_adjacent_block should return next sibling of list if called on last item' do
      input = <<~'EOS'
      * first

      second
      EOS

      doc = document_from_string input
      assert_equal doc.blocks[1], doc.blocks[0].blocks[0].next_adjacent_block
    end

    test 'next_adjacent_block should return next item in dlist if called on last block of list item' do
      input = <<~'EOS'
      first::
      desc
      +
      more desc

      second::
      desc
      EOS

      doc = document_from_string input
      assert_equal doc.blocks[0].items[1], doc.blocks[0].items[0][1].blocks[0].next_adjacent_block
    end
  end
end
