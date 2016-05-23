# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context "Blocks" do
  context 'Line Breaks' do
    test "ruler" do
      output = render_string("'''")
      assert_xpath '//*[@id="content"]/hr', output, 1
      assert_xpath '//*[@id="content"]/*', output, 1
    end

    test "ruler between blocks" do
      output = render_string("Block above\n\n'''\n\nBlock below")
      assert_xpath '//*[@id="content"]/hr', output, 1
      assert_xpath '//*[@id="content"]/hr/preceding-sibling::*', output, 1
      assert_xpath '//*[@id="content"]/hr/following-sibling::*', output, 1
    end

    test "page break" do
      output = render_embedded_string("page 1\n\n<<<\n\npage 2")
      assert_xpath '/*[translate(@style, ";", "")="page-break-after: always"]', output, 1
      assert_xpath '/*[translate(@style, ";", "")="page-break-after: always"]/preceding-sibling::div/p[text()="page 1"]', output, 1
      assert_xpath '/*[translate(@style, ";", "")="page-break-after: always"]/following-sibling::div/p[text()="page 2"]', output, 1
    end
  end

  context 'Comments' do
    test 'line comment between paragraphs offset by blank lines' do
      input = <<-EOS
first paragraph

// line comment

second paragraph
      EOS
      output = render_embedded_string input
      refute_match(/line comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent line comment between paragraphs' do
      input = <<-EOS
first line
// line comment
second line
      EOS
      output = render_embedded_string input
      refute_match(/line comment/, output)
      assert_xpath '//p', output, 1
      assert_xpath "//p[1][text()='first line\nsecond line']", output, 1
    end

    test 'comment block between paragraphs offset by blank lines' do
      input = <<-EOS
first paragraph

////
block comment
////

second paragraph
      EOS
      output = render_embedded_string input
      refute_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent comment block between paragraphs' do
      input = <<-EOS
first paragraph
////
block comment
////
second paragraph
      EOS
      output = render_embedded_string input
      refute_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test "can render with block comment at end of document with trailing endlines" do
      input = <<-EOS
paragraph

////
block comment
////


      EOS
      output = render_embedded_string input
      refute_match(/block comment/, output)
    end

    test "trailing endlines after block comment at end of document does not create paragraph" do
      input = <<-EOS
paragraph

////
block comment
////


      EOS
      d = document_from_string input
      assert_equal 1, d.blocks.size
      assert_xpath '//p', d.render, 1
    end

    test 'line starting with three slashes should not be line comment' do
      input = <<-EOS
/// not a line comment
      EOS

      output = render_embedded_string input
      assert !output.strip.empty?, "Line should be emitted => #{input.rstrip}"
    end

    test 'preprocessor directives should not be processed within comment block within block metadata' do
      input = <<-EOS
.sample title
////
ifdef::asciidoctor[////]
////
line should be rendered
      EOS

      output = render_embedded_string input
      assert_xpath '//p[text() = "line should be rendered"]', output, 1
    end

    test 'preprocessor directives should not be processed within comment block' do
      input = <<-EOS
dummy line

////
ifdef::asciidoctor[////]
////

line should be rendered
      EOS

      output = render_embedded_string input
      assert_xpath '//p[text() = "line should be rendered"]', output, 1
    end

    # WARNING if first line of content is a directive, it will get interpretted before we know it's a comment block
    # it happens because we always look a line ahead...not sure what we can do about it
    test 'preprocessor directives should not be processed within comment open block' do
      input = <<-EOS
[comment]
--
first line of comment
ifdef::asciidoctor[--]
line should not be rendered
--

      EOS

      output = render_embedded_string input
      assert_xpath '//p', output, 0
    end

    # WARNING if first line of content is a directive, it will get interpretted before we know it's a comment block
    # it happens because we always look a line ahead...not sure what we can do about it
    test 'preprocessor directives should not be processed within comment paragraph' do
      input = <<-EOS
[comment]
first line of content
ifdef::asciidoctor[////]

this line should be rendered
      EOS

      output = render_embedded_string input
      assert_xpath '//p[text() = "this line should be rendered"]', output, 1
    end

    test 'comment style on open block should only skip block' do
      input = <<-EOS
[comment]
--
skip

this block
--

not this text
      EOS
      result = render_embedded_string input
      assert_xpath '//p', result, 1
      assert_xpath '//p[text()="not this text"]', result, 1
    end

    test 'comment style on paragraph should only skip paragraph' do
      input = <<-EOS
[comment]
skip
this paragraph

not this text
      EOS
      result = render_embedded_string input
      assert_xpath '//p', result, 1
      assert_xpath '//p[text()="not this text"]', result, 1
    end

    test 'comment style on paragraph should not cause adjacent block to be skipped' do
      input = <<-EOS
[comment]
skip
this paragraph
[example]
not this text
      EOS
      result = render_embedded_string input
      assert_xpath '/*[@class="exampleblock"]', result, 1
      assert_xpath '/*[@class="exampleblock"]//*[normalize-space(text())="not this text"]', result, 1
    end
  end

  context 'Quote and Verse Blocks' do
    test 'quote block with no attribution' do
      input = <<-EOS
____
A famous quote.
____
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath '//*[@class = "quoteblock"]//p[text() = "A famous quote."]', output, 1
    end

    test 'quote block with attribution' do
      input = <<-EOS
[quote, Famous Person, Famous Book (1999)]
____
A famous quote.
____
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 1
      assert_css '.quoteblock > .attribution > cite', output, 1
      assert_css '.quoteblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]/cite[text() = "Famous Book (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{expand_entity 8212} Famous Person", author.text.strip
    end

    test 'quote block with attribute and id and role shorthand' do
      input = <<-EOS
[quote#think.big, Donald Trump]
____
As long as your going to be thinking anyway, think big.
____
      EOS

      output = render_embedded_string input
      assert_css '.quoteblock', output, 1
      assert_css '#think.quoteblock.big', output, 1
      assert_css '.quoteblock > .attribution', output, 1
    end

    test 'quote block with complex content' do
      input = <<-EOS
____
A famous quote.

NOTE: _That_ was inspiring.
____
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph', output, 1
      assert_css '.quoteblock > blockquote > .paragraph + .admonitionblock', output, 1
    end

    test 'quote block using air quotes with no attribution' do
      input = <<-EOS
""
A famous quote.
""
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath '//*[@class = "quoteblock"]//p[text() = "A famous quote."]', output, 1
    end

    test 'markdown-style quote block with single paragraph and no attribution' do
      input = <<-EOS
> A famous quote.
> Some more inspiring words.
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %(//*[@class = "quoteblock"]//p[text() = "A famous quote.\nSome more inspiring words."]), output, 1
    end

    test 'lazy markdown-style quote block with single paragraph and no attribution' do
      input = <<-EOS
> A famous quote.
Some more inspiring words.
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %(//*[@class = "quoteblock"]//p[text() = "A famous quote.\nSome more inspiring words."]), output, 1
    end

    test 'markdown-style quote block with multiple paragraphs and no attribution' do
      input = <<-EOS
> A famous quote.
>
> Some more inspiring words.
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 2
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %((//*[@class = "quoteblock"]//p)[1][text() = "A famous quote."]), output, 1
      assert_xpath %((//*[@class = "quoteblock"]//p)[2][text() = "Some more inspiring words."]), output, 1
    end

    test 'markdown-style quote block with multiple blocks and no attribution' do
      input = <<-EOS
> A famous quote.
>
> NOTE: Some more inspiring words.
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_css '.quoteblock > blockquote > .admonitionblock', output, 1
      assert_css '.quoteblock > .attribution', output, 0
      assert_xpath %((//*[@class = "quoteblock"]//p)[1][text() = "A famous quote."]), output, 1
      assert_xpath %((//*[@class = "quoteblock"]//*[@class = "admonitionblock note"]//*[@class="content"])[1][normalize-space(text()) = "Some more inspiring words."]), output, 1
    end

    test 'markdown-style quote block with single paragraph and attribution' do
      input = <<-EOS
> A famous quote.
> Some more inspiring words.
> -- Famous Person, Famous Source, Volume 1 (1999)
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph > p', output, 1
      assert_xpath %(//*[@class = "quoteblock"]//p[text() = "A famous quote.\nSome more inspiring words."]), output, 1
      assert_css '.quoteblock > .attribution', output, 1
      assert_css '.quoteblock > .attribution > cite', output, 1
      assert_css '.quoteblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]/cite[text() = "Famous Source, Volume 1 (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{expand_entity 8212} Famous Person", author.text.strip
    end

    test 'quoted paragraph-style quote block with attribution' do
      input = <<-EOS
"A famous quote.
Some more inspiring words."
-- Famous Person, Famous Source, Volume 1 (1999)
      EOS
      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_xpath %(//*[@class = "quoteblock"]/blockquote[normalize-space(text()) = "A famous quote. Some more inspiring words."]), output, 1
      assert_css '.quoteblock > .attribution', output, 1
      assert_css '.quoteblock > .attribution > cite', output, 1
      assert_css '.quoteblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]/cite[text() = "Famous Source, Volume 1 (1999)"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{expand_entity 8212} Famous Person", author.text.strip
    end

    test 'single-line verse block without attribution' do
      input = <<-EOS
[verse]
____
A famous verse.
____
      EOS
      output = render_string input
      assert_css '.verseblock', output, 1
      assert_css '.verseblock > pre', output, 1
      assert_css '.verseblock > .attribution', output, 0
      assert_css '.verseblock p', output, 0
      assert_xpath '//*[@class = "verseblock"]/pre[normalize-space(text()) = "A famous verse."]', output, 1
    end

    test 'single-line verse block with attribution' do
      input = <<-EOS
[verse, Famous Poet, Famous Poem]
____
A famous verse.
____
      EOS
      output = render_string input
      assert_css '.verseblock', output, 1
      assert_css '.verseblock p', output, 0
      assert_css '.verseblock > pre', output, 1
      assert_css '.verseblock > .attribution', output, 1
      assert_css '.verseblock > .attribution > cite', output, 1
      assert_css '.verseblock > .attribution > br + cite', output, 1
      assert_xpath '//*[@class = "verseblock"]/*[@class = "attribution"]/cite[text() = "Famous Poem"]', output, 1
      attribution = xmlnodes_at_xpath '//*[@class = "verseblock"]/*[@class = "attribution"]', output, 1
      author = attribution.children.first
      assert_equal "#{expand_entity 8212} Famous Poet", author.text.strip
    end

    test 'multi-stanza verse block' do
      input = <<-EOS
[verse]
____
A famous verse.

Stanza two.
____
      EOS
      output = render_string input
      assert_xpath '//*[@class = "verseblock"]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre', output, 1
      assert_xpath '//*[@class = "verseblock"]//p', output, 0
      assert_xpath '//*[@class = "verseblock"]/pre[contains(text(), "A famous verse.")]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre[contains(text(), "Stanza two.")]', output, 1
    end

    test 'verse block does not contain block elements' do
      input = <<-EOS
[verse]
____
A famous verse.

....
not a literal
....
____
      EOS
      output = render_string input
      assert_css '.verseblock', output, 1
      assert_css '.verseblock > pre', output, 1
      assert_css '.verseblock p', output, 0
      assert_css '.verseblock .literalblock', output, 0
    end

    test 'verse should have normal subs' do
      input = <<-EOS
[verse]
____
A famous verse
____
      EOS

      verse = block_from_string input
      assert_equal Asciidoctor::Substitutors::SUBS[:normal], verse.subs
    end

    test 'should not recognize callouts in a verse' do
      input = <<-EOS
[verse]
____
La la la <1>
____
<1> Not pointing to a callout
      EOS

      output = render_embedded_string input
      assert_xpath '//pre[text()="La la la <1>"]', output, 1
    end

    test 'should perform normal subs on a verse block' do
      input = <<-EOS
[verse]
____
_GET /groups/link:#group-id[\{group-id\}]_
____
      EOS

      output = render_embedded_string input
      assert output.include?('<pre class="content"><em>GET /groups/<a href="#group-id">{group-id}</a></em></pre>')
    end
  end

  context "Example Blocks" do
    test "can render example block" do
      input = <<-EOS
====
This is an example of an example block.

How crazy is that?
====
      EOS

      output = render_string input
      assert_xpath '//*[@class="exampleblock"]//p', output, 2
    end

    test "assigns sequential numbered caption to example block with title" do
      input = <<-EOS
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
      output = doc.render
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Example 1. Writing Docs with AsciiDoc"]', output, 1
      assert_xpath '(//*[@class="exampleblock"])[2]/*[@class="title"][text()="Example 2. Writing Docs with DocBook"]', output, 1
      assert_equal 2, doc.attributes['example-number']
    end

    test "assigns sequential character caption to example block with title" do
      input = <<-EOS
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
      output = doc.render
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Example A. Writing Docs with AsciiDoc"]', output, 1
      assert_xpath '(//*[@class="exampleblock"])[2]/*[@class="title"][text()="Example B. Writing Docs with DocBook"]', output, 1
      assert_equal 'B', doc.attributes['example-number']
    end

    test "explicit caption is used if provided" do
      input = <<-EOS
[caption="Look! "]
.Writing Docs with AsciiDoc
====
Here's how you write AsciiDoc.

You just write.
====
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Look! Writing Docs with AsciiDoc"]', output, 1
      assert !doc.attributes.has_key?('example-number')
    end

    test 'explicit caption is set on block even if block has no title' do
      input = <<-EOS
[caption="Look!"]
====
Just write.
====
      EOS

      doc = document_from_string input
      assert_equal 'Look!', doc.blocks.first.caption
      output = doc.render
      refute_match(/Look/, output)
    end

    test 'automatic caption can be turned off and on and modified' do
      input = <<-EOS
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

      output = render_embedded_string input
      assert_xpath '/*[@class="exampleblock"]', output, 3
      assert_xpath '(/*[@class="exampleblock"])[1]/*[@class="title"][starts-with(text(), "Example ")]', output, 1
      assert_xpath '(/*[@class="exampleblock"])[2]/*[@class="title"][text()="second example"]', output, 1
      assert_xpath '(/*[@class="exampleblock"])[3]/*[@class="title"][starts-with(text(), "Exhibit ")]', output, 1
    end
  end

  context 'Admonition Blocks' do
    test 'caption block-level attribute should be used as caption' do
       input = <<-EOS
:tip-caption: Pro Tip

[caption="Pro Tip"]
TIP: Override the caption of an admonition block using an attribute entry
       EOS

       output = render_embedded_string input
       assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Pro Tip"]', output, 1
    end

    test 'can override caption of admonition block using document attribute' do
       input = <<-EOS
:tip-caption: Pro Tip

TIP: Override the caption of an admonition block using an attribute entry
       EOS

       output = render_embedded_string input
       assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Pro Tip"]', output, 1
    end

    test 'blank caption document attribute should not blank admonition block caption' do
       input = <<-EOS
:caption:

TIP: Override the caption of an admonition block using an attribute entry
       EOS

       output = render_embedded_string input
       assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Tip"]', output, 1
    end
  end

  context "Preformatted Blocks" do
    test 'should separate adjacent paragraphs and listing into blocks' do
      input = <<-EOS
paragraph 1
----
listing content
----
paragraph 2
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="paragraph"]/p', output, 2
      assert_xpath '/*[@class="listingblock"]', output, 1
      assert_xpath '(/*[@class="paragraph"]/following-sibling::*)[1][@class="listingblock"]', output, 1
    end

    test "should preserve endlines in literal block" do
      input = <<-EOS
....
line one

line two

line three
....
EOS
      [true, false].each {|header_footer|
        output = render_string input, :header_footer => header_footer
        assert_xpath '//pre', output, 1
        assert_xpath '//pre/text()', output, 1
        text = xmlnodes_at_xpath('//pre/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[ \t]*\n/).size
        assert blank_lines >= 2
      }
    end

    test "should preserve endlines in listing block" do
      input = <<-EOS
[source]
----
line one

line two

line three
----
EOS
      [true, false].each {|header_footer|
        output = render_string input, header_footer => header_footer
        assert_xpath '//pre/code', output, 1
        assert_xpath '//pre/code/text()', output, 1
        text = xmlnodes_at_xpath('//pre/code/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[ \t]*\n/).size
        assert blank_lines >= 2
      }
    end

    test "should preserve endlines in verse block" do
      input = <<-EOS
--
[verse]
____
line one

line two

line three
____
--
EOS
      [true, false].each {|header_footer|
        output = render_string input, :header_footer => header_footer
        assert_xpath '//*[@class="verseblock"]/pre', output, 1
        assert_xpath '//*[@class="verseblock"]/pre/text()', output, 1
        text = xmlnodes_at_xpath('//*[@class="verseblock"]/pre/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[ \t]*\n/).size
        assert blank_lines >= 2
      }
    end

    test 'should strip leading and trailing blank lines when rendering verbatim block' do
      input = <<-EOS
[subs="attributes"]
....


  first line

last line

{empty}

....
      EOS

      doc = document_from_string input, :header_footer => false
      block = doc.blocks.first
      assert_equal ['', '', '  first line', '', 'last line', '', '{empty}', ''], block.lines
      result = doc.render
      assert_xpath %(//pre[text()="  first line\n\nlast line"]), result, 1
    end

    test 'should process block with CRLF endlines' do
      input = <<-EOS
[source]\r
----\r
source line 1\r
source line 2\r
----\r
      EOS

      output = render_embedded_string input
      refute_match(/\[source\]/, output)
      assert_xpath '/*[@class="listingblock"]//pre', output, 1
      assert_xpath '/*[@class="listingblock"]//pre/code', output, 1
      assert_xpath %(/*[@class="listingblock"]//pre/code[text()="source line 1\nsource line 2"]), output, 1
    end

    test 'should remove block indent if indent attribute is 0' do
      input = <<-EOS
[indent="0"]
----
    def names

      @names.split ' '

    end
----
      EOS

      expected = <<-EOS
def names

  @names.split ' '

end
      EOS

      output = render_embedded_string input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected.chomp, result
    end

    test 'should not remove block indent if indent attribute is -1' do
      input = <<-EOS
[indent="-1"]
----
    def names

      @names.split ' '

    end
----
      EOS

      expected = <<-EOS
    def names

      @names.split ' '

    end
      EOS

      output = render_embedded_string input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected.chomp, result
    end

    test 'should set block indent to value specified by indent attribute' do
      input = <<-EOS
[indent="1"]
----
    def names

      @names.split ' '

    end
----
      EOS

      expected = <<-EOS
 def names

   @names.split ' '

 end
      EOS

      output = render_embedded_string input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected.chomp, result
    end

    test 'should set block indent to value specified by indent document attribute' do
      input = <<-EOS
:source-indent: 1

[source,ruby]
----
    def names

      @names.split ' '

    end
----
      EOS

      expected = <<-EOS
 def names

   @names.split ' '

 end
      EOS

      output = render_embedded_string input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected.chomp, result
    end

    test 'should expand tabs if tabsize attribute is positive' do
      input = <<-EOS
:tabsize: 4

[indent=0]
----
	def names

		@names.split ' '

	end
----
      EOS

      expected = <<-EOS
def names

    @names.split ' '

end
      EOS

      output = render_embedded_string input
      assert_css 'pre', output, 1
      assert_css '.listingblock pre', output, 1
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal expected.chomp, result
    end

    test 'literal block should honor nowrap option' do
      input = <<-EOS
[options="nowrap"]
----
Do not wrap me if I get too long.
----
      EOS

      output = render_embedded_string input
      assert_css 'pre.nowrap', output, 1
    end

    test 'literal block should set nowrap class if prewrap document attribute is disabled' do
      input = <<-EOS
:prewrap!:

----
Do not wrap me if I get too long.
----
      EOS

      output = render_embedded_string input
      assert_css 'pre.nowrap', output, 1
    end

    test 'literal block should honor explicit subs list' do
      input = <<-EOS
[subs="verbatim,quotes"]
----
Map<String, String> *attributes*; //<1>
----
      EOS

      block = block_from_string input
      assert_equal [:specialcharacters,:callouts,:quotes], block.subs
      output = block.render
      assert output.include?('Map&lt;String, String&gt; <strong>attributes</strong>;')
      assert_xpath '//pre/b[text()="(1)"]', output, 1
    end

    test 'should be able to disable callouts for literal block' do
      input = <<-EOS
[subs="specialcharacters"]
----
No callout here <1>
----
      EOS
      block = block_from_string input
      assert_equal [:specialcharacters], block.subs
      output = block.render
      assert_xpath '//pre/b[text()="(1)"]', output, 0
    end

    test 'listing block should honor explicit subs list' do
      input = <<-EOS
[subs="specialcharacters,quotes"]
----
$ *python functional_tests.py*
Traceback (most recent call last):
  File "functional_tests.py", line 4, in <module>
    assert 'Django' in browser.title
AssertionError
----
      EOS

      output = render_embedded_string input

      assert_css '.listingblock pre', output, 1
      assert_css '.listingblock pre strong', output, 1
      assert_css '.listingblock pre em', output, 0

      input2 = <<-EOS
[subs="specialcharacters,macros"]
----
$ pass:quotes[*python functional_tests.py*]
Traceback (most recent call last):
  File "functional_tests.py", line 4, in <module>
    assert pass:quotes['Django'] in browser.title
AssertionError
----
      EOS

      output2 = render_embedded_string input2
      # FIXME JRuby is adding extra trailing endlines in the second document,
      # for now, rstrip is necessary
      assert_equal output.rstrip, output2.rstrip
    end

    test 'listing block without title should generate screen element in docbook' do
      input = <<-EOS
----
listing block
----
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '/screen[text()="listing block"]', output, 1
    end

    test 'listing block with title should generate screen element inside formalpara element in docbook' do
      input = <<-EOS
.title
----
listing block
----
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '/formalpara', output, 1
      assert_xpath '/formalpara/title[text()="title"]', output, 1
      assert_xpath '/formalpara/para/screen[text()="listing block"]', output, 1
    end

    test 'source block with no title or language should generate screen element in docbook' do
      input = <<-EOS
[source]
----
listing block
----
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '/screen[text()="listing block"]', output, 1
    end

    test 'source block with title and no language should generate screen element inside formalpara element in docbook' do
      input = <<-EOS
[source]
.title
----
listing block
----
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '/formalpara', output, 1
      assert_xpath '/formalpara/title[text()="title"]', output, 1
      assert_xpath '/formalpara/para/screen[text()="listing block"]', output, 1
    end
  end

  context "Open Blocks" do
    test "can render open block" do
      input = <<-EOS
--
This is an open block.

It can span multiple lines.
--
      EOS

      output = render_string input
      assert_xpath '//*[@class="openblock"]//p', output, 2
    end

    test "open block can contain another block" do
      input = <<-EOS
--
This is an open block.

It can span multiple lines.

____
It can hold great quotes like this one.
____
--
      EOS

      output = render_string input
      assert_xpath '//*[@class="openblock"]//p', output, 3
      assert_xpath '//*[@class="openblock"]//*[@class="quoteblock"]', output, 1
    end
  end

  context 'Passthrough Blocks' do
    test 'can parse a passthrough block' do
      input = <<-EOS
++++
This is a passthrough block.
++++
      EOS

      block = block_from_string input
      assert !block.nil?
      assert_equal 1, block.lines.size
      assert_equal 'This is a passthrough block.', block.source
    end

    test 'does not perform subs on a passthrough block by default' do
      input = <<-EOS
:type: passthrough

++++
This is a '{type}' block.
http://asciidoc.org
image:tiger.png[]
++++
      EOS

      expected = %(This is a '{type}' block.\nhttp://asciidoc.org\nimage:tiger.png[])
      output = render_embedded_string input
      assert_equal expected, output.strip
    end

    test 'does not perform subs on a passthrough block with pass style by default' do
      input = <<-EOS
:type: passthrough

[pass]
++++
This is a '{type}' block.
http://asciidoc.org
image:tiger.png[]
++++
      EOS

      expected = %(This is a '{type}' block.\nhttp://asciidoc.org\nimage:tiger.png[])
      output = render_embedded_string input
      assert_equal expected, output.strip
    end

    test 'passthrough block honors explicit subs list' do
      input = <<-EOS
:type: passthrough

[subs="attributes,quotes,macros"]
++++
This is a _{type}_ block.
http://asciidoc.org
++++
      EOS

      expected = %(This is a <em>passthrough</em> block.\n<a href="http://asciidoc.org" class="bare">http://asciidoc.org</a>)
      output = render_embedded_string input
      assert_equal expected, output.strip
    end

    test 'should strip leading and trailing blank lines when rendering raw block' do
      input = <<-EOS
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

      doc = document_from_string input, :header_footer => false
      block = doc.blocks[1]
      assert_equal ['', '', '  first line', '', 'last line', '', ''], block.lines
      result = doc.render
      assert_equal "line above\n  first line\n\nlast line\nline below", result, 1
    end
  end

  context 'Math blocks' do
    test 'should add LaTeX math delimiters around latexmath block content' do
      input = <<-'EOS'
[latexmath]
++++
\sqrt{3x-1}+(1+x)^2 < y
++++
      EOS

      output = render_embedded_string input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output, 1
      assert_equal '\[\sqrt{3x-1}+(1+x)^2 &lt; y\]', nodes.first.to_s.strip
    end

    test 'should not add LaTeX math delimiters around latexmath block content if already present' do
      input = <<-'EOS'
[latexmath]
++++
\[\sqrt{3x-1}+(1+x)^2 < y\]
++++
      EOS

      output = render_embedded_string input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output, 1
      assert_equal '\[\sqrt{3x-1}+(1+x)^2 &lt; y\]', nodes.first.to_s.strip
    end

    test 'should render latexmath block in alt of equation in DocBook backend' do
      input = <<-'EOS'
[latexmath]
++++
\sqrt{3x-1}+(1+x)^2 < y
++++
      EOS

      expect = <<-'EOS'
<informalequation>
<alt><![CDATA[\sqrt{3x-1}+(1+x)^2 < y]]></alt>
<mathphrase><![CDATA[\sqrt{3x-1}+(1+x)^2 < y]]></mathphrase>
</informalequation>
      EOS

      output = render_embedded_string input, :backend => :docbook
      assert_equal expect.strip, output.strip
    end

    test 'should add AsciiMath delimiters around asciimath block content' do
      input = <<-'EOS'
[asciimath]
++++
sqrt(3x-1)+(1+x)^2 < y
++++
      EOS

      output = render_embedded_string input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output, 1
      assert_equal '\$sqrt(3x-1)+(1+x)^2 &lt; y\$', nodes.first.to_s.strip
    end

    test 'should not add AsciiMath delimiters around asciimath block content if already present' do
      input = <<-'EOS'
[asciimath]
++++
\$sqrt(3x-1)+(1+x)^2 < y\$
++++
      EOS

      output = render_embedded_string input
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output, 1
      assert_equal '\$sqrt(3x-1)+(1+x)^2 &lt; y\$', nodes.first.to_s.strip
    end

    test 'should render asciimath block in textobject of equation in DocBook backend' do
      input = <<-'EOS'
[asciimath]
++++
x+b/(2a)<+-sqrt((b^2)/(4a^2)-c/a)
++++
      EOS

      expect = %(<informalequation>
<mml:math xmlns:mml="http://www.w3.org/1998/Math/MathML"><mml:mi>x</mml:mi><mml:mo>+</mml:mo><mml:mfrac><mml:mi>b</mml:mi><mml:mrow><mml:mn>2</mml:mn><mml:mi>a</mml:mi></mml:mrow></mml:mfrac><mml:mo>&#x003C;</mml:mo><mml:mo>&#x00B1;</mml:mo><mml:msqrt><mml:mrow><mml:mfrac><mml:msup><mml:mi>b</mml:mi><mml:mn>2</mml:mn></mml:msup><mml:mrow><mml:mn>4</mml:mn><mml:msup><mml:mi>a</mml:mi><mml:mn>2</mml:mn></mml:msup></mml:mrow></mml:mfrac><mml:mo>&#x2212;</mml:mo><mml:mfrac><mml:mi>c</mml:mi><mml:mi>a</mml:mi></mml:mfrac></mml:mrow></mml:msqrt></mml:math>
</informalequation>)

      output = render_embedded_string input, :backend => :docbook
      assert_equal expect.strip, output.strip
    end

    test 'should output title for latexmath block if defined' do
      input = <<-'EOS'
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

      output = render_embedded_string input
      assert_css '.stemblock', output, 1
      assert_css '.stemblock .title', output, 1
      assert_xpath '//*[@class="title"][text()="The Lorenz Equations"]', output, 1
    end

    test 'should output title for asciimath block if defined' do
      input = <<-'EOS'
.Simple fraction
[asciimath]
++++
a//b
++++
      EOS

      output = render_embedded_string input
      assert_css '.stemblock', output, 1
      assert_css '.stemblock .title', output, 1
      assert_xpath '//*[@class="title"][text()="Simple fraction"]', output, 1
    end

    test 'should add AsciiMath delimiters around stem block content if stem attribute != latexmath' do
      input = <<-'EOS'
[stem]
++++
sqrt(3x-1)+(1+x)^2 < y
++++
      EOS

      [
        {},
        {'stem' => ''},
        {'stem' => 'asciimath'}
      ].each do |attributes|
        output = render_embedded_string input, :attributes => attributes
        assert_css '.stemblock', output, 1
        nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output, 1
        assert_equal '\$sqrt(3x-1)+(1+x)^2 &lt; y\$', nodes.first.to_s.strip
      end
    end

    test 'should add LaTeX math delimiters around stem block content if stem attribute is latexmath' do
      input = <<-'EOS'
[stem]
++++
\sqrt{3x-1}+(1+x)^2 < y
++++
      EOS

      output = render_embedded_string input, :attributes => {'stem' => 'latexmath'}
      assert_css '.stemblock', output, 1
      nodes = xmlnodes_at_xpath '//*[@class="content"]/child::text()', output, 1
      assert_equal '\[\sqrt{3x-1}+(1+x)^2 &lt; y\]', nodes.first.to_s.strip
    end
  end

  context 'Metadata' do
    test 'block title above section gets carried over to first block in section' do
      input = <<-EOS
.Title
== Section

paragraph
      EOS
      output = render_string input
      assert_xpath '//*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="paragraph"]/*[@class="title"][text() = "Title"]', output, 1
      assert_xpath '//*[@class="paragraph"]/p[text() = "paragraph"]', output, 1
    end

    test 'block title above document title demotes document title to a section title' do
      input = <<-EOS
.Block title
= Section Title

section paragraph
      EOS
      output, errors = nil
      redirect_streams do |stdout, stderr|
        output = render_string input
        errors = stderr.string
      end
      assert_xpath '//*[@id="header"]/*', output, 0
      assert_xpath '//*[@id="preamble"]/*', output, 0
      assert_xpath '//*[@id="content"]/h1[text()="Section Title"]', output, 1
      assert_xpath '//*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="paragraph"]/*[@class="title"][text()="Block title"]', output, 1
      assert !errors.empty?
      assert_match(/only book doctypes can contain level 0 sections/, errors)
    end

    test 'block title above document title gets carried over to first block in first section if no preamble' do
      input = <<-EOS
.Block title
= Document Title

== First Section

paragraph
      EOS
      output = render_string input
      assert_xpath '//*[@class="sect1"]//*[@class="paragraph"]/*[@class="title"][text() = "Block title"]', output, 1
    end

    test 'empty attribute list should not appear in output' do
      input = <<-EOS
[]
--
Block content
--
      EOS

      output = render_embedded_string input
      assert output.include?('Block content')
      assert !output.include?('[]')
    end

    test 'empty block anchor should not appear in output' do
      input = <<-EOS
[[]]
--
Block content
--
      EOS

      output = render_embedded_string input
      assert output.include?('Block content')
      assert !output.include?('[[]]')
    end
  end

  context 'Images' do
    test 'can render block image with alt text defined in macro' do
      input = <<-EOS
image::images/tiger.png[Tiger]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'renders SVG image using img element by default' do
      input = <<-EOS
image::tiger.svg[Tiger]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//img[@src="tiger.svg"][@alt="Tiger"]', output, 1
    end

    test 'renders interactive SVG image with alt text using object element' do
      input = <<-EOS
:imagesdir: images

[%interactive]
image::tiger.svg[Tiger,100]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="images/tiger.svg"][@width="100"]/span[@class="alt"][text()="Tiger"]', output, 1
    end

    test 'renders SVG image with alt text using img element when safe mode is secure' do
      input = <<-EOS
[%interactive]
image::images/tiger.svg[Tiger,100]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.svg"][@alt="Tiger"]', output, 1
    end

    test 'inserts fallback image for SVG inside object element using same dimensions' do
      input = <<-EOS
:imagesdir: images

[%interactive]
image::tiger.svg[Tiger,100,fallback=tiger.png]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="images/tiger.svg"][@width="100"]/img[@src="images/tiger.png"][@width="100"]', output, 1
    end

    test 'detects SVG image URI that contains a query string' do
      input = <<-EOS
:imagesdir: images

[%interactive]
image::http://example.org/tiger.svg?foo=bar[Tiger,100]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="http://example.org/tiger.svg?foo=bar"][@width="100"]/span[@class="alt"][text()="Tiger"]', output, 1
    end

    test 'detects SVG image when format attribute is svg' do
      input = <<-EOS
:imagesdir: images

[%interactive]
image::http://example.org/tiger-svg[Tiger,100,format=svg]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '/*[@class="imageblock"]//object[@type="image/svg+xml"][@data="http://example.org/tiger-svg"][@width="100"]/span[@class="alt"][text()="Tiger"]', output, 1
    end

    test 'renders inline SVG image using svg element' do
      input = <<-EOS
:imagesdir: fixtures

[%inline]
image::circle.svg[Tiger,100]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER, :attributes => { 'docdir' => ::File.dirname(__FILE__) }
      assert_match(/<svg\s[^>]*width="100px"[^>]*>/, output, 1)
      refute_match(/<svg\s[^>]*width="500px"[^>]*>/, output)
      refute_match(/<svg\s[^>]*height="500px"[^>]*>/, output)
      refute_match(/<svg\s[^>]*style="width:500px;height:500px"[^>]*>/, output)
    end

    test 'renders inline SVG image using svg element even when data-uri is set' do
      input = <<-EOS
:imagesdir: fixtures
:data-uri:

[%inline]
image::circle.svg[Tiger,100]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER, :attributes => { 'docdir' => ::File.dirname(__FILE__) }
      assert_match(/<svg\s[^>]*width="100px">/, output, 1)
    end

    test 'renders alt text for inline svg element if svg cannot be read' do
      input = <<-EOS
[%inline]
image::no-such-image.svg[Alt Text]
      EOS

      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '//span[@class="alt"][text()="Alt Text"]', output, 1
    end

    test 'can render block image with alt text defined in macro containing escaped square bracket' do
      input = <<-EOS
image::images/tiger.png[A [Bengal\\] Tiger]
      EOS

      output = render_string input
      img = xmlnodes_at_xpath '//img', output, 1
      assert_equal 'A [Bengal] Tiger', img.attr('alt').value
    end

    test 'can render block image with alt text defined in block attribute above macro' do
      input = <<-EOS
[Tiger]
image::images/tiger.png[]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'alt text in macro overrides alt text above macro' do
      input = <<-EOS
[Alt Text]
image::images/tiger.png[Tiger]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'alt text is escaped in HTML backend' do
      input = <<-EOS
image::images/open.png[File > Open]
      EOS

      output = render_embedded_string input
      assert_match(/File &gt; Open/, output)
    end

    test 'alt text is escaped in DocBook backend' do
      input = <<-EOS
image::images/open.png[File > Open]
      EOS

      output = render_embedded_string input, :backend => :docbook
      assert_match(/File &gt; Open/, output)
    end

    test "can render block image with auto-generated alt text" do
      input = <<-EOS
image::images/tiger.png[]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="tiger"]', output, 1
    end

    test "can render block image with alt text and height and width" do
      input = <<-EOS
image::images/tiger.png[Tiger, 200, 300]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"][@width="200"][@height="300"]', output, 1
    end

    test "can render block image with link" do
      input = <<-EOS
image::images/tiger.png[Tiger, link='http://en.wikipedia.org/wiki/Tiger']
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//a[@class="image"][@href="http://en.wikipedia.org/wiki/Tiger"]/img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test "can render block image with caption" do
      input = <<-EOS
.The AsciiDoc Tiger
image::images/tiger.png[Tiger]
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
      assert_xpath '//*[@class="imageblock"]/*[@class="title"][text() = "Figure 1. The AsciiDoc Tiger"]', output, 1
      assert_equal 1, doc.attributes['figure-number']
    end

    test 'can render block image with explicit caption' do
      input = <<-EOS
[caption="Voila! "]
.The AsciiDoc Tiger
image::images/tiger.png[Tiger]
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
      assert_xpath '//*[@class="imageblock"]/*[@class="title"][text() = "Voila! The AsciiDoc Tiger"]', output, 1
      assert !doc.attributes.has_key?('figure-number')
    end

    test 'can align image in DocBook backend' do
      input = <<-EOS
image::images/sunset.jpg[Sunset, align="right"]
      EOS

      output = render_embedded_string input, :backend => :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@align="right"]', output, 1
    end

    test 'can scale image in DocBook backend' do
      input = <<-EOS
image::images/sunset.jpg[Sunset, scale="200"]
      EOS

      output = render_embedded_string input, :backend => :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@scale="200"]', output, 1
    end

    test 'can scale image width in DocBook backend' do
      input = <<-EOS
image::images/sunset.jpg[Sunset, scaledwidth="25%"]
      EOS

      output = render_embedded_string input, :backend => :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@width="25%"]', output, 1
      assert_xpath '//imagedata[@scalefit="1"]', output, 1
    end

    test 'adds % to scaled width if no units given in DocBook backend ' do
      input = <<-EOS
image::images/sunset.jpg[Sunset, scaledwidth="25"]
      EOS

      output = render_embedded_string input, :backend => :docbook
      assert_xpath '//imagedata', output, 1
      assert_xpath '//imagedata[@width="25%"]', output, 1
      assert_xpath '//imagedata[@scalefit="1"]', output, 1
    end

    test 'keeps line unprocessed if image target is missing attribute reference and attribute-missing is skip' do
      input = <<-EOS
:attribute-missing: skip

image::{bogus}[]
      EOS

      output = render_embedded_string input
      assert output.include?('image::{bogus}[]')
    end

    test 'drops line if image target is missing attribute reference and attribute-missing is drop' do
      input = <<-EOS
:attribute-missing: drop

image::{bogus}[]
      EOS

      output = render_embedded_string input
      assert output.strip.empty?
    end

    test 'drops line if image target is missing attribute reference and attribute-missing is drop-line' do
      input = <<-EOS
:attribute-missing: drop-line

image::{bogus}[]
      EOS

      output = render_embedded_string input
      assert output.strip.empty?
    end

    test 'dropped image does not break processing of following section and attribute-missing is drop-line' do
      input = <<-EOS
:attribute-missing: drop-line

image::{bogus}[]

== Section Title
      EOS

      output = render_embedded_string input
      assert_css 'img', output, 0
      assert_css 'h2', output, 1
      assert !output.include?('== Section Title')
    end

    test 'should pass through image that references uri' do
      input = <<-EOS
:imagesdir: images

image::http://asciidoc.org/images/tiger.png[Tiger]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="http://asciidoc.org/images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'can resolve image relative to imagesdir' do
      input = <<-EOS
:imagesdir: images

image::tiger.png[Tiger]
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'embeds base64-encoded data uri for image when data-uri attribute is set' do
      input = <<-EOS
:data-uri:
:imagesdir: fixtures

image::dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal 'fixtures', doc.attributes['imagesdir']
      output = doc.render
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'embeds base64-encoded data uri for remote image when data-uri attribute is set' do
      input = <<-EOS
:data-uri:

image::http://#{resolve_localhost}:9876/fixtures/dot.gif[Dot]
      EOS

      output = using_test_webserver do
        render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
      end

      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'embeds base64-encoded data uri for remote image when imagesdir is a URI and data-uri attribute is set' do
      input = <<-EOS
:data-uri:
:imagesdir: http://#{resolve_localhost}:9876/fixtures

image::dot.gif[Dot]
      EOS

      output = using_test_webserver do
        render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
      end

      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'uses remote image uri when data-uri attribute is set and image cannot be retrieved' do
      image_uri = "http://#{resolve_localhost}:9876/fixtures/missing-image.gif"
      input = <<-EOS
:data-uri:

image::#{image_uri}[Missing image]
      EOS

      output = using_test_webserver do
        render_embedded_string input, :safe => :safe, :attributes => {'allow-uri-read' => ''}
      end

      assert_xpath %(/*[@class="imageblock"]//img[@src="#{image_uri}"][@alt="Missing image"]), output, 1
    end

    test 'uses remote image uri when data-uri attribute is set and allow-uri-read is not set' do
      image_uri = "http://#{resolve_localhost}:9876/fixtures/dot.gif"
      input = <<-EOS
:data-uri:

image::#{image_uri}[Dot]
      EOS

      output = using_test_webserver do
        render_embedded_string input, :safe => :safe
      end

      assert_xpath %(/*[@class="imageblock"]//img[@src="#{image_uri}"][@alt="Dot"]), output, 1
    end

    test 'can handle embedded data uri images' do
      input = <<-EOS
image::data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs=[Dot]
      EOS

      output = render_embedded_string input
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'can handle embedded data uri images when data-uri attribute is set' do
      input = <<-EOS
:data-uri:

image::data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs=[Dot]
      EOS

      output = render_embedded_string input
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    # this test will cause a warning to be printed to the console (until we have a message facility)
    test 'cleans reference to ancestor directories in imagesdir before reading image if safe mode level is at least SAFE' do
      input = <<-EOS
:data-uri:
:imagesdir: ../..//fixtures/./../../fixtures

image::dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal '../..//fixtures/./../../fixtures', doc.attributes['imagesdir']
      output = doc.render
      # image target resolves to fixtures/dot.gif relative to docdir (which is explicitly set to the directory of this file)
      # the reference cannot fall outside of the document directory in safe mode
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'cleans reference to ancestor directories in target before reading image if safe mode level is at least SAFE' do
      input = <<-EOS
:data-uri:
:imagesdir: ./

image::../..//fixtures/./../../fixtures/dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal './', doc.attributes['imagesdir']
      output = doc.render
      # image target resolves to fixtures/dot.gif relative to docdir (which is explicitly set to the directory of this file)
      # the reference cannot fall outside of the document directory in safe mode
      assert_xpath '//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end
  end

  context 'Media' do
    test 'should detect and render video macro' do
      input = <<-EOS
video::cats-vs-dogs.avi[]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
    end

    test 'should detect and render video macro with positional attributes for poster and dimensions' do
      input = <<-EOS
video::cats-vs-dogs.avi[cats-and-dogs.png, 200, 300]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
      assert_css 'video[poster="cats-and-dogs.png"]', output, 1
      assert_css 'video[width="200"]', output, 1
      assert_css 'video[height="300"]', output, 1
    end

    test 'video macro should honor all options' do
      input = <<-EOS
video::cats-vs-dogs.avi[options="autoplay,nocontrols,loop"]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[autoplay]', output, 1
      assert_css 'video:not([controls])', output, 1
      assert_css 'video[loop]', output, 1
    end

    test 'video macro should add time range anchor with start time if start attribute is set' do
      input = <<-EOS
video::cats-vs-dogs.avi[start="30"]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_xpath '//video[@src="cats-vs-dogs.avi#t=30"]', output, 1
    end

    test 'video macro should add time range anchor with end time if end attribute is set' do
      input = <<-EOS
video::cats-vs-dogs.avi[end="30"]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_xpath '//video[@src="cats-vs-dogs.avi#t=,30"]', output, 1
    end

    test 'video macro should add time range anchor with start and end time if start and end attributes are set' do
      input = <<-EOS
video::cats-vs-dogs.avi[start="30",end="60"]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_xpath '//video[@src="cats-vs-dogs.avi#t=30,60"]', output, 1
    end

    test 'video macro should use imagesdir attribute to resolve target and poster' do
      input = <<-EOS
:imagesdir: assets

video::cats-vs-dogs.avi[cats-and-dogs.png, 200, 300]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="assets/cats-vs-dogs.avi"]', output, 1
      assert_css 'video[poster="assets/cats-and-dogs.png"]', output, 1
      assert_css 'video[width="200"]', output, 1
      assert_css 'video[height="300"]', output, 1
    end

    test 'video macro should not use imagesdir attribute to resolve target if target is a URL' do
      input = <<-EOS
:imagesdir: assets

video::http://example.org/videos/cats-vs-dogs.avi[]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="http://example.org/videos/cats-vs-dogs.avi"]', output, 1
    end

    test 'video macro should output custom HTML with iframe for vimeo service' do
      input = <<-EOS
video::67480300[vimeo, 400, 300, start=60, options=autoplay]
      EOS
      output = render_embedded_string input
      assert_css 'video', output, 0
      assert_css 'iframe', output, 1
      assert_css 'iframe[src="https://player.vimeo.com/video/67480300#at=60?autoplay=1"]', output, 1
      assert_css 'iframe[width="400"]', output, 1
      assert_css 'iframe[height="300"]', output, 1
    end

    test 'video macro should output custom HTML with iframe for youtube service' do
      input = <<-EOS
video::U8GBXvdmHT4/PLg7s6cbtAD15Das5LK9mXt_g59DLWxKUe[youtube, 640, 360, start=60, options="autoplay,modest", theme=light]
      EOS
      output = render_embedded_string input
      assert_css 'video', output, 0
      assert_css 'iframe', output, 1
      assert_css 'iframe[src="https://www.youtube.com/embed/U8GBXvdmHT4?rel=0&start=60&autoplay=1&list=PLg7s6cbtAD15Das5LK9mXt_g59DLWxKUe&modestbranding=1&theme=light"]', output, 1
      assert_css 'iframe[width="640"]', output, 1
      assert_css 'iframe[height="360"]', output, 1
    end

    test 'video macro should output custom HTML with iframe for youtube service with dynamic playlist' do
      input = <<-EOS
video::SCZF6I-Rc4I,AsKGOeonbIs,HwrPhOp6-aM[youtube, 640, 360, start=60, options=autoplay]
      EOS
      output = render_embedded_string input
      assert_css 'video', output, 0
      assert_css 'iframe', output, 1
      assert_css 'iframe[src="https://www.youtube.com/embed/SCZF6I-Rc4I?rel=0&start=60&autoplay=1&playlist=AsKGOeonbIs,HwrPhOp6-aM"]', output, 1
      assert_css 'iframe[width="640"]', output, 1
      assert_css 'iframe[height="360"]', output, 1
    end

    test 'should detect and render audio macro' do
      input = <<-EOS
audio::podcast.mp3[]
      EOS

      output = render_embedded_string input
      assert_css 'audio', output, 1
      assert_css 'audio[src="podcast.mp3"]', output, 1
    end

    test 'audio macro should use imagesdir attribute to resolve target' do
      input = <<-EOS
:imagesdir: assets

audio::podcast.mp3[]
      EOS

      output = render_embedded_string input
      assert_css 'audio', output, 1
      assert_css 'audio[src="assets/podcast.mp3"]', output, 1
    end

    test 'audio macro should not use imagesdir attribute to resolve target if target is a URL' do
      input = <<-EOS
:imagesdir: assets

video::http://example.org/podcast.mp3[]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="http://example.org/podcast.mp3"]', output, 1
    end

    test 'audio macro should honor all options' do
      input = <<-EOS
audio::podcast.mp3[options="autoplay,nocontrols,loop"]
      EOS

      output = render_embedded_string input
      assert_css 'audio', output, 1
      assert_css 'audio[autoplay]', output, 1
      assert_css 'audio:not([controls])', output, 1
      assert_css 'audio[loop]', output, 1
    end
  end

  context 'Admonition icons' do
    test 'can resolve icon relative to default iconsdir' do
      input = <<-EOS
:icons:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="./images/icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'can resolve icon relative to custom iconsdir' do
      input = <<-EOS
:icons:
:iconsdir: icons

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'should add file extension to custom icon if not specified' do
      input = <<-EOS
:icons: font
:iconsdir: images/icons

[TIP,icon=a]
Override the icon of an admonition block using an attribute
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="images/icons/a.png"]', output, 1
    end

    test 'embeds base64-encoded data uri of icon when data-uri attribute is set and safe mode level is less than SECURE' do
      input = <<-EOS
:icons:
:iconsdir: fixtures
:icontype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end

    test 'does not embed base64-encoded data uri of icon when safe mode level is SECURE or greater' do
      input = <<-EOS
:icons:
:iconsdir: fixtures
:icontype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :attributes => {'icons' => ''}
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="fixtures/tip.gif"][@alt="Tip"]', output, 1
    end

    test 'cleans reference to ancestor directories before reading icon if safe mode level is at least SAFE' do
      input = <<-EOS
:icons:
:iconsdir: ../fixtures
:icontype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end

    test 'should import Font Awesome and use font-based icons when value of icons attribute is font' do
      input = <<-EOS
:icons: font

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_css 'html > head > link[rel="stylesheet"][href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.6.3/css/font-awesome.min.css"]', output, 1
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/i[@class="fa icon-tip"]', output, 1
    end

    test 'font-based icon should not override icon specified on admonition' do
      input = <<-EOS
:icons: font
:iconsdir: images/icons

[TIP,icon=a.png]
Override the icon of an admonition block using an attribute
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/i[@class="fa icon-tip"]', output, 0
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="images/icons/a.png"]', output, 1
    end

    test 'should use http uri scheme for assets when asset-uri-scheme is http' do
      input = <<-EOS
:asset-uri-scheme: http
:icons: font
:source-highlighter: highlightjs

TIP: You can control the URI scheme used for assets with the asset-uri-scheme attribute

[source,ruby]
puts "AsciiDoc, FTW!"
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_css 'html > head > link[rel="stylesheet"][href="http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.6.3/css/font-awesome.min.css"]', output, 1
      assert_css 'html > body > script[src="http://cdnjs.cloudflare.com/ajax/libs/highlight.js/8.9.1/highlight.min.js"]', output, 1
    end

    test 'should use no uri scheme for assets when asset-uri-scheme is blank' do
      input = <<-EOS
:asset-uri-scheme:
:icons: font
:source-highlighter: highlightjs

TIP: You can control the URI scheme used for assets with the asset-uri-scheme attribute

[source,ruby]
puts "AsciiDoc, FTW!"
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_css 'html > head > link[rel="stylesheet"][href="//cdnjs.cloudflare.com/ajax/libs/font-awesome/4.6.3/css/font-awesome.min.css"]', output, 1
      assert_css 'html > body > script[src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/8.9.1/highlight.min.js"]', output, 1
    end
  end

  context 'Image paths' do

    test 'restricts access to ancestor directories when safe mode level is at least SAFE' do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.expand_path File.dirname(__FILE__)
      block = block_from_string input, :attributes => {'docdir' => basedir}
      doc = block.document
      assert doc.safe >= Asciidoctor::SafeMode::SAFE

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      assert_equal File.join(basedir, 'etc/images'), block.normalize_asset_path("#{disk_root}etc/images")
      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('../../images')
    end

    test 'does not restrict access to ancestor directories when safe mode is disabled' do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.expand_path File.dirname(__FILE__)
      block = block_from_string input, :safe => Asciidoctor::SafeMode::UNSAFE, :attributes => {'docdir' => basedir}
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
      input = <<-EOS
```
puts "Hello, World!"
```
      EOS

      output = render_embedded_string input
      assert_css '.listingblock', output, 1
      assert_css '.listingblock pre code', output, 1
      assert_css '.listingblock pre code:not([class])', output, 1
    end

    test 'should not recognize fenced code blocks with more than three delimiters' do
      input = <<-EOS
````ruby
puts "Hello, World!"
````

~~~~ javascript
alert("Hello, World!")
~~~~
      EOS

      output = render_embedded_string input
      assert_css '.listingblock', output, 0
    end

    test 'should support fenced code blocks with languages' do
      input = <<-EOS
```ruby
puts "Hello, World!"
```

``` javascript
alert("Hello, World!")
```
      EOS

      output = render_embedded_string input
      assert_css '.listingblock', output, 2
      assert_css '.listingblock pre code.language-ruby[data-lang=ruby]', output, 1
      assert_css '.listingblock pre code.language-javascript[data-lang=javascript]', output, 1
    end

    test 'should support fenced code blocks with languages and numbering' do
      input = <<-EOS
```ruby,numbered
puts "Hello, World!"
```

``` javascript, numbered
alert("Hello, World!")
```
      EOS

      output = render_embedded_string input
      assert_css '.listingblock', output, 2
      assert_css '.listingblock pre code.language-ruby[data-lang=ruby]', output, 1
      assert_css '.listingblock pre code.language-javascript[data-lang=javascript]', output, 1
    end

    test 'should highlight source if source-highlighter attribute is coderay' do
      input = <<-EOS
:source-highlighter: coderay

[source, ruby]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :linkcss_default => true
      assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
      assert_match(/\.CodeRay *\{/, output)
    end

    test 'should read source language from source-language document attribute if not specified on source block' do
      input = <<-EOS
:source-highlighter: coderay
:source-language: ruby

[source]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SAFE, :linkcss_default => true
      assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
    end

    test 'should rename document attribute named language to source-language when compat-mode is enabled' do
      input = <<-EOS
:language: ruby

{source-language}
      EOS

      assert_equal 'ruby', render_string(input, :doctype => :inline, :attributes => {'compat-mode' => ''})

      input = <<-EOS
:language: ruby

{source-language}
      EOS

      assert_equal '{source-language}', render_string(input, :doctype => :inline)
    end

    test 'should replace callout marks but not highlight them if source-highlighter attribute is coderay' do
      input = <<-EOS
:source-highlighter: coderay

[source, ruby]
----
require 'coderay' # <1>

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table) # <2>
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
      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_match(/<span class="content">coderay<\/span>.* <b class="conum">\(1\)<\/b>$/, output)
      assert_match(/<span class="content">puts 'Hello, world!'<\/span>.* <b class="conum">\(2\)<\/b>$/, output)
      assert_match(/puts html * <b class="conum">\(3\)<\/b> <b class="conum">\(4\)<\/b>$/, output)
      assert_match(/exit.* <b class="conum">\(5\)<\/b> <b class="conum">\(6\)<\/b><\/code>/, output)
    end

    test 'should restore callout marks to correct lines if source highlighter is coderay and table line numbering is enabled' do
      input = <<-EOS
:source-highlighter: coderay
:coderay-linenums-mode: table

[source, ruby, numbered]
----
require 'coderay' # <1>

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table) # <2>
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
      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_match(/<span class="content">coderay<\/span>.* <b class="conum">\(1\)<\/b>$/, output)
      assert_match(/<span class="content">puts 'Hello, world!'<\/span>.* <b class="conum">\(2\)<\/b>$/, output)
      assert_match(/puts html * <b class="conum">\(3\)<\/b> <b class="conum">\(4\)<\/b>$/, output)
      assert_match(/exit.* <b class="conum">\(5\)<\/b> <b class="conum">\(6\)<\/b><\/pre>/, output)
    end

    test 'should preserve passthrough placeholders when highlighting source using coderay' do
      input = <<-EOS
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
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_match(/\.<em>out<\/em>\./, output, 1)
      assert_match(/\*asterisks\*/, output, 1)
      assert_match(/<strong>bold<\/strong>/, output, 1)
      assert !output.include?(Asciidoctor::Substitutors::PASS_START)
    end

    test 'should link to CodeRay stylesheet if source-highlighter is coderay and linkcss is set' do
      input = <<-EOS
:source-highlighter: coderay

[source, ruby]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'linkcss' => ''}
      assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
      assert_css 'link[rel="stylesheet"][href="./coderay-asciidoctor.css"]', output, 1
    end

    test 'should highlight source inline if source-highlighter attribute is coderay and coderay-css is style' do
      input = <<-EOS
:source-highlighter: coderay
:coderay-css: style

[source, ruby]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :linkcss_default => true
      assert_xpath '//pre[@class="CodeRay highlight"]/code[@data-lang="ruby"]//span[@style = "color:#036;font-weight:bold"][text() = "CodeRay"]', output, 1
      refute_match(/\.CodeRay \{/, output)
    end

    test 'should include remote highlight.js assets if source-highlighter attribute is highlightjs' do
      input = <<-EOS
:source-highlighter: highlightjs

[source, javascript]
----
<link rel="stylesheet" href="styles/default.css">
<script src="highlight.pack.js"></script>
<script>hljs.initHighlightingOnLoad();</script>
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_match(/<link .*highlight\.js/, output)
      assert_match(/<script .*highlight\.js/, output)
      assert_match(/hljs.initHighlightingOnLoad/, output)
    end

    test 'should add language classes to child code element when source-highlighter is prettify' do
      input = <<-EOS
[source,ruby]
----
puts "foo"
----
      EOS

      output = render_embedded_string input, :attributes => {'source-highlighter' => 'prettify'}
      assert_css 'pre[class="prettyprint highlight"]', output, 1
      assert_css 'pre > code.language-ruby[data-lang="ruby"]', output, 1
    end

    test 'should set lang attribute on pre when source-highlighter is html-pipeline' do
      input = <<-EOS
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

      output = render_string input, :attributes => {'source-highlighter' => 'html-pipeline'}
      assert_css 'pre[lang="ruby"]', output, 1
      assert_css 'pre[lang="ruby"] > code', output, 1
      assert_css 'pre[class]', output, 0
      assert_css 'code[class]', output, 0
    end

    test 'document cannot turn on source highlighting if safe mode is at least SERVER' do
      input = <<-EOS
:source-highlighter: coderay
      EOS
      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert doc.attributes['source-highlighter'].nil?
    end
  end

  context 'Abstract and Part Intro' do
    test 'should make abstract on open block without title a quote block for article' do
      input = <<-EOS
= Article

[abstract]
--
This article is about stuff.

And other stuff.
--

== Section One

content
      EOS

      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock.abstract', output, 1
      assert_css '#preamble .quoteblock', output, 1
      assert_css '.quoteblock > blockquote', output, 1
      assert_css '.quoteblock > blockquote > .paragraph', output, 2
    end

    test 'should make abstract on open block with title a quote block with title for article' do
      input = <<-EOS
= Article

.My abstract
[abstract]
--
This article is about stuff.
--

== Section One

content
      EOS

      output = render_string input
      assert_css '.quoteblock', output, 1
      assert_css '.quoteblock.abstract', output, 1
      assert_css '#preamble .quoteblock', output, 1
      assert_css '.quoteblock > .title', output, 1
      assert_css '.quoteblock > .title + blockquote', output, 1
      assert_css '.quoteblock > .title + blockquote > .paragraph', output, 1
    end

    test 'should allow abstract in document with title if doctype is book' do
      input = <<-EOS
= Book
:doctype: book

[abstract]
Abstract for book with title is valid
      EOS

      output = render_string input
      assert_css '.abstract', output, 1
    end

    test 'should not allow abstract as direct child of document if doctype is book' do
      input = <<-EOS
:doctype: book

[abstract]
Abstract for book without title is invalid.
      EOS

      warnings = nil
      output = nil
      redirect_streams do |stdout, stderr|
        output = render_string input
        warnings = stderr.string
      end
      assert_css '.abstract', output, 0
      refute_nil warnings
      assert_match(/WARNING:.*abstract block/, warnings)
    end

    test 'should make abstract on open block without title rendered to DocBook' do
      input = <<-EOS
= Article

[abstract]
--
This article is about stuff.

And other stuff.
--
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'abstract', output, 1
      assert_css 'abstract > simpara', output, 2
    end

    test 'should make abstract on open block with title rendered to DocBook' do
      input = <<-EOS
= Article

.My abstract
[abstract]
--
This article is about stuff.
--
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'abstract', output, 1
      assert_css 'abstract > title', output, 1
      assert_css 'abstract > title + simpara', output, 1
    end

    test 'should allow abstract in document with title if doctype is book rendered to DocBook' do
      input = <<-EOS
= Book
:doctype: book

[abstract]
Abstract for book with title is valid
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'abstract', output, 1
    end

    test 'should not allow abstract as direct child of document if doctype is book rendered to DocBook' do
      input = <<-EOS
:doctype: book

[abstract]
Abstract for book is invalid.
      EOS

      output = nil
      warnings = nil
      redirect_streams do |stdout, stderr|
        output = render_string input, :backend => 'docbook'
        warnings = stderr.string
      end
      assert_css 'abstract', output, 0
      refute_nil warnings
      assert_match(/WARNING:.*abstract block/, warnings)
    end

    # TODO partintro shouldn't be recognized if doctype is not book, should be in proper place
    test 'should accept partintro on open block without title' do
      input = <<-EOS
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

      output = render_string input
      assert_css '.openblock', output, 1
      assert_css '.openblock.partintro', output, 1
      assert_css '.openblock .title', output, 0
      assert_css '.openblock .content', output, 1
      assert_xpath %(//h1[@id="_part_1"]/following-sibling::*[#{contains_class(:openblock)}]), output, 1
      assert_xpath %(//*[#{contains_class(:openblock)}]/*[@class="content"]/*[@class="paragraph"]), output, 2
    end

    test 'should accept partintro on open block with title' do
      input = <<-EOS
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

      output = render_string input
      assert_css '.openblock', output, 1
      assert_css '.openblock.partintro', output, 1
      assert_css '.openblock .title', output, 1
      assert_css '.openblock .content', output, 1
      assert_xpath %(//h1[@id="_part_1"]/following-sibling::*[#{contains_class(:openblock)}]), output, 1
      assert_xpath %(//*[#{contains_class(:openblock)}]/*[@class="title"][text() = "Intro title"]), output, 1
      assert_xpath %(//*[#{contains_class(:openblock)}]/*[@class="content"]/*[@class="paragraph"]), output, 1
    end

    test 'should exclude partintro if not a child of part' do
      input = <<-EOS
= Book
:doctype: book

[partintro]
part intro paragraph
      EOS

      output = render_string input
      assert_css '.partintro', output, 0
    end

    test 'should not allow partintro unless doctype is book' do
      input = <<-EOS
[partintro]
part intro paragraph
      EOS

      output = render_string input
      assert_css '.partintro', output, 0
    end

    test 'should accept partintro on open block without title rendered to DocBook' do
      input = <<-EOS
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

      output = render_string input, :backend => 'docbook45'
      assert_css 'partintro', output, 1
      assert_css 'part#_part_1 > partintro', output, 1
      assert_css 'partintro > simpara', output, 2
    end

    test 'should accept partintro on open block with title rendered to DocBook' do
      input = <<-EOS
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

      output = render_string input, :backend => 'docbook45'
      assert_css 'partintro', output, 1
      assert_css 'part#_part_1 > partintro', output, 1
      assert_css 'partintro > title', output, 1
      assert_css 'partintro > title + simpara', output, 1
    end

    test 'should exclude partintro if not a child of part rendered to DocBook' do
      input = <<-EOS
= Book
:doctype: book

[partintro]
part intro paragraph
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'partintro', output, 0
    end

    test 'should not allow partintro unless doctype is book rendered to DocBook' do
      input = <<-EOS
[partintro]
part intro paragraph
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'partintro', output, 0
    end
  end

  context 'Substitutions' do
    test 'should be able to append subs to default block substitution list' do
      input = <<-EOS
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
      input = <<-EOS
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
      input = <<-EOS
[subs="-quotes,-replacements"]
content
      EOS

      doc = document_from_string input
      block = doc.blocks.first
      assert_equal [:specialcharacters, :attributes, :macros, :post_replacements], block.subs
    end

    test 'should be able to prepend, append and remove subs from default block substitution list' do
      input = <<-EOS
:application: asciidoctor

[subs="attributes+,-verbatim,+specialcharacters,+macros"]
....
http://{application}.org[{gt}{gt}] <1>
....
      EOS

      doc = document_from_string input, :header_footer => false
      block = doc.blocks.first
      assert_equal [:attributes, :specialcharacters, :macros], block.subs
      result = doc.render
      assert result.include?('<pre><a href="http://asciidoctor.org">&gt;&gt;</a> &lt;1&gt;</pre>')
    end

    test 'should be able to set subs then modify them' do
      input = <<-EOS
[subs="verbatim,-callouts"]
_hey now_ <1>
      EOS

      doc = document_from_string input, :header_footer => false
      block = doc.blocks.first
      assert_equal [:specialcharacters], block.subs
      result = doc.render
      assert result.include?('_hey now_ &lt;1&gt;')
    end
  end

  context 'References' do
    test 'should not recognize block anchor with illegal id characters' do
      input = <<-EOS
[[illegal$id,Reference Text]]
----
content
----
      EOS

      doc = document_from_string input
      block = doc.blocks.first
      assert_nil block.id
      assert_nil(block.attr 'reftext')
      assert !doc.references[:ids].has_key?('illegal$id')
    end

    test 'should use specified id and reftext when registering block reference' do
      input = <<-EOS
[[debian,Debian Install]]
.Installation on Debian
----
$ apt-get install asciidoctor
----
      EOS

      doc = document_from_string input
      reftext = doc.references[:ids]['debian']
      refute_nil reftext
      assert_equal 'Debian Install', reftext
    end

    test 'should allow square brackets in block reference text' do
      input = <<-EOS
[[debian,[Debian] Install]]
.Installation on Debian
----
$ apt-get install asciidoctor
----
      EOS

      doc = document_from_string input
      reftext = doc.references[:ids]['debian']
      refute_nil reftext
      assert_equal '[Debian] Install', reftext
    end

    test 'should allow comma in block reference text' do
      input = <<-EOS
[[debian, Debian, Ubuntu]]
.Installation on Debian
----
$ apt-get install asciidoctor
----
      EOS

      doc = document_from_string input
      reftext = doc.references[:ids]['debian']
      refute_nil reftext
      assert_equal 'Debian, Ubuntu', reftext
    end

    test 'should use specified reftext when registering block reference' do
      input = <<-EOS
[[debian]]
[reftext="Debian Install"]
.Installation on Debian
----
$ apt-get install asciidoctor
----
      EOS

      doc = document_from_string input
      reftext = doc.references[:ids]['debian']
      refute_nil reftext
      assert_equal 'Debian Install', reftext
    end
  end
end
