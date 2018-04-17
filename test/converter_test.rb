# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end
require 'tilt' unless defined? ::Tilt

context 'Converter' do

  context 'View options' do
    test 'should set Haml format to html5 for html5 backend' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Tilt::HamlTemplate, selected.templates['paragraph']
      assert_equal :html5, selected.templates['paragraph'].options[:format]
    end

    test 'should set Haml format to xhtml for docbook backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Tilt::HamlTemplate, selected.templates['paragraph']
      assert_equal :xhtml, selected.templates['paragraph'].options[:format]
    end

    test 'should configure Slim to resolve includes in specified template dirs' do
      template_dirs = [(fixture_path 'custom-backends/slim'), (fixture_path 'custom-backends/slim-overrides')]
      doc = Asciidoctor::Document.new [], :template_dirs => template_dirs, :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_equal template_dirs.reverse.map {|dir| File.expand_path dir }, selected.templates['paragraph'].options[:include_dirs]
    end

    test 'should coerce template_dirs option to an Array' do
      template_dirs = fixture_path 'custom-backends/slim'
      doc = Asciidoctor::Document.new [], :template_dirs => template_dirs, :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Array, (selected.instance_variable_get :@template_dirs)
    end

    test 'should set Slim format to html for html5 backend' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_equal :html, selected.templates['paragraph'].options[:format]
    end

    test 'should set Slim format to nil for docbook backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_nil selected.templates['paragraph'].options[:format]
    end

    test 'should set safe mode of Slim AsciiDoc engine to match document safe mode when Slim >= 3' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false, :safe => :unsafe
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      slim_asciidoc_opts = selected.instance_variable_get(:@engine_options)[:slim][:asciidoc]
      if ::Slim::VERSION >= '3.0'
        assert_equal({ :safe => Asciidoctor::SafeMode::UNSAFE }, slim_asciidoc_opts)
      else
        assert_nil slim_asciidoc_opts
      end
    end

    test 'should support custom template engine options for known engine' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false, :template_engine_options => { :slim => { :pretty => true } }
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_equal true, selected.templates['paragraph'].options[:pretty]
    end

    test 'should support custom template engine options' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false, :template_engine_options => { :slim => { :pretty => true } }
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_equal false, selected.templates['paragraph'].options[:sort_attrs]
      assert_equal true, selected.templates['paragraph'].options[:pretty]
    end
  end

  context 'Custom backends' do
    test 'should load Haml templates for default backend' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      ['paragraph', 'sidebar'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        assert_kind_of Tilt::HamlTemplate, selected.templates[node_name]
        assert_equal %(block_#{node_name}.html.haml), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should set outfilesuffix according to backend info' do
      doc = Asciidoctor.load 'content'
      doc.convert
      assert_equal '.html', doc.attributes['outfilesuffix']

      doc = Asciidoctor.load 'content', :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false
      doc.convert
      assert_equal '.html', doc.attributes['outfilesuffix']
    end

    test 'should not override outfilesuffix attribute if locked' do
      doc = Asciidoctor.load 'content', :attributes => {'outfilesuffix' => '.foo'}
      doc.convert
      assert_equal '.foo', doc.attributes['outfilesuffix']

      doc = Asciidoctor.load 'content', :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false, :attributes => {'outfilesuffix' => '.foo'}
      doc.convert
      assert_equal '.foo', doc.attributes['outfilesuffix']
    end

    test 'should load Haml templates for docbook45 backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        assert_kind_of Tilt::HamlTemplate, selected.templates[node_name]
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

      output = render_embedded_string input, :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false
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

        template_dir = fixture_path 'custom-backends/haml'
        doc = Asciidoctor::Document.new [], :template_dir => template_dir
        doc.converter
        caches = Asciidoctor::Converter::TemplateConverter.caches
        if defined? ::ThreadSafe::Cache
          assert_kind_of ::ThreadSafe::Cache, caches[:templates]
          refute_empty caches[:templates]
          paragraph_template_before = caches[:templates].values.find {|t| File.basename(t.file) == 'block_paragraph.html.haml' }
          refute_nil paragraph_template_before

          # should use cache
          doc = Asciidoctor::Document.new [], :template_dir => template_dir
          template_converter = doc.converter.find_converter('paragraph')
          paragraph_template_after = template_converter.templates['paragraph']
          refute_nil paragraph_template_after
          assert paragraph_template_before.eql?(paragraph_template_after)

          # should not use cache
          doc = Asciidoctor::Document.new [], :template_dir => template_dir, :template_cache => false
          template_converter = doc.converter.find_converter('paragraph')
          paragraph_template_after = template_converter.templates['paragraph']
          refute_nil paragraph_template_after
          refute paragraph_template_before.eql?(paragraph_template_after)
        else
          assert_empty caches
        end
      ensure
        # clean up
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter
      end
    end

    test 'should use custom cache to cache templates' do
      template_dir = fixture_path 'custom-backends/haml'
      Asciidoctor::PathResolver.new.system_path(File.join(template_dir, 'html5', 'block_paragraph.html.haml'), nil)
      caches = { :scans => {}, :templates => {} }
      doc = Asciidoctor::Document.new [], :template_dir => template_dir, :template_cache => caches
      doc.converter
      refute_empty caches[:scans]
      refute_empty caches[:templates]
      paragraph_template = caches[:templates].values.find {|t| File.basename(t.file) == 'block_paragraph.html.haml' }
      refute_nil paragraph_template
      assert_kind_of ::Tilt::HamlTemplate, paragraph_template
    end

    test 'should be able to disable template cache' do
      begin
        # clear out any cache, just to be sure
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter

        doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/haml'), :template_cache => false
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
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/erb'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        template = selected.templates[node_name]
        assert_kind_of Tilt::ERBTemplate, template
        refute_kind_of Tilt::ErubisTemplate, template
        assert_kind_of ::ERB, template.instance_variable_get('@engine')
        assert_equal %(block_#{node_name}.html.erb), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load ERB templates using ErubisTemplate if eruby is set to erubis' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/erb'), :template_cache => false, :eruby => 'erubis'
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        template = selected.templates[node_name]
        assert_kind_of Tilt::ERBTemplate, template
        assert_kind_of Tilt::ErubisTemplate, template
        assert_kind_of ::Erubis::FastEruby, template.instance_variable_get('@engine')
        assert_equal %(block_#{node_name}.html.erb), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load Slim templates for default backend' do
      doc = Asciidoctor::Document.new [], :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      ['paragraph', 'sidebar'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        assert_kind_of Slim::Template, selected.templates[node_name]
        assert_equal %(block_#{node_name}.html.slim), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load Slim templates for docbook45 backend' do
      doc = Asciidoctor::Document.new [], :backend => 'docbook45', :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      ['paragraph'].each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        assert_kind_of Slim::Template, selected.templates[node_name]
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

      output = render_embedded_string input, :template_dir => (fixture_path 'custom-backends/slim'), :template_cache => false
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

    test 'should map handles? method on converter to respond_to? by default' do
      class CustomConverterC
        include Asciidoctor::Converter
        def paragraph node
          'paragraph'
        end
      end

      converter = CustomConverterC.new 'myhtml'
      assert_respond_to converter, :handles?
      assert converter.handles?(:paragraph)
    end

    test 'should not configure converter to support templates by default' do
      input = <<-EOS
paragraph
      EOS

      begin
        Asciidoctor::Converter::Factory.unregister_all
        class CustomConverterD
          include Asciidoctor::Converter
          register_for 'myhtml'
          def convert node, transform = nil, opts = {}
            transform ||= node.node_name
            send transform, node
          end

          def document node
            ['<!DOCTYPE html>', '<html>', '<body>', node.content, '</body>', '</html>'] * %(\n)
          end

          def paragraph node
            ['<div class="paragraph">', %(<p>#{node.content}</p>), '</div>'] * %(\n)
          end
        end

        doc = document_from_string input, :backend => 'myhtml', :template_dir => (fixture_path 'custom-backends/slim/html5'), :template_cache => false
        assert_kind_of CustomConverterD, doc.converter
        refute doc.converter.supports_templates?
        output = doc.convert
        assert_xpath '//*[@class="paragraph"]/p[text()="paragraph"]', output, 1
      ensure
        Asciidoctor::Converter::Factory.unregister_all
      end
    end

    test 'should wrap converter in composite converter with template converter if it declares that it supports templates' do
      input = <<-EOS
paragraph
      EOS

      begin
        Asciidoctor::Converter::Factory.unregister_all
        class CustomConverterE
          include Asciidoctor::Converter
          register_for 'myhtml'

          def initialize *args
            super
            supports_templates
          end

          def convert node, transform = nil, opts = {}
            transform ||= node.node_name
            send transform, node
          end

          def document node
            ['<!DOCTYPE html>', '<html>', '<body>', node.content, '</body>', '</html>'] * %(\n)
          end

          def paragraph node
            ['<div class="paragraph">', %(<p>#{node.content}</p>), '</div>'] * %(\n)
          end
        end

        doc = document_from_string input, :backend => 'myhtml', :template_dir => (fixture_path 'custom-backends/slim/html5'), :template_cache => false
        assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
        output = doc.convert
        assert_xpath '//*[@class="paragraph"]/p[text()="paragraph"]', output, 0
        assert_xpath '//body/p[text()="paragraph"]', output, 1
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

        class CustomConverterF
          include Asciidoctor::Converter
          register_for '*'
          def convert node, name = nil
            'foobaz content'
          end
        end

        converters = Asciidoctor::Converter::Factory.converters
        assert converters['*'] == CustomConverterF
        output = render_string input, :backend => 'foobaz'
        assert 'foobaz content', output
      ensure
        Asciidoctor::Converter::Factory.unregister_all
      end
    end
  end
end
