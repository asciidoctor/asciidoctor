require 'test_helper'

context 'Links' do

  test 'qualified url inline with text' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = 'http://asciidoc.org']", render_string("The AsciiDoc project is located at http://asciidoc.org.")
  end

  test 'qualified url with label' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = 'AsciiDoc']", render_string("We're parsing http://asciidoc.org[AsciiDoc] markup")
  end

  test 'qualified url with label containing escaped right square bracket' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = '[Ascii]Doc']", render_string("We're parsing http://asciidoc.org[[Ascii\\]Doc] markup")
  end

  test 'qualified url with label using link macro' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = 'AsciiDoc']", render_string("We're parsing link:http://asciidoc.org[AsciiDoc] markup")
  end

  test 'qualified url using macro syntax with multi-line label inline with text' do
    assert_xpath %{//a[@href='http://asciidoc.org'][text() = 'AsciiDoc\nmarkup']}, render_string("We're parsing link:http://asciidoc.org[AsciiDoc\nmarkup]")
  end

  test 'qualified url surrounded by angled brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="http://asciidoc.org"]', render_string('<http://asciidoc.org> is the project page for AsciiDoc.'), 1
  end

  test 'qualified url surrounded by round brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="http://asciidoc.org"]', render_string('(http://asciidoc.org) is the project page for AsciiDoc.'), 1
  end

  test 'qualified url containing round brackets' do
    assert_xpath '//a[@href="http://jruby.org/apidocs/org/jruby/Ruby.html#addModule(org.jruby.RubyModule)"][text()="addModule() adds a Ruby module"]', render_string('http://jruby.org/apidocs/org/jruby/Ruby.html#addModule(org.jruby.RubyModule)[addModule() adds a Ruby module]'), 1
  end

  test 'qualified url adjacent to text in square brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', render_string(']http://asciidoc.org[AsciiDoc] project page.'), 1
  end

  test 'qualified url adjacent to text in round brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', render_string(')http://asciidoc.org[AsciiDoc] project page.'), 1
  end

  test 'qualified url using invalid link macro should not create link' do
    assert_xpath '//a', render_string('link:http://asciidoc.org is the project page for AsciiDoc.'), 0
  end

  test 'escaped inline qualified url should not create link' do
    assert_xpath '//a', render_string('\http://asciidoc.org is the project page for AsciiDoc.'), 0
  end

  test 'escaped inline qualified url using macro syntax should not create link' do
    assert_xpath '//a', render_string('\http://asciidoc.org[AsciiDoc] is the key to good docs.'), 0
  end

  test 'inline qualified url followed by an endline should not include endline in link' do
    assert_xpath '//a[@href="http://github.com/asciidoctor"]', render_string("The source code for Asciidoctor can be found at http://github.com/asciidoctor\nwhich is a GitHub organization."), 1
  end

  test 'qualified url divided by endline using macro syntax should not create link' do
    assert_xpath '//a', render_string("The source code for Asciidoctor can be found at link:http://github.com/asciidoctor\n[]which is a GitHub organization."), 0
  end

  test 'qualified url containing whitespace using macro syntax should not create link' do
    assert_xpath '//a', render_string('I often need to refer to the chapter on link:http://asciidoc.org?q=attribute references[Attribute References].'), 0
  end

  test 'qualified url containing an encoded space using macro syntax should create a link' do
    assert_xpath '//a', render_string('I often need to refer to the chapter on link:http://asciidoc.org?q=attribute%20references[Attribute References].'), 1
  end

  test 'inline quoted qualified url should not consume surrounding angled brackets' do
    assert_xpath '//a[@href="http://github.com/asciidoctor"]', render_string('Asciidoctor GitHub organization: <**http://github.com/asciidoctor**>'), 1
  end

  test 'inline ref' do
    doc = document_from_string 'Here you can read about tigers.[[tigers]]'
    output = doc.render
    assert_equal '[tigers]', doc.references[:ids]['tigers']
    assert_xpath '//a[@id = "tigers"]', output, 1
    assert_xpath '//a[@id = "tigers"]/child::text()', output, 0
  end

  test 'inline ref with reftext' do
    doc = document_from_string 'Here you can read about tigers.[[tigers,Tigers]]'
    output = doc.render
    assert_equal 'Tigers', doc.references[:ids]['tigers']
    assert_xpath '//a[@id = "tigers"]', output, 1
    assert_xpath '//a[@id = "tigers"]/child::text()', output, 0
  end

  test 'escaped inline ref' do
    doc = document_from_string 'Here you can read about tigers.\[[tigers]]'
    output = doc.render
    assert !doc.references[:ids].has_key?('tigers')
    assert_xpath '//a[@id = "tigers"]', output, 0
  end

  test 'xref using angled bracket syntax' do
    doc = document_from_string '<<tigers>>'
    doc.references[:ids]['tigers'] = '[tigers]'
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', doc.render, 1
  end

  test 'xref using angled bracket syntax with label' do
    assert_xpath '//a[@href="#tigers"][text() = "About Tigers"]', render_string('<<tigers,About Tigers>>'), 1
  end

  test 'xref using angled bracket syntax with quoted label' do
    assert_xpath '//a[@href="#tigers"][text() = "About Tigers"]', render_string('<<tigers,"About Tigers">>'), 1
  end

  test 'xref using angled bracket syntax inline with text' do
    assert_xpath '//a[@href="#tigers"][text() = "about tigers"]', render_string('Want to learn <<tigers,about tigers>>?'), 1
  end

  test 'xref using angled bracket syntax with multi-line label inline with text' do
    assert_xpath %{//a[@href="#tigers"][text() = "about\ntigers"]}, render_string("Want to learn <<tigers,about\ntigers>>?"), 1
  end

  test 'xref using macro syntax' do
    doc = document_from_string 'xref:tigers[]'
    doc.references[:ids]['tigers'] = '[tigers]'
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', doc.render, 1
  end

  test 'xref using macro syntax with label' do
    assert_xpath '//a[@href="#tigers"][text() = "About Tigers"]', render_string('xref:tigers[About Tigers]'), 1
  end

  test 'xref using macro syntax inline with text' do
    assert_xpath '//a[@href="#tigers"][text() = "about tigers"]', render_string('Want to learn xref:tigers[about tigers]?'), 1
  end

  test 'xref using macro syntax with multi-line label inline with text' do
    assert_xpath %{//a[@href="#tigers"][text() = "about\ntigers"]}, render_string("Want to learn xref:tigers[about\ntigers]?"), 1
  end

  test 'xref using invalid macro syntax does not create link' do
    doc = document_from_string 'xref:tigers'
    doc.references[:ids]['tigers'] = '[tigers]'
    assert_xpath '//a', doc.render, 0
  end

  test 'xref creates link for unknown reference' do
    doc = document_from_string '<<tigers>>'
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', doc.render, 1
  end

  test 'xref shows label from title of target for forward and backward references in html backend' do
    input = <<-EOS
== Section A

<\<_section_b>>

== Section B

<\<_section_a>>
    EOS
    
    output = render_embedded_string input
    assert_xpath '//h2[@id="_section_a"][text()="Section A"]', output, 1
    assert_xpath '//a[@href="#_section_a"][text()="Section A"]', output, 1
    assert_xpath '//h2[@id="_section_b"][text()="Section B"]', output, 1
    assert_xpath '//a[@href="#_section_b"][text()="Section B"]', output, 1
  end

  test 'anchor creates reference' do
    doc = document_from_string "[[tigers]]Tigers roam here."
    assert_equal({'tigers' => '[tigers]'}, doc.references[:ids])
  end

  test 'anchor with label creates reference' do
    doc = document_from_string "[[tigers,Tigers]]Tigers roam here."
    assert_equal({'tigers' => 'Tigers'}, doc.references[:ids])
  end

  test 'anchor with quoted label creates reference' do
    doc = document_from_string %([["tigers","Tigers roam here"]]Tigers roam here.)
    assert_equal({'tigers' => "Tigers roam here"}, doc.references[:ids])
  end

end
