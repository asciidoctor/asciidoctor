# frozen_string_literal: true
require_relative 'test_helper'

context 'Links' do

  test 'qualified url inline with text' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare'][text() = 'http://asciidoc.org']", convert_string("The AsciiDoc project is located at http://asciidoc.org.")
  end

  test 'qualified url with role inline with text' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare project'][text() = 'http://asciidoc.org']", convert_string("The AsciiDoc project is located at http://asciidoc.org[role=project].")
  end

  test 'qualified http url inline with hide-uri-scheme set' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare'][text() = 'asciidoc.org']", convert_string("The AsciiDoc project is located at http://asciidoc.org.", attributes: { 'hide-uri-scheme' => '' })
  end

  test 'qualified file url inline with label' do
    assert_xpath "//a[@href='file:///home/user/bookmarks.html'][text() = 'My Bookmarks']", convert_string_to_embedded('file:///home/user/bookmarks.html[My Bookmarks]')
  end

  test 'qualified file url inline with hide-uri-scheme set' do
    assert_xpath "//a[@href='file:///etc/app.conf'][text() = '/etc/app.conf']", convert_string('Edit the configuration file link:file:///etc/app.conf[]', attributes: { 'hide-uri-scheme' => '' })
  end

  test 'should not hide bare URI scheme in implicit text of link macro when hide-uri-scheme is set' do
    {
      'link:https://[]' => 'https://',
      'link:ssh://[]' => 'ssh://',
    }.each do |input, expected|
      assert_xpath %(/a[text() = "#{expected}"]), (convert_inline_string input, attributes: { 'hide-uri-scheme' => '' })
    end
  end

  test 'qualified url with label' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = 'AsciiDoc']", convert_string("We're parsing http://asciidoc.org[AsciiDoc] markup")
  end

  test 'qualified url with label containing escaped right square bracket' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = '[Ascii]Doc']", convert_string("We're parsing http://asciidoc.org[[Ascii\\]Doc] markup")
  end

  test 'qualified url with backslash label' do
    assert_xpath "//a[@href='https://google.com'][text() = 'Google for \\']", convert_string("I advise you to https://google.com[Google for +\\+]")
  end

  test 'qualified url with label using link macro' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = 'AsciiDoc']", convert_string("We're parsing link:http://asciidoc.org[AsciiDoc] markup")
  end

  test 'qualified url with role using link macro' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare project'][text() = 'http://asciidoc.org']", convert_string("We're parsing link:http://asciidoc.org[role=project] markup")
  end

  test 'qualified url using macro syntax with multi-line label inline with text' do
    assert_xpath %{//a[@href='http://asciidoc.org'][text() = 'AsciiDoc\nmarkup']}, convert_string("We're parsing link:http://asciidoc.org[AsciiDoc\nmarkup]")
  end

  test 'qualified url with label containing square brackets using link macro' do
    str = 'http://example.com[[bracket1\]]'
    doc = document_from_string str, standalone: false, doctype: 'inline'
    assert_match '<a href="http://example.com">[bracket1]</a>', doc.convert, 1
    doc = document_from_string str, standalone: false, backend: 'docbook', doctype: 'inline'
    assert_match '<link xl:href="http://example.com">[bracket1]</link>', doc.convert, 1
  end

  test 'link macro with empty target' do
    input = 'Link to link:[this page].'
    output = convert_string_to_embedded input
    assert_xpath '//a', output, 1
    assert_xpath '//a[@href=""]', output, 1
  end

  test 'should not recognize link macro with double colons' do
    input = 'The link::http://example.org[example domain] is reserved for tests and documentation.'
    output = convert_string_to_embedded input
    assert_includes output, 'link::http://example.org[example domain]'
  end

  test 'qualified url surrounded by angled brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="http://asciidoc.org"]', convert_string('<http://asciidoc.org> is the project page for AsciiDoc.'), 1
  end

  test 'qualified url surrounded by round brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="http://asciidoc.org"]', convert_string('(http://asciidoc.org) is the project page for AsciiDoc.'), 1
  end

  test 'qualified url with trailing period' do
    result = convert_string_to_embedded 'The homepage for Asciidoctor is https://asciidoctor.org.'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,".")]', result, 1
  end

  test 'qualified url with trailing explanation point' do
    result = convert_string_to_embedded 'Check out https://asciidoctor.org!'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,"!")]', result, 1
  end

  test 'qualified url with trailing question mark' do
    result = convert_string_to_embedded 'Is the homepage for Asciidoctor https://asciidoctor.org?'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,"?")]', result, 1
  end

  test 'qualified url with trailing round bracket' do
    result = convert_string_to_embedded 'Asciidoctor is a Ruby-based AsciiDoc processor (see https://asciidoctor.org)'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,")")]', result, 1
  end

  test 'qualified url with trailing period followed by round bracket' do
    result = convert_string_to_embedded '(The homepage for Asciidoctor is https://asciidoctor.org.)'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,".)")]', result, 1
  end

  test 'qualified url with trailing exclamation point followed by round bracket' do
    result = convert_string_to_embedded '(Check out https://asciidoctor.org!)'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,"!)")]', result, 1
  end

  test 'qualified url with trailing question mark followed by round bracket' do
    result = convert_string_to_embedded '(Is the homepage for Asciidoctor https://asciidoctor.org?)'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,"?)")]', result, 1
  end

  test 'qualified url with trailing semi-colon' do
    result = convert_string_to_embedded 'https://asciidoctor.org; where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,";")]', result, 1
  end

  test 'qualified url with trailing colon' do
    result = convert_string_to_embedded 'https://asciidoctor.org: where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,":")]', result, 1
  end

  test 'qualified url in round brackets with trailing colon' do
    result = convert_string_to_embedded '(https://asciidoctor.org): where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(.,"):")]', result, 1
  end

  test 'qualified url with trailing round bracket followed by colon' do
    result = convert_string_to_embedded '(from https://asciidoctor.org): where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(., "):")]', result, 1
  end

  test 'qualified url in round brackets with trailing semi-colon' do
    result = convert_string_to_embedded '(https://asciidoctor.org); where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(., ");")]', result, 1
  end

  test 'qualified url with trailing round bracket followed by semi-colon' do
    result = convert_string_to_embedded '(from https://asciidoctor.org); where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[starts-with(., ");")]', result, 1
  end

  test 'URI scheme with trailing characters should not be converted to a link' do
    input_sources = %w(
      (https://)
      http://;
      file://:
      <ftp://>
    )
    expected_outputs = %w(
      (https://)
      http://;
      file://:
      &lt;ftp://&gt;
    )
    input_sources.each_with_index do |input_source, i|
      expected_output = expected_outputs[i]
      actual = block_from_string input_source
      assert_equal expected_output, actual.content
    end
  end

  test 'qualified url containing round brackets' do
    assert_xpath '//a[@href="http://jruby.org/apidocs/org/jruby/Ruby.html#addModule(org.jruby.RubyModule)"][text()="addModule() adds a Ruby module"]', convert_string('http://jruby.org/apidocs/org/jruby/Ruby.html#addModule(org.jruby.RubyModule)[addModule() adds a Ruby module]'), 1
  end

  test 'qualified url adjacent to text in square brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', convert_string(']http://asciidoc.org[AsciiDoc] project page.'), 1
  end

  test 'qualified url adjacent to text in round brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', convert_string(')http://asciidoc.org[AsciiDoc] project page.'), 1
  end

  test 'qualified url following no-break space' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', convert_string(%(#{[0xa0].pack 'U1'}http://asciidoc.org[AsciiDoc] project page.)), 1
  end

  test 'qualified url following smart apostrophe' do
    output = convert_string_to_embedded("l&#8217;http://www.irit.fr[IRIT]")
    assert_match(/l&#8217;<a href=/, output)
  end

  test 'should convert qualified url as macro enclosed in double quotes' do
    output = convert_string_to_embedded('"https://asciidoctor.org[]"')
    assert_include '"<a href="https://asciidoctor.org" class="bare">https://asciidoctor.org</a>"', output
  end

  test 'should convert qualified url as macro enclosed in single quotes' do
    output = convert_string_to_embedded('\'https://asciidoctor.org[]\'')
    assert_include '\'<a href="https://asciidoctor.org" class="bare">https://asciidoctor.org</a>\'', output
  end

  test 'qualified url using invalid link macro should not create link' do
    assert_xpath '//a', convert_string('link:http://asciidoc.org is the project page for AsciiDoc.'), 0
  end

  test 'escaped inline qualified url should not create link' do
    assert_xpath '//a', convert_string('\http://asciidoc.org is the project page for AsciiDoc.'), 0
  end

  test 'url in link macro with at (@) sign should not create mailto link' do
    assert_xpath '//a[@href="http://xircles.codehaus.org/lists/dev@geb.codehaus.org"][text()="subscribe"]', convert_string('http://xircles.codehaus.org/lists/dev@geb.codehaus.org[subscribe]')
  end

  test 'implicit url with at (@) sign should not create mailto link' do
    assert_xpath '//a[@href="http://xircles.codehaus.org/lists/dev@geb.codehaus.org"][text()="http://xircles.codehaus.org/lists/dev@geb.codehaus.org"]', convert_string('http://xircles.codehaus.org/lists/dev@geb.codehaus.org')
  end

  test 'escaped inline qualified url using macro syntax should not create link' do
    assert_xpath '//a', convert_string('\http://asciidoc.org[AsciiDoc] is the key to good docs.'), 0
  end

  test 'inline qualified url followed by a newline should not include newline in link' do
    assert_xpath '//a[@href="https://github.com/asciidoctor"]', convert_string("The source code for Asciidoctor can be found at https://github.com/asciidoctor\nwhich is a GitHub organization."), 1
  end

  test 'qualified url divided by newline using macro syntax should not create link' do
    assert_xpath '//a', convert_string("The source code for Asciidoctor can be found at link:https://github.com/asciidoctor\n[]which is a GitHub organization."), 0
  end

  test 'qualified url containing whitespace using macro syntax should not create link' do
    assert_xpath '//a', convert_string('I often need to refer to the chapter on link:http://asciidoc.org?q=attribute references[Attribute References].'), 0
  end

  test 'qualified url containing an encoded space using macro syntax should create a link' do
    assert_xpath '//a', convert_string('I often need to refer to the chapter on link:http://asciidoc.org?q=attribute%20references[Attribute References].'), 1
  end

  test 'inline quoted qualified url should not consume surrounding angled brackets' do
    assert_xpath '//a[@href="https://github.com/asciidoctor"]', convert_string('Asciidoctor GitHub organization: <**https://github.com/asciidoctor**>'), 1
  end

  test 'link with quoted text should not be separated into attributes when text contains an equal sign' do
    assert_xpath '//a[@href="http://search.example.com"][text()="Google, Yahoo, Bing = Search Engines"]', convert_string_to_embedded('http://search.example.com["Google, Yahoo, Bing = Search Engines"]'), 1
  end

  test 'should leave link text as is if it contains an equals sign but no attributes are found' do
    assert_xpath %(//a[@href="https://example.com"][text()="What You Need\n= What You Get"]), convert_string_to_embedded(%(https://example.com[What You Need\n= What You Get])), 1
  end

  test 'link with quoted text but no equal sign should carry quotes over to output' do
    assert_xpath %(//a[@href="http://search.example.com"][text()='"Google, Yahoo, Bing"']), convert_string_to_embedded('http://search.example.com["Google, Yahoo, Bing"]'), 1
  end

  test 'link with comma in text but no equal sign should not be separated into attributes' do
    assert_xpath '//a[@href="http://search.example.com"][text()="Google, Yahoo, Bing"]', convert_string_to_embedded('http://search.example.com[Google, Yahoo, Bing]'), 1
  end

  test 'link with formatted wrapped text should not be separated into attributes' do
    result = convert_string_to_embedded %(https://example.com[[.role]#Foo\nBar#])
    assert_include %(<a href="https://example.com"><span class="role">Foo\nBar</span></a>), result
  end

  test 'should process role and window attributes on link' do
    assert_xpath '//a[@href="http://google.com"][@class="external"][@target="_blank"]', convert_string_to_embedded('http://google.com[Google, role=external, window="_blank"]'), 1
  end

  test 'should parse link with wrapped text that includes attributes' do
    result = convert_string_to_embedded %(https://example.com[Foo\nBar,role=foobar])
    assert_include %(<a href="https://example.com" class="foobar">Foo Bar</a>), result
  end

  test 'link macro with attributes but no text should use URL as text' do
    url = 'https://fonts.googleapis.com/css?family=Roboto:400,400italic,'
    assert_xpath %(//a[@href="#{url}"][text()="#{url}"]), convert_string_to_embedded(%(link:#{url}[family=Roboto,weight=400])), 1
  end

  test 'link macro with attributes but blank text should use URL as text' do
    url = 'https://fonts.googleapis.com/css?family=Roboto:400,400italic,'
    assert_xpath %(//a[@href="#{url}"][text()="#{url}"]), convert_string_to_embedded(%(link:#{url}[,family=Roboto,weight=400])), 1
  end

  test 'link macro with comma but no explicit attributes in text should not parse text' do
    url = 'https://fonts.googleapis.com/css?family=Roboto:400,400italic,'
    assert_xpath %(//a[@href="#{url}"][text()="Roboto,400"]), convert_string_to_embedded(%(link:#{url}[Roboto,400])), 1
  end

  test 'link macro should support id and role attributes' do
    url = 'https://fonts.googleapis.com/css?family=Roboto:400'
    assert_xpath %(//a[@href="#{url}"][@id="roboto-regular"][@class="bare font"][text()="#{url}"]), convert_string_to_embedded(%(link:#{url}[,id=roboto-regular,role=font])), 1
  end

  test 'link text that ends in ^ should set link window to _blank' do
    assert_xpath '//a[@href="http://google.com"][@target="_blank"]', convert_string_to_embedded('http://google.com[Google^]'), 1
  end

  test 'rel=noopener should be added to a link that targets the _blank window' do
    assert_xpath '//a[@href="http://google.com"][@target="_blank"][@rel="noopener"]', convert_string_to_embedded('http://google.com[Google^]'), 1
  end

  test 'rel=noopener should be added to a link that targets a named window when the noopener option is set' do
    assert_xpath '//a[@href="http://google.com"][@target="name"][@rel="noopener"]', convert_string_to_embedded('http://google.com[Google,window=name,opts=noopener]'), 1
  end

  test 'rel=noopener should not be added to a link if it does not target a window' do
    result = convert_string_to_embedded 'http://google.com[Google,opts=noopener]'
    assert_xpath '//a[@href="http://google.com"]', result, 1
    assert_xpath '//a[@href="http://google.com"][@rel="noopener"]', result, 0
  end

  test 'rel=nofollow should be added to a link when the nofollow option is set' do
    assert_xpath '//a[@href="http://google.com"][@target="name"][@rel="nofollow noopener"]', convert_string_to_embedded('http://google.com[Google,window=name,opts="nofollow,noopener"]'), 1
  end

  test 'id attribute on link is processed' do
    assert_xpath '//a[@href="http://google.com"][@id="link-1"]', convert_string_to_embedded('http://google.com[Google, id="link-1"]'), 1
  end

  test 'title attribute on link is processed' do
    assert_xpath '//a[@href="http://google.com"][@title="title-1"]', convert_string_to_embedded('http://google.com[Google, title="title-1"]'), 1
  end

  test 'inline irc link' do
    assert_xpath '//a[@href="irc://irc.freenode.net"][text()="irc://irc.freenode.net"]', convert_string_to_embedded('irc://irc.freenode.net'), 1
  end

  test 'inline irc link with text' do
    assert_xpath '//a[@href="irc://irc.freenode.net"][text()="Freenode IRC"]', convert_string_to_embedded('irc://irc.freenode.net[Freenode IRC]'), 1
  end

  test 'inline ref' do
    variations = %w([[tigers]] anchor:tigers[])
    variations.each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor})
      output = doc.convert
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_nil doc.catalog[:refs]['tigers'].text
      assert_xpath '//a[@id="tigers"]', output, 1
      assert_xpath '//a[@id="tigers"]/child::text()', output, 0
    end
  end

  test 'escaped inline ref' do
    variations = %w([[tigers]] anchor:tigers[])
    variations.each do |anchor|
      doc = document_from_string %(Here you can read about tigers.\\#{anchor})
      output = doc.convert
      refute doc.catalog[:refs].key?('tigers')
      assert_xpath '//a[@id="tigers"]', output, 0
    end
  end

  test 'inline ref can start with colon' do
    input = '[[:idname]] text'
    output = convert_string_to_embedded input
    assert_xpath '//a[@id=":idname"]', output, 1
  end

  test 'inline ref cannot start with digit' do
    input = '[[1-install]] text'
    output = convert_string_to_embedded input
    assert_includes output, '[[1-install]]'
    assert_xpath '//a[@id = "1-install"]', output, 0
  end

  test 'inline ref with reftext' do
    %w([[tigers,Tigers]] anchor:tigers[Tigers]).each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor})
      output = doc.convert
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_equal 'Tigers', doc.catalog[:refs]['tigers'].text
      assert_xpath '//a[@id="tigers"]', output, 1
      assert_xpath '//a[@id="tigers"]/child::text()', output, 0
    end
  end

  test 'should encode double quotes in reftext of anchor macro in DocBook output' do
    input = 'anchor:uncola[the "un"-cola]'
    result = convert_inline_string input, backend: :docbook
    assert_equal '<anchor xml:id="uncola" xreflabel="the &quot;un&quot;-cola"/>', result
  end

  test 'should substitute attribute references in reftext when registering inline ref' do
    %w([[tigers,{label-tigers}]] anchor:tigers[{label-tigers}]).each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor}), attributes: { 'label-tigers' => 'Tigers' }
      doc.convert
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_equal 'Tigers', doc.catalog[:refs]['tigers'].text
    end
  end

  test 'inline ref with reftext converted to DocBook' do
    %w([[tigers,<Tigers>]] anchor:tigers[<Tigers>]).each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor}), backend: :docbook
      output = doc.convert standalone: false
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_equal '<Tigers>', doc.catalog[:refs]['tigers'].text
      assert_includes output, '<anchor xml:id="tigers" xreflabel="&lt;Tigers&gt;"/>'
    end
  end

  test 'does not match bibliography anchor in prose when scanning for inline anchor' do
    doc = document_from_string 'Use [[[label]]] to assign a label to a bibliography entry.'
    refute doc.catalog[:refs].key? 'label'
  end

  test 'repeating inline anchor macro with empty reftext' do
    input = 'anchor:one[] anchor:two[] anchor:three[]'
    result = convert_inline_string input
    assert_equal '<a id="one"></a> <a id="two"></a> <a id="three"></a>', result
  end

  test 'mixed inline anchor macro and anchor shorthand with empty reftext' do
    input = 'anchor:one[][[two]]anchor:three[][[four]]anchor:five[]'
    result = convert_inline_string input
    assert_equal '<a id="one"></a><a id="two"></a><a id="three"></a><a id="four"></a><a id="five"></a>', result
  end

  test 'assigns xreflabel value for anchor macro without reftext in DocBook output' do
    ['anchor:foo[]bar', '[[foo]]bar'].each do |input|
      result = convert_inline_string input, backend: :docbook
      assert_equal '<anchor xml:id="foo" xreflabel="[foo]"/>bar', result
    end
  end

  test 'unescapes square bracket in reftext of anchor macro' do
    input = <<~'EOS'
    see <<foo>>

    anchor:foo[b[a\]r]tex
    EOS
    result = convert_string_to_embedded input
    assert_includes result, 'see <a href="#foo">b[a]r</a>'
  end

  test 'unescapes square bracket in reftext of anchor macro in DocBook output' do
    input = 'anchor:foo[b[a\]r]'
    result = convert_inline_string input, backend: :docbook
    assert_equal '<anchor xml:id="foo" xreflabel="b[a]r"/>', result
  end

  test 'xref using angled bracket syntax' do
    doc = document_from_string '<<tigers>>'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, '[tigers]', type: :ref, target: 'tigers'), '[tigers]']
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with explicit hash' do
    doc = document_from_string '<<#tigers>>'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, 'Tigers', type: :ref, target: 'tigers'), 'Tigers']
    assert_xpath '//a[@href="#tigers"][text() = "Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with label' do
    input = <<~'EOS'
    <<tigers,About Tigers>>

    [#tigers]
    == Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "About Tigers"]', convert_string(input), 1
  end

  test 'xref should use title of target as link text when no explicit reftext is specified' do
    input = <<~'EOS'
    <<tigers>>

    [#tigers]
    == Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "Tigers"]', convert_string(input), 1
  end

  test 'xref should use title of target as link text when explicit link text is empty' do
    input = <<~'EOS'
    <<tigers,>>

    [#tigers]
    == Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "Tigers"]', convert_string(input), 1
  end

  test 'xref using angled bracket syntax with quoted label' do
    input = <<~'EOS'
    <<tigers,"About Tigers">>

    [#tigers]
    == Tigers
    EOS
    assert_xpath %q(//a[@href="#tigers"][text() = '"About Tigers"']), convert_string(input), 1
  end

  test 'should not interpret path sans extension in xref with angled bracket syntax in compat mode' do
    using_memory_logger do |logger|
      doc = document_from_string '<<tigers#>>', standalone: false, attributes: { 'compat-mode' => '' }
      assert_xpath '//a[@href="#tigers#"][text() = "[tigers#]"]', doc.convert, 1
    end
  end

  test 'xref using angled bracket syntax with path sans extension' do
    doc = document_from_string '<<tigers#>>', standalone: false
    assert_xpath '//a[@href="tigers.html"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'inter-document xref shorthand syntax should assume AsciiDoc extension if AsciiDoc extension not present' do
    {
      'using-.net-web-services#' => 'Using .NET web services',
      'asciidoctor.1#' => 'Asciidoctor Manual',
      'path/to/document#' => 'Document Title',
    }.each do |target, text|
      result = convert_string_to_embedded %(<<#{target},#{text}>>)
      assert_xpath %(//a[@href="#{target.chop}.html"][text()="#{text}"]), result, 1
    end
  end

  test 'xref macro with explicit inter-document target should assume implicit AsciiDoc file extension if no file extension is present' do
    {
      'using-.net-web-services#' => 'Using .NET web services',
      'asciidoctor.1#' => 'Asciidoctor Manual',
    }.each do |target, text|
      result = convert_string_to_embedded %(xref:#{target}[#{text}])
      assert_xpath %(//a[@href="#{target.chop}"][text()="#{text}"]), result, 1
    end
    {
      'document#' => 'Document Title',
      'path/to/document#' => 'Document Title',
      'include.d/document#' => 'Document Title',
    }.each do |target, text|
      result = convert_string_to_embedded %(xref:#{target}[#{text}])
      assert_xpath %(//a[@href="#{target.chop}.html"][text()="#{text}"]), result, 1
    end
  end

  test 'xref macro with implicit inter-document target should preserve path with file extension' do
    {
      'refcard.pdf' => 'Refcard',
      'asciidoctor.1' => 'Asciidoctor Manual',
    }.each do |path, text|
      result = convert_string_to_embedded %(xref:#{path}[#{text}])
      assert_xpath %(//a[@href="#{path}"][text()="#{text}"]), result, 1
    end
    {
      'sections.d/first' => 'First Section',
    }.each do |path, text|
      result = convert_string_to_embedded %(xref:#{path}[#{text}])
      assert_xpath %(//a[@href="##{path}"][text()="#{text}"]), result, 1
    end
  end

  test 'inter-document xref should only remove the file extension part if the path contains a period elsewhere' do
    result = convert_string_to_embedded '<<using-.net-web-services.adoc#,Using .NET web services>>'
    assert_xpath '//a[@href="using-.net-web-services.html"][text() = "Using .NET web services"]', result, 1
  end

  test 'xref macro target containing dot should be interpreted as a path unless prefixed by #' do
    result = convert_string_to_embedded 'xref:using-.net-web-services[Using .NET web services]'
    assert_xpath '//a[@href="using-.net-web-services"][text() = "Using .NET web services"]', result, 1
    result = convert_string_to_embedded 'xref:#using-.net-web-services[Using .NET web services]'
    assert_xpath '//a[@href="#using-.net-web-services"][text() = "Using .NET web services"]', result, 1
  end

  test 'should not interpret double underscore in target of xref macro if sequence is preceded by a backslash' do
    result = convert_string_to_embedded 'xref:doc\__with_double__underscore.adoc[text]'
    assert_xpath '//a[@href="doc__with_double__underscore.html"][text() = "text"]', result, 1
  end

  test 'should not interpret double underscore in target of xref shorthand if sequence is preceded by a backslash' do
    result = convert_string_to_embedded '<<doc\__with_double__underscore.adoc#,text>>'
    assert_xpath '//a[@href="doc__with_double__underscore.html"][text() = "text"]', result, 1
  end

  test 'xref using angled bracket syntax with path sans extension using docbook backend' do
    doc = document_from_string '<<tigers#>>', standalone: false, backend: 'docbook'
    assert_match '<link xl:href="tigers.xml">tigers.xml</link>', doc.convert, 1
  end

  test 'xref using angled bracket syntax with ancestor path sans extension' do
    doc = document_from_string '<<../tigers#,tigers>>', standalone: false
    assert_xpath '//a[@href="../tigers.html"][text() = "tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with absolute path sans extension' do
    doc = document_from_string '<</path/to/tigers#,tigers>>', standalone: false
    assert_xpath '//a[@href="/path/to/tigers.html"][text() = "tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and extension' do
    using_memory_logger do |logger|
      doc = document_from_string '<<tigers.adoc>>', standalone: false
      assert_xpath '//a[@href="#tigers.adoc"][text() = "[tigers.adoc]"]', doc.convert, 1
    end
  end

  test 'xref using angled bracket syntax with path and extension with hash' do
    doc = document_from_string '<<tigers.adoc#>>', standalone: false
    assert_xpath '//a[@href="tigers.html"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and extension with fragment' do
    doc = document_from_string '<<tigers.adoc#id>>', standalone: false
    assert_xpath '//a[@href="tigers.html#id"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using macro syntax with path and extension in compat mode' do
    using_memory_logger do |logger|
      doc = document_from_string 'xref:tigers.adoc[]', standalone: false, attributes: { 'compat-mode' => '' }
      assert_xpath '//a[@href="#tigers.adoc"][text() = "[tigers.adoc]"]', doc.convert, 1
    end
  end

  test 'xref using macro syntax with path and extension' do
    doc = document_from_string 'xref:tigers.adoc[]', standalone: false
    assert_xpath '//a[@href="tigers.html"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and fragment' do
    doc = document_from_string '<<tigers#about>>', standalone: false
    assert_xpath '//a[@href="tigers.html#about"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path, fragment and text' do
    doc = document_from_string '<<tigers#about,About Tigers>>', standalone: false
    assert_xpath '//a[@href="tigers.html#about"][text() = "About Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and custom relfilesuffix and outfilesuffix' do
    attributes = { 'relfileprefix' => '../', 'outfilesuffix' => '/' }
    doc = document_from_string '<<tigers#about,About Tigers>>', standalone: false, attributes: attributes
    assert_xpath '//a[@href="../tigers/#about"][text() = "About Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and custom relfilesuffix' do
    attributes = { 'relfilesuffix' => '/' }
    doc = document_from_string '<<tigers#about,About Tigers>>', standalone: false, attributes: attributes
    assert_xpath '//a[@href="tigers/#about"][text() = "About Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path which has been included in this document' do
    using_memory_logger do |logger|
      in_verbose_mode do
        doc = document_from_string '<<tigers#about,About Tigers>>', standalone: false
        doc.catalog[:includes]['tigers'] = true
        output = doc.convert
        assert_xpath '//a[@href="#about"][text() = "About Tigers"]', output, 1
        assert_message logger, :INFO, 'possible invalid reference: about'
      end
    end
  end

  test 'xref using angled bracket syntax with nested path which has been included in this document' do
    using_memory_logger do |logger|
      in_verbose_mode do
        doc = document_from_string '<<part1/tigers#about,About Tigers>>', standalone: false
        doc.catalog[:includes]['part1/tigers'] = true
        output = doc.convert
        assert_xpath '//a[@href="#about"][text() = "About Tigers"]', output, 1
        assert_message logger, :INFO, 'possible invalid reference: about'
      end
    end
  end

  test 'xref using angled bracket syntax inline with text' do
    input = <<~'EOS'
    Want to learn <<tigers,about tigers>>?

    [#tigers]
    == Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "about tigers"]', convert_string(input), 1
  end

  test 'xref using angled bracket syntax with multi-line label inline with text' do
    input = <<~'EOS'
    Want to learn <<tigers,about
    tigers>>?

    [#tigers]
    == Tigers
    EOS
    assert_xpath %{//a[@href="#tigers"][normalize-space(text()) = "about tigers"]}, convert_string(input), 1
  end

  test 'xref with escaped text' do
    # when \x0 was used as boundary character for passthrough, it was getting stripped
    # now using unicode marks as boundary characters, which resolves issue
    input = <<~'EOS'
    See the <<tigers, `+[tigers]+`>> section for details about tigers.

    [#tigers]
    == Tigers
    EOS
    output = convert_string_to_embedded input
    assert_xpath %(//a[@href="#tigers"]/code[text()="[tigers]"]), output, 1
  end

  test 'xref with target that begins with attribute reference in title' do
    ['<<{lessonsdir}/lesson-1#,Lesson 1>>', 'xref:{lessonsdir}/lesson-1.adoc[Lesson 1]'].each do |xref|
      input = <<~EOS
      :lessonsdir: lessons

      [#lesson-1-listing]
      == #{xref}

      A summary of the first lesson.
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//h2/a[@href="lessons/lesson-1.html"]', output, 1
    end
  end

  test 'xref using macro syntax' do
    doc = document_from_string 'xref:tigers[]'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, '[tigers]', type: :ref, target: 'tigers'), '[tigers]']
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', doc.convert, 1
  end

  test 'multiple xref macros with implicit text in single line' do
    input = <<~'EOS'
    This document has two sections, xref:sect-a[] and xref:sect-b[].

    [#sect-a]
    == Section A

    [#sect-b]
    == Section B
    EOS
    result = convert_string_to_embedded input
    assert_xpath '//a[@href="#sect-a"][text() = "Section A"]', result, 1
    assert_xpath '//a[@href="#sect-b"][text() = "Section B"]', result, 1
  end

  test 'xref using macro syntax with explicit hash' do
    doc = document_from_string 'xref:#tigers[]'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, 'Tigers', type: :ref, target: 'tigers'), 'Tigers']
    assert_xpath '//a[@href="#tigers"][text() = "Tigers"]', doc.convert, 1
  end

  test 'xref using macro syntax with label' do
    input = <<~'EOS'
    xref:tigers[About Tigers]

    [#tigers]
    == Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "About Tigers"]', convert_string(input), 1
  end

  test 'xref using macro syntax inline with text' do
    input = <<~'EOS'
    Want to learn xref:tigers[about tigers]?

    [#tigers]
    == Tigers
    EOS

    assert_xpath '//a[@href="#tigers"][text() = "about tigers"]', convert_string(input), 1
  end

  test 'xref using macro syntax with multi-line label inline with text' do
    input = <<~'EOS'
    Want to learn xref:tigers[about
    tigers]?

    [#tigers]
    == Tigers
    EOS
    assert_xpath %{//a[@href="#tigers"][normalize-space(text()) = "about tigers"]}, convert_string(input), 1
  end

  test 'xref using macro syntax with text that ends with an escaped closing bracket' do
    input = <<~'EOS'
    xref:tigers[[tigers\]]

    [#tigers]
    == Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', convert_string_to_embedded(input), 1
  end

  test 'xref using macro syntax with text that contains an escaped closing bracket' do
    input = <<~'EOS'
    xref:tigers[[tigers\] are cats]

    [#tigers]
    == Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "[tigers] are cats"]', convert_string_to_embedded(input), 1
  end

  test 'unescapes square bracket in reftext used by xref' do
    input = <<~'EOS'
    anchor:foo[b[a\]r]about

    see <<foo>>
    EOS
    result = convert_string_to_embedded input
    assert_xpath '//a[@href="#foo"]', result, 1
    assert_xpath '//a[@href="#foo"][text()="b[a]r"]', result, 1
  end

  test 'xref using invalid macro syntax does not create link' do
    doc = document_from_string 'xref:tigers'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, 'Tigers', type: :ref, target: 'tigers'), 'Tigers']
    assert_xpath '//a', doc.convert, 0
  end

  test 'should warn and create link if verbose flag is set and reference is not found' do
    input = <<~'EOS'
    [#foobar]
    == Foobar

    == Section B

    See <<foobaz>>.
    EOS
    using_memory_logger do |logger|
      in_verbose_mode do
        output = convert_string_to_embedded input
        assert_xpath '//a[@href="#foobaz"][text() = "[foobaz]"]', output, 1
        assert_message logger, :INFO, 'possible invalid reference: foobaz'
      end
    end
  end

  test 'should not warn if verbose flag is set and reference is found in compat mode' do
    input = <<~'EOS'
    [[foobar]]
    == Foobar

    == Section B

    See <<foobar>>.
    EOS
    using_memory_logger do |logger|
      in_verbose_mode do
        output = convert_string_to_embedded input, attributes: { 'compat-mode' => '' }
        assert_xpath '//a[@href="#foobar"][text() = "Foobar"]', output, 1
        assert_empty logger
      end
    end
  end

  test 'should warn and create link if verbose flag is set and reference using # notation is not found' do
    input = <<~'EOS'
    [#foobar]
    == Foobar

    == Section B

    See <<#foobaz>>.
    EOS
    using_memory_logger do |logger|
      in_verbose_mode do
        output = convert_string_to_embedded input
        assert_xpath '//a[@href="#foobaz"][text() = "[foobaz]"]', output, 1
        assert_message logger, :INFO, 'possible invalid reference: foobaz'
      end
    end
  end

  test 'should produce an internal anchor from an inter-document xref to file included into current file' do
    input = <<~'EOS'
    = Book Title
    :doctype: book

    [#ch1]
    == Chapter 1

    So it begins.

    Read <<other-chapters.adoc#ch2>> to find out what happens next!

    include::other-chapters.adoc[]
    EOS

    doc = document_from_string input, safe: :safe, base_dir: fixturedir
    assert doc.catalog[:includes].key?('other-chapters')
    assert doc.catalog[:includes]['other-chapters']
    output = doc.convert
    assert_xpath '//a[@href="#ch2"][text()="Chapter 2"]', output, 1
  end

  test 'should produce an internal anchor from an inter-document xref to file included entirely into current file using tags' do
    input = <<~'EOS'
    = Book Title
    :doctype: book

    [#ch1]
    == Chapter 1

    So it begins.

    Read <<other-chapters.adoc#ch2>> to find out what happens next!

    include::other-chapters.adoc[tags=**]
    EOS

    output = convert_string_to_embedded input, safe: :safe, base_dir: fixturedir
    assert_xpath '//a[@href="#ch2"][text()="Chapter 2"]', output, 1
  end

  test 'should not produce an internal anchor for inter-document xref to file partially included into current file' do
    input = <<~'EOS'
    = Book Title
    :doctype: book

    [#ch1]
    == Chapter 1

    So it begins.

    Read <<other-chapters.adoc#ch2,the next chapter>> to find out what happens next!

    include::other-chapters.adoc[tags=ch2]
    EOS

    doc = document_from_string input, safe: :safe, base_dir: fixturedir
    assert doc.catalog[:includes].key?('other-chapters')
    refute doc.catalog[:includes]['other-chapters']
    output = doc.convert
    assert_xpath '//a[@href="other-chapters.html#ch2"][text()="the next chapter"]', output, 1
  end

  test 'should warn and create link if debug mode is enabled, inter-document xref points to current doc, and reference not found' do
    input = <<~'EOS'
    [#foobar]
    == Foobar

    == Section B

    See <<test.adoc#foobaz>>.
    EOS
    using_memory_logger do |logger|
      in_verbose_mode do
        output = convert_string_to_embedded input, attributes: { 'docname' => 'test' }
        assert_xpath '//a[@href="#foobaz"][text() = "[foobaz]"]', output, 1
        assert_message logger, :INFO, 'possible invalid reference: foobaz'
      end
    end
  end

  test 'should use doctitle as fallback link text if inter-document xref points to current doc and no link text is provided' do
    input = <<~'EOS'
    = Links & Stuff at https://example.org

    See xref:test.adoc[]
    EOS
    output = convert_string_to_embedded input, attributes: { 'docname' => 'test' }
    assert_include '<a href="#">Links &amp; Stuff at https://example.org</a>', output
  end

  test 'should use doctitle of root document as fallback link text for inter-document xref in AsciiDoc table cell that resolves to current doc' do
    input = <<~'EOS'
    = Document Title

    |===
    a|See xref:test.adoc[]
    |===
    EOS
    output = convert_string_to_embedded input, attributes: { 'docname' => 'test' }
    assert_include '<a href="#">Document Title</a>', output
  end

  test 'should use reftext on document as fallback link text if inter-document xref points to current doc and no link text is provided' do
    input = <<~'EOS'
    [reftext="Links and Stuff"]
    = Links & Stuff

    See xref:test.adoc[]
    EOS
    output = convert_string_to_embedded input, attributes: { 'docname' => 'test' }
    assert_include '<a href="#">Links and Stuff</a>', output
  end

  test 'should use reftext on document as fallback link text if xref points to empty fragment and no link text is provided' do
    input = <<~'EOS'
    [reftext="Links and Stuff"]
    = Links & Stuff

    See xref:#[]
    EOS
    output = convert_string_to_embedded input, attributes: { 'docname' => 'test' }
    assert_include '<a href="#">Links and Stuff</a>', output
  end

  test 'should use fallback link text if inter-document xref points to current doc without header and no link text is provided' do
    input = <<~'EOS'
    See xref:test.adoc[]
    EOS
    output = convert_string_to_embedded input, attributes: { 'docname' => 'test' }
    assert_include '<a href="#">[^top]</a>', output
  end

  test 'should use fallback link text if fragment of internal xref is empty and no link text is provided' do
    input = <<~'EOS'
    See xref:#[]
    EOS
    output = convert_string_to_embedded input, attributes: { 'docname' => 'test' }
    assert_include '<a href="#">[^top]</a>', output
  end

  test 'should use document id as linkend for self xref in DocBook backend' do
    input = <<~'EOS'
    [#docid]
    = Document Title

    See xref:test.adoc[]
    EOS
    output = convert_string_to_embedded input, backend: :docbook, attributes: { 'docname' => 'test' }
    assert_include '<xref linkend="docid"/>', output
  end

  test 'should auto-generate document id to use as linkend for self xref in DocBook backend' do
    input = <<~'EOS'
    = Document Title

    See xref:test.adoc[]
    EOS
    doc = document_from_string input, backend: :docbook, attributes: { 'docname' => 'test' }
    assert_nil doc.id
    output = doc.convert
    assert_nil doc.id
    assert_include ' xml:id="__article-root__"', output
    assert_include '<xref linkend="__article-root__"/>', output
  end

  test 'should produce an internal anchor for inter-document xref to file outside of base directory' do
    input = <<~'EOS'
    = Document Title

    See <<../section-a.adoc#section-a>>.

    include::../section-a.adoc[]
    EOS

    doc = document_from_string input, safe: :unsafe, base_dir: (File.join fixturedir, 'subdir')
    assert_includes doc.catalog[:includes], '../section-a'
    output = doc.convert standalone: false
    assert_xpath '//a[@href="#section-a"][text()="Section A"]', output, 1
  end

  test 'xref uses title of target as label for forward and backward references in html output' do
    input = <<~'EOS'
    == Section A

    <<_section_b>>

    == Section B

    <<_section_a>>
    EOS

    output = convert_string_to_embedded input
    assert_xpath '//h2[@id="_section_a"][text()="Section A"]', output, 1
    assert_xpath '//a[@href="#_section_a"][text()="Section A"]', output, 1
    assert_xpath '//h2[@id="_section_b"][text()="Section B"]', output, 1
    assert_xpath '//a[@href="#_section_b"][text()="Section B"]', output, 1
  end

  test 'should not fail to resolve broken xref in title of block with ID' do
    input = <<~'EOS'
    [#p1]
    .<<DNE>>
    paragraph text
    EOS

    output = convert_string_to_embedded input
    assert_xpath '//*[@class="title"]/a[@href="#DNE"][text()="[DNE]"]', output, 1
  end

  test 'should resolve forward xref in title of block with ID' do
    input = <<~'EOS'
    [#p1]
    .<<conclusion>>
    paragraph text

    [#conclusion]
    == Conclusion
    EOS

    output = convert_string_to_embedded input
    assert_xpath '//*[@class="title"]/a[@href="#conclusion"][text()="Conclusion"]', output, 1
  end

  test 'should not fail to resolve broken xref in section title' do
    input = <<~'EOS'
    [#s1]
    == <<DNE>>

    == <<s1>>
    EOS

    output = convert_string_to_embedded input
    assert_xpath '//h2[@id="s1"]/a[@href="#DNE"][text()="[DNE]"]', output, 1
    assert_xpath '//h2/a[@href="#s1"][text()="[DNE]"]', output, 1
  end

  test 'should break circular xref reference in section title' do
    input = <<~'EOS'
    [#a]
    == A <<b>>

    [#b]
    == B <<a>>
    EOS

    output = convert_string_to_embedded input
    assert_includes output, '<h2 id="a">A <a href="#b">B [a]</a></h2>'
    assert_includes output, '<h2 id="b">B <a href="#a">[a]</a></h2>'
  end

  test 'should drop nested anchor in xreftext' do
    input = <<~'EOS'
    [#a]
    == See <<b>>

    [#b]
    == Consult https://google.com[Google]
    EOS

    output = convert_string_to_embedded input
    assert_includes output, '<h2 id="a">See <a href="#b">Consult Google</a></h2>'
  end

  test 'should not resolve forward xref evaluated during parsing' do
    input = <<~'EOS'
    [#s1]
    == <<forward>>

    == <<s1>>

    [#forward]
    == Forward
    EOS

    output = convert_string_to_embedded input
    assert_xpath '//a[@href="#forward"][text()="Forward"]', output, 0
  end

  test 'should not resolve forward natural xref evaluated during parsing' do
    input = <<~'EOS'
    :idprefix:

    [#s1]
    == <<Forward>>

    == <<s1>>

    == Forward
    EOS

    output = convert_string_to_embedded input
    assert_xpath '//a[@href="#forward"][text()="Forward"]', output, 0
  end

  test 'should resolve first matching natural xref' do
    input = <<~'EOS'
    see <<Section Title>>

    [#s1]
    == Section Title

    [#s2]
    == Section Title
    EOS

    output = convert_string_to_embedded input
    assert_xpath '//a[@href="#s1"]', output, 1
    assert_xpath '//a[@href="#s1"][text()="Section Title"]', output, 1
  end

  test 'anchor creates reference' do
    doc = document_from_string '[[tigers]]Tigers roam here.'
    ref = doc.catalog[:refs]['tigers']
    refute_nil ref
    assert_nil ref.reftext
  end

  test 'anchor with label creates reference' do
    doc = document_from_string '[[tigers,Tigers]]Tigers roam here.'
    ref = doc.catalog[:refs]['tigers']
    refute_nil ref
    assert_equal 'Tigers', ref.reftext
  end

  test 'anchor with quoted label creates reference with quoted label text' do
    doc = document_from_string %([[tigers,"Tigers roam here"]]Tigers roam here.)
    ref = doc.catalog[:refs]['tigers']
    refute_nil ref
    assert_equal '"Tigers roam here"', ref.reftext
  end

  test 'anchor with label containing a comma creates reference' do
    doc = document_from_string %([[tigers,Tigers, scary tigers, roam here]]Tigers roam here.)
    ref = doc.catalog[:refs]['tigers']
    refute_nil ref
    assert_equal 'Tigers, scary tigers, roam here', ref.reftext
  end
end
