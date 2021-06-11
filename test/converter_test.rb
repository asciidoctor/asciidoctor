# frozen_string_literal: true
require_relative 'test_helper'
require 'tilt' unless defined? Tilt.new

context 'Converter' do
  context 'View options' do
    test 'should set Haml format to html5 for html5 backend' do
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Tilt::HamlTemplate, selected.templates['paragraph']
      assert_equal :html5, selected.templates['paragraph'].options[:format]
    end

    test 'should set Haml format to xhtml for docbook backend' do
      doc = Asciidoctor::Document.new [], backend: 'docbook5', template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Tilt::HamlTemplate, selected.templates['paragraph']
      assert_equal :xhtml, selected.templates['paragraph'].options[:format]
    end

    test 'should configure Slim to resolve includes in specified template dirs' do
      template_dirs = [(fixture_path 'custom-backends/slim'), (fixture_path 'custom-backends/slim-overrides')]
      doc = Asciidoctor::Document.new [], template_dirs: template_dirs, template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_equal template_dirs.reverse.map {|dir| File.expand_path dir }, selected.templates['paragraph'].options[:include_dirs]
    end

    test 'should coerce template_dirs option to an Array' do
      template_dirs = fixture_path 'custom-backends/slim'
      doc = Asciidoctor::Document.new [], template_dirs: template_dirs, template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Array, (selected.instance_variable_get :@template_dirs)
    end

    test 'should set Slim format to html for html5 backend' do
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/slim'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_equal :html, selected.templates['paragraph'].options[:format]
    end

    test 'should set Slim format to nil for docbook backend' do
      doc = Asciidoctor::Document.new [], backend: 'docbook5', template_dir: (fixture_path 'custom-backends/slim'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_nil selected.templates['paragraph'].options[:format]
    end

    test 'should set safe mode of Slim AsciiDoc engine to match document safe mode when Slim >= 3' do
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/slim'), template_cache: false, safe: :unsafe
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      slim_asciidoc_opts = selected.instance_variable_get(:@engine_options)[:slim][:asciidoc]
      assert_equal({ safe: Asciidoctor::SafeMode::UNSAFE }, slim_asciidoc_opts)
    end

    test 'should support custom template engine options for known engine' do
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/slim'), template_cache: false, template_engine_options: { slim: { pretty: true } }
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      selected = doc.converter.find_converter('paragraph')
      assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
      assert_kind_of Slim::Template, selected.templates['paragraph']
      assert_equal true, selected.templates['paragraph'].options[:pretty]
    end

    test 'should support custom template engine options' do
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/slim'), template_cache: false, template_engine_options: { slim: { pretty: true } }
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
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      %w(paragraph sidebar).each do |node_name|
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

      doc = Asciidoctor.load 'content', template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
      doc.convert
      assert_equal '.html', doc.attributes['outfilesuffix']
    end

    test 'should not override outfilesuffix attribute if locked' do
      doc = Asciidoctor.load 'content', attributes: { 'outfilesuffix' => '.foo' }
      doc.convert
      assert_equal '.foo', doc.attributes['outfilesuffix']

      doc = Asciidoctor.load 'content', template_dir: (fixture_path 'custom-backends/haml'), template_cache: false, attributes: { 'outfilesuffix' => '.foo' }
      doc.convert
      assert_equal '.foo', doc.attributes['outfilesuffix']
    end

    test 'should load Haml templates for docbook5 backend' do
      doc = Asciidoctor::Document.new [], backend: 'docbook5', template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      %w(paragraph).each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        assert_kind_of Tilt::HamlTemplate, selected.templates[node_name]
        assert_equal %(block_#{node_name}.xml.haml), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should use Haml templates in place of built-in templates' do
      input = <<~'EOS'
      = Document Title
      Author Name

      == Section One

      Sample paragraph

      .Related
      ****
      Sidebar content
      ****
      EOS

      output = convert_string_to_embedded input, template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p', output, 1
      assert_xpath '//aside', output, 1
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p/following-sibling::aside', output, 1
      assert_xpath '//aside/header/h1[text()="Related"]', output, 1
      assert_xpath '//aside/header/following-sibling::p[text()="Sidebar content"]', output, 1
    end

    test 'should allow custom backend to emulate a known backend' do
      doc = Asciidoctor.load 'content', backend: 'html5-tweaks:html', template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
      assert doc.basebackend? 'html'
      assert_equal 'html5-tweaks', doc.backend
      converter = doc.converter
      assert_kind_of Asciidoctor::Converter::TemplateConverter, (converter.find_converter 'embedded')
      refute_kind_of Asciidoctor::Converter::TemplateConverter, (converter.find_converter 'admonition')
      assert_equal '<p>content</p>', doc.convert
    end

    test 'should create template converter even when a converter is not registered for the specified backend' do
      input = 'paragraph content'
      output = convert_string_to_embedded input, backend: :unknown, template_dir: (fixture_path 'custom-backends/haml/html5-tweaks'), template_cache: false
      assert_equal '<p>paragraph content</p>', output
    end

    test 'should use built-in global cache to cache templates' do
      begin
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter
        template_dir = fixture_path 'custom-backends/haml'
        doc = Asciidoctor::Document.new [], template_dir: template_dir
        doc.converter
        caches = Asciidoctor::Converter::TemplateConverter.caches
        if defined? ::Concurrent::Map
          assert_kind_of ::Concurrent::Map, caches[:templates]
        else
          assert_kind_of ::Hash, caches[:templates]
        end
        refute_empty caches[:templates]
        paragraph_template_before = caches[:templates].values.find {|t| File.basename(t.file) == 'block_paragraph.html.haml' }
        refute_nil paragraph_template_before

        # should use cache
        doc = Asciidoctor::Document.new [], template_dir: template_dir
        template_converter = doc.converter.find_converter('paragraph')
        paragraph_template_after = template_converter.templates['paragraph']
        refute_nil paragraph_template_after
        assert paragraph_template_before.eql?(paragraph_template_after)

        # should not use cache
        doc = Asciidoctor::Document.new [], template_dir: template_dir, template_cache: false
        template_converter = doc.converter.find_converter('paragraph')
        paragraph_template_after = template_converter.templates['paragraph']
        refute_nil paragraph_template_after
        refute paragraph_template_before.eql?(paragraph_template_after)
      ensure
        # clean up
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter
      end
    end

    test 'should use custom cache to cache templates' do
      template_dir = fixture_path 'custom-backends/haml'
      Asciidoctor::PathResolver.new.system_path(File.join(template_dir, 'html5', 'block_paragraph.html.haml'), nil)
      caches = { scans: {}, templates: {} }
      doc = Asciidoctor::Document.new [], template_dir: template_dir, template_cache: caches
      doc.converter
      refute_empty caches[:scans]
      refute_empty caches[:templates]
      paragraph_template = caches[:templates].values.find {|t| File.basename(t.file) == 'block_paragraph.html.haml' }
      refute_nil paragraph_template
      assert_kind_of ::Tilt::HamlTemplate, paragraph_template
    end

    test 'should be able to disable template cache' do
      begin
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter
        doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/haml'), template_cache: false
        doc.converter
        caches = Asciidoctor::Converter::TemplateConverter.caches
        assert_empty caches[:scans]
        assert_empty caches[:templates]
      ensure
        # clean up
        Asciidoctor::Converter::TemplateConverter.clear_caches if defined? Asciidoctor::Converter::TemplateConverter
      end
    end

    test 'should load ERB templates using ERBTemplate if eruby is not set' do
      input = %([.wrapper]\n--\nfoobar\n--)
      doc = Asciidoctor::Document.new input, template_dir: (fixture_path 'custom-backends/erb'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      %w(paragraph).each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        template = selected.templates[node_name]
        assert_kind_of Tilt::ERBTemplate, template
        refute_kind_of Tilt::ErubiTemplate, template
        assert_kind_of ::ERB, template.instance_variable_get('@engine')
        assert_equal %(block_#{node_name}.html.erb), File.basename(selected.templates[node_name].file)
      end
      # NOTE verify behavior of trim mode
      expected_output = <<~'EOS'.chop
      <div class="openblock wrapper">
      <div class="content">
      <div class="paragraph">
      <p>foobar</p>
      </div>
      </div>
      </div>
      EOS
      assert_equal expected_output, doc.convert
    end

    test 'should load ERB templates using ErubiTemplate if eruby is set to erubi' do
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/erb'), template_cache: false, eruby: 'erubi'
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      %w(paragraph).each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        template = selected.templates[node_name]
        assert_kind_of Tilt::ErubiTemplate, template
        assert_kind_of ::Erubi::Engine, template.instance_variable_get('@engine')
        assert_equal %(block_#{node_name}.html.erb), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load Slim templates for default backend' do
      doc = Asciidoctor::Document.new [], template_dir: (fixture_path 'custom-backends/slim'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      %w(paragraph sidebar).each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        assert_kind_of Slim::Template, selected.templates[node_name]
        assert_equal %(block_#{node_name}.html.slim), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should load Slim templates for docbook5 backend' do
      doc = Asciidoctor::Document.new [], backend: 'docbook5', template_dir: (fixture_path 'custom-backends/slim'), template_cache: false
      assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
      %w(paragraph).each do |node_name|
        selected = doc.converter.find_converter node_name
        assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
        assert_kind_of Slim::Template, selected.templates[node_name]
        assert_equal %(block_#{node_name}.xml.slim), File.basename(selected.templates[node_name].file)
      end
    end

    test 'should use Slim templates in place of built-in templates' do
      input = <<~'EOS'
      = Document Title
      Author Name

      == Section One

      Sample paragraph

      .Related
      ****
      Sidebar content
      ****
      EOS

      output = convert_string_to_embedded input, template_dir: (fixture_path 'custom-backends/slim'), template_cache: false
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p', output, 1
      assert_xpath '//aside', output, 1
      assert_xpath '/*[@class="sect1"]/*[@class="sectionbody"]/p/following-sibling::aside', output, 1
      assert_xpath '//aside/header/h1[text()="Related"]', output, 1
      assert_xpath '//aside/header/following-sibling::p[text()="Sidebar content"]', output, 1
    end

    test 'should be able to override the outline using a custom template' do
      input = <<~'EOS'
      :toc:
      = Document Title

      == Section One

      == Section Two

      == Section Three
      EOS

      output = document_from_string(input, template_dir: (fixture_path 'custom-backends/slim/html5-custom-outline'), template_cache: false).convert
      assert_xpath '//*[@id="toc"]/ul', output, 1
      assert_xpath '//*[@id="toc"]/ul[1]/li', output, 3
      assert_xpath '//*[@id="toc"]/ul[1]/li[1][text()="Section One"]', output, 1
    end
  end

  context 'Custom converters' do
    test 'should not expose included method on Converter class' do
      refute_includes Asciidoctor::Converter.methods, :included
      assert_includes Asciidoctor::Converter.private_methods, :included
      refute_respond_to Asciidoctor::Converter, :included
    end

    test 'should derive backend traits for the given backend' do
      expected = { basebackend: 'dita', filetype: 'dita', outfilesuffix: '.dita' }
      actual = Asciidoctor::Converter.derive_backend_traits 'dita2'
      assert_equal expected, actual
    end

    test 'should use specified converter for current backend' do
      input = <<~'EOS'
      = Document Title

      preamble

      == Section

      content
      EOS

      class CustomHtmlConverterA
        def initialize *args; end

        def convert node, name = nil
          'document'
        end
      end

      doc = document_from_string input, converter: CustomHtmlConverterA
      assert_kind_of CustomHtmlConverterA, doc.converter
      assert_equal 'html', doc.attributes['filetype']
      assert_equal 'document', doc.convert
    end

    test 'should use specified converter for specified backend' do
      input = <<~'EOS'
      = Document Title

      preamble

      == Section

      content
      EOS

      class CustomTextConverterA
        def initialize *args; end

        def convert node, name = nil
          'document'
        end
      end

      doc = document_from_string input, backend: 'text', converter: CustomTextConverterA
      assert_kind_of CustomTextConverterA, doc.converter
      assert_equal 'text', doc.attributes['filetype']
      assert_equal 'document', doc.convert
    end

    test 'should get converter from specified converter factory' do
      input = <<~'EOS'
      = Document Title

      preamble

      == Section

      content
      EOS

      my_converter_class = Class.new Asciidoctor::Converter::Base do
        def convert_document node
          'document'
        end
      end

      converter_factory = Asciidoctor::Converter::CustomFactory.new 'html5' => my_converter_class

      doc = document_from_string input, converter_factory: converter_factory
      assert_kind_of my_converter_class, doc.converter
      assert_equal 'html', doc.attributes['filetype']
      assert_equal 'document', doc.convert
    end

    test 'should allow converter to set htmlsyntax when basebackend is html' do
      input = 'image::sunset.jpg[]'
      converter = Asciidoctor::Converter.create 'html5', htmlsyntax: 'xml'
      doc = document_from_string input, converter: converter
      assert_equal converter, doc.converter
      assert_equal 'xml', (doc.attr 'htmlsyntax')
      output = doc.convert standalone: false
      assert_includes output, '<img src="sunset.jpg" alt="sunset"/>'
    end

    test 'should use converter registered for backend' do
      begin
        converters_before = Asciidoctor::Converter.converters

        class CustomConverterB
          include Asciidoctor::Converter
          register_for 'foobar'
          def initialize *args
            super
            basebackend 'text'
            filetype 'text'
            outfilesuffix '.fb'
          end

          def convert node, name = nil
            'foobar content'
          end
        end

        input = 'content'
        assert_equal CustomConverterB, (Asciidoctor::Converter.for 'foobar')
        converters = Asciidoctor::Converter.converters
        assert converters.size == converters_before.size + 1
        assert converters['foobar'] == CustomConverterB
        output = convert_string input, backend: 'foobar'
        assert_equal 'foobar content', output
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should be able to register converter using symbol' do
      begin
        converter = Class.new Asciidoctor::Converter::Base do
          register_for :foobaz
          def initialize *args
            super
            basebackend 'text'
            filetype 'text'
            outfilesuffix '.fb'
          end
        end
        assert_equal converter, (Asciidoctor::Converter.for 'foobaz')
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should use basebackend to compute filetype and outfilesuffix' do
      begin
        assert_nil Asciidoctor::Converter.for 'slides'

        class SlidesConverter < Asciidoctor::Converter::Base
          register_for 'slides'

          def initialize backend, opts = {}
            super
            basebackend 'html'
          end
        end

        doc = document_from_string 'content', backend: 'slides'
        assert_equal '.html', doc.outfilesuffix
        expected_traits = { basebackend: 'html', filetype: 'html', htmlsyntax: 'html', outfilesuffix: '.html' }
        assert_equal expected_traits, doc.converter.backend_traits
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should be able to register converter from converter class itself' do
      begin
        assert_nil Asciidoctor::Converter.for 'foobar'

        class AnotherCustomConverterB
          include Asciidoctor::Converter
        end

        AnotherCustomConverterB.register_for 'foobar'
        assert_equal AnotherCustomConverterB, (Asciidoctor::Converter.for 'foobar')
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should map handles? method on converter to respond_to? implementation by default' do
      class CustomConverterC
        include Asciidoctor::Converter
        def convert_paragraph node
          'paragraph'
        end
      end

      converter = CustomConverterC.new 'myhtml'
      assert_respond_to converter, :handles?
      assert converter.handles?(:convert_paragraph)
    end

    test 'should not configure converter to support templates by default' do
      begin
        class CustomConverterD
          include Asciidoctor::Converter
          register_for 'myhtml'

          def convert node, transform = nil, opts = nil
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

        input = 'paragraph'
        doc = document_from_string input, backend: 'myhtml', template_dir: (fixture_path 'custom-backends/slim/html5'), template_cache: false
        assert_kind_of CustomConverterD, doc.converter
        refute doc.converter.supports_templates?
        output = doc.convert
        assert_xpath '//*[@class="paragraph"]/p[text()="paragraph"]', output, 1
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should wrap converter in composite converter with template converter if it declares that it supports templates' do
      begin
        class CustomConverterE < Asciidoctor::Converter::Base
          register_for 'myhtml'

          def initialize *args
            super
            supports_templates
          end

          def convert node, transform = nil, opts = nil
            transform ||= node.node_name
            send transform, node
          end

          alias handles? respond_to?

          def document node
            ['<!DOCTYPE html>', '<html>', '<body>', node.content, '</body>', '</html>'] * %(\n)
          end

          def paragraph node
            ['<div class="paragraph">', %(<p>#{node.content}</p>), '</div>'] * %(\n)
          end
        end

        input = 'paragraph'
        doc = document_from_string input, backend: 'myhtml', template_dir: (fixture_path 'custom-backends/slim/html5'), template_cache: false
        assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
        output = doc.convert
        assert_xpath '//*[@class="paragraph"]/p[text()="paragraph"]', output, 0
        assert_xpath '//body/p[text()="paragraph"]', output, 1
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should map Factory.new to DefaultFactoryProxy constructor by default' do
      assert_equal (Asciidoctor::Converter.for 'html5'), (Asciidoctor::Converter::Factory.new.for 'html5')
    end

    test 'should map Factory.new to CustomFactory constructor if proxy keyword arg is false' do
      assert_nil (Asciidoctor::Converter::Factory.new proxy_default: false).for 'html5'
    end

    test 'should default to catch all converter' do
      begin
        class CustomConverterF
          include Asciidoctor::Converter
          register_for '*'
          def convert node, name = nil
            'foobaz content'
          end
        end

        input = 'content'
        assert_equal CustomConverterF, (Asciidoctor::Converter.for 'all')
        assert_equal CustomConverterF, (Asciidoctor::Converter.for 'whatever')
        refute_equal CustomConverterF, (Asciidoctor::Converter.for 'html5')
        converters = Asciidoctor::Converter.converters
        assert_nil converters['*']
        assert_equal CustomConverterF, (Asciidoctor::Converter.send :catch_all)
        output = convert_string input, backend: 'foobaz'
        assert_equal 'foobaz content', output
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should use catch all converter from custom factory only if no other converter matches' do
      class FooConverter < Asciidoctor::Converter::Base; end
      class CatchAllConverter < Asciidoctor::Converter::Base; end

      factory = Asciidoctor::Converter::CustomFactory.new 'foo' => FooConverter, '*' => CatchAllConverter
      assert_equal FooConverter, (factory.for 'foo')
      assert_equal CatchAllConverter, (factory.for 'nada')
      assert_equal CatchAllConverter, (factory.for 'html5')
    end

    test 'should prefer catch all converter from proxy over statically registered catch all converter' do
      begin
        class StaticCatchAllConverter < Asciidoctor::Converter::Base
          register_for '*'
        end

        class LocalCatchAllConverter < Asciidoctor::Converter::Base; end

        factory = Asciidoctor::Converter::DefaultFactoryProxy.new '*' => LocalCatchAllConverter
        assert_equal LocalCatchAllConverter, (factory.for 'foobar')
        refute_equal LocalCatchAllConverter, (factory.for 'html5')
        refute_equal StaticCatchAllConverter, (factory.for 'html5')
      ensure
        Asciidoctor::Converter.unregister_all
      end
    end

    test 'should prefer converter in proxy with same name as provided converter' do
      class MyHtml5Converter < Asciidoctor::Converter::Base; end
      factory = Asciidoctor::Converter::DefaultFactoryProxy.new 'html5' => MyHtml5Converter
      assert_equal MyHtml5Converter, (factory.for 'html5')
    end

    test 'should allow nil to be registered as converter' do
      factory = Asciidoctor::Converter::DefaultFactoryProxy.new 'html5' => nil
      assert_nil factory.for 'html5'
    end

    test 'should create a new custom factory when Converter::Factory.new is invoked' do
      class MyConverter < Asciidoctor::Converter::Base; end
      converters = { 'mine' => MyConverter }
      factory = Asciidoctor::Converter::Factory.new converters
      assert_kind_of Asciidoctor::Converter::CustomFactory, factory
      assert_equal MyConverter, (factory.for 'mine')
    end

    test 'should delegate to method on HTML 5 converter with convert_ prefix if called without prefix' do
      doc = document_from_string 'paragraph'
      assert_respond_to doc.converter, :paragraph
      result = doc.converter.paragraph doc.blocks[0]
      assert_css 'p', result, 1
    end

    test 'should not delegate unprefixed method on HTML 5 converter if converter does not handle transform' do
      doc = document_from_string 'paragraph'
      refute_respond_to doc.converter, :sentence
      assert_raises NoMethodError do
        doc.converter.sentence doc.blocks[0]
      end
    end

    test 'can call read_svg_contents on built-in HTML5 converter; should remove markup prior the root svg element' do
      doc = document_from_string 'image::circle.svg[]', base_dir: fixturedir
      result = doc.converter.read_svg_contents doc.blocks[0], 'circle.svg'
      refute_nil result
      assert result.start_with? '<svg'
    end
  end
end
