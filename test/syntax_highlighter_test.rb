require_relative 'test_helper'

context 'Syntax Highlighter' do
  test 'should set syntax_highlighter property on document if source highlighter is set and basebackend is html' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source, ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    doc = document_from_string input, safe: :safe, parse: true
    assert doc.basebackend? 'html'
    refute_nil doc.syntax_highlighter
    assert_kind_of Asciidoctor::SyntaxHighlighter, doc.syntax_highlighter
  end

  test 'should not set syntax_highlighter property on document if source highlighter is not set' do
    input = <<~'EOS'
    [source, ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    doc = document_from_string input, safe: :safe, parse: true
    assert_nil doc.syntax_highlighter
  end

  test 'should not set syntax_highlighter property on document if syntax highlighter cannot be found' do
    input = <<~'EOS'
    :source-highlighter: unknown

    [source, ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    doc = document_from_string input, safe: :safe, parse: true
    assert_nil doc.syntax_highlighter
  end

  test 'should not set syntax_highlighter property on document if basebackend is not html' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source, ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    doc = document_from_string input, safe: :safe, backend: 'docbook', parse: true
    refute doc.basebackend? 'html'
    assert_nil doc.syntax_highlighter
  end

  test 'should not allow document to enable syntax highlighter if safe mode is at least SERVER' do
    input = ':source-highlighter: coderay'
    doc = document_from_string input, safe: Asciidoctor::SafeMode::SERVER, parse: true
    assert_nil doc.attributes['source-highlighter']
    assert_nil doc.syntax_highlighter
  end

  test 'should set language on source block output when source-highlighter attribute is not set' do
    input = <<~'EOS'
    [source, ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    output = convert_string input, safe: Asciidoctor::SafeMode::SAFE
    assert_css 'pre.highlight', output, 1
    assert_css 'pre.highlight > code.language-ruby', output, 1
    assert_css 'pre.highlight > code.language-ruby[data-lang="ruby"]', output, 1
  end

  test 'should set language on source block output when source-highlighter attribute is not recognized' do
    input = <<~'EOS'
    :source-highlighter: unknown

    [source, ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    output = convert_string input, safe: Asciidoctor::SafeMode::SAFE
    assert_css 'pre.highlight', output, 1
    assert_css 'pre.highlight > code.language-ruby', output, 1
    assert_css 'pre.highlight > code.language-ruby[data-lang="ruby"]', output, 1
  end

  test 'should highlight source if source-highlighter attribute is coderay' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source, ruby]
    ----
    require 'coderay'

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table
    ----
    EOS
    output = convert_string input, safe: Asciidoctor::SafeMode::SAFE, linkcss_default: true
    assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
    assert_match(/\.CodeRay *\{/, output)
  end

  test 'should highlight source if source highlighter is set even if language is not set' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source%linenums]
    ----
    [numbers]
    one
    two
    three
    ----
    EOS
    output = convert_string input, safe: :safe
    assert_css 'pre.CodeRay.highlight', output, 1
    assert_css 'pre.CodeRay.highlight td.line-numbers', output, 1
    assert_includes output, '<code>'
  end

  test 'should not crash if source block has no lines and source highlighter is set' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source,text]
    ----
    ----
    EOS
    output = convert_string_to_embedded input, safe: :safe
    assert_css 'pre.CodeRay', output, 1
    assert_css 'pre.CodeRay > code', output, 1
    assert_css 'pre.CodeRay > code:empty', output, 1
  end

  test 'should highlight source inside AsciiDoc table cell if source-highlighter attribute is coderay' do
    input = <<~'EOS'
    :source-highlighter: coderay

    |===
    a|
    [source, ruby]
    ----
    require 'coderay'

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table
    ----
    |===
    EOS
    output = convert_string_to_embedded input, safe: :safe
    assert_xpath '/table//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
  end

  test 'should number lines if third positional attribute is set' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source,ruby,linenums]
    ----
    puts 'Hello, World!'
    ----
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    assert_xpath '//td[@class="line-numbers"]', output, 1
  end

  test 'should number lines if linenums option is set on source block' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source%linenums,ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    assert_xpath '//td[@class="line-numbers"]', output, 1
  end

  test 'should number lines of source block if source-linenums-option document attribute is set' do
    input = <<~'EOS'
    :source-highlighter: coderay
    :source-linenums-option:

    [source,ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    assert_xpath '//td[@class="line-numbers"]', output, 1
  end

  test 'should set starting line number in HTML output if linenums option is enabled and start attribute is set' do
    input = <<~'EOS'
    :source-highlighter: coderay
    :coderay-linenums-mode: inline

    [source%linenums,ruby,start=10]
    ----
    puts 'Hello, World!'
    ----
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    assert_xpath '//span[@class="line-numbers"]', output, 1
    assert_xpath '//span[@class="line-numbers"][text()="10"]', output, 1
  end

  test 'should set starting line number in DocBook output if linenums option is enabled and start attribute is set' do
    input = <<~'EOS'
    [source%linenums,java,start=3]
    ----
    public class HelloWorld {
      public static void main(String[] args) {
        out.println("Hello, World!");
      }
    }
    ----
    EOS

    output = convert_string_to_embedded input, backend: :docbook, safe: Asciidoctor::SafeMode::SAFE
    assert_css 'programlisting[startinglinenumber]', output, 1
    assert_css 'programlisting[startinglinenumber="3"]', output, 1
  end

  test 'should highlight lines specified in highlight attribute if linenums is set and source-highlighter is coderay' do
    %w(highlight="1,4-6" highlight=1;4..6 highlight=1;4..;!7).each do |highlight_attr|
      input = <<~EOS
      :source-highlighter: coderay

      [source%linenums,java,#{highlight_attr}]
      ----
      import static java.lang.System.out;

      public class HelloWorld {
        public static void main(String[] args) {
          out.println("Hello, World!");
        }
      }
      ----
      EOS
      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
      assert_css 'strong.highlighted', output, 4
      assert_xpath '//strong[@class="highlighted"][text()="1"]', output, 1
      assert_xpath '//strong[@class="highlighted"][text()="2"]', output, 0
      assert_xpath '//strong[@class="highlighted"][text()="3"]', output, 0
      assert_xpath '//strong[@class="highlighted"][text()="4"]', output, 1
      assert_xpath '//strong[@class="highlighted"][text()="5"]', output, 1
      assert_xpath '//strong[@class="highlighted"][text()="6"]', output, 1
      assert_xpath '//strong[@class="highlighted"][text()="7"]', output, 0
    end
  end

  test 'should read source language from source-language document attribute if not specified on source block' do
    input = <<~'EOS'
    :source-highlighter: coderay
    :source-language: ruby

    [source]
    ----
    require 'coderay'

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table
    ----
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE, linkcss_default: true
    assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
  end

  test 'should rename document attribute named language to source-language when compat-mode is enabled' do
    input = <<~'EOS'
    :language: ruby

    {source-language}
    EOS

    assert_equal 'ruby', (convert_inline_string input, attributes: { 'compat-mode' => '' })

    input = <<~'EOS'
    :language: ruby

    {source-language}
    EOS

    assert_equal '{source-language}', (convert_inline_string input)
  end

  test 'should replace callout marks but not highlight them if source-highlighter attribute is coderay' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source, ruby]
    ----
    require 'coderay' # <1>

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table # <2>
    puts html # <3> <4>
    exit 0 # <5><6>
    ----
    <1> Load library
    <2> Highlight source
    <3> Print to stdout
    <4> Redirect to a file to capture output
    <5> Exit program
    <6> Reports success
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    assert_match(/<span class="content">coderay<\/span>.* # <b class="conum">\(1\)<\/b>$/, output)
    assert_match(/<span class="content">puts 'Hello, world!'<\/span>.* # <b class="conum">\(2\)<\/b>$/, output)
    assert_match(/puts html.* # <b class="conum">\(3\)<\/b> <b class="conum">\(4\)<\/b>$/, output)
    assert_match(/exit.* # <b class="conum">\(5\)<\/b> <b class="conum">\(6\)<\/b><\/code>/, output)
  end

  test 'should support autonumbered callout marks if source-highlighter attribute is coderay' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source, ruby]
    ----
    require 'coderay' # <.><.>

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table # <.>
    puts html # <.>
    ----
    <.> Load library
    <.> Gem must be installed
    <.> Highlight source
    <.> Print to stdout
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    assert_match(/<span class="content">coderay<\/span>.* # <b class="conum">\(1\)<\/b> <b class="conum">\(2\)<\/b>$/, output)
    assert_match(/<span class="content">puts 'Hello, world!'<\/span>.* # <b class="conum">\(3\)<\/b>$/, output)
    assert_match(/puts html.* # <b class="conum">\(4\)<\/b><\/code>/, output)
    assert_css '.colist ol', output, 1
    assert_css '.colist ol li', output, 4
  end

  test 'should restore callout marks to correct lines if source highlighter is coderay and table line numbering is enabled' do
    input = <<~'EOS'
    :source-highlighter: coderay
    :coderay-linenums-mode: table

    [source, ruby, numbered]
    ----
    require 'coderay' # <1>

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table # <2>
    puts html # <3> <4>
    exit 0 # <5><6>
    ----
    <1> Load library
    <2> Highlight source
    <3> Print to stdout
    <4> Redirect to a file to capture output
    <5> Exit program
    <6> Reports success
    EOS
    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    assert_match(/<span class="content">coderay<\/span>.* # <b class="conum">\(1\)<\/b>$/, output)
    assert_match(/<span class="content">puts 'Hello, world!'<\/span>.* # <b class="conum">\(2\)<\/b>$/, output)
    assert_match(/puts html.* # <b class="conum">\(3\)<\/b> <b class="conum">\(4\)<\/b>$/, output)
    # NOTE notice there's a newline before the closing </pre> tag
    assert_match(/exit.* # <b class="conum">\(5\)<\/b> <b class="conum">\(6\)<\/b>\n<\/pre>/, output)
  end

  test 'should restore isolated callout mark on last line of source when source highlighter is coderay' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source,ruby,linenums]
    ----
    require 'app'

    launch_app
    # <1>
    ----
    <1> Profit.
    EOS

    output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE
    # NOTE notice there's a newline before the closing </pre> tag
    assert_match(/\n# <b class="conum">\(1\)<\/b>\n<\/pre>/, output)
  end

  test 'should preserve space before callout on final line' do
    inputs = []

    inputs << <<~'EOS'
    [source,yaml]
    ----
    a: 'a'
    key: 'value' #<1>
    ----
    <1> key-value pair
    EOS

    inputs << <<~'EOS'
    [source,ruby]
    ----
    puts 'hi'
    puts 'value' #<1>
    ----
    <1> print to stdout
    EOS

    inputs << <<~'EOS'
    [source,python]
    ----
    print 'hi'
    print 'value' #<1>
    ----
    <1> print to stdout
    EOS

    inputs.each do |input|
      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'source-highlighter' => 'coderay' }
      output = output.gsub(/<\/?span.*?>/, '')
      assert_includes output, '\'value\' #<b class="conum">(1)</b>'
    end
  end

  test 'should preserve passthrough placeholders when highlighting source using coderay' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source,java]
    [subs="specialcharacters,macros,callouts"]
    ----
    public class Printer {
      public static void main(String[] args) {
        System.pass:quotes[_out_].println("*asterisks* make text pass:quotes[*bold*]");
      }
    }
    ----
    EOS
    output = convert_string input, safe: Asciidoctor::SafeMode::SAFE
    assert_match(/\.<em>out<\/em>\./, output, 1)
    assert_match(/\*asterisks\*/, output, 1)
    assert_match(/<strong>bold<\/strong>/, output, 1)
    refute_includes output, Asciidoctor::Substitutors::PASS_START
  end

  test 'should link to CodeRay stylesheet if source-highlighter is coderay and linkcss is set' do
    input = <<~'EOS'
    :source-highlighter: coderay

    [source, ruby]
    ----
    require 'coderay'

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table
    ----
    EOS
    output = convert_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'linkcss' => '' }
    assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
    assert_css 'link[rel="stylesheet"][href="./coderay-asciidoctor.css"]', output, 1
  end

  test 'should highlight source inline if source-highlighter attribute is coderay and coderay-css is style' do
    input = <<~'EOS'
    :source-highlighter: coderay
    :coderay-css: style

    [source, ruby]
    ----
    require 'coderay'

    html = CodeRay.scan("puts 'Hello, world!'", :ruby).div line_numbers: :table
    ----
    EOS
    output = convert_string input, safe: Asciidoctor::SafeMode::SAFE, linkcss_default: true
    assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@style = "color:#036;font-weight:bold"][text() = "CodeRay"]', output, 1
    refute_match(/\.CodeRay \{/, output)
  end

  test 'should include remote highlight.js assets if source-highlighter attribute is highlight.js' do
    input = <<~'EOS'
    :source-highlighter: highlight.js

    [source, javascript]
    ----
    <link rel="stylesheet" href="styles/default.css">
    <script src="highlight.pack.js"></script>
    <script>hljs.initHighlightingOnLoad();</script>
    ----
    EOS
    output = convert_string input, safe: Asciidoctor::SafeMode::SAFE
    assert_match(/<link .*highlight\.js/, output)
    assert_match(/<script .*highlight\.js/, output)
    assert_match(/hljs.initHighlightingOnLoad/, output)
  end

  test 'should add language-none class to source block when source-highlighter is highlight.js and language is not set' do
    input = <<~'EOS'
    :source-highlighter: highlight.js

    [source]
    ----
    [numbers]
    one
    two
    three
    ----
    EOS
    output = convert_string input, safe: :safe
    assert_css 'code.language-none', output, 1
  end

  test 'should add language classes to child code element when source-highlighter is prettify' do
    input = <<~'EOS'
    [source,ruby]
    ----
    puts "foo"
    ----
    EOS

    output = convert_string_to_embedded input, attributes: { 'source-highlighter' => 'prettify' }
    assert_css 'pre[class="prettyprint highlight"]', output, 1
    assert_css 'pre > code[data-lang="ruby"]', output, 1
  end

  test 'should set linenums start if linenums are enabled and start attribute is set when source-highlighter is prettify' do
    input = <<~'EOS'
    [source%linenums,ruby,start=5]
    ----
    puts "foo"
    ----
    EOS

    output = convert_string_to_embedded input, attributes: { 'source-highlighter' => 'prettify' }
    assert_css 'pre[class="prettyprint highlight linenums:5"]', output, 1
    assert_css 'pre > code[data-lang="ruby"]', output, 1
  end

  test 'should set lang attribute on pre when source-highlighter is html-pipeline' do
    input = <<~'EOS'
    [source,ruby]
    ----
    filters = [
    HTML::Pipeline::AsciiDocFilter,
    HTML::Pipeline::SanitizationFilter,
    HTML::Pipeline::SyntaxHighlightFilter
    ]

    puts HTML::Pipeline.new(filters, {}).call(input)[:output]
    ----
    EOS

    output = convert_string input, attributes: { 'source-highlighter' => 'html-pipeline' }
    assert_css 'pre[lang="ruby"]', output, 1
    assert_css 'pre[lang="ruby"] > code', output, 1
    assert_css 'pre[class]', output, 0
    assert_css 'code[class]', output, 0
  end

  test 'should not invoke highlight method on syntax highlighter if highlight? is false' do
    Class.new Asciidoctor::SyntaxHighlighter::Base do
      register_for 'unavailable'

      def format node, language, opts
        %(<pre class="highlight"><code class="language-#{language}" data-lang="#{language}">#{node.content}</code></pre>)
      end

      def highlight?
        false
      end
    end

    input = <<~'EOS'
    [source,ruby]
    ----
    puts 'Hello, World!'
    ----
    EOS

    doc = document_from_string input, attributes: { 'source-highlighter' => 'unavailable' }
    output = doc.convert
    assert_css 'pre.highlight > code.language-ruby', output, 1
    source_block = (doc.find_by {|candidate| candidate.style == 'source' })[0]
    assert_raises NotImplementedError do
      doc.syntax_highlighter.highlight source_block, source_block.source, (source_block.attr 'language'), {}
    end
  end

  context 'Pygments' do
    test 'should highlight source if source-highlighter attribute is pygments' do
      input = <<~'EOS'
      :source-highlighter: pygments
      :pygments-style: monokai

      [source,python]
      ----
      from pygments import highlight
      from pygments.lexers import PythonLexer
      from pygments.formatters import HtmlFormatter

      source = 'print "Hello World"'
      print(highlight(source, PythonLexer(), HtmlFormatter()))
      ----
      EOS
      output = convert_string input, safe: :safe, linkcss_default: true
      assert_xpath '//pre[@class="pygments highlight"]/code[@data-lang="python"]/span[@class="tok-kn"][text()="import"]', output, 3
      assert_includes output, 'pre.pygments '
    end

    test 'should gracefully fallback to default style if specified style not recognized' do
      input = <<~'EOS'
      :source-highlighter: pygments
      :pygments-style: unknown

      [source,python]
      ----
      from pygments import highlight
      from pygments.lexers import PythonLexer
      from pygments.formatters import HtmlFormatter

      source = 'print "Hello World"'
      print(highlight(source, PythonLexer(), HtmlFormatter()))
      ----
      EOS
      output = convert_string input, safe: :safe, linkcss_default: true
      assert_css 'pre.pygments', output, 1
      assert_includes output, 'pre.pygments '
      assert_includes output, '.tok-c { color: #408080;'
    end

    test 'should restore callout marks to correct lines if source highlighter is pygments and table line numbering is enabled' do
      input = <<~'EOS'
      :source-highlighter: pygments
      :pygments-linenums-mode: table

      [source%linenums,ruby]
      ----
      from pygments import highlight # <1>
      from pygments.lexers import PythonLexer
      from pygments.formatters import HtmlFormatter

      code = 'print "Hello World"'
      print(highlight(code, PythonLexer(), HtmlFormatter())) # <2><3>
      ----
      <1> Load library
      <2> Highlight source
      <3> Print to stdout
      EOS
      output = convert_string_to_embedded input, safe: :safe
      assert_match(/highlight<\/span> # <b class="conum">\(1\)<\/b>$/, output)
      # NOTE notice there's a newline before the closing </pre> tag
      assert_match(/\(\)\)\).*<\/span> # <b class="conum">\(2\)<\/b> <b class="conum">\(3\)<\/b>$/, output)
    end

    test 'should restore isolated callout mark on last line of source when source highlighter is pygments' do
      input = <<~'EOS'
      :source-highlighter: pygments

      [source,ruby,linenums]
      ----
      require 'app'

      launch_app
      # <1>
      ----
      <1> Profit.
      EOS

      output = convert_string_to_embedded input, safe: :safe
      # NOTE notice there's a newline before the closing </pre> tag, but not before the closing </td> tag
      assert_match(/\n# <b class="conum">\(1\)<\/b>\n<\/pre><\/td>/, output)
    end

    test 'should not hardcode inline styles on lineno div and pre elements when linenums are enabled in table mode' do
      input = <<~'EOS'
      :source-highlighter: pygments
      :pygments-css: inline

      [source%linenums,ruby]
      ----
      puts 'Hello, World!'
      ----
      EOS

      output = convert_string_to_embedded input, safe: :safe
      assert_css 'td.linenos', output, 1
      assert_css 'div.linenodiv:not([style])', output, 1
      assert_includes output, '<div class="linenodiv"><pre>'
      assert_css 'pre:not([style])', output, 2
    end

    test 'should not hardcode inline styles on lineno spans when linenums are enabled and source-highlighter is pygments' do
      input = <<~'EOS'
      :source-highlighter: pygments
      :pygments-css: inline
      :pygments-linenums-mode: inline

      [source%linenums,ruby]
      ----
      puts 'Hello, World!'
      puts 'Hello, World!'
      puts 'Hello, World!'
      puts 'Hello, World!'
      puts 'Hello, World!'
      puts 'Hello, World!'
      puts 'Hello, World!'
      puts 'Hello, World!'
      puts 'Hello, World!'
      exit 0
      ----
      EOS

      output = convert_string_to_embedded input, safe: :safe
      assert_includes output, '<span class="lineno"> 1 </span>'
      assert_includes output, '<span class="lineno">10 </span>'
    end
  end if ENV['PYGMENTS']
end
