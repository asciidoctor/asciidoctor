# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context 'Paragraphs' do
  context 'Normal' do
    test 'should treat plain text separated by blank lines as paragraphs' do
      input = <<-EOS
Plain text for the win!

Yep. Text. Plain and simple.
      EOS
      output = render_embedded_string input
      assert_css 'p', output, 2
      assert_xpath '(//p)[1][text() = "Plain text for the win!"]', output, 1
      assert_xpath '(//p)[2][text() = "Yep. Text. Plain and simple."]', output, 1
    end

    test 'should associate block title with paragraph' do
      input = <<-EOS
.Titled
Paragraph.

Winning.
      EOS
      output = render_embedded_string input
      
      assert_css 'p', output, 2
      assert_xpath '(//p)[1]/preceding-sibling::*[@class = "title"]', output, 1
      assert_xpath '(//p)[1]/preceding-sibling::*[@class = "title"][text() = "Titled"]', output, 1
      assert_xpath '(//p)[2]/preceding-sibling::*[@class = "title"]', output, 0
    end

    test 'no duplicate block before next section' do
      input = <<-EOS
= Title

Preamble

== First Section

Paragraph 1

Paragraph 2

== Second Section

Last words
      EOS

      output = render_string input
      assert_xpath '//p[text() = "Paragraph 2"]', output, 1
    end

    test 'does not treat wrapped line as a list item' do
      input = <<-EOS
paragraph
. wrapped line
      EOS

      output = render_embedded_string input 
      assert_css 'p', output, 1
      assert_xpath %(//p[text()="paragraph\n. wrapped line"]), output, 1
    end

    test 'does not treat wrapped line as a block title' do
      input = <<-EOS
paragraph
.wrapped line
      EOS

      output = render_embedded_string input 
      assert_css 'p', output, 1
      assert_xpath %(//p[text()="paragraph\n.wrapped line"]), output, 1
    end

    test 'interprets normal paragraph style as normal paragraph' do
      input = <<-EOS
[normal]
Normal paragraph.
Nothing special.
      EOS

      output = render_embedded_string input
      assert_css 'p', output, 1
    end

    test 'removes indentation from literal paragraph marked as normal' do
      input = <<-EOS
[normal]
  Normal paragraph.
    Nothing special.
  Last line.
      EOS

      output = render_embedded_string input
      assert_css 'p', output, 1
      assert_xpath %(//p[text()="Normal paragraph.\n  Nothing special.\nLast line."]), output, 1
    end

    test 'normal paragraph terminates at block attribute list' do
      input = <<-EOS
normal text
[literal]
literal text
      EOS
      output = render_embedded_string input
      assert_css '.paragraph:root', output, 1
      assert_css '.literalblock:root', output, 1
    end

    test 'normal paragraph terminates at block delimiter' do
      input = <<-EOS
normal text
--
text in open block
--
      EOS
      output = render_embedded_string input
      assert_css '.paragraph:root', output, 1
      assert_css '.openblock:root', output, 1
    end

    test 'normal paragraph terminates at list continuation' do
      input = <<-EOS
normal text
+
      EOS
      output = render_embedded_string input
      assert_css '.paragraph:root', output, 2
      assert_xpath %((/*[@class="paragraph"])[1]/p[text() = "normal text"]), output, 1
      assert_xpath %((/*[@class="paragraph"])[2]/p[text() = "+"]), output, 1
    end

    test 'normal style turns literal paragraph into normal paragraph' do
      input = <<-EOS
[normal]
 normal paragraph,
 despite the leading indent
      EOS

      output = render_embedded_string input
      assert_css '.paragraph:root > p', output, 1
    end

    test 'expands index term macros in DocBook backend' do
      input = <<-EOS
Here is an index entry for ((tigers)).
indexterm:[Big cats,Tigers,Siberian Tiger]
Here is an index entry for indexterm2:[Linux].
(((Operating Systems,Linux,Fedora)))
Note that multi-entry terms generate separate index entries.
      EOS

      output = render_embedded_string input, :attributes => {'backend' => 'docbook45'}
      assert_xpath '/simpara', output, 1
      term1 = (xmlnodes_at_xpath '(//indexterm)[1]', output, 1).first
      assert_equal '<indexterm><primary>tigers</primary></indexterm>', term1.to_s
      assert term1.next.content.start_with?('tigers')

      term2 = (xmlnodes_at_xpath '(//indexterm)[2]', output, 1).first
      term2_elements = term2.elements
      assert_equal 3, term2_elements.size
      assert_equal '<primary>Big cats</primary>', term2_elements[0].to_s
      assert_equal '<secondary>Tigers</secondary>', term2_elements[1].to_s
      assert_equal '<tertiary>Siberian Tiger</tertiary>', term2_elements[2].to_s

      term3 = (xmlnodes_at_xpath '(//indexterm)[3]', output, 1).first
      term3_elements = term3.elements
      assert_equal 2, term3_elements.size
      assert_equal '<primary>Tigers</primary>', term3_elements[0].to_s
      assert_equal '<secondary>Siberian Tiger</secondary>', term3_elements[1].to_s

      term4 = (xmlnodes_at_xpath '(//indexterm)[4]', output, 1).first
      term4_elements = term4.elements
      assert_equal 1, term4_elements.size
      assert_equal '<primary>Siberian Tiger</primary>', term4_elements[0].to_s

      term5 = (xmlnodes_at_xpath '(//indexterm)[5]', output, 1).first
      assert_equal '<indexterm><primary>Linux</primary></indexterm>', term5.to_s
      assert term5.next.content.start_with?('Linux')

      assert_xpath '(//indexterm)[6]/*', output, 3
      assert_xpath '(//indexterm)[7]/*', output, 2
      assert_xpath '(//indexterm)[8]/*', output, 1
    end

    test 'normal paragraph should honor explicit subs list' do
      input = <<-EOS
[subs="specialcharacters"]
*<Hey Jude>*
      EOS

      output = render_embedded_string input
      assert output.include?('*&lt;Hey Jude&gt;*')
    end

    test 'normal paragraph should honor specialchars shorthand' do
      input = <<-EOS
[subs="specialchars"]
*<Hey Jude>*
      EOS

      output = render_embedded_string input
      assert output.include?('*&lt;Hey Jude&gt;*')
    end

    test 'should add a hardbreak at end of each line when hardbreaks option is set' do
      input = <<-EOS
[%hardbreaks]
read
my
lips
      EOS

      output = render_embedded_string input
      assert_css 'br', output, 2
      assert_xpath '//p', output, 1
      assert output.include?("<p>read<br>\nmy<br>\nlips</p>")
    end
  end

  context 'Literal' do
    test 'single-line literal paragraphs' do
      input = <<-EOS
 LITERALS

 ARE LITERALLY

 AWESOME!
      EOS
      output = render_embedded_string input
      assert_xpath '//pre', output, 3
    end

    test 'multi-line literal paragraph' do
      input = <<-EOS
Install instructions:

 yum install ruby rubygems
 gem install asciidoctor

You're good to go!
      EOS
      output = render_embedded_string input
      assert_xpath '//pre', output, 1
      # indentation should be trimmed from literal block
      assert_xpath %(//pre[text() = "yum install ruby rubygems\ngem install asciidoctor"]), output, 1
    end

    test 'literal paragraph' do
      input = <<-EOS
[literal]
this text is literally literal
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="literalblock"]//pre[text()="this text is literally literal"]), output, 1
    end

    test 'should read content below literal style verbatim' do
      input = <<-EOS
[literal]
image::not-an-image-block[]
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="literalblock"]//pre[text()="image::not-an-image-block[]"]), output, 1
      assert_css 'img', output, 0
    end

    test 'listing paragraph' do
      input = <<-EOS
[listing]
this text is a listing
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="listingblock"]//pre[text()="this text is a listing"]), output, 1
    end

    test 'source paragraph' do
      input = <<-EOS
[source]
use the source, luke!
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="listingblock"]//pre[@class="highlight"]/code[text()="use the source, luke!"]), output, 1
    end

    test 'source code paragraph with language' do
      input = <<-EOS
[source, perl]
die 'zomg perl sucks';
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="listingblock"]//pre[@class="highlight"]/code[@class="perl language-perl"][text()="die 'zomg perl sucks';"]), output, 1
    end

    test 'literal paragraph terminates at block attribute list' do
      input = <<-EOS
 literal text
[normal]
normal text
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="literalblock"]), output, 1
      assert_xpath %(/*[@class="paragraph"]), output, 1
    end

    test 'literal paragraph terminates at block delimiter' do
      input = <<-EOS
 literal text
--
normal text
--
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="literalblock"]), output, 1
      assert_xpath %(/*[@class="openblock"]), output, 1
    end

    test 'literal paragraph terminates at list continuation' do
      input = <<-EOS
 literal text
+
      EOS
      output = render_embedded_string input
      assert_xpath %(/*[@class="literalblock"]), output, 1
      assert_xpath %(/*[@class="literalblock"]//pre[text() = "literal text"]), output, 1
      assert_xpath %(/*[@class="paragraph"]), output, 1
      assert_xpath %(/*[@class="paragraph"]/p[text() = "+"]), output, 1
    end
  end

  context 'Quote' do
    test "single-line quote paragraph" do
      input = <<-EOS
[quote]
Famous quote.
      EOS
      output = render_string input
      assert_xpath '//*[@class = "quoteblock"]', output, 1
      assert_xpath '//*[@class = "quoteblock"]//p', output, 0
      assert_xpath '//*[@class = "quoteblock"]//*[contains(text(), "Famous quote.")]', output, 1
    end

    test 'quote paragraph terminates at list continuation' do
      input = <<-EOS
[quote]
A famouse quote.
+
      EOS
      output = render_embedded_string input
      assert_css '.quoteblock:root', output, 1
      assert_css '.paragraph:root', output, 1
      assert_xpath %(/*[@class="paragraph"]/p[text() = "+"]), output, 1
    end

    test "verse paragraph" do
      output = render_string("[verse]\nFamous verse.")
      assert_xpath '//*[@class = "verseblock"]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre', output, 1
      assert_xpath '//*[@class = "verseblock"]//p', output, 0
      assert_xpath '//*[@class = "verseblock"]/pre[normalize-space(text()) = "Famous verse."]', output, 1
    end

    test 'should perform normal subs on a verse paragraph' do
      input = <<-EOS
[verse]
_GET /groups/link:#group-id[\{group-id\}]_
      EOS

      output = render_embedded_string input
      assert output.include?('<pre class="content"><em>GET /groups/<a href="#group-id">{group-id}</a></em></pre>')
    end

    test 'quote paragraph should honor explicit subs list' do
      input = <<-EOS
[subs="specialcharacters"]
[quote]
*Hey Jude*
      EOS

      output = render_embedded_string input
      assert output.include?('*Hey Jude*')
    end
  end

  context "special" do
    test "note multiline syntax" do
      Asciidoctor::ADMONITION_STYLES.each do |style|
        assert_xpath "//div[@class='admonitionblock #{style.downcase}']", render_string("[#{style}]\nThis is a winner.")
      end
    end

    test "note block syntax" do
      Asciidoctor::ADMONITION_STYLES.each do |style|
        assert_xpath "//div[@class='admonitionblock #{style.downcase}']", render_string("[#{style}]\n====\nThis is a winner.\n====")
      end
    end

    test "note inline syntax" do
      Asciidoctor::ADMONITION_STYLES.each do |style|
        assert_xpath "//div[@class='admonitionblock #{style.downcase}']", render_string("#{style}: This is important, fool!")
      end
    end

    test "sidebar block" do
      input = <<-EOS
== Section

.Sidebar
****
Content goes here
****
      EOS
      result = render_string(input)
      assert_xpath "//*[@class='sidebarblock']//p", result, 1
    end

    context 'Styled Paragraphs' do
      test 'should wrap text in simpara for styled paragraphs when rendered to DocBook' do
        input = <<-EOS
= Book
:doctype: book

[preface]
= About this book

[abstract]
An abstract for the book.

= Part 1

[partintro]
An intro to this part.

== Chapter 1

[sidebar]
Just a side note.

[example]
As you can see here.

[quote]
Wise words from a wise person.
        EOS

        output = render_string input, :backend => 'docbook'
        assert_css 'abstract > simpara', output, 1
        assert_css 'partintro > simpara', output, 1
        assert_css 'sidebar > simpara', output, 1
        assert_css 'informalexample > simpara', output, 1
        assert_css 'blockquote > simpara', output, 1
      end

      test 'should wrap text in simpara for styled paragraphs with title when rendered to DocBook' do
        input = <<-EOS
= Book
:doctype: book

[preface]
= About this book

[abstract]
.Abstract title
An abstract for the book.

= Part 1

[partintro]
.Part intro title
An intro to this part.

== Chapter 1

[sidebar]
.Sidebar title
Just a side note.

[example]
.Example title
As you can see here.

[quote]
.Quote title
Wise words from a wise person.
        EOS

        output = render_string input, :backend => 'docbook'
        assert_css 'abstract > title', output, 1
        assert_xpath '//abstract/title[text() = "Abstract title"]', output, 1
        assert_css 'abstract > title + simpara', output, 1
        assert_css 'partintro > title', output, 1
        assert_xpath '//partintro/title[text() = "Part intro title"]', output, 1
        assert_css 'partintro > title + simpara', output, 1
        assert_css 'sidebar > title', output, 1
        assert_xpath '//sidebar/title[text() = "Sidebar title"]', output, 1
        assert_css 'sidebar > title + simpara', output, 1
        assert_css 'example > title', output, 1
        assert_xpath '//example/title[text() = "Example title"]', output, 1
        assert_css 'example > title + simpara', output, 1
        assert_css 'blockquote > title', output, 1
        assert_xpath '//blockquote/title[text() = "Quote title"]', output, 1
        assert_css 'blockquote > title + simpara', output, 1
      end
    end

    context 'Inline doctype' do
      test 'should only format and output text in first paragraph when doctype is inline' do
        input = "http://asciidoc.org[AsciiDoc] is a _lightweight_ markup language...\n\nignored"
        output = render_string input, :doctype => 'inline'
        assert_equal '<a href="http://asciidoc.org">AsciiDoc</a> is a <em>lightweight</em> markup language&#8230;', output
      end

      test 'should output empty string if first block is not a paragraph' do
        input = '* bullet'
        output = render_string input, :doctype => 'inline'
        assert output.empty?
      end
    end
  end
end
