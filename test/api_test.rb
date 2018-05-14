# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context 'API' do
  context 'Load' do
    test 'should load input file' do
      sample_input_path = fixture_path('sample.asciidoc')
      doc = File.open(sample_input_path) {|file| Asciidoctor.load file, :safe => Asciidoctor::SafeMode::SAFE }
      assert_equal 'Document Title', doc.doctitle
      assert_equal File.expand_path(sample_input_path), doc.attr('docfile')
      assert_equal File.expand_path(File.dirname(sample_input_path)), doc.attr('docdir')
      assert_equal '.asciidoc', doc.attr('docfilesuffix')
    end

    test 'should load input file from filename' do
      sample_input_path = fixture_path('sample.asciidoc')
      doc = Asciidoctor.load_file(sample_input_path, :safe => Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      assert_equal File.expand_path(sample_input_path), doc.attr('docfile')
      assert_equal File.expand_path(File.dirname(sample_input_path)), doc.attr('docdir')
      assert_equal '.asciidoc', doc.attr('docfilesuffix')
    end

    test 'should not load invalid file' do
      sample_input_path = fixture_path('hello-asciidoctor.pdf')
      exception = assert_raises ArgumentError do
        Asciidoctor.load_file(sample_input_path, :safe => Asciidoctor::SafeMode::SAFE)
      end
      assert_match(/Failed to load AsciiDoc document/, exception.message)
      # verify we have the correct backtrace (should be in at least first 5 lines)
      assert_match((RUBY_ENGINE == 'rbx' ? /parser\.rb/ : /helpers\.rb/), exception.backtrace[0..4].join("\n"))
    end if RUBY_MIN_VERSION_1_9

    test 'should load input IO' do
      input = StringIO.new(<<-EOS)
Document Title
==============

preamble
      EOS
      doc = Asciidoctor.load(input, :safe => Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      refute doc.attr?('docfile')
      assert_equal doc.base_dir, doc.attr('docdir')
    end

    test 'should load input string' do
      input = <<-EOS
Document Title
==============

preamble
      EOS
      doc = Asciidoctor.load(input, :safe => Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      refute doc.attr?('docfile')
      assert_equal doc.base_dir, doc.attr('docdir')
    end

    test 'should load input string array' do
      input = <<-EOS
Document Title
==============

preamble
      EOS
      doc = Asciidoctor.load(input.lines.entries, :safe => Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      refute doc.attr?('docfile')
      assert_equal doc.base_dir, doc.attr('docdir')
    end

    test 'should accept attributes as array' do
	  # NOTE there's a tab character before idseparator
      doc = Asciidoctor.load('text', :attributes => %w(toc sectnums   source-highlighter=coderay idprefix	idseparator=-))
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
      doc = Asciidoctor.load('text', :attributes => [])
      assert_kind_of Hash, doc.attributes
    end

    test 'should accept attributes as string' do
      doc = Asciidoctor.load('text', :attributes => 'toc sectnums
source-highlighter=coderay
idprefix
idseparator=-')
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
      doc = Asciidoctor.load('text', :attributes => %(idprefix idseparator=-   note-caption=Note\\ to\\\tself toc))
      assert_kind_of Hash, doc.attributes
      assert doc.attr?('idprefix')
      assert_equal '', doc.attr('idprefix')
      assert doc.attr?('idseparator')
      assert_equal '-', doc.attr('idseparator')
      assert doc.attr?('note-caption')
      assert_equal "Note to\tself", doc.attr('note-caption')
    end

    test 'should accept attributes as empty string' do
      doc = Asciidoctor.load('text', :attributes => '')
      assert_kind_of Hash, doc.attributes
    end

    test 'should accept attributes as nil' do
      doc = Asciidoctor.load('text', :attributes => nil)
      assert_kind_of Hash, doc.attributes
    end

    test 'should accept attributes if hash like' do
      class Hashish
        def initialize
          @table = {'toc' => ''}
        end

        def keys
          @table.keys
        end

        def [](key)
          @table[key]
        end
      end

      doc = Asciidoctor.load('text', :attributes => Hashish.new)
      assert_kind_of Hash, doc.attributes
      assert doc.attributes.has_key?('toc')
    end

    test 'should not expand value of docdir attribute if specified via API' do
      docdir = 'virtual/directory'
      doc = document_from_string '', :safe => :safe, :attributes => { 'docdir' => docdir }
      assert_equal docdir, (doc.attr 'docdir')
      assert_equal docdir, doc.base_dir
    end

    test 'converts block to output format when convert is called' do
      doc = Asciidoctor.load 'paragraph text'
      expected = <<-EOS
<div class="paragraph">
<p>paragraph text</p>
</div>
      EOS
      assert_equal 1, doc.blocks.length
      assert_equal :paragraph, doc.blocks[0].context
      assert_equal expected.chomp, doc.blocks[0].convert
    end

    test 'render method on node is aliased to convert method' do
      input = <<-EOS
paragraph text

* list item
      EOS
      doc = Asciidoctor.load input
      assert_equal 2, doc.blocks.length
      ([doc] + doc.blocks).each do |block|
        assert_equal block.method(:convert), block.method(:render)
      end
      inline = Asciidoctor::Inline.new doc.blocks[0], :image, nil, :type => 'image', :target => 'tiger.png'
      assert_equal inline.method(:convert), inline.method(:render)
    end

    test 'should output timestamps by default' do
      doc = document_from_string 'text', :backend => :html5, :attributes => nil
      result = doc.convert
      assert doc.attr?('docdate')
      refute doc.attr? 'reproducible'
      assert_xpath '//div[@id="footer-text" and contains(string(.//text()), "Last updated")]', result, 1
    end

    test 'should not output timestamps if reproducible attribute is set in HTML 5' do
      doc = document_from_string 'text', :backend => :html5, :attributes => { 'reproducible' => '' }
      result = doc.convert
      assert doc.attr?('docdate')
      assert doc.attr?('reproducible')
      assert_xpath '//div[@id="footer-text" and contains(string(.//text()), "Last updated")]', result, 0
    end

    test 'should not output timestamps if reproducible attribute is set in DocBook' do
      doc = document_from_string 'text', :backend => :docbook, :attributes => { 'reproducible' => '' }
      result = doc.convert
      assert doc.attr?('docdate')
      assert doc.attr?('reproducible')
      assert_xpath '/article/info/date', result, 0
    end

    test 'should not modify options argument' do
      options = {
        :safe => Asciidoctor::SafeMode::SAFE
      }
      options.freeze
      sample_input_path = fixture_path('sample.asciidoc')
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
        :safe => Asciidoctor::SafeMode::SAFE,
        :attributes => attributes
      }
      sample_input_path = fixture_path('sample.asciidoc')
      begin
        Asciidoctor.load_file sample_input_path, options
      rescue
        flunk %(attributes argument should not be modified)
      end
    end

    test 'should be able to restore header attributes after call to convert' do
      input = <<-EOS
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
      doc = Asciidoctor.load_file fixture_path('sample.asciidoc'), :sourcemap => true

      refute_nil doc.source_location
      assert_equal 'sample.asciidoc', doc.file
      assert_equal 1, doc.lineno

      section_1 = doc.sections[0]
      assert_equal 'Section A', section_1.title
      refute_nil section_1.source_location
      assert_equal 'sample.asciidoc', section_1.file
      assert_equal 10, section_1.lineno

      section_2 = doc.sections[1]
      assert_equal 'Section B', section_2.title
      refute_nil section_2.source_location
      assert_equal 'sample.asciidoc', section_2.file
      assert_equal 18, section_2.lineno

      table_block = section_2.blocks[1]
      assert_equal :table, table_block.context
      refute_nil table_block.source_location
      assert_equal 'sample.asciidoc', table_block.file
      assert_equal 22, table_block.lineno
      first_cell = table_block.rows.body[0][0]
      refute_nil first_cell.source_location
      assert_equal 'sample.asciidoc', first_cell.file
      assert_equal 23, first_cell.lineno
      second_cell = table_block.rows.body[0][1]
      refute_nil second_cell.source_location
      assert_equal 'sample.asciidoc', second_cell.file
      assert_equal 23, second_cell.lineno
      last_cell = table_block.rows.body[-1][-1]
      refute_nil last_cell.source_location
      assert_equal 'sample.asciidoc', last_cell.file
      assert_equal 24, last_cell.lineno

      last_block = section_2.blocks[-1]
      assert_equal :ulist, last_block.context
      refute_nil last_block.source_location
      assert_equal 'sample.asciidoc', last_block.file
      assert_equal 28, last_block.lineno

      list_items = last_block.blocks
      refute_nil list_items[0].source_location
      assert_equal 'sample.asciidoc', list_items[0].file
      assert_equal 28, list_items[0].lineno

      refute_nil list_items[1].source_location
      assert_equal 'sample.asciidoc', list_items[1].file
      assert_equal 29, list_items[1].lineno

      refute_nil list_items[2].source_location
      assert_equal 'sample.asciidoc', list_items[2].file
      assert_equal 30, list_items[2].lineno

      doc = Asciidoctor.load_file fixture_path('master.adoc'), :sourcemap => true, :safe => :safe

      section_1 = doc.sections[0]
      assert_equal 'Chapter A', section_1.title
      refute_nil section_1.source_location
      assert_equal fixture_path('chapter-a.adoc'), section_1.file
      assert_equal 1, section_1.lineno
    end

    test 'should track file and line information on list items if sourcemap option is set' do
      doc = Asciidoctor.load_file fixture_path('lists.adoc'), :sourcemap => true

      first_section = doc.blocks[1]

      unordered_basic_list = first_section.blocks[0]
      assert_equal 11, unordered_basic_list.lineno

      unordered_basic_list_items = unordered_basic_list.find_by :context => :list_item
      assert_equal 11, unordered_basic_list_items[0].lineno
      assert_equal 12, unordered_basic_list_items[1].lineno
      assert_equal 13, unordered_basic_list_items[2].lineno

      unordered_max_nesting = first_section.blocks[1]
      assert_equal 16, unordered_max_nesting.lineno
      unordered_max_nesting_items = unordered_max_nesting.find_by :context => :list_item
      assert_equal 16, unordered_max_nesting_items[0].lineno
      assert_equal 17, unordered_max_nesting_items[1].lineno
      assert_equal 18, unordered_max_nesting_items[2].lineno
      assert_equal 19, unordered_max_nesting_items[3].lineno
      assert_equal 20, unordered_max_nesting_items[4].lineno
      assert_equal 21, unordered_max_nesting_items[5].lineno

      checklist = first_section.blocks[2]
      assert_equal 24, checklist.lineno
      checklist_list_items = checklist.find_by :context => :list_item
      assert_equal 24, checklist_list_items[0].lineno
      assert_equal 25, checklist_list_items[1].lineno
      assert_equal 26, checklist_list_items[2].lineno
      assert_equal 27, checklist_list_items[3].lineno

      ordered_basic = first_section.blocks[3]
      assert_equal 30, ordered_basic.lineno
      ordered_basic_list_items = ordered_basic.find_by :context => :list_item
      assert_equal 30, ordered_basic_list_items[0].lineno
      assert_equal 31, ordered_basic_list_items[1].lineno
      assert_equal 32, ordered_basic_list_items[2].lineno

      ordered_nested = first_section.blocks[4]
      assert_equal 35, ordered_nested.lineno
      ordered_nested_list_items = ordered_nested.find_by :context => :list_item
      assert_equal 35, ordered_nested_list_items[0].lineno
      assert_equal 36, ordered_nested_list_items[1].lineno
      assert_equal 37, ordered_nested_list_items[2].lineno
      assert_equal 38, ordered_nested_list_items[3].lineno
      assert_equal 39, ordered_nested_list_items[4].lineno

      ordered_max_nesting = first_section.blocks[5]
      assert_equal 42, ordered_max_nesting.lineno
      ordered_max_nesting_items = ordered_max_nesting.find_by :context => :list_item
      assert_equal 42, ordered_max_nesting_items[0].lineno
      assert_equal 43, ordered_max_nesting_items[1].lineno
      assert_equal 44, ordered_max_nesting_items[2].lineno
      assert_equal 45, ordered_max_nesting_items[3].lineno
      assert_equal 46, ordered_max_nesting_items[4].lineno
      assert_equal 47, ordered_max_nesting_items[5].lineno

      labeled_singleline = first_section.blocks[6]
      assert_equal 50, labeled_singleline.lineno
      labeled_singleline_items = labeled_singleline.find_by :context => :list_item
      assert_equal 50, labeled_singleline_items[0].lineno
      assert_equal 50, labeled_singleline_items[1].lineno
      assert_equal 51, labeled_singleline_items[2].lineno
      assert_equal 51, labeled_singleline_items[3].lineno

      labeled_multiline = first_section.blocks[7]
      assert_equal 54, labeled_multiline.lineno
      labeled_multiline_items = labeled_multiline.find_by :context => :list_item
      assert_equal 54, labeled_multiline_items[0].lineno
      assert_equal 55, labeled_multiline_items[1].lineno
      assert_equal 56, labeled_multiline_items[2].lineno
      assert_equal 57, labeled_multiline_items[3].lineno

      qanda = first_section.blocks[8]
      assert_equal 61, qanda.lineno
      qanda_items = qanda.find_by :context => :list_item
      assert_equal 61, qanda_items[0].lineno
      assert_equal 62, qanda_items[1].lineno
      assert_equal 63, qanda_items[2].lineno
      assert_equal 63, qanda_items[3].lineno

      mixed = first_section.blocks[9]
      assert_equal 66, mixed.lineno
      mixed_items = mixed.find_by(:context => :list_item) {|block| block.text? }
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
      unordered_complex_items = unordered_complex_list.find_by :context => :list_item
      assert_equal 86, unordered_complex_items[0].lineno
      assert_equal 87, unordered_complex_items[1].lineno
      assert_equal 88, unordered_complex_items[2].lineno
      assert_equal 92, unordered_complex_items[3].lineno
      assert_equal 96, unordered_complex_items[4].lineno
    end

    test 'should assign correct source location if section occurs on last line of input' do
      input = <<-EOS
= Document Title

== Section A

content

== Section B
      EOS

      doc = document_from_string input, :sourcemap => true
      assert_equal [1, 3, 7], (doc.find_by :context => :section).map(&:lineno)
    end

    test 'should allow sourcemap option on document to be modified' do
      doc = Asciidoctor.load_file fixture_path('sample.asciidoc'), :parse => false
      doc.sourcemap = true
      doc = doc.parse

      section_1 = doc.sections[0]
      assert_equal 'Section A', section_1.title
      refute_nil section_1.source_location
      assert_equal 'sample.asciidoc', section_1.file
      assert_equal 10, section_1.lineno
    end

    test 'find_by should return Array of blocks anywhere in document tree that match criteria' do
      input = <<-EOS
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
      result = doc.find_by :context => :image
      assert_equal 2, result.size
      assert_equal :image, result[0].context
      assert_equal 'tiger.png', result[0].attr('target')
      assert_equal :image, result[1].context
      assert_equal 'shoe.png', result[1].attr('target')
    end

    test 'find_by should return an empty Array if no matches are found' do
      input = <<-EOS
paragraph
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by :context => :section
      refute_nil result
      assert_equal 0, result.size
    end

    test 'find_by should return Array of blocks that match style criteria' do
      input = <<-EOS
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
      result = doc.find_by :context => :ulist, :style => 'square'
      assert_equal 1, result.size
      assert_equal :ulist, result[0].context
    end

    test 'find_by should return Array of blocks that match role criteria' do
      input = <<-EOS
[#tiger.animal]
image::tiger.png[Tiger]

image::shoe.png[Shoe]
      EOS

      doc = Asciidoctor.load input
      result = doc.find_by :context => :image, :role => 'animal'
      assert_equal 1, result.size
      assert_equal :image, result[0].context
      assert_equal 'tiger.png', result[0].attr('target')
    end

    test 'find_by should return the document title section if context selector is :section' do
      input = <<-EOS
= Document Title

preamble

== Section One

content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by :context => :section
      refute_nil result
      assert_equal 2, result.size
      assert_equal :section, result[0].context
      assert_equal 'Document Title', result[0].title
    end

    test 'find_by should only return results for which the block argument yields true' do
      input = <<-EOS
== Section

content

=== Subsection

content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by(:context => :section) {|sect| sect.level == 1 }
      refute_nil result
      assert_equal 1, result.size
      assert_equal :section, result[0].context
      assert_equal 'Section', result[0].title
    end

    test 'find_by should only return one result when matching by id' do
      input = <<-EOS
== Section

content

[#subsection]
=== Subsection

content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by(:context => :section, :id => 'subsection')
      refute_nil result
      assert_equal 1, result.size
      assert_equal :section, result[0].context
      assert_equal 'Subsection', result[0].title
    end

    test 'find_by should return an empty Array if the id criteria matches but the block argument yields false' do
      input = <<-EOS
== Section

content

[#subsection]
=== Subsection

content
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by(:context => :section, :id => 'subsection') {|sect| false }
      refute_nil result
      assert_equal 0, result.size
    end

    test 'find_by should not crash if dlist entry does not have description' do
      input = <<-EOS
term without description::
      EOS
      doc = Asciidoctor.load input
      result = doc.find_by
      refute_nil result
      assert_equal 3, result.size
      assert_kind_of Asciidoctor::Document, result[0]
      assert_kind_of Asciidoctor::List, result[1]
      assert_kind_of Asciidoctor::ListItem, result[2]
    end

    test 'timings are recorded for each step when load and convert are called separately' do
      sample_input_path = fixture_path 'asciidoc_index.txt'
      (Asciidoctor.load_file sample_input_path, :timings => (timings = Asciidoctor::Timings.new)).convert
      refute_equal '0.00000', '%05.5f' % timings.read_parse.to_f
      refute_equal '0.00000', '%05.5f' % timings.convert.to_f
      refute_equal timings.read_parse, timings.total
    end
  end

  context 'Convert' do
    test 'render_file is aliased to convert_file' do
      assert_equal Asciidoctor.method(:convert_file), Asciidoctor.method(:render_file)
    end

    test 'render is aliased to convert' do
      assert_equal Asciidoctor.method(:convert), Asciidoctor.method(:render)
    end

    test 'should convert source document to string when to_file is false' do
      sample_input_path = fixture_path('sample.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :header_footer => true, :to_file => false
      refute_empty output
      assert_xpath '/html', output, 1
      assert_xpath '/html/head', output, 1
      assert_xpath '/html/body', output, 1
      assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
      assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
    end

    test 'lines in output should be separated by line feed' do
      sample_input_path = fixture_path('sample.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :header_footer => true, :to_file => false
      refute_empty output
      lines = output.split("\n")
      assert_equal lines.size, output.split(/\r\n|\r|\n/).size
      raw_lengths = lines.map(&:length)
      trimmed_lengths = lines.map {|line| line.rstrip.length }
      assert_equal raw_lengths, trimmed_lengths
    end

    test 'should accept attributes as array' do
      sample_input_path = fixture_path('sample.asciidoc')
      output = Asciidoctor.convert_file sample_input_path, :attributes => %w(sectnums idprefix idseparator=-), :to_file => false
      assert_css '#section-a', output, 1
    end

    test 'should accept attributes as string' do
      sample_input_path = fixture_path('sample.asciidoc')
      output = Asciidoctor.convert_file sample_input_path, :attributes => 'sectnums idprefix idseparator=-', :to_file => false
      assert_css '#section-a', output, 1
    end

    test 'should link to default stylesheet by default when safe mode is SECURE or greater' do
      sample_input_path = fixture_path('basic.asciidoc')
      output = Asciidoctor.convert_file sample_input_path, :header_footer => true, :to_file => false
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 1
    end

    test 'should embed default stylesheet by default if SafeMode is less than SECURE' do
      input = <<-EOS
= Document Title

text
      EOS

      output = Asciidoctor.convert input, :safe => Asciidoctor::SafeMode::SERVER, :header_footer => true
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 0
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
    end

    test 'should not allow linkcss be unset from document if SafeMode is SECURE or greater' do
      input = <<-EOS
= Document Title
:linkcss!:

text
      EOS

      output = Asciidoctor.convert input, :header_footer => true
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 1
    end

    test 'should embed default stylesheet if linkcss is unset from API and SafeMode is SECURE or greater' do
      input = <<-EOS
= Document Title

text
      EOS

      #[{ 'linkcss!' => '' }, { 'linkcss' => nil }, { 'linkcss' => false }].each do |attrs|
      [{ 'linkcss!' => '' }, { 'linkcss' => nil }].each do |attrs|
        output = Asciidoctor.convert input, :header_footer => true, :attributes => attrs
        assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
        assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 0
        stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
        styles = stylenode.content
        refute_nil styles
        refute_empty styles.strip
      end
    end

    test 'should embed default stylesheet if safe mode is less than SECURE and linkcss is unset from API' do
      sample_input_path = fixture_path('basic.asciidoc')
      output = Asciidoctor.convert_file sample_input_path, :header_footer => true, :to_file => false,
          :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'linkcss!' => ''}
      assert_css 'html:root > head > style', output, 1
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
    end

    test 'should not link to stylesheet if stylesheet is unset' do
      input = <<-EOS
= Document Title

text
      EOS

      output = Asciidoctor.convert input, :header_footer => true, :attributes => {'stylesheet!' => ''}
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 0
      assert_css 'html:root > head > link[rel="stylesheet"]', output, 0
    end

    test 'should link to custom stylesheet if specified in stylesheet attribute' do
      input = <<-EOS
= Document Title

text
      EOS

      output = Asciidoctor.convert input, :header_footer => true, :attributes => {'stylesheet' => './custom.css'}
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 0
      assert_css 'html:root > head > link[rel="stylesheet"][href="./custom.css"]', output, 1

      output = Asciidoctor.convert input, :header_footer => true, :attributes => {'stylesheet' => 'file:///home/username/custom.css'}
      assert_css 'html:root > head > link[rel="stylesheet"][href="file:///home/username/custom.css"]', output, 1
    end

    test 'should resolve custom stylesheet relative to stylesdir' do
      input = <<-EOS
= Document Title

text
      EOS

      output = Asciidoctor.convert input, :header_footer => true, :attributes => {'stylesheet' => 'custom.css', 'stylesdir' => './stylesheets'}
      assert_css 'html:root > head > link[rel="stylesheet"][href="./stylesheets/custom.css"]', output, 1
    end

    test 'should resolve custom stylesheet to embed relative to stylesdir' do
      sample_input_path = fixture_path('basic.asciidoc')
      output = Asciidoctor.convert_file sample_input_path, :header_footer => true, :safe => Asciidoctor::SafeMode::SAFE, :to_file => false,
          :attributes => {'stylesheet' => 'custom.css', 'stylesdir' => './stylesheets', 'linkcss!' => ''}
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
    end

    test 'should convert source file and write result to adjacent file by default' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('sample.html')
      begin
        Asciidoctor.convert_file sample_input_path
        assert File.exist?(sample_output_path)
        output = IO.read(sample_output_path)
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

    test 'should convert source file and write to specified file' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('result.html')
      begin
        Asciidoctor.convert_file sample_input_path, :to_file => sample_output_path
        assert File.exist?(sample_output_path)
        output = IO.read(sample_output_path)
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
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('result.html')
      fixture_dir = fixture_path('')
      begin
        Asciidoctor.convert_file sample_input_path, :to_file => 'result.html', :base_dir => fixture_dir
        assert File.exist?(sample_output_path)
        output = IO.read(sample_output_path)
        refute_empty output
        assert_xpath '/html', output, 1
        assert_xpath '/html/head', output, 1
        assert_xpath '/html/body', output, 1
        assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
        assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
      rescue => e
        flunk e.message
      ensure
        FileUtils.rm(sample_output_path, :force => true)
      end
    end

    test 'in_place option is ignored when to_file is specified' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('result.html')
      begin
        Asciidoctor.convert_file sample_input_path, :to_file => sample_output_path, :in_place => true
        assert File.exist?(sample_output_path)
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
      end
    end

    test 'in_place option is ignored when to_dir is specified' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('sample.html')
      begin
        Asciidoctor.convert_file sample_input_path, :to_dir => File.dirname(sample_output_path), :in_place => true
        assert File.exist?(sample_output_path)
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
      end
    end

    test 'should set outfilesuffix to match file extension of target file' do
      sample_input = '{outfilesuffix}'
      sample_output_path = fixture_path('result.htm')
      begin
        Asciidoctor.convert sample_input, :to_file => sample_output_path, :header_footer => false
        assert File.exist?(sample_output_path)
        output = IO.read(sample_output_path)
        refute_empty output
        assert_includes output, '<p>.htm</p>'
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'output should be relative to to_dir option' do
      sample_input_path = fixture_path('sample.asciidoc')
      output_dir = File.join(File.dirname(sample_input_path), 'test_output')
      Dir.mkdir output_dir if !File.exist? output_dir
      sample_output_path = File.join(output_dir, 'sample.html')
      begin
        Asciidoctor.convert_file sample_input_path, :to_dir => output_dir
        assert File.exist? sample_output_path
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
        FileUtils.rmdir output_dir
      end
    end

    test 'missing directories should be created if mkdirs is enabled' do
      sample_input_path = fixture_path('sample.asciidoc')
      output_dir = File.join(File.join(File.dirname(sample_input_path), 'test_output'), 'subdir')
      sample_output_path = File.join(output_dir, 'sample.html')
      begin
        Asciidoctor.convert_file sample_input_path, :to_dir => output_dir, :mkdirs => true
        assert File.exist? sample_output_path
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
        FileUtils.rmdir output_dir
        FileUtils.rmdir File.dirname(output_dir)
      end
    end

    # TODO need similar test for when to_dir is specified
    test 'should raise exception if an attempt is made to overwrite input file' do
      sample_input_path = fixture_path('sample.asciidoc')

      assert_raises IOError do
        Asciidoctor.convert_file sample_input_path, :attributes => { 'outfilesuffix' => '.asciidoc' }
      end
    end

    test 'to_file should be relative to to_dir when both given' do
      sample_input_path = fixture_path('sample.asciidoc')
      base_dir = File.dirname(sample_input_path)
      sample_rel_output_path = File.join('test_output', 'result.html')
      output_dir = File.dirname(File.join(base_dir, sample_rel_output_path))
      Dir.mkdir output_dir if !File.exist? output_dir
      sample_output_path = File.join(base_dir, sample_rel_output_path)
      begin
        Asciidoctor.convert_file sample_input_path, :to_dir => base_dir, :to_file => sample_rel_output_path
        assert File.exist? sample_output_path
      ensure
        FileUtils.rm(sample_output_path) if File.exist? sample_output_path
        FileUtils.rmdir output_dir
      end
    end

    test 'should not modify options argument' do
      options = {
        :safe => Asciidoctor::SafeMode::SAFE,
        :to_file => false
      }
      options.freeze
      sample_input_path = fixture_path('sample.asciidoc')
      begin
        Asciidoctor.convert_file sample_input_path, options
      rescue
        flunk %(options argument should not be modified)
      end
    end

    test 'should set to_dir option to parent directory of specified output file' do
      sample_input_path = fixture_path 'basic.asciidoc'
      sample_output_path = fixture_path 'basic.html'
      begin
        doc = Asciidoctor.convert_file sample_input_path, :to_file => sample_output_path
        assert_equal File.dirname(sample_output_path), doc.options[:to_dir]
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'should set to_dir option to parent directory of specified output directory and file' do
      sample_input_path = fixture_path 'basic.asciidoc'
      sample_output_path = fixture_path 'basic.html'
      fixture_base_path = File.dirname sample_output_path
      fixture_parent_path = File.dirname fixture_base_path
      sample_output_relpath = File.join 'fixtures', 'basic.html'
      begin
        doc = Asciidoctor.convert_file sample_input_path, :to_dir => fixture_parent_path, :to_file => sample_output_relpath
        assert_equal fixture_base_path, doc.options[:to_dir]
      ensure
        FileUtils.rm(sample_output_path)
      end
    end

    test 'timings are recorded for each step' do
      sample_input_path = fixture_path 'asciidoc_index.txt'
      Asciidoctor.convert_file sample_input_path, :timings => (timings = Asciidoctor::Timings.new), :to_file => false
      refute_equal '0.00000', '%05.5f' % timings.read_parse.to_f
      refute_equal '0.00000', '%05.5f' % timings.convert.to_f
      refute_equal timings.read_parse, timings.total
    end
  end

  context 'AST' do
    test 'should not crash if nil cell text is passed to Cell constructor' do
      input = <<-EOS
|===
|a
|===
      EOS
      table = (document_from_string input).blocks[0]
      cell = Asciidoctor::Table::Cell.new table.rows.body[0][0].column, nil, {}
      refute cell.style
      assert_same Asciidoctor::AbstractNode::NORMAL_SUBS, cell.subs
      assert_equal '', cell.text
    end

    test 'should set option on node when set_option is called' do
      input = <<-EOS
. three
. two
. one
      EOS

      block = (document_from_string input).blocks[0]
      assert block.set_option('reversed')
      refute block.set_option('reversed')
      assert block.option?('reversed')
      assert_equal '', block.attributes['reversed-option']
      assert_equal 'reversed', block.attributes['options']
    end

    test 'should append option to existing options' do
      input = <<-EOS
[%fancy]
. three
. two
. one
      EOS

      block = (document_from_string input).blocks[0]
      assert block.set_option('reversed')
      assert_equal 'fancy,reversed', block.attributes['options']
    end

    test 'should not append option if option is already set' do
      input = <<-EOS
[%reversed]
. three
. two
. one
      EOS

      block = (document_from_string input).blocks[0]
      refute block.set_option('reversed')
      assert_equal 'reversed', block.attributes['options']
    end
  end
end
