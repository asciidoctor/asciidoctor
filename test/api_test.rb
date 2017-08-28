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

    test 'should track file and line information with blocks if sourcemap option is set' do
      doc = Asciidoctor.load_file fixture_path('sample.asciidoc'), :sourcemap => true

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

      last_block = section_2.blocks[-1]
      assert_equal :ulist, last_block.context
      refute_nil last_block.source_location
      assert_equal 'sample.asciidoc', last_block.file
      assert_equal 23, last_block.lineno

      doc = Asciidoctor.load_file fixture_path('master.adoc'), :sourcemap => true, :safe => :safe

      section_1 = doc.sections[0]
      assert_equal 'Chapter A', section_1.title
      refute_nil section_1.source_location
      assert_equal fixture_path('chapter-a.adoc'), section_1.file
      assert_equal 1, section_1.lineno
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
  end
  
  context 'Convert' do
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

      output = Asciidoctor.render(input, :safe => Asciidoctor::SafeMode::SERVER, :header_footer => true)
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 0
      stylenode = xmlnodes_at_css 'html:root > head > style', output, 1
      styles = stylenode.content
      refute_nil styles
      refute_empty styles.strip
    end

    test 'should link to default stylesheet by default even if linkcss is unset in document' do
      input = <<-EOS
= Document Title
:linkcss!:

text
      EOS

      output = Asciidoctor.render(input, :header_footer => true)
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 1
    end

    test 'should link to default stylesheet by default if linkcss is unset' do
      input = <<-EOS
= Document Title

text
      EOS

      output = Asciidoctor.render(input, :header_footer => true, :attributes => {'linkcss!' => ''})
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 1
      assert_css 'html:root > head > link[rel="stylesheet"][href="./asciidoctor.css"]', output, 1
    end

    test 'should embed default stylesheet if safe mode is less than secure and linkcss is unset' do
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

      output = Asciidoctor.render(input, :header_footer => true, :attributes => {'stylesheet!' => ''})
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 0
      assert_css 'html:root > head > link[rel="stylesheet"]', output, 0
    end

    test 'should link to custom stylesheet if specified in stylesheet attribute' do
      input = <<-EOS
= Document Title

text
      EOS

      output = Asciidoctor.render(input, :header_footer => true, :attributes => {'stylesheet' => './custom.css'})
      assert_css 'html:root > head > link[rel="stylesheet"][href^="https://fonts.googleapis.com"]', output, 0
      assert_css 'html:root > head > link[rel="stylesheet"][href="./custom.css"]', output, 1

      output = Asciidoctor.render(input, :header_footer => true, :attributes => {'stylesheet' => 'file:///home/username/custom.css'})
      assert_css 'html:root > head > link[rel="stylesheet"][href="file:///home/username/custom.css"]', output, 1
    end

    test 'should resolve custom stylesheet relative to stylesdir' do
      input = <<-EOS
= Document Title

text
      EOS

      output = Asciidoctor.render(input, :header_footer => true, :attributes => {'stylesheet' => 'custom.css', 'stylesdir' => './stylesheets'})
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
        # FIXME we shouldn't need unsafe here since combined file is within jail
        doc = Asciidoctor.convert_file sample_input_path, :to_dir => fixture_parent_path, :to_file => sample_output_relpath, :safe => :unsafe
        assert_equal fixture_base_path, doc.options[:to_dir]
      ensure
        FileUtils.rm(sample_output_path)
      end
    end
  end
end
