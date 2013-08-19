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

  test 'link with quoted text should not be separated into attributes when linkattrs is set' do
    assert_xpath '//a[@href="http://search.example.com"][text()="Google, Yahoo, Bing"]', render_embedded_string('http://search.example.com["Google, Yahoo, Bing"]', :attributes => {'linkattrs' => ''}), 1
  end

  test 'role and window attributes on link are processed when linkattrs is set' do
    assert_xpath '//a[@href="http://google.com"][@class="external"][@target="_blank"]', render_embedded_string('http://google.com[Google, role="external", window="_blank"]', :attributes => {'linkattrs' => ''}), 1
  end

  test 'link text that ends in ^ should set link window to _blank' do
    assert_xpath '//a[@href="http://google.com"][@target="_blank"]', render_embedded_string('http://google.com[Google^]'), 1
  end

  test 'inline irc link' do
    assert_xpath '//a[@href="irc://irc.freenode.net"][text()="irc://irc.freenode.net"]', render_embedded_string('irc://irc.freenode.net'), 1
  end

  test 'inline irc link with text' do
    assert_xpath '//a[@href="irc://irc.freenode.net"][text()="Freenode IRC"]', render_embedded_string('irc://irc.freenode.net[Freenode IRC]'), 1
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

  test 'xref using angled bracket syntax with path sans extension' do
    doc = document_from_string '<<tigers#>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html"][text() = "[tigers]"]', doc.render, 1
  end

  test 'xref using angled bracket syntax with path and extension' do
    doc = document_from_string '<<tigers.adoc#>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html"][text() = "[tigers]"]', doc.render, 1
  end

  test 'xref using angled bracket syntax with path and fragment' do
    doc = document_from_string '<<tigers#about>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html#about"][text() = "[tigers#about]"]', doc.render, 1
  end

  test 'xref using angled bracket syntax with path, fragment and text' do
    doc = document_from_string '<<tigers#about,About Tigers>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html#about"][text() = "About Tigers"]', doc.render, 1
  end

  test 'xref using angled bracket syntax with path which has been included in this document' do
    doc = document_from_string '<<tigers#about,About Tigers>>', :header_footer => false
    doc.references[:includes] << 'tigers'
    assert_xpath '//a[@href="#about"][text() = "About Tigers"]', doc.render, 1
  end

  test 'xref using angled bracket syntax with nested path which has been included in this document' do
    doc = document_from_string '<<part1/tigers#about,About Tigers>>', :header_footer => false
    doc.references[:includes] << 'part1/tigers'
    assert_xpath '//a[@href="#about"][text() = "About Tigers"]', doc.render, 1
  end

  test 'xref using angled bracket syntax inline with text' do
    assert_xpath '//a[@href="#tigers"][text() = "about tigers"]', render_string('Want to learn <<tigers,about tigers>>?'), 1
  end

  test 'xref using angled bracket syntax with multi-line label inline with text' do
    assert_xpath %{//a[@href="#tigers"][normalize-space(text()) = "about tigers"]}, render_string("Want to learn <<tigers,about\ntigers>>?"), 1
  end

  test 'xref with escaped text' do
    # when \x0 was used as boundary character for passthrough, it was getting stripped
    # now using \e as boundary character, which resolves issue
    input = 'See the <<tigers , `[tigers]`>> section for data about tigers'
    output = render_embedded_string input
    assert_xpath %(//a[@href="#tigers"]/code[text()="[tigers]"]), output, 1
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
    assert_xpath %{//a[@href="#tigers"][normalize-space(text()) = "about tigers"]}, render_string("Want to learn xref:tigers[about\ntigers]?"), 1
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
