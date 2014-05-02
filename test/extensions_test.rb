# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end
require 'asciidoctor/extensions'

class SamplePreprocessor < Asciidoctor::Extensions::Preprocessor
  def process doc, reader
    nil
  end
end

class SampleIncludeProcessor < Asciidoctor::Extensions::IncludeProcessor
end

class SampleTreeprocessor < Asciidoctor::Extensions::Treeprocessor
end

class SamplePostprocessor < Asciidoctor::Extensions::Postprocessor
end

class SampleBlock < Asciidoctor::Extensions::BlockProcessor
end

class SampleBlockMacro < Asciidoctor::Extensions::BlockMacroProcessor
end

class SampleInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
end

class ScrubHeaderPreprocessor < Asciidoctor::Extensions::Preprocessor
  def process doc, reader
    lines = reader.lines
    skipped = []
    while !lines.empty? && !lines.first.start_with?('=')
      skipped << lines.shift
      reader.advance
    end
    doc.set_attr 'skipped', (skipped * "\n")
    reader
  end
end

class BoilerplateTextIncludeProcessor < Asciidoctor::Extensions::IncludeProcessor
  def handles? target
    target.end_with? '.txt'
  end

  def process reader, target, attributes
    case target
    when 'lorem-ipsum.txt'
      content = ["Lorem ipsum dolor sit amet...\n"]
      reader.push_include content, target, target, 1, attributes
    else
      nil
    end
  end
end

class ReplaceAuthorTreeprocessor < Asciidoctor::Extensions::Treeprocessor
  def process document
    document.attributes['firstname'] = 'Ghost'
    document.attributes['author'] = 'Ghost Writer'
  end
end

class StripAttributesPostprocessor < Asciidoctor::Extensions::Postprocessor
  def process document, output
    output.gsub(/<(\w+).*?>/m, "<\\1>")
  end
end

class UppercaseBlock < Asciidoctor::Extensions::BlockProcessor; use_dsl
  match_name :yell
  on_contexts :paragraph
  parse_content_as :simple
  def process parent, reader, attributes
    create_paragraph parent, reader.lines.map(&:upcase), attributes
  end
end

class SnippetMacro < Asciidoctor::Extensions::BlockMacroProcessor
  def process parent, target, attributes
    create_pass_block parent, %(<script src="http://example.com/#{target}.js"></script>), {}, :content_model => :raw
  end
end

class TemperatureMacro < Asciidoctor::Extensions::InlineMacroProcessor; use_dsl
  match_name :degrees
  map_attributes ['units']
  def process parent, target, attributes
    units = attributes['units'] || (parent.document.attr 'temperature-unit', 'C')
    c = target.to_f
    case units
    when 'C'
      %(#{c} &#176;C)
    when 'F'
      %(#{c * 1.8 + 32 } &#176;F)
    else
      c
    end
  end
end

class SampleExtensionGroup < Asciidoctor::Extensions::Group
  def activate registry
    registry.document.attributes['activate-method-called'] = ''
    registry.preprocessor SamplePreprocessor
  end
end

context 'Extensions' do
  context 'Register' do
    test 'should register extension group class' do
      begin
        Asciidoctor::Extensions.register :sample, SampleExtensionGroup
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        assert_equal SampleExtensionGroup, Asciidoctor::Extensions.groups[:sample]
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should self register extension group class' do
      begin
        SampleExtensionGroup.register :sample
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        assert_equal SampleExtensionGroup, Asciidoctor::Extensions.groups[:sample]
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should register extension group from class name' do
      begin
        Asciidoctor::Extensions.register :sample, 'SampleExtensionGroup'
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        assert_equal SampleExtensionGroup, Asciidoctor::Extensions.groups[:sample]
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should register extension group from instance' do
      begin
        Asciidoctor::Extensions.register :sample, SampleExtensionGroup.new
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        assert Asciidoctor::Extensions.groups[:sample].is_a? SampleExtensionGroup
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should register extension block' do
      begin
        Asciidoctor::Extensions.register(:sample) do
        end
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        assert Asciidoctor::Extensions.groups[:sample].is_a? Proc
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should get class for top-level class name' do
      clazz = Asciidoctor::Extensions.class_for_name('Asciidoctor')
      refute_nil clazz
      assert_equal Asciidoctor, clazz
    end

    test 'should get class for class name in module' do
      clazz = Asciidoctor::Extensions.class_for_name('Asciidoctor::Extensions')
      refute_nil clazz
      assert_equal Asciidoctor::Extensions, clazz
    end

    test 'should get class for class name resolved from root' do
      clazz = Asciidoctor::Extensions.class_for_name('::Asciidoctor::Extensions')
      refute_nil clazz
      assert_equal Asciidoctor::Extensions, clazz
    end

    test 'should raise exception if cannot find class for name' do
      begin
        Asciidoctor::Extensions.class_for_name('InvalidModule::InvalidClass')
        flunk 'Expecting RuntimeError to be raised'
      rescue RuntimeError => e
        assert_equal 'Could not resolve class for name: InvalidModule::InvalidClass', e.message
      end
    end

    test 'should resolve class if class is given' do
      clazz = Asciidoctor::Extensions.resolve_class(Asciidoctor::Extensions)
      refute_nil clazz
      assert_equal Asciidoctor::Extensions, clazz
    end

    test 'should resolve class if class from string' do
      clazz = Asciidoctor::Extensions.resolve_class('Asciidoctor::Extensions')
      refute_nil clazz
      assert_equal Asciidoctor::Extensions, clazz
    end
  end

  context 'Activate' do
    test 'should call activate on extension group class' do
      begin
        doc = Asciidoctor::Document.new
        Asciidoctor::Extensions.register :sample, SampleExtensionGroup
        registry = Asciidoctor::Extensions::Registry.new
        registry.activate doc
        assert doc.attr? 'activate-method-called'
        assert registry.preprocessors?
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke extension block' do
      begin
        doc = Asciidoctor::Document.new
        Asciidoctor::Extensions.register do
          @document.attributes['block-called'] = ''
          preprocessor SamplePreprocessor
        end
        registry = Asciidoctor::Extensions::Registry.new
        registry.activate doc
        assert doc.attr? 'block-called'
        assert registry.preprocessors?
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should create registry in Document if extensions are loaded' do
      begin
        SampleExtensionGroup.register
        doc = Asciidoctor::Document.new
        assert doc.extensions?
        assert doc.extensions.is_a? Asciidoctor::Extensions::Registry
      ensure
        Asciidoctor::Extensions.unregister_all
      end
      
    end
  end

  context 'Instantiate' do
    test 'should instantiate preprocessors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.preprocessor SamplePreprocessor
      registry.activate Asciidoctor::Document.new
      assert registry.preprocessors?
      extensions = registry.preprocessors
      assert_equal 1, extensions.size
      assert extensions.first.is_a? Asciidoctor::Extensions::ProcessorExtension
      assert extensions.first.instance.is_a? SamplePreprocessor
      assert extensions.first.process_method.is_a? ::Method
    end

    test 'should instantiate include processors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.include_processor SampleIncludeProcessor
      registry.activate Asciidoctor::Document.new
      assert registry.include_processors?
      extensions = registry.include_processors
      assert_equal 1, extensions.size
      assert extensions.first.is_a? Asciidoctor::Extensions::ProcessorExtension
      assert extensions.first.instance.is_a? SampleIncludeProcessor
      assert extensions.first.process_method.is_a? ::Method
    end

    test 'should instantiate treeprocessors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.treeprocessor SampleTreeprocessor
      registry.activate Asciidoctor::Document.new
      assert registry.treeprocessors?
      extensions = registry.treeprocessors
      assert_equal 1, extensions.size
      assert extensions.first.is_a? Asciidoctor::Extensions::ProcessorExtension
      assert extensions.first.instance.is_a? SampleTreeprocessor
      assert extensions.first.process_method.is_a? ::Method
    end

    test 'should instantiate postprocessors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.postprocessor SamplePostprocessor
      registry.activate Asciidoctor::Document.new
      assert registry.postprocessors?
      extensions = registry.postprocessors
      assert_equal 1, extensions.size
      assert extensions.first.is_a? Asciidoctor::Extensions::ProcessorExtension
      assert extensions.first.instance.is_a? SamplePostprocessor
      assert extensions.first.process_method.is_a? ::Method
    end

    test 'should instantiate block processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block SampleBlock, :sample
      registry.activate Asciidoctor::Document.new
      assert registry.blocks?
      assert registry.registered_for_block? :sample, :paragraph
      extension = registry.find_block_extension :sample
      assert extension.is_a? Asciidoctor::Extensions::ProcessorExtension
      assert extension.instance.is_a? SampleBlock
      assert extension.process_method.is_a? ::Method
    end

    test 'should not match block processor for unsupported context' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block SampleBlock, :sample
      registry.activate Asciidoctor::Document.new
      assert !(registry.registered_for_block? :sample, :sidebar)
    end

    test 'should instantiate block macro processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block_macro SampleBlockMacro, 'sample'
      registry.activate Asciidoctor::Document.new
      assert registry.block_macros?
      assert registry.registered_for_block_macro? 'sample'
      extension = registry.find_block_macro_extension 'sample'
      assert extension.is_a? Asciidoctor::Extensions::ProcessorExtension
      assert extension.instance.is_a? SampleBlockMacro
      assert extension.process_method.is_a? ::Method
    end

    test 'should instantiate inline macro processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.inline_macro SampleInlineMacro, 'sample'
      registry.activate Asciidoctor::Document.new
      assert registry.inline_macros?
      assert registry.registered_for_inline_macro? 'sample'
      extension = registry.find_inline_macro_extension 'sample'
      assert extension.is_a? Asciidoctor::Extensions::ProcessorExtension
      assert extension.instance.is_a? SampleInlineMacro
      assert extension.process_method.is_a? ::Method
    end

    test 'should allow processors to be registered by a string name' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.preprocessor 'SamplePreprocessor'
      registry.activate Asciidoctor::Document.new
      assert registry.preprocessors?
      extensions = registry.preprocessors
      assert_equal 1, extensions.size
      assert extensions.first.is_a? Asciidoctor::Extensions::ProcessorExtension
    end
  end

  context 'Integration' do
    test 'should invoke preprocessors before parsing document' do
      input = <<-EOS
junk line

= Document Title

sample content
      EOS

      begin
        Asciidoctor::Extensions.register do
          preprocessor ScrubHeaderPreprocessor
        end

        doc = document_from_string input
        assert doc.attr? 'skipped'
        assert_equal 'junk line', (doc.attr 'skipped').strip
        assert doc.has_header?
        assert_equal 'Document Title', doc.doctitle
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke include processor to process include macro' do
      input = <<-EOS
before

include::lorem-ipsum.txt[]

after
      EOS

      begin
        Asciidoctor::Extensions.register do
          include_processor BoilerplateTextIncludeProcessor
        end

        result = render_string input, :safe => :server
        assert_css '.paragraph > p', result, 3
        assert result.include?('before')
        assert result.include?('Lorem ipsum')
        assert result.include?('after')
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end
  
    test 'should call include processor to process include directive' do
      input = <<-EOS
first line

include::include-file.asciidoc[]

last line
      EOS

      # Safe Mode is not required here
      document = empty_document :base_dir => File.expand_path(File.dirname(__FILE__))
      document.extensions.include_processor do
        process do |reader, target, attributes|
          # demonstrate that push_include normalizes endlines
          content = ["include target:: #{target}\n", "\n", "middle line\n"]
          reader.push_include content, target, target, 1, attributes
        end
      end
      reader = Asciidoctor::PreprocessorReader.new document, input
      lines = []
      lines << reader.read_line
      lines << reader.read_line
      lines << reader.read_line
      assert_equal 'include target:: include-file.asciidoc', lines.last
      assert_equal 'include-file.asciidoc: line 2', reader.line_info
      while reader.has_more_lines?
        lines << reader.read_line
      end
      source = lines * ::Asciidoctor::EOL
      assert_match(/^include target:: include-file.asciidoc$/, source)
      assert_match(/^middle line$/, source)
    end

    test 'should invoke treeprocessors after parsing document' do
      input = <<-EOS
= Document Title
Doc Writer

content
      EOS

      begin
        Asciidoctor::Extensions.register do
          treeprocessor ReplaceAuthorTreeprocessor
        end

        doc = document_from_string input
        assert_equal 'Ghost Writer', doc.author
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke postprocessors after rendering document' do
      input = <<-EOS
* one
* two
* three
      EOS

      begin
        Asciidoctor::Extensions.register do
          postprocessor StripAttributesPostprocessor
        end

        output = render_string input
        refute_match(/<div class="ulist">/, output)
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke processor for custom block' do
      input = <<-EOS
[yell]
Hi there!
      EOS

      begin
        Asciidoctor::Extensions.register do
          block UppercaseBlock
        end

        output = render_embedded_string input
        assert_xpath '//p', output, 1
        assert_xpath '//p[text()="HI THERE!"]', output, 1
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke processor for custom block macro' do
      input = <<-EOS
snippet::12345[]
      EOS

      begin
        Asciidoctor::Extensions.register do
          block_macro SnippetMacro, :snippet
        end

        output = render_embedded_string input
        assert output.include?('<script src="http://example.com/12345.js"></script>')
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke processor for custom inline macro' do
      begin
        Asciidoctor::Extensions.register do
          inline_macro TemperatureMacro, :degrees
        end

        output = render_embedded_string 'Room temperature is degrees:25[C].', :attributes => {'temperature-unit' => 'F'}
        assert output.include?('Room temperature is 25.0 &#176;C.')

        output = render_embedded_string 'Room temperature is degrees:25[].', :attributes => {'temperature-unit' => 'F'}
        assert output.include?('Room temperature is 77.0 &#176;F.')
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should not carry over attributes if block processor returns nil' do
      begin
        Asciidoctor::Extensions.register do
          block do
            named :skip
            on_context :paragraph
            parse_content_as :raw
            process do |parent, reader, attrs|
              nil
            end
          end
        end
        input = <<-EOS
.unused title
[skip]
not rendered

--
rendered
--
        EOS
        doc = document_from_string input
        assert_equal 1, doc.blocks.size
        assert_nil doc.blocks[0].attributes['title']
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should pass attributes by value to block processor' do
      begin
        Asciidoctor::Extensions.register do
          block do
            named :foo
            on_context :paragraph
            parse_content_as :raw
            process do |parent, reader, attrs|
              original_attrs = attrs.dup
              attrs.delete('title')
              create_paragraph parent, reader.read_lines, original_attrs.merge('id' => 'value')
            end
          end
        end
        input = <<-EOS
.title
[foo]
content
        EOS
        doc = document_from_string input
        assert_equal 1, doc.blocks.size
        assert_equal 'title', doc.blocks[0].attributes['title']
        assert_equal 'value', doc.blocks[0].id
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end
  end
end
