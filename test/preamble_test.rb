require 'test_helper'

context 'Preamble' do

  test 'title and single paragraph preamble before section' do
    input = <<-EOS
Title
=====

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

  test 'title and multi-paragraph preamble before section' do
    input = <<-EOS
Title
=====

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

  test 'title and preamble only' do
    input = <<-EOS
Title
=====

Preamble paragraph 1.
    EOS
    result = render_string(input)
    assert_xpath '//p', result, 1
    assert_xpath '//*[@id="preamble"]', result, 1
    assert_xpath '//*[@id="preamble"]//p', result, 1
    assert_xpath '//*[@id="preamble"]/following-sibling::*', result, 0
  end

  test 'title and section without preamble' do
    input = <<-EOS
Title
=====

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

end
