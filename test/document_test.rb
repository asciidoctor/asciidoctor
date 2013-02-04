require 'test_helper'

context 'Document' do

  context 'Example document' do
    test 'test_title' do
      doc = example_document(:asciidoc_index)
      assert_equal 'AsciiDoc Home Page', doc.doctitle
      assert_equal 'AsciiDoc Home Page', doc.name
      assert_equal 14, doc.blocks.size
      assert_equal :preamble, doc.blocks[0].context
      assert doc.blocks[1].is_a? ::Asciidoctor::Section
    end
  end

  context 'Default settings' do
    test 'safe mode level set to SECURE by default' do
      doc = Asciidoctor::Document.new
      assert_equal Asciidoctor::SafeMode::SECURE, doc.safe
    end

    test 'safe mode level can be set in the constructor' do
      doc = Asciidoctor::Document.new [], :safe => Asciidoctor::SafeMode::SAFE
      assert_equal Asciidoctor::SafeMode::SAFE, doc.safe
    end

    test 'safe model level cannot be modified' do
      doc = Asciidoctor::Document.new
      begin
        doc.safe = Asciidoctor::SafeMode::UNSAFE
        flunk 'safe mode property of Asciidoctor::Document should not be writable!' 
      rescue
      end
    end
  end

  context 'Load APIs' do
    test 'should load input file' do
      sample_input_path = fixture_path('sample.asciidoc')
      doc = Asciidoctor.load(File.new(sample_input_path), :safe => Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      assert_equal File.expand_path(sample_input_path), doc.attr('docfile')
      assert_equal File.expand_path(File.dirname(sample_input_path)), doc.attr('docdir')
    end

    test 'should load input file from filename' do
      sample_input_path = fixture_path('sample.asciidoc')
      doc = Asciidoctor.load_file(sample_input_path, :safe => Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      assert_equal File.expand_path(sample_input_path), doc.attr('docfile')
      assert_equal File.expand_path(File.dirname(sample_input_path)), doc.attr('docdir')
    end

    test 'should load input IO' do
      input = StringIO.new(<<-EOS)
Document Title
==============

preamble
      EOS
      doc = Asciidoctor.load(input, :safe => Asciidoctor::SafeMode::SAFE)
      assert_equal 'Document Title', doc.doctitle
      assert !doc.attr?('docfile')
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
      assert !doc.attr?('docfile')
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
      assert !doc.attr?('docfile')
      assert_equal doc.base_dir, doc.attr('docdir')
    end
  end

  context 'Render APIs' do
    test 'should render document to string' do
      sample_input_path = fixture_path('sample.asciidoc')
      output = Asciidoctor.render_file(sample_input_path, :header_footer => true)
      assert !output.empty?
      assert_xpath '/html', output, 1
      assert_xpath '/html/head', output, 1
      assert_xpath '/html/body', output, 1
      assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
      assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
    end

    test 'should render document in place' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('sample.html')
      begin
        Asciidoctor.render_file(sample_input_path, :in_place => true)
        assert File.exist?(sample_output_path)
        output = File.read(sample_output_path)
        assert !output.empty?
        assert_xpath '/html', output, 1
        assert_xpath '/html/head', output, 1
        assert_xpath '/html/body', output, 1
        assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
        assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
      ensure
        FileUtils::rm(sample_output_path)
      end
    end

    test 'should render document to file' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('result.html')
      begin
        Asciidoctor.render_file(sample_input_path, :to_file => sample_output_path)
        assert File.exist?(sample_output_path)
        output = File.read(sample_output_path)
        assert !output.empty?
        assert_xpath '/html', output, 1
        assert_xpath '/html/head', output, 1
        assert_xpath '/html/body', output, 1
        assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
        assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
      ensure
        FileUtils::rm(sample_output_path)
      end
    end

    test 'in_place option must not be used with to_file option' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('result.html')
      assert_raise ArgumentError do
        begin
          Asciidoctor.render_file(sample_input_path, :to_file => sample_output_path, :in_place => true)
        ensure
          FileUtils::rm(sample_output_path) if File.exists? sample_output_path
        end
      end
    end

    test 'in_place option must not be used with to_dir option' do
      sample_input_path = fixture_path('sample.asciidoc')
      sample_output_path = fixture_path('result.html')
      assert_raise ArgumentError do
        begin
          Asciidoctor.render_file(sample_input_path, :to_dir => '', :in_place => true)
        ensure
          FileUtils::rm(sample_output_path) if File.exists? sample_output_path
        end
      end
    end

    test 'output should be relative to to_dir option' do
      sample_input_path = fixture_path('sample.asciidoc')
      output_dir = File.join(File.dirname(sample_input_path), 'test_output')
      Dir.mkdir output_dir if !File.exists? output_dir
      sample_output_path = File.join(output_dir, 'sample.html')
      begin
        Asciidoctor.render_file(sample_input_path, :to_dir => output_dir)
        assert File.exists? sample_output_path
      ensure
        FileUtils::rm(sample_output_path) if File.exists? sample_output_path
        FileUtils::rmdir output_dir
      end
    end

    test 'missing directories should be created if specified' do
      sample_input_path = fixture_path('sample.asciidoc')
      output_dir = File.join(File.join(File.dirname(sample_input_path), 'test_output'), 'subdir')
      sample_output_path = File.join(output_dir, 'sample.html')
      begin
        Asciidoctor.render_file(sample_input_path, :to_dir => output_dir, :mkdirs => true)
        assert File.exists? sample_output_path
      ensure
        FileUtils::rm(sample_output_path) if File.exists? sample_output_path
        FileUtils::rmdir output_dir
        FileUtils::rmdir File.dirname(output_dir)
      end
    end

    test 'to_file should be relative to to_dir when both given' do
      sample_input_path = fixture_path('sample.asciidoc')
      base_dir = File.dirname(sample_input_path)
      sample_rel_output_path = File.join('test_output', 'result.html')
      output_dir = File.dirname(File.join(base_dir, sample_rel_output_path))
      Dir.mkdir output_dir if !File.exists? output_dir
      sample_output_path = File.join(base_dir, sample_rel_output_path)
      begin
        Asciidoctor.render_file(sample_input_path, :to_dir => base_dir, :to_file => sample_rel_output_path)
        assert File.exists? sample_output_path
      ensure
        FileUtils::rm(sample_output_path) if File.exists? sample_output_path
        FileUtils::rmdir output_dir
      end
    end
  end

  context 'Renderer' do
    test 'built-in HTML5 views are registered by default' do
      doc = document_from_string ''
      assert_equal 'html5', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-html5'
      assert_equal 'html', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-html'
      renderer = doc.renderer
      assert !renderer.nil?
      views = renderer.views
      assert !views.nil?
      assert_equal 29, views.size
      assert views.has_key? 'document'
      assert views['document'].is_a?(Asciidoctor::HTML5::DocumentTemplate)
      assert_equal 'ERB', views['document'].eruby.to_s
    end

    test 'built-in DocBook45 views are registered when backend is docbook45' do
      doc = document_from_string '', :attributes => {'backend' => 'docbook45'}
      renderer = doc.renderer
      assert_equal 'docbook45', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-docbook45'
      assert_equal 'docbook', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-docbook'
      assert !renderer.nil?
      views = renderer.views
      assert !views.nil?
      assert_equal 29, views.size
      assert views.has_key? 'document'
      assert views['document'].is_a?(Asciidoctor::DocBook45::DocumentTemplate)
      assert_equal 'ERB', views['document'].eruby.to_s
    end
  
    test 'can set erubis as eRuby implementation' do
      doc = Asciidoctor::Document.new [], :eruby => 'erubis', :header_footer => true
      assert $LOADED_FEATURES.detect {|p| p == 'erubis.rb' || p.end_with?('/erubis.rb') }.nil?
      renderer = doc.renderer
      assert $LOADED_FEATURES.detect {|p| p == 'erubis.rb' || p.end_with?('/erubis.rb') }
      views = renderer.views
      assert !views.nil?
      assert views.has_key? 'document'
      assert_equal 'Erubis::FastEruby', views['document'].eruby.to_s
      assert_equal 'Erubis::FastEruby', views['document'].template.class.to_s
    end
  end

  context 'Structure' do
    test 'test_with_no_title' do
      doc = document_from_string('Snorf')
      assert_nil doc.doctitle
      assert_nil doc.name
      assert !doc.has_header?
      assert_nil doc.header
    end

    test 'test_with_explicit_title' do
     input = <<-EOS
= Title
:title: Document Title

preamble

== First Section
     EOS
     doc = document_from_string input
     assert_equal 'Document Title', doc.doctitle
     assert_equal 'Document Title', doc.title
     assert doc.has_header?
     assert_equal 'Title', doc.header.title
     assert_equal 'Title', doc.first_section.title
    end

    test 'should recognize document title when preceded by blank lines' do
      input = <<-EOS
:doctype: book

= Title

preamble

== Section 1

text
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_css '#header h1', output, 1
      assert_css '#content h1', output, 0
    end
     
    test 'test_empty_document' do
      doc = document_from_string('')
      assert doc.blocks.empty?
      assert_nil doc.doctitle
      assert !doc.has_header?
      assert_nil doc.header
    end

    test 'test_with_metadata' do
      input = <<-EOS
= AsciiDoc
Stuart Rackham <founder@asciidoc.org>
v8.6.8, 2012-07-12: See changelog.

== Version 8.6.8

more info...
      EOS
      output = render_string input
      assert_xpath '//*[@id="header"]/span[@id="author"][text() = "Stuart Rackham"]', output, 1
      assert_xpath '//*[@id="header"]/span[@id="email"][contains(text(), "founder@asciidoc.org")]', output, 1
      assert_xpath '//*[@id="header"]/span[@id="revnumber"][text() = "version 8.6.8,"]', output, 1
      assert_xpath '//*[@id="header"]/span[@id="revdate"][text() = "2012-07-12"]', output, 1
      assert_xpath '//*[@id="header"]/span[@id="revremark"][text() = "See changelog."]', output, 1
    end

    test 'test_with_header_footer' do
      result = render_string("= Title\n\npreamble")
      assert_xpath '/html', result, 1
      assert_xpath '//*[@id="header"]', result, 1
      assert_xpath '//*[@id="footer"]', result, 1
      assert_xpath '//*[@id="preamble"]', result, 1
    end

    test 'test_with_no_header_footer' do
      result = render_string("= Title\n\npreamble", :header_footer => false)
      assert_xpath '/html', result, 0
      assert_xpath '/*[@id="header"]', result, 0
      assert_xpath '/*[@id="footer"]', result, 0
      assert_xpath '/*[@id="preamble"]', result, 1
    end

    test 'renders footnotes in footer' do
      input = <<-EOS
A footnote footnote:[An example footnote.];
a second footnote with a reference ID footnoteref:[note2,Second footnote.];
finally a reference to the second footnote footnoteref:[note2].
      EOS

      output = render_string input
      assert_css '#footnotes', output, 1
      assert_css '#footnotes .footnote', output, 2
      assert_css '#footnotes .footnote#_footnote_1', output, 1
      assert_xpath '//div[@id="footnotes"]/div[@id="_footnote_1"]/a[@href="#_footnoteref_1"][text()="1"]', output, 1
      text = xmlnodes_at_xpath '//div[@id="footnotes"]/div[@id="_footnote_1"]/text()', output, 1
      assert_equal '. An example footnote.', text.text.strip
      assert_css '#footnotes .footnote#_footnote_2', output, 1
      assert_xpath '//div[@id="footnotes"]/div[@id="_footnote_2"]/a[@href="#_footnoteref_2"][text()="2"]', output, 1
      text = xmlnodes_at_xpath '//div[@id="footnotes"]/div[@id="_footnote_2"]/text()', output, 1
      assert_equal '. Second footnote.', text.text.strip
    end
  end

  context 'Backends and Doctypes' do 
    test 'test_html5_backend_doctype_article' do
      result = render_string("= Title\n\npreamble", :attributes => {'backend' => 'html5'})
      assert_xpath '/html', result, 1
      assert_xpath '/html/body[@class="article"]', result, 1
      assert_xpath '/html//*[@id="header"]/h1[text() = "Title"]', result, 1
      assert_xpath '/html//*[@id="preamble"]//p[text() = "preamble"]', result, 1
    end

    test 'test_html5_backend_doctype_book' do
      result = render_string("= Title\n\npreamble", :attributes => {'backend' => 'html5', 'doctype' => 'book'})
      assert_xpath '/html', result, 1
      assert_xpath '/html/body[@class="book"]', result, 1
      assert_xpath '/html//*[@id="header"]/h1[text() = "Title"]', result, 1
      assert_xpath '/html//*[@id="preamble"]//p[text() = "preamble"]', result, 1
    end

    test 'test_docbook45_backend_doctype_article' do
      input = <<-EOS
= Title

preamble

== First Section

section body
      EOS
      result = render_string(input, :attributes => {'backend' => 'docbook45'})
      assert_xpath '/article', result, 1
      assert_xpath '/article/articleinfo/title[text() = "Title"]', result, 1
      assert_xpath '/article/simpara[text() = "preamble"]', result, 1
      assert_xpath '/article/section', result, 1
      assert_xpath '/article/section[@id = "_first_section"]/title[text() = "First Section"]', result, 1
      assert_xpath '/article/section[@id = "_first_section"]/simpara[text() = "section body"]', result, 1
    end

    test 'test_docbook45_backend_doctype_article_no_title' do
      result = render_string('text', :attributes => {'backend' => 'docbook45'})
      assert_xpath '/article', result, 1
      assert_xpath '/article/articleinfo/date', result, 1
      assert_xpath '/article/simpara[text() = "text"]', result, 1
    end

    test 'test_docbook45_backend_doctype_book' do
      input = <<-EOS
= Title

preamble

== First Chapter

chapter body
      EOS
      result = render_string(input, :attributes => {'backend' => 'docbook45', 'doctype' => 'book'})
      assert_xpath '/book', result, 1
      assert_xpath '/book/bookinfo/title[text() = "Title"]', result, 1
      assert_xpath '/book/preface/simpara[text() = "preamble"]', result, 1
      assert_xpath '/book/chapter', result, 1
      assert_xpath '/book/chapter[@id = "_first_chapter"]/title[text() = "First Chapter"]', result, 1
      assert_xpath '/book/chapter[@id = "_first_chapter"]/simpara[text() = "chapter body"]', result, 1
    end

    test 'test_docbook45_backend_doctype_book_no_title' do
      result = render_string('text', :attributes => {'backend' => 'docbook45', 'doctype' => 'book'})
      assert_xpath '/book', result, 1
      assert_xpath '/book/bookinfo/date', result, 1
      assert_xpath '/book/simpara[text() = "text"]', result, 1
    end

    test 'do not override explicit author initials' do
      input = <<-EOS
= AsciiDoc
Stuart Rackham <founder@asciidoc.org>
:Author Initials: SJR

more info...
      EOS
      output = render_string input, :attributes => {'backend' => 'docbook45'}
      assert_xpath '/article/articleinfo/authorinitials[text()="SJR"]', output, 1
    end
  end
end
