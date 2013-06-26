require 'test_helper'
require 'tilt'

context 'Renderer' do

  context 'View mapping' do
    test 'should extract view mapping from built-in template with one segment and backend' do
      view_name, view_backend = Asciidoctor::Renderer.extract_view_mapping('Asciidoctor::HTML5::DocumentTemplate') 
      assert_equal 'document', view_name
      assert_equal 'html5', view_backend
    end

    test 'should extract view mapping from built-in template with two segments and backend' do
      view_name, view_backend = Asciidoctor::Renderer.extract_view_mapping('Asciidoctor::DocBook45::BlockSidebarTemplate') 
      assert_equal 'block_sidebar', view_name
      assert_equal 'docbook45', view_backend
    end

    test 'should extract view mapping from built-in template without backend' do
      view_name, view_backend = Asciidoctor::Renderer.extract_view_mapping('Asciidoctor::DocumentTemplate') 
      assert_equal 'document', view_name
      assert view_backend.nil?
    end
  end

  context 'View options' do
    test 'should set Haml format to html5 for html5 backend' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
      assert doc.renderer.views['block_paragraph'].is_a? Tilt::HamlTemplate
      assert_equal :html5, doc.renderer.views['block_paragraph'].options[:format]
    end

    test 'should set Haml format to xhtml for docbook backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
      assert doc.renderer.views['block_paragraph'].is_a? Tilt::HamlTemplate
      assert_equal :xhtml, doc.renderer.views['block_paragraph'].options[:format]
    end
  end

  context 'Custom backends' do
    test 'should load Haml templates for default backend' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
      assert doc.renderer.views['block_paragraph'].is_a? Tilt::HamlTemplate
      assert doc.renderer.views['block_paragraph'].file.end_with? 'block_paragraph.html.haml'
      assert doc.renderer.views['block_sidebar'].is_a? Tilt::HamlTemplate
      assert doc.renderer.views['block_sidebar'].file.end_with? 'block_sidebar.html.haml'
    end

    test 'should load Haml templates for docbook45 backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
      assert doc.renderer.views['block_paragraph'].is_a? Tilt::HamlTemplate
      assert doc.renderer.views['block_paragraph'].file.end_with? 'block_paragraph.xml.haml'
    end

    test 'should use Haml templates in place of built-in templates' do
      input = <<-EOS
= Document Title
Author Name

== Section One

Sample paragraph

.Related
****
Sidebar content
****
      EOS

      output = render_embedded_string input, :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p', output, 1
      assert_xpath '//aside', output, 1
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p/following-sibling::aside', output, 1
      assert_xpath '//aside/header/h1[text()="Related"]', output, 1
      assert_xpath '//aside/header/following-sibling::p[text()="Sidebar content"]', output, 1
    end

    test 'should use built-in global cache to cache templates' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
      doc.renderer
      template_cache = Asciidoctor::Renderer.class_variable_get(:@@global_cache)
      assert template_cache.is_a? Asciidoctor::TemplateCache
      cache = template_cache.cache
      assert_not_nil cache
      assert cache.size > 0
    end

    test 'should use custom cache to cache templates' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'),
          :template_cache => Asciidoctor::TemplateCache.new
      assert_not_nil doc.renderer.cache
      cache = doc.renderer.cache.cache
      assert_not_nil cache
      assert cache.size > 0
      assert cache.values[0].is_a? Tilt::HamlTemplate
    end

    test 'should be able to disable template cache' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'),
          :template_cache => false
      assert_nil doc.renderer.cache
    end

    test 'should load Slim templates for default backend' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim')
      assert doc.renderer.views['block_paragraph'].is_a? Slim::Template
      assert doc.renderer.views['block_paragraph'].file.end_with? 'block_paragraph.html.slim'
      assert doc.renderer.views['block_sidebar'].is_a? Slim::Template
      assert doc.renderer.views['block_sidebar'].file.end_with? 'block_sidebar.html.slim'
    end

    test 'should load Slim templates for docbook45 backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim')
      assert doc.renderer.views['block_paragraph'].is_a? Slim::Template
      assert doc.renderer.views['block_paragraph'].file.end_with? 'block_paragraph.xml.slim'
    end

    test 'should use Slim templates in place of built-in templates' do
      input = <<-EOS
= Document Title
Author Name

== Section One

Sample paragraph

.Related
****
Sidebar content
****
      EOS

      output = render_embedded_string input, :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim')
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p', output, 1
      assert_xpath '//aside', output, 1
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p/following-sibling::aside', output, 1
      assert_xpath '//aside/header/h1[text()="Related"]', output, 1
      assert_xpath '//aside/header/following-sibling::p[text()="Sidebar content"]', output, 1
    end
  end
end
