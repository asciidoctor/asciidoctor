# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end
require 'tilt' unless defined? ::Tilt

context 'Converter' do

  context 'View options' do
    test 'should set Haml format to html5 for html5 backend' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      selected = doc.converter.find_converter('paragraph')
      assert selected.is_a? Asciidoctor::Converter::TemplateConverter
      assert selected.templates['paragraph'].is_a? Tilt::HamlTemplate
      assert_equal :html5, selected.templates['paragraph'].options[:format]
    end

    test 'should set Haml format to xhtml for docbook backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      selected = doc.converter.find_converter('paragraph')
      assert selected.is_a? Asciidoctor::Converter::TemplateConverter
      assert selected.templates['paragraph'].is_a? Tilt::HamlTemplate
      assert_equal :xhtml, selected.templates['paragraph'].options[:format]
    end

    test 'should set Slim format to html5 for html5 backend' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      selected = doc.converter.find_converter('paragraph')
      assert selected.is_a? Asciidoctor::Converter::TemplateConverter
      assert selected.templates['paragraph'].is_a? Slim::Template
      assert_equal :html5, selected.templates['paragraph'].options[:format]
    end

    test 'should set Slim format to nil for docbook backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      selected = doc.converter.find_converter('paragraph')
      assert selected.is_a? Asciidoctor::Converter::TemplateConverter
      assert selected.templates['paragraph'].is_a? Slim::Template
      assert_nil selected.templates['paragraph'].options[:format]
    end

    test 'should support custom template engine options for known engine' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim'), :template_cache => false, :template_engine_options => { :slim => { :pretty => true } }
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      selected = doc.converter.find_converter('paragraph')
      assert selected.is_a? Asciidoctor::Converter::TemplateConverter
      assert selected.templates['paragraph'].is_a? Slim::Template
      assert_equal true, selected.templates['paragraph'].options[:pretty]
    end

    test 'should support custom template engine options' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim'), :template_cache => false, :template_engine_options => { :slim => { :pretty => true } }
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      selected = doc.converter.find_converter('paragraph')
      assert selected.is_a? Asciidoctor::Converter::TemplateConverter
      assert selected.templates['paragraph'].is_a? Slim::Template
      assert_equal false, selected.templates['paragraph'].options[:sort_attrs]
      assert_equal true, selected.templates['paragraph'].options[:pretty]
    end
  end

  context 'Custom backends' do
    test 'should load Haml templates for default backend' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      ['paragraph', 'sidebar'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert selected.is_a? Asciidoctor::Converter::TemplateConverter
        assert selected.templates[node_name].is_a? Tilt::HamlTemplate
        assert_equal %(block_#{node_name}.html.haml), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should set outfilesuffix according to backend info' do
      doc = Asciidoctor.load 'content'
      doc.render
      assert_equal '.html', doc.attributes['outfilesuffix']

      doc = Asciidoctor.load 'content', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'), :template_cache => false
      doc.render
      assert_equal '.html', doc.attributes['outfilesuffix']
    end

    test 'should not override outfilesuffix attribute if locked' do
      doc = Asciidoctor.load 'content', :attributes => {'outfilesuffix' => '.foo'}
      doc.render
      assert_equal '.foo', doc.attributes['outfilesuffix']

      doc = Asciidoctor.load 'content', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'), :template_cache => false, :attributes => {'outfilesuffix' => '.foo'}
      doc.render
      assert_equal '.foo', doc.attributes['outfilesuffix']
    end

    test 'should load Haml templates for docbook45 backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert selected.is_a? Asciidoctor::Converter::TemplateConverter
        assert selected.templates[node_name].is_a? Tilt::HamlTemplate
        assert_equal %(block_#{node_name}.xml.haml), File.basename(selected.templates[node_name].file)
      end
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

      output = render_embedded_string input, :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'), :template_cache => false
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p', output, 1
      assert_xpath '//aside', output, 1
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p/following-sibling::aside', output, 1
      assert_xpath '//aside/header/h1[text()="Related"]', output, 1
      assert_xpath '//aside/header/following-sibling::p[text()="Sidebar content"]', output, 1
    end

    test 'should use built-in global cache to cache templates' do
      begin
        # clear out any cache, just to be sure
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter

        template_dir = File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
        doc = Asciidoctor::Document.new [], :template_dir => template_dir
        doc.converter
        caches = Asciidoctor::Converter::TemplateConverter.caches
        if defined? ::ThreadSafe::Cache
          assert caches[:templates].is_a?(::ThreadSafe::Cache)
          assert !caches[:templates].empty?
          paragraph_template_before = caches[:templates].values.find {|t| File.basename(t.file) == 'block_paragraph.html.haml' }
          assert !paragraph_template_before.nil?

          # should use cache
          doc = Asciidoctor::Document.new [], :template_dir => template_dir
          template_converter = doc.converter.find_converter('paragraph')
          paragraph_template_after = template_converter.templates['paragraph']
          assert !paragraph_template_after.nil?
          assert paragraph_template_before.eql?(paragraph_template_after)

          # should not use cache
          doc = Asciidoctor::Document.new [], :template_dir => template_dir, :template_cache => false
          template_converter = doc.converter.find_converter('paragraph')
          paragraph_template_after = template_converter.templates['paragraph']
          assert !paragraph_template_after.nil?
          assert !paragraph_template_before.eql?(paragraph_template_after)
        else
          assert caches.empty?
        end
      ensure
        # clean up
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter
      end
    end

    test 'should use custom cache to cache templates' do
      template_dir = File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml')
      Asciidoctor::PathResolver.new.system_path(File.join(template_dir, 'html5', 'block_paragraph.html.haml'), nil)
      caches = { :scans => {}, :templates => {} }
      doc = Asciidoctor::Document.new [], :template_dir => template_dir, :template_cache => caches
      doc.converter
      assert !caches[:scans].empty?
      assert !caches[:templates].empty?
      paragraph_template = caches[:templates].values.find {|t| File.basename(t.file) == 'block_paragraph.html.haml' }
      assert !paragraph_template.nil?
      assert paragraph_template.is_a? ::Tilt::HamlTemplate
    end

    test 'should be able to disable template cache' do
      begin
        # clear out any cache, just to be sure
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter

        doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'haml'),
            :template_cache => false
        doc.converter
        caches = Asciidoctor::Converter::TemplateConverter.caches
        assert caches.empty? || caches[:scans].empty?
        assert caches.empty? || caches[:templates].empty?
      ensure
        # clean up
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter
      end
    end

    test 'should load ERB templates using ERBTemplate if eruby is not set' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'erb'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert selected.is_a? Asciidoctor::Converter::TemplateConverter
        template = selected.templates[node_name]
        assert template.is_a? Tilt::ERBTemplate
        assert !(template.is_a? Tilt::ErubisTemplate)
        assert template.instance_variable_get('@engine').is_a? ::ERB
        assert_equal %(block_#{node_name}.html.erb), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load ERB templates using ErubisTemplate if eruby is set to erubis' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'erb'), :template_cache => false, :eruby => 'erubis'
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert selected.is_a? Asciidoctor::Converter::TemplateConverter
        template = selected.templates[node_name]
        assert template.is_a? Tilt::ERBTemplate
        assert template.is_a? Tilt::ErubisTemplate
        assert template.instance_variable_get('@engine').is_a? ::Erubis::FastEruby
        assert_equal %(block_#{node_name}.html.erb), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load Slim templates for default backend' do
      doc = Asciidoctor::Document.new [], :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      ['paragraph', 'sidebar'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert selected.is_a? Asciidoctor::Converter::TemplateConverter
        assert selected.templates[node_name].is_a? Slim::Template
        assert_equal %(block_#{node_name}.html.slim), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load Slim templates for docbook45 backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim'), :template_cache => false
      assert doc.converter.is_a?(Asciidoctor::Converter::CompositeConverter)
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert selected.is_a? Asciidoctor::Converter::TemplateConverter
        assert selected.templates[node_name].is_a? Slim::Template
        assert_equal %(block_#{node_name}.xml.slim), File.basename(selected.templates[node_name].file)
      end
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

      output = render_embedded_string input, :template_dir => File.join(File.dirname(__FILE__), 'fixtures', 'custom-backends', 'slim'), :template_cache => false
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p', output, 1
      assert_xpath '//aside', output, 1
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p/following-sibling::aside', output, 1
      assert_xpath '//aside/header/h1[text()="Related"]', output, 1
      assert_xpath '//aside/header/following-sibling::p[text()="Sidebar content"]', output, 1
    end

    test 'should use custom converter if specified' do
      input = <<-EOS
= Document Title

preamble

== Section

content
      EOS

      class CustomConverterA
        def initialize backend, opts = {}
        end

        def convert node, name = nil
          'document'
        end

        def self.converts? backend
          true
        end
      end

      output = render_string input, :converter => CustomConverterA
      assert 'document', output
    end

    test 'should use converter registered for backend' do
      input = <<-EOS
content
      EOS

      begin
        Asciidoctor::Converter::Factory.unregister_all 

        class CustomConverterB
          include Asciidoctor::Converter
          register_for 'foobar'
          def convert node, name = nil
            'foobar content'
          end
        end

        converters = Asciidoctor::Converter::Factory.converters
        assert converters.size == 1
        assert converters['foobar'] == CustomConverterB
        output = render_string input, :backend => 'foobar'
        assert 'foobar content', output
      ensure
        Asciidoctor::Converter::Factory.unregister_all 
      end
    end

    test 'should fall back to catch all converter' do
      input = <<-EOS
content
      EOS

      begin
        Asciidoctor::Converter::Factory.unregister_all 

        class CustomConverterC
          include Asciidoctor::Converter
          register_for '*'
          def convert node, name = nil
            'foobaz content'
          end
        end

        converters = Asciidoctor::Converter::Factory.converters
        assert converters['*'] == CustomConverterC
        output = render_string input, :backend => 'foobaz'
        assert 'foobaz content', output
      ensure
        Asciidoctor::Converter::Factory.unregister_all 
      end
    end
  end
end
