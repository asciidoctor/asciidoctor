# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

class ExtensionsInitTest < Minitest::Test
  def test_autoload
    doc = empty_document
    refute doc.extensions?, 'Extensions should not be enabled by default'

    begin
      # NOTE trigger extensions to autoload by registering empty group
      Asciidoctor::Extensions.register do
      end
    rescue; end

    doc = empty_document
    assert doc.extensions?, 'Extensions should be enabled after being autoloaded'

    self.class.remove_tests self.class
  ensure
    Asciidoctor::Extensions.unregister_all
  end
  self
end.new(nil).test_autoload

class SamplePreprocessor < Asciidoctor::Extensions::Preprocessor
  def process doc, reader
    nil
  end
end

class SampleIncludeProcessor < Asciidoctor::Extensions::IncludeProcessor
end

class SampleDocinfoProcessor < Asciidoctor::Extensions::DocinfoProcessor
end

# NOTE intentionally using the deprecated name
class SampleTreeprocessor < Asciidoctor::Extensions::Treeprocessor
  def process document
    nil
  end
end
SampleTreeProcessor = SampleTreeprocessor

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

  def process document, reader, target, attributes
    case target
    when 'lorem-ipsum.txt'
      content = ["Lorem ipsum dolor sit amet...\n"]
      reader.push_include content, target, target, 1, attributes
    else
      nil
    end
  end
end

class ReplaceAuthorTreeProcessor < Asciidoctor::Extensions::TreeProcessor
  def process document
    document.attributes['firstname'] = 'Ghost'
    document.attributes['author'] = 'Ghost Writer'
    document
  end
end

class ReplaceTreeTreeProcessor < Asciidoctor::Extensions::TreeProcessor
  def process document
    if document.doctitle == 'Original Document'
      Asciidoctor.load %(== Replacement Document\nReplacement Author\n\ncontent)
    else
      document
    end
  end
end

class StripAttributesPostprocessor < Asciidoctor::Extensions::Postprocessor
  def process document, output
    output.gsub(/<(\w+).*?>/m, "<\\1>")
  end
end

class UppercaseBlock < Asciidoctor::Extensions::BlockProcessor; use_dsl
  named :yell
  bound_to :paragraph
  parses_content_as :simple
  def process parent, reader, attributes
    create_paragraph parent, reader.lines.map(&:upcase), attributes
  end
end

class SnippetMacro < Asciidoctor::Extensions::BlockMacroProcessor
  def process parent, target, attributes
    create_pass_block parent, %(<script src="http://example.com/#{target}.js?_mode=#{attributes['mode']}"></script>), {}, :content_model => :raw
  end
end

class TemperatureMacro < Asciidoctor::Extensions::InlineMacroProcessor; use_dsl
  named :degrees
  resolves_attributes '1:units', 'precision=1'
  def process parent, target, attributes
    units = attributes['units'] || (parent.document.attr 'temperature-unit', 'C')
    precision = attributes['precision'].to_i
    c = target.to_f
    case units
    when 'C'
      %(#{round_with_precision c, precision} &#176;C)
    when 'F'
      %(#{round_with_precision c * 1.8 + 32, precision} &#176;F)
    else
      raise ::ArgumentError, %(Unknown temperature units: #{units})
    end
  end

  if (::Numeric.instance_method :round).arity == 0
    def round_with_precision value, precision = 0
      if precision == 0
        value.round
      else
        factor = 10 ** precision
        if precision < 0
          (value * factor).round.div factor
        else
          (value * factor).round.fdiv factor
        end
      end
    end
  else
    def round_with_precision value, precision = 0
      value.round precision
    end
  end
end

class MetaRobotsDocinfoProcessor < Asciidoctor::Extensions::DocinfoProcessor
  def process document
    '<meta name="robots" content="index,follow">'
  end
end

class MetaAppDocinfoProcessor < Asciidoctor::Extensions::DocinfoProcessor; use_dsl
  at_location :head

  def process document
    '<meta name="application-name" content="Asciidoctor App">'
  end
end

class SampleExtensionGroup < Asciidoctor::Extensions::Group
  def activate registry
    registry.document.attributes['activate-method-called'] = ''
    registry.preprocessor SamplePreprocessor
  end
end

def create_cat_in_sink_block_macro
  Asciidoctor::Extensions.create do
    block_macro do
      named :cat_in_sink
      process do |parent, target, attrs|
        image_attrs = {}
        unless target.nil_or_empty?
          image_attrs['target'] = %(cat-in-sink-day-#{target}.png)
        end
        if (alt = attrs.delete 1)
          image_attrs['alt'] = alt
        end
        create_image_block parent, image_attrs
      end
    end
  end
end

context 'Extensions' do
  context 'Register' do
    test 'should not activate registry if no extension groups are registered' do
      assert defined? Asciidoctor::Extensions
      doc = empty_document
      refute doc.extensions?, 'Extensions should not be enabled if not groups are registered'
    end

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
        assert_kind_of SampleExtensionGroup, Asciidoctor::Extensions.groups[:sample]
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should register extension block' do
      begin
        Asciidoctor::Extensions.register :sample do
        end
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        assert_kind_of Proc, Asciidoctor::Extensions.groups[:sample]
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should coerce group name to symbol when registering' do
      begin
        Asciidoctor::Extensions.register 'sample', SampleExtensionGroup
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        assert_equal SampleExtensionGroup, Asciidoctor::Extensions.groups[:sample]
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should unregister extension group by symbol name' do
      begin
        Asciidoctor::Extensions.register :sample, SampleExtensionGroup
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        Asciidoctor::Extensions.unregister :sample
        assert_equal 0, Asciidoctor::Extensions.groups.size
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should unregister extension group by string name' do
      begin
        Asciidoctor::Extensions.register :sample, SampleExtensionGroup
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 1, Asciidoctor::Extensions.groups.size
        Asciidoctor::Extensions.unregister 'sample'
        assert_equal 0, Asciidoctor::Extensions.groups.size
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should unregister multiple extension groups by name' do
      begin
        Asciidoctor::Extensions.register :sample1, SampleExtensionGroup
        Asciidoctor::Extensions.register :sample2, SampleExtensionGroup
        refute_nil Asciidoctor::Extensions.groups
        assert_equal 2, Asciidoctor::Extensions.groups.size
        Asciidoctor::Extensions.unregister :sample1, :sample2
        assert_equal 0, Asciidoctor::Extensions.groups.size
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should get class for top-level class name' do
      clazz = Asciidoctor::Extensions.class_for_name 'String'
      refute_nil clazz
      assert_equal String, clazz
    end

    test 'should get class for class name in module' do
      clazz = Asciidoctor::Extensions.class_for_name 'Asciidoctor::Document'
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should get class for class name resolved from root' do
      clazz = Asciidoctor::Extensions.class_for_name '::Asciidoctor::Document'
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should raise exception if cannot find class for name' do
      begin
        Asciidoctor::Extensions.class_for_name 'InvalidModule::InvalidClass'
        flunk 'Expecting RuntimeError to be raised'
      rescue NameError => e
        assert_equal 'Could not resolve class for name: InvalidModule::InvalidClass', e.message
      end
    end

    test 'should raise exception if constant name is invalid' do
      begin
        Asciidoctor::Extensions.class_for_name 'foobar'
        flunk 'Expecting RuntimeError to be raised'
      rescue NameError => e
        assert_equal 'Could not resolve class for name: foobar', e.message
      end
    end

    test 'should raise exception if class not found in scope' do
      begin
        Asciidoctor::Extensions.class_for_name 'Asciidoctor::Extensions::String'
        flunk 'Expecting RuntimeError to be raised'
      rescue NameError => e
        assert_equal 'Could not resolve class for name: Asciidoctor::Extensions::String', e.message
      end
    end

    test 'should raise exception if name resolves to module' do
      begin
        Asciidoctor::Extensions.class_for_name 'Asciidoctor::Extensions'
        flunk 'Expecting RuntimeError to be raised'
      rescue NameError => e
        assert_equal 'Could not resolve class for name: Asciidoctor::Extensions', e.message
      end
    end

    test 'should resolve class if class is given' do
      clazz = Asciidoctor::Extensions.resolve_class Asciidoctor::Document
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should resolve class if class from string' do
      clazz = Asciidoctor::Extensions.resolve_class 'Asciidoctor::Document'
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should not resolve class if not in scope' do
      begin
        Asciidoctor::Extensions.resolve_class 'Asciidoctor::Extensions::String'
        flunk 'Expecting RuntimeError to be raised'
      rescue NameError => e
        assert_equal 'Could not resolve class for name: Asciidoctor::Extensions::String', e.message
      end
    end

    test 'should raise NameError if extension class cannot be resolved from string' do
      begin
        Asciidoctor::Extensions.register do
          block 'foobar'
        end
        empty_document
        flunk 'Expecting RuntimeError to be raised'
      rescue NameError => e
        assert_equal 'Could not resolve class for name: foobar', e.message
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should allow standalone registry to be created but not registered' do
      registry = Asciidoctor::Extensions.create 'sample' do
        block do
          named :whisper
          bound_to :paragraph
          parses_content_as :simple
          def process parent, reader, attributes
            create_paragraph parent, reader.lines.map(&:downcase), attributes
          end
        end
      end

      assert_instance_of Asciidoctor::Extensions::Registry, registry
      refute_nil registry.groups
      assert_equal 1, registry.groups.size
      assert_equal 'sample', registry.groups.keys.first
      assert_equal 0, Asciidoctor::Extensions.groups.size
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
        assert_kind_of Asciidoctor::Extensions::Registry, doc.extensions
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
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extensions.first
      assert_kind_of SamplePreprocessor, extensions.first.instance
      assert_kind_of Method, extensions.first.process_method
    end

    test 'should instantiate include processors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.include_processor SampleIncludeProcessor
      registry.activate Asciidoctor::Document.new
      assert registry.include_processors?
      extensions = registry.include_processors
      assert_equal 1, extensions.size
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extensions.first
      assert_kind_of SampleIncludeProcessor, extensions.first.instance
      assert_kind_of Method, extensions.first.process_method
    end

    test 'should instantiate docinfo processors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.docinfo_processor SampleDocinfoProcessor
      registry.activate Asciidoctor::Document.new
      assert registry.docinfo_processors?
      assert registry.docinfo_processors?(:head)
      extensions = registry.docinfo_processors
      assert_equal 1, extensions.size
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extensions.first
      assert_kind_of SampleDocinfoProcessor, extensions.first.instance
      assert_kind_of Method, extensions.first.process_method
    end

    # NOTE intentionally using the legacy names
    test 'should instantiate tree processors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.treeprocessor SampleTreeprocessor
      registry.activate Asciidoctor::Document.new
      assert registry.treeprocessors?
      extensions = registry.treeprocessors
      assert_equal 1, extensions.size
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extensions.first
      assert_kind_of SampleTreeprocessor, extensions.first.instance
      assert_kind_of Method, extensions.first.process_method
    end

    test 'should instantiate postprocessors' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.postprocessor SamplePostprocessor
      registry.activate Asciidoctor::Document.new
      assert registry.postprocessors?
      extensions = registry.postprocessors
      assert_equal 1, extensions.size
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extensions.first
      assert_kind_of SamplePostprocessor, extensions.first.instance
      assert_kind_of Method, extensions.first.process_method
    end

    test 'should instantiate block processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block SampleBlock, :sample
      registry.activate Asciidoctor::Document.new
      assert registry.blocks?
      assert registry.registered_for_block? :sample, :paragraph
      extension = registry.find_block_extension :sample
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extension
      assert_kind_of SampleBlock, extension.instance
      assert_kind_of Method, extension.process_method
    end

    test 'should not match block processor for unsupported context' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block SampleBlock, :sample
      registry.activate Asciidoctor::Document.new
      refute registry.registered_for_block? :sample, :sidebar
    end

    test 'should instantiate block macro processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.block_macro SampleBlockMacro, 'sample'
      registry.activate Asciidoctor::Document.new
      assert registry.block_macros?
      assert registry.registered_for_block_macro? 'sample'
      extension = registry.find_block_macro_extension 'sample'
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extension
      assert_kind_of SampleBlockMacro, extension.instance
      assert_kind_of Method, extension.process_method
    end

    test 'should instantiate inline macro processor' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.inline_macro SampleInlineMacro, 'sample'
      registry.activate Asciidoctor::Document.new
      assert registry.inline_macros?
      assert registry.registered_for_inline_macro? 'sample'
      extension = registry.find_inline_macro_extension 'sample'
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extension
      assert_kind_of SampleInlineMacro, extension.instance
      assert_kind_of Method, extension.process_method
    end

    test 'should allow processors to be registered by a string name' do
      registry = Asciidoctor::Extensions::Registry.new
      registry.preprocessor 'SamplePreprocessor'
      registry.activate Asciidoctor::Document.new
      assert registry.preprocessors?
      extensions = registry.preprocessors
      assert_equal 1, extensions.size
      assert_kind_of Asciidoctor::Extensions::ProcessorExtension, extensions.first
    end
  end

  context 'Integration' do
    test 'can provide extension registry as an option' do
      registry = Asciidoctor::Extensions.create do
        tree_processor SampleTreeProcessor
      end

      doc = document_from_string %(= Document Title\n\ncontent), :extension_registry => registry
      refute_nil doc.extensions
      assert_equal 1, doc.extensions.groups.size
      assert doc.extensions.tree_processors?
      assert_equal 1, doc.extensions.tree_processors.size
      assert_equal 0, Asciidoctor::Extensions.groups.size
    end

    # NOTE I'm not convinced we want to continue to support this use case
    test 'can provide extension registry created without any groups as option' do
      registry = Asciidoctor::Extensions.create
      registry.tree_processor SampleTreeProcessor

      doc = document_from_string %(= Document Title\n\ncontent), :extension_registry => registry
      refute_nil doc.extensions
      assert_equal 0, doc.extensions.groups.size
      assert doc.extensions.tree_processors?
      assert_equal 1, doc.extensions.tree_processors.size
      assert_equal 0, Asciidoctor::Extensions.groups.size
    end

    test 'can provide extensions proc as option' do
      doc = document_from_string %(= Document Title\n\ncontent), :extensions => proc {
        tree_processor SampleTreeProcessor
      }
      refute_nil doc.extensions
      assert_equal 1, doc.extensions.groups.size
      assert doc.extensions.tree_processors?
      assert_equal 1, doc.extensions.tree_processors.size
      assert_equal 0, Asciidoctor::Extensions.groups.size
    end

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
        assert_includes result, 'before'
        assert_includes result, 'Lorem ipsum'
        assert_includes result, 'after'
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

      registry = Asciidoctor::Extensions.create do
        include_processor do
          handles? do |target|
            target == 'include-file.asciidoc'
          end

          process do |doc, reader, target, attributes|
            # demonstrate that push_include normalizes endlines
            content = ["include target:: #{target}\n", "\n", "middle line\n"]
            reader.push_include content, target, target, 1, attributes
          end
        end
      end
      # Safe Mode is not required here
      document = empty_document :base_dir => testdir, :extension_registry => registry
      reader = Asciidoctor::PreprocessorReader.new document, input, nil, :normalize => true
      lines = []
      lines << reader.read_line
      lines << reader.read_line
      lines << reader.read_line
      assert_equal 'include target:: include-file.asciidoc', lines.last
      assert_equal 'include-file.asciidoc: line 2', reader.line_info
      while reader.has_more_lines?
        lines << reader.read_line
      end
      source = lines * ::Asciidoctor::LF
      assert_match(/^include target:: include-file.asciidoc$/, source)
      assert_match(/^middle line$/, source)
    end

    test 'should invoke tree processors after parsing document' do
      input = <<-EOS
= Document Title
Doc Writer

content
      EOS

      begin
        Asciidoctor::Extensions.register do
          tree_processor ReplaceAuthorTreeProcessor
        end

        doc = document_from_string input
        assert_equal 'Ghost Writer', doc.author
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should set source_location on document before invoking tree processors' do
      begin
        Asciidoctor::Extensions.register do
          tree_processor do
            process do |doc|
              para = create_paragraph doc.blocks.last.parent, %(file: #{doc.file}, lineno: #{doc.lineno}), {}
              doc << para
            end
          end
        end

        sample_doc = fixture_path 'sample.asciidoc'
        doc = Asciidoctor.load_file sample_doc, :sourcemap => true
        assert_includes doc.convert, 'file: sample.asciidoc, lineno: 1'
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should allow tree processor to replace tree' do
      input = <<-EOS
= Original Document
Doc Writer

content
      EOS

      begin
        Asciidoctor::Extensions.register do
          tree_processor ReplaceTreeTreeProcessor
        end

        doc = document_from_string input
        assert_equal 'Replacement Document', doc.doctitle
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should honor block title assigned in tree processor' do
      input = <<-EOS
= Document Title
:!example-caption:

.Old block title
====
example block content
====
      EOS

      old_title = nil
      begin
        Asciidoctor::Extensions.register do
          tree_processor do
            process do |doc|
              ex = (doc.find_by :context => :example)[0]
              old_title = ex.title
              ex.title = 'New block title'
            end
          end
        end

        doc = document_from_string input
        assert_equal 'Old block title', old_title
        assert_equal 'New block title', (doc.find_by :context => :example)[0].title
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

    test 'should invoke processor for custom block in an AsciiDoc table cell' do
      input = <<-EOS
|===
a|
[yell]
Hi there!
|===
      EOS

      begin
        Asciidoctor::Extensions.register do
          block UppercaseBlock
        end

        output = render_embedded_string input
        assert_xpath '/table//p', output, 1
        assert_xpath '/table//p[text()="HI THERE!"]', output, 1
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should pass cloaked context in attributes passed to process method of custom block' do
      input = <<-EOS
[custom]
****
sidebar
****
      EOS

      cloaked_context = nil
      begin
        Asciidoctor::Extensions.register do
          block :custom do
            on_context :sidebar
            process do |doc, reader, attrs|
              cloaked_context = attrs['cloaked-context']
              nil
            end
          end
        end

        render_embedded_string input
        assert_equal :sidebar, cloaked_context
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke processor for custom block macro' do
      input = <<-EOS
snippet::12345[mode=edit]
      EOS

      begin
        Asciidoctor::Extensions.register do
          block_macro SnippetMacro, :snippet
        end

        output = render_embedded_string input
        assert_includes output, '<script src="http://example.com/12345.js?_mode=edit"></script>'
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke processor for custom block macro in an AsciiDoc table cell' do
      input = <<-EOS
|===
a|message::hi[]
|===
      EOS

      begin
        Asciidoctor::Extensions.register do
          block_macro :message do
            process do |parent, target, attrs|
              create_paragraph parent, target.upcase, {}
            end
          end
        end

        output = render_embedded_string input
        assert_xpath '/table//p[text()="HI"]', output, 1
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should match short form of block macro' do
      input = <<-EOS
custom-toc::[]
      EOS

      resolved_target = nil

      begin
        Asciidoctor::Extensions.register do
          block_macro do
            named 'custom-toc'
            process do |parent, target, attrs|
              resolved_target = target
              create_pass_block parent, '<!-- custom toc goes here -->', {}, :content_model => :raw
            end
          end
        end

        output = render_embedded_string input
        assert_equal '<!-- custom toc goes here -->', output
        assert_equal '', resolved_target
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke processor for custom inline macro' do
      begin
        Asciidoctor::Extensions.register do
          inline_macro TemperatureMacro, :deg
        end

        output = render_embedded_string 'Room temperature is deg:25[C,precision=0].', :attributes => { 'temperature-unit' => 'F' }
        assert_includes output, 'Room temperature is 25 &#176;C.'

        output = render_embedded_string 'Normal body temperature is deg:37[].', :attributes => { 'temperature-unit' => 'F' }
        assert_includes output, 'Normal body temperature is 98.6 &#176;F.'
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should resolve regexp for inline macro lazily' do
      begin
        Asciidoctor::Extensions.register do
          inline_macro do
            named :label
            with_format :short
            resolves_attributes false
            process do |parent, target|
              %(<label>#{target}</label>)
            end
          end
        end

        output = render_embedded_string 'label:[Checkbox]'
        assert_includes output, '<label>Checkbox</label>'
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should assign captures correctly for inline macros' do
      begin
        Asciidoctor::Extensions.register do
          inline_macro do
            named :short_attributes
            with_format :short
            resolves_attributes '1:name'
            process do |parent, target, attrs|
              %(target=#{target.inspect}, attributes=#{attrs.sort_by {|k, _| k.to_s }.inspect})
            end
          end

          inline_macro do
            named :short_text
            with_format :short
            resolves_attributes false
            process do |parent, target, attrs|
              %(target=#{target.inspect}, attributes=#{attrs.sort_by {|k, _| k.to_s }.inspect})
            end
          end

          inline_macro do
            named :'full-attributes'
            resolves_attributes '1:name' => nil
            process do |parent, target, attrs|
              %(target=#{target.inspect}, attributes=#{attrs.sort_by {|k, _| k.to_s }.inspect})
            end
          end

          inline_macro do
            named :'full-text'
            resolves_attributes false
            process do |parent, target, attrs|
              %(target=#{target.inspect}, attributes=#{attrs.sort_by {|k, _| k.to_s }.inspect})
            end
          end

          inline_macro do
            named :@short_match
            matching %r/@(\w+)/
            resolves_attributes false
            process do |parent, target, attrs|
              %(target=#{target.inspect}, attributes=#{attrs.sort_by {|k, _| k.to_s }.inspect})
            end
          end
        end

        input = <<-EOS
[subs=normal]
++++
short_attributes:[]
short_attributes:[value,key=val]
short_text:[]
short_text:[[text\\]]
full-attributes:target[]
full-attributes:target[value,key=val]
full-text:target[]
full-text:target[[text\\]]
@target
++++
        EOS
        expected = <<-EOS.chomp
target="", attributes=[]
target="value,key=val", attributes=[[1, "value"], ["key", "val"], ["name", "value"]]
target="", attributes=[["text", ""]]
target="[text]", attributes=[["text", "[text]"]]
target="target", attributes=[]
target="target", attributes=[[1, "value"], ["key", "val"], ["name", "value"]]
target="target", attributes=[["text", ""]]
target="target", attributes=[["text", "[text]"]]
target="target", attributes=[]
        EOS
        output = render_embedded_string input
        assert_equal expected, output
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should invoke convert on return value if value is an inline node' do
      begin
        Asciidoctor::Extensions.register do
          inline_macro do
            named :mention
            resolves_attributes false
            process do |parent, target, attrs|
              if (text = attrs['text']).empty?
                text = %(@#{target})
              end
              create_anchor parent, text, :type => :link, :target => %(https://github.com/#{target})
            end
          end
        end

        output = render_embedded_string 'mention:mojavelinux[Dan]'
        assert_includes output, '<a href="https://github.com/mojavelinux">Dan</a>'
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'wip should not carry over attributes if block processor returns nil' do
      begin
        Asciidoctor::Extensions.register do
          block do
            named 'skip-me'
            on_context :paragraph
            parses_content_as :raw
            process do |parent, reader, attrs|
              nil
            end
          end
        end
        input = <<-EOS
.unused title
[skip-me]
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

    test 'should not invoke process method or carry over attributes if block processor declares skip content model' do
      begin
        process_method_called = false
        Asciidoctor::Extensions.register do
          block do
            named :ignore
            on_context :paragraph
            parses_content_as :skip
            process do |parent, reader, attrs|
              process_method_called = true
              nil
            end
          end
        end
        input = <<-EOS
.unused title
[ignore]
not rendered

--
rendered
--
        EOS
        doc = document_from_string input
        refute process_method_called
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
            parses_content_as :raw
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

    test 'parse_content should not share attributes between parsed blocks' do
      begin
        Asciidoctor::Extensions.register do
          block do
            named :wrap
            on_context :open
            process do |parent, reader, attrs|
              wrap = create_open_block parent, nil, attrs
              parse_content wrap, reader.read_lines
            end
          end
        end
        input = <<-EOS
[wrap]
--
[foo=bar]
====
content
====

[baz=qux]
====
content
====
--
        EOS
        doc = document_from_string input
        assert_equal 1, doc.blocks.size
        wrap = doc.blocks[0]
        assert_equal 2, wrap.blocks.size
        assert_equal 2, wrap.blocks[0].attributes.size
        assert_equal 2, wrap.blocks[1].attributes.size
        assert_nil wrap.blocks[1].attributes['foo']
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'create_section should set up all section properties' do
      begin
        sect = nil
        Asciidoctor::Extensions.register do
          block_macro do
            named :sect
            process do |parent, target, attrs|
              opts = (level = attrs.delete 'level') ? { :level => level.to_i } : {}
              attrs['id'] = false if attrs['id'] == 'false'
              parent = parent.parent if parent.context == :preamble
              sect = create_section parent, 'Section Title', attrs, opts
              nil
            end
          end
        end

        input_tpl = <<-EOS
= Document Title
:doctype: book
:sectnums:

sect::[%s]
        EOS

        {
          ''                       => ['chapter',  1, false, true, '_section_title'],
          'level=0'                => ['part',     0, false, false, '_section_title'],
          'level=0,alt'            => ['part',     0, false, true, '_section_title', { 'partnums' => '' }],
          'level=0,style=appendix' => ['appendix', 1, true,  true, '_section_title'],
          'style=appendix'         => ['appendix', 1, true,  true, '_section_title'],
          'style=glossary'         => ['glossary', 1, true,  false, '_section_title'],
          'style=glossary,alt'     => ['glossary', 1, true,  :chapter, '_section_title', { 'sectnums' => 'all' }],
          'style=abstract'         => ['chapter',  1, false, true, '_section_title'],
          'id=section-title'       => ['chapter',  1, false, true, 'section-title'],
          'id=false'               => ['chapter',  1, false, true, nil]
        }.each do |attrlist, (expect_sectname, expect_level, expect_special, expect_numbered, expect_id, extra_attrs)|
          input = input_tpl % attrlist
          document_from_string input, :safe => :server, :attributes => extra_attrs
          assert_equal expect_sectname, sect.sectname
          assert_equal expect_level, sect.level
          assert_equal expect_special, sect.special
          assert_equal expect_numbered, sect.numbered
          if expect_id
            assert_equal expect_id, sect.id
          else
            assert_nil sect.id
          end
        end
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should add docinfo to document' do
      input = <<-EOS
= Document Title

sample content
      EOS

      begin
        Asciidoctor::Extensions.register do
          docinfo_processor MetaRobotsDocinfoProcessor
        end

        doc = document_from_string input, :safe => :server
        assert_equal '<meta name="robots" content="index,follow">', doc.docinfo
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should add multiple docinfo to document' do
      input = <<-EOS
= Document Title

sample content
      EOS

      begin
        Asciidoctor::Extensions.register do
          docinfo_processor MetaAppDocinfoProcessor
          docinfo_processor MetaRobotsDocinfoProcessor, :position => :>>
          docinfo_processor do
            at_location :footer
            process do |doc|
              '<script><!-- analytics code --></script>'
            end
          end
        end

        doc = document_from_string input, :safe => :server
        assert_equal '<meta name="robots" content="index,follow">
<meta name="application-name" content="Asciidoctor App">', doc.docinfo
        assert_equal '<script><!-- analytics code --></script>', doc.docinfo(:footer)
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should append docinfo to document' do
      begin
        Asciidoctor::Extensions.register do
          docinfo_processor MetaRobotsDocinfoProcessor
        end
        sample_input_path = fixture_path('basic.asciidoc')

        output = Asciidoctor.convert_file sample_input_path, :to_file => false,
                                          :header_footer => true,
                                          :safe => Asciidoctor::SafeMode::SERVER,
                                          :attributes => {'docinfo' => ''}
        refute_empty output
        assert_css 'script[src="modernizr.js"]', output, 1
        assert_css 'meta[name="robots"]', output, 1
        assert_css 'meta[http-equiv="imagetoolbar"]', output, 0
      ensure
        Asciidoctor::Extensions.unregister_all
      end
    end

    test 'should raise an exception if mandatory target attribute is not provided for image block' do
      input = <<-EOS
.Cat in Sink?
cat_in_sink::[]
      EOS
      exception = assert_raises ArgumentError do
        render_embedded_string input, :extension_registry => create_cat_in_sink_block_macro
      end
      assert_match(/target attribute is required/, exception.message)
    end

    test 'should assign alt attribute to image block if alt is not provided' do
      input = <<-EOS
.Cat in Sink?
cat_in_sink::25[]
      EOS
      doc = document_from_string input, :header_footer => false, :extension_registry => create_cat_in_sink_block_macro
      image = doc.blocks[0]
      assert_equal 'cat in sink day 25', (image.attr 'alt')
      assert_equal 'cat in sink day 25', (image.attr 'default-alt')
      output = doc.convert
      assert_includes output, '<img src="cat-in-sink-day-25.png" alt="cat in sink day 25">'
    end

    test 'should create an image block if mandatory attributes are provided' do
      input = <<-EOS
.Cat in Sink?
cat_in_sink::30[cat in sink (yes)]
      EOS
      doc = document_from_string input, :header_footer => false, :extension_registry => create_cat_in_sink_block_macro
      image = doc.blocks[0]
      assert_equal 'cat in sink (yes)', (image.attr 'alt')
      refute(image.attr? 'default-alt')
      output = doc.convert
      assert_includes output, '<img src="cat-in-sink-day-30.png" alt="cat in sink (yes)">'
    end
  end
end
