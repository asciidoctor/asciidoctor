# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

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

  test "proper encoding to handle utf8 characters in document using docbook45 backend" do
    output = example_document(:encoding, :attributes => {'backend' => 'docbook45', 'xmlns' => ''}).render
    assert_xpath '//xmlns:simpara', output, 4
    assert_xpath '//xmlns:ulink', output, 1
  end

  test "proper encoding to handle utf8 characters in embedded document using docbook45 backend" do
    output = example_document(:encoding, :header_footer => false, :attributes => {'backend' => 'docbook45'}).render
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
    block = Asciidoctor::Parser.next_block(reader, doc)
    assert_xpath '//pre', block.render.gsub(/^\s*\n/, ''), 1
  end

  test 'proper encoding to handle utf8 characters from included file' do
    input = <<-EOS
include::fixtures/encoding.asciidoc[tags=romé]
    EOS
    doc = empty_safe_document :base_dir => File.expand_path(File.dirname(__FILE__))
    reader = Asciidoctor::PreprocessorReader.new doc, input
    block = Asciidoctor::Parser.next_block(reader, doc)
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

  test 'single- and double-quoted text' do
    rendered = render_embedded_string(%q(``Where?,'' she said, flipping through her copy of `The New Yorker.'), :attributes => {'compat-mode' => ''})
    assert_match(/&#8220;Where\?,&#8221;/, rendered)
    assert_match(/&#8216;The New Yorker.&#8217;/, rendered)

    rendered = render_embedded_string(%q("`Where?,`" she said, flipping through her copy of '`The New Yorker.`'))
    assert_match(/&#8220;Where\?,&#8221;/, rendered)
    assert_match(/&#8216;The New Yorker.&#8217;/, rendered)
  end

  test 'multiple double-quoted text on a single line' do
    assert_equal '&#8220;Our business is constantly changing&#8221; or &#8220;We need faster time to market.&#8221;',
        render_embedded_string(%q(``Our business is constantly changing'' or ``We need faster time to market.''), :doctype => :inline, :attributes => {'compat-mode' => ''})
    assert_equal '&#8220;Our business is constantly changing&#8221; or &#8220;We need faster time to market.&#8221;',
        render_embedded_string(%q("`Our business is constantly changing`" or "`We need faster time to market.`"), :doctype => :inline)
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

  test "emphasized text using underscore characters" do
    assert_xpath "//em", render_string("An _emphatic_ no")
  end

  test 'emphasized text with single quote using apostrophe characters' do
    rsquo = [8217].pack 'U*'
    assert_xpath %(//em[text()="Johnny#{rsquo}s"]), render_string(%q(It's 'Johnny's' phone), :attributes => {'compat-mode' => ''})
    assert_xpath %(//p[text()="It#{rsquo}s 'Johnny#{rsquo}s' phone"]), render_string(%q(It's 'Johnny's' phone))
  end

  test 'emphasized text with escaped single quote using apostrophe characters' do
    assert_xpath %(//em[text()="Johnny's"]), render_string(%q(It's 'Johnny\\'s' phone), :attributes => {'compat-mode' => ''})
    assert_xpath %(//p[text()="It's 'Johnny's' phone"]), render_string(%q(It\\'s 'Johnny\\'s' phone))
  end

  test "escaped single quote is restored as single quote" do
    assert_xpath "//p[contains(text(), \"Let's do it!\")]", render_string("Let\\'s do it!")
  end

  test 'unescape escaped single quote emphasis in compat mode only' do
    assert_xpath %(//p[text()="A 'single quoted string' example"]), render_embedded_string(%(A \\'single quoted string' example), :attributes => {'compat-mode' => ''})
    assert_xpath %(//p[text()="'single quoted string'"]), render_embedded_string(%(\\'single quoted string'), :attributes => {'compat-mode' => ''})

    assert_xpath %(//p[text()="A \\'single quoted string' example"]), render_embedded_string(%(A \\'single quoted string' example))
    assert_xpath %(//p[text()="\\'single quoted string'"]), render_embedded_string(%(\\'single quoted string'))
  end

  test "emphasized text at end of line" do
    assert_xpath "//em", render_string("This library is _awesome_")
  end

  test "emphasized text at beginning of line" do
    assert_xpath "//em", render_string("_drop_ it")
  end

  test "emphasized text across line" do
    assert_xpath "//em", render_string("_check it_")
  end

  test "unquoted text" do
    refute_match(/#/, render_string("An #unquoted# word"))
  end

  test 'backticks and straight quotes in text' do
    backslash = '\\'
    assert_equal %q(run <code>foo</code> <em>dog</em>), render_embedded_string(%q(run `foo` 'dog'), :doctype => :inline, :attributes => {'compat-mode' => ''})
    assert_equal %q(run <code>foo</code> 'dog'), render_embedded_string(%q(run `foo` 'dog'), :doctype => :inline)
    assert_equal %q(run `foo` 'dog'), render_embedded_string(%(run #{backslash}`foo` 'dog'), :doctype => :inline)
    assert_equal %q(run &#8216;foo` 'dog&#8217;), render_embedded_string(%q(run '`foo` 'dog`'), :doctype => :inline)
    assert_equal %q(run '`foo` 'dog`'), render_embedded_string(%(run #{backslash}'`foo` 'dog#{backslash}`'), :doctype => :inline)
  end

  test 'plus characters inside single plus passthrough' do
    assert_xpath '//p[text()="+"]', render_embedded_string('+++')
    assert_xpath '//p[text()="+="]', render_embedded_string('++=+')
  end

  test 'plus passthrough escapes entity reference' do
    assert_match(/&amp;#44;/, render_embedded_string('+&#44;+'))
    assert_match(/one&amp;#44;two/, render_embedded_string('one++&#44;++two'))
  end

  context "basic styling" do
    setup do
      @rendered = render_string("A *BOLD* word.  An _italic_ word.  A `mono` word.  ^superscript!^ and some ~subscript~.")
    end

    test "strong" do
      assert_xpath "//strong", @rendered, 1
    end

    test "italic" do
      assert_xpath "//em", @rendered, 1
    end

    test "monospaced" do
      assert_xpath "//code", @rendered, 1
    end

    test "superscript" do
      assert_xpath "//sup", @rendered, 1
    end

    test "subscript" do
      assert_xpath "//sub", @rendered, 1
    end

    test "passthrough" do
      assert_xpath "//code", render_string("This is +passed through+."), 0
      assert_xpath "//code", render_string("This is +passed through and monospaced+.", :attributes => {'compat-mode' => ''}), 1
    end

    test "nested styles" do
      rendered = render_string("Winning *big _time_* in the +city *boyeeee*+.", :attributes => {'compat-mode' => ''})

      assert_xpath "//strong/em", rendered
      assert_xpath "//code/strong", rendered

      rendered = render_string("Winning *big _time_* in the `city *boyeeee*`.")

      assert_xpath "//strong/em", rendered
      assert_xpath "//code/strong", rendered
    end

    test "unconstrained quotes" do
      rendered_chars = render_string("**B**__I__++M++", :attributes => {'compat-mode' => ''})
      assert_xpath "//strong", rendered_chars
      assert_xpath "//em", rendered_chars
      assert_xpath "//code", rendered_chars

      rendered_chars = render_string("**B**__I__``M``")
      assert_xpath "//strong", rendered_chars
      assert_xpath "//em", rendered_chars
      assert_xpath "//code", rendered_chars
    end
  end

  test 'should format Asian characters as words' do
    assert_xpath '//strong', (render_embedded_string 'bold *要* bold')
    assert_xpath '//strong', (render_embedded_string 'bold *素* bold')
    assert_xpath '//strong', (render_embedded_string 'bold *要素* bold')
  end
end
