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
      assert_equal 26, views.size
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
      assert_equal 26, views.size
      assert views.has_key? 'document'
      assert views['document'].is_a?(Asciidoctor::DocBook45::DocumentTemplate)
      assert_equal 'ERB', views['document'].eruby.to_s
    end
  
    test 'can set erubis as eRuby implementation' do
      doc = Asciidoctor::Document.new [], :eruby => 'erubis' 
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
