# frozen_string_literal: true

require_relative 'test_helper'

context 'Stem Interpreter' do
  test 'should set stem_interpreter property on document if stem attribute is set and basebackend is html' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, parse: true
    assert doc.basebackend? 'html'
    refute_nil doc.stem_interpreter
    assert_kind_of Asciidoctor::StemInterpreter, doc.stem_interpreter
  end

  test 'should set stem_interpreter property on document if stem attribute is not set and basebackend is html' do
    doc = document_from_string '', safe: :safe, parse: true
    assert_equal 'mathjax2', doc.stem_interpreter.name
  end

  test 'should not set stem_interpreter property on document if basebackend is not html' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, backend: 'docbook', parse: true
    refute doc.basebackend? 'html'
    assert_nil doc.stem_interpreter
  end

  test 'should use mathjax2 interpreter by default when stem attribute is set' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, parse: true
    assert_equal 'mathjax2', doc.stem_interpreter.name
  end

  test 'should use mathjax2 interpreter when stem-interpreter attribute is not set regardless of stem value' do
    [
      { 'stem' => '' },
      { 'stem' => 'asciimath' },
      { 'stem' => 'latexmath' },
    ].each do |attributes|
      doc = document_from_string '', safe: :safe, attributes: attributes, parse: true
      assert_equal 'mathjax2', doc.stem_interpreter.name
    end
  end

  test 'should use interpreter specified by stem-interpreter attribute' do
    Class.new do
      include Asciidoctor::StemInterpreter
      register_for 'katex'

      def convert node, opts = {}
        node.block? ? node.content : node.text
      end

      def format node, opts = {}
        %(<div class="stemblock katex">#{convert node}</div>)
      end
    end

    input = ':stem:'
    doc = document_from_string input, safe: :safe, attributes: { 'stem' => '', 'stem-interpreter' => 'katex' }, parse: true
    assert_equal 'katex', doc.stem_interpreter.name
  ensure
    Asciidoctor::StemInterpreter.register nil, 'katex'
  end

  test 'should fall back to mathjax2 if stem-interpreter attribute specifies unknown interpreter' do
    input = ':stem:'
    doc = document_from_string input, safe: :safe, attributes: { 'stem' => '', 'stem-interpreter' => 'unknown' }, parse: true
    assert_equal 'mathjax2', doc.stem_interpreter.name
  end

  test 'should fall back to mathjax2 if custom factory does not provide stem interpreter' do
    factory = Asciidoctor::StemInterpreter::CustomFactory.new
    doc = document_from_string '', safe: :safe, stem_interpreter_factory: factory, parse: true
    assert_equal 'mathjax2', doc.stem_interpreter.name
  end

  test 'should use stem interpreter from :stem_interpreter_factory option' do
    interpreter = Class.new do
      include Asciidoctor::StemInterpreter
    end
    factory = Asciidoctor::StemInterpreter::CustomFactory.new 'custom' => interpreter
    doc = document_from_string '', safe: :safe, stem_interpreter_factory: factory, attributes: { 'stem-interpreter' => 'custom' }, parse: true
    assert_kind_of interpreter, doc.stem_interpreter
  end

  test 'should use stem interpreter from :stem_interpreters option' do
    interpreter = Class.new do
      include Asciidoctor::StemInterpreter
    end
    doc = document_from_string '', safe: :safe, stem_interpreters: { 'custom' => interpreter }, attributes: { 'stem-interpreter' => 'custom' }, parse: true
    assert_kind_of interpreter, doc.stem_interpreter
  end

  test 'should be able to register stem interpreter from interpreter class itself' do
    interpreter = Class.new do
      include Asciidoctor::StemInterpreter

      def convert node, opts = {}; end

      def format node, opts = {}; end
    end

    interpreter.register_for 'myinterpreter'
    assert_equal interpreter, (Asciidoctor::StemInterpreter.for 'myinterpreter')
  ensure
    Asciidoctor::StemInterpreter.register nil, 'myinterpreter'
  end

  test 'should propagate stem_interpreter from parent document to child document' do
    input = <<~'EOS'
    :stem:

    |===
    a|
    stem:[x^2]
    |===
    EOS
    doc = document_from_string input, safe: :safe, parse: true
    table_cell_doc = (doc.find_by context: :table_cell)[0].inner_document
    refute_nil table_cell_doc.stem_interpreter
    assert_equal doc.stem_interpreter.name, table_cell_doc.stem_interpreter.name
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

    test 'should convert stem block and inline stem using mathjax2 interpreter if stem attribute is not set' do
      input = <<~'EOS'
      [latexmath]
      ++++
      x^2
      ++++

      Use latexmath:[y^2] in your formula.
      EOS
      output = convert_string input, safe: :safe
      assert_includes output, '\[x^2\]'
      assert_includes output, '\(y^2\)'
      assert_css 'script[src*="MathJax.js"]', output, 0
    end

    test 'should not inject MathJax script if extension unsets stem attribute' do
      input = <<~'EOS'
      :stem:

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string input, safe: :safe, extension_registry: Asciidoctor::Extensions.create {
        tree_processor do
          process do |doc|
            doc.remove_attr 'stem'
            nil
          end
        end
      }
      assert_css '.stemblock', output, 1
      assert_css 'script[src*="MathJax.js"]', output, 0
    end

    test 'should convert stem nodes when document has not been processed for html backend' do
      doc = empty_document
      block = Asciidoctor::Block.new doc, :stem, source: 'x^2'
      block.style = 'latexmath'
      inline = Asciidoctor::Inline.new doc, :quoted, 'y^2', type: :latexmath
      converter = Asciidoctor::Converter.create 'html5'
      assert_nil doc.stem_interpreter
      assert_includes (converter.convert block, 'stem'), '\[x^2\]'
      assert_equal '\(y^2\)', (converter.convert inline, 'inline_quoted')
    end

    test 'should add id and role to inline stem' do
      doc = empty_document
      inline = Asciidoctor::Inline.new doc, :quoted, 'x^2', type: :latexmath, id: 'eq', attributes: { 'role' => 'formula' }
      assert_equal '<span id="eq" class="formula">\(x^2\)</span>', ((Asciidoctor::Converter.create 'html5').convert inline, 'inline_quoted')
    end

    test 'should split multiline asciimath block using self-closing br tag if htmlsyntax is xml' do
      input = <<~'EOS'
      :stem:

      [stem]
      ++++
      x^2

      y^2
      ++++
      EOS
      output = convert_string_to_embedded input, safe: :safe, backend: 'xhtml5'
      assert_includes output, %(\\$x^2\\$\n<br/>\n\\$y^2\\$)
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

  context 'Custom Interpreter' do
    test 'should call format on custom interpreter for stem block' do
      Class.new do
        include Asciidoctor::StemInterpreter
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
      :stem-interpreter: katex

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_css '.stemblock.katex', output, 1
      assert_includes output, '$x^2$'
    ensure
      Asciidoctor::StemInterpreter.register nil, 'katex'
    end

    test 'should call convert on custom interpreter for inline stem macro' do
      Class.new do
        include Asciidoctor::StemInterpreter
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
      :stem-interpreter: katex

      Use stem:[x^2] here.
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_includes output, '$x^2$'
    ensure
      Asciidoctor::StemInterpreter.register nil, 'katex'
    end

    test 'should inject custom interpreter docinfo in head and footer' do
      Class.new do
        include Asciidoctor::StemInterpreter
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
      :stem-interpreter: katex

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string input, safe: :safe
      assert_css 'head > link[href*="katex.min.css"]', output, 1
      assert_css 'body > script[src*="katex.min.js"]', output, 1
    ensure
      Asciidoctor::StemInterpreter.register nil, 'katex'
    end

    test 'should inject custom interpreter docinfo in head when syntax highlighter has no head docinfo' do
      Class.new do
        include Asciidoctor::StemInterpreter
        register_for 'katex'

        def docinfo? location
          location == :head
        end

        def docinfo location, doc, opts
          %(<link rel="stylesheet" href="https://cdn.example.org/katex/katex.min.css">)
        end
      end

      syntax_hl = Class.new Asciidoctor::SyntaxHighlighter::Base do
        register_for 'nohead'
      end

      input = <<~'EOS'
      :stem:
      :stem-interpreter: katex
      :source-highlighter: nohead
      EOS
      output = convert_string input, safe: :safe
      assert_css 'head > link[href*="katex.min.css"]', output, 1
      assert_kind_of syntax_hl, (document_from_string input, safe: :safe).syntax_highlighter
    ensure
      Asciidoctor::StemInterpreter.register nil, 'katex'
      Asciidoctor::SyntaxHighlighter.register nil, 'nohead'
    end

    test 'should inject custom interpreter docinfo only in footer if head docinfo is not defined' do
      Class.new do
        include Asciidoctor::StemInterpreter
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
      :stem-interpreter: katex

      [stem]
      ++++
      x^2
      ++++
      EOS
      output = convert_string input, safe: :safe
      assert_css 'head > script', output, 0
      assert_css 'body > script[src*="katex.min.js"]', output, 1
    ensure
      Asciidoctor::StemInterpreter.register nil, 'katex'
    end
  end
end
