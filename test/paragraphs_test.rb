require 'test_helper'

context "Paragraphs" do
  context 'Normal' do
    test "rendered correctly" do
      assert_xpath "//p", render_string("Plain text for the win.\n\nYes, plainly."), 2
    end

    test "with title" do
      rendered = render_string(".Titled\nParagraph.\n\nWinning")
      
      assert_xpath "//div[@class='title']", rendered
      assert_xpath "//p", rendered, 2
    end

    test "no duplicate block before next section" do
      rendered = render_string("Title\n=====\n\nPreamble.\n\n== First Section\n\nParagraph 1\n\nParagraph 2\n\n\n== Second Section\n\nLast words")
      assert_xpath '//p[text()="Paragraph 2"]', rendered, 1
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
  end

  context "code" do
    test "single-line literal paragraphs" do
      assert_xpath "//pre", render_string("    LITERALS\n\n    ARE LITERALLY\n\n    AWESOMMMME.")
    end

    test "multi-line literal paragraph" do
      input = <<-EOS
Install instructions:

 yum install ruby rubygems
 gem install asciidoctor

You're good to go!
      EOS
      output = render_string(input)
      assert_xpath "//pre", output, 1
      assert_match(/^gem install asciidoctor/, output, "Indentation should be trimmed from literal block")
    end

    test "literal paragraph" do
      assert_xpath "//*[@class='literalblock']//pre[text()='blah blah blah']", render_string("[literal]\nblah blah blah")
    end

    test "listing paragraph" do
      assert_xpath "//*[@class='listingblock']//pre[text()='blah blah blah']", render_string("[listing]\nblah blah blah")
    end

    test "source code paragraph" do
      assert_xpath "//pre[@class='highlight']/code", render_string("[source]\nblah blah blah")
    end

    test "source code paragraph with language" do
      assert_xpath "//pre[@class='highlight']/code[@class='perl']", render_string("[source, perl]\ndie 'zomg perl sucks';")
    end
  end

  context "quote" do
    test "quote block" do
      output = render_string("____\nFamous quote.\n____")
      assert_xpath '//*[@class = "quoteblock"]', output, 1
      assert_xpath '//*[@class = "quoteblock"]//p[text() = "Famous quote."]', output, 1
    end

    test "quote block with attribution" do
      output = render_string("[quote, A famous person, A famous book (1999)]\n____\nFamous quote.\n____")
      assert_xpath '//*[@class = "quoteblock"]', output, 1
      assert_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]', output, 1
      assert_xpath '//*[@class = "quoteblock"]/*[@class = "attribution"]/cite[text() = "A famous book (1999)"]', output, 1
      # TODO I can't seem to match the attribution (author) w/ xpath
    end

    test "quote block with section body" do
      output = render_string("____\nFamous quote.\n\nNOTE: That was inspiring.\n____")
      assert_xpath '//*[@class = "quoteblock"]', output, 1
      assert_xpath '//*[@class = "quoteblock"]//*[@class = "admonitionblock"]', output, 1
    end

    test "single-line quote paragraph" do
      output = render_string("[quote]\nFamous quote.")
      assert_xpath '//*[@class = "quoteblock"]', output, 1
      assert_xpath '//*[@class = "quoteblock"]//p', output, 0
      assert_xpath '//*[@class = "quoteblock"]//*[contains(text(), "Famous quote.")]', output, 1
    end

    test "verse paragraph" do
      output = render_string("[verse]\nFamous verse.")
      assert_xpath '//*[@class = "verseblock"]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre', output, 1
      assert_xpath '//*[@class = "verseblock"]//p', output, 0
      assert_xpath '//*[@class = "verseblock"]/pre[normalize-space(text()) = "Famous verse."]', output, 1
    end

    test "single-line verse block" do
      output = render_string("[verse]\n____\nFamous verse.\n____")
      assert_xpath '//*[@class = "verseblock"]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre', output, 1
      assert_xpath '//*[@class = "verseblock"]//p', output, 0
      assert_xpath '//*[@class = "verseblock"]/pre[normalize-space(text()) = "Famous verse."]', output, 1
    end

    test "multi-line verse block" do
      output = render_string("[verse]\n____\nFamous verse.\n\nStanza two.\n____")
      assert_xpath '//*[@class = "verseblock"]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre', output, 1
      assert_xpath '//*[@class = "verseblock"]//p', output, 0
      assert_xpath '//*[@class = "verseblock"]/pre[contains(text(), "Famous verse.")]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre[contains(text(), "Stanza two.")]', output, 1
    end

    test "verse block does not contain block elements" do
      output = render_string("[verse]\n____\nFamous verse.\n\n....\nnot a literal\n....\n____")
      assert_xpath '//*[@class = "verseblock"]', output, 1
      assert_xpath '//*[@class = "verseblock"]/pre', output, 1
      assert_xpath '//*[@class = "verseblock"]//p', output, 0
      assert_xpath '//*[@class = "verseblock"]//*[@class = "literalblock"]', output, 0
    end
  end

  context "special" do
    test "note multiline syntax" do
      Asciidoctor::ADMONITION_STYLES.each do |style|
        assert_xpath "//div[@class='admonitionblock']", render_string("[#{style}]\nThis is a winner.")
      end
    end

    test "note block syntax" do
      Asciidoctor::ADMONITION_STYLES.each do |style|
        assert_xpath "//div[@class='admonitionblock']", render_string("[#{style}]\n====\nThis is a winner.\n====")
      end
    end

    test "note inline syntax" do
      Asciidoctor::ADMONITION_STYLES.each do |style|
        assert_xpath "//div[@class='admonitionblock']", render_string("#{style}: This is important, fool!")
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
  end
end
