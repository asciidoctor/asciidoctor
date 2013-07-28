require 'test_helper'

# TODO
# - test negatives
# - test role on every quote type
context 'Substitutions' do
  context 'Dispatcher' do
    test 'apply normal substitutions' do
      para = block_from_string("[blue]'http://asciidoc.org[AsciiDoc]' & [red]*Ruby*\n&#167; Making +++<u>documentation</u>+++ together +\nsince (C) {inception_year}.")
      para.document.attributes['inception_year'] = '2012'
      result = para.apply_normal_subs(para.buffer) 
      assert_equal %{<em class="blue"><a href="http://asciidoc.org">AsciiDoc</a></em> &amp; <strong class="red">Ruby</strong>\n&#167; Making <u>documentation</u> together<br>\nsince &#169; 2012.}, result
    end
  end

  context 'Quotes' do
    test 'single-line double-quoted string' do
      para = block_from_string(%q{``a few quoted words''})
      assert_equal '&#8220;a few quoted words&#8221;', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line double-quoted string' do
      para = block_from_string(%q{\``a few quoted words''})
      assert_equal %q(&#8216;`a few quoted words&#8217;'), para.sub_quotes(para.buffer.join)
    end

    test 'multi-line double-quoted string' do
      para = block_from_string(%Q{``a few\nquoted words''})
      assert_equal "&#8220;a few\nquoted words&#8221;", para.sub_quotes(para.buffer.join)
    end

    test 'double-quoted string with inline single quote' do
      para = block_from_string(%q{``Here's Johnny!''})
      assert_equal %q{&#8220;Here's Johnny!&#8221;}, para.sub_quotes(para.buffer.join)
    end

    test 'double-quoted string with inline backquote' do
      para = block_from_string(%q{``Here`s Johnny!''})
      assert_equal %q{&#8220;Here`s Johnny!&#8221;}, para.sub_quotes(para.buffer.join)
    end

    test 'single-line single-quoted string' do
      para = block_from_string(%q{`a few quoted words'})
      assert_equal '&#8216;a few quoted words&#8217;', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line single-quoted string' do
      para = block_from_string(%q{\`a few quoted words'})
      assert_equal %(`a few quoted words'), para.sub_quotes(para.buffer.join)
    end

    test 'multi-line single-quoted string' do
      para = block_from_string(%Q{`a few\nquoted words'})
      assert_equal "&#8216;a few\nquoted words&#8217;", para.sub_quotes(para.buffer.join)
    end

    test 'single-quoted string with inline single quote' do
      para = block_from_string(%q{`That isn't what I did.'})
      assert_equal %q{&#8216;That isn't what I did.&#8217;}, para.sub_quotes(para.buffer.join)
    end

    test 'single-quoted string with inline backquote' do
      para = block_from_string(%q{`Here`s Johnny!'})
      assert_equal %q{&#8216;Here`s Johnny!&#8217;}, para.sub_quotes(para.buffer.join)
    end

    test 'single-line constrained unquoted string' do
      para = block_from_string(%q{#a few words#})
      assert_equal 'a few words', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line constrained unquoted string' do
      para = block_from_string(%q{\#a few words#})
      assert_equal '#a few words#', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line constrained unquoted string' do
      para = block_from_string(%Q{#a few\nwords#})
      assert_equal "a few\nwords", para.sub_quotes(para.buffer.join)
    end

    test 'single-line unconstrained unquoted string' do
      para = block_from_string(%q{##--anything goes ##})
      assert_equal '--anything goes ', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line unconstrained unquoted string' do
      para = block_from_string(%q{\##--anything goes ##})
      assert_equal '#--anything goes #', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line unconstrained unquoted string' do
      para = block_from_string(%Q{##--anything\ngoes ##})
      assert_equal "--anything\ngoes ", para.sub_quotes(para.buffer.join)
    end

    test 'single-line constrained strong string' do
      para = block_from_string(%q{*a few strong words*})
      assert_equal '<strong>a few strong words</strong>', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line constrained strong string' do
      para = block_from_string(%q{\*a few strong words*})
      assert_equal '*a few strong words*', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line constrained strong string' do
      para = block_from_string(%Q{*a few\nstrong words*})
      assert_equal "<strong>a few\nstrong words</strong>", para.sub_quotes(para.buffer.join)
    end

    test 'constrained strong string containing an asterisk' do
      para = block_from_string(%q{*bl*ck*-eye})
      assert_equal '<strong>bl*ck</strong>-eye', para.sub_quotes(para.buffer.join)
    end

    test 'single-line constrained quote variation emphasized string' do
      para = block_from_string(%q{'a few emphasized words'})
      assert_equal '<em>a few emphasized words</em>', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line constrained quote variation emphasized string' do
      para = block_from_string(%q{\'a few emphasized words'})
      assert_equal %q('a few emphasized words'), para.sub_quotes(para.buffer.join)
    end

    test 'multi-line constrained emphasized quote variation string' do
      para = block_from_string(%Q{'a few\nemphasized words'})
      assert_equal "<em>a few\nemphasized words</em>", para.sub_quotes(para.buffer.join)
    end

    test 'single-quoted string containing an emphasized phrase' do
      para = block_from_string(%q{`I told him, 'Just go for it!''})
      assert_equal '&#8216;I told him, <em>Just go for it!</em>&#8217;', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-quotes inside emphasized words are restored' do
      para = block_from_string(%q{'Here\'s Johnny!'})
      # NOTE the \' is replaced with ' by the :replacements substitution, later in the substitution pipeline
      assert_equal %q{<em>Here\'s Johnny!</em>}, para.sub_quotes(para.buffer.join)
    end

    test 'single-line constrained emphasized underline variation string' do
      para = block_from_string(%q{_a few emphasized words_})
      assert_equal '<em>a few emphasized words</em>', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line constrained emphasized underline variation string' do
      para = block_from_string(%q{\_a few emphasized words_})
      assert_equal '_a few emphasized words_', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line constrained emphasized underline variation string' do
      para = block_from_string(%Q{_a few\nemphasized words_})
      assert_equal "<em>a few\nemphasized words</em>", para.sub_quotes(para.buffer.join)
    end

    test 'single-line constrained monospaced string' do
      para = block_from_string(%q{`a few <\{monospaced\}> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal '<code>a few &lt;{monospaced}&gt; words</code>', para.apply_normal_subs(para.buffer)
    end

    test 'single-line constrained monospaced string with role' do
      para = block_from_string(%q{[input]`a few <\{monospaced\}> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal '<code class="input">a few &lt;{monospaced}&gt; words</code>', para.apply_normal_subs(para.buffer)
    end

    test 'escaped single-line constrained monospaced string' do
      para = block_from_string(%q{\`a few <monospaced> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal '`a few &lt;monospaced&gt; words`', para.apply_normal_subs(para.buffer)
    end

    test 'escaped single-line constrained monospaced string with role' do
      para = block_from_string(%q{[input]\`a few <monospaced> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal '[input]`a few &lt;monospaced&gt; words`', para.apply_normal_subs(para.buffer)
    end

    test 'escaped role on single-line constrained monospaced string' do
      para = block_from_string(%q{\[input]`a few <monospaced> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal '[input]<code>a few &lt;monospaced&gt; words</code>', para.apply_normal_subs(para.buffer)
    end

    test 'escaped role on escaped single-line constrained monospaced string' do
      para = block_from_string(%q{\[input]\`a few <monospaced> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal '\[input]`a few &lt;monospaced&gt; words`', para.apply_normal_subs(para.buffer)
    end

    test 'multi-line constrained monospaced string' do
      para = block_from_string(%Q{`a few\n<\{monospaced\}> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal "<code>a few\n&lt;{monospaced}&gt; words</code>", para.apply_normal_subs(para.buffer)
    end

    test 'single-line unconstrained strong chars' do
      para = block_from_string(%q{**Git**Hub})
      assert_equal '<strong>Git</strong>Hub', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line unconstrained strong chars' do
      para = block_from_string(%q{\**Git**Hub})
      assert_equal '<strong>*Git</strong>*Hub', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line unconstrained strong chars' do
      para = block_from_string(%Q{**G\ni\nt\n**Hub})
      assert_equal "<strong>G\ni\nt\n</strong>Hub", para.sub_quotes(para.buffer.join)
    end

    test 'unconstrained strong chars with inline asterisk' do
      para = block_from_string(%q{**bl*ck**-eye})
      assert_equal '<strong>bl*ck</strong>-eye', para.sub_quotes(para.buffer.join)
    end

    test 'unconstrained strong chars with role' do
      para = block_from_string(%q{Git[blue]**Hub**})
      assert_equal %q{Git<strong class="blue">Hub</strong>}, para.sub_quotes(para.buffer.join)
    end

    # TODO this is not the same result as AsciiDoc, though I don't understand why AsciiDoc gets what it gets
    test 'escaped unconstrained strong chars with role' do
      para = block_from_string(%q{Git\[blue]**Hub**})
      assert_equal %q{Git[blue]<strong>*Hub</strong>*}, para.sub_quotes(para.buffer.join)
    end

    test 'single-line unconstrained emphasized chars' do
      para = block_from_string(%q{__Git__Hub})
      assert_equal '<em>Git</em>Hub', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line unconstrained emphasized chars' do
      para = block_from_string(%q{\__Git__Hub})
      assert_equal '__Git__Hub', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line unconstrained emphasized chars' do
      para = block_from_string(%Q{__G\ni\nt\n__Hub})
      assert_equal "<em>G\ni\nt\n</em>Hub", para.sub_quotes(para.buffer.join)
    end

    test 'unconstrained emphasis chars with role' do
      para = block_from_string(%q{[gray]__Git__Hub})
      assert_equal %q{<em class="gray">Git</em>Hub}, para.sub_quotes(para.buffer.join)
    end

    test 'escaped unconstrained emphasis chars with role' do
      para = block_from_string(%q{\[gray]__Git__Hub})
      assert_equal %q{[gray]__Git__Hub}, para.sub_quotes(para.buffer.join)
    end

    test 'single-line constrained monospaced chars' do
      para = block_from_string(%q{call +save()+ to persist the changes})
      assert_equal 'call <code>save()</code> to persist the changes', para.sub_quotes(para.buffer.join)
    end

    test 'single-line constrained monospaced chars with role' do
      para = block_from_string(%q{call [method]+save()+ to persist the changes})
      assert_equal 'call <code class="method">save()</code> to persist the changes', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line constrained monospaced chars' do
      para = block_from_string(%q{call \+save()+ to persist the changes})
      assert_equal 'call +save()+ to persist the changes', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line constrained monospaced chars with role' do
      para = block_from_string(%q{call [method]\+save()+ to persist the changes})
      assert_equal 'call [method]+save()+ to persist the changes', para.sub_quotes(para.buffer.join)
    end

    test 'escaped role on single-line constrained monospaced chars' do
      para = block_from_string(%q{call \[method]+save()+ to persist the changes})
      assert_equal 'call [method]<code>save()</code> to persist the changes', para.sub_quotes(para.buffer.join)
    end

    test 'escaped role on escaped single-line constrained monospaced chars' do
      para = block_from_string(%q{call \[method]\+save()+ to persist the changes})
      assert_equal 'call \[method]+save()+ to persist the changes', para.sub_quotes(para.buffer.join)
    end

    test 'single-line unconstrained monospaced chars' do
      para = block_from_string(%q{Git++Hub++})
      assert_equal 'Git<code>Hub</code>', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line unconstrained monospaced chars' do
      para = block_from_string(%q{Git\++Hub++})
      assert_equal 'Git+<code>Hub</code>+', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line unconstrained monospaced chars' do
      para = block_from_string(%Q{Git++\nH\nu\nb++})
      assert_equal "Git<code>\nH\nu\nb</code>", para.sub_quotes(para.buffer.join)
    end

    test 'single-line superscript chars' do
      para = block_from_string(%q{x^2^ = x * x, e = mc^2^, there's a 1^st^ time for everything})
      assert_equal 'x<sup>2</sup> = x * x, e = mc<sup>2</sup>, there\'s a 1<sup>st</sup> time for everything', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line superscript chars' do
      para = block_from_string(%q{x\^2^ = x * x})
      assert_equal 'x^2^ = x * x', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line superscript chars' do
      para = block_from_string(%Q{x^(n\n-\n1)^})
      assert_equal "x<sup>(n\n-\n1)</sup>", para.sub_quotes(para.buffer.join)
    end

    test 'single-line subscript chars' do
      para = block_from_string(%q{H~2~O})
      assert_equal 'H<sub>2</sub>O', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line subscript chars' do
      para = block_from_string(%q{H\~2~O})
      assert_equal 'H~2~O', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line subscript chars' do
      para = block_from_string(%Q{project~ view\non\nGitHub~})
      assert_equal "project<sub> view\non\nGitHub</sub>", para.sub_quotes(para.buffer.join)
    end
  end

  context 'Macros' do
    test 'a single-line link macro should be interpreted as a link' do
      para = block_from_string('link:/home.html[]')
      assert_equal %q{<a href="/home.html">/home.html</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line link macro with text should be interpreted as a link' do
      para = block_from_string('link:/home.html[Home]')
      assert_equal %q{<a href="/home.html">Home</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a mailto macro should be interpreted as a mailto link' do
      para = block_from_string('mailto:doc.writer@asciidoc.org[]')
      assert_equal %q{<a href="mailto:doc.writer@asciidoc.org">doc.writer@asciidoc.org</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a mailto macro with text should be interpreted as a mailto link' do
      para = block_from_string('mailto:doc.writer@asciidoc.org[Doc Writer]')
      assert_equal %q{<a href="mailto:doc.writer@asciidoc.org">Doc Writer</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a mailto macro with text and subject should be interpreted as a mailto link' do
      para = block_from_string('mailto:doc.writer@asciidoc.org[Doc Writer, Pull request]', :attributes => {'linkattrs' => ''})
      assert_equal %q{<a href="mailto:doc.writer@asciidoc.org?subject=Pull%20request">Doc Writer</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a mailto macro with text, subject and body should be interpreted as a mailto link' do
      para = block_from_string('mailto:doc.writer@asciidoc.org[Doc Writer, Pull request, Please accept my pull request]', :attributes => {'linkattrs' => ''})
      assert_equal %q{<a href="mailto:doc.writer@asciidoc.org?subject=Pull%20request&amp;body=Please%20accept%20my%20pull%20request">Doc Writer</a>}, para.sub_macros(para.buffer.join)
    end

    test 'should recognize inline email addresses' do
      para = block_from_string('doc.writer@asciidoc.org')
      assert_equal %q{<a href="mailto:doc.writer@asciidoc.org">doc.writer@asciidoc.org</a>}, para.sub_macros(para.buffer.join)
      para = block_from_string('<doc.writer@asciidoc.org>')
      assert_equal %q{&lt;<a href="mailto:doc.writer@asciidoc.org">doc.writer@asciidoc.org</a>&gt;}, para.apply_normal_subs(para.buffer)
      para = block_from_string('author+website@4fs.no')
      assert_equal %q{<a href="mailto:author+website@4fs.no">author+website@4fs.no</a>}, para.sub_macros(para.buffer.join)
      para = block_from_string('john@domain.uk.co')
      assert_equal %q{<a href="mailto:john@domain.uk.co">john@domain.uk.co</a>}, para.sub_macros(para.buffer.join)
    end

    test 'should ignore escaped inline email address' do
      para = block_from_string('\doc.writer@asciidoc.org')
      assert_equal %q{doc.writer@asciidoc.org}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line raw url should be interpreted as a link' do
      para = block_from_string('http://google.com')
      assert_equal %q{<a href="http://google.com">http://google.com</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line raw url with text should be interpreted as a link' do
      para = block_from_string('http://google.com[Google]')
      assert_equal %q{<a href="http://google.com">Google</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a multi-line raw url with text should be interpreted as a link' do
      para = block_from_string("http://google.com[Google\nHomepage]")
      assert_equal %{<a href="http://google.com">Google\nHomepage</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a multi-line raw url with attribute as text should be interpreted as a link with resolved attribute' do
      para = block_from_string("http://google.com[{google_homepage}]")
      para.document.attributes['google_homepage'] = 'Google Homepage'
      assert_equal %q{<a href="http://google.com">Google Homepage</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line escaped raw url should not be interpreted as a link' do
      para = block_from_string('\http://google.com')
      assert_equal %q{http://google.com}, para.sub_macros(para.buffer.join)
    end

    test 'a comma separated list of links should not include commas in links' do
      para = block_from_string('http://foo.com, http://bar.com, http://example.org')
      assert_equal %q{<a href="http://foo.com">http://foo.com</a>, <a href="http://bar.com">http://bar.com</a>, <a href="http://example.org">http://example.org</a>}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line image macro should be interpreted as an image' do
      para = block_from_string('image:tiger.png[]')
      assert_equal %{<span class="image"><img src="tiger.png" alt="tiger"></span>}, para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text should be interpreted as an image with alt text' do
      para = block_from_string('image:tiger.png[Tiger]')
      assert_equal %{<span class="image"><img src="tiger.png" alt="Tiger"></span>}, para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text containing escaped square bracket should be interpreted as an image with alt text' do
      para = block_from_string('image:tiger.png[[Another\] Tiger]')
      assert_equal %{<span class="image"><img src="tiger.png" alt="[Another] Tiger"></span>}, para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text and dimensions should be interpreted as an image with alt text and dimensions' do
      para = block_from_string('image:tiger.png[Tiger, 200, 100]')
      assert_equal %{<span class="image"><img src="tiger.png" alt="Tiger" width="200" height="100"></span>},
          para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text and link should be interpreted as a linked image with alt text' do
      para = block_from_string('image:tiger.png[Tiger, link="http://en.wikipedia.org/wiki/Tiger"]')
      assert_equal %{<span class="image"><a class="image" href="http://en.wikipedia.org/wiki/Tiger"><img src="tiger.png" alt="Tiger"></a></span>},
          para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'a multi-line image macro with text and dimensions should be interpreted as an image with alt text and dimensions' do
      para = block_from_string(%(image:tiger.png[Another\nAwesome\nTiger, 200,\n100]))
      assert_equal %{<span class="image"><img src="tiger.png" alt="Another Awesome Tiger" width="200" height="100"></span>},
          para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'an inline image macro with a url target should be interpreted as an image' do
      para = block_from_string %(Beware of the image:http://example.com/images/tiger.png[tiger].)
      assert_equal %{Beware of the <span class="image"><img src="http://example.com/images/tiger.png" alt="tiger"></span>.},
          para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'should prepend value of imagesdir attribute to inline image target if target is relative path' do
      para = block_from_string %(Beware of the image:tiger.png[tiger].), :attributes => {'imagesdir' => './images'}
      assert_equal %{Beware of the <span class="image"><img src="./images/tiger.png" alt="tiger"></span>.},
          para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'should not prepend value of imagesdir attribute to inline image target if target is absolute path' do
      para = block_from_string %(Beware of the image:/tiger.png[tiger].), :attributes => {'imagesdir' => './images'}
      assert_equal %{Beware of the <span class="image"><img src="/tiger.png" alt="tiger"></span>.},
          para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'should not prepend value of imagesdir attribute to inline image target if target is url' do
      para = block_from_string %(Beware of the image:http://example.com/images/tiger.png[tiger].), :attributes => {'imagesdir' => './images'}
      assert_equal %{Beware of the <span class="image"><img src="http://example.com/images/tiger.png" alt="tiger"></span>.},
          para.sub_macros(para.buffer.join).gsub(/>\s+</, '><')
    end

    test 'a block image macro should not be detected within paragraph text' do
      para = block_from_string(%(Not an inline image macro image::tiger.png[].))
      result = para.sub_macros(para.buffer.join)
      assert !result.include?('<img ')
      assert result.include?('image::tiger.png[]')
    end

    test 'a single-line footnote macro should be registered and rendered as a footnote' do
      para = block_from_string('Sentence text footnote:[An example footnote.].')
      assert_equal %(Sentence text <span class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>.), para.sub_macros(para.buffer.join)
      assert_equal 1, para.document.references[:footnotes].size
      footnote = para.document.references[:footnotes].first
      assert_equal 1, footnote.index
      assert footnote.id.nil?
      assert_equal 'An example footnote.', footnote.text
    end

    test 'a multi-line footnote macro should be registered and rendered as a footnote' do
      para = block_from_string("Sentence text footnote:[An example footnote\nwith wrapped text.].")
      assert_equal %(Sentence text <span class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>.), para.sub_macros(para.buffer.join)
      assert_equal 1, para.document.references[:footnotes].size
      footnote = para.document.references[:footnotes].first
      assert_equal 1, footnote.index
      assert footnote.id.nil?
      assert_equal "An example footnote\nwith wrapped text.", footnote.text
    end

    test 'a footnote macro can be directly adjacent to preceding word' do
      para = block_from_string('Sentence textfootnote:[An example footnote.].')
      assert_equal %(Sentence text<span class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>.), para.sub_macros(para.buffer.join)
    end

    test 'a footnote macro may contain a macro' do
      para = block_from_string('Share your code. footnote:[http://github.com[GitHub]]')
      assert_equal %(Share your code. <span class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>), para.sub_macros(para.buffer.join)
      assert_equal 1, para.document.references[:footnotes].size
      footnote1 = para.document.references[:footnotes][0]
      assert_equal '<a href="http://github.com">GitHub</a>', footnote1.text
    end

    test 'a footnote macro may contain a plain URL' do
      para = block_from_string %(the JLine footnote:[https://github.com/jline/jline2]\nlibrary.)
      result = para.sub_macros para.buffer.join
      assert_equal %(the JLine <span class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>\nlibrary.), result
      assert_equal 1, para.document.references[:footnotes].size
      fn1 = para.document.references[:footnotes].first
      assert_equal '<a href="https://github.com/jline/jline2">https://github.com/jline/jline2</a>', fn1.text
    end

    test 'a footnote macro followed by a semi-colon may contain a plain URL' do
      para = block_from_string %(the JLine footnote:[https://github.com/jline/jline2];\nlibrary.)
      result = para.sub_macros para.buffer.join
      assert_equal %(the JLine <span class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>;\nlibrary.), result
      assert_equal 1, para.document.references[:footnotes].size
      fn1 = para.document.references[:footnotes].first
      assert_equal '<a href="https://github.com/jline/jline2">https://github.com/jline/jline2</a>', fn1.text
    end

    test 'should increment index of subsequent footnote macros' do
      para = block_from_string("Sentence text footnote:[An example footnote.]. Sentence text footnote:[Another footnote.].")
      assert_equal %(Sentence text <span class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>. Sentence text <span class="footnote">[<a id="_footnoteref_2" class="footnote" href="#_footnote_2" title="View footnote.">2</a>]</span>.), para.sub_macros(para.buffer.join)
      assert_equal 2, para.document.references[:footnotes].size
      footnote1 = para.document.references[:footnotes][0]
      assert_equal 1, footnote1.index
      assert footnote1.id.nil?
      assert_equal "An example footnote.", footnote1.text
      footnote2 = para.document.references[:footnotes][1]
      assert_equal 2, footnote2.index
      assert footnote2.id.nil?
      assert_equal "Another footnote.", footnote2.text
    end

    test 'a footnoteref macro with id and single-line text should be registered and rendered as a footnote' do
      para = block_from_string('Sentence text footnoteref:[ex1, An example footnote.].')
      assert_equal %(Sentence text <span class="footnote" id="_footnote_ex1">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>.), para.sub_macros(para.buffer.join)
      assert_equal 1, para.document.references[:footnotes].size
      footnote = para.document.references[:footnotes].first
      assert_equal 1, footnote.index
      assert_equal 'ex1', footnote.id
      assert_equal 'An example footnote.', footnote.text
    end

    test 'a footnoteref macro with id and multi-line text should be registered and rendered as a footnote' do
      para = block_from_string("Sentence text footnoteref:[ex1, An example footnote\nwith wrapped text.].")
      assert_equal %(Sentence text <span class="footnote" id="_footnote_ex1">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>.), para.sub_macros(para.buffer.join)
      assert_equal 1, para.document.references[:footnotes].size
      footnote = para.document.references[:footnotes].first
      assert_equal 1, footnote.index
      assert_equal 'ex1', footnote.id
      assert_equal "An example footnote\nwith wrapped text.", footnote.text
    end

    test 'a footnoteref macro with id should refer to footnoteref with same id' do
      para = block_from_string('Sentence text footnoteref:[ex1, An example footnote.]. Sentence text footnoteref:[ex1].')
      assert_equal %(Sentence text <span class="footnote" id="_footnote_ex1">[<a id="_footnoteref_1" class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>. Sentence text <span class="footnoteref">[<a class="footnote" href="#_footnote_1" title="View footnote.">1</a>]</span>.), para.sub_macros(para.buffer.join)
      assert_equal 1, para.document.references[:footnotes].size
      footnote = para.document.references[:footnotes].first
      assert_equal 1, footnote.index
      assert_equal 'ex1', footnote.id
      assert_equal 'An example footnote.', footnote.text
    end

    test 'a single-line index term macro with a primary term should be registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[Tigers]', '(((Tigers)))']
      macros.each do |macro|
        para = block_from_string("#{sentence}#{macro}")
        output = para.sub_macros(para.buffer.join)
        assert_equal sentence, output
        assert_equal 1, para.document.references[:indexterms].size
        assert_equal ['Tigers'], para.document.references[:indexterms].first
      end
    end

    test 'a single-line index term macro with primary and secondary terms should be registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[Big cats, Tigers]', '(((Big cats, Tigers)))']
      macros.each do |macro|
        para = block_from_string("#{sentence}#{macro}")
        output = para.sub_macros(para.buffer.join)
        assert_equal sentence, output
        assert_equal 1, para.document.references[:indexterms].size
        assert_equal ['Big cats', 'Tigers'], para.document.references[:indexterms].first
      end
    end

    test 'a single-line index term macro with primary, secondary and tertiary terms should be registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[Big cats,Tigers , Panthera tigris]', '(((Big cats,Tigers , Panthera tigris)))']
      macros.each do |macro|
        para = block_from_string("#{sentence}#{macro}")
        output = para.sub_macros(para.buffer.join)
        assert_equal sentence, output
        assert_equal 1, para.document.references[:indexterms].size
        assert_equal ['Big cats', 'Tigers', 'Panthera tigris'], para.document.references[:indexterms].first
      end
    end

    test 'a multi-line index term macro should be compacted and registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ["indexterm:[Panthera\ntigris]", "(((Panthera\ntigris)))"]
      macros.each do |macro|
        para = block_from_string("#{sentence}#{macro}")
        output = para.sub_macros(para.buffer.join)
        assert_equal sentence, output
        assert_equal 1, para.document.references[:indexterms].size
        assert_equal ['Panthera tigris'], para.document.references[:indexterms].first
      end
    end

    test 'normal substitutions are performed on an index term macro' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[*Tigers*]', '(((*Tigers*)))']
      macros.each do |macro|
        para = block_from_string("#{sentence}#{macro}")
        output = para.apply_normal_subs(para.buffer)
        assert_equal sentence, output
        assert_equal 1, para.document.references[:indexterms].size
        assert_equal ['<strong>Tigers</strong>'], para.document.references[:indexterms].first
      end
    end

    test 'registers multiple index term macros' do
      sentence = "The tiger (Panthera tigris) is the largest cat species."
      macros = "(((Tigers)))\n(((Animals,Cats)))"
      para = block_from_string("#{sentence}\n#{macros}")
      output = para.sub_macros(para.buffer.join)
      assert_equal sentence, output.rstrip
      assert_equal 2, para.document.references[:indexterms].size
      assert_equal ['Tigers'], para.document.references[:indexterms][0]
      assert_equal ['Animals', 'Cats'], para.document.references[:indexterms][1]
    end

    test 'an index term macro with round bracket syntax may contain round brackets in term' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macro = '(((Tiger (Panthera tigris))))'
      para = block_from_string("#{sentence}#{macro}")
      output = para.sub_macros(para.buffer.join)
      assert_equal sentence, output
      assert_equal 1, para.document.references[:indexterms].size
      assert_equal ['Tiger (Panthera tigris)'], para.document.references[:indexterms].first
    end

    test 'an index term macro with square bracket syntax may contain square brackets in term' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macro = 'indexterm:[Tiger [Panthera tigris\\]]'
      para = block_from_string("#{sentence}#{macro}")
      output = para.sub_macros(para.buffer.join)
      assert_equal sentence, output
      assert_equal 1, para.document.references[:indexterms].size
      assert_equal ['Tiger [Panthera tigris]'], para.document.references[:indexterms].first
    end

    test 'a single-line index term 2 macro should be registered as an index reference and retain term inline' do
      sentence = 'The tiger (Panthera tigris) is the largest cat species.'
      macros = ['The indexterm2:[tiger] (Panthera tigris) is the largest cat species.', 'The ((tiger)) (Panthera tigris) is the largest cat species.']
      macros.each do |macro|
        para = block_from_string(macro)
        output = para.sub_macros(para.buffer.join)
        assert_equal sentence, output
        assert_equal 1, para.document.references[:indexterms].size
        assert_equal ['tiger'], para.document.references[:indexterms].first
      end
    end

    test 'a multi-line index term 2 macro should be compacted and registered as an index reference and retain term inline' do
      sentence = 'The panthera tigris is the largest cat species.'
      macros = ["The indexterm2:[ panthera\ntigris ] is the largest cat species.", "The (( panthera\ntigris )) is the largest cat species."]
      macros.each do |macro|
        para = block_from_string(macro)
        output = para.sub_macros(para.buffer.join)
        assert_equal sentence, output
        assert_equal 1, para.document.references[:indexterms].size
        assert_equal ['panthera tigris'], para.document.references[:indexterms].first
      end
    end

    test 'registers multiple index term 2 macros' do
      sentence = "The ((tiger)) (Panthera tigris) is the largest ((cat)) species."
      para = block_from_string(sentence)
      output = para.sub_macros(para.buffer.join)
      assert_equal 'The tiger (Panthera tigris) is the largest cat species.', output
      assert_equal 2, para.document.references[:indexterms].size
      assert_equal ['tiger'], para.document.references[:indexterms][0]
      assert_equal ['cat'], para.document.references[:indexterms][1]
    end

    test 'normal substitutions are performed on an index term 2 macro' do
      sentence = 'The ((*tiger*)) (Panthera tigris) is the largest cat species.'
      para = block_from_string sentence
      output = para.apply_normal_subs(para.buffer)
      assert_equal 'The <strong>tiger</strong> (Panthera tigris) is the largest cat species.', output
      assert_equal 1, para.document.references[:indexterms].size
      assert_equal ['<strong>tiger</strong>'], para.document.references[:indexterms].first
    end

    test 'index term 2 macro with round bracket syntex should not interfer with index term macro with round bracket syntax' do
      sentence = "The ((panthera tigris)) is the largest cat species.\n(((Big cats,Tigers)))"
      para = block_from_string sentence
      output = para.sub_macros(para.buffer.join)
      assert_equal "The panthera tigris is the largest cat species.\n", output
      terms = para.document.references[:indexterms]
      assert_equal 2, terms.size
      assert_equal ['Big cats', 'Tigers'], terms[0]
      assert_equal ['panthera tigris'], terms[1]
    end

    context 'Button macro' do
      test 'btn macro' do
        para = block_from_string('btn:[Save]', :attributes => {'experimental' => ''})
        assert_equal %q{<b class="button">Save</b>}, para.sub_macros(para.buffer.join)
      end

      test 'btn macro for docbook backend' do
        para = block_from_string('btn:[Save]', :backend => 'docbook', :attributes => {'experimental' => ''})
        assert_equal %q{<guibutton>Save</guibutton>}, para.sub_macros(para.buffer.join)
      end
    end

    context 'Keyboard macro' do
      test 'kbd macro with single key' do
        para = block_from_string('kbd:[F3]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd>F3</kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with single key, docbook backend' do
        para = block_from_string('kbd:[F3]', :backend => 'docbook', :attributes => {'experimental' => ''})
        assert_equal %q{<keycap>F3</keycap>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination' do
        para = block_from_string('kbd:[Ctrl+Shift+T]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd class="keyseq"><kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd></kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination with spaces' do
        para = block_from_string('kbd:[Ctrl + Shift + T]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd class="keyseq"><kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd></kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination delimited by commas' do
        para = block_from_string('kbd:[Ctrl,Shift,T]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd class="keyseq"><kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd></kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination containing a plus key no spaces' do
        para = block_from_string('kbd:[Ctrl++]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd class="keyseq"><kbd>Ctrl</kbd>+<kbd>+</kbd></kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination delimited by commands containing a comma key' do
        para = block_from_string('kbd:[Ctrl,,]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd class="keyseq"><kbd>Ctrl</kbd>+<kbd>,</kbd></kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination containing a plus key with spaces' do
        para = block_from_string('kbd:[Ctrl + +]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd class="keyseq"><kbd>Ctrl</kbd>+<kbd>+</kbd></kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination containing escaped bracket' do
        para = block_from_string('kbd:[Ctrl + \]]', :attributes => {'experimental' => ''})
        assert_equal %q{<kbd class="keyseq"><kbd>Ctrl</kbd>+<kbd>]</kbd></kbd>}, para.sub_macros(para.buffer.join)
      end
  
      test 'kbd macro with key combination, docbook backend' do
        para = block_from_string('kbd:[Ctrl+Shift+T]', :backend => 'docbook', :attributes => {'experimental' => ''})
        assert_equal %q{<keycombo><keycap>Ctrl</keycap><keycap>Shift</keycap><keycap>T</keycap></keycombo>}, para.sub_macros(para.buffer.join)
      end
    end

    context 'Menu macro' do
      test 'should process menu using macro sytnax' do
        para = block_from_string('menu:File[]', :attributes => {'experimental' => ''})
        assert_equal %q{<span class="menu">File</span>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu for docbook backend' do
        para = block_from_string('menu:File[]', :backend => 'docbook', :attributes => {'experimental' => ''})
        assert_equal %q{<guimenu>File</guimenu>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu with menu item using macro syntax' do
        para = block_from_string('menu:File[Save As&#8230;]', :attributes => {'experimental' => ''})
        assert_equal %q{<span class="menuseq"><span class="menu">File</span>&#160;&#9656; <span class="menuitem">Save As&#8230;</span></span>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu with menu item for docbook backend' do
        para = block_from_string('menu:File[Save As&#8230;]', :backend => 'docbook', :attributes => {'experimental' => ''})
        assert_equal %q{<menuchoice><guimenu>File</guimenu> <guimenuitem>Save As&#8230;</guimenuitem></menuchoice>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu with menu item in submenu using macro syntax' do
        para = block_from_string('menu:Tools[Project &gt; Build]', :attributes => {'experimental' => ''})
        assert_equal %q{<span class="menuseq"><span class="menu">Tools</span>&#160;&#9656; <span class="submenu">Project</span>&#160;&#9656; <span class="menuitem">Build</span></span>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu with menu item in submenu for docbook backend' do
        para = block_from_string('menu:Tools[Project &gt; Build]', :backend => 'docbook', :attributes => {'experimental' => ''})
        assert_equal %q{<menuchoice><guimenu>Tools</guimenu> <guisubmenu>Project</guisubmenu> <guimenuitem>Build</guimenuitem></menuchoice>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu with menu item in submenu using macro syntax and comma delimiter' do
        para = block_from_string('menu:Tools[Project, Build]', :attributes => {'experimental' => ''})
        assert_equal %q{<span class="menuseq"><span class="menu">Tools</span>&#160;&#9656; <span class="submenu">Project</span>&#160;&#9656; <span class="menuitem">Build</span></span>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu with menu item using inline syntax' do
        para = block_from_string('"File &gt; Save As&#8230;"', :attributes => {'experimental' => ''})
        assert_equal %q{<span class="menuseq"><span class="menu">File</span>&#160;&#9656; <span class="menuitem">Save As&#8230;</span></span>}, para.sub_macros(para.buffer.join)
      end

      test 'should process menu with menu item in submenu using inline syntax' do
        para = block_from_string('"Tools &gt; Project &gt; Build"', :attributes => {'experimental' => ''})
        assert_equal %q{<span class="menuseq"><span class="menu">Tools</span>&#160;&#9656; <span class="submenu">Project</span>&#160;&#9656; <span class="menuitem">Build</span></span>}, para.sub_macros(para.buffer.join)
      end

      test 'inline syntax should not closing quote of XML attribute' do
        para = block_from_string('<span class="xmltag">&lt;node&gt;</span><span class="classname">r</span>', :attributes => {'experimental' => ''})
        assert_equal %q{<span class="xmltag">&lt;node&gt;</span><span class="classname">r</span>}, para.sub_macros(para.buffer.join)
      end
    end
  end

  context 'Passthroughs' do
    test 'collect inline triple plus passthroughs' do
      para = block_from_string('+++<code>inline code</code>+++')
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\e" + '0' + "\e", result
      assert_equal 1, para.passthroughs.size
      assert_equal '<code>inline code</code>', para.passthroughs.first[:text]
      assert para.passthroughs.first[:subs].empty?
    end

    test 'collect multi-line inline triple plus passthroughs' do
      para = block_from_string("+++<code>inline\ncode</code>+++")
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\e" + '0' + "\e", result
      assert_equal 1, para.passthroughs.size
      assert_equal "<code>inline\ncode</code>", para.passthroughs.first[:text]
      assert para.passthroughs.first[:subs].empty?
    end

    test 'collect inline double dollar passthroughs' do
      para = block_from_string('$$<code>{code}</code>$$')
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\e" + '0' + "\e", result
      assert_equal 1, para.passthroughs.size
      assert_equal '<code>{code}</code>', para.passthroughs.first[:text]
      assert_equal [:specialcharacters], para.passthroughs.first[:subs]
    end

    test 'collect multi-line inline double dollar passthroughs' do
      para = block_from_string("$$<code>\n{code}\n</code>$$")
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\e" + '0' + "\e", result
      assert_equal 1, para.passthroughs.size
      assert_equal "<code>\n{code}\n</code>", para.passthroughs.first[:text]
      assert_equal [:specialcharacters], para.passthroughs.first[:subs]
    end

    test 'collect passthroughs from inline pass macro' do
      para = block_from_string(%Q{pass:specialcharacters,quotes[<code>['code'\\]</code>]})
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\e" + '0' + "\e", result
      assert_equal 1, para.passthroughs.size
      assert_equal %q{<code>['code']</code>}, para.passthroughs.first[:text]
      assert_equal [:specialcharacters, :quotes], para.passthroughs.first[:subs]
    end

    test 'collect multi-line passthroughs from inline pass macro' do
      para = block_from_string(%Q{pass:specialcharacters,quotes[<code>['more\ncode'\\]</code>]})
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\e" + '0' + "\e", result
      assert_equal 1, para.passthroughs.size
      assert_equal %Q{<code>['more\ncode']</code>}, para.passthroughs.first[:text]
      assert_equal [:specialcharacters, :quotes], para.passthroughs.first[:subs]
    end

    # NOTE placeholder is surrounded by text to prevent reader from stripping trailing boundary char (unique to test scenario)
    test 'restore inline passthroughs without subs' do
      para = block_from_string("some \e" + '0' + "\e to study")
      para.passthroughs << {:text => '<code>inline code</code>', :subs => []}
      result = para.restore_passthroughs(para.buffer.join)
      assert_equal "some <code>inline code</code> to study", result
    end

    # NOTE placeholder is surrounded by text to prevent reader from stripping trailing boundary char (unique to test scenario)
    test 'restore inline passthroughs with subs' do
      para = block_from_string("some \e" + '0' + "\e to study in the \e" + '1' + "\e programming language")
      para.passthroughs << {:text => '<code>{code}</code>', :subs => [:specialcharacters]}
      para.passthroughs << {:text => '{language}', :subs => [:specialcharacters]}
      result = para.restore_passthroughs(para.buffer.join)
      assert_equal 'some &lt;code&gt;{code}&lt;/code&gt; to study in the {language} programming language', result
    end

    test 'complex inline passthrough macro' do
      text_to_escape = %q{[(] <'basic form'> <'logical operator'> <'basic form'> [)]}
      para = block_from_string %($$#{text_to_escape}$$) 
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal 1, para.passthroughs.size
      assert_equal text_to_escape, para.passthroughs[0][:text]

      text_to_escape_escaped = %q{[(\] <'basic form'> <'logical operator'> <'basic form'> [)\]}
      para = block_from_string %(pass:specialcharacters[#{text_to_escape_escaped}])
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal 1, para.passthroughs.size
      assert_equal text_to_escape, para.passthroughs[0][:text]
    end
  end

  context 'Replacements' do
    test 'unescapes XML entities' do
      para = block_from_string '< &quot; &#34; &#x22; >'
      assert_equal '&lt; &quot; &#34; &#x22; &gt;', para.apply_normal_subs(para.buffer)
    end

    test 'replaces arrows' do
      para = block_from_string '<- -> <= => \<- \-> \<= \=>'
      assert_equal '&#8592; &#8594; &#8656; &#8658; &lt;- -&gt; &lt;= =&gt;', para.apply_normal_subs(para.buffer.join)
    end

    test 'replaces dashes' do
      para = block_from_string %(-- foo foo--bar foo\\--bar foo -- bar foo \\-- bar
stuff in between
-- foo
stuff in between
foo --
stuff in between
foo --)
      expected = %(&#8201;&#8212;&#8201;foo foo&#8212;bar foo--bar foo&#8201;&#8212;&#8201;bar foo -- bar
stuff in between&#8201;&#8212;&#8201;foo
stuff in between
foo&#8201;&#8212;&#8201;stuff in between
foo&#8201;&#8212;&#8201;)
      assert_equal expected, para.sub_replacements(para.buffer.join)
    end

    test 'replaces marks' do
      para = block_from_string '(C) (R) (TM) \(C) \(R) \(TM)' 
      assert_equal '&#169; &#174; &#8482; (C) (R) (TM)', para.sub_replacements(para.buffer.join)
    end

    test 'replaces punctuation' do
      para = block_from_string %(John's Hideout... foo\\'bar)
      assert_equal "John&#8217;s Hideout&#8230; foo'bar", para.sub_replacements(para.buffer.join)
    end
  end

  context 'Post replacements' do
    test 'line break inserted after line with line break character' do
      para = block_from_string("First line +\nSecond line")
      result = para.apply_subs(para.buffer, :post_replacements)
      assert_equal "First line<br>\n", result.first
    end

    test 'line break inserted after line wrap with hardbreaks enabled' do
      para = block_from_string("First line\nSecond line", :attributes => {'hardbreaks' => ''})
      result = para.apply_subs(para.buffer, :post_replacements)
      assert_equal "First line<br>\n", result.first
    end

    test 'line break character stripped from end of line with hardbreaks enabled' do
      para = block_from_string("First line +\nSecond line", :attributes => {'hardbreaks' => ''})
      result = para.apply_subs(para.buffer, :post_replacements)
      assert_equal "First line<br>\n", result.first
    end

    test 'line break not inserted for single line with hardbreaks enabled' do
      para = block_from_string("First line", :attributes => {'hardbreaks' => ''})
      result = para.apply_subs(para.buffer, :post_replacements)
      assert_equal "First line", result.first
    end
  end
end
