# encoding: UTF-8
require 'test_helper'

context "Text" do
  test "proper encoding to handle utf8 characters in document using html backend" do
    output = example_document(:encoding).render
    assert_xpath '//p', output, 4
    assert_xpath '//a', output, 1
  end

  test "proper encoding to handle utf8 characters in embedded document using html backend" do
    output = example_document(:encoding, :header_footer => false).render
    assert_xpath '//p', output, 4
    assert_xpath '//a', output, 1
  end

  test "proper encoding to handle utf8 characters in document using docbook backend" do
    output = example_document(:encoding, :attributes => {'backend' => 'docbook'}).render
    assert_xpath '//xmlns:simpara', output, 4
    assert_xpath '//xmlns:ulink', output, 1
  end

  test "proper encoding to handle utf8 characters in embedded document using docbook backend" do
    output = example_document(:encoding, :header_footer => false, :attributes => {'backend' => 'docbook'}).render
    assert_xpath '//simpara', output, 4
    assert_xpath '//ulink', output, 1
  end

  # NOTE this test ensures we have the encoding line on block templates too
  test 'proper encoding to handle utf8 characters in arbitrary block' do
    input = []
    input << "[verse]\n"
    input.concat(File.readlines(sample_doc_path(:encoding)))
    doc = empty_document
    reader = Asciidoctor::PreprocessorReader.new doc, input
    block = Asciidoctor::Lexer.next_block(reader, doc)
    assert_xpath '//pre', block.render.gsub(/^\s*\n/, ''), 1
  end

  test 'proper encoding to handle utf8 characters from included file' do
    input = <<-EOS
include::fixtures/encoding.asciidoc[tags=romé]
    EOS
    doc = empty_safe_document :base_dir => File.expand_path(File.dirname(__FILE__))
    reader = Asciidoctor::PreprocessorReader.new doc, input
    block = Asciidoctor::Lexer.next_block(reader, doc)
    output = block.render
    assert_css '.paragraph', output, 1
  end

  test 'escaped text markup' do
    assert_match(/All your &lt;em&gt;inline&lt;\/em&gt; markup belongs to &lt;strong&gt;us&lt;\/strong&gt;!/,
        render_string('All your <em>inline</em> markup belongs to <strong>us</strong>!'))
  end

  test "line breaks" do
    assert_xpath "//br", render_string("Well this is +\njust fine and dandy, isn't it?"), 1
  end

  test "single- and double-quoted text" do
    rendered = render_string("``Where?,'' she said, flipping through her copy of `The New Yorker.'")
    assert_match(/&#8220;Where\?,&#8221;/, rendered)
    assert_match(/&#8216;The New Yorker.&#8217;/, rendered)
  end

  test 'horizontal rule' do
    input = <<-EOS
This line is separated by a horizontal rule...

'''

...from this line.
    EOS
    output = render_embedded_string input
    assert_xpath "//hr", output, 1
    assert_xpath "/*[@class='paragraph']", output, 2
    assert_xpath "(/*[@class='paragraph'])[1]/following-sibling::hr", output, 1
    assert_xpath "/hr/following-sibling::*[@class='paragraph']", output, 1
  end

  test 'markdown horizontal rules' do
    variants = [
      '---',
      '- - -',
      '***',
      '* * *',
      '___',
      '_ _ _'
    ]

    offsets = [
      '',
      ' ',
      '  ',
      '   '
    ]

    variants.each do |variant|
      offsets.each do |offset|
        input = <<-EOS
This line is separated by a horizontal rule...

#{offset}#{variant}

...from this line.
        EOS
        output = render_embedded_string input
        assert_xpath "//hr", output, 1
        assert_xpath "/*[@class='paragraph']", output, 2
        assert_xpath "(/*[@class='paragraph'])[1]/following-sibling::hr", output, 1
        assert_xpath "/hr/following-sibling::*[@class='paragraph']", output, 1
      end
    end
  end

  test 'markdown horizontal rules negative case' do

    bad_variants = [
      '- - - -',
      '* * * *',
      '_ _ _ _'
    ]

    good_offsets = [
      '',
      ' ',
      '  ',
      '   '
    ]

    bad_variants.each do |variant|
      good_offsets.each do |offset|
        input = <<-EOS
This line is separated something that is not a horizontal rule...

#{offset}#{variant}

...from this line.
        EOS
        output = render_embedded_string input
        assert_xpath '//hr', output, 0
      end
    end

    good_variants = [
      '- - -',
      '* * *',
      '_ _ _'
    ]

    bad_offsets = [
      "\t",
      '    '
    ]

    good_variants.each do |variant|
      bad_offsets.each do |offset|
        input = <<-EOS
This line is separated something that is not a horizontal rule...

#{offset}#{variant}

...from this line.
        EOS
        output = render_embedded_string input
        assert_xpath '//hr', output, 0
      end
    end
  end

  test "emphasized text" do
    assert_xpath "//em", render_string("An 'emphatic' no")
  end

  test "emphasized text with single quote" do
    assert_xpath "//em[text()=\"Johnny#{[8217].pack('U*')}s\"]", render_string("It's 'Johnny's' phone")
  end

  test "emphasized text with escaped single quote" do
    assert_xpath "//em[text()=\"Johnny's\"]", render_string("It's 'Johnny\\'s' phone")
  end

  test "escaped single quote is restored as single quote" do
    assert_xpath "//p[contains(text(), \"Let's do it!\")]", render_string("Let\\'s do it!")
  end

  test "emphasized text at end of line" do
    assert_xpath "//em", render_string("This library is 'awesome'")
  end

  test "emphasized text at beginning of line" do
    assert_xpath "//em", render_string("'drop' it")
  end

  test "emphasized text across line" do
    assert_xpath "//em", render_string("'check it'")
  end

  test "unquoted text" do
    assert_no_match(/#/, render_string("An #unquoted# word"))
  end

  test "backtick-escaped text followed by single-quoted text" do
    assert_match(/<code>foo<\/code>/, render_string(%Q(run `foo` 'dog')))
  end

  context "basic styling" do
    setup do
      @rendered = render_string("A *BOLD* word.  An _italic_ word.  A +mono+ word.  ^superscript!^ and some ~subscript~.")
    end

    test "strong" do
      assert_xpath "//strong", @rendered
    end

    test "italic" do
      assert_xpath "//em", @rendered
    end

    test "monospaced" do
      assert_xpath "//code", @rendered
    end

    test "superscript" do
      assert_xpath "//sup", @rendered
    end

    test "subscript" do
      assert_xpath "//sub", @rendered
    end

    test "backticks" do
      assert_xpath "//code", render_string("This is `totally cool`.")
    end

    test "nested styles" do
      rendered = render_string("Winning *big _time_* in the +city *boyeeee*+.")

      assert_xpath "//strong/em", rendered
      assert_xpath "//code/strong", rendered
    end

    test "unconstrained quotes" do
      rendered_chars = render_string("**B**__I__++M++")
      assert_xpath "//strong", rendered_chars
      assert_xpath "//em", rendered_chars
      assert_xpath "//code", rendered_chars
    end
  end
end
