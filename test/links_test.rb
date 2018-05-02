# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context 'Links' do

  test 'qualified url inline with text' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare'][text() = 'http://asciidoc.org']", render_string("The AsciiDoc project is located at http://asciidoc.org.")
  end

  test 'qualified url with role inline with text' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare project'][text() = 'http://asciidoc.org']", render_string("The AsciiDoc project is located at http://asciidoc.org[role=project].")
  end

  test 'qualified http url inline with hide-uri-scheme set' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare'][text() = 'asciidoc.org']", render_string("The AsciiDoc project is located at http://asciidoc.org.", :attributes => {'hide-uri-scheme' => ''})
  end

  test 'qualified file url inline with label' do
    assert_xpath "//a[@href='file:///home/user/bookmarks.html'][text() = 'My Bookmarks']", render_embedded_string('file:///home/user/bookmarks.html[My Bookmarks]')
  end

  test 'qualified file url inline with hide-uri-scheme set' do
    assert_xpath "//a[@href='file:///etc/app.conf'][text() = '/etc/app.conf']", render_string('Edit the configuration file link:file:///etc/app.conf[]', :attributes => {'hide-uri-scheme' => ''})
  end

  test 'qualified url with label' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = 'AsciiDoc']", render_string("We're parsing http://asciidoc.org[AsciiDoc] markup")
  end

  test 'qualified url with label containing escaped right square bracket' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = '[Ascii]Doc']", render_string("We're parsing http://asciidoc.org[[Ascii\\]Doc] markup")
  end

  test 'qualified url with backslash label' do
    assert_xpath "//a[@href='https://google.com'][text() = 'Google for \\']", render_string("I advise you to https://google.com[Google for +\\+]")
  end

  test 'qualified url with label using link macro' do
    assert_xpath "//a[@href='http://asciidoc.org'][text() = 'AsciiDoc']", render_string("We're parsing link:http://asciidoc.org[AsciiDoc] markup")
  end

  test 'qualified url with role using link macro' do
    assert_xpath "//a[@href='http://asciidoc.org'][@class='bare project'][text() = 'http://asciidoc.org']", render_string("We're parsing link:http://asciidoc.org[role=project] markup")
  end

  test 'qualified url using macro syntax with multi-line label inline with text' do
    assert_xpath %{//a[@href='http://asciidoc.org'][text() = 'AsciiDoc\nmarkup']}, render_string("We're parsing link:http://asciidoc.org[AsciiDoc\nmarkup]")
  end

  test 'qualified url with label containing square brackets using link macro' do
    str = 'http://example.com[[bracket1\]]'
    doc = document_from_string str, :header_footer => false, :doctype => 'inline'
    assert_match '<a href="http://example.com">[bracket1]</a>', doc.convert, 1
    doc = document_from_string str, :header_footer => false, :backend => 'docbook', :doctype => 'inline'
    assert_match '<link xl:href="http://example.com">[bracket1]</link>', doc.convert, 1
    doc = document_from_string str, :header_footer => false, :backend => 'docbook45', :doctype => 'inline'
    assert_match '<ulink url="http://example.com">[bracket1]</ulink>', doc.convert, 1
  end

  test 'link macro with empty target' do
    input = 'Link to link:[this page].'
    output = render_embedded_string input
    assert_xpath '//a', output, 1
    assert_xpath '//a[@href=""]', output, 1
  end

  test 'should not recognize link macro with double colons' do
    input = 'The link::http://example.org[example domain] is reserved for tests and documentation.'
    output = render_embedded_string input
    assert_includes output, 'link::http://example.org[example domain]'
  end

  test 'qualified url surrounded by angled brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="http://asciidoc.org"]', render_string('<http://asciidoc.org> is the project page for AsciiDoc.'), 1
  end

  test 'qualified url surrounded by round brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="http://asciidoc.org"]', render_string('(http://asciidoc.org) is the project page for AsciiDoc.'), 1
  end

  test 'qualified url with trailing round bracket' do
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', render_string('Asciidoctor is a Ruby-based AsciiDoc processor (see https://asciidoctor.org)'), 1
  end

  test 'qualified url with trailing semi-colon' do
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', render_string('https://asciidoctor.org; where text gets parsed'), 1
  end

  test 'qualified url with trailing colon' do
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', render_string('https://asciidoctor.org: where text gets parsed'), 1
  end

  test 'qualified url in round brackets with trailing colon' do
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', render_string('(https://asciidoctor.org): where text gets parsed'), 1
  end

  test 'qualified url with trailing round bracket followed by colon' do
    result = render_embedded_string '(from https://asciidoctor.org): where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/preceding-sibling::text()[.="(from "]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[.="): where text gets parsed"]', result, 1
  end

  test 'qualified url in round brackets with trailing semi-colon' do
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', render_string('(https://asciidoctor.org); where text gets parsed'), 1
  end

  test 'qualified url with trailing round bracket followed by semi-colon' do
    result = render_embedded_string '(from https://asciidoctor.org); where text gets parsed'
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/preceding-sibling::text()[.="(from "]', result, 1
    assert_xpath '//a[@href="https://asciidoctor.org"][text()="https://asciidoctor.org"]/following-sibling::text()[.="); where text gets parsed"]', result, 1
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
    assert_xpath '//a[@href="http://jruby.org/apidocs/org/jruby/Ruby.html#addModule(org.jruby.RubyModule)"][text()="addModule() adds a Ruby module"]', render_string('http://jruby.org/apidocs/org/jruby/Ruby.html#addModule(org.jruby.RubyModule)[addModule() adds a Ruby module]'), 1
  end

  test 'qualified url adjacent to text in square brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', render_string(']http://asciidoc.org[AsciiDoc] project page.'), 1
  end

  test 'qualified url adjacent to text in round brackets' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', render_string(')http://asciidoc.org[AsciiDoc] project page.'), 1
  end

  test 'qualified url following no-break space' do
    assert_xpath '//a[@href="http://asciidoc.org"][text()="AsciiDoc"]', render_string(%(#{[0xa0].pack 'U1'}http://asciidoc.org[AsciiDoc] project page.)), 1
  end if ::RUBY_MIN_VERSION_1_9

  test 'qualified url following smart apostrophe' do
    output = render_embedded_string("l&#8217;http://www.irit.fr[IRIT]")
    assert_match(/l&#8217;<a href=/, output)
  end

  test 'qualified url using invalid link macro should not create link' do
    assert_xpath '//a', render_string('link:http://asciidoc.org is the project page for AsciiDoc.'), 0
  end

  test 'escaped inline qualified url should not create link' do
    assert_xpath '//a', render_string('\http://asciidoc.org is the project page for AsciiDoc.'), 0
  end

  test 'url in link macro with at (@) sign should not create mailto link' do
    assert_xpath '//a[@href="http://xircles.codehaus.org/lists/dev@geb.codehaus.org"][text()="subscribe"]', render_string('http://xircles.codehaus.org/lists/dev@geb.codehaus.org[subscribe]')
  end

  test 'implicit url with at (@) sign should not create mailto link' do
    assert_xpath '//a[@href="http://xircles.codehaus.org/lists/dev@geb.codehaus.org"][text()="http://xircles.codehaus.org/lists/dev@geb.codehaus.org"]', render_string('http://xircles.codehaus.org/lists/dev@geb.codehaus.org')
  end

  test 'escaped inline qualified url using macro syntax should not create link' do
    assert_xpath '//a', render_string('\http://asciidoc.org[AsciiDoc] is the key to good docs.'), 0
  end

  test 'inline qualified url followed by an endline should not include endline in link' do
    assert_xpath '//a[@href="https://github.com/asciidoctor"]', render_string("The source code for Asciidoctor can be found at https://github.com/asciidoctor\nwhich is a GitHub organization."), 1
  end

  test 'qualified url divided by endline using macro syntax should not create link' do
    assert_xpath '//a', render_string("The source code for Asciidoctor can be found at link:https://github.com/asciidoctor\n[]which is a GitHub organization."), 0
  end

  test 'qualified url containing whitespace using macro syntax should not create link' do
    assert_xpath '//a', render_string('I often need to refer to the chapter on link:http://asciidoc.org?q=attribute references[Attribute References].'), 0
  end

  test 'qualified url containing an encoded space using macro syntax should create a link' do
    assert_xpath '//a', render_string('I often need to refer to the chapter on link:http://asciidoc.org?q=attribute%20references[Attribute References].'), 1
  end

  test 'inline quoted qualified url should not consume surrounding angled brackets' do
    assert_xpath '//a[@href="https://github.com/asciidoctor"]', render_string('Asciidoctor GitHub organization: <**https://github.com/asciidoctor**>'), 1
  end

  test 'link with quoted text should not be separated into attributes when text contains an equal sign' do
    assert_xpath '//a[@href="http://search.example.com"][text()="Google, Yahoo, Bing = Search Engines"]', render_embedded_string('http://search.example.com["Google, Yahoo, Bing = Search Engines"]'), 1
  end

  test 'link with quoted text but no equal sign should carry quotes over to output' do
    assert_xpath %(//a[@href="http://search.example.com"][text()='"Google, Yahoo, Bing"']), render_embedded_string('http://search.example.com["Google, Yahoo, Bing"]'), 1
  end

  test 'link with comma in text but no equal sign should not be separated into attributes' do
    assert_xpath '//a[@href="http://search.example.com"][text()="Google, Yahoo, Bing"]', render_embedded_string('http://search.example.com[Google, Yahoo, Bing]'), 1
  end

  test 'role and window attributes on link are processed' do
    assert_xpath '//a[@href="http://google.com"][@class="external"][@target="_blank"]', render_embedded_string('http://google.com[Google, role=external, window="_blank"]'), 1
  end

  test 'link macro with attributes but no text should use URL as text' do
    url = 'https://fonts.googleapis.com/css?family=Roboto:400,400italic,'
    assert_xpath %(//a[@href="#{url}"][text()="#{url}"]), render_embedded_string(%(link:#{url}[family=Roboto,weight=400])), 1
  end

  test 'link macro with attributes but blank text should use URL as text' do
    url = 'https://fonts.googleapis.com/css?family=Roboto:400,400italic,'
    assert_xpath %(//a[@href="#{url}"][text()="#{url}"]), render_embedded_string(%(link:#{url}[,family=Roboto,weight=400])), 1
  end

  test 'link macro with comma but no explicit attributes in text should not parse text' do
    url = 'https://fonts.googleapis.com/css?family=Roboto:400,400italic,'
    assert_xpath %(//a[@href="#{url}"][text()="Roboto,400"]), render_embedded_string(%(link:#{url}[Roboto,400])), 1
  end

  test 'link text that ends in ^ should set link window to _blank' do
    assert_xpath '//a[@href="http://google.com"][@target="_blank"]', render_embedded_string('http://google.com[Google^]'), 1
  end

  test 'rel=noopener should be added to a link that targets the _blank window' do
    assert_xpath '//a[@href="http://google.com"][@target="_blank"][@rel="noopener"]', render_embedded_string('http://google.com[Google^]'), 1
  end

  test 'rel=noopener should be added to a link that targets a named window when the noopener option is set' do
    assert_xpath '//a[@href="http://google.com"][@target="name"][@rel="noopener"]', render_embedded_string('http://google.com[Google,window=name,opts=noopener]'), 1
  end

  test 'rel=noopener should not be added to a link if it does not target a window' do
    result = render_embedded_string 'http://google.com[Google,opts=noopener]'
    assert_xpath '//a[@href="http://google.com"]', result, 1
    assert_xpath '//a[@href="http://google.com"][@rel="noopener"]', result, 0
  end

  test 'rel=nofollow should be added to a link when the nofollow option is set' do
    assert_xpath '//a[@href="http://google.com"][@target="name"][@rel="nofollow noopener"]', render_embedded_string('http://google.com[Google,window=name,opts="nofollow,noopener"]'), 1
  end

  test 'id attribute on link is processed' do
    assert_xpath '//a[@href="http://google.com"][@id="link-1"]', render_embedded_string('http://google.com[Google, id="link-1"]'), 1
  end

  test 'title attribute on link is processed' do
    assert_xpath '//a[@href="http://google.com"][@title="title-1"]', render_embedded_string('http://google.com[Google, title="title-1"]'), 1
  end

  test 'inline irc link' do
    assert_xpath '//a[@href="irc://irc.freenode.net"][text()="irc://irc.freenode.net"]', render_embedded_string('irc://irc.freenode.net'), 1
  end

  test 'inline irc link with text' do
    assert_xpath '//a[@href="irc://irc.freenode.net"][text()="Freenode IRC"]', render_embedded_string('irc://irc.freenode.net[Freenode IRC]'), 1
  end

  test 'inline ref' do
    variations = %w([[tigers]] anchor:tigers[])
    variations.each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor})
      output = doc.convert
      assert_equal '[tigers]', doc.catalog[:ids]['tigers']
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_nil doc.catalog[:refs]['tigers'].text
      assert_xpath '//a[@id = "tigers"]', output, 1
      assert_xpath '//a[@id = "tigers"]/child::text()', output, 0
    end
  end

  test 'escaped inline ref' do
    variations = %w([[tigers]] anchor:tigers[])
    variations.each do |anchor|
      doc = document_from_string %(Here you can read about tigers.\\#{anchor})
      output = doc.convert
      refute doc.catalog[:ids].key?('tigers')
      refute doc.catalog[:refs].key?('tigers')
      assert_xpath '//a[@id = "tigers"]', output, 0
    end
  end

  test 'inline ref can start with colon' do
    input = '[[:idname]] text'
    output = render_embedded_string input
    assert_xpath '//a[@id = ":idname"]', output, 1
  end

  test 'inline ref cannot start with digit' do
    input = '[[1-install]] text'
    output = render_embedded_string input
    assert_includes output, '[[1-install]]'
    assert_xpath '//a[@id = "1-install"]', output, 0
  end

  test 'inline ref with reftext' do
    %w([[tigers,Tigers]] anchor:tigers[Tigers]).each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor})
      output = doc.convert
      assert_equal 'Tigers', doc.catalog[:ids]['tigers']
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_equal 'Tigers', doc.catalog[:refs]['tigers'].text
      assert_xpath '//a[@id = "tigers"]', output, 1
      assert_xpath '//a[@id = "tigers"]/child::text()', output, 0
    end
  end

  test 'should encode double quotes in reftext of anchor macro in DocBook output' do
    input = 'anchor:uncola[the "un"-cola]'
    result = render_inline_string input, :backend => :docbook
    assert_equal '<anchor xml:id="uncola" xreflabel="the &quot;un&quot;-cola"/>', result
  end

  test 'should substitute attribute references in reftext when registering inline ref' do
    %w([[tigers,{label-tigers}]] anchor:tigers[{label-tigers}]).each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor}), :attributes => { 'label-tigers' => 'Tigers' }
      doc.convert
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_equal 'Tigers', doc.catalog[:refs]['tigers'].text
      assert_equal 'Tigers', doc.catalog[:ids]['tigers']
    end
  end

  test 'inline ref with reftext converted to DocBook' do
    %w([[tigers,<Tigers>]] anchor:tigers[<Tigers>]).each do |anchor|
      doc = document_from_string %(Here you can read about tigers.#{anchor}), :backend => :docbook45
      output = doc.convert :header_footer => false
      assert_kind_of Asciidoctor::Inline, doc.catalog[:refs]['tigers']
      assert_equal '<Tigers>', doc.catalog[:refs]['tigers'].text
      assert_equal '<Tigers>', doc.references[:ids]['tigers']
      assert_includes output, '<anchor id="tigers" xreflabel="&lt;Tigers&gt;"/>'
    end
  end

  test 'does not match bibliography anchor in prose when scanning for inline anchor' do
    doc = document_from_string 'Use [[[label]]] to assign a label to a bibliography entry.'
    refute doc.catalog[:ids].key?('label')
    refute doc.catalog[:refs].key?('label')
  end

  test 'repeating inline anchor macro with empty reftext' do
    input = 'anchor:one[] anchor:two[] anchor:three[]'
    result = render_inline_string input
    assert_equal '<a id="one"></a> <a id="two"></a> <a id="three"></a>', result
  end

  test 'mixed inline anchor macro and anchor shorthand with empty reftext' do
    input = 'anchor:one[][[two]]anchor:three[][[four]]anchor:five[]'
    result = render_inline_string input
    assert_equal '<a id="one"></a><a id="two"></a><a id="three"></a><a id="four"></a><a id="five"></a>', result
  end

  test 'assigns xreflabel value for anchor macro without reftext in DocBook output' do
    input = 'anchor:foo[]'
    result = render_inline_string input, :backend => :docbook
    assert_equal '<anchor xml:id="foo" xreflabel="[foo]"/>', result
  end

  test 'unescapes square bracket in reftext of anchor macro' do
    input = 'see <<foo>>

anchor:foo[b[a\]r]text'
    result = render_embedded_string input
    assert_includes result, 'see <a href="#foo">b[a]r</a>'
  end

  test 'unescapes square bracket in reftext of anchor macro in DocBook output' do
    input = 'anchor:foo[b[a\]r]'
    result = render_inline_string input, :backend => :docbook
    assert_equal '<anchor xml:id="foo" xreflabel="b[a]r"/>', result
  end

  test 'xref using angled bracket syntax' do
    doc = document_from_string '<<tigers>>'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, '[tigers]', :type => :ref, :target => 'tigers'), '[tigers]']
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with explicit hash' do
    doc = document_from_string '<<#tigers>>'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, 'Tigers', :type => :ref, :target => 'tigers'), 'Tigers']
    assert_xpath '//a[@href="#tigers"][text() = "Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with label' do
    input = <<-EOS
<<tigers,About Tigers>>

[#tigers]
== Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "About Tigers"]', render_string(input), 1
  end

  test 'xref using angled bracket syntax with quoted label' do
    input = <<-EOS
<<tigers,"About Tigers">>

[#tigers]
== Tigers
    EOS
    assert_xpath %q(//a[@href="#tigers"][text() = '"About Tigers"']), render_string(input), 1
  end

  test 'should not interpret path sans extension in xref with angled bracket syntax in compat mode' do
    using_memory_logger do |logger|
      doc = document_from_string '<<tigers#>>', :header_footer => false, :attributes => { 'compat-mode' => '' }
      assert_xpath '//a[@href="#tigers#"][text() = "[tigers#]"]', doc.convert, 1
    end
  end

  test 'xref using angled bracket syntax with path sans extension' do
    doc = document_from_string '<<tigers#>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'inter-document xref should not add suffix to path with a non-AsciiDoc extension' do
    {
      'using-.net-web-services' => 'Using .NET web services',
      '../file.pdf' => 'Download the .pdf file'
    }.each do |path, text|
      result = render_embedded_string %(<<#{path}#,#{text}>>)
      assert_xpath %(//a[@href="#{path}"][text() = "#{text}"]), result, 1
    end
  end

  test 'inter-document xref should only remove the file extension part if the path contains a period elsewhere' do
    result = render_embedded_string '<<using-.net-web-services.adoc#,Using .NET web services>>'
    assert_xpath '//a[@href="using-.net-web-services.html"][text() = "Using .NET web services"]', result, 1
  end

  test 'xref using angled bracket syntax with path sans extension using docbook backend' do
    doc = document_from_string '<<tigers#>>', :header_footer => false, :backend => 'docbook'
    assert_match '<link xl:href="tigers.xml">tigers.xml</link>', doc.convert, 1
    doc = document_from_string '<<tigers#>>', :header_footer => false, :backend => 'docbook45'
    assert_match '<ulink url="tigers.xml">tigers.xml</ulink>', doc.convert, 1
  end

  test 'xref using angled bracket syntax with ancestor path sans extension' do
    doc = document_from_string '<<../tigers#,tigers>>', :header_footer => false
    assert_xpath '//a[@href="../tigers.html"][text() = "tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with absolute path sans extension' do
    doc = document_from_string '<</path/to/tigers#,tigers>>', :header_footer => false
    assert_xpath '//a[@href="/path/to/tigers.html"][text() = "tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and extension' do
    using_memory_logger do |logger|
      doc = document_from_string '<<tigers.adoc>>', :header_footer => false
      assert_xpath '//a[@href="#tigers.adoc"][text() = "[tigers.adoc]"]', doc.convert, 1
    end
  end

  test 'xref using angled bracket syntax with path and extension with hash' do
    doc = document_from_string '<<tigers.adoc#>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and extension with fragment' do
    doc = document_from_string '<<tigers.adoc#id>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html#id"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using macro syntax with path and extension in compat mode' do
    using_memory_logger do |logger|
      doc = document_from_string 'xref:tigers.adoc[]', :header_footer => false, :attributes => { 'compat-mode' => '' }
      assert_xpath '//a[@href="#tigers.adoc"][text() = "[tigers.adoc]"]', doc.convert, 1
    end
  end

  test 'xref using macro syntax with path and extension' do
    doc = document_from_string 'xref:tigers.adoc[]', :header_footer => false
    assert_xpath '//a[@href="tigers.html"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and fragment' do
    doc = document_from_string '<<tigers#about>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html#about"][text() = "tigers.html"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path, fragment and text' do
    doc = document_from_string '<<tigers#about,About Tigers>>', :header_footer => false
    assert_xpath '//a[@href="tigers.html#about"][text() = "About Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and custom relfilesuffix and outfilesuffix' do
    attributes = {'relfileprefix' => '../', 'outfilesuffix' => '/'}
    doc = document_from_string '<<tigers#about,About Tigers>>', :header_footer => false, :attributes => attributes
    assert_xpath '//a[@href="../tigers/#about"][text() = "About Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path and custom relfilesuffix' do
    attributes = { 'relfilesuffix' => '/' }
    doc = document_from_string '<<tigers#about,About Tigers>>', :header_footer => false, :attributes => attributes
    assert_xpath '//a[@href="tigers/#about"][text() = "About Tigers"]', doc.convert, 1
  end

  test 'xref using angled bracket syntax with path which has been included in this document' do
    using_memory_logger do |logger|
      in_verbose_mode do
        doc = document_from_string '<<tigers#about,About Tigers>>', :header_footer => false
        doc.catalog[:includes]['tigers'] = true
        output = doc.convert
        assert_xpath '//a[@href="#about"][text() = "About Tigers"]', output, 1
        assert_message logger, :WARN, 'invalid reference: about'
      end
    end
  end

  test 'xref using angled bracket syntax with nested path which has been included in this document' do
    using_memory_logger do |logger|
      in_verbose_mode do
        doc = document_from_string '<<part1/tigers#about,About Tigers>>', :header_footer => false
        doc.catalog[:includes]['part1/tigers'] = true
        output = doc.convert
        assert_xpath '//a[@href="#about"][text() = "About Tigers"]', output, 1
        assert_message logger, :WARN, 'invalid reference: about'
      end
    end
  end

  test 'xref using angled bracket syntax inline with text' do
    input = <<-EOS
Want to learn <<tigers,about tigers>>?

[#tigers]
== Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "about tigers"]', render_string(input), 1
  end

  test 'xref using angled bracket syntax with multi-line label inline with text' do
    input = <<-EOS
Want to learn <<tigers,about
tigers>>?

[#tigers]
== Tigers
    EOS
    assert_xpath %{//a[@href="#tigers"][normalize-space(text()) = "about tigers"]}, render_string(input), 1
  end

  test 'xref with escaped text' do
    # when \x0 was used as boundary character for passthrough, it was getting stripped
    # now using unicode marks as boundary characters, which resolves issue
    input = <<-EOS
See the <<tigers, `+[tigers]+`>> section for details about tigers.

[#tigers]
== Tigers
    EOS
    output = render_embedded_string input
    assert_xpath %(//a[@href="#tigers"]/code[text()="[tigers]"]), output, 1
  end

  test 'xref with target that begins with attribute reference in title' do
    ['<<{lessonsdir}/lesson-1#,Lesson 1>>', 'xref:{lessonsdir}/lesson-1#[Lesson 1]'].each do |xref|
      input = <<-EOS
:lessonsdir: lessons

[#lesson-1-listing]
== #{xref}

A summary of the first lesson.
      EOS

      output = render_embedded_string input
      assert_xpath '//h2/a[@href="lessons/lesson-1.html"]', output, 1
    end
  end

  test 'xref using macro syntax' do
    doc = document_from_string 'xref:tigers[]'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, '[tigers]', :type => :ref, :target => 'tigers'), '[tigers]']
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', doc.convert, 1
  end

  test 'multiple xref macros with implicit text in single line' do
    input = <<-EOS
This document has two sections, xref:sect-a[] and xref:sect-b[].

[#sect-a]
== Section A

[#sect-b]
== Section B
    EOS
    result = render_embedded_string input
    assert_xpath '//a[@href="#sect-a"][text() = "Section A"]', result, 1
    assert_xpath '//a[@href="#sect-b"][text() = "Section B"]', result, 1
  end

  test 'xref using macro syntax with explicit hash' do
    doc = document_from_string 'xref:#tigers[]'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, 'Tigers', :type => :ref, :target => 'tigers'), 'Tigers']
    assert_xpath '//a[@href="#tigers"][text() = "Tigers"]', doc.convert, 1
  end

  test 'xref using macro syntax with label' do
    input = <<-EOS
xref:tigers[About Tigers]

[#tigers]
== Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "About Tigers"]', render_string(input), 1
  end

  test 'xref using macro syntax inline with text' do
    input = <<-EOS
Want to learn xref:tigers[about tigers]?

[#tigers]
== Tigers
    EOS

    assert_xpath '//a[@href="#tigers"][text() = "about tigers"]', render_string(input), 1
  end

  test 'xref using macro syntax with multi-line label inline with text' do
    input = <<-EOS
Want to learn xref:tigers[about
tigers]?

[#tigers]
== Tigers
    EOS
    assert_xpath %{//a[@href="#tigers"][normalize-space(text()) = "about tigers"]}, render_string(input), 1
  end

  test 'xref using macro syntax with text that ends with an escaped closing bracket' do
    input = <<-EOS
xref:tigers[[tigers\\]]

[#tigers]
== Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "[tigers]"]', render_embedded_string(input), 1
  end

  test 'xref using macro syntax with text that contains an escaped closing bracket' do
    input = <<-EOS
xref:tigers[[tigers\\] are cats]

[#tigers]
== Tigers
    EOS
    assert_xpath '//a[@href="#tigers"][text() = "[tigers] are cats"]', render_embedded_string(input), 1
  end

  test 'unescapes square bracket in reftext used by xref' do
    input = 'anchor:foo[b[a\]r]about

see <<foo>>'
    result = render_embedded_string input
    assert_xpath '//a[@href="#foo"]', result, 1
    assert_xpath '//a[@href="#foo"][text()="b[a]r"]', result, 1
  end

  test 'xref using invalid macro syntax does not create link' do
    doc = document_from_string 'xref:tigers'
    doc.register :refs, ['tigers', (Asciidoctor::Inline.new doc, :anchor, 'Tigers', :type => :ref, :target => 'tigers'), 'Tigers']
    assert_xpath '//a', doc.convert, 0
  end

  test 'should warn and create link if verbose flag is set and reference is not found' do
    input = <<-EOS
[#foobar]
== Foobar

== Section B

See <<foobaz>>.
    EOS
    using_memory_logger do |logger|
      in_verbose_mode do
        output = render_embedded_string input
        assert_xpath '//a[@href="#foobaz"][text() = "[foobaz]"]', output, 1
        assert_message logger, :WARN, 'invalid reference: foobaz'
      end
    end
  end

  test 'should warn and create link if verbose flag is set and reference using # notation is not found' do
    input = <<-EOS
[#foobar]
== Foobar

== Section B

See <<#foobaz>>.
    EOS
    using_memory_logger do |logger|
      in_verbose_mode do
        output = render_embedded_string input
        assert_xpath '//a[@href="#foobaz"][text() = "[foobaz]"]', output, 1
        assert_message logger, :WARN, 'invalid reference: foobaz'
      end
    end
  end

  test 'should produce an internal anchor from an inter-document xref to file included into current file' do
    input = <<-'EOS'
= Book Title
:doctype: book

[#ch1]
== Chapter 1

So it begins.

Read <<other-chapters.adoc#ch2>> to find out what happens next!

include::other-chapters.adoc[]
    EOS

    doc = document_from_string input, :safe => :safe, :base_dir => fixturedir
    assert doc.catalog[:includes].key?('other-chapters')
    assert doc.catalog[:includes]['other-chapters']
    output = doc.convert
    assert_xpath '//a[@href="#ch2"][text()="Chapter 2"]', output, 1
  end

  test 'should produce an internal anchor from an inter-document xref to file included entirely into current file using tags' do
    input = <<-'EOS'
= Book Title
:doctype: book

[#ch1]
== Chapter 1

So it begins.

Read <<other-chapters.adoc#ch2>> to find out what happens next!

include::other-chapters.adoc[tags=**]
    EOS

    output = render_embedded_string input, :safe => :safe, :base_dir => fixturedir
    assert_xpath '//a[@href="#ch2"][text()="Chapter 2"]', output, 1
  end

  test 'should not produce an internal anchor for inter-document xref to file partially included into current file' do
    input = <<-'EOS'
= Book Title
:doctype: book

[#ch1]
== Chapter 1

So it begins.

Read <<other-chapters.adoc#ch2,the next chapter>> to find out what happens next!

include::other-chapters.adoc[tags=ch2]
    EOS

    doc = document_from_string input, :safe => :safe, :base_dir => fixturedir
    assert doc.catalog[:includes].key?('other-chapters')
    refute doc.catalog[:includes]['other-chapters']
    output = doc.convert
    assert_xpath '//a[@href="other-chapters.html#ch2"][text()="the next chapter"]', output, 1
  end

  test 'should warn and create link if debug mode is enabled, inter-document xref points to current doc, and reference not found' do
    input = <<-EOS
[#foobar]
== Foobar

== Section B

See <<test.adoc#foobaz>>.
    EOS
    using_memory_logger do |logger|
      in_verbose_mode do
        output = render_embedded_string input, :attributes => { 'docname' => 'test' }
        assert_xpath '//a[@href="#foobaz"][text() = "[foobaz]"]', output, 1
        assert_message logger, :WARN, 'invalid reference: foobaz'
      end
    end
  end

  test 'xref uses title of target as label for forward and backward references in html output' do
    input = <<-EOS
== Section A

<<_section_b>>

== Section B

<<_section_a>>
    EOS

    output = render_embedded_string input
    assert_xpath '//h2[@id="_section_a"][text()="Section A"]', output, 1
    assert_xpath '//a[@href="#_section_a"][text()="Section A"]', output, 1
    assert_xpath '//h2[@id="_section_b"][text()="Section B"]', output, 1
    assert_xpath '//a[@href="#_section_b"][text()="Section B"]', output, 1
  end

  test 'anchor creates reference' do
    doc = document_from_string "[[tigers]]Tigers roam here."
    assert_equal({'tigers' => '[tigers]'}, doc.catalog[:ids])
  end

  test 'anchor with label creates reference' do
    doc = document_from_string "[[tigers,Tigers]]Tigers roam here."
    assert_equal({'tigers' => 'Tigers'}, doc.catalog[:ids])
  end

  test 'anchor with quoted label creates reference with quoted label text' do
    doc = document_from_string %([[tigers,"Tigers roam here"]]Tigers roam here.)
    assert_equal({'tigers' => '"Tigers roam here"'}, doc.catalog[:ids])
  end

  test 'anchor with label containing a comma creates reference' do
    doc = document_from_string %([[tigers,Tigers, scary tigers, roam here]]Tigers roam here.)
    assert_equal({'tigers' => 'Tigers, scary tigers, roam here'}, doc.catalog[:ids])
  end
end
