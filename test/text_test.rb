# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context "Text" do
  test "proper encoding to handle utf8 characters in document using html backend" do
    output = example_document(:encoding).convert
    assert_xpath '//p', output, 4
    assert_xpath '//a', output, 1
  end

  test "proper encoding to handle utf8 characters in embedded document using html backend" do
    output = example_document(:encoding, :header_footer => false).convert
    assert_xpath '//p', output, 4
    assert_xpath '//a', output, 1
  end

  test "proper encoding to handle utf8 characters in document using docbook45 backend" do
    output = example_document(:encoding, :attributes => {'backend' => 'docbook45', 'xmlns' => ''}).convert
    assert_xpath '//xmlns:simpara', output, 4
    assert_xpath '//xmlns:ulink', output, 1
  end

  test "proper encoding to handle utf8 characters in embedded document using docbook45 backend" do
    output = example_document(:encoding, :header_footer => false, :attributes => {'backend' => 'docbook45'}).convert
    assert_xpath '//simpara', output, 4
    assert_xpath '//ulink', output, 1
  end

  # NOTE this test ensures we have the encoding line on block templates too
  test 'proper encoding to handle utf8 characters in arbitrary block' do
    input = []
    input << "[verse]\n"
    input.concat(File.readlines(sample_doc_path(:encoding)))
    doc = empty_document
    reader = Asciidoctor::PreprocessorReader.new doc, input, nil, :normalize => true
    block = Asciidoctor::Parser.next_block(reader, doc)
    assert_xpath '//pre', block.convert.gsub(/^\s*\n/, ''), 1
  end

  test 'proper encoding to handle utf8 characters from included file' do
    input = <<-EOS
include::fixtures/encoding.asciidoc[tags=romé]
    EOS
    doc = empty_safe_document :base_dir => testdir
    reader = Asciidoctor::PreprocessorReader.new doc, input, nil, :normalize => true
    block = Asciidoctor::Parser.next_block(reader, doc)
    output = block.convert
    assert_css '.paragraph', output, 1
  end

  test 'escaped text markup' do
    assert_match(/All your &lt;em&gt;inline&lt;\/em&gt; markup belongs to &lt;strong&gt;us&lt;\/strong&gt;!/,
        convert_string('All your <em>inline</em> markup belongs to <strong>us</strong>!'))
  end

  test "line breaks" do
    assert_xpath "//br", convert_string("Well this is +\njust fine and dandy, isn't it?"), 1
  end

  test 'single- and double-quoted text' do
    output = convert_string_to_embedded(%q(``Where?,'' she said, flipping through her copy of `The New Yorker.'), :attributes => {'compat-mode' => ''})
    assert_match(/&#8220;Where\?,&#8221;/, output)
    assert_match(/&#8216;The New Yorker.&#8217;/, output)

    output = convert_string_to_embedded(%q("`Where?,`" she said, flipping through her copy of '`The New Yorker.`'))
    assert_match(/&#8220;Where\?,&#8221;/, output)
    assert_match(/&#8216;The New Yorker.&#8217;/, output)
  end

  test 'multiple double-quoted text on a single line' do
    assert_equal '&#8220;Our business is constantly changing&#8221; or &#8220;We need faster time to market.&#8221;',
        convert_inline_string(%q(``Our business is constantly changing'' or ``We need faster time to market.''), :attributes => {'compat-mode' => ''})
    assert_equal '&#8220;Our business is constantly changing&#8221; or &#8220;We need faster time to market.&#8221;',
        convert_inline_string(%q("`Our business is constantly changing`" or "`We need faster time to market.`"))
  end

  test 'horizontal rule' do
    input = <<-EOS
This line is separated by a horizontal rule...

'''

...from this line.
    EOS
    output = convert_string_to_embedded input
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
        output = convert_string_to_embedded input
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
This line is separated by something that is not a horizontal rule...

#{offset}#{variant}

...from this line.
        EOS
        output = convert_string_to_embedded input
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
This line is separated by something that is not a horizontal rule...

#{offset}#{variant}

...from this line.
        EOS
        output = convert_string_to_embedded input
        assert_xpath '//hr', output, 0
      end
    end
  end

  test "emphasized text using underscore characters" do
    assert_xpath "//em", convert_string("An _emphatic_ no")
  end

  test 'emphasized text with single quote using apostrophe characters' do
    rsquo = decode_char 8217
    assert_xpath %(//em[text()="Johnny#{rsquo}s"]), convert_string(%q(It's 'Johnny's' phone), :attributes => {'compat-mode' => ''})
    assert_xpath %(//p[text()="It#{rsquo}s 'Johnny#{rsquo}s' phone"]), convert_string(%q(It's 'Johnny's' phone))
  end

  test 'emphasized text with escaped single quote using apostrophe characters' do
    assert_xpath %(//em[text()="Johnny's"]), convert_string(%q(It's 'Johnny\\'s' phone), :attributes => {'compat-mode' => ''})
    assert_xpath %(//p[text()="It's 'Johnny's' phone"]), convert_string(%q(It\\'s 'Johnny\\'s' phone))
  end

  test "escaped single quote is restored as single quote" do
    assert_xpath "//p[contains(text(), \"Let's do it!\")]", convert_string("Let\\'s do it!")
  end

  test 'unescape escaped single quote emphasis in compat mode only' do
    assert_xpath %(//p[text()="A 'single quoted string' example"]), convert_string_to_embedded(%(A \\'single quoted string' example), :attributes => {'compat-mode' => ''})
    assert_xpath %(//p[text()="'single quoted string'"]), convert_string_to_embedded(%(\\'single quoted string'), :attributes => {'compat-mode' => ''})

    assert_xpath %(//p[text()="A \\'single quoted string' example"]), convert_string_to_embedded(%(A \\'single quoted string' example))
    assert_xpath %(//p[text()="\\'single quoted string'"]), convert_string_to_embedded(%(\\'single quoted string'))
  end

  test "emphasized text at end of line" do
    assert_xpath "//em", convert_string("This library is _awesome_")
  end

  test "emphasized text at beginning of line" do
    assert_xpath "//em", convert_string("_drop_ it")
  end

  test "emphasized text across line" do
    assert_xpath "//em", convert_string("_check it_")
  end

  test "unquoted text" do
    refute_match(/#/, convert_string("An #unquoted# word"))
  end

  test 'backticks and straight quotes in text' do
    backslash = '\\'
    assert_equal %q(run <code>foo</code> <em>dog</em>), convert_inline_string(%q(run `foo` 'dog'), :attributes => {'compat-mode' => ''})
    assert_equal %q(run <code>foo</code> 'dog'), convert_inline_string(%q(run `foo` 'dog'))
    assert_equal %q(run `foo` 'dog'), convert_inline_string(%(run #{backslash}`foo` 'dog'))
    assert_equal %q(run &#8216;foo` 'dog&#8217;), convert_inline_string(%q(run '`foo` 'dog`'))
    assert_equal %q(run '`foo` 'dog`'), convert_inline_string(%(run #{backslash}'`foo` 'dog#{backslash}`'))
  end

  test 'plus characters inside single plus passthrough' do
    assert_xpath '//p[text()="+"]', convert_string_to_embedded('+++')
    assert_xpath '//p[text()="+="]', convert_string_to_embedded('++=+')
  end

  test 'plus passthrough escapes entity reference' do
    assert_match(/&amp;#44;/, convert_string_to_embedded('+&#44;+'))
    assert_match(/one&amp;#44;two/, convert_string_to_embedded('one++&#44;++two'))
  end

  context "basic styling" do
    setup do
      @output = convert_string("A *BOLD* word.  An _italic_ word.  A `mono` word.  ^superscript!^ and some ~subscript~.")
    end

    test "strong" do
      assert_xpath "//strong", @output, 1
    end

    test "italic" do
      assert_xpath "//em", @output, 1
    end

    test "monospaced" do
      assert_xpath "//code", @output, 1
    end

    test "superscript" do
      assert_xpath "//sup", @output, 1
    end

    test "subscript" do
      assert_xpath "//sub", @output, 1
    end

    test "passthrough" do
      assert_xpath "//code", convert_string("This is +passed through+."), 0
      assert_xpath "//code", convert_string("This is +passed through and monospaced+.", :attributes => {'compat-mode' => ''}), 1
    end

    test "nested styles" do
      output = convert_string("Winning *big _time_* in the +city *boyeeee*+.", :attributes => {'compat-mode' => ''})

      assert_xpath "//strong/em", output
      assert_xpath "//code/strong", output

      output = convert_string("Winning *big _time_* in the `city *boyeeee*`.")

      assert_xpath "//strong/em", output
      assert_xpath "//code/strong", output
    end

    test 'unconstrained quotes' do
      output = convert_string('**B**__I__++M++[role]++M++', :attributes => {'compat-mode' => ''})
      assert_xpath '//strong', output, 1
      assert_xpath '//em', output, 1
      assert_xpath '//code[not(@class)]', output, 1
      assert_xpath '//code[@class="role"]', output, 1

      output = convert_string('**B**__I__``M``[role]``M``')
      assert_xpath '//strong', output, 1
      assert_xpath '//em', output, 1
      assert_xpath '//code[not(@class)]', output, 1
      assert_xpath '//code[@class="role"]', output, 1
    end
  end

  test 'should format Asian characters as words' do
    assert_xpath '//strong', (convert_string_to_embedded 'bold *要* bold')
    assert_xpath '//strong', (convert_string_to_embedded 'bold *素* bold')
    assert_xpath '//strong', (convert_string_to_embedded 'bold *要素* bold')
  end
end
