# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context 'Preamble' do

  test 'title and single paragraph preamble before section' do
    input = <<-EOS
= Title

Preamble paragraph 1.

== First Section

Section paragraph 1.
    EOS
    result = render_string(input)
    assert_xpath '//p', result, 2
    assert_xpath '//*[@id="preamble"]', result, 1
    assert_xpath '//*[@id="preamble"]//p', result, 1
    assert_xpath '//*[@id="preamble"]/following-sibling::*//h2[@id="_first_section"]', result, 1
    assert_xpath '//*[@id="preamble"]/following-sibling::*//p', result, 1
  end

  test 'title of preface is blank by default in DocBook output' do
    input = <<-EOS
= Document Title
:doctype: book

Preface content.

== First Section

Section content.
    EOS
    result = render_string input, :backend => :docbook
    assert_xpath '//preface/title', result, 1
    title_node = xmlnodes_at_xpath '//preface/title', result, 1
    assert_equal '', title_node.text
  end

  test 'preface-title attribute is assigned as title of preface in DocBook output' do
    input = <<-EOS
= Document Title
:doctype: book
:preface-title: Preface

Preface content.

== First Section

Section content.
    EOS
    result = render_string input, :backend => :docbook
    assert_xpath '//preface/title[text()="Preface"]', result, 1
  end

  test 'title and multi-paragraph preamble before section' do
    input = <<-EOS
= Title

Preamble paragraph 1.

Preamble paragraph 2.

== First Section

Section paragraph 1.
    EOS
    result = render_string(input)
    assert_xpath '//p', result, 3
    assert_xpath '//*[@id="preamble"]', result, 1
    assert_xpath '//*[@id="preamble"]//p', result, 2
    assert_xpath '//*[@id="preamble"]/following-sibling::*//h2[@id="_first_section"]', result, 1
    assert_xpath '//*[@id="preamble"]/following-sibling::*//p', result, 1
  end

  test 'should not wrap content in preamble if document has title but no sections' do
    input = <<-EOS
= Title

paragraph
    EOS
    result = render_string(input)
    assert_xpath '//p', result, 1
    assert_xpath '//*[@id="content"]/*[@class="paragraph"]/p', result, 1
    assert_xpath '//*[@id="content"]/*[@class="paragraph"]/following-sibling::*', result, 0
  end

  test 'title and section without preamble' do
    input = <<-EOS
= Title

== First Section

Section paragraph 1.
    EOS
    result = render_string(input)
    assert_xpath '//p', result, 1
    assert_xpath '//*[@id="preamble"]', result, 0
    assert_xpath '//h2[@id="_first_section"]', result, 1
  end

  test 'no title with preamble and section' do
    input = <<-EOS
Preamble paragraph 1.

== First Section

Section paragraph 1.
    EOS
    result = render_string(input)
    assert_xpath '//p', result, 2
    assert_xpath '//*[@id="preamble"]', result, 0
    assert_xpath '//h2[@id="_first_section"]/preceding::p', result, 1
  end

  test 'preamble in book doctype' do
      input = <<-EOS
= Book
:doctype: book

Back then...

= Chapter One

[partintro]
It was a dark and stormy night...

== Scene One

Someone's gonna get axed.

= Chapter Two

[partintro]
They couldn't believe their eyes when...

== Scene One

The axe came swinging.
      EOS

      d = document_from_string(input)
      assert_equal 'book', d.doctype
      output = d.render
      assert_xpath '//h1', output, 3
      assert_xpath %{//*[@id="preamble"]//p[text() = "Back then#{expand_entity 8230}#{expand_entity 8203}"]}, output, 1
  end

  test 'should render table of contents in preamble if toc-placement attribute value is preamble' do
    input = <<-EOS
= Article
:toc:
:toc-placement: preamble

Once upon a time...

== Section One

It was a dark and stormy night...

== Section Two

They couldn't believe their eyes when...
      EOS

    output = render_string input
    assert_xpath '//*[@id="preamble"]/*[@id="toc"]', output, 1
  end
end
