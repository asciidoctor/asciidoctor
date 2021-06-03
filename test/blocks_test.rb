# frozen_string_literal: true
require_relative 'test_helper'

context 'Blocks' do
  default_logger = Asciidoctor::LoggerManager.logger

  setup do
    Asciidoctor::LoggerManager.logger = (@logger = Asciidoctor::MemoryLogger.new)
  end

  teardown do
    Asciidoctor::LoggerManager.logger = default_logger
  end

  context 'Layout Breaks' do
    test 'horizontal rule' do
      %w(''' '''' '''''').each do |line|
        output = convert_string_to_embedded line
        assert_includes output, '<hr>'
      end
    end

    test 'horizontal rule with markdown syntax disabled' do
      old_markdown_syntax = Asciidoctor::Compliance.markdown_syntax
      begin
        Asciidoctor::Compliance.markdown_syntax = false
        %w(''' '''' '''''').each do |line|
          output = convert_string_to_embedded line
          assert_includes output, '<hr>'
        end
        %w(--- *** ___).each do |line|
          output = convert_string_to_embedded line
          refute_includes output, '<hr>'
        end
      ensure
        Asciidoctor::Compliance.markdown_syntax = old_markdown_syntax
      end
    end

    test '< 3 chars does not make horizontal rule' do
      %w(' '').each do |line|
        output = convert_string_to_embedded line
        refute_includes output, '<hr>'
        assert_includes output, %(<p>#{line}</p>)
      end
    end

    test 'mixed chars does not make horizontal rule' do
      [%q(''<), %q('''<), %q(' ' ')].each do |line|
        output = convert_string_to_embedded line
        refute_includes output, '<hr>'
        assert_includes output, %(<p>#{line.sub '<', '&lt;'}</p>)
      end
    end

    test 'horizontal rule between blocks' do
      output = convert_string_to_embedded %(Block above\n\n'''\n\nBlock below)
      assert_xpath '/hr', output, 1
      assert_xpath '/hr/preceding-sibling::*', output, 1
      assert_xpath '/hr/following-sibling::*', output, 1
    end

    test 'page break' do
      output = convert_string_to_embedded %(page 1\n\n<<<\n\npage 2)
      assert_xpath '/*[translate(@style, ";", "")="page-break-after: always"]', output, 1
      assert_xpath '/*[translate(@style, ";", "")="page-break-after: always"]/preceding-sibling::div/p[text()="page 1"]', output, 1
      assert_xpath '/*[translate(@style, ";", "")="page-break-after: always"]/following-sibling::div/p[text()="page 2"]', output, 1
    end
  end

  context 'Comments' do
    test 'line comment between paragraphs offset by blank lines' do
      input = <<~'EOS'
      first paragraph

      // line comment

      second paragraph
      EOS
      output = convert_string_to_embedded input
      refute_match(/line comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent line comment between paragraphs' do
      input = <<~'EOS'
      first line
      // line comment
      second line
      EOS
      output = convert_string_to_embedded input
      refute_match(/line comment/, output)
      assert_xpath '//p', output, 1
      assert_xpath "//p[1][text()='first line\nsecond line']", output, 1
    end

    test 'comment block between paragraphs offset by blank lines' do
      input = <<~'EOS'
      first paragraph

      ////
      block comment
      ////

      second paragraph
      EOS
      output = convert_string_to_embedded input
      refute_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'comment block between paragraphs offset by blank lines inside delimited block' do
      input = <<~'EOS'
      ====
      first paragraph

      ////
      block comment
      ////

      second paragraph
      ====
      EOS
      output = convert_string_to_embedded input
      refute_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent comment block between paragraphs' do
      input = <<~'EOS'
      first paragraph
      ////
      block comment
      ////
      second paragraph
      EOS
      output = convert_string_to_embedded input
      refute_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test "can convert with block comment at end of document with trailing newlines" do
      input = <<~'EOS'
      paragraph

      ////
      block comment
      ////


      EOS
      output = convert_string_to_embedded input
      refute_match(/block comment/, output)
    end

    test "trailing newlines after block comment at end of document does not create paragraph" do
      input = <<~'EOS'
      paragraph

      ////
      block comment
      ////


      EOS
      d = document_from_string input
      assert_equal 1, d.blocks.size
      assert_xpath '//p', d.convert, 1
    end

    test 'line starting with three slashes should not be line comment' do
      input = '/// not a line comment'
      output = convert_string_to_embedded input
      refute_empty output.strip, "Line should be emitted => #{input.rstrip}"
    end

    test 'preprocessor directives should not be processed within comment block within block metadata' do
      input = <<~'EOS'
      .sample title
      ////
      ifdef::asciidoctor[////]
      ////
      line should be shown
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//p[text()="line should be shown"]', output, 1
    end

    test 'preprocessor directives should not be processed within comment block' do
      input = <<~'EOS'
      dummy line

      ////
      ifdef::asciidoctor[////]
      ////

      line should be shown
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//p[text()="line should be shown"]', output, 1
    end

    test 'should warn if unterminated comment block is detected in body' do
      input = <<~'EOS'
      before comment block

      ////
      content that has been disabled

      supposed to be after comment block, except it got swallowed by block comment
      EOS

      convert_string_to_embedded input
      assert_message @logger, :WARN, '<stdin>: line 3: unterminated comment block', Hash
    end

    test 'should warn if unterminated comment block is detected inside another block' do
      input = <<~'EOS'
      before sidebar block

      ****
      ////
      content that has been disabled
      ****

      supposed to be after sidebar block, except it got swallowed by block comment
      EOS

      convert_string_to_embedded input
      assert_message @logger, :WARN, '<stdin>: line 4: unterminated comment block', Hash
    end

    # WARNING if first line of content is a directive, it will get interpretted before we know it's a comment block
    # it happens because we always look a line ahead...not sure what we can do about it
    test 'preprocessor directives should not be processed within comment open block' do
      input = <<~'EOS'
      [comment]
      --
      first line of comment
      ifdef::asciidoctor[--]
      line should not be shown
      --

      EOS

      output = convert_string_to_embedded input
      assert_xpath '//p', output, 0
    end

    # WARNING this assertion fails if the directive is the first line of the paragraph instead of the second
    # it happens because we always look a line ahead; not sure what we can do about it
    test 'preprocessor directives should not be processed on subsequent lines of a comment paragraph' do
      input = <<~'EOS'
      [comment]
      first line of content
      ifdef::asciidoctor[////]

      this line should be shown
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//p[text()="this line should be shown"]', output, 1
    end

    test 'comment style on open block should only skip block' do
      input = <<~'EOS'
      [comment]
      --
      skip

      this block
      --

      not this text
      EOS
      result = convert_string_to_embedded input
      assert_xpath '//p', result, 1
      assert_xpath '//p[text()="not this text"]', result, 1
    end

    test 'comment style on paragraph should only skip paragraph' do
      input = <<~'EOS'
      [comment]
      skip
      this paragraph

      not this text
      EOS
      result = convert_string_to_embedded input
      assert_xpath '//p', result, 1
      assert_xpath '//p[text()="not this text"]', result, 1
    end

    test 'comment style on paragraph should not cause adjacent block to be skipped' do
      input = <<~'EOS'
      [comment]
      skip
      this paragraph
      [example]
      not this text
      EOS
      result = convert_string_to_embedded input
      assert_xpath '/*[@class="exampleblock"]', result, 1
      assert_xpath '/*[@class="exampleblock"]//*[normalize-space(text())="not this text"]', result, 1
    end

    # NOTE this test verifies the nil return value of Parser#next_block
    test 'should not drop content that follows skipped content inside a delimited block' do
      input = <<~'EOS'
      ====
      paragraph

      [comment#idname]
      skip

      paragraph
      ====
      EOS
      result = convert_string_to_embedded input
      assert_xpath '/*[@class="exampleblock"]', result, 1
      assert_xpath '/*[@class="exampleblock"]//*[@class="paragraph"]', result, 2
      assert_xpath '//*[@class="paragraph"][@id="idname"]', result, 0
    end
  end

  context 'Sidebar Blocks' do
    test 'should parse sidebar block' do
      input = <<~'EOS'
      == Section

      .Sidebar
      ****
      Content goes here
      ****
      EOS
      result = convert_string input
      assert_xpath "//*[@class='sidebarblock']//p", result, 1
    end
  end

  context 'Quote and Verse Blocks' do
    test 'quote block with no attribution' do
      input = <<~'EOS'
      ____
      A famous quote.
      ____
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath '//*[@class="quoteblock"]//p[text()="A famous quote."]', output, 1
    end

    test 'quote block with attribution' do
      input = <<~'EOS'
      [quote, Famous Person, Famous Book (1999)]
      ____
      A famous quote.
      ____
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 1
      assert_css '.quoteblock > .attribution > cite', output, 1
      assert_css '.quoteblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class="quoteblock"]/*[@class="attribution"]/cite[text()="Famous Book (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class="quoteblock"]/*[@class="attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{decode_char 8212} Famous Person", author.text.strip
    end

    test 'quote block with attribute and id and role shorthand' do
      input = <<~'EOS'
      [quote#justice-to-all.solidarity, Martin Luther King, Jr.]
      ____
      Injustice anywhere is a threat to justice everywhere.
      ____
      EOS

      output = convert_string_to_embedded input
      assert_css '.quoteblock', output, 1
      assert_css '#justice-to-all.quoteblock.solidarity', output, 1
      assert_css '.quoteblock > .attribution', output, 1
    end

    test 'setting ID using style shorthand should not reset block style' do
      input = <<~'EOS'
      [quote]
      [#justice-to-all.solidarity, Martin Luther King, Jr.]
      ____
      Injustice anywhere is a threat to justice everywhere.
      ____
      EOS

      output = convert_string_to_embedded input
      assert_css '.quoteblock', output, 1
      assert_css '#justice-to-all.quoteblock.solidarity', output, 1
      assert_css '.quoteblock > .attribution', output, 1
    end

    test 'quote block with complex content' do
      input = <<~'EOS'
      ____
      A famous quote.

      NOTE: _That_ was inspiring.
      ____
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph', output, 1
      assert_css '.quoteblock > blockquote > .paragraph + .admonitionblock', output, 1
    end

    test 'quote block with attribution converted to DocBook' do
      input = <<~'EOS'
      [quote, Famous Person, Famous Book (1999)]
      ____
      A famous quote.
      ____
      EOS
      output = convert_string input, backend: :docbook
      assert_css 'blockquote', output, 1
      assert_css 'blockquote > simpara', output, 1
      assert_css 'blockquote > attribution', output, 1
      assert_css 'blockquote > attribution > citetitle', output, 1
      assert_xpath '//blockquote/attribution/citetitle[text()="Famous Book (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//blockquote/attribution', output, 1
      author = attribution.children.first
      assert_equal 'Famous Person', author.text.strip
    end

    test 'epigraph quote block with attribution converted to DocBook' do
      input = <<~'EOS'
      [.epigraph, Famous Person, Famous Book (1999)]
      ____
      A famous quote.
      ____
      EOS
      output = convert_string input, backend: :docbook
      assert_css 'epigraph', output, 1
      assert_css 'epigraph > simpara', output, 1
      assert_css 'epigraph > attribution', output, 1
      assert_css 'epigraph > attribution > citetitle', output, 1
      assert_xpath '//epigraph/attribution/citetitle[text()="Famous Book (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//epigraph/attribution', output, 1
      author = attribution.children.first
      assert_equal 'Famous Person', author.text.strip
    end

    test 'markdown-style quote block with single paragraph and no attribution' do
      input = <<~'EOS'
      > A famous quote.
      > Some more inspiring words.
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %(//*[@class="quoteblock"]//p[text()="A famous quote.\nSome more inspiring words."]), output, 1
    end

    test 'lazy markdown-style quote block with single paragraph and no attribution' do
      input = <<~'EOS'
      > A famous quote.
      Some more inspiring words.
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %(//*[@class="quoteblock"]//p[text()="A famous quote.\nSome more inspiring words."]), output, 1
    end

    test 'markdown-style quote block with multiple paragraphs and no attribution' do
      input = <<~'EOS'
      > A famous quote.
      >
      > Some more inspiring words.
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 2
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %((//*[@class="quoteblock"]//p)[1][text()="A famous quote."]), output, 1
      assert_xpath %((//*[@class="quoteblock"]//p)[2][text()="Some more inspiring words."]), output, 1
    end

    test 'markdown-style quote block with multiple blocks and no attribution' do
      input = <<~'EOS'
      > A famous quote.
      >
      > NOTE: Some more inspiring words.
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > blockquote > .admonitionblock', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %((//*[@class="quoteblock"]//p)[1][text()="A famous quote."]), output, 1
      assert_xpath %((//*[@class="quoteblock"]//*[@class="admonitionblock note"]//*[@class="content"])[1][normalize-space(text())="Some more inspiring words."]), output, 1
    end

    test 'markdown-style quote block with single paragraph and attribution' do
      input = <<~'EOS'
      > A famous quote.
      > Some more inspiring words.
      > -- Famous Person, Famous Source, Volume 1 (1999)
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_xpath %(//*[@class="quoteblock"]//p[text()="A famous quote.\nSome more inspiring words."]), output, 1
      assert_css '.quoteblock > .attribution', output, 1
      assert_css '.quoteblock > .attribution > cite', output, 1
      assert_css '.quoteblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class="quoteblock"]/*[@class="attribution"]/cite[text()="Famous Source, Volume 1 (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class="quoteblock"]/*[@class="attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{decode_char 8212} Famous Person", author.text.strip
    end

    test 'markdown-style quote block with only attribution' do
      input = '> -- Anonymous'
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > *', output, 0
      assert_css '.quoteblock > .attribution', output, 1
      assert_xpath %(//*[@class="quoteblock"]//*[@class="attribution"][contains(text(),"Anonymous")]), output, 1
    end

    test 'should parse credit line in markdown-style quote block like positional block attributes' do
      input = <<~'EOS'
      > I hold it that a little rebellion now and then is a good thing,
      > and as necessary in the political world as storms in the physical.
      -- Thomas Jefferson, https://jeffersonpapers.princeton.edu/selected-documents/james-madison-1[The Papers of Thomas Jefferson, Volume 11]
      EOS

      output = convert_string_to_embedded input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock cite a[href="https://jeffersonpapers.princeton.edu/selected-documents/james-madison-1"]', output, 1
    end

    test 'quoted paragraph-style quote block with attribution' do
      input = <<~'EOS'
      "A famous quote.
      Some more inspiring words."
      -- Famous Person, Famous Source, Volume 1 (1999)
      EOS
      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_xpath %(//*[@class="quoteblock"]/blockquote[normalize-space(text())="A famous quote. Some more inspiring words."]), output, 1
      assert_css '.quoteblock > .attribution', output, 1
      assert_css '.quoteblock > .attribution > cite', output, 1
      assert_css '.quoteblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class="quoteblock"]/*[@class="attribution"]/cite[text()="Famous Source, Volume 1 (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class="quoteblock"]/*[@class="attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{decode_char 8212} Famous Person", author.text.strip
    end

    test 'should parse credit line in quoted paragraph-style quote block like positional block attributes' do
      input = <<~'EOS'
      "I hold it that a little rebellion now and then is a good thing,
      and as necessary in the political world as storms in the physical."
      -- Thomas Jefferson, https://jeffersonpapers.princeton.edu/selected-documents/james-madison-1[The Papers of Thomas Jefferson, Volume 11]
      EOS

      output = convert_string_to_embedded input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock cite a[href="https://jeffersonpapers.princeton.edu/selected-documents/james-madison-1"]', output, 1
    end

    test 'single-line verse block without attribution' do
      input = <<~'EOS'
      [verse]
      ____
      A famous verse.
      ____
      EOS
      output = convert_string input
      assert_css '.verseblock', output, 1
      assert_css '.verseblock > pre', output, 1
      assert_css '.verseblock > .attribution', output, 0
      assert_css '.verseblock p', output, 0
      assert_xpath '//*[@class="verseblock"]/pre[normalize-space(text())="A famous verse."]', output, 1
    end

    test 'single-line verse block with attribution' do
      input = <<~'EOS'
      [verse, Famous Poet, Famous Poem]
      ____
      A famous verse.
      ____
      EOS
      output = convert_string input
      assert_css '.verseblock', output, 1
      assert_css '.verseblock p', output, 0
      assert_css '.verseblock > pre', output, 1
      assert_css '.verseblock > .attribution', output, 1
      assert_css '.verseblock > .attribution > cite', output, 1
      assert_css '.verseblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class="verseblock"]/*[@class="attribution"]/cite[text()="Famous Poem"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class="verseblock"]/*[@class="attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{decode_char 8212} Famous Poet", author.text.strip
    end

    test 'single-line verse block with attribution converted to DocBook' do
      input = <<~'EOS'
      [verse, Famous Poet, Famous Poem]
      ____
      A famous verse.
      ____
      EOS
      output = convert_string input, backend: :docbook
      assert_css 'blockquote', output, 1
      assert_css 'blockquote simpara', output, 0
      assert_css 'blockquote > literallayout', output, 1
      assert_css 'blockquote > attribution', output, 1
      assert_css 'blockquote > attribution > citetitle', output, 1
      assert_xpath '//blockquote/attribution/citetitle[text()="Famous Poem"]', output, 1
      attribution = xmlnodes_at_xpath '//blockquote/attribution', output, 1
      author = attribution.children.first
      assert_equal 'Famous Poet', author.text.strip
    end

    test 'single-line epigraph verse block with attribution converted to DocBook' do
      input = <<~'EOS'
      [verse.epigraph, Famous Poet, Famous Poem]
      ____
      A famous verse.
      ____
      EOS
      output = convert_string input, backend: :docbook
      assert_css 'epigraph', output, 1
      assert_css 'epigraph simpara', output, 0
      assert_css 'epigraph > literallayout', output, 1
      assert_css 'epigraph > attribution', output, 1
      assert_css 'epigraph > attribution > citetitle', output, 1
      assert_xpath '//epigraph/attribution/citetitle[text()="Famous Poem"]', output, 1
      attribution = xmlnodes_at_xpath '//epigraph/attribution', output, 1
      author = attribution.children.first
      assert_equal 'Famous Poet', author.text.strip
    end

    test 'multi-stanza verse block' do
      input = <<~'EOS'
      [verse]
      ____
      A famous verse.

      Stanza two.
      ____
      EOS
      output = convert_string input
      assert_xpath '//*[@class="verseblock"]', output, 1
      assert_xpath '//*[@class="verseblock"]/pre', output, 1
      assert_xpath '//*[@class="verseblock"]//p', output, 0
      assert_xpath '//*[@class="verseblock"]/pre[contains(text(), "A famous verse.")]', output, 1
      assert_xpath '//*[@class="verseblock"]/pre[contains(text(), "Stanza two.")]', output, 1
    end

    test 'verse block does not contain block elements' do
      input = <<~'EOS'
      [verse]
      ____
      A famous verse.

      ....
      not a literal
      ....
      ____
      EOS
      output = convert_string input
      assert_css '.verseblock', output, 1
      assert_css '.verseblock > pre', output, 1
      assert_css '.verseblock p', output, 0
      assert_css '.verseblock .literalblock', output, 0
    end

    test 'verse should have normal subs' do
      input = <<~'EOS'
      [verse]
      ____
      A famous verse
      ____
      EOS

      verse = block_from_string input
      assert_equal Asciidoctor::Substitutors::NORMAL_SUBS, verse.subs
    end

    test 'should not recognize callouts in a verse' do
      input = <<~'EOS'
      [verse]
      ____
      La la la <1>
      ____
      <1> Not pointing to a callout
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//pre[text()="La la la <1>"]', output, 1
      assert_message @logger, :WARN, '<stdin>: line 5: no callout found for <1>', Hash
    end

    test 'should perform normal subs on a verse block' do
      input = <<~'EOS'
      [verse]
      ____
      _GET /groups/link:#group-id[\{group-id\}]_
      ____
      EOS

      output = convert_string_to_embedded input
      assert_includes output, '<pre class="content"><em>GET /groups/<a href="#group-id">{group-id}</a></em></pre>'
    end
  end

  context "Example Blocks" do
    test "can convert example block" do
      input = <<~'EOS'
      ====
      This is an example of an example block.

      How crazy is that?
      ====
      EOS

      output = convert_string input
      assert_xpath '//*[@class="exampleblock"]//p', output, 2
    end

    test 'assigns sequential numbered caption to example block with title' do
      input = <<~'EOS'
      .Writing Docs with AsciiDoc
      ====
      Here's how you write AsciiDoc.

      You just write.
      ====

      .Writing Docs with DocBook
      ====
      Here's how you write DocBook.

      You futz with XML.
      ====
      EOS

      doc = document_from_string input
      assert_equal 1, doc.blocks[0].numeral
      assert_equal 1, doc.blocks[0].number
      assert_equal 2, doc.blocks[1].numeral
      assert_equal 2, doc.blocks[1].number
      output = doc.convert
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Example 1. Writing Docs with AsciiDoc"]', output, 1
      assert_xpath '(//*[@class="exampleblock"])[2]/*[@class="title"][text()="Example 2. Writing Docs with DocBook"]', output, 1
      assert_equal 2, doc.attributes['example-number']
    end

    test 'assigns sequential character caption to example block with title' do
      input = <<~'EOS'
      :example-number: @

      .Writing Docs with AsciiDoc
      ====
      Here's how you write AsciiDoc.

      You just write.
      ====

      .Writing Docs with DocBook
      ====
      Here's how you write DocBook.

      You futz with XML.
      ====
      EOS

      doc = document_from_string input
      assert_equal 'A', doc.blocks[0].numeral
      assert_equal 'A', doc.blocks[0].number
      assert_equal 'B', doc.blocks[1].numeral
      assert_equal 'B', doc.blocks[1].number
      output = doc.convert
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Example A. Writing Docs with AsciiDoc"]', output, 1
      assert_xpath '(//*[@class="exampleblock"])[2]/*[@class="title"][text()="Example B. Writing Docs with DocBook"]', output, 1
      assert_equal 'B', doc.attributes['example-number']
    end

    test 'should increment counter for example even when example-number is locked by the API' do
      input = <<~'EOS'
      .Writing Docs with AsciiDoc
      ====
      Here's how you write AsciiDoc.

      You just write.
      ====

      .Writing Docs with DocBook
      ====
      Here's how you write DocBook.

      You futz with XML.
      ====
      EOS

      doc = document_from_string input, attributes: { 'example-number' => '`' }
      output = doc.convert
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Example a. Writing Docs with AsciiDoc"]', output, 1
      assert_xpath '(//*[@class="exampleblock"])[2]/*[@class="title"][text()="Example b. Writing Docs with DocBook"]', output, 1
      assert_equal 'b', doc.attributes['example-number']
    end

    test 'should use explicit caption if specified' do
      input = <<~'EOS'
      [caption="Look! "]
      .Writing Docs with AsciiDoc
      ====
      Here's how you write AsciiDoc.

      You just write.
      ====
      EOS

      doc = document_from_string input
      assert_nil doc.blocks[0].numeral
      output = doc.convert
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Look! Writing Docs with AsciiDoc"]', output, 1
      refute doc.attributes.key? 'example-number'
    end

    test 'automatic caption can be turned off and on and modified' do
      input = <<~'EOS'
      .first example
      ====
      an example
      ====

      :caption:

      .second example
      ====
      another example
      ====

      :caption!:
      :example-caption: Exhibit

      .third example
      ====
      yet another example
      ====
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="exampleblock"]', output, 3
      assert_xpath '(/*[@class="exampleblock"])[1]/*[@class="title"][starts-with(text(), "Example ")]', output, 1
      assert_xpath '(/*[@class="exampleblock"])[2]/*[@class="title"][text()="second example"]', output, 1
      assert_xpath '(/*[@class="exampleblock"])[3]/*[@class="title"][starts-with(text(), "Exhibit ")]', output, 1
    end

    test 'should use explicit caption if specified even if block-specific global caption is disabled' do
      input = <<~'EOS'
      :!example-caption:

      [caption="Look! "]
      .Writing Docs with AsciiDoc
      ====
      Here's how you write AsciiDoc.

      You just write.
      ====
      EOS

      doc = document_from_string input
      assert_nil doc.blocks[0].numeral
      output = doc.convert
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Look! Writing Docs with AsciiDoc"]', output, 1
      refute doc.attributes.key? 'example-number'
    end

    test 'should use global caption if specified even if block-specific global caption is disabled' do
      input = <<~'EOS'
      :!example-caption:
      :caption: Look!{sp}

      .Writing Docs with AsciiDoc
      ====
      Here's how you write AsciiDoc.

      You just write.
      ====
      EOS

      doc = document_from_string input
      assert_nil doc.blocks[0].numeral
      output = doc.convert
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Look! Writing Docs with AsciiDoc"]', output, 1
      refute doc.attributes.key? 'example-number'
    end

    test 'should not process caption attribute on block that does not support a caption' do
      input = <<~'EOS'
      [caption="Look! "]
      .No caption here
      --
      content
      --
      EOS

      doc = document_from_string input
      assert_nil doc.blocks[0].caption
      assert_equal 'Look! ', (doc.blocks[0].attr 'caption')
      output = doc.convert
      assert_xpath '(//*[@class="openblock"])[1]/*[@class="title"][text()="No caption here"]', output, 1
    end

    test 'should create details/summary set if collapsible option is set' do
      input = <<~'EOS'
      .Toggle Me
      [%collapsible]
      ====
      This content is revealed when the user clicks the words "Toggle Me".
      ====
      EOS

      output = convert_string_to_embedded input
      assert_css 'details', output, 1
      assert_css 'details[open]', output, 0
      assert_css 'details > summary.title', output, 1
      assert_xpath '//details/summary[text()="Toggle Me"]', output, 1
      assert_css 'details > summary.title + .content', output, 1
      assert_css 'details > summary.title + .content p', output, 1
    end

    test 'should open details/summary set if collapsible and open options are set' do
      input = <<~'EOS'
      .Toggle Me
      [%collapsible%open]
      ====
      This content is revealed when the user clicks the words "Toggle Me".
      ====
      EOS

      output = convert_string_to_embedded input
      assert_css 'details', output, 1
      assert_css 'details[open]', output, 1
      assert_css 'details > summary.title', output, 1
      assert_xpath '//details/summary[text()="Toggle Me"]', output, 1
    end

    test 'should add default summary element if collapsible option is set and title is not specifed' do
      input = <<~'EOS'
      [%collapsible]
      ====
      This content is revealed when the user clicks the words "Details".
      ====
      EOS

      output = convert_string_to_embedded input
      assert_css 'details', output, 1
      assert_css 'details > summary.title', output, 1
      assert_xpath '//details/summary[text()="Details"]', output, 1
    end

    test 'should not allow collapsible block to increment example number' do
      input = <<~'EOS'
      .Before
      ====
      before
      ====

      .Show Me The Goods
      [%collapsible]
      ====
      This content is revealed when the user clicks the words "Show Me The Goods".
      ====

      .After
      ====
      after
      ====
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="title"][text()="Example 1. Before"]', output, 1
      assert_xpath '//*[@class="title"][text()="Example 2. After"]', output, 1
      assert_css 'details', output, 1
      assert_css 'details > summary.title', output, 1
      assert_xpath '//details/summary[text()="Show Me The Goods"]', output, 1
    end

    test 'should warn if example block is not terminated' do
      input = <<~'EOS'
      outside

      ====
      inside

      still inside

      eof
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="exampleblock"]', output, 1
      assert_message @logger, :WARN, '<stdin>: line 3: unterminated example block', Hash
    end
  end

  context 'Admonition Blocks' do
    test 'caption block-level attribute should be used as caption' do
      input = <<~'EOS'
      :tip-caption: Pro Tip

      [caption="Pro Tip"]
      TIP: Override the caption of an admonition block using an attribute entry
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Pro Tip"]', output, 1
    end

    test 'can override caption of admonition block using document attribute' do
      input = <<~'EOS'
      :tip-caption: Pro Tip

      TIP: Override the caption of an admonition block using an attribute entry
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Pro Tip"]', output, 1
    end

    test 'blank caption document attribute should not blank admonition block caption' do
      input = <<~'EOS'
      :caption:

      TIP: Override the caption of an admonition block using an attribute entry
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Tip"]', output, 1
    end
  end

  context "Preformatted Blocks" do
    test 'should separate adjacent paragraphs and listing into blocks' do
      input = <<~'EOS'
      paragraph 1
      ----
      listing content
      ----
      paragraph 2
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="paragraph"]/p', output, 2
      assert_xpath '/*[@class="listingblock"]', output, 1
      assert_xpath '(/*[@class="paragraph"]/following-sibling::*)[1][@class="listingblock"]', output, 1
    end

    test 'should warn if listing block is not terminated' do
      input = <<~'EOS'
      outside

      ----
      inside

      still inside

      eof
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="listingblock"]', output, 1
      assert_message @logger, :WARN, '<stdin>: line 3: unterminated listing block', Hash
    end

    test 'should not crash if listing block has no lines' do
      input = <<~'EOS'
      ----
      ----
      EOS
      output = convert_string_to_embedded input
      assert_css 'pre', output, 1
      assert_css 'pre:empty', output, 1
    end

    test 'should preserve newlines in literal block' do
      input = <<~'EOS'
      ....
      line one

      line two

      line three
      ....
      EOS
      [true, false].each do |standalone|
        output = convert_string input, standalone: standalone
        assert_xpath '//pre', output, 1
        assert_xpath '//pre/text()', output, 1
        text = xmlnodes_at_xpath('//pre/text()', output, 1).text
        lines = text.lines
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines
        assert_equal expected, lines
        blank_lines = output.scan(/\n[ \t]*\n/).size
        assert blank_lines >= 2
      end
    end

    test 'should preserve newlines in listing block' do
      input = <<~'EOS'
      ----
      line one

      line two

      line three
      ----
      EOS
      [true, false].each do |standalone|
        output = convert_string input, standalone: standalone
        assert_xpath '//pre', output, 1
        assert_xpath '//pre/text()', output, 1
        text = xmlnodes_at_xpath('//pre/text()', output, 1).text
        lines = text.lines
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines
        assert_equal expected, lines
        blank_lines = output.scan(/\n[ \t]*\n/).size
        assert blank_lines >= 2
      end
    end

    test 'should preserve newlines in verse block' do
      input = <<~'EOS'
      --
      [verse]
      ____
      line one

      line two

      line three
      ____
      --
      EOS
      [true, false].each do |standalone|
        output = convert_string input, standalone: standalone
        assert_xpath '//*[@class="verseblock"]/pre', output, 1
        assert_xpath '//*[@class="verseblock"]/pre/text()', output, 1
        text = xmlnodes_at_xpath('//*[@class="verseblock"]/pre/text()', output, 1).text
        lines = text.lines
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines
        assert_equal expected, lines
        blank_lines = output.scan(/\n[ \t]*\n/).size
        assert blank_lines >= 2
      end
    end

    test 'should strip leading and trailing blank lines when converting verbatim block' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [subs="attributes"]
      ....


        first line

      last line

      {empty}

      ....
      EOS

      doc = document_from_string input, standalone: false
      block = doc.blocks.first
      assert_equal ['', '', '  first line', '', 'last line', '', '{empty}', ''], block.lines
      result = doc.convert
      assert_xpath %(//pre[text()="  first line\n\nlast line"]), result, 1
    end

    test 'should process block with CRLF line endings' do
      input = <<~EOS
      ----\r
      source line 1\r
      source line 2\r
      ----\r
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="listingblock"]//pre', output, 1
      assert_xpath %(/*[@class="listingblock"]//pre[text()="source line 1\nsource line 2"]), output, 1
    end

    test 'should remove block indent if indent attribute is 0' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [indent="0"]
      ----
          def names

            @names.split

          end
      ----
      EOS

      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      expected = <<~EOS.chop
      def names

        @names.split

      end
      EOS

      output = convert_string_to_embedded input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected, result
    end

    test 'should not remove block indent if indent attribute is -1' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [indent="-1"]
      ----
          def names

            @names.split

          end
      ----
      EOS

      expected = (input.lines.slice 2, 5).join.chop

      output = convert_string_to_embedded input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected, result
    end

    test 'should set block indent to value specified by indent attribute' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [indent="1"]
      ----
          def names

            @names.split

          end
      ----
      EOS

      expected = (input.lines.slice 2, 5).map {|l| l.sub '    ', ' ' }.join.chop

      output = convert_string_to_embedded input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected, result
    end

    test 'should set block indent to value specified by indent document attribute' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      :source-indent: 1

      [source,ruby]
      ----
          def names

            @names.split

          end
      ----
      EOS

      expected = (input.lines.slice 4, 5).map {|l| l.sub '    ', ' ' }.join.chop

      output = convert_string_to_embedded input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected, result
    end

    test 'should expand tabs if tabsize attribute is positive' do
      input = <<~EOS
      :tabsize: 4

      [indent=0]
      ----
      \tdef names

      \t\t@names.split

      \tend
      ----
      EOS

      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      expected = <<~EOS.chop
      def names

          @names.split

      end
      EOS

      output = convert_string_to_embedded input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected, result
    end

    test 'literal block should honor nowrap option' do
      input = <<~'EOS'
      [options="nowrap"]
      ----
      Do not wrap me if I get too long.
      ----
      EOS

      output = convert_string_to_embedded input
      assert_css 'pre.nowrap', output, 1
    end

    test 'literal block should set nowrap class if prewrap document attribute is disabled' do
      input = <<~'EOS'
      :prewrap!:

      ----
      Do not wrap me if I get too long.
      ----
      EOS

      output = convert_string_to_embedded input
      assert_css 'pre.nowrap', output, 1
    end

    test 'should preserve guard in front of callout if icons are not enabled' do
      input = <<~'EOS'
      ----
      puts 'Hello, World!' # <1>
      puts 'Goodbye, World ;(' # <2>
      ----
      EOS

      result = convert_string_to_embedded input
      assert_include ' # <b class="conum">(1)</b>', result
      assert_include ' # <b class="conum">(2)</b>', result
    end

    test 'should preserve guard around callout if icons are not enabled' do
      input = <<~'EOS'
      ----
      <parent> <!--1-->
        <child/> <!--2-->
      </parent>
      ----
      EOS

      result = convert_string_to_embedded input
      assert_include ' &lt;!--<b class="conum">(1)</b>--&gt;', result
      assert_include ' &lt;!--<b class="conum">(2)</b>--&gt;', result
    end

    test 'literal block should honor explicit subs list' do
      input = <<~'EOS'
      [subs="verbatim,quotes"]
      ----
      Map<String, String> *attributes*; //<1>
      ----
      EOS

      block = block_from_string input
      assert_equal [:specialcharacters, :callouts, :quotes], block.subs
      output = block.convert
      assert_includes output, 'Map&lt;String, String&gt; <strong>attributes</strong>;'
      assert_xpath '//pre/b[text()="(1)"]', output, 1
    end

    test 'should be able to disable callouts for literal block' do
      input = <<~'EOS'
      [subs="specialcharacters"]
      ----
      No callout here <1>
      ----
      EOS
      block = block_from_string input
      assert_equal [:specialcharacters], block.subs
      output = block.convert
      assert_xpath '//pre/b[text()="(1)"]', output, 0
    end

    test 'listing block should honor explicit subs list' do
      input = <<~'EOS'
      [subs="specialcharacters,quotes"]
      ----
      $ *python functional_tests.py*
      Traceback (most recent call last):
        File "functional_tests.py", line 4, in <module>
          assert 'Django' in browser.title
      AssertionError
      ----
      EOS

      output = convert_string_to_embedded input

      assert_css '.listingblock pre', output, 1
      assert_css '.listingblock pre strong', output, 1
      assert_css '.listingblock pre em', output, 0

      input2 = <<~'EOS'
      [subs="specialcharacters,macros"]
      ----
      $ pass:quotes[*python functional_tests.py*]
      Traceback (most recent call last):
        File "functional_tests.py", line 4, in <module>
          assert pass:quotes['Django'] in browser.title
      AssertionError
      ----
      EOS

      output2 = convert_string_to_embedded input2
      # FIXME JRuby is adding extra trailing newlines in the second document,
      # for now, rstrip is necessary
      assert_equal output.rstrip, output2.rstrip
    end

    test 'first character of block title may be a period if not followed by space' do
      input = <<~'EOS'
      ..gitignore
      ----
      /.bundle/
      /build/
      /Gemfile.lock
      ----
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="title"][text()=".gitignore"]', output
    end

    test 'listing block without title should generate screen element in docbook' do
      input = <<~'EOS'
      ----
      listing block
      ----
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '/screen[text()="listing block"]', output, 1
    end

    test 'listing block with title should generate screen element inside formalpara element in docbook' do
      input = <<~'EOS'
      .title
      ----
      listing block
      ----
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '/formalpara', output, 1
      assert_xpath '/formalpara/title[text()="title"]', output, 1
      assert_xpath '/formalpara/para/screen[text()="listing block"]', output, 1
    end

    test 'should not prepend caption to title of listing block with title if listing-caption attribute is not set' do
      input = <<~'EOS'
      .title
      ----
      listing block content
      ----
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="listingblock"][1]/*[@class="title"][text()="title"]', output, 1
    end

    test 'should prepend caption specified by listing-caption attribute and number to title of listing block with title' do
      input = <<~'EOS'
      :listing-caption: Listing

      .title
      ----
      listing block content
      ----
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="listingblock"][1]/*[@class="title"][text()="Listing 1. title"]', output, 1
    end

    test 'should prepend caption specified by caption attribute on listing block even if listing-caption attribute is not set' do
      input = <<~'EOS'
      [caption="Listing {counter:listing-number}. "]
      .Behold!
      ----
      listing block content
      ----
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="listingblock"][1]/*[@class="title"][text()="Listing 1. Behold!"]', output, 1
    end

    test 'listing block without an explicit style and with a second positional argument should be promoted to a source block' do
      input = <<~'EOS'
      [,ruby]
      ----
      puts 'Hello, Ruby!'
      ----
      EOS
      matches = (document_from_string input).find_by context: :listing, style: 'source'
      assert_equal 1, matches.length
      assert_equal 'ruby', (matches[0].attr 'language')
    end

    test 'listing block without an explicit style should be promoted to a source block if source-language is set' do
      input = <<~'EOS'
      :source-language: ruby

      ----
      puts 'Hello, Ruby!'
      ----
      EOS
      matches = (document_from_string input).find_by context: :listing, style: 'source'
      assert_equal 1, matches.length
      assert_equal 'ruby', (matches[0].attr 'language')
    end

    test 'listing block with an explicit style and a second positional argument should not be promoted to a source block' do
      input = <<~'EOS'
      [listing,ruby]
      ----
      puts 'Hello, Ruby!'
      ----
      EOS
      matches = (document_from_string input).find_by context: :listing
      assert_equal 1, matches.length
      assert_equal 'listing', matches[0].style
      assert_nil matches[0].attr 'language'
    end

    test 'listing block with an explicit style should not be promoted to a source block if source-language is set' do
      input = <<~'EOS'
      :source-language: ruby

      [listing]
      ----
      puts 'Hello, Ruby!'
      ----
      EOS
      matches = (document_from_string input).find_by context: :listing
      assert_equal 1, matches.length
      assert_equal 'listing', matches[0].style
      assert_nil matches[0].attr 'language'
    end

    test 'source block with no title or language should generate screen element in docbook' do
      input = <<~'EOS'
      [source]
      ----
      source block
      ----
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '/screen[@linenumbering="unnumbered"][text()="source block"]', output, 1
    end

    test 'source block with title and no language should generate screen element inside formalpara element for docbook' do
      input = <<~'EOS'
      [source]
      .title
      ----
      source block
      ----
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '/formalpara', output, 1
      assert_xpath '/formalpara/title[text()="title"]', output, 1
      assert_xpath '/formalpara/para/screen[@linenumbering="unnumbered"][text()="source block"]', output, 1
    end
  end

  context "Open Blocks" do
    test "can convert open block" do
      input = <<~'EOS'
      --
      This is an open block.

      It can span multiple lines.
      --
      EOS

      output = convert_string input
      assert_xpath '//*[@class="openblock"]//p', output, 2
    end

    test "open block can contain another block" do
      input = <<~'EOS'
      --
      This is an open block.

      It can span multiple lines.

      ____
      It can hold great quotes like this one.
      ____
      --
      EOS

      output = convert_string input
      assert_xpath '//*[@class="openblock"]//p', output, 3
      assert_xpath '//*[@class="openblock"]//*[@class="quoteblock"]', output, 1
    end

    test 'should transfer id and reftext on open block to DocBook output' do
      input = <<~'EOS'
      Check out that <<open>>!

      [[open,Open Block]]
      --
      This is an open block.

      TIP: An open block can have other blocks inside of it.
      --

      Back to our regularly scheduled programming.
      EOS

      output = convert_string input, backend: :docbook, keep_namespaces: true
      assert_css 'article:root > para[xml|id="open"]', output, 1
      assert_css 'article:root > para[xreflabel="Open Block"]', output, 1
      assert_css 'article:root > simpara', output, 2
      assert_css 'article:root > para', output, 1
      assert_css 'article:root > para > simpara', output, 1
      assert_css 'article:root > para > tip', output, 1
    end

    test 'should transfer id and reftext on open paragraph to DocBook output' do
      input = <<~'EOS'
      [open#openpara,reftext="Open Paragraph"]
      This is an open paragraph.
      EOS

      output = convert_string input, backend: :docbook, keep_namespaces: true
      assert_css 'article:root > simpara', output, 1
      assert_css 'article:root > simpara[xml|id="openpara"]', output, 1
      assert_css 'article:root > simpara[xreflabel="Open Paragraph"]', output, 1
    end

    test 'should transfer title on open block to DocBook output' do
      input = <<~'EOS'
      .Behold the open
      --
      This is an open block with a title.
      --
      EOS

      output = convert_string input, backend: :docbook
      assert_css 'article > formalpara', output, 1
      assert_css 'article > formalpara > *', output, 2
      assert_css 'article > formalpara > title', output, 1
      assert_xpath '/article/formalpara/title[text()="Behold the open"]', output, 1
      assert_css 'article > formalpara > para', output, 1
      assert_css 'article > formalpara > para > simpara', output, 1
    end

    test 'should transfer title on open paragraph to DocBook output' do
      input = <<~'EOS'
      .Behold the open
      This is an open paragraph with a title.
      EOS

      output = convert_string input, backend: :docbook
      assert_css 'article > formalpara', output, 1
      assert_css 'article > formalpara > *', output, 2
      assert_css 'article > formalpara > title', output, 1
      assert_xpath '/article/formalpara/title[text()="Behold the open"]', output, 1
      assert_css 'article > formalpara > para', output, 1
      assert_css 'article > formalpara > para[text()="This is an open paragraph with a title."]', output, 1
    end

    test 'should transfer role on open block to DocBook output' do
      input = <<~'EOS'
      [.container]
      --
      This is an open block.
      It holds stuff.
      --
      EOS

      output = convert_string input, backend: :docbook
      assert_css 'article > para[role=container]', output, 1
      assert_css 'article > para[role=container] > simpara', output, 1
    end

    test 'should transfer role on open paragraph to DocBook output' do
      input = <<~'EOS'
      [.container]
      This is an open block.
      It holds stuff.
      EOS

      output = convert_string input, backend: :docbook
      assert_css 'article > simpara[role=container]', output, 1
    end
  end

  context 'Passthrough Blocks' do
    test 'can parse a passthrough block' do
      input = <<~'EOS'
      ++++
      This is a passthrough block.
      ++++
      EOS

      block = block_from_string input
      refute_nil block
      assert_equal 1, block.lines.size
      assert_equal 'This is a passthrough block.', block.source
    end

    test 'does not perform subs on a passthrough block by default' do
      input = <<~'EOS'
      :type: passthrough

      ++++
      This is a '{type}' block.
      http://asciidoc.org
      image:tiger.png[]
      ++++
      EOS

      expected = %(This is a '{type}' block.\nhttp://asciidoc.org\nimage:tiger.png[])
      output = convert_string_to_embedded input
      assert_equal expected, output.strip
    end

    test 'does not perform subs on a passthrough block with pass style by default' do
      input = <<~'EOS'
      :type: passthrough

      [pass]
      ++++
      This is a '{type}' block.
      http://asciidoc.org
      image:tiger.png[]
      ++++
      EOS

      expected = %(This is a '{type}' block.\nhttp://asciidoc.org\nimage:tiger.png[])
      output = convert_string_to_embedded input
      assert_equal expected, output.strip
    end

    test 'passthrough block honors explicit subs list' do
      input = <<~'EOS'
      :type: passthrough

      [subs="attributes,quotes,macros"]
      ++++
      This is a _{type}_ block.
      http://asciidoc.org
      ++++
      EOS

      expected = %(This is a <em>passthrough</em> block.\n<a href="http://asciidoc.org" class="bare">http://asciidoc.org</a>)
      output = convert_string_to_embedded input
      assert_equal expected, output.strip
    end

    test 'should strip leading and trailing blank lines when converting raw block' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      ++++
      line above
      ++++

      ++++


        first line

      last line


      ++++

      ++++
      line below
      ++++
      EOS

      doc = document_from_string input, standalone: false
      block = doc.blocks[1]
      assert_equal ['', '', '  first line', '', 'last line', '', ''], block.lines
      result = doc.convert
      assert_equal "line above\n  first line\n\nlast line\nline below", result, 1
    end
  end

  context 'Math blocks' do
    test 'should not crash when converting to HTML if stem block is empty' do
      input = <<~'EOS'
      [stem]
      ++++
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
    end

    test 'should add LaTeX math delimiters around latexmath block content' do
      input = <<~'EOS'
      [latexmath]
      ++++
      \sqrt{3x-1}+(1+x)^2 < y
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
      assert_equal '\[\sqrt{3x-1}+(1+x)^2 &lt; y\]', nodes.first.to_s.strip
    end

    test 'should not add LaTeX math delimiters around latexmath block content if already present' do
      input = <<~'EOS'
      [latexmath]
      ++++
      \[\sqrt{3x-1}+(1+x)^2 < y\]
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
      assert_equal '\[\sqrt{3x-1}+(1+x)^2 &lt; y\]', nodes.first.to_s.strip
    end

    test 'should display latexmath block in alt of equation in DocBook backend' do
      input = <<~'EOS'
      [latexmath]
      ++++
      \sqrt{3x-1}+(1+x)^2 < y
      ++++
      EOS

      expect = <<~'EOS'
      <informalequation>
      <alt><![CDATA[\sqrt{3x-1}+(1+x)^2 < y]]></alt>
      <mathphrase><![CDATA[\sqrt{3x-1}+(1+x)^2 < y]]></mathphrase>
      </informalequation>
      EOS

      output = convert_string_to_embedded input, backend: :docbook
      assert_equal expect.strip, output.strip
    end

    test 'should set autoNumber option for latexmath to none by default' do
      input = <<~'EOS'
      :stem: latexmath

      [stem]
      ++++
      y = x^2
      ++++
      EOS

      output = convert_string input
      assert_includes output, 'TeX: { equationNumbers: { autoNumber: "none" } }'
    end

    test 'should set autoNumber option for latexmath to none if eqnums is set to none' do
      input = <<~'EOS'
      :stem: latexmath
      :eqnums: none

      [stem]
      ++++
      y = x^2
      ++++
      EOS

      output = convert_string input
      assert_includes output, 'TeX: { equationNumbers: { autoNumber: "none" } }'
    end

    test 'should set autoNumber option for latexmath to AMS if eqnums is set' do
      input = <<~'EOS'
      :stem: latexmath
      :eqnums:

      [stem]
      ++++
      \begin{equation}
      y = x^2
      \end{equation}
      ++++
      EOS

      output = convert_string input
      assert_includes output, 'TeX: { equationNumbers: { autoNumber: "AMS" } }'
    end

    test 'should set autoNumber option for latexmath to all if eqnums is set to all' do
      input = <<~'EOS'
      :stem: latexmath
      :eqnums: all

      [stem]
      ++++
      y = x^2
      ++++
      EOS

      output = convert_string input
      assert_includes output, 'TeX: { equationNumbers: { autoNumber: "all" } }'
    end

    test 'should not split equation in AsciiMath block at single newline' do
      input = <<~'EOS'
      [asciimath]
      ++++
      f: bbb"N" -> bbb"N"
      f: x |-> x + 1
      ++++
      EOS
      expected = <<~'EOS'.chop
      \$f: bbb"N" -&gt; bbb"N"
      f: x |-&gt; x + 1\$
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]', output
      assert_equal expected, nodes.first.inner_html.strip
    end

    test 'should split equation in AsciiMath block at escaped newline' do
      input = <<~'EOS'
      [asciimath]
      ++++
      f: bbb"N" -> bbb"N" \
      f: x |-> x + 1
      ++++
      EOS
      expected = <<~'EOS'.chop
      \$f: bbb"N" -&gt; bbb"N"\$
      \$f: x |-&gt; x + 1\$
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]', output
      assert_equal expected, nodes.first.inner_html.strip
    end

    test 'should split equation in AsciiMath block at sequence of escaped newlines' do
      input = <<~'EOS'
      [asciimath]
      ++++
      f: bbb"N" -> bbb"N" \
      \
      f: x |-> x + 1
      ++++
      EOS
      expected = <<~'EOS'.chop
      \$f: bbb"N" -&gt; bbb"N"\$
      <br>
      \$f: x |-&gt; x + 1\$
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]', output
      assert_equal expected, nodes.first.inner_html.strip
    end

    test 'should split equation in AsciiMath block at newline sequence and preserve breaks' do
      input = <<~'EOS'
      [asciimath]
      ++++
      f: bbb"N" -> bbb"N"


      f: x |-> x + 1
      ++++
      EOS
      expected = <<~'EOS'.chop
      \$f: bbb"N" -&gt; bbb"N"\$
      <br>
      <br>
      \$f: x |-&gt; x + 1\$
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]', output
      assert_equal expected, nodes.first.inner_html.strip
    end

    test 'should add AsciiMath delimiters around asciimath block content' do
      input = <<~'EOS'
      [asciimath]
      ++++
      sqrt(3x-1)+(1+x)^2 < y
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
      assert_equal '\$sqrt(3x-1)+(1+x)^2 &lt; y\$', nodes.first.to_s.strip
    end

    test 'should not add AsciiMath delimiters around asciimath block content if already present' do
      input = <<~'EOS'
      [asciimath]
      ++++
      \$sqrt(3x-1)+(1+x)^2 < y\$
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
      assert_equal '\$sqrt(3x-1)+(1+x)^2 &lt; y\$', nodes.first.to_s.strip
    end

    test 'should convert contents of asciimath block to MathML in DocBook output if asciimath gem is available' do
      asciimath_available = !(Asciidoctor::Helpers.require_library 'asciimath', true, :ignore).nil?
      input = <<~'EOS'
      [asciimath]
      ++++
      x+b/(2a)<+-sqrt((b^2)/(4a^2)-c/a)
      ++++

      [asciimath]
      ++++
      ++++
      EOS

      expect = <<~'EOS'.chop
      <informalequation>
      <mml:math xmlns:mml="http://www.w3.org/1998/Math/MathML"><mml:mi>x</mml:mi><mml:mo>+</mml:mo><mml:mfrac><mml:mi>b</mml:mi><mml:mrow><mml:mn>2</mml:mn><mml:mi>a</mml:mi></mml:mrow></mml:mfrac><mml:mo>&lt;</mml:mo><mml:mo>&#xB1;</mml:mo><mml:msqrt><mml:mrow><mml:mfrac><mml:msup><mml:mi>b</mml:mi><mml:mn>2</mml:mn></mml:msup><mml:mrow><mml:mn>4</mml:mn><mml:msup><mml:mi>a</mml:mi><mml:mn>2</mml:mn></mml:msup></mml:mrow></mml:mfrac><mml:mo>&#x2212;</mml:mo><mml:mfrac><mml:mi>c</mml:mi><mml:mi>a</mml:mi></mml:mfrac></mml:mrow></mml:msqrt></mml:math>
      </informalequation>
      <informalequation>
      <mml:math xmlns:mml="http://www.w3.org/1998/Math/MathML"></mml:math>
      </informalequation>
      EOS

      using_memory_logger do |logger|
        doc = document_from_string input, backend: :docbook, standalone: false
        actual = doc.convert
        if asciimath_available
          assert_equal expect, actual.strip
          assert_equal :loaded, doc.converter.instance_variable_get(:@asciimath_status)
        else
          assert_message logger, :WARN, 'optional gem \'asciimath\' is not available. Functionality disabled.'
          assert_equal :unavailable, doc.converter.instance_variable_get(:@asciimath_status)
        end
      end
    end

    test 'should output title for latexmath block if defined' do
      input = <<~'EOS'
      .The Lorenz Equations
      [latexmath]
      ++++
      \begin{aligned}
      \dot{x} & = \sigma(y-x) \\
      \dot{y} & = \rho x - y - xz \\
      \dot{z} & = -\beta z + xy
      \end{aligned}
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      assert_css '.stemblock .title', output, 1
      assert_xpath '//*[@class="title"][text()="The Lorenz Equations"]', output, 1
    end

    test 'should output title for asciimath block if defined' do
      input = <<~'EOS'
      .Simple fraction
      [asciimath]
      ++++
      a//b
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_css '.stemblock', output, 1
      assert_css '.stemblock .title', output, 1
      assert_xpath '//*[@class="title"][text()="Simple fraction"]', output, 1
    end

    test 'should add AsciiMath delimiters around stem block content if stem attribute is asciimath, empty, or not set' do
      input = <<~'EOS'
      [stem]
      ++++
      sqrt(3x-1)+(1+x)^2 < y
      ++++
      EOS

      [
        {},
        { 'stem' => '' },
        { 'stem' => 'asciimath' },
        { 'stem' => 'bogus' },
      ].each do |attributes|
        output = convert_string_to_embedded input, attributes: attributes
        assert_css '.stemblock', output, 1
        nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
        assert_equal '\$sqrt(3x-1)+(1+x)^2 &lt; y\$', nodes.first.to_s.strip
      end
    end

    test 'should add LaTeX math delimiters around stem block content if stem attribute is latexmath, latex, or tex' do
      input = <<~'EOS'
      [stem]
      ++++
      \sqrt{3x-1}+(1+x)^2 < y
      ++++
      EOS

      [
        { 'stem' => 'latexmath' },
        { 'stem' => 'latex' },
        { 'stem' => 'tex' },
      ].each do |attributes|
        output = convert_string_to_embedded input, attributes: attributes
        assert_css '.stemblock', output, 1
        nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
        assert_equal '\[\sqrt{3x-1}+(1+x)^2 &lt; y\]', nodes.first.to_s.strip
      end
    end

    test 'should allow stem style to be set using second positional argument of block attributes' do
      input = <<~'EOS'
      :stem: latexmath

      [stem,asciimath]
      ++++
      sqrt(3x-1)+(1+x)^2 < y
      ++++
      EOS

      doc = document_from_string input
      stemblock = doc.blocks[0]
      assert_equal :stem, stemblock.context
      assert_equal 'asciimath', stemblock.attributes['style']
      output = doc.convert standalone: false
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output
      assert_equal '\$sqrt(3x-1)+(1+x)^2 &lt; y\$', nodes.first.to_s.strip
    end
  end

  context 'Custom Blocks' do
    test 'should not warn if block style is unknown' do
      input = <<~'EOS'
      [foo]
      --
      bar
      --
      EOS
      convert_string_to_embedded input
      assert_empty @logger.messages
    end

    test 'should log debug message if block style is unknown and debug level is enabled' do
      input = <<~'EOS'
      [foo]
      --
      bar
      --
      EOS
      using_memory_logger Logger::Severity::DEBUG do |logger|
        convert_string_to_embedded input
        assert_message logger, :DEBUG, '<stdin>: line 2: unknown style for open block: foo', Hash
      end
    end
  end

  context 'Metadata' do
    test 'block title above section gets carried over to first block in section' do
      input = <<~'EOS'
      .Title
      == Section

      paragraph
      EOS
      output = convert_string input
      assert_xpath '//*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="paragraph"]/*[@class="title"][text()="Title"]', output, 1
      assert_xpath '//*[@class="paragraph"]/p[text()="paragraph"]', output, 1
    end

    test 'block title above document title demotes document title to a section title' do
      input = <<~'EOS'
      .Block title
      = Section Title

      section paragraph
      EOS
      output = convert_string input
      assert_xpath '//*[@id="header"]/*', output, 0
      assert_xpath '//*[@id="preamble"]/*', output, 0
      assert_xpath '//*[@id="content"]/h1[text()="Section Title"]', output, 1
      assert_xpath '//*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="paragraph"]/*[@class="title"][text()="Block title"]', output, 1
      assert_message @logger, :ERROR, '<stdin>: line 2: level 0 sections can only be used when doctype is book', Hash
    end

    test 'block title above document title gets carried over to first block in first section if no preamble' do
      input = <<~'EOS'
      :doctype: book
      .Block title
      = Document Title

      == First Section

      paragraph
      EOS
      doc = document_from_string input
      # NOTE block title demotes document title to level-0 section
      refute doc.header?
      output = doc.convert
      assert_xpath '//*[@class="sect1"]//*[@class="paragraph"]/*[@class="title"][text()="Block title"]', output, 1
    end

    test 'should apply substitutions to a block title in normal order' do
      input = <<~'EOS'
      .{link-url}[{link-text}]{tm}
      The one and only!
      EOS

      output = convert_string_to_embedded input, attributes: {
        'link-url' => 'https://acme.com',
        'link-text' => 'ACME',
        'tm' => '(TM)',
      }
      assert_css '.title', output, 1
      assert_css '.title a[href="https://acme.com"]', output, 1
      assert_xpath %(//*[@class="title"][contains(text(),"#{decode_char 8482}")]), output, 1
    end

    test 'empty attribute list should not appear in output' do
      input = <<~'EOS'
      []
      --
      Block content
      --
      EOS

      output = convert_string_to_embedded input
      assert_includes output, 'Block content'
      refute_includes output, '[]'
    end

    test 'empty block anchor should not appear in output' do
      input = <<~'EOS'
      [[]]
      --
      Block content
      --
      EOS

      output = convert_string_to_embedded input
      assert_includes output, 'Block content'
      refute_includes output, '[[]]'
    end
  end

  context 'Images' do
    test 'can convert block image with alt text defined in macro' do
      input = 'image::images/tiger.png[Tiger]'
      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'converts SVG image using img element by default' do
      input = 'image::tiger.svg[Tiger]'
      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//img[@src="tiger.svg"][@alt="Tiger"]', output, 1
    end

    test 'converts interactive SVG image with alt text using object element' do
      input = <<~'EOS'
      :imagesdir: images

      [%interactive]
      image::tiger.svg[Tiger,100]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="images/tiger.svg"][@width="100"]/span[@class="alt"][text()="Tiger"]', output, 1
    end

    test 'converts SVG image with alt text using img element when safe mode is secure' do
      input = <<~'EOS'
      [%interactive]
      image::images/tiger.svg[Tiger,100]
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.svg"][@alt="Tiger"]', output, 1
    end

    test 'inserts fallback image for SVG inside object element using same dimensions' do
      input = <<~'EOS'
      :imagesdir: images

      [%interactive]
      image::tiger.svg[Tiger,100,fallback=tiger.png]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="images/tiger.svg"][@width="100"]/img[@src="images/tiger.png"][@width="100"]', output, 1
    end

    test 'detects SVG image URI that contains a query string' do
      input = <<~'EOS'
      :imagesdir: images

      [%interactive]
      image::http://example.org/tiger.svg?foo=bar[Tiger,100]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="http://example.org/tiger.svg?foo=bar"][@width="100"]/span[@class="alt"][text()="Tiger"]', output, 1
    end

    test 'detects SVG image when format attribute is svg' do
      input = <<~'EOS'
      :imagesdir: images

      [%interactive]
      image::http://example.org/tiger-svg[Tiger,100,format=svg]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="http://example.org/tiger-svg"][@width="100"]/span[@class="alt"][text()="Tiger"]', output, 1
    end

    test 'converts to inline SVG image when inline option is set on block' do
      input = <<~'EOS'
      :imagesdir: fixtures

      [%inline]
      image::circle.svg[Tiger,100]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER, attributes: { 'docdir' => testdir }
      assert_match(/<svg\s[^>]*width="100"[^>]*>/, output, 1)
      refute_match(/<svg\s[^>]*width="500"[^>]*>/, output)
      refute_match(/<svg\s[^>]*height="500"[^>]*>/, output)
      refute_match(/<svg\s[^>]*style="[^>]*>/, output)
    end

    test 'should honor percentage width for SVG image with inline option' do
      input = <<~'EOS'
      :imagesdir: fixtures

      image::circle.svg[Circle,50%,opts=inline]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER, attributes: { 'docdir' => testdir }
      assert_match(/<svg\s[^>]*width="50%"[^>]*>/, output, 1)
    end

    test 'should not crash if explicit width on SVG image block is an integer' do
      input = <<~'EOS'
      :imagesdir: fixtures

      image::circle.svg[Circle,opts=inline]
      EOS

      doc = document_from_string input, safe: Asciidoctor::SafeMode::SERVER, attributes: { 'docdir' => testdir }
      doc.blocks[0].set_attr 'width', 50
      output = doc.convert
      assert_match %r/<svg\s[^>]*width="50"[^>]*>/, output, 1
    end

    test 'converts to inline SVG image when inline option is set on block and data-uri is set on document' do
      input = <<~'EOS'
      :imagesdir: fixtures
      :data-uri:

      [%inline]
      image::circle.svg[Tiger,100]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER, attributes: { 'docdir' => testdir }
      assert_match(/<svg\s[^>]*width="100">/, output, 1)
    end

    test 'should not throw exception if SVG to inline is empty' do
      input = 'image::empty.svg[nada,opts=inline]'
      output = convert_string_to_embedded input, safe: :safe, attributes: { 'docdir' => testdir, 'imagesdir' => 'fixtures' }
      assert_xpath '//svg', output, 0
      assert_xpath '//span[@class="alt"][text()="nada"]', output, 1
      assert_message @logger, :WARN, '~contents of SVG is empty:'
    end

    test 'should not throw exception if SVG to inline contains an incomplete start tag and explicit width is specified' do
      input = 'image::incomplete.svg[,200,opts=inline]'
      output = convert_string_to_embedded input, safe: :safe, attributes: { 'docdir' => testdir, 'imagesdir' => 'fixtures' }
      assert_xpath '//svg', output, 1
      assert_xpath '//span[@class="alt"]', output, 0
    end

    test 'embeds remote SVG to inline when inline option is set on block and allow-uri-read is set on document' do
      input = %(image::http://#{resolve_localhost}:9876/fixtures/circle.svg[Circle,100,100,opts=inline])
      output = using_test_webserver do
        convert_string_to_embedded input, safe: :safe, attributes: { 'allow-uri-read' => '' }
      end

      assert_css 'svg', output, 1
      assert_css 'svg[style]', output, 0
      assert_css 'svg[width="100"]', output, 1
      assert_css 'svg[height="100"]', output, 1
      assert_css 'svg circle', output, 1
    end

    test 'converts to alt text for SVG with inline option set if SVG cannot be read' do
      input = <<~'EOS'
      [%inline]
      image::no-such-image.svg[Alt Text]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '//span[@class="alt"][text()="Alt Text"]', output, 1
      assert_message @logger, :WARN, '~SVG does not exist or cannot be read'
    end

    test 'can convert block image with alt text defined in macro containing square bracket' do
      input = 'image::images/tiger.png[A [Bengal] Tiger]'
      output = convert_string input
      img = xmlnodes_at_xpath '//img', output, 1
      assert_equal 'A [Bengal] Tiger', img.attr('alt')
    end

    test 'can convert block image with target containing spaces' do
      input = 'image::images/big tiger.png[A Big Tiger]'
      output = convert_string input
      img = xmlnodes_at_xpath '//img', output, 1
      assert_equal 'images/big%20tiger.png', img.attr('src')
      assert_equal 'A Big Tiger', img.attr('alt')
    end

    test 'should not recognize block image if target has leading or trailing spaces' do
      [' tiger.png', 'tiger.png '].each do |target|
        input = %(image::#{target}[Tiger])

        output = convert_string_to_embedded input
        assert_xpath '//img', output, 0
      end
    end

    test 'can convert block image with alt text defined in block attribute above macro' do
      input = <<~'EOS'
      [Tiger]
      image::images/tiger.png[]
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'alt text in macro overrides alt text above macro' do
      input = <<~'EOS'
      [Alt Text]
      image::images/tiger.png[Tiger]
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'should substitute attribute references in alt text defined in image block macro' do
      input = <<~'EOS'
      :alt-text: Tiger

      image::images/tiger.png[{alt-text}]
      EOS
      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'should set direction CSS class on image if float attribute is set' do
      input = <<~'EOS'
      [float=left]
      image::images/tiger.png[Tiger]
      EOS

      output = convert_string_to_embedded input
      assert_css '.imageblock.left', output, 1
      assert_css '.imageblock[style]', output, 0
    end

    test 'should set text alignment CSS class on image if align attribute is set' do
      input = <<~'EOS'
      [align=center]
      image::images/tiger.png[Tiger]
      EOS

      output = convert_string_to_embedded input
      assert_css '.imageblock.text-center', output, 1
      assert_css '.imageblock[style]', output, 0
    end

    test 'style attribute is dropped from image macro' do
      input = <<~'EOS'
      [style=value]
      image::images/tiger.png[Tiger]
      EOS

      doc = document_from_string input
      img = doc.blocks[0]
      refute(img.attributes.key? 'style')
      assert_nil img.style
    end

    test 'should apply specialcharacters and replacement substitutions to alt text' do
      input = 'A tiger\'s "roar" is < a bear\'s "growl"'
      expected = 'A tiger&#8217;s &quot;roar&quot; is &lt; a bear&#8217;s &quot;growl&quot;'
      result = convert_string_to_embedded %(image::images/tiger-roar.png[#{input}])
      assert_includes result, %(alt="#{expected}")
    end

    test 'should not encode double quotes in alt text when converting to DocBook' do
      input = 'Select "File > Open"'
      expected = 'Select "File &gt; Open"'
      result = convert_string_to_embedded %(image::images/open.png[#{input}]), backend: :docbook
      assert_includes result, %(<phrase>#{expected}</phrase>)
    end

    test 'should auto-generate alt text for block image if alt text is not specified' do
      input = 'image::images/lions-and-tigers.png[]'
      image = block_from_string input
      assert_equal 'lions and tigers', (image.attr 'alt')
      assert_equal 'lions and tigers', (image.attr 'default-alt')
      output = image.convert
      assert_xpath '/*[@class="imageblock"]//img[@src="images/lions-and-tigers.png"][@alt="lions and tigers"]', output, 1
    end

    test "can convert block image with alt text and height and width" do
      input = 'image::images/tiger.png[Tiger, 200, 300]'
      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"][@width="200"][@height="300"]', output, 1
    end

    test 'should not output empty width attribute if positional width attribute is empty' do
      input = 'image::images/tiger.png[Tiger,]'
      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"]', output, 1
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@width]', output, 0
    end

    test "can convert block image with link" do
      input = <<~'EOS'
      image::images/tiger.png[Tiger, link='http://en.wikipedia.org/wiki/Tiger']
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//a[@class="image"][@href="http://en.wikipedia.org/wiki/Tiger"]/img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'adds rel=noopener attribute to block image with link that targets _blank window' do
      input = 'image::images/tiger.png[Tiger,link=http://en.wikipedia.org/wiki/Tiger,window=_blank]'
      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//a[@class="image"][@href="http://en.wikipedia.org/wiki/Tiger"][@target="_blank"][@rel="noopener"]/img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'adds rel=noopener attribute to block image with link that targets name window when the noopener option is set' do
      input = 'image::images/tiger.png[Tiger,link=http://en.wikipedia.org/wiki/Tiger,window=name,opts=noopener]'
      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//a[@class="image"][@href="http://en.wikipedia.org/wiki/Tiger"][@target="name"][@rel="noopener"]/img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'adds rel=nofollow attribute to block image with a link when the nofollow option is set' do
      input = 'image::images/tiger.png[Tiger,link=http://en.wikipedia.org/wiki/Tiger,opts=nofollow]'
      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//a[@class="image"][@href="http://en.wikipedia.org/wiki/Tiger"][@rel="nofollow"]/img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'can convert block image with caption' do
      input = <<~'EOS'
      .The AsciiDoc Tiger
      image::images/tiger.png[Tiger]
      EOS

      doc = document_from_string input
      assert_equal 1, doc.blocks[0].numeral
      output = doc.convert
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
      assert_xpath '//*[@class="imageblock"]/*[@class="title"][text()="Figure 1. The AsciiDoc Tiger"]', output, 1
      assert_equal 1, doc.attributes['figure-number']
    end

    test 'can convert block image with explicit caption' do
      input = <<~'EOS'
      [caption="Voila! "]
      .The AsciiDoc Tiger
      image::images/tiger.png[Tiger]
      EOS

      doc = document_from_string input
      assert_nil doc.blocks[0].numeral
      output = doc.convert
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
      assert_xpath '//*[@class="imageblock"]/*[@class="title"][text()="Voila! The AsciiDoc Tiger"]', output, 1
      refute doc.attributes.key?('figure-number')
    end

    test 'can align image in DocBook backend' do
      input = 'image::images/sunset.jpg[Sunset,align=right]'
      output = convert_string_to_embedded input, backend: :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@align="right"]', output, 1
    end

    test 'should set content width and depth in DocBook backend if no scaling' do
      input = 'image::images/sunset.jpg[Sunset,500,332]'
      output = convert_string_to_embedded input, backend: :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@contentwidth="500"]', output, 1
      assert_xpath '//imagedata[@contentdepth="332"]', output, 1
      assert_xpath '//imagedata[@width]', output, 0
      assert_xpath '//imagedata[@depth]', output, 0
    end

    test 'can scale image in DocBook backend' do
      input = 'image::images/sunset.jpg[Sunset,500,332,scale=200]'
      output = convert_string_to_embedded input, backend: :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@scale="200"]', output, 1
      assert_xpath '//imagedata[@width]', output, 0
      assert_xpath '//imagedata[@depth]', output, 0
      assert_xpath '//imagedata[@contentwidth]', output, 0
      assert_xpath '//imagedata[@contentdepth]', output, 0
    end

    test 'scale image width in DocBook backend' do
      input = 'image::images/sunset.jpg[Sunset,500,332,scaledwidth=25%]'
      output = convert_string_to_embedded input, backend: :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@width="25%"]', output, 1
      assert_xpath '//imagedata[@depth]', output, 0
      assert_xpath '//imagedata[@contentwidth]', output, 0
      assert_xpath '//imagedata[@contentdepth]', output, 0
    end

    test 'adds % to scaled width if no units given in DocBook backend ' do
      input = 'image::images/sunset.jpg[Sunset,scaledwidth=25]'
      output = convert_string_to_embedded input, backend: :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@width="25%"]', output, 1
    end

    test 'keeps attribute reference unprocessed if image target is missing attribute reference and attribute-missing is skip' do
      input = <<~'EOS'
      :attribute-missing: skip

      image::{bogus}[]
      EOS

      output = convert_string_to_embedded input
      assert_css 'img[src="{bogus}"]', output, 1
      assert_empty @logger
    end

    test 'should not drop line if image target is missing attribute reference and attribute-missing is drop' do
      input = <<~'EOS'
      :attribute-missing: drop

      image::{bogus}/photo.jpg[]
      EOS

      output = convert_string_to_embedded input
      assert_css 'img[src="/photo.jpg"]', output, 1
      assert_empty @logger
    end

    test 'drops line if image target is missing attribute reference and attribute-missing is drop-line' do
      input = <<~'EOS'
      :attribute-missing: drop-line

      image::{bogus}[]
      EOS

      output = convert_string_to_embedded input
      assert_empty output.strip
      assert_message @logger, :INFO, 'dropping line containing reference to missing attribute: bogus'
    end

    test 'should not drop line if image target resolves to blank and attribute-missing is drop-line' do
      input = <<~'EOS'
      :attribute-missing: drop-line

      image::{blank}[]
      EOS

      output = convert_string_to_embedded input
      assert_css 'img[src=""]', output, 1
      assert_empty @logger
    end

    test 'dropped image does not break processing of following section and attribute-missing is drop-line' do
      input = <<~'EOS'
      :attribute-missing: drop-line

      image::{bogus}[]

      == Section Title
      EOS

      output = convert_string_to_embedded input
      assert_css 'img', output, 0
      assert_css 'h2', output, 1
      refute_includes output, '== Section Title'
      assert_message @logger, :INFO, 'dropping line containing reference to missing attribute: bogus'
    end

    test 'should pass through image that references uri' do
      input = <<~'EOS'
      :imagesdir: images

      image::http://asciidoc.org/images/tiger.png[Tiger]
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="http://asciidoc.org/images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'should encode spaces in image target if value is a URI' do
      input = 'image::http://example.org/svg?digraph=digraph G { a -> b; }[diagram]'
      output = convert_string_to_embedded input
      assert_xpath %(/*[@class="imageblock"]//img[@src="http://example.org/svg?digraph=digraph%20G%20{%20a%20-#{decode_char 62}%20b;%20}"]), output, 1
    end

    test 'can resolve image relative to imagesdir' do
      input = <<~'EOS'
      :imagesdir: images

      image::tiger.png[Tiger]
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'embeds base64-encoded data uri for image when data-uri attribute is set' do
      input = <<~'EOS'
      :data-uri:
      :imagesdir: fixtures

      image::dot.gif[Dot]
      EOS

      doc = document_from_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_equal 'fixtures', doc.attributes['imagesdir']
      output = doc.convert
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'embeds SVG image with image/svg+xml mimetype when file extension is .svg' do
      input = <<~'EOS'
      :imagesdir: fixtures
      :data-uri:

      image::circle.svg[Tiger,100]
      EOS

      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER, attributes: { 'docdir' => testdir }
      assert_xpath '//img[starts-with(@src,"data:image/svg+xml;base64,")]', output, 1
    end

    test 'embeds empty base64-encoded data uri for unreadable image when data-uri attribute is set' do
      input = <<~'EOS'
      :data-uri:
      :imagesdir: fixtures

      image::unreadable.gif[Dot]
      EOS

      doc = document_from_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_equal 'fixtures', doc.attributes['imagesdir']
      output = doc.convert
      assert_xpath '//img[@src="data:image/gif;base64,"]', output, 1
      assert_message @logger, :WARN, '~image to embed not found or not readable'
    end

    test 'embeds base64-encoded data uri with application/octet-stream mimetype when file extension is missing' do
      input = <<~'EOS'
      :data-uri:
      :imagesdir: fixtures

      image::dot[Dot]
      EOS

      doc = document_from_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_equal 'fixtures', doc.attributes['imagesdir']
      output = doc.convert
      assert_xpath '//img[starts-with(@src,"data:application/octet-stream;base64,")]', output, 1
    end

    test 'embeds base64-encoded data uri for remote image when data-uri attribute is set' do
      input = <<~EOS
      :data-uri:

      image::http://#{resolve_localhost}:9876/fixtures/dot.gif[Dot]
      EOS

      output = using_test_webserver do
        convert_string_to_embedded input, safe: :safe, attributes: { 'allow-uri-read' => '' }
      end

      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'embeds base64-encoded data uri for remote image when imagesdir is a URI and data-uri attribute is set' do
      input = <<~EOS
      :data-uri:
      :imagesdir: http://#{resolve_localhost}:9876/fixtures

      image::dot.gif[Dot]
      EOS

      output = using_test_webserver do
        convert_string_to_embedded input, safe: :safe, attributes: { 'allow-uri-read' => '' }
      end

      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'uses remote image uri when data-uri attribute is set and image cannot be retrieved' do
      image_uri = "http://#{resolve_localhost}:9876/fixtures/missing-image.gif"
      input = <<~EOS
      :data-uri:

      image::#{image_uri}[Missing image]
      EOS

      output = using_test_webserver do
        convert_string_to_embedded input, safe: :safe, attributes: { 'allow-uri-read' => '' }
      end

      assert_xpath %(/*[@class="imageblock"]//img[@src="#{image_uri}"][@alt="Missing image"]), output, 1
      assert_message @logger, :WARN, '~could not retrieve image data from URI'
    end

    test 'uses remote image uri when data-uri attribute is set and allow-uri-read is not set' do
      image_uri = "http://#{resolve_localhost}:9876/fixtures/dot.gif"
      input = <<~EOS
      :data-uri:

      image::#{image_uri}[Dot]
      EOS

      output = using_test_webserver do
        convert_string_to_embedded input, safe: :safe
      end

      assert_xpath %(/*[@class="imageblock"]//img[@src="#{image_uri}"][@alt="Dot"]), output, 1
    end

    test 'can handle embedded data uri images' do
      input = 'image::data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs=[Dot]'
      output = convert_string_to_embedded input
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'can handle embedded data uri images when data-uri attribute is set' do
      input = <<~'EOS'
      :data-uri:

      image::data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs=[Dot]
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'cleans reference to ancestor directories in imagesdir before reading image if safe mode level is at least SAFE' do
      input = <<~'EOS'
      :data-uri:
      :imagesdir: ../..//fixtures/./../../fixtures

      image::dot.gif[Dot]
      EOS

      doc = document_from_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_equal '../..//fixtures/./../../fixtures', doc.attributes['imagesdir']
      output = doc.convert
      # image target resolves to fixtures/dot.gif relative to docdir (which is explicitly set to the directory of this file)
      # the reference cannot fall outside of the document directory in safe mode
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
      assert_message @logger, :WARN, 'image has illegal reference to ancestor of jail; recovering automatically'
    end

    test 'cleans reference to ancestor directories in target before reading image if safe mode level is at least SAFE' do
      input = <<~'EOS'
      :data-uri:
      :imagesdir: ./

      image::../..//fixtures/./../../fixtures/dot.gif[Dot]
      EOS

      doc = document_from_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_equal './', doc.attributes['imagesdir']
      output = doc.convert
      # image target resolves to fixtures/dot.gif relative to docdir (which is explicitly set to the directory of this file)
      # the reference cannot fall outside of the document directory in safe mode
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
      assert_message @logger, :WARN, 'image has illegal reference to ancestor of jail; recovering automatically'
    end
  end

  context 'Media' do
    test 'should detect and convert video macro' do
      input = 'video::cats-vs-dogs.avi[]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
    end

    test 'should detect and convert video macro with positional attributes for poster and dimensions' do
      input = 'video::cats-vs-dogs.avi[cats-and-dogs.png, 200, 300]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
      assert_css 'video[poster="cats-and-dogs.png"]', output, 1
      assert_css 'video[width="200"]', output, 1
      assert_css 'video[height="300"]', output, 1
    end

    test 'should set direction CSS class on video block if float attribute is set' do
      input = 'video::cats-vs-dogs.avi[cats-and-dogs.png,float=right]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
      assert_css '.videoblock.right', output, 1
    end

    test 'should set text alignment CSS class on video block if align attribute is set' do
      input = 'video::cats-vs-dogs.avi[cats-and-dogs.png,align=center]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
      assert_css '.videoblock.text-center', output, 1
    end

    test 'video macro should honor all options' do
      input = 'video::cats-vs-dogs.avi[options="autoplay,muted,nocontrols,loop",preload="metadata"]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[autoplay]', output, 1
      assert_css 'video[muted]', output, 1
      assert_css 'video:not([controls])', output, 1
      assert_css 'video[loop]', output, 1
      assert_css 'video[preload=metadata]', output, 1
    end

    test 'video macro should add time range anchor with start time if start attribute is set' do
      input = 'video::cats-vs-dogs.avi[start="30"]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_xpath '//video[@src="cats-vs-dogs.avi#t=30"]', output, 1
    end

    test 'video macro should add time range anchor with end time if end attribute is set' do
      input = 'video::cats-vs-dogs.avi[end="30"]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_xpath '//video[@src="cats-vs-dogs.avi#t=,30"]', output, 1
    end

    test 'video macro should add time range anchor with start and end time if start and end attributes are set' do
      input = 'video::cats-vs-dogs.avi[start="30",end="60"]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_xpath '//video[@src="cats-vs-dogs.avi#t=30,60"]', output, 1
    end

    test 'video macro should use imagesdir attribute to resolve target and poster' do
      input = <<~'EOS'
      :imagesdir: assets

      video::cats-vs-dogs.avi[cats-and-dogs.png, 200, 300]
      EOS

      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[src="assets/cats-vs-dogs.avi"]', output, 1
      assert_css 'video[poster="assets/cats-and-dogs.png"]', output, 1
      assert_css 'video[width="200"]', output, 1
      assert_css 'video[height="300"]', output, 1
    end

    test 'video macro should not use imagesdir attribute to resolve target if target is a URL' do
      input = <<~'EOS'
      :imagesdir: assets

      video::http://example.org/videos/cats-vs-dogs.avi[]
      EOS

      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[src="http://example.org/videos/cats-vs-dogs.avi"]', output, 1
    end

    test 'video macro should output custom HTML with iframe for vimeo service' do
      input = 'video::67480300[vimeo, 400, 300, start=60, options="autoplay,muted"]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 0
      assert_css 'iframe', output, 1
      assert_css 'iframe[src="https://player.vimeo.com/video/67480300?autoplay=1&muted=1#at=60"]', output, 1
      assert_css 'iframe[width="400"]', output, 1
      assert_css 'iframe[height="300"]', output, 1
    end

    test 'video macro should output custom HTML with iframe for youtube service' do
      input = 'video::U8GBXvdmHT4/PLg7s6cbtAD15Das5LK9mXt_g59DLWxKUe[youtube, 640, 360, start=60, options="autoplay,muted,modest", theme=light]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 0
      assert_css 'iframe', output, 1
      assert_css 'iframe[src="https://www.youtube.com/embed/U8GBXvdmHT4?rel=0&start=60&autoplay=1&mute=1&list=PLg7s6cbtAD15Das5LK9mXt_g59DLWxKUe&modestbranding=1&theme=light"]', output, 1
      assert_css 'iframe[width="640"]', output, 1
      assert_css 'iframe[height="360"]', output, 1
    end

    test 'video macro should output custom HTML with iframe for youtube service with dynamic playlist' do
      input = 'video::SCZF6I-Rc4I,AsKGOeonbIs,HwrPhOp6-aM[youtube, 640, 360, start=60, options=autoplay]'
      output = convert_string_to_embedded input
      assert_css 'video', output, 0
      assert_css 'iframe', output, 1
      assert_css 'iframe[src="https://www.youtube.com/embed/SCZF6I-Rc4I?rel=0&start=60&autoplay=1&playlist=AsKGOeonbIs,HwrPhOp6-aM"]', output, 1
      assert_css 'iframe[width="640"]', output, 1
      assert_css 'iframe[height="360"]', output, 1
    end

    test 'should detect and convert audio macro' do
      input = 'audio::podcast.mp3[]'
      output = convert_string_to_embedded input
      assert_css 'audio', output, 1
      assert_css 'audio[src="podcast.mp3"]', output, 1
    end

    test 'audio macro should use imagesdir attribute to resolve target' do
      input = <<~'EOS'
      :imagesdir: assets

      audio::podcast.mp3[]
      EOS

      output = convert_string_to_embedded input
      assert_css 'audio', output, 1
      assert_css 'audio[src="assets/podcast.mp3"]', output, 1
    end

    test 'audio macro should not use imagesdir attribute to resolve target if target is a URL' do
      input = <<~'EOS'
      :imagesdir: assets

      video::http://example.org/podcast.mp3[]
      EOS

      output = convert_string_to_embedded input
      assert_css 'video', output, 1
      assert_css 'video[src="http://example.org/podcast.mp3"]', output, 1
    end

    test 'audio macro should honor all options' do
      input = 'audio::podcast.mp3[options="autoplay,nocontrols,loop"]'
      output = convert_string_to_embedded input
      assert_css 'audio', output, 1
      assert_css 'audio[autoplay]', output, 1
      assert_css 'audio:not([controls])', output, 1
      assert_css 'audio[loop]', output, 1
    end

    test 'audio macro should support start and end time' do
      input = 'audio::podcast.mp3[start=1,end=2]'
      output = convert_string_to_embedded input
      assert_css 'audio', output, 1
      assert_css 'audio[controls]', output, 1
      assert_css 'audio[src="podcast.mp3#t=1,2"]', output, 1
    end
  end

  context 'Admonition icons' do
    test 'can resolve icon relative to default iconsdir' do
      input = <<~'EOS'
      :icons:

      [TIP]
      You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="./images/icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'can resolve icon relative to custom iconsdir' do
      input = <<~'EOS'
      :icons:
      :iconsdir: icons

      [TIP]
      You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'should add file extension to custom icon if not specified' do
      input = <<~'EOS'
      :icons: font
      :iconsdir: images/icons

      [TIP,icon=a]
      Override the icon of an admonition block using an attribute
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="images/icons/a.png"]', output, 1
    end

    test 'should allow icontype to be specified when using built-in admonition icon' do
      input = 'TIP: Set the icontype using either the icontype attribute on the icons attribute.'
      [
        { 'icons' => '', 'ext' => 'png' },
        { 'icons' => '', 'icontype' => 'jpg', 'ext' => 'jpg' },
        { 'icons' => 'jpg', 'ext' => 'jpg' },
        { 'icons' => 'image', 'ext' => 'png' },
      ].each do |attributes|
        expected_src = %(./images/icons/tip.#{attributes.delete 'ext'})
        output = convert_string input, attributes: attributes
        assert_xpath %(//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="#{expected_src}"]), output, 1
      end
    end

    test 'should allow icontype to be specified when using custom admonition icon' do
      input = <<~'EOS'
      [TIP,icon=hint]
      Set the icontype using either the icontype attribute on the icons attribute.
      EOS
      [
        { 'icons' => '', 'ext' => 'png' },
        { 'icons' => '', 'icontype' => 'jpg', 'ext' => 'jpg' },
        { 'icons' => 'jpg', 'ext' => 'jpg' },
        { 'icons' => 'image', 'ext' => 'png' },
      ].each do |attributes|
        expected_src = %(./images/icons/hint.#{attributes.delete 'ext'})
        output = convert_string input, attributes: attributes
        assert_xpath %(//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="#{expected_src}"]), output, 1
      end
    end

    test 'embeds base64-encoded data uri of icon when data-uri attribute is set and safe mode level is less than SECURE' do
      input = <<~'EOS'
      :icons:
      :iconsdir: fixtures
      :icontype: gif
      :data-uri:

      [TIP]
      You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end

    test 'should embed base64-encoded data uri of custom icon when data-uri attribute is set' do
      input = <<~'EOS'
      :icons:
      :iconsdir: fixtures
      :icontype: gif
      :data-uri:

      [TIP,icon=tip]
      You can set a custom icon using the icon attribute on the block.
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end

    test 'does not embed base64-encoded data uri of icon when safe mode level is SECURE or greater' do
      input = <<~'EOS'
      :icons:
      :iconsdir: fixtures
      :icontype: gif
      :data-uri:

      [TIP]
      You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = convert_string input, attributes: { 'icons' => '' }
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="fixtures/tip.gif"][@alt="Tip"]', output, 1
    end

    test 'cleans reference to ancestor directories before reading icon if safe mode level is at least SAFE' do
      input = <<~'EOS'
      :icons:
      :iconsdir: ../fixtures
      :icontype: gif
      :data-uri:

      [TIP]
      You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => testdir }
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
      assert_message @logger, :WARN, 'image has illegal reference to ancestor of jail; recovering automatically'
    end

    test 'should import Font Awesome and use font-based icons when value of icons attribute is font' do
      input = <<~'EOS'
      :icons: font

      [TIP]
      You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SERVER
      assert_css %(html > head > link[rel="stylesheet"][href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/#{Asciidoctor::FONT_AWESOME_VERSION}/css/font-awesome.min.css"]), output, 1
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/i[@class="fa icon-tip"]', output, 1
    end

    test 'font-based icon should not override icon specified on admonition' do
      input = <<~'EOS'
      :icons: font
      :iconsdir: images/icons

      [TIP,icon=a.png]
      Override the icon of an admonition block using an attribute
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/i[@class="fa icon-tip"]', output, 0
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="images/icons/a.png"]', output, 1
    end

    test 'should use http uri scheme for assets when asset-uri-scheme is http' do
      input = <<~'EOS'
      :asset-uri-scheme: http
      :icons: font
      :source-highlighter: highlightjs

      TIP: You can control the URI scheme used for assets with the asset-uri-scheme attribute

      [source,ruby]
      puts "AsciiDoc, FTW!"
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SAFE
      assert_css %(html > head > link[rel="stylesheet"][href="http://cdnjs.cloudflare.com/ajax/libs/font-awesome/#{Asciidoctor::FONT_AWESOME_VERSION}/css/font-awesome.min.css"]), output, 1
      assert_css %(html > body > script[src="http://cdnjs.cloudflare.com/ajax/libs/highlight.js/#{Asciidoctor::HIGHLIGHT_JS_VERSION}/highlight.min.js"]), output, 1
    end

    test 'should use no uri scheme for assets when asset-uri-scheme is blank' do
      input = <<~'EOS'
      :asset-uri-scheme:
      :icons: font
      :source-highlighter: highlightjs

      TIP: You can control the URI scheme used for assets with the asset-uri-scheme attribute

      [source,ruby]
      puts "AsciiDoc, FTW!"
      EOS

      output = convert_string input, safe: Asciidoctor::SafeMode::SAFE
      assert_css %(html > head > link[rel="stylesheet"][href="//cdnjs.cloudflare.com/ajax/libs/font-awesome/#{Asciidoctor::FONT_AWESOME_VERSION}/css/font-awesome.min.css"]), output, 1
      assert_css %(html > body > script[src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/#{Asciidoctor::HIGHLIGHT_JS_VERSION}/highlight.min.js"]), output, 1
    end
  end

  context 'Image paths' do
    test 'restricts access to ancestor directories when safe mode level is at least SAFE' do
      input = 'image::asciidoctor.png[Asciidoctor]'
      basedir = testdir
      block = block_from_string input, attributes: { 'docdir' => basedir }
      doc = block.document
      assert doc.safe >= Asciidoctor::SafeMode::SAFE

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      assert_equal File.join(basedir, 'etc/images'), block.normalize_asset_path("#{disk_root}etc/images")
      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('../../images')
    end

    test 'does not restrict access to ancestor directories when safe mode is disabled' do
      input = 'image::asciidoctor.png[Asciidoctor]'
      basedir = testdir
      block = block_from_string input, safe: Asciidoctor::SafeMode::UNSAFE, attributes: { 'docdir' => basedir }
      doc = block.document
      assert doc.safe == Asciidoctor::SafeMode::UNSAFE

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      absolute_path = "#{disk_root}etc/images"
      assert_equal absolute_path, block.normalize_asset_path(absolute_path)
      assert_equal File.expand_path(File.join(basedir, '../../images')), block.normalize_asset_path('../../images')
    end
  end

  context 'Source code' do
    test 'should support fenced code block using backticks' do
      input = <<~'EOS'
      ```
      puts "Hello, World!"
      ```
      EOS

      output = convert_string_to_embedded input
      assert_css '.listingblock', output, 1
      assert_css '.listingblock pre code', output, 1
      assert_css '.listingblock pre code:not([class])', output, 1
    end

    test 'should not recognize fenced code blocks with more than three delimiters' do
      input = <<~'EOS'
      ````ruby
      puts "Hello, World!"
      ````

      ~~~~ javascript
      alert("Hello, World!")
      ~~~~
      EOS

      output = convert_string_to_embedded input
      assert_css '.listingblock', output, 0
    end

    test 'should support fenced code blocks with languages' do
      input = <<~'EOS'
      ```ruby
      puts "Hello, World!"
      ```

      ``` javascript
      alert("Hello, World!")
      ```
      EOS

      output = convert_string_to_embedded input
      assert_css '.listingblock', output, 2
      assert_css '.listingblock pre code.language-ruby[data-lang=ruby]', output, 1
      assert_css '.listingblock pre code.language-javascript[data-lang=javascript]', output, 1
    end

    test 'should support fenced code blocks with languages and numbering' do
      input = <<~'EOS'
      ```ruby,numbered
      puts "Hello, World!"
      ```

      ``` javascript, numbered
      alert("Hello, World!")
      ```
      EOS

      output = convert_string_to_embedded input
      assert_css '.listingblock', output, 2
      assert_css '.listingblock pre code.language-ruby[data-lang=ruby]', output, 1
      assert_css '.listingblock pre code.language-javascript[data-lang=javascript]', output, 1
    end
  end

  context 'Abstract and Part Intro' do
    test 'should make abstract on open block without title a quote block for article' do
      input = <<~'EOS'
      = Article

      [abstract]
      --
      This article is about stuff.

      And other stuff.
      --

      == Section One

      content
      EOS

      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock.abstract', output, 1
      assert_css '#preamble .quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph', output, 2
    end

    test 'should make abstract on open block with title a quote block with title for article' do
      input = <<~'EOS'
      = Article

      .My abstract
      [abstract]
      --
      This article is about stuff.
      --

      == Section One

      content
      EOS

      output = convert_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock.abstract', output, 1
      assert_css '#preamble .quoteblock', output, 1
      assert_css '.quoteblock > .title', output, 1
      assert_css '.quoteblock > .title + blockquote', output, 1
      assert_css '.quoteblock > .title + blockquote > .paragraph', output, 1
    end

    test 'should allow abstract in document with title if doctype is book' do
      input = <<~'EOS'
      = Book
      :doctype: book

      [abstract]
      Abstract for book with title is valid
      EOS

      output = convert_string input
      assert_css '.abstract', output, 1
    end

    test 'should not allow abstract as direct child of document if doctype is book' do
      input = <<~'EOS'
      :doctype: book

      [abstract]
      Abstract for book without title is invalid.
      EOS

      output = convert_string input
      assert_css '.abstract', output, 0
      assert_message @logger, :WARN, 'abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
    end

    test 'should make abstract on open block without title converted to DocBook' do
      input = <<~'EOS'
      = Article

      [abstract]
      --
      This article is about stuff.

      And other stuff.
      --
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'abstract', output, 1
      assert_css 'abstract > simpara', output, 2
    end

    test 'should make abstract on open block with title converted to DocBook' do
      input = <<~'EOS'
      = Article

      .My abstract
      [abstract]
      --
      This article is about stuff.
      --
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'abstract', output, 1
      assert_css 'abstract > title', output, 1
      assert_css 'abstract > title + simpara', output, 1
    end

    test 'should allow abstract in document with title if doctype is book converted to DocBook' do
      input = <<~'EOS'
      = Book
      :doctype: book

      [abstract]
      Abstract for book with title is valid
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'abstract', output, 1
    end

    test 'should not allow abstract as direct child of document if doctype is book converted to DocBook' do
      input = <<~'EOS'
      :doctype: book

      [abstract]
      Abstract for book is invalid.
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'abstract', output, 0
      assert_message @logger, :WARN, 'abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
    end

    # TODO partintro shouldn't be recognized if doctype is not book, should be in proper place
    test 'should accept partintro on open block without title' do
      input = <<~'EOS'
      = Book
      :doctype: book

      = Part 1

      [partintro]
      --
      This is a part intro.

      It can have multiple paragraphs.
      --

      == Chapter 1

      content
      EOS

      output = convert_string input
      assert_css '.openblock', output, 1
      assert_css '.openblock.partintro', output, 1
      assert_css '.openblock .title', output, 0
      assert_css '.openblock .content', output, 1
      assert_xpath %(//h1[@id="_part_1"]/following-sibling::*[#{contains_class(:openblock)}]), output, 1
      assert_xpath %(//*[#{contains_class(:openblock)}]/*[@class="content"]/*[@class="paragraph"]), output, 2
    end

    test 'should accept partintro on open block with title' do
      input = <<~'EOS'
      = Book
      :doctype: book

      = Part 1

      .Intro title
      [partintro]
      --
      This is a part intro with a title.
      --

      == Chapter 1

      content
      EOS

      output = convert_string input
      assert_css '.openblock', output, 1
      assert_css '.openblock.partintro', output, 1
      assert_css '.openblock .title', output, 1
      assert_css '.openblock .content', output, 1
      assert_xpath %(//h1[@id="_part_1"]/following-sibling::*[#{contains_class(:openblock)}]), output, 1
      assert_xpath %(//*[#{contains_class(:openblock)}]/*[@class="title"][text()="Intro title"]), output, 1
      assert_xpath %(//*[#{contains_class(:openblock)}]/*[@class="content"]/*[@class="paragraph"]), output, 1
    end

    test 'should exclude partintro if not a child of part' do
      input = <<~'EOS'
      = Book
      :doctype: book

      [partintro]
      part intro paragraph
      EOS

      output = convert_string input
      assert_css '.partintro', output, 0
      assert_message @logger, :ERROR, 'partintro block can only be used when doctype is book and must be a child of a book part. Excluding block content.'
    end

    test 'should not allow partintro unless doctype is book' do
      input = <<~'EOS'
      [partintro]
      part intro paragraph
      EOS

      output = convert_string input
      assert_css '.partintro', output, 0
      assert_message @logger, :ERROR, 'partintro block can only be used when doctype is book and must be a child of a book part. Excluding block content.'
    end

    test 'should accept partintro on open block without title converted to DocBook' do
      input = <<~'EOS'
      = Book
      :doctype: book

      = Part 1

      [partintro]
      --
      This is a part intro.

      It can have multiple paragraphs.
      --

      == Chapter 1

      content
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'partintro', output, 1
      assert_css 'part[xml|id="_part_1"] > partintro', output, 1
      assert_css 'partintro > simpara', output, 2
    end

    test 'should accept partintro on open block with title converted to DocBook' do
      input = <<~'EOS'
      = Book
      :doctype: book

      = Part 1

      .Intro title
      [partintro]
      --
      This is a part intro with a title.
      --

      == Chapter 1

      content
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'partintro', output, 1
      assert_css 'part[xml|id="_part_1"] > partintro', output, 1
      assert_css 'partintro > title', output, 1
      assert_css 'partintro > title + simpara', output, 1
    end

    test 'should exclude partintro if not a child of part converted to DocBook' do
      input = <<~'EOS'
      = Book
      :doctype: book

      [partintro]
      part intro paragraph
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'partintro', output, 0
      assert_message @logger, :ERROR, 'partintro block can only be used when doctype is book and must be a child of a book part. Excluding block content.'
    end

    test 'should not allow partintro unless doctype is book converted to DocBook' do
      input = <<~'EOS'
      [partintro]
      part intro paragraph
      EOS

      output = convert_string input, backend: 'docbook'
      assert_css 'partintro', output, 0
      assert_message @logger, :ERROR, 'partintro block can only be used when doctype is book and must be a child of a book part. Excluding block content.'
    end
  end

  context 'Substitutions' do
    test 'processor should not crash if subs are empty' do
      input = <<~'EOS'
      [subs=","]
      ....
      content
      ....
      EOS

      doc = document_from_string input
      block = doc.blocks.first
      assert_equal [], block.subs
    end

    test 'should be able to append subs to default block substitution list' do
      input = <<~'EOS'
      :application: Asciidoctor

      [subs="+attributes,+macros"]
      ....
      {application}
      ....
      EOS

      doc = document_from_string input
      block = doc.blocks.first
      assert_equal [:specialcharacters, :attributes, :macros], block.subs
    end

    test 'should be able to prepend subs to default block substitution list' do
      input = <<~'EOS'
      :application: Asciidoctor

      [subs="attributes+"]
      ....
      {application}
      ....
      EOS

      doc = document_from_string input
      block = doc.blocks.first
      assert_equal [:attributes, :specialcharacters], block.subs
    end

    test 'should be able to remove subs to default block substitution list' do
      input = <<~'EOS'
      [subs="-quotes,-replacements"]
      content
      EOS

      doc = document_from_string input
      block = doc.blocks.first
      assert_equal [:specialcharacters, :attributes, :macros, :post_replacements], block.subs
    end

    test 'should be able to prepend, append and remove subs from default block substitution list' do
      input = <<~'EOS'
      :application: asciidoctor

      [subs="attributes+,-verbatim,+specialcharacters,+macros"]
      ....
      https://{application}.org[{gt}{gt}] <1>
      ....
      EOS

      doc = document_from_string input, standalone: false
      block = doc.blocks.first
      assert_equal [:attributes, :specialcharacters, :macros], block.subs
      result = doc.convert
      assert_includes result, '<pre><a href="https://asciidoctor.org">&gt;&gt;</a> &lt;1&gt;</pre>'
    end

    test 'should be able to set subs then modify them' do
      input = <<~'EOS'
      [subs="verbatim,-callouts"]
      _hey now_ <1>
      EOS

      doc = document_from_string input, standalone: false
      block = doc.blocks.first
      assert_equal [:specialcharacters], block.subs
      result = doc.convert
      assert_includes result, '_hey now_ &lt;1&gt;'
    end
  end

  context 'References' do
    test 'should not recognize block anchor with illegal id characters' do
      input = <<~'EOS'
      [[illegal$id,Reference Text]]
      ----
      content
      ----
      EOS

      doc = document_from_string input
      block = doc.blocks.first
      assert_nil block.id
      assert_nil(block.attr 'reftext')
      refute doc.catalog[:refs].key? 'illegal$id'
    end

    test 'should not recognize block anchor that starts with digit' do
      input = <<~'EOS'
      [[3-blind-mice]]
      --
      see how they run
      --
      EOS

      output = convert_string_to_embedded input
      assert_includes output, '[[3-blind-mice]]'
      assert_xpath '/*[@id=":3-blind-mice"]', output, 0
    end

    test 'should recognize block anchor that starts with colon' do
      input = <<~'EOS'
      [[:idname]]
      --
      content
      --
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@id=":idname"]', output, 1
    end

    test 'should use specified id and reftext when registering block reference' do
      input = <<~'EOS'
      [[debian,Debian Install]]
      .Installation on Debian
      ----
      $ apt-get install asciidoctor
      ----
      EOS

      doc = document_from_string input
      ref = doc.catalog[:refs]['debian']
      refute_nil ref
      assert_equal 'Debian Install', ref.reftext
      assert_equal 'debian', (doc.resolve_id 'Debian Install')
    end

    test 'should allow square brackets in block reference text' do
      input = <<~'EOS'
      [[debian,[Debian] Install]]
      .Installation on Debian
      ----
      $ apt-get install asciidoctor
      ----
      EOS

      doc = document_from_string input
      ref = doc.catalog[:refs]['debian']
      refute_nil ref
      assert_equal '[Debian] Install', ref.reftext
      assert_equal 'debian', (doc.resolve_id '[Debian] Install')
    end

    test 'should allow comma in block reference text' do
      input = <<~'EOS'
      [[debian, Debian, Ubuntu]]
      .Installation on Debian
      ----
      $ apt-get install asciidoctor
      ----
      EOS

      doc = document_from_string input
      ref = doc.catalog[:refs]['debian']
      refute_nil ref
      assert_equal 'Debian, Ubuntu', ref.reftext
      assert_equal 'debian', (doc.resolve_id 'Debian, Ubuntu')
    end

    test 'should resolve attribute reference in title using attribute defined at location of block' do
      input = <<~'EOS'
      = Document Title
      :foo: baz

      intro paragraph. see <<free-standing>>.

      :foo: bar

      .foo is {foo}
      [#formal-para]
      paragraph with title

      [discrete#free-standing]
      == foo is still {foo}
      EOS

      doc = document_from_string input
      ref = doc.catalog[:refs]['formal-para']
      refute_nil ref
      assert_equal 'foo is bar', ref.title
      assert_equal 'formal-para', (doc.resolve_id 'foo is bar')
      output = doc.convert standalone: false
      assert_include '<a href="#free-standing">foo is still bar</a>', output
      assert_include '<h2 id="free-standing" class="discrete">foo is still bar</h2>', output
    end

    test 'should substitute attribute references in reftext when registering block reference' do
      input = <<~'EOS'
      :label-tiger: Tiger

      [[tiger-evolution,Evolution of the {label-tiger}]]
      ****
      Information about the evolution of the tiger.
      ****
      EOS

      doc = document_from_string input
      ref = doc.catalog[:refs]['tiger-evolution']
      refute_nil ref
      assert_equal 'Evolution of the Tiger', ref.attributes['reftext']
      assert_equal 'tiger-evolution', (doc.resolve_id 'Evolution of the Tiger')
    end

    test 'should use specified reftext when registering block reference' do
      input = <<~'EOS'
      [[debian]]
      [reftext="Debian Install"]
      .Installation on Debian
      ----
      $ apt-get install asciidoctor
      ----
      EOS

      doc = document_from_string input
      ref = doc.catalog[:refs]['debian']
      refute_nil ref
      assert_equal 'Debian Install', ref.reftext
      assert_equal 'debian', (doc.resolve_id 'Debian Install')
    end
  end
end
