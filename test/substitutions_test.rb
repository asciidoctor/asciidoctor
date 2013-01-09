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
      assert_equal %{<em><span class="blue"><a href="http://asciidoc.org">AsciiDoc</a></span></em> &amp; <strong><span class="red">Ruby</span></strong>\n&#167; Making <u>documentation</u> together<br>\nsince &#169; 2012.}, result
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
      assert_equal '<tt>a few &lt;{monospaced}&gt; words</tt>', para.apply_normal_subs(para.buffer)
    end

    test 'escaped single-line constrained monospaced string' do
      para = block_from_string(%q{\`a few <monospaced> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal '`a few &lt;monospaced&gt; words`', para.apply_normal_subs(para.buffer)
    end

    test 'multi-line constrained monospaced string' do
      para = block_from_string(%Q{`a few\n<\{monospaced\}> words`})
      # NOTE must use apply_normal_subs because constrained monospaced is handled as a passthrough
      assert_equal "<tt>a few\n&lt;{monospaced}&gt; words</tt>", para.apply_normal_subs(para.buffer)
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
      assert_equal %q{Git<strong><span class="blue">Hub</span></strong>}, para.sub_quotes(para.buffer.join)
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
      assert_equal %q{<em><span class="gray">Git</span></em>Hub}, para.sub_quotes(para.buffer.join)
    end

    test 'escaped unconstrained emphasis chars with role' do
      para = block_from_string(%q{\[gray]__Git__Hub})
      assert_equal %q{[gray]__Git__Hub}, para.sub_quotes(para.buffer.join)
    end

    test 'single-line unconstrained monospaced chars' do
      para = block_from_string(%q{Git++Hub++})
      assert_equal 'Git<tt>Hub</tt>', para.sub_quotes(para.buffer.join)
    end

    test 'escaped single-line unconstrained monospaced chars' do
      para = block_from_string(%q{Git\++Hub++})
      assert_equal 'Git+<tt>Hub</tt>+', para.sub_quotes(para.buffer.join)
    end

    test 'multi-line unconstrained monospaced chars' do
      para = block_from_string(%Q{Git++\nH\nu\nb++})
      assert_equal "Git<tt>\nH\nu\nb</tt>", para.sub_quotes(para.buffer.join)
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
      para = block_from_string(%Q{x^(n\n+\n1)^})
      assert_equal "x<sup>(n\n+\n1)</sup>", para.sub_quotes(para.buffer.join)
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

    test 'a single-line image macro should be interpreted as an image' do
      para = block_from_string('image:tiger.png[]')
      assert_equal %{<span class="image">\n  <img src="tiger.png" alt="tiger">\n</span>}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line image macro with text should be interpreted as an image with alt text' do
      para = block_from_string('image:tiger.png[Tiger]')
      assert_equal %{<span class="image">\n  <img src="tiger.png" alt="Tiger">\n</span>}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line image macro with text and dimensions should be interpreted as an image with alt text and dimensions' do
      para = block_from_string('image:tiger.png[Tiger, 200, 100]')
      assert_equal %{<span class="image">\n  <img src="tiger.png" alt="Tiger" width="200" height="100">\n</span>}, para.sub_macros(para.buffer.join)
    end

    test 'a single-line image macro with text and link should be interpreted as a linked image with alt text' do
      para = block_from_string('image:tiger.png[Tiger, link="http://en.wikipedia.org/wiki/Tiger"]')
      assert_equal %{<span class="image">\n  <a class="image" href="http://en.wikipedia.org/wiki/Tiger"><img src="tiger.png" alt="Tiger"></a>\n</span>}, para.sub_macros(para.buffer.join)
    end
  end

  context 'Passthroughs' do
    test 'collect inline triple plus passthroughs' do
      para = block_from_string('+++<code>inline code</code>+++')
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\x0" + '0' + "\x0", result
      assert_equal 1, para.passthroughs.size
      assert_equal '<code>inline code</code>', para.passthroughs.first[:text]
      assert para.passthroughs.first[:subs].empty?
    end

    test 'collect multi-line inline triple plus passthroughs' do
      para = block_from_string("+++<code>inline\ncode</code>+++")
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\x0" + '0' + "\x0", result
      assert_equal 1, para.passthroughs.size
      assert_equal "<code>inline\ncode</code>", para.passthroughs.first[:text]
      assert para.passthroughs.first[:subs].empty?
    end

    test 'collect inline double dollar passthroughs' do
      para = block_from_string('$$<code>{code}</code>$$')
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\x0" + '0' + "\x0", result
      assert_equal 1, para.passthroughs.size
      assert_equal '<code>{code}</code>', para.passthroughs.first[:text]
      assert_equal [:specialcharacters], para.passthroughs.first[:subs]
    end

    test 'collect multi-line inline double dollar passthroughs' do
      para = block_from_string("$$<code>\n{code}\n</code>$$")
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\x0" + '0' + "\x0", result
      assert_equal 1, para.passthroughs.size
      assert_equal "<code>\n{code}\n</code>", para.passthroughs.first[:text]
      assert_equal [:specialcharacters], para.passthroughs.first[:subs]
    end

    test 'collect passthroughs from inline pass macro' do
      para = block_from_string(%Q{pass:specialcharacters,quotes[<code>['code'\\]</code>]})
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\x0" + '0' + "\x0", result
      assert_equal 1, para.passthroughs.size
      assert_equal %q{<code>['code']</code>}, para.passthroughs.first[:text]
      assert_equal [:specialcharacters, :quotes], para.passthroughs.first[:subs]
    end

    test 'collect multi-line passthroughs from inline pass macro' do
      para = block_from_string(%Q{pass:specialcharacters,quotes[<code>['more\ncode'\\]</code>]})
      result = para.extract_passthroughs(para.buffer.join)
      assert_equal "\x0" + '0' + "\x0", result
      assert_equal 1, para.passthroughs.size
      assert_equal %Q{<code>['more\ncode']</code>}, para.passthroughs.first[:text]
      assert_equal [:specialcharacters, :quotes], para.passthroughs.first[:subs]
    end

    test 'restore inline passthroughs without subs' do
      para = block_from_string("\x0" + '0' + "\x0")
      para.passthroughs << {:text => '<code>inline code</code>', :subs => []}
      result = para.restore_passthroughs(para.buffer.join)
      assert_equal '<code>inline code</code>', result
    end

    # TODO add two entries to ensure index lookup is working correctly (0 indx could be ambiguous)
    test 'restore inline passthroughs with subs' do
      para = block_from_string("\x0" + '0' + "\x0")
      para.passthroughs << {:text => '<code>{code}</code>', :subs => [:specialcharacters]}
      result = para.restore_passthroughs(para.buffer.join)
      assert_equal '&lt;code&gt;{code}&lt;/code&gt;', result
    end
  end

  context 'Post replacements' do
    test 'line break' do
      para = block_from_string("First line +\nSecond line")
      result = para.apply_subs(para.buffer, :post_replacements)
      assert_equal "First line<br>\n", result.first
    end
  end
end
