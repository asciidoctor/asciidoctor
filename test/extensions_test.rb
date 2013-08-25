require 'test_helper'
require 'asciidoctor/extensions'

class SamplePreprocessor < Asciidoctor::Extensions::Preprocessor
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
  def process reader, lines
    while !lines.empty? && !lines.first.start_with?('=')
      lines.shift
      reader.advance
    end
    #lines
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
  def process
    @document.attributes['firstname'] = 'Ghost'
    @document.attributes['author'] = 'Ghost Writer'
  end
end

class StripAttributesPostprocessor < Asciidoctor::Extensions::Postprocessor
  def process output
    output.gsub(/<(\w+).*?>/m, "<\\1>")
  end
end

class UppercaseBlock < Asciidoctor::Extensions::BlockProcessor
  def process parent, reader, attributes
    Asciidoctor::Block.new parent, :paragraph, :source => reader.lines.map {|line| line.upcase }
  end
end

class SnippetMacro < Asciidoctor::Extensions::BlockMacroProcessor
  def process parent, target, attributes
    Asciidoctor::Block.new parent, :pass, :content_model => :raw, :source => %(<script src="http://example.com/#{target}.js"></script>)
  end
end

class TemperatureMacro < Asciidoctor::Extensions::InlineMacroProcessor
  def process parent, target, attributes
    temperature_unit = @document.attr('temperature-unit', 'C')
    c = target.to_f
    if temperature_unit == 'C'
      text = %(#{c} &#176;C)
    elsif temperature_unit == 'F'
      f = c * 1.8 + 32 
      text = %(#{f} &#176;F)
    else
      text = target
    end

    text
  end
end

class SampleExtension < Asciidoctor::Extensions::Extension
  def self.activate(registry, document)
    document.attributes['activate-method-called'] = ''
    registry.preprocessor SamplePreprocessor
  end
end

context 'Extensions' do
  context 'Register' do
    test 'should register extension class' do
      begin
        Asciidoctor::Extensions.register SampleExtension
        assert_not_nil Asciidoctor::Extensions.registered
        assert_equal 1, Asciidoctor::Extensions.registered.size
        assert_equal SampleExtension, Asciidoctor::Extensions.registered.first
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should be able to self register extension class' do
      begin
        SampleExtension.register
        assert_not_nil Asciidoctor::Extensions.registered
        assert_equal 1, Asciidoctor::Extensions.registered.size
        assert_equal SampleExtension, Asciidoctor::Extensions.registered.first
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should register extension class from string' do
      begin
        Asciidoctor::Extensions.register 'SampleExtension'
        assert_not_nil Asciidoctor::Extensions.registered
        assert_equal 1, Asciidoctor::Extensions.registered.size
        assert_equal SampleExtension, Asciidoctor::Extensions.registered.first
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should register extension block' do
      begin
        Asciidoctor::Extensions.register do |document|
        end
        assert_not_nil Asciidoctor::Extensions.registered
        assert_equal 1, Asciidoctor::Extensions.registered.size
        assert Asciidoctor::Extensions.registered.first.is_a?(Proc)
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should get class for top-level class name' do
      clazz = Asciidoctor::Extensions.class_for_name('Asciidoctor')
      assert_not_nil clazz
      assert_equal Asciidoctor, clazz
    end

    test 'should get class for class name in module' do
      clazz = Asciidoctor::Extensions.class_for_name('Asciidoctor::Extensions')
      assert_not_nil clazz
      assert_equal Asciidoctor::Extensions, clazz
    end

    test 'should get class for class name resolved from root' do
      clazz = Asciidoctor::Extensions.class_for_name('::Asciidoctor::Extensions')
      assert_not_nil clazz
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
      assert_not_nil clazz
      assert_equal Asciidoctor::Extensions, clazz
    end

    test 'should resolve class if class from string' do
      clazz = Asciidoctor::Extensions.resolve_class('Asciidoctor::Extensions')
      assert_not_nil clazz
      assert_equal Asciidoctor::Extensions, clazz
    end
  end

  context 'Activate' do
    test 'should call activate on extension class' do
      begin
        doc = Asciidoctor::Document.new
        Asciidoctor::Extensions.register SampleExtension
        registry = Asciidoctor::Extensions::Registry.new doc
        assert doc.attr? 'activate-method-called'
        assert registry.preprocessors?
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke extension block' do
      begin
        doc = Asciidoctor::Document.new
        Asciidoctor::Extensions.register do |document|
          document.attributes['block-called'] = ''
          preprocessor SamplePreprocessor
        end
        registry = Asciidoctor::Extensions::Registry.new doc
        assert doc.attr? 'block-called'
        assert registry.preprocessors?
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should create registry in Document if extensions are loaded' do
      begin
        SampleExtension.register
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
      assert registry.preprocessors?
      processors = registry.load_preprocessors Asciidoctor::Document.new
      assert_equal 1, processors.size
      assert processors.first.is_a? SamplePreprocessor
    end

    test 'should instantiate include processors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.include_processor SampleIncludeProcessor
      assert registry.include_processors?
      processors = registry.load_include_processors Asciidoctor::Document.new
      assert_equal 1, processors.size
      assert processors.first.is_a? SampleIncludeProcessor
    end

    test 'should instantiate treeprocessors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.treeprocessor SampleTreeprocessor
      assert registry.treeprocessors?
      processors = registry.load_treeprocessors Asciidoctor::Document.new
      assert_equal 1, processors.size
      assert processors.first.is_a? SampleTreeprocessor
    end

    test 'should instantiate postprocessors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.postprocessor SamplePostprocessor
      assert registry.postprocessors?
      processors = registry.load_postprocessors Asciidoctor::Document.new
      assert_equal 1, processors.size
      assert processors.first.is_a? SamplePostprocessor
    end

    test 'should instantiate block processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block :sample, SampleBlock
      assert registry.blocks?
      assert registry.processor_registered_for_block? :sample, :paragraph
      processor = registry.load_block_processor :sample, Asciidoctor::Document.new
      assert processor.is_a? SampleBlock
    end

    test 'should not match block processor for unsupported context' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block :sample, SampleBlock
      assert !(registry.processor_registered_for_block? :sample, :sidebar)
    end

    test 'should instantiate block macro processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block_macro 'sample', SampleBlockMacro
      assert registry.block_macros?
      assert registry.processor_registered_for_block_macro? 'sample'
      processor = registry.load_block_macro_processor 'sample', Asciidoctor::Document.new
      assert processor.is_a? SampleBlockMacro
    end

    test 'should instantiate inline macro processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.inline_macro 'sample', SampleInlineMacro
      assert registry.inline_macros?
      assert registry.processor_registered_for_inline_macro? 'sample'
      processor = registry.load_inline_macro_processor 'sample', Asciidoctor::Document.new
      assert processor.is_a? SampleInlineMacro
    end

    test 'should allow processors to be registered by a string name' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.preprocessor 'SamplePreprocessor'
      assert registry.preprocessors?
      processors = registry.load_preprocessors Asciidoctor::Document.new
      assert_equal 1, processors.size
      assert processors.first.is_a? SamplePreprocessor
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
        Asciidoctor::Extensions.register do |document|
          preprocessor ScrubHeaderPreprocessor
        end

        doc = document_from_string input
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
        Asciidoctor::Extensions.register do |document|
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

    test 'should invoke treeprocessors after parsing document' do
      input = <<-EOS
= Document Title
Doc Writer

content
      EOS

      begin
        Asciidoctor::Extensions.register do |document|
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
        Asciidoctor::Extensions.register do |document|
          postprocessor StripAttributesPostprocessor
        end

        output = render_string input
        assert_no_match(/<div class="ulist">/, output)
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
        Asciidoctor::Extensions.register do |document|
          block :yell, UppercaseBlock
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
        Asciidoctor::Extensions.register do |document|
          block_macro :snippet, SnippetMacro
        end

        output = render_embedded_string input
        assert output.include?('<script src="http://example.com/12345.js"></script>')
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke processor for custom inline macro' do
      input = <<-EOS
Room temperature is degrees:25[].
      EOS

      begin
        Asciidoctor::Extensions.register do |document|
          inline_macro :degrees, TemperatureMacro
        end

        output = render_embedded_string input, :attributes => {'temperature-unit' => 'F'}
        assert output.include?('Room temperature is 77.0 &#176;F.')
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end
  end
end
