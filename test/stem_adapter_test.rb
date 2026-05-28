# frozen_string_literal: true

require_relative 'test_helper'

context 'Stem Adapter' do
  test 'should set stem_adapter property on document if stem attribute is set and basebackend is html' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, parse: true
    assert doc.basebackend? 'html'
    refute_nil doc.stem_adapter
    assert_kind_of Asciidoctor::StemAdapter, doc.stem_adapter
  end

  test 'should not set stem_adapter property on document if stem attribute is not set' do
    doc = document_from_string '', safe: :safe, parse: true
    assert_nil doc.stem_adapter
  end

  test 'should not set stem_adapter property on document if basebackend is not html' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, backend: 'docbook', parse: true
    refute doc.basebackend? 'html'
    assert_nil doc.stem_adapter
  end

  test 'should use mathjax adapter by default when stem attribute is set' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, parse: true
    assert_equal 'mathjax', doc.stem_adapter.name
  end

  test 'should use mathjax adapter when stem-adapter attribute is not set regardless of stem value' do
    [
      { 'stem' => '' },
      { 'stem' => 'asciimath' },
      { 'stem' => 'latexmath' },
    ].each do |attributes|
      doc = document_from_string '', safe: :safe, attributes: attributes, parse: true
      assert_equal 'mathjax', doc.stem_adapter.name
    end
  end

  test 'should use adapter specified by stem-adapter attribute' do
    Class.new do
      include Asciidoctor::StemAdapter
      register_for 'katex'

      def convert node, opts = {}
        node.block? ? node.content : node.text
      end

      def format node, opts = {}
        %(<div class="stemblock katex">#{convert node}</div>)
      end
    end

    input = ':stem:'
    doc = document_from_string input, safe: :safe, attributes: { 'stem' => '', 'stem-adapter' => 'katex' }, parse: true
    assert_equal 'katex', doc.stem_adapter.name
  ensure
    Asciidoctor::StemAdapter.register nil, 'katex'
  end

  test 'should fall back to mathjax if stem-adapter attribute specifies unknown adapter' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, attributes: { 'stem' => '', 'stem-adapter' => 'unknown' }, parse: true
    assert_equal 'mathjax', doc.stem_adapter.name
  end

  test 'should be able to register stem adapter from adapter class itself' do
    adapter = Class.new do
      include Asciidoctor::StemAdapter

      def convert node, opts = {}; end

      def format node, opts = {}; end
    end

    adapter.register_for 'myadapter'
    assert_equal adapter, (Asciidoctor::StemAdapter.for 'myadapter')
  ensure
    Asciidoctor::StemAdapter.register nil, 'myadapter'
  end

  test 'should propagate stem_adapter from parent document to child document' do
    input = <<~'EOS'
    :stem:

    |===
    a|
    stem:[x^2]
    |===
    EOS
    doc = document_from_string input, safe: :safe, parse: true
    table_cell_doc = (doc.find_by context: :table_cell)[0].inner_document
    refute_nil table_cell_doc.stem_adapter
    assert_equal doc.stem_adapter.name, table_cell_doc.stem_adapter.name
  end

  context 'MathJax' do
    test 'should inject MathJax script in footer when stem attribute is set' do
      input = ':stem:'
      output = convert_string input, safe: :safe
      assert_css 'body > script[src*="MathJax.js"]', output, 1
    end

    test 'should not inject MathJax script when stem attribute is not set' do
      output = convert_string '', safe: :safe
      assert_css 'script[src*="MathJax.js"]', output, 0
    end

    test 'should inject MathJax config script before MathJax script' do
      input = ':stem:'
      output = convert_string input, safe: :safe
      assert_xpath '//script[@type="text/x-mathjax-config"]', output, 1
      assert_css 'script[type="text/x-mathjax-config"] ~ script[src*="MathJax.js"]', output, 1
    end

    test 'should use eqnums AMS if eqnums attribute is set to empty' do
      input = <<~'EOS'
      :stem:
      :eqnums:
      EOS
      output = convert_string input, safe: :safe
      assert_includes output, 'autoNumber: "AMS"'
    end

    test 'should use custom eqnums value if eqnums attribute is set' do
      input = <<~'EOS'
      :stem:
      :eqnums: all
      EOS
      output = convert_string input, safe: :safe
      assert_includes output, 'autoNumber: "all"'
    end

    test 'should wrap stem block content in asciimath delimiters by default' do
      input = <<~'EOS'
      :stem:

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
      assert_equal '\$x^2\$', nodes.first.to_s.strip
    end

    test 'should wrap stem block content in latexmath delimiters when stem is latexmath' do
      input = <<~'EOS'
      :stem: latexmath

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
      assert_equal '\[x^2\]', nodes.first.to_s.strip
    end

    test 'should wrap inline stem macro content in asciimath delimiters' do
      input = <<~'EOS'
      :stem:

      Use stem:[x^2] in your formula.
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_includes output, '\$x^2\$'
    end

    test 'should wrap inline latexmath macro content in latexmath delimiters' do
      input = <<~'EOS'
      :stem: latexmath

      Use stem:[x^2] in your formula.
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_includes output, '\(x^2\)'
    end
  end

  context 'Custom Adapter' do
    test 'should call format on custom adapter for stem block' do
      Class.new do
        include Asciidoctor::StemAdapter
        register_for 'katex'

        def convert node, opts = {}
          %($#{node.content}$)
        end

        def format node, opts = {}
          %(<div class="stemblock katex">#{convert node}</div>)
        end
      end

      input = <<~'EOS'
      :stem:
      :stem-adapter: katex

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_css '.stemblock.katex', output, 1
      assert_includes output, '$x^2$'
    ensure
      Asciidoctor::StemAdapter.register nil, 'katex'
    end

    test 'should call convert on custom adapter for inline stem macro' do
      Class.new do
        include Asciidoctor::StemAdapter
        register_for 'katex'

        def convert node, opts = {}
          node.block? ? %($#{node.content}$) : %($#{node.text}$)
        end

        def format node, opts = {}
          %(<div class="stemblock katex">#{convert node}</div>)
        end
      end

      input = <<~'EOS'
      :stem:
      :stem-adapter: katex

      Use stem:[x^2] here.
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_includes output, '$x^2$'
    ensure
      Asciidoctor::StemAdapter.register nil, 'katex'
    end

    test 'should inject custom adapter docinfo in head and footer' do
      Class.new do
        include Asciidoctor::StemAdapter
        register_for 'katex'

        def docinfo? location
          location == :head || location == :footer
        end

        def docinfo location, doc, opts
          if location == :head
            %(<link rel="stylesheet" href="https://cdn.example.org/katex/katex.min.css">)
          else
            %(<script src="https://cdn.example.org/katex/katex.min.js"></script>)
          end
        end

        def convert node, opts = {}
          node.block? ? node.content : node.text
        end

        def format node, opts = {}
          %(<div class="stemblock">#{convert node}</div>)
        end
      end

      input = <<~'EOS'
      :stem:
      :stem-adapter: katex

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string input, safe: :safe
      assert_css 'head > link[href*="katex.min.css"]', output, 1
      assert_css 'body > script[src*="katex.min.js"]', output, 1
    ensure
      Asciidoctor::StemAdapter.register nil, 'katex'
    end

    test 'should inject custom adapter docinfo only in footer if head docinfo is not defined' do
      Class.new do
        include Asciidoctor::StemAdapter
        register_for 'katex'

        def docinfo? location
          location == :footer
        end

        def docinfo location, doc, opts
          %(<script src="https://cdn.example.org/katex/katex.min.js"></script>)
        end

        def convert node, opts = {}
          node.block? ? node.content : node.text
        end

        def format node, opts = {}
          %(<div class="stemblock">#{convert node}</div>)
        end
      end

      input = <<~'EOS'
      :stem:
      :stem-adapter: katex

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string input, safe: :safe
      assert_css 'head > script', output, 0
      assert_css 'body > script[src*="katex.min.js"]', output, 1
    ensure
      Asciidoctor::StemAdapter.register nil, 'katex'
    end
  end
end
