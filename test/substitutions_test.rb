# frozen_string_literal: true

require_relative 'test_helper'

# TODO
# - test negatives
# - test role on every quote type
context 'Substitutions' do
  BACKSLASH = ?\\
  context 'Dispatcher' do
    test 'apply normal substitutions' do
      para = block_from_string "[blue]_http://asciidoc.org[AsciiDoc]_ & [red]*Ruby*\n&#167; Making +++<u>documentation</u>+++ together +\nsince (C) {inception_year}."
      para.document.attributes['inception_year'] = '2012'
      result = para.apply_subs para.source
      assert_equal %(<em class="blue"><a href="http://asciidoc.org">AsciiDoc</a></em> &amp; <strong class="red">Ruby</strong>\n&#167; Making <u>documentation</u> together<br>\nsince &#169; 2012.), result
    end

    test 'apply_subs should not modify string directly' do
      input = '<html> -- the root of all web'
      para = block_from_string input
      para_source = para.source
      result = para.apply_subs para_source
      assert_equal '&lt;html&gt;&#8201;&#8212;&#8201;the root of all web', result
      assert_equal input, para_source
    end

    test 'should not drop trailing blank lines when performing substitutions' do
      para = block_from_string %([%hardbreaks]\nthis\nis\n-> {program})
      para.lines << ''
      para.lines << ''
      para.document.attributes['program'] = 'Asciidoctor'
      result = para.apply_subs para.lines
      assert_equal ['this<br>', 'is<br>', '&#8594; Asciidoctor<br>', '<br>', ''], result
      result = para.apply_subs para.lines * "\n"
      assert_equal %(this<br>\nis<br>\n&#8594; Asciidoctor<br>\n<br>\n), result
    end

    test 'should expand subs passed to expand_subs' do
      para = block_from_string %({program}\n*bold*\n2 > 1)
      para.document.attributes['program'] = 'Asciidoctor'
      assert_equal [:specialcharacters], (para.expand_subs [:specialchars])
      refute para.expand_subs([:none])
      assert_equal [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements], (para.expand_subs [:normal])
    end

    test 'apply_subs should allow the subs argument to be nil' do
      block = block_from_string %([pass]\n*raw*)
      result = block.apply_subs block.source, nil
      assert_equal '*raw*', result
    end
  end

  context 'Quotes' do
    test 'single-line double-quoted string' do
      para = block_from_string %q(``a few quoted words''), attributes: { 'compat-mode' => '' }
      assert_equal '&#8220;a few quoted words&#8221;', para.sub_quotes(para.source)

      para = block_from_string '"`a few quoted words`"'
      assert_equal '&#8220;a few quoted words&#8221;', para.sub_quotes(para.source)

      para = block_from_string '"`a few quoted words`"', backend: 'docbook'
      assert_equal '<quote role="double">a few quoted words</quote>', para.sub_quotes(para.source)
    end

    test 'escaped single-line double-quoted string' do
      para = block_from_string %(#{BACKSLASH}``a few quoted words''), attributes: { 'compat-mode' => '' }
      assert_equal %q(&#8216;`a few quoted words&#8217;'), para.sub_quotes(para.source)

      para = block_from_string %(#{BACKSLASH * 2}``a few quoted words''), attributes: { 'compat-mode' => '' }
      assert_equal %q(``a few quoted words''), para.sub_quotes(para.source)

      para = block_from_string %(#{BACKSLASH}"`a few quoted words`")
      assert_equal '"`a few quoted words`"', para.sub_quotes(para.source)

      para = block_from_string %(#{BACKSLASH * 2}"`a few quoted words`")
      assert_equal %(#{BACKSLASH}"`a few quoted words`"), para.sub_quotes(para.source)
    end

    test 'multi-line double-quoted string' do
      para = block_from_string %(``a few\nquoted words''), attributes: { 'compat-mode' => '' }
      assert_equal %(&#8220;a few\nquoted words&#8221;), para.sub_quotes(para.source)

      para = block_from_string %("`a few\nquoted words`")
      assert_equal %(&#8220;a few\nquoted words&#8221;), para.sub_quotes(para.source)
    end

    test 'double-quoted string with inline single quote' do
      para = block_from_string %q(``Here's Johnny!''), attributes: { 'compat-mode' => '' }
      assert_equal %q(&#8220;Here's Johnny!&#8221;), para.sub_quotes(para.source)

      para = block_from_string %q("`Here's Johnny!`")
      assert_equal %q(&#8220;Here's Johnny!&#8221;), para.sub_quotes(para.source)
    end

    test 'double-quoted string with inline backquote' do
      para = block_from_string %q(``Here`s Johnny!''), attributes: { 'compat-mode' => '' }
      assert_equal '&#8220;Here`s Johnny!&#8221;', para.sub_quotes(para.source)

      para = block_from_string '"`Here`s Johnny!`"'
      assert_equal '&#8220;Here`s Johnny!&#8221;', para.sub_quotes(para.source)
    end

    test 'double-quoted string around monospaced text' do
      para = block_from_string '"``E=mc^2^` is the solution!`"'
      assert_equal '&#8220;`E=mc<sup>2</sup>` is the solution!&#8221;', para.apply_subs(para.source)

      para = block_from_string '"```E=mc^2^`` is the solution!`"'
      assert_equal '&#8220;<code>E=mc<sup>2</sup></code> is the solution!&#8221;', para.apply_subs(para.source)
    end

    test 'single-line single-quoted string' do
      para = block_from_string %q(`a few quoted words'), attributes: { 'compat-mode' => '' }
      assert_equal '&#8216;a few quoted words&#8217;', para.sub_quotes(para.source)

      para = block_from_string %q('`a few quoted words`')
      assert_equal '&#8216;a few quoted words&#8217;', para.sub_quotes(para.source)

      para = block_from_string %q('`a few quoted words`'), backend: 'docbook'
      assert_equal '<quote role="single">a few quoted words</quote>', para.sub_quotes(para.source)
    end

    test 'escaped single-line single-quoted string' do
      para = block_from_string %(#{BACKSLASH}`a few quoted words'), attributes: { 'compat-mode' => '' }
      assert_equal %(`a few quoted words'), para.sub_quotes(para.source)

      para = block_from_string %(#{BACKSLASH}'`a few quoted words`')
      assert_equal %('`a few quoted words`'), para.sub_quotes(para.source)
    end

    test 'multi-line single-quoted string' do
      para = block_from_string %(`a few\nquoted words'), attributes: { 'compat-mode' => '' }
      assert_equal %(&#8216;a few\nquoted words&#8217;), para.sub_quotes(para.source)

      para = block_from_string %('`a few\nquoted words`')
      assert_equal %(&#8216;a few\nquoted words&#8217;), para.sub_quotes(para.source)
    end

    test 'single-quoted string with inline single quote' do
      para = block_from_string %q(`That isn't what I did.'), attributes: { 'compat-mode' => '' }
      assert_equal %q(&#8216;That isn't what I did.&#8217;), para.sub_quotes(para.source)

      para = block_from_string %q('`That isn't what I did.`')
      assert_equal %q(&#8216;That isn't what I did.&#8217;), para.sub_quotes(para.source)
    end

    test 'single-quoted string with inline backquote' do
      para = block_from_string %q(`Here`s Johnny!'), attributes: { 'compat-mode' => '' }
      assert_equal '&#8216;Here`s Johnny!&#8217;', para.sub_quotes(para.source)

      para = block_from_string %q('`Here`s Johnny!`')
      assert_equal '&#8216;Here`s Johnny!&#8217;', para.sub_quotes(para.source)
    end

    test 'single-line constrained marked string' do
      #para = block_from_string('#a few words#', attributes: { 'compat-mode' => '' })
      #assert_equal 'a few words', para.sub_quotes(para.source)

      para = block_from_string '#a few words#'
      assert_equal '<mark>a few words</mark>', para.sub_quotes(para.source)
    end

    test 'escaped single-line constrained marked string' do
      para = block_from_string %(#{BACKSLASH}#a few words#)
      assert_equal '#a few words#', para.sub_quotes(para.source)
    end

    test 'multi-line constrained marked string' do
      #para = block_from_string %(#a few\nwords#), attributes: { 'compat-mode' => '' }
      #assert_equal %(a few\nwords), para.sub_quotes(para.source)

      para = block_from_string %(#a few\nwords#)
      assert_equal %(<mark>a few\nwords</mark>), para.sub_quotes(para.source)
    end

    test 'constrained marked string should not match entity references' do
      para = block_from_string '111 #mark a# 222 "`quote a`" 333 #mark b# 444'
      assert_equal %(111 <mark>mark a</mark> 222 &#8220;quote a&#8221; 333 <mark>mark b</mark> 444), para.sub_quotes(para.source)
    end

    test 'single-line unconstrained marked string' do
      #para = block_from_string('##--anything goes ##', attributes: { 'compat-mode' => '' })
      #assert_equal '--anything goes ', para.sub_quotes(para.source)

      para = block_from_string '##--anything goes ##'
      assert_equal '<mark>--anything goes </mark>', para.sub_quotes(para.source)
    end

    test 'escaped single-line unconstrained marked string' do
      para = block_from_string %(#{BACKSLASH}#{BACKSLASH}##--anything goes ##)
      assert_equal '##--anything goes ##', para.sub_quotes(para.source)
    end

    test 'multi-line unconstrained marked string' do
      #para = block_from_string %(##--anything\ngoes ##), attributes: { 'compat-mode' => '' }
      #assert_equal %(--anything\ngoes ), para.sub_quotes(para.source)

      para = block_from_string %(##--anything\ngoes ##)
      assert_equal %(<mark>--anything\ngoes </mark>), para.sub_quotes(para.source)
    end

    test 'single-line constrained marked string with role' do
      para = block_from_string '[statement]#a few words#'
      assert_equal '<span class="statement">a few words</span>', para.sub_quotes(para.source)
    end

    test 'does not recognize attribute list with left square bracket on formatted text' do
      para = block_from_string 'key: [ *before [.redacted]#redacted# after* ]'
      assert_equal 'key: [ <strong>before <span class="redacted">redacted</span> after</strong> ]', para.sub_quotes(para.source)
    end

    test 'should ignore enclosing square brackets when processing formatted text with attribute list' do
      doc = document_from_string 'nums = [1, 2, 3, [.blue]#4#]', doctype: :inline
      assert_equal 'nums = [1, 2, 3, <span class="blue">4</span>]', doc.convert
    end

    test 'single-line constrained strong string' do
      para = block_from_string '*a few strong words*'
      assert_equal '<strong>a few strong words</strong>', para.sub_quotes(para.source)
    end

    test 'escaped single-line constrained strong string' do
      para = block_from_string %(#{BACKSLASH}*a few strong words*)
      assert_equal '*a few strong words*', para.sub_quotes(para.source)
    end

    test 'multi-line constrained strong string' do
      para = block_from_string %(*a few\nstrong words*)
      assert_equal %(<strong>a few\nstrong words</strong>), para.sub_quotes(para.source)
    end

    test 'constrained strong string containing an asterisk' do
      para = block_from_string '*bl*ck*-eye'
      assert_equal '<strong>bl*ck</strong>-eye', para.sub_quotes(para.source)
    end

    test 'constrained strong string containing an asterisk and multibyte word chars' do
      para = block_from_string '*黑*眼圈*'
      assert_equal '<strong>黑*眼圈</strong>', para.sub_quotes(para.source)
    end

    test 'single-line constrained quote variation emphasized string' do
      para = block_from_string '_a few emphasized words_'
      assert_equal '<em>a few emphasized words</em>', para.sub_quotes(para.source)
    end

    test 'escaped single-line constrained quote variation emphasized string' do
      para = block_from_string %(#{BACKSLASH}_a few emphasized words_)
      assert_equal '_a few emphasized words_', para.sub_quotes(para.source)
    end

    test 'escaped single quoted string' do
      para = block_from_string %(#{BACKSLASH}'a few emphasized words')
      # NOTE the \' is replaced with ' by the :replacements substitution, later in the substitution pipeline
      assert_equal %(#{BACKSLASH}'a few emphasized words'), para.sub_quotes(para.source)
    end

    test 'multi-line constrained emphasized quote variation string' do
      para = block_from_string %(_a few\nemphasized words_)
      assert_equal %(<em>a few\nemphasized words</em>), para.sub_quotes(para.source)
    end

    test 'single-quoted string containing an emphasized phrase' do
      para = block_from_string %q(`I told him, 'Just go for it!''), attributes: { 'compat-mode' => '' }
      assert_equal '&#8216;I told him, <em>Just go for it!</em>&#8217;', para.sub_quotes(para.source)

      para = block_from_string %q('`I told him, 'Just go for it!'`')
      assert_equal %q(&#8216;I told him, 'Just go for it!'&#8217;), para.sub_quotes(para.source)
    end

    test 'escaped single-quotes inside emphasized words are restored' do
      para = block_from_string %('Here#{BACKSLASH}'s Johnny!'), attributes: { 'compat-mode' => '' }
      assert_equal %q(<em>Here's Johnny!</em>), para.apply_subs(para.source)

      para = block_from_string %('Here#{BACKSLASH}'s Johnny!')
      assert_equal %q('Here's Johnny!'), para.apply_subs(para.source)
    end

    test 'single-line constrained emphasized underline variation string' do
      para = block_from_string '_a few emphasized words_'
      assert_equal '<em>a few emphasized words</em>', para.sub_quotes(para.source)
    end

    test 'escaped single-line constrained emphasized underline variation string' do
      para = block_from_string %(#{BACKSLASH}_a few emphasized words_)
      assert_equal '_a few emphasized words_', para.sub_quotes(para.source)
    end

    test 'multi-line constrained emphasized underline variation string' do
      para = block_from_string %(_a few\nemphasized words_)
      assert_equal %(<em>a few\nemphasized words</em>), para.sub_quotes(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'single-line constrained monospaced string' do
      para = block_from_string %(`a few <{monospaced}> words`), attributes: { 'monospaced' => 'monospaced', 'compat-mode' => '' }
      assert_equal '<code>a few &lt;{monospaced}&gt; words</code>', para.apply_subs(para.source)

      para = block_from_string %(`a few <{monospaced}> words`), attributes: { 'monospaced' => 'monospaced' }
      assert_equal '<code>a few &lt;monospaced&gt; words</code>', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'single-line constrained monospaced string with role' do
      para = block_from_string %([input]`a few <{monospaced}> words`), attributes: { 'monospaced' => 'monospaced', 'compat-mode' => '' }
      assert_equal '<code class="input">a few &lt;{monospaced}&gt; words</code>', para.apply_subs(para.source)

      para = block_from_string %([input]`a few <{monospaced}> words`), attributes: { 'monospaced' => 'monospaced' }
      assert_equal '<code class="input">a few &lt;monospaced&gt; words</code>', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'escaped single-line constrained monospaced string' do
      para = block_from_string %(#{BACKSLASH}`a few <monospaced> words`), attributes: { 'compat-mode' => '' }
      assert_equal '`a few &lt;monospaced&gt; words`', para.apply_subs(para.source)

      para = block_from_string %(#{BACKSLASH}`a few <monospaced> words`)
      assert_equal '`a few &lt;monospaced&gt; words`', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'escaped single-line constrained monospaced string with role' do
      para = block_from_string %([input]#{BACKSLASH}`a few <monospaced> words`), attributes: { 'compat-mode' => '' }
      assert_equal '[input]`a few &lt;monospaced&gt; words`', para.apply_subs(para.source)

      para = block_from_string %([input]#{BACKSLASH}`a few <monospaced> words`)
      assert_equal '[input]`a few &lt;monospaced&gt; words`', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'escaped role on single-line constrained monospaced string' do
      para = block_from_string %(#{BACKSLASH}[input]`a few <monospaced> words`), attributes: { 'compat-mode' => '' }
      assert_equal '[input]<code>a few &lt;monospaced&gt; words</code>', para.apply_subs(para.source)

      para = block_from_string %(#{BACKSLASH}[input]`a few <monospaced> words`)
      assert_equal '[input]<code>a few &lt;monospaced&gt; words</code>', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'escaped role on escaped single-line constrained monospaced string' do
      para = block_from_string %(#{BACKSLASH}[input]#{BACKSLASH}`a few <monospaced> words`), attributes: { 'compat-mode' => '' }
      assert_equal %(#{BACKSLASH}[input]`a few &lt;monospaced&gt; words`), para.apply_subs(para.source)

      para = block_from_string %(#{BACKSLASH}[input]#{BACKSLASH}`a few <monospaced> words`)
      assert_equal %(#{BACKSLASH}[input]`a few &lt;monospaced&gt; words`), para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'should ignore role that ends with transitional role on constrained monospace span' do
      para = block_from_string %([foox-]`leave it alone`)
      assert_equal '<code class="foox-">leave it alone</code>', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'escaped single-line constrained monospace string with forced compat role' do
      para = block_from_string %([x-]#{BACKSLASH}`leave it alone`)
      assert_equal '[x-]`leave it alone`', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'escaped forced compat role on single-line constrained monospace string' do
      para = block_from_string %(#{BACKSLASH}[x-]`just *mono*`)
      assert_equal '[x-]<code>just <strong>mono</strong></code>', para.apply_subs(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'multi-line constrained monospaced string' do
      para = block_from_string %(`a few\n<{monospaced}> words`), attributes: { 'monospaced' => 'monospaced', 'compat-mode' => '' }
      assert_equal "<code>a few\n&lt;{monospaced}&gt; words</code>", para.apply_subs(para.source)

      para = block_from_string %(`a few\n<{monospaced}> words`), attributes: { 'monospaced' => 'monospaced' }
      assert_equal "<code>a few\n&lt;monospaced&gt; words</code>", para.apply_subs(para.source)
    end

    test 'single-line unconstrained strong chars' do
      para = block_from_string '**Git**Hub'
      assert_equal '<strong>Git</strong>Hub', para.sub_quotes(para.source)
    end

    test 'escaped single-line unconstrained strong chars' do
      para = block_from_string %(#{BACKSLASH}**Git**Hub)
      assert_equal '<strong>*Git</strong>*Hub', para.sub_quotes(para.source)
    end

    test 'multi-line unconstrained strong chars' do
      para = block_from_string %(**G\ni\nt\n**Hub)
      assert_equal %(<strong>G\ni\nt\n</strong>Hub), para.sub_quotes(para.source)
    end

    test 'unconstrained strong chars with inline asterisk' do
      para = block_from_string '**bl*ck**-eye'
      assert_equal '<strong>bl*ck</strong>-eye', para.sub_quotes(para.source)
    end

    test 'unconstrained strong chars with role' do
      para = block_from_string 'Git[blue]**Hub**'
      assert_equal 'Git<strong class="blue">Hub</strong>', para.sub_quotes(para.source)
    end

    # TODO this is not the same result as AsciiDoc, though I don't understand why AsciiDoc gets what it gets
    test 'escaped unconstrained strong chars with role' do
      para = block_from_string %(Git#{BACKSLASH}[blue]**Hub**)
      assert_equal 'Git[blue]<strong>*Hub</strong>*', para.sub_quotes(para.source)
    end

    test 'single-line unconstrained emphasized chars' do
      para = block_from_string '__Git__Hub'
      assert_equal '<em>Git</em>Hub', para.sub_quotes(para.source)
    end

    test 'escaped single-line unconstrained emphasized chars' do
      para = block_from_string %(#{BACKSLASH}__Git__Hub)
      assert_equal '__Git__Hub', para.sub_quotes(para.source)
    end

    test 'escaped single-line unconstrained emphasized chars around word' do
      para = block_from_string %(#{BACKSLASH}#{BACKSLASH}__GitHub__)
      assert_equal '__GitHub__', para.sub_quotes(para.source)
    end

    test 'multi-line unconstrained emphasized chars' do
      para = block_from_string %(__G\ni\nt\n__Hub)
      assert_equal %(<em>G\ni\nt\n</em>Hub), para.sub_quotes(para.source)
    end

    test 'unconstrained emphasis chars with role' do
      para = block_from_string '[gray]__Git__Hub'
      assert_equal '<em class="gray">Git</em>Hub', para.sub_quotes(para.source)
    end

    test 'escaped unconstrained emphasis chars with role' do
      para = block_from_string %(#{BACKSLASH}[gray]__Git__Hub)
      assert_equal '[gray]__Git__Hub', para.sub_quotes(para.source)
    end

    test 'single-line constrained monospaced chars' do
      para = block_from_string 'call +save()+ to persist the changes', attributes: { 'compat-mode' => '' }
      assert_equal 'call <code>save()</code> to persist the changes', para.sub_quotes(para.source)

      para = block_from_string 'call [x-]+save()+ to persist the changes'
      assert_equal 'call <code>save()</code> to persist the changes', para.apply_subs(para.source)

      para = block_from_string 'call `save()` to persist the changes'
      assert_equal 'call <code>save()</code> to persist the changes', para.sub_quotes(para.source)
    end

    test 'single-line constrained monospaced chars with role' do
      para = block_from_string 'call [method]+save()+ to persist the changes', attributes: { 'compat-mode' => '' }
      assert_equal 'call <code class="method">save()</code> to persist the changes', para.sub_quotes(para.source)

      para = block_from_string 'call [method x-]+save()+ to persist the changes'
      assert_equal 'call <code class="method">save()</code> to persist the changes', para.apply_subs(para.source)

      para = block_from_string 'call [method]`save()` to persist the changes'
      assert_equal 'call <code class="method">save()</code> to persist the changes', para.sub_quotes(para.source)
    end

    test 'escaped single-line constrained monospaced chars' do
      para = block_from_string %(call #{BACKSLASH}+save()+ to persist the changes), attributes: { 'compat-mode' => '' }
      assert_equal 'call +save()+ to persist the changes', para.sub_quotes(para.source)

      para = block_from_string %(call #{BACKSLASH}`save()` to persist the changes)
      assert_equal 'call `save()` to persist the changes', para.sub_quotes(para.source)
    end

    test 'escaped single-line constrained monospaced chars with role' do
      para = block_from_string %(call [method]#{BACKSLASH}+save()+ to persist the changes), attributes: { 'compat-mode' => '' }
      assert_equal 'call [method]+save()+ to persist the changes', para.sub_quotes(para.source)

      para = block_from_string %(call [method]#{BACKSLASH}`save()` to persist the changes)
      assert_equal 'call [method]`save()` to persist the changes', para.sub_quotes(para.source)
    end

    test 'escaped role on single-line constrained monospaced chars' do
      para = block_from_string %(call #{BACKSLASH}[method]+save()+ to persist the changes), attributes: { 'compat-mode' => '' }
      assert_equal 'call [method]<code>save()</code> to persist the changes', para.sub_quotes(para.source)

      para = block_from_string %(call #{BACKSLASH}[method]`save()` to persist the changes)
      assert_equal 'call [method]<code>save()</code> to persist the changes', para.sub_quotes(para.source)
    end

    test 'escaped role on escaped single-line constrained monospaced chars' do
      para = block_from_string %(call #{BACKSLASH}[method]#{BACKSLASH}+save()+ to persist the changes), attributes: { 'compat-mode' => '' }
      assert_equal %(call #{BACKSLASH}[method]+save()+ to persist the changes), para.sub_quotes(para.source)

      para = block_from_string %(call #{BACKSLASH}[method]#{BACKSLASH}`save()` to persist the changes)
      assert_equal %(call #{BACKSLASH}[method]`save()` to persist the changes), para.sub_quotes(para.source)
    end

    # NOTE must use apply_subs because constrained monospaced is handled as a passthrough
    test 'escaped single-line constrained passthrough string with forced compat role' do
      para = block_from_string %([x-]#{BACKSLASH}+leave it alone+)
      assert_equal '[x-]+leave it alone+', para.apply_subs(para.source)
    end

    test 'single-line unconstrained monospaced chars' do
      para = block_from_string 'Git++Hub++', attributes: { 'compat-mode' => '' }
      assert_equal 'Git<code>Hub</code>', para.sub_quotes(para.source)

      para = block_from_string 'Git[x-]++Hub++'
      assert_equal 'Git<code>Hub</code>', para.apply_subs(para.source)

      para = block_from_string 'Git``Hub``'
      assert_equal 'Git<code>Hub</code>', para.sub_quotes(para.source)
    end

    test 'escaped single-line unconstrained monospaced chars' do
      para = block_from_string %(Git#{BACKSLASH}++Hub++), attributes: { 'compat-mode' => '' }
      assert_equal 'Git+<code>Hub</code>+', para.sub_quotes(para.source)

      para = block_from_string %(Git#{BACKSLASH * 2}++Hub++), attributes: { 'compat-mode' => '' }
      assert_equal 'Git++Hub++', para.sub_quotes(para.source)

      para = block_from_string %(Git#{BACKSLASH}``Hub``)
      assert_equal 'Git``Hub``', para.sub_quotes(para.source)
    end

    test 'multi-line unconstrained monospaced chars' do
      para = block_from_string %(Git++\nH\nu\nb++), attributes: { 'compat-mode' => '' }
      assert_equal %(Git<code>\nH\nu\nb</code>), para.sub_quotes(para.source)

      para = block_from_string %(Git[x-]++\nH\nu\nb++)
      assert_equal %(Git<code>\nH\nu\nb</code>), para.apply_subs(para.source)

      para = block_from_string %(Git``\nH\nu\nb``)
      assert_equal %(Git<code>\nH\nu\nb</code>), para.sub_quotes(para.source)
    end

    test 'single-line superscript chars' do
      para = block_from_string %(x^2^ = x * x, e = mc^2^, there's a 1^st^ time for everything)
      assert_equal %(x<sup>2</sup> = x * x, e = mc<sup>2</sup>, there\'s a 1<sup>st</sup> time for everything), para.sub_quotes(para.source)
    end

    test 'escaped single-line superscript chars' do
      para = block_from_string %(x#{BACKSLASH}^2^ = x * x)
      assert_equal 'x^2^ = x * x', para.sub_quotes(para.source)
    end

    test 'does not match superscript across whitespace' do
      para = block_from_string %(x^(n\n-\n1)^)
      assert_equal para.source, para.sub_quotes(para.source)
    end

    test 'allow spaces in superscript if spaces are inserted using an attribute reference' do
      para = block_from_string 'Night ^A{sp}poem{sp}by{sp}Jane{sp}Kondo^.'
      assert_equal 'Night <sup>A poem by Jane Kondo</sup>.', para.apply_subs(para.source)
    end

    test 'allow spaces in superscript if text is wrapped in a passthrough' do
      para = block_from_string 'Night ^+A poem by Jane Kondo+^.'
      assert_equal 'Night <sup>A poem by Jane Kondo</sup>.', para.apply_subs(para.source)
    end

    test 'does not match adjacent superscript chars' do
      para = block_from_string 'a ^^ b'
      assert_equal 'a ^^ b', para.sub_quotes(para.source)
    end

    test 'does not confuse superscript and links with blank window shorthand' do
      para = block_from_string 'http://localhost[Text^] on the 21^st^ and 22^nd^'
      assert_equal '<a href="http://localhost" target="_blank" rel="noopener">Text</a> on the 21<sup>st</sup> and 22<sup>nd</sup>', para.content
    end

    test 'single-line subscript chars' do
      para = block_from_string 'H~2~O'
      assert_equal 'H<sub>2</sub>O', para.sub_quotes(para.source)
    end

    test 'escaped single-line subscript chars' do
      para = block_from_string %(H#{BACKSLASH}~2~O)
      assert_equal 'H~2~O', para.sub_quotes(para.source)
    end

    test 'does not match subscript across whitespace' do
      para = block_from_string %(project~ view\non\nGitHub~)
      assert_equal para.source, para.sub_quotes(para.source)
    end

    test 'does not match adjacent subscript chars' do
      para = block_from_string 'a ~~ b'
      assert_equal 'a ~~ b', para.sub_quotes(para.source)
    end

    test 'does not match subscript across distinct URLs' do
      para = block_from_string 'http://www.abc.com/~def[DEF] and http://www.abc.com/~ghi[GHI]'
      assert_equal para.source, para.sub_quotes(para.source)
    end

    test 'quoted text with role shorthand' do
      para = block_from_string '[.white.red-background]#alert#'
      assert_equal '<span class="white red-background">alert</span>', para.sub_quotes(para.source)
    end

    test 'quoted text with id shorthand' do
      para = block_from_string '[#bond]#007#'
      assert_equal '<span id="bond">007</span>', para.sub_quotes(para.source)
    end

    test 'quoted text with id and role shorthand' do
      para = block_from_string '[#bond.white.red-background]#007#'
      assert_equal '<span id="bond" class="white red-background">007</span>', para.sub_quotes(para.source)
    end

    test 'quoted text with id and role shorthand with roles before id' do
      para = block_from_string '[.white.red-background#bond]#007#'
      assert_equal '<span id="bond" class="white red-background">007</span>', para.sub_quotes(para.source)
    end

    test 'quoted text with id and role shorthand with roles around id' do
      para = block_from_string '[.white#bond.red-background]#007#'
      assert_equal '<span id="bond" class="white red-background">007</span>', para.sub_quotes(para.source)
    end

    test 'quoted text with id and role shorthand using docbook backend' do
      para = block_from_string '[#bond.white.red-background]#007#', backend: 'docbook'
      assert_equal '<anchor xml:id="bond" xreflabel="007"/><phrase role="white red-background">007</phrase>', para.sub_quotes(para.source)
    end

    test 'should not assign role attribute if shorthand style has no roles' do
      para = block_from_string '[#idname]*blah*'
      assert_equal '<strong id="idname">blah</strong>', para.content
    end

    test 'should remove trailing spaces from role defined using shorthand' do
      para = block_from_string '[.rolename ]*blah*'
      assert_equal '<strong class="rolename">blah</strong>', para.content
    end

    test 'should allow role to be defined using attribute reference' do
      input = '[{rolename}]#phrase#'
      result = convert_string_to_embedded input, doctype: 'inline', attributes: { 'rolename' => 'red' }
      assert_equal '<span class="red">phrase</span>', result
    end

    test 'should ignore attributes after comma' do
      para = block_from_string '[red, foobar]#alert#'
      assert_equal '<span class="red">alert</span>', para.sub_quotes(para.source)
    end

    test 'should remove leading and trailing spaces around role after ignoring attributes after comma' do
      para = block_from_string '[ red , foobar]#alert#'
      assert_equal '<span class="red">alert</span>', para.sub_quotes(para.source)
    end

    test 'should not assign role if value before comma is empty' do
      para = block_from_string '[,]#anonymous#'
      assert_equal 'anonymous', para.sub_quotes(para.source)
    end

    test 'inline passthrough with id and role set using shorthand' do
      %w(#idname.rolename .rolename#idname).each do |attrlist|
        para = block_from_string %([#{attrlist}]+pass+)
        assert_equal '<span id="idname" class="rolename">pass</span>', para.content
      end
    end
  end

  context 'Macros' do
    test 'a single-line link macro should be interpreted as a link' do
      para = block_from_string 'link:/home.html[]'
      assert_equal '<a href="/home.html" class="bare">/home.html</a>', para.sub_macros(para.source)
    end

    test 'a single-line link macro with text should be interpreted as a link' do
      para = block_from_string 'link:/home.html[Home]'
      assert_equal '<a href="/home.html">Home</a>', para.sub_macros(para.source)
    end

    test 'a mailto macro should be interpreted as a mailto link' do
      para = block_from_string 'mailto:doc.writer@asciidoc.org[]'
      assert_equal '<a href="mailto:doc.writer@asciidoc.org">doc.writer@asciidoc.org</a>', para.sub_macros(para.source)
    end

    test 'a mailto macro with text should be interpreted as a mailto link' do
      para = block_from_string 'mailto:doc.writer@asciidoc.org[Doc Writer]'
      assert_equal '<a href="mailto:doc.writer@asciidoc.org">Doc Writer</a>', para.sub_macros(para.source)
    end

    test 'a mailto macro with text and subject should be interpreted as a mailto link' do
      para = block_from_string 'mailto:doc.writer@asciidoc.org[Doc Writer, Pull request]'
      assert_equal '<a href="mailto:doc.writer@asciidoc.org?subject=Pull%20request">Doc Writer</a>', para.sub_macros(para.source)
    end

    test 'a mailto macro with text, subject and body should be interpreted as a mailto link' do
      para = block_from_string 'mailto:doc.writer@asciidoc.org[Doc Writer, Pull request, Please accept my pull request]'
      assert_equal '<a href="mailto:doc.writer@asciidoc.org?subject=Pull%20request&amp;body=Please%20accept%20my%20pull%20request">Doc Writer</a>', para.sub_macros(para.source)
    end

    test 'a mailto macro with subject and body only should use e-mail as text' do
      para = block_from_string 'mailto:doc.writer@asciidoc.org[,Pull request,Please accept my pull request]'
      assert_equal '<a href="mailto:doc.writer@asciidoc.org?subject=Pull%20request&amp;body=Please%20accept%20my%20pull%20request">doc.writer@asciidoc.org</a>', para.sub_macros(para.source)
    end

    test 'a mailto macro supports id and role attributes' do
      para = block_from_string 'mailto:doc.writer@asciidoc.org[,id=contact,role=icon]'
      assert_equal '<a href="mailto:doc.writer@asciidoc.org" id="contact" class="icon">doc.writer@asciidoc.org</a>', para.sub_macros(para.source)
    end

    test 'should recognize inline email addresses' do
      %w(
        doc.writer@asciidoc.org
        author+website@4fs.no
        john@domain.uk.co
        name@somewhere.else.com
        joe_bloggs@mail_server.com
        joe-bloggs@mail-server.com
        joe.bloggs@mail.server.com
        FOO@BAR.COM
        docs@writing.ninja
      ).each do |input|
        para = block_from_string input
        assert_equal %(<a href="mailto:#{input}">#{input}</a>), (para.sub_macros para.source)
      end
    end

    test 'should recognize inline email address containing an ampersand' do
      para = block_from_string 'bert&ernie@sesamestreet.com'
      assert_equal '<a href="mailto:bert&amp;ernie@sesamestreet.com">bert&amp;ernie@sesamestreet.com</a>', para.apply_subs(para.source)
    end

    test 'should recognize inline email address surrounded by angle brackets' do
      para = block_from_string '<doc.writer@asciidoc.org>'
      assert_equal '&lt;<a href="mailto:doc.writer@asciidoc.org">doc.writer@asciidoc.org</a>&gt;', para.apply_subs(para.source)
    end

    test 'should ignore escaped inline email address' do
      para = block_from_string %(#{BACKSLASH}doc.writer@asciidoc.org)
      assert_equal 'doc.writer@asciidoc.org', para.sub_macros(para.source)
    end

    test 'a single-line raw url should be interpreted as a link' do
      para = block_from_string 'http://google.com'
      assert_equal '<a href="http://google.com" class="bare">http://google.com</a>', para.sub_macros(para.source)
    end

    test 'a single-line raw url with text should be interpreted as a link' do
      para = block_from_string 'http://google.com[Google]'
      assert_equal '<a href="http://google.com">Google</a>', para.sub_macros(para.source)
    end

    test 'a multi-line raw url with text should be interpreted as a link' do
      para = block_from_string %(http://google.com[Google\nHomepage])
      assert_equal %(<a href="http://google.com">Google\nHomepage</a>), para.sub_macros(para.source)
    end

    test 'a single-line raw url with attribute as text should be interpreted as a link with resolved attribute' do
      para = block_from_string 'http://google.com[{google_homepage}]'
      para.document.attributes['google_homepage'] = 'Google Homepage'
      assert_equal '<a href="http://google.com">Google Homepage</a>', para.sub_macros(para.sub_attributes(para.source))
    end

    test 'should not resolve an escaped attribute in link text' do
      {
        'http://google.com' => "http://google.com[#{BACKSLASH}{google_homepage}]",
        'http://google.com?q=,' => "link:http://google.com?q=,[#{BACKSLASH}{google_homepage}]",
      }.each do |uri, macro|
        para = block_from_string macro
        para.document.attributes['google_homepage'] = 'Google Homepage'
        assert_equal %(<a href="#{uri}">{google_homepage}</a>), para.sub_macros(para.sub_attributes(para.source))
      end
    end

    test 'a single-line escaped raw url should not be interpreted as a link' do
      para = block_from_string %(#{BACKSLASH}http://google.com)
      assert_equal 'http://google.com', para.sub_macros(para.source)
    end

    test 'a comma separated list of links should not include commas in links' do
      para = block_from_string 'http://foo.com, http://bar.com, http://example.org'
      assert_equal '<a href="http://foo.com" class="bare">http://foo.com</a>, <a href="http://bar.com" class="bare">http://bar.com</a>, <a href="http://example.org" class="bare">http://example.org</a>', para.sub_macros(para.source)
    end

    test 'a single-line image macro should be interpreted as an image' do
      para = block_from_string 'image:tiger.png[]'
      assert_equal '<span class="image"><img src="tiger.png" alt="tiger"></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should replace underscore and hyphen with space in generated alt text for an inline image' do
      para = block_from_string 'image:tiger-with-family_1.png[]'
      assert_equal '<span class="image"><img src="tiger-with-family_1.png" alt="tiger with family 1"></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text should be interpreted as an image with alt text' do
      para = block_from_string 'image:tiger.png[Tiger]'
      assert_equal '<span class="image"><img src="tiger.png" alt="Tiger"></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should encode special characters in alt text of inline image' do
      input = 'A tiger\'s "roar" is < a bear\'s "growl"'
      expected = 'A tiger&#8217;s &quot;roar&quot; is &lt; a bear&#8217;s &quot;growl&quot;'
      output = (convert_inline_string %(image:tiger-roar.png[#{input}])).gsub(/>\s+</, '><')
      assert_equal %(<span class="image"><img src="tiger-roar.png" alt="#{expected}"></span>), output
    end

    test 'an image macro with SVG image and text should be interpreted as an image with alt text' do
      para = block_from_string 'image:tiger.svg[Tiger]'
      assert_equal '<span class="image"><img src="tiger.svg" alt="Tiger"></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an image macro with an interactive SVG image and alt text should be converted to an object element' do
      para = block_from_string 'image:tiger.svg[Tiger,opts=interactive]', safe: Asciidoctor::SafeMode::SERVER, attributes: { 'imagesdir' => 'images' }
      assert_equal '<span class="image"><object type="image/svg+xml" data="images/tiger.svg"><span class="alt">Tiger</span></object></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an image macro with an interactive SVG image, fallback and alt text should be converted to an object element' do
      para = block_from_string 'image:tiger.svg[Tiger,fallback=tiger.png,opts=interactive]', safe: Asciidoctor::SafeMode::SERVER, attributes: { 'imagesdir' => 'images' }
      assert_equal '<span class="image"><object type="image/svg+xml" data="images/tiger.svg"><img src="images/tiger.png" alt="Tiger"></object></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an image macro with an inline SVG image should be converted to an svg element' do
      para = block_from_string 'image:circle.svg[Tiger,100,opts=inline]', safe: Asciidoctor::SafeMode::SERVER, attributes: { 'imagesdir' => 'fixtures', 'docdir' => testdir }
      result = para.sub_macros(para.source).gsub(/>\s+</, '><')
      assert_match(/<svg\s[^>]*width="100"[^>]*>/, result)
      refute_match(/<svg\s[^>]*width="500"[^>]*>/, result)
      refute_match(/<svg\s[^>]*height="500"[^>]*>/, result)
      refute_match(/<svg\s[^>]*style="[^>]*>/, result)
    end

    test 'should ignore link attribute if value is self and image target is inline SVG' do
      para = block_from_string 'image:circle.svg[Tiger,100,opts=inline,link=self]', safe: Asciidoctor::SafeMode::SERVER, attributes: { 'imagesdir' => 'fixtures', 'docdir' => testdir }
      result = para.sub_macros(para.source).gsub(/>\s+</, '><')
      assert_match(/<svg\s[^>]*width="100"[^>]*>/, result)
      refute_match(/<a href=/, result)
    end

    test 'an image macro with an inline SVG image should be converted to an svg element even when data-uri is set' do
      para = block_from_string 'image:circle.svg[Tiger,100,opts=inline]', safe: Asciidoctor::SafeMode::SERVER, attributes: { 'data-uri' => '', 'imagesdir' => 'fixtures', 'docdir' => testdir }
      assert_match(/<svg\s[^>]*width="100">/, para.sub_macros(para.source).gsub(/>\s+</, '><'))
    end

    test 'an image macro with an SVG image should not use an object element when safe mode is secure' do
      para = block_from_string 'image:tiger.svg[Tiger,opts=interactive]', attributes: { 'imagesdir' => 'images' }
      assert_equal '<span class="image"><img src="images/tiger.svg" alt="Tiger"></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text containing escaped square bracket should be interpreted as an image with alt text' do
      para = block_from_string %(image:tiger.png[[Another#{BACKSLASH}] Tiger])
      assert_equal '<span class="image"><img src="tiger.png" alt="[Another] Tiger"></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text and dimensions should be interpreted as an image with alt text and dimensions' do
      para = block_from_string 'image:tiger.png[Tiger, 200, 100]'
      assert_equal '<span class="image"><img src="tiger.png" alt="Tiger" width="200" height="100"></span>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text and dimensions should be interpreted as an image with alt text and dimensions in docbook' do
      para = block_from_string 'image:tiger.png[Tiger, 200, 100]', backend: 'docbook'
      assert_equal '<inlinemediaobject><imageobject><imagedata fileref="tiger.png" contentwidth="200" contentdepth="100"/></imageobject><textobject><phrase>Tiger</phrase></textobject></inlinemediaobject>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with scaledwidth attribute should be supported in docbook' do
      para = block_from_string 'image:tiger.png[Tiger,scaledwidth=25%]', backend: 'docbook'
      assert_equal '<inlinemediaobject><imageobject><imagedata fileref="tiger.png" width="25%"/></imageobject><textobject><phrase>Tiger</phrase></textobject></inlinemediaobject>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with scaled attribute should be supported in docbook' do
      para = block_from_string 'image:tiger.png[Tiger,scale=200]', backend: 'docbook'
      assert_equal '<inlinemediaobject><imageobject><imagedata fileref="tiger.png" scale="200"/></imageobject><textobject><phrase>Tiger</phrase></textobject></inlinemediaobject>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should pass through role on image macro to DocBook output' do
      para = block_from_string 'image:tiger.png[Tiger,200,role=animal]', backend: 'docbook'
      result = para.sub_macros para.source
      assert_includes result, '<inlinemediaobject role="animal">'
    end

    test 'a single-line image macro with text and link should be interpreted as a linked image with alt text' do
      para = block_from_string 'image:tiger.png[Tiger, link="http://en.wikipedia.org/wiki/Tiger"]'
      assert_equal '<span class="image"><a class="image" href="http://en.wikipedia.org/wiki/Tiger"><img src="tiger.png" alt="Tiger"></a></span>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line image macro with text and link to self should be interpreted as a self-referencing image with alt text' do
      para = block_from_string 'image:tiger.png[Tiger, link=self]', attributes: { 'imagesdir' => 'img' }
      assert_equal '<span class="image"><a class="image" href="img/tiger.png"><img src="img/tiger.png" alt="Tiger"></a></span>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should link to data URI if value of link attribute is self and inline image is embedded' do
      para = block_from_string 'image:circle.svg[Tiger,100,link=self]', safe: Asciidoctor::SafeMode::SERVER, attributes: { 'data-uri' => '', 'imagesdir' => 'fixtures', 'docdir' => testdir }
      output = para.sub_macros(para.source).gsub(/>\s+</, '><')
      assert_xpath '//a[starts-with(@href,"data:image/svg+xml;base64,")]', output, 1
      assert_xpath '//img[starts-with(@src,"data:image/svg+xml;base64,")]', output, 1
    end

    test 'rel=noopener should be added to an image with a link that targets the _blank window' do
      para = block_from_string 'image:tiger.png[Tiger,link=http://en.wikipedia.org/wiki/Tiger,window=_blank]'
      assert_equal '<span class="image"><a class="image" href="http://en.wikipedia.org/wiki/Tiger" target="_blank" rel="noopener"><img src="tiger.png" alt="Tiger"></a></span>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'rel=noopener should be added to an image with a link that targets a named window when the noopener option is set' do
      para = block_from_string 'image:tiger.png[Tiger,link=http://en.wikipedia.org/wiki/Tiger,window=name,opts=noopener]'
      assert_equal '<span class="image"><a class="image" href="http://en.wikipedia.org/wiki/Tiger" target="name" rel="noopener"><img src="tiger.png" alt="Tiger"></a></span>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'rel=nofollow should be added to an image with a link when the nofollow option is set' do
      para = block_from_string 'image:tiger.png[Tiger,link=http://en.wikipedia.org/wiki/Tiger,opts=nofollow]'
      assert_equal '<span class="image"><a class="image" href="http://en.wikipedia.org/wiki/Tiger" rel="nofollow"><img src="tiger.png" alt="Tiger"></a></span>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a multi-line image macro with text and dimensions should be interpreted as an image with alt text and dimensions' do
      para = block_from_string %(image:tiger.png[Another\nAwesome\nTiger, 200,\n100])
      assert_equal '<span class="image"><img src="tiger.png" alt="Another Awesome Tiger" width="200" height="100"></span>',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an inline image macro with a url target should be interpreted as an image' do
      para = block_from_string %(Beware of the image:http://example.com/images/tiger.png[tiger].)
      assert_equal 'Beware of the <span class="image"><img src="http://example.com/images/tiger.png" alt="tiger"></span>.',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an inline image macro with a float attribute should be interpreted as a floating image' do
      para = block_from_string %(image:http://example.com/images/tiger.png[tiger, float="right"] Beware of the tigers!)
      assert_equal '<span class="image right"><img src="http://example.com/images/tiger.png" alt="tiger"></span> Beware of the tigers!',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should prepend value of imagesdir attribute to inline image target if target is relative path' do
      para = block_from_string %(Beware of the image:tiger.png[tiger].), attributes: { 'imagesdir' => './images' }
      assert_equal 'Beware of the <span class="image"><img src="./images/tiger.png" alt="tiger"></span>.',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should not prepend value of imagesdir attribute to inline image target if target is absolute path' do
      para = block_from_string %(Beware of the image:/tiger.png[tiger].), attributes: { 'imagesdir' => './images' }
      assert_equal 'Beware of the <span class="image"><img src="/tiger.png" alt="tiger"></span>.',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should not prepend value of imagesdir attribute to inline image target if target is url' do
      para = block_from_string %(Beware of the image:http://example.com/images/tiger.png[tiger].), attributes: { 'imagesdir' => './images' }
      assert_equal 'Beware of the <span class="image"><img src="http://example.com/images/tiger.png" alt="tiger"></span>.',
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should match an inline image macro if target contains a space character' do
      para = block_from_string %(Beware of the image:big cats.png[] around here.)
      assert_equal %(Beware of the <span class="image"><img src="big%20cats.png" alt="big cats"></span> around here.),
        para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should not match an inline image macro if target contains a newline character' do
      para = block_from_string %(Fear not. There are no image:big\ncats.png[] around here.)
      result = para.sub_macros para.source
      refute_includes result, '<img '
      assert_includes result, %(image:big\ncats.png[])
    end

    test 'should not match an inline image macro if target begins or ends with space character' do
      ['image: big cats.png[]', 'image:big cats.png []'].each do |input|
        para = block_from_string %(Fear not. There are no #{input} around here.)
        result = para.sub_macros para.source
        refute_includes result, '<img '
        assert_includes result, input
      end
    end

    test 'should not detect a block image macro found inline' do
      para = block_from_string %(Not an inline image macro image::tiger.png[].)
      result = para.sub_macros para.source
      refute_includes result, '<img '
      assert_includes result, 'image::tiger.png[]'
    end

    # NOTE this test verifies attributes get substituted eagerly in target of image in title
    test 'should substitute attributes in target of inline image in section title' do
      input = '== image:{iconsdir}/dot.gif[dot] Title'

      using_memory_logger do |logger|
        sect = block_from_string input, attributes: { 'data-uri' => '', 'iconsdir' => 'fixtures', 'docdir' => testdir }, safe: :server, catalog_assets: true
        assert_equal 1, sect.document.catalog[:images].size
        assert_equal 'fixtures/dot.gif', sect.document.catalog[:images][0].to_s
        assert_nil sect.document.catalog[:images][0].imagesdir
        assert_empty logger
      end
    end

    test 'an icon macro should be interpreted as an icon if icons are enabled' do
      para = block_from_string 'icon:github[]', attributes: { 'icons' => '' }
      assert_equal '<span class="icon"><img src="./images/icons/github.png" alt="github"></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an icon macro should be interpreted as alt text if icons are disabled' do
      para = block_from_string 'icon:github[]'
      assert_equal '<span class="icon">[github&#93;</span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should not mangle icon with link if icons are disabled' do
      para = block_from_string 'icon:github[link=https://github.com]'
      assert_equal '<span class="icon"><a class="image" href="https://github.com">[github&#93;</a></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'should not mangle icon inside link if icons are disabled' do
      para = block_from_string 'https://github.com[icon:github[] GitHub]'
      assert_equal '<a href="https://github.com"><span class="icon">[github&#93;</span> GitHub</a>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an icon macro should output alt text if icons are disabled and alt is given' do
      para = block_from_string 'icon:github[alt="GitHub"]'
      assert_equal '<span class="icon">[GitHub&#93;</span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an icon macro should be interpreted as a font-based icon when icons=font' do
      para = block_from_string 'icon:github[]', attributes: { 'icons' => 'font' }
      assert_equal '<span class="icon"><i class="fa fa-github"></i></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an icon macro with a size should be interpreted as a font-based icon with a size when icons=font' do
      para = block_from_string 'icon:github[4x]', attributes: { 'icons' => 'font' }
      assert_equal '<span class="icon"><i class="fa fa-github fa-4x"></i></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an icon macro with flip should be interpreted as a flipped font-based icon when icons=font' do
      para = block_from_string 'icon:shield[fw,flip=horizontal]', attributes: { 'icons' => 'font' }
      assert_equal '<span class="icon"><i class="fa fa-shield fa-fw fa-flip-horizontal"></i></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an icon macro with rotate should be interpreted as a rotated font-based icon when icons=font' do
      para = block_from_string 'icon:shield[fw,rotate=90]', attributes: { 'icons' => 'font' }
      assert_equal '<span class="icon"><i class="fa fa-shield fa-fw fa-rotate-90"></i></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'an icon macro with a role and title should be interpreted as a font-based icon with a class and title when icons=font' do
      para = block_from_string 'icon:heart[role="red", title="Heart me"]', attributes: { 'icons' => 'font' }
      assert_equal '<span class="icon red"><i class="fa fa-heart" title="Heart me"></i></span>', para.sub_macros(para.source).gsub(/>\s+</, '><')
    end

    test 'a single-line footnote macro should be registered and output as a footnote' do
      para = block_from_string 'Sentence text footnote:[An example footnote.].'
      assert_equal %(Sentence text <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>.), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote = para.document.catalog[:footnotes].first
      assert_equal 1, footnote.index
      assert_nil footnote.id
      assert_equal 'An example footnote.', footnote.text
    end

    test 'a multi-line footnote macro should be registered and output as a footnote without newline' do
      para = block_from_string "Sentence text footnote:[An example footnote\nwith wrapped text.]."
      assert_equal %(Sentence text <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>.), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote = para.document.catalog[:footnotes].first
      assert_equal 1, footnote.index
      assert_nil footnote.id
      assert_equal 'An example footnote with wrapped text.', footnote.text
    end

    test 'an escaped closing square bracket in a footnote should be unescaped when converted' do
      para = block_from_string %(footnote:[a #{BACKSLASH}] b].)
      assert_equal %(<sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>.), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote = para.document.catalog[:footnotes].first
      assert_equal 'a ] b', footnote.text
    end

    test 'a footnote macro can be directly adjacent to preceding word' do
      para = block_from_string 'Sentence textfootnote:[An example footnote.].'
      assert_equal 'Sentence text<sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>.', para.sub_macros(para.source)
    end

    test 'a footnote macro may contain an escaped backslash' do
      para = block_from_string "footnote:[\\]]\nfootnote:[a \\] b]\nfootnote:[a \\]\\] b]"
      para.sub_macros para.source
      assert_equal 3, para.document.catalog[:footnotes].size
      footnote1 = para.document.catalog[:footnotes][0]
      assert_equal ']', footnote1.text
      footnote2 = para.document.catalog[:footnotes][1]
      assert_equal 'a ] b', footnote2.text
      footnote3 = para.document.catalog[:footnotes][2]
      assert_equal 'a ]] b', footnote3.text
    end

    test 'a footnote macro may contain a link macro' do
      para = block_from_string 'Share your code. footnote:[https://github.com[GitHub]]'
      assert_equal %(Share your code. <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote1 = para.document.catalog[:footnotes][0]
      assert_equal '<a href="https://github.com">GitHub</a>', footnote1.text
    end

    test 'a footnote macro may contain a plain URL' do
      para = block_from_string %(the JLine footnote:[https://github.com/jline/jline2]\nlibrary.)
      result = para.sub_macros para.source
      assert_equal %(the JLine <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>\nlibrary.), result
      assert_equal 1, para.document.catalog[:footnotes].size
      fn1 = para.document.catalog[:footnotes].first
      assert_equal '<a href="https://github.com/jline/jline2" class="bare">https://github.com/jline/jline2</a>', fn1.text
    end

    test 'a footnote macro followed by a semi-colon may contain a plain URL' do
      para = block_from_string %(the JLine footnote:[https://github.com/jline/jline2];\nlibrary.)
      result = para.sub_macros para.source
      assert_equal %(the JLine <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>;\nlibrary.), result
      assert_equal 1, para.document.catalog[:footnotes].size
      fn1 = para.document.catalog[:footnotes].first
      assert_equal '<a href="https://github.com/jline/jline2" class="bare">https://github.com/jline/jline2</a>', fn1.text
    end

    test 'a footnote macro may contain text formatting' do
      para = block_from_string 'You can download patches from the product page.footnote:[Only available with an _active_ subscription.]'
      para.convert
      footnotes = para.document.catalog[:footnotes]
      assert_equal 1, footnotes.size
      assert_equal 'Only available with an <em>active</em> subscription.', footnotes[0].text
    end

    test 'an externalized footnote macro may contain text formatting' do
      input = <<~'EOS'
      :fn-disclaimer: pass:q[footnote:[Only available with an _active_ subscription.]]

      You can download patches from the production page.{fn-disclaimer}
      EOS
      doc = document_from_string input
      doc.convert
      footnotes = doc.catalog[:footnotes]
      assert_equal 1, footnotes.size
      assert_equal 'Only available with an <em>active</em> subscription.', footnotes[0].text
    end

    test 'a footnote macro may contain a shorthand xref' do
      # specialcharacters escaping is simulated
      para = block_from_string 'text footnote:[&lt;&lt;_install,install&gt;&gt;]'
      doc = para.document
      doc.register :refs, ['_install', (Asciidoctor::Inline.new doc, :anchor, 'Install', type: :ref, target: '_install'), 'Install']
      catalog = doc.catalog
      assert_equal %(text <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>), para.sub_macros(para.source)
      assert_equal 1, catalog[:footnotes].size
      footnote1 = catalog[:footnotes][0]
      assert_equal '<a href="#_install">install</a>', footnote1.text
    end

    test 'a footnote macro may contain an xref macro' do
      para = block_from_string 'text footnote:[xref:_install[install]]'
      doc = para.document
      doc.register :refs, ['_install', (Asciidoctor::Inline.new doc, :anchor, 'Install', type: :ref, target: '_install'), 'Install']
      catalog = doc.catalog
      assert_equal %(text <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>), para.sub_macros(para.source)
      assert_equal 1, catalog[:footnotes].size
      footnote1 = catalog[:footnotes][0]
      assert_equal '<a href="#_install">install</a>', footnote1.text
    end

    test 'a footnote macro may contain an anchor macro' do
      para = block_from_string 'text footnote:[a [[b]] [[c\]\] d]'
      assert_equal %(text <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote1 = para.document.catalog[:footnotes][0]
      assert_equal 'a <a id="b"></a> [[c]] d', footnote1.text
    end

    test 'subsequent footnote macros with escaped URLs should be restored in DocBook' do
      input = 'foofootnote:[+http://example.com+]barfootnote:[+http://acme.com+]baz'

      result = convert_string_to_embedded input, doctype: 'inline', backend: 'docbook'
      assert_equal 'foo<footnote><simpara>http://example.com</simpara></footnote>bar<footnote><simpara>http://acme.com</simpara></footnote>baz', result
    end

    test 'should increment index of subsequent footnote macros' do
      para = block_from_string 'Sentence text footnote:[An example footnote.]. Sentence text footnote:[Another footnote.].'
      assert_equal 'Sentence text <sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>. Sentence text <sup class="footnote">[<a id="_footnoteref_2" class="footnote" href="#_footnotedef_2" title="View footnote.">2</a>]</sup>.', para.sub_macros(para.source)
      assert_equal 2, para.document.catalog[:footnotes].size
      footnote1 = para.document.catalog[:footnotes][0]
      assert_equal 1, footnote1.index
      assert_nil footnote1.id
      assert_equal 'An example footnote.', footnote1.text
      footnote2 = para.document.catalog[:footnotes][1]
      assert_equal 2, footnote2.index
      assert_nil footnote2.id
      assert_equal 'Another footnote.', footnote2.text
    end

    test 'a footnoteref macro with id and single-line text should be registered and output as a footnote' do
      para = block_from_string 'Sentence text footnoteref:[ex1, An example footnote.].', attributes: { 'compat-mode' => '' }
      assert_equal %(Sentence text <sup class="footnote" id="_footnote_ex1">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>.), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote = para.document.catalog[:footnotes].first
      assert_equal 1, footnote.index
      assert_equal 'ex1', footnote.id
      assert_equal 'An example footnote.', footnote.text
    end

    test 'a footnoteref macro with id and multi-line text should be registered and output as a footnote without newlines' do
      para = block_from_string "Sentence text footnoteref:[ex1, An example footnote\nwith wrapped text.].", attributes: { 'compat-mode' => '' }
      assert_equal %(Sentence text <sup class="footnote" id="_footnote_ex1">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>.), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote = para.document.catalog[:footnotes].first
      assert_equal 1, footnote.index
      assert_equal 'ex1', footnote.id
      assert_equal 'An example footnote with wrapped text.', footnote.text
    end

    test 'a footnoteref macro with id should refer to footnoteref with same id' do
      para = block_from_string 'Sentence text footnoteref:[ex1, An example footnote.]. Sentence text footnoteref:[ex1].', attributes: { 'compat-mode' => '' }
      assert_equal %(Sentence text <sup class="footnote" id="_footnote_ex1">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>. Sentence text <sup class="footnoteref">[<a class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>.), para.sub_macros(para.source)
      assert_equal 1, para.document.catalog[:footnotes].size
      footnote = para.document.catalog[:footnotes].first
      assert_equal 1, footnote.index
      assert_equal 'ex1', footnote.id
      assert_equal 'An example footnote.', footnote.text
    end

    test 'an unresolved footnote reference should produce a warning message and output fallback text in red' do
      input = 'Sentence text.footnote:ex1[]'
      using_memory_logger do |logger|
        para = block_from_string input
        output = para.sub_macros para.source
        assert_equal 'Sentence text.<sup class="footnoteref red" title="Unresolved footnote reference.">[ex1]</sup>', output
        assert_message logger, :WARN, 'invalid footnote reference: ex1'
      end
    end

    test 'using a footnoteref macro should generate a warning when compat mode is not enabled' do
      input = 'Sentence text.footnoteref:[fn1,Commentary on this sentence.]'
      using_memory_logger do |logger|
        para = block_from_string input
        para.sub_macros para.source
        assert_message logger, :WARN, 'found deprecated footnoteref macro: footnoteref:[fn1,Commentary on this sentence.]; use footnote macro with target instead'
      end
    end

    test 'inline footnote macro can be used to define and reference a footnote reference' do
      input = <<~'EOS'
      You can download the software from the product page.footnote:sub[Option only available if you have an active subscription.]

      You can also file a support request.footnote:sub[]

      If all else fails, you can give us a call.footnoteref:[sub]
      EOS

      using_memory_logger do |logger|
        output = convert_string_to_embedded input, attributes: { 'compat-mode' => '' }
        assert_css '#_footnotedef_1', output, 1
        assert_css 'p a[href="#_footnotedef_1"]', output, 3
        assert_css '#footnotes .footnote', output, 1
        assert_empty logger
      end
    end

    test 'should parse multiple footnote references in a single line' do
      input = 'notable text.footnote:id[about this [text\]], footnote:id[], footnote:id[]'
      output = convert_string_to_embedded input
      assert_xpath '(//p)[1]/sup[starts-with(@class,"footnote")]', output, 3
      assert_xpath '(//p)[1]/sup[@class="footnote"]', output, 1
      assert_xpath '(//p)[1]/sup[@class="footnoteref"]', output, 2
      assert_xpath '(//p)[1]/sup[starts-with(@class,"footnote")]/a[@class="footnote"][text()="1"]', output, 3
      assert_css '#footnotes .footnote', output, 1
    end

    test 'should not register footnote with id and text if id already registered' do
      input = <<~'EOS'
      :fn-notable-text: footnote:id[about this text]

      notable text.{fn-notable-text}

      more notable text.{fn-notable-text}
      EOS
      output = convert_string_to_embedded input
      assert_xpath '(//p)[1]/sup[@class="footnote"]', output, 1
      assert_xpath '(//p)[2]/sup[@class="footnoteref"]', output, 1
      assert_css '#footnotes .footnote', output, 1
    end

    test 'should not resolve an inline footnote macro missing both id and text' do
      input = <<~'EOS'
      The footnote:[] macro can be used for defining and referencing footnotes.

      The footnoteref:[] macro is now deprecated.
      EOS

      output = convert_string_to_embedded input
      assert_includes output, 'The footnote:[] macro'
      assert_includes output, 'The footnoteref:[] macro'
    end

    test 'inline footnote macro can define a numeric id without conflicting with auto-generated ID' do
      input = 'You can download the software from the product page.footnote:1[Option only available if you have an active subscription.]'

      output = convert_string_to_embedded input
      assert_css '#_footnote_1', output, 1
      assert_css 'p sup#_footnote_1', output, 1
      assert_css 'p a#_footnoteref_1', output, 1
      assert_css 'p a[href="#_footnotedef_1"]', output, 1
      assert_css '#footnotes #_footnotedef_1', output, 1
    end

    test 'inline footnote macro can define an id that uses any word characters in Unicode' do
      input = <<~'EOS'
      L'origine du mot forêt{blank}footnote:forêt[un massif forestier] est complexe.

      Qu'est-ce qu'une forêt ?{blank}footnote:forêt[]
      EOS
      output = convert_string_to_embedded input
      assert_css '#_footnote_forêt', output, 1
      assert_css '#_footnotedef_1', output, 1
      assert_xpath '//a[@class="footnote"][text()="1"]', output, 2
    end

    test 'should be able to reference a bibliography entry in a footnote' do
      input = <<~'EOS'
      Choose a design pattern.footnote:[See <<gof>> to find a collection of design patterns.]

      [bibliography]
      == Bibliography

      * [[[gof]]] Erich Gamma, et al. _Design Patterns: Elements of Reusable Object-Oriented Software._ Addison-Wesley. 1994.
      EOS

      result = convert_string_to_embedded input
      assert_include '<a href="#_footnoteref_1">1</a>. See <a href="#gof">[gof]</a> to find a collection of design patterns.', result
    end

    test 'footnotes in headings are expected to be numbered out of sequence' do
      input = <<~'EOS'
      == Section 1

      para.footnote:[first footnote]

      == Section 2footnote:[second footnote]

      para.footnote:[third footnote]
      EOS

      result = convert_string_to_embedded input
      footnote_refs = xmlnodes_at_css 'a.footnote', result
      footnote_defs = xmlnodes_at_css 'div.footnote', result
      assert_equal 3, footnote_refs.length
      assert_equal %w(1 1 2), footnote_refs.map(&:text)
      assert_equal 3, footnote_defs.length
      assert_equal ['1. second footnote', '1. first footnote', '2. third footnote'], footnote_defs.map(&:text).map(&:strip)
    end

    test 'a single-line index term macro with a primary term should be registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[Tigers]', '(((Tigers)))']
      macros.each do |macro|
        para = block_from_string "#{sentence}#{macro}"
        output = para.sub_macros para.source
        assert_equal sentence, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #assert_equal ['Tigers'], para.document.catalog[:indexterms].first
      end
    end

    test 'a single-line index term macro with primary and secondary terms should be registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[Big cats, Tigers]', '(((Big cats, Tigers)))']
      macros.each do |macro|
        para = block_from_string "#{sentence}#{macro}"
        output = para.sub_macros para.source
        assert_equal sentence, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #assert_equal ['Big cats', 'Tigers'], para.document.catalog[:indexterms].first
      end
    end

    test 'a single-line index term macro with primary, secondary and tertiary terms should be registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[Big cats,Tigers , Panthera tigris]', '(((Big cats,Tigers , Panthera tigris)))']
      macros.each do |macro|
        para = block_from_string "#{sentence}#{macro}"
        output = para.sub_macros para.source
        assert_equal sentence, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #assert_equal ['Big cats', 'Tigers', 'Panthera tigris'], para.document.catalog[:indexterms].first
      end
    end

    test 'a multi-line index term macro should be compacted and registered as an index reference' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ["indexterm:[Panthera\ntigris]", "(((Panthera\ntigris)))"]
      macros.each do |macro|
        para = block_from_string "#{sentence}#{macro}"
        output = para.sub_macros para.source
        assert_equal sentence, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #assert_equal ['Panthera tigris'], para.document.catalog[:indexterms].first
      end
    end

    test 'should escape concealed index term if second bracket is preceded by a backslash' do
      input = %[National Institute of Science and Technology (#{BACKSLASH}((NIST)))]
      doc = document_from_string input, standalone: false
      output = doc.convert
      assert_xpath '//p[text()="National Institute of Science and Technology (((NIST)))"]', output, 1
      #assert doc.catalog[:indexterms].empty?
    end

    test 'should only escape enclosing brackets if concealed index term is preceded by a backslash' do
      input = %[National Institute of Science and Technology #{BACKSLASH}(((NIST)))]
      doc = document_from_string input, standalone: false
      output = doc.convert
      assert_xpath '//p[text()="National Institute of Science and Technology (NIST)"]', output, 1
      #term = doc.catalog[:indexterms].first
      #assert_equal 1, term.size
      #assert_equal 'NIST', term.first
    end

    test 'should not split index terms on commas inside of quoted terms' do
      inputs = []
      inputs.push <<~'EOS'
      Tigers are big, scary cats.
      indexterm:[Tigers, "[Big\],
      scary cats"]
      EOS
      inputs.push <<~'EOS'
      Tigers are big, scary cats.
      (((Tigers, "[Big],
      scary cats")))
      EOS

      inputs.each do |input|
        para = block_from_string input
        output = para.sub_macros para.source
        assert_equal input.lines.first, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #terms = para.document.catalog[:indexterms].first
        #assert_equal 2, terms.size
        #assert_equal 'Tigers', terms.first
        #assert_equal '[Big], scary cats', terms.last
      end
    end

    test 'normal substitutions are performed on an index term macro' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macros = ['indexterm:[*Tigers*]', '(((*Tigers*)))']
      macros.each do |macro|
        para = block_from_string "#{sentence}#{macro}"
        output = para.apply_subs para.source
        assert_equal sentence, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #assert_equal ['<strong>Tigers</strong>'], para.document.catalog[:indexterms].first
      end
    end

    test 'registers multiple index term macros' do
      sentence = 'The tiger (Panthera tigris) is the largest cat species.'
      macros = "(((Tigers)))\n(((Animals,Cats)))"
      para = block_from_string "#{sentence}\n#{macros}"
      output = para.sub_macros para.source
      assert_equal sentence, output.rstrip
      #assert_equal 2, para.document.catalog[:indexterms].size
      #assert_equal ['Tigers'], para.document.catalog[:indexterms][0]
      #assert_equal ['Animals', 'Cats'], para.document.catalog[:indexterms][1]
    end

    test 'an index term macro with round bracket syntax may contain round brackets in term' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macro = '(((Tiger (Panthera tigris))))'
      para = block_from_string "#{sentence}#{macro}"
      output = para.sub_macros para.source
      assert_equal sentence, output
      #assert_equal 1, para.document.catalog[:indexterms].size
      #assert_equal ['Tiger (Panthera tigris)'], para.document.catalog[:indexterms].first
    end

    test 'visible shorthand index term macro should not consume trailing round bracket' do
      input = '(text with ((index term)))'
      expected = <<~'EOS'.chop
      (text with <indexterm>
      <primary>index term</primary>
      </indexterm>index term)
      EOS
      #expected_term = ['index term']
      para = block_from_string input, backend: :docbook
      output = para.sub_macros para.source
      assert_equal expected, output
      #indexterms_table = para.document.catalog[:indexterms]
      #assert_equal 1, indexterms_table.size
      #assert_equal expected_term, indexterms_table[0]
    end

    test 'visible shorthand index term macro should not consume leading round bracket' do
      input = '(((index term)) for text)'
      expected = <<~'EOS'.chop
      (<indexterm>
      <primary>index term</primary>
      </indexterm>index term for text)
      EOS
      #expected_term = ['index term']
      para = block_from_string input, backend: :docbook
      output = para.sub_macros para.source
      assert_equal expected, output
      #indexterms_table = para.document.catalog[:indexterms]
      #assert_equal 1, indexterms_table.size
      #assert_equal expected_term, indexterms_table[0]
    end

    test 'an index term macro with square bracket syntax may contain square brackets in term' do
      sentence = "The tiger (Panthera tigris) is the largest cat species.\n"
      macro = 'indexterm:[Tiger [Panthera tigris\\]]'
      para = block_from_string "#{sentence}#{macro}"
      output = para.sub_macros para.source
      assert_equal sentence, output
      #assert_equal 1, para.document.catalog[:indexterms].size
      #assert_equal ['Tiger [Panthera tigris]'], para.document.catalog[:indexterms].first
    end

    test 'a single-line index term 2 macro should be registered as an index reference and retain term inline' do
      sentence = 'The tiger (Panthera tigris) is the largest cat species.'
      macros = ['The indexterm2:[tiger] (Panthera tigris) is the largest cat species.', 'The ((tiger)) (Panthera tigris) is the largest cat species.']
      macros.each do |macro|
        para = block_from_string macro
        output = para.sub_macros para.source
        assert_equal sentence, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #assert_equal ['tiger'], para.document.catalog[:indexterms].first
      end
    end

    test 'a multi-line index term 2 macro should be compacted and registered as an index reference and retain term inline' do
      sentence = 'The panthera tigris is the largest cat species.'
      macros = ["The indexterm2:[ panthera\ntigris ] is the largest cat species.", "The (( panthera\ntigris )) is the largest cat species."]
      macros.each do |macro|
        para = block_from_string macro
        output = para.sub_macros para.source
        assert_equal sentence, output
        #assert_equal 1, para.document.catalog[:indexterms].size
        #assert_equal ['panthera tigris'], para.document.catalog[:indexterms].first
      end
    end

    test 'registers multiple index term 2 macros' do
      sentence = 'The ((tiger)) (Panthera tigris) is the largest ((cat)) species.'
      para = block_from_string sentence
      output = para.sub_macros para.source
      assert_equal 'The tiger (Panthera tigris) is the largest cat species.', output
      #assert_equal 2, para.document.catalog[:indexterms].size
      #assert_equal ['tiger'], para.document.catalog[:indexterms][0]
      #assert_equal ['cat'], para.document.catalog[:indexterms][1]
    end

    test 'should escape visible index term if preceded by a backslash' do
      sentence = "The #{BACKSLASH}((tiger)) (Panthera tigris) is the largest #{BACKSLASH}((cat)) species."
      para = block_from_string sentence
      output = para.sub_macros para.source
      assert_equal 'The ((tiger)) (Panthera tigris) is the largest ((cat)) species.', output
      #assert para.document.catalog[:indexterms].empty?
    end

    test 'normal substitutions are performed on an index term 2 macro' do
      sentence = 'The ((*tiger*)) (Panthera tigris) is the largest cat species.'
      para = block_from_string sentence
      output = para.apply_subs para.source
      assert_equal 'The <strong>tiger</strong> (Panthera tigris) is the largest cat species.', output
      #assert_equal 1, para.document.catalog[:indexterms].size
      #assert_equal ['<strong>tiger</strong>'], para.document.catalog[:indexterms].first
    end

    test 'index term 2 macro with round bracket syntex should not interfer with index term macro with round bracket syntax' do
      sentence = "The ((panthera tigris)) is the largest cat species.\n(((Big cats,Tigers)))"
      para = block_from_string sentence
      output = para.sub_macros para.source
      assert_equal "The panthera tigris is the largest cat species.\n", output
      #terms = para.document.catalog[:indexterms]
      #assert_equal 2, terms.size
      #assert_equal ['panthera tigris'], terms[0]
      #assert_equal ['Big cats', 'Tigers'], terms[1]
    end

    test 'should parse visible shorthand index term with see and seealso' do
      sentence = '((Flash >> HTML 5)) has been supplanted by ((HTML 5 &> CSS 3 &> SVG)).'
      output = convert_string_to_embedded sentence, backend: 'docbook'
      indexterm_flash = <<~'EOS'.chop
      <indexterm>
      <primary>Flash</primary>
      <see>HTML 5</see>
      </indexterm>
      EOS
      indexterm_html5 = <<~'EOS'.chop
      <indexterm>
      <primary>HTML 5</primary>
      <seealso>CSS 3</seealso>
      <seealso>SVG</seealso>
      </indexterm>
      EOS
      assert_includes output, indexterm_flash
      assert_includes output, indexterm_html5
    end

    test 'should parse concealed shorthand index term with see and seealso' do
      sentence = 'Flash(((Flash >> HTML 5))) has been supplanted by HTML 5(((HTML 5 &> CSS 3 &> SVG))).'
      output = convert_string_to_embedded sentence, backend: 'docbook'
      indexterm_flash = <<~'EOS'.chop
      <indexterm>
      <primary>Flash</primary>
      <see>HTML 5</see>
      </indexterm>
      EOS
      indexterm_html5 = <<~'EOS'.chop
      <indexterm>
      <primary>HTML 5</primary>
      <seealso>CSS 3</seealso>
      <seealso>SVG</seealso>
      </indexterm>
      EOS
      assert_includes output, indexterm_flash
      assert_includes output, indexterm_html5
    end

    test 'should parse visible index term macro with see and seealso' do
      sentence = 'indexterm2:[Flash,see=HTML 5] has been supplanted by indexterm2:[HTML 5,see-also="CSS 3, SVG"].'
      output = convert_string_to_embedded sentence, backend: 'docbook'
      indexterm_flash = <<~'EOS'.chop
      <indexterm>
      <primary>Flash</primary>
      <see>HTML 5</see>
      </indexterm>
      EOS
      indexterm_html5 = <<~'EOS'.chop
      <indexterm>
      <primary>HTML 5</primary>
      <seealso>CSS 3</seealso>
      <seealso>SVG</seealso>
      </indexterm>
      EOS
      assert_includes output, indexterm_flash
      assert_includes output, indexterm_html5
    end

    test 'should parse concealed index term macro with see and seealso' do
      sentence = 'Flashindexterm:[Flash,see=HTML 5] has been supplanted by HTML 5indexterm:[HTML 5,see-also="CSS 3, SVG"].'
      output = convert_string_to_embedded sentence, backend: 'docbook'
      indexterm_flash = <<~'EOS'.chop
      <indexterm>
      <primary>Flash</primary>
      <see>HTML 5</see>
      </indexterm>
      EOS
      indexterm_html5 = <<~'EOS'.chop
      <indexterm>
      <primary>HTML 5</primary>
      <seealso>CSS 3</seealso>
      <seealso>SVG</seealso>
      </indexterm>
      EOS
      assert_includes output, indexterm_flash
      assert_includes output, indexterm_html5
    end

    test 'should honor secondary and tertiary index terms when primary index term is quoted and contains equals sign' do
      sentence = 'Assigning variables.'
      expected = %(#{sentence}<indexterm><primary>name=value</primary><secondary>variable</secondary><tertiary>assignment</tertiary></indexterm>)
      macros = ['indexterm:["name=value",variable,assignment]', '(((name=value,variable,assignment)))']
      macros.each do |macro|
        para = block_from_string %(#{sentence}#{macro}), backend: 'docbook'
        output = (para.sub_macros para.source).tr ?\n, ''
        assert_equal expected, output
      end
    end

    context 'Button macro' do
      test 'btn macro' do
        para = block_from_string 'btn:[Save]', attributes: { 'experimental' => '' }
        assert_equal '<b class="button">Save</b>', para.sub_macros(para.source)
      end

      test 'btn macro that spans multiple lines' do
        para = block_from_string %(btn:[Rebase and\nmerge]), attributes: { 'experimental' => '' }
        assert_equal '<b class="button">Rebase and merge</b>', para.sub_macros(para.source)
      end

      test 'btn macro for docbook backend' do
        para = block_from_string 'btn:[Save]', backend: 'docbook', attributes: { 'experimental' => '' }
        assert_equal '<guibutton>Save</guibutton>', para.sub_macros(para.source)
      end
    end

    context 'Keyboard macro' do
      test 'kbd macro with single key' do
        para = block_from_string 'kbd:[F3]', attributes: { 'experimental' => '' }
        assert_equal '<kbd>F3</kbd>', para.sub_macros(para.source)
      end

      test 'kbd macro with single backslash key' do
        para = block_from_string "kbd:[#{BACKSLASH} ]", attributes: { 'experimental' => '' }
        assert_equal '<kbd>\</kbd>', para.sub_macros(para.source)
      end

      test 'kbd macro with single key, docbook backend' do
        para = block_from_string 'kbd:[F3]', backend: 'docbook', attributes: { 'experimental' => '' }
        assert_equal '<keycap>F3</keycap>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination' do
        para = block_from_string 'kbd:[Ctrl+Shift+T]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination that spans multiple lines' do
        para = block_from_string %(kbd:[Ctrl +\nT]), attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>T</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination, docbook backend' do
        para = block_from_string 'kbd:[Ctrl+Shift+T]', backend: 'docbook', attributes: { 'experimental' => '' }
        assert_equal '<keycombo><keycap>Ctrl</keycap><keycap>Shift</keycap><keycap>T</keycap></keycombo>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination delimited by pluses with spaces' do
        para = block_from_string 'kbd:[Ctrl + Shift + T]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination delimited by commas' do
        para = block_from_string 'kbd:[Ctrl,Shift,T]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination delimited by commas with spaces' do
        para = block_from_string 'kbd:[Ctrl, Shift, T]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination delimited by plus containing a comma key' do
        para = block_from_string 'kbd:[Ctrl+,]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>,</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination delimited by commas containing a plus key' do
        para = block_from_string 'kbd:[Ctrl, +, Shift]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>+</kbd>+<kbd>Shift</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination where last key matches plus delimiter' do
        para = block_from_string 'kbd:[Ctrl + +]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>+</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination where last key matches comma delimiter' do
        para = block_from_string 'kbd:[Ctrl, ,]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>,</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination containing escaped bracket' do
        para = block_from_string 'kbd:[Ctrl + \]]', attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>]</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro with key combination ending in backslash' do
        para = block_from_string "kbd:[Ctrl + #{BACKSLASH} ]", attributes: { 'experimental' => '' }
        assert_equal '<span class="keyseq"><kbd>Ctrl</kbd>+<kbd>\\</kbd></span>', para.sub_macros(para.source)
      end

      test 'kbd macro looks for delimiter beyond first character' do
        para = block_from_string 'kbd:[,te]', attributes: { 'experimental' => '' }
        assert_equal '<kbd>,te</kbd>', para.sub_macros(para.source)
      end

      test 'kbd macro restores trailing delimiter as key value' do
        para = block_from_string 'kbd:[te,]', attributes: { 'experimental' => '' }
        assert_equal '<kbd>te,</kbd>', para.sub_macros(para.source)
      end
    end

    context 'Menu macro' do
      test 'should process menu using macro sytnax' do
        para = block_from_string 'menu:File[]', attributes: { 'experimental' => '' }
        assert_equal '<b class="menuref">File</b>', para.sub_macros(para.source)
      end

      test 'should process menu for docbook backend' do
        para = block_from_string 'menu:File[]', backend: 'docbook', attributes: { 'experimental' => '' }
        assert_equal '<guimenu>File</guimenu>', para.sub_macros(para.source)
      end

      test 'should process multiple menu macros in same line' do
        para = block_from_string 'menu:File[] and menu:Edit[]', attributes: { 'experimental' => '' }
        assert_equal '<b class="menuref">File</b> and <b class="menuref">Edit</b>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item using macro syntax' do
        para = block_from_string 'menu:File[Save As&#8230;]', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">File</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Save As&#8230;</b></span>', para.sub_macros(para.source)
      end

      test 'should process menu macro that spans multiple lines' do
        input = %(menu:Preferences[Compile\non\nSave])
        para = block_from_string input, attributes: { 'experimental' => '' }
        assert_equal %(<span class="menuseq"><b class="menu">Preferences</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Compile\non\nSave</b></span>), para.sub_macros(para.source)
      end

      test 'should unescape escaped closing bracket in menu macro' do
        input = 'menu:Preferences[Compile [on\\] Save]'
        para = block_from_string input, attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">Preferences</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Compile [on] Save</b></span>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item using macro syntax when fonts icons are enabled' do
        para = block_from_string 'menu:Tools[More Tools &gt; Extensions]', attributes: { 'experimental' => '', 'icons' => 'font' }
        assert_equal '<span class="menuseq"><b class="menu">Tools</b>&#160;<i class="fa fa-angle-right caret"></i> <b class="submenu">More Tools</b>&#160;<i class="fa fa-angle-right caret"></i> <b class="menuitem">Extensions</b></span>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item for docbook backend' do
        para = block_from_string 'menu:File[Save As&#8230;]', backend: 'docbook', attributes: { 'experimental' => '' }
        assert_equal '<menuchoice><guimenu>File</guimenu> <guimenuitem>Save As&#8230;</guimenuitem></menuchoice>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item in submenu using macro syntax' do
        para = block_from_string 'menu:Tools[Project &gt; Build]', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">Tools</b>&#160;<b class="caret">&#8250;</b> <b class="submenu">Project</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Build</b></span>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item in submenu for docbook backend' do
        para = block_from_string 'menu:Tools[Project &gt; Build]', backend: 'docbook', attributes: { 'experimental' => '' }
        assert_equal '<menuchoice><guimenu>Tools</guimenu> <guisubmenu>Project</guisubmenu> <guimenuitem>Build</guimenuitem></menuchoice>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item in submenu using macro syntax and comma delimiter' do
        para = block_from_string 'menu:Tools[Project, Build]', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">Tools</b>&#160;<b class="caret">&#8250;</b> <b class="submenu">Project</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Build</b></span>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item using inline syntax' do
        para = block_from_string '"File &gt; Save As&#8230;"', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">File</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Save As&#8230;</b></span>', para.sub_macros(para.source)
      end

      test 'should process menu with menu item in submenu using inline syntax' do
        para = block_from_string '"Tools &gt; Project &gt; Build"', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">Tools</b>&#160;<b class="caret">&#8250;</b> <b class="submenu">Project</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Build</b></span>', para.sub_macros(para.source)
      end

      test 'inline menu syntax should not match closing quote of XML attribute' do
        para = block_from_string '<span class="xmltag">&lt;node&gt;</span><span class="classname">r</span>', attributes: { 'experimental' => '' }
        assert_equal '<span class="xmltag">&lt;node&gt;</span><span class="classname">r</span>', para.sub_macros(para.source)
      end

      test 'should process menu macro with items containing multibyte characters' do
        para = block_from_string 'menu:视图[放大, 重置]', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">视图</b>&#160;<b class="caret">&#8250;</b> <b class="submenu">放大</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">重置</b></span>', para.sub_macros(para.source)
      end

      test 'should process inline menu with items containing multibyte characters' do
        para = block_from_string '"视图 &gt; 放大 &gt; 重置"', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">视图</b>&#160;<b class="caret">&#8250;</b> <b class="submenu">放大</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">重置</b></span>', para.sub_macros(para.source)
      end

      test 'should process a menu macro with a target that begins with a character reference' do
        para = block_from_string 'menu:&#8942;[More Tools, Extensions]', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">&#8942;</b>&#160;<b class="caret">&#8250;</b> <b class="submenu">More Tools</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Extensions</b></span>', para.sub_macros(para.source)
      end

      test 'should not process a menu macro with a target that ends with a space' do
        input = 'menu:foo [bar] menu:File[Save]'
        para = block_from_string input, attributes: { 'experimental' => '' }
        result = para.sub_macros para.source
        assert_xpath '/span[@class="menuseq"]', result, 1
        assert_xpath '//b[@class="menu"][text()="File"]', result, 1
      end

      test 'should process an inline menu that begins with a character reference' do
        para = block_from_string '"&#8942; &gt; More Tools &gt; Extensions"', attributes: { 'experimental' => '' }
        assert_equal '<span class="menuseq"><b class="menu">&#8942;</b>&#160;<b class="caret">&#8250;</b> <b class="submenu">More Tools</b>&#160;<b class="caret">&#8250;</b> <b class="menuitem">Extensions</b></span>', para.sub_macros(para.source)
      end
    end
  end

  context 'Passthroughs' do
    test 'collect inline triple plus passthroughs' do
      para = block_from_string '+++<code>inline code</code>+++'
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal '<code>inline code</code>', passthroughs[0][:text]
      assert_empty passthroughs[0][:subs]
    end

    test 'collect multi-line inline triple plus passthroughs' do
      para = block_from_string "+++<code>inline\ncode</code>+++"
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal "<code>inline\ncode</code>", passthroughs[0][:text]
      assert_empty passthroughs[0][:subs]
    end

    test 'collect inline double dollar passthroughs' do
      para = block_from_string '$$<code>{code}</code>$$'
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal '<code>{code}</code>', passthroughs[0][:text]
      assert_equal [:specialcharacters], passthroughs[0][:subs]
    end

    test 'collect inline double plus passthroughs' do
      para = block_from_string '++<code>{code}</code>++'
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal '<code>{code}</code>', passthroughs[0][:text]
      assert_equal [:specialcharacters], passthroughs[0][:subs]
    end

    test 'should not crash if role on passthrough is enclosed in quotes' do
      %W(
        ['role']#{BACKSLASH}++This++++++++++++
        ['role']#{BACKSLASH}+++++++++This++++++++++++
      ).each do |input|
        para = block_from_string input
        assert_includes para.content, %(<span class="'role'">)
      end
    end

    test 'should allow inline double plus passthrough to be escaped using backslash' do
      para = block_from_string "you need to replace `int a = n#{BACKSLASH}++;` with `int a = ++n;`!"
      result = para.apply_subs para.source
      assert_equal 'you need to replace <code>int a = n++;</code> with <code>int a = ++n;</code>!', result
    end

    test 'should allow inline double plus passthrough with attributes to be escaped using backslash' do
      para = block_from_string "=[attrs]#{BACKSLASH}#{BACKSLASH}++text++"
      result = para.apply_subs para.source
      assert_equal '=[attrs]++text++', result
    end

    test 'collect multi-line inline double dollar passthroughs' do
      para = block_from_string "$$<code>\n{code}\n</code>$$"
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal "<code>\n{code}\n</code>", passthroughs[0][:text]
      assert_equal [:specialcharacters], passthroughs[0][:subs]
    end

    test 'collect multi-line inline double plus passthroughs' do
      para = block_from_string "++<code>\n{code}\n</code>++"
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal "<code>\n{code}\n</code>", passthroughs[0][:text]
      assert_equal [:specialcharacters], passthroughs[0][:subs]
    end

    test 'collect passthroughs from inline pass macro' do
      para = block_from_string %q(pass:specialcharacters,quotes[<code>['code'\\]</code>])
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal %q(<code>['code']</code>), passthroughs[0][:text]
      assert_equal [:specialcharacters, :quotes], passthroughs[0][:subs]
    end

    test 'collect multi-line passthroughs from inline pass macro' do
      para = block_from_string %(pass:specialcharacters,quotes[<code>['more\ncode'\\]</code>])
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal Asciidoctor::Substitutors::PASS_START + '0' + Asciidoctor::Substitutors::PASS_END, result
      assert_equal 1, passthroughs.size
      assert_equal %(<code>['more\ncode']</code>), passthroughs[0][:text]
      assert_equal [:specialcharacters, :quotes], passthroughs[0][:subs]
    end

    test 'should find and replace placeholder duplicated by substitution' do
      input = '+first passthrough+ followed by link:$$http://example.com/__u_no_format_me__$$[] with passthrough'
      result = convert_inline_string input
      assert_equal 'first passthrough followed by <a href="http://example.com/__u_no_format_me__" class="bare">http://example.com/__u_no_format_me__</a> with passthrough', result
    end

    test 'resolves sub shorthands on inline pass macro' do
      para = block_from_string 'pass:q,a[*<{backend}>*]'
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal 1, passthroughs.size
      assert_equal [:quotes, :attributes], passthroughs[0][:subs]
      result = para.restore_passthroughs result
      assert_equal '<strong><html5></strong>', result
    end

    test 'inline pass macro supports incremental subs' do
      para = block_from_string 'pass:n,-a[<{backend}>]'
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal 1, passthroughs.size
      result = para.restore_passthroughs result
      assert_equal '&lt;{backend}&gt;', result
    end

    test 'should not recognize pass macro with invalid substitution list' do
      [',', '42', 'a,'].each do |subs|
        para = block_from_string %(pass:#{subs}[foobar])
        result = para.extract_passthroughs para.source
        assert_equal %(pass:#{subs}[foobar]), result
      end
    end

    test 'should allow content of inline pass macro to be empty' do
      para = block_from_string 'pass:[]'
      result = para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal 1, passthroughs.size
      assert_equal '', para.restore_passthroughs(result)
    end

    # NOTE placeholder is surrounded by text to prevent reader from stripping trailing boundary char (unique to test scenario)
    test 'restore inline passthroughs without subs' do
      para = block_from_string "some #{Asciidoctor::Substitutors::PASS_START}" + '0' + "#{Asciidoctor::Substitutors::PASS_END} to study"
      para.extract_passthroughs ''
      passthroughs = para.instance_variable_get :@passthroughs
      passthroughs[0] = { text: '<code>inline code</code>', subs: [] }
      result = para.restore_passthroughs para.source
      assert_equal 'some <code>inline code</code> to study', result
    end

    # NOTE placeholder is surrounded by text to prevent reader from stripping trailing boundary char (unique to test scenario)
    test 'restore inline passthroughs with subs' do
      para = block_from_string "some #{Asciidoctor::Substitutors::PASS_START}" + '0' + "#{Asciidoctor::Substitutors::PASS_END} to study in the #{Asciidoctor::Substitutors::PASS_START}" + '1' + "#{Asciidoctor::Substitutors::PASS_END} programming language"
      para.extract_passthroughs ''
      passthroughs = para.instance_variable_get :@passthroughs
      passthroughs[0] = { text: '<code>{code}</code>', subs: [:specialcharacters] }
      passthroughs[1] = { text: '{language}', subs: [:specialcharacters] }
      result = para.restore_passthroughs para.source
      assert_equal 'some &lt;code&gt;{code}&lt;/code&gt; to study in the {language} programming language', result
    end

    test 'should restore nested passthroughs' do
      result = convert_inline_string %q(+Sometimes you feel pass:q[`mono`].+ Sometimes you +$$don't$$+.)
      assert_equal %q(Sometimes you feel <code>mono</code>. Sometimes you don't.), result
    end

    test 'should not fail to restore remaining passthroughs after processing inline passthrough with macro substitution' do
      input = 'pass:m[.] pass:[.]'
      assert_equal '. .', (convert_inline_string input)
    end

    test 'should honor role on double plus passthrough' do
      result = convert_inline_string 'Print the version using [var]++{asciidoctor-version}++.'
      assert_equal 'Print the version using <span class="var">{asciidoctor-version}</span>.', result
    end

    test 'complex inline passthrough macro' do
      text_to_escape = %q([(] <'basic form'> <'logical operator'> <'basic form'> [)])
      para = block_from_string %($$#{text_to_escape}$$)
      para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal 1, passthroughs.size
      assert_equal text_to_escape, passthroughs[0][:text]

      text_to_escape_escaped = %q([(\] <'basic form'> <'logical operator'> <'basic form'> [)\])
      para = block_from_string %(pass:specialcharacters[#{text_to_escape_escaped}])
      para.extract_passthroughs para.source
      passthroughs = para.instance_variable_get :@passthroughs
      assert_equal 1, passthroughs.size
      assert_equal text_to_escape, passthroughs[0][:text]
    end

    test 'inline pass macro with a composite sub' do
      para = block_from_string %(pass:verbatim[<{backend}>])
      assert_equal '&lt;{backend}&gt;', para.content
    end

    test 'should support constrained passthrough in middle of monospace span' do
      input = 'a `foo +bar+ baz` kind of thing'
      para = block_from_string input
      assert_equal 'a <code>foo bar baz</code> kind of thing', para.content
    end

    test 'should support constrained passthrough in monospace span preceded by escaped boxed attrlist with transitional role' do
      input = %(#{BACKSLASH}[x-]`foo +bar+ baz`)
      para = block_from_string input
      assert_equal '[x-]<code>foo bar baz</code>', para.content
    end

    test 'should treat monospace phrase with escaped boxed attrlist with transitional role as monospace' do
      input = %(#{BACKSLASH}[x-]`*foo* +bar+ baz`)
      para = block_from_string input
      assert_equal '[x-]<code><strong>foo</strong> bar baz</code>', para.content
    end

    test 'should ignore escaped attrlist with transitional role on monospace phrase if not proceeded by [' do
      input = %(#{BACKSLASH}x-]`*foo* +bar+ baz`)
      para = block_from_string input
      assert_equal %(#{BACKSLASH}x-]<code><strong>foo</strong> bar baz</code>), para.content
    end

    test 'should not process passthrough inside transitional literal monospace span' do
      input = 'a [x-]`foo +bar+ baz` kind of thing'
      para = block_from_string input
      assert_equal 'a <code>foo +bar+ baz</code> kind of thing', para.content
    end

    test 'should support constrained passthrough in monospace phrase with attrlist' do
      input = '[.role]`foo +bar+ baz`'
      para = block_from_string input
      assert_equal '<code class="role">foo bar baz</code>', para.content
    end

    test 'should support attrlist on a literal monospace phrase' do
      input = '[.baz]`+foo--bar+`'
      para = block_from_string input
      assert_equal '<code class="baz">foo--bar</code>', para.content
    end

    test 'should not process an escaped passthrough macro inside a monospaced phrase' do
      input = 'use the `\pass:c[]` macro'
      para = block_from_string input
      assert_equal 'use the <code>pass:c[]</code> macro', para.content
    end

    test 'should not process an escaped passthrough macro inside a monospaced phrase with attributes' do
      input = 'use the [syntax]`\pass:c[]` macro'
      para = block_from_string input
      assert_equal 'use the <code class="syntax">pass:c[]</code> macro', para.content
    end

    test 'should honor an escaped single plus passthrough inside a monospaced phrase' do
      input = 'use `\+{author}+` to show an attribute reference'
      para = block_from_string input, attributes: { 'author' => 'Dan' }
      assert_equal 'use <code>+Dan+</code> to show an attribute reference', para.content
    end

    context 'Math macros' do
      test 'should passthrough text in asciimath macro and surround with AsciiMath delimiters' do
        using_memory_logger do |logger|
          input = 'asciimath:[x/x={(1,if x!=0),(text{undefined},if x=0):}]'
          para = block_from_string input, attributes: { 'attribute-missing' => 'warn' }
          assert_equal '\$x/x={(1,if x!=0),(text{undefined},if x=0):}\$', para.content
          assert_empty logger
        end
      end

      test 'should not recognize asciimath macro with no content' do
        input = 'asciimath:[]'
        para = block_from_string input
        assert_equal 'asciimath:[]', para.content
      end

      test 'should perform specialcharacters subs on asciimath macro content in html backend by default' do
        input = 'asciimath:[a < b]'
        para = block_from_string input
        assert_equal '\$a &lt; b\$', para.content
      end

      test 'should convert contents of asciimath macro to MathML in DocBook output if asciimath gem is available' do
        asciimath_available = !(Asciidoctor::Helpers.require_library 'asciimath', true, :ignore).nil?
        input = 'asciimath:[a < b]'
        expected = '<inlineequation><mml:math xmlns:mml="http://www.w3.org/1998/Math/MathML"><mml:mi>a</mml:mi><mml:mo>&lt;</mml:mo><mml:mi>b</mml:mi></mml:math></inlineequation>'
        using_memory_logger do |logger|
          para = block_from_string input, backend: :docbook
          actual = para.content
          if asciimath_available
            assert_equal expected, actual
            assert_equal :loaded, para.document.converter.instance_variable_get(:@asciimath_status)
          else
            assert_message logger, :WARN, 'optional gem \'asciimath\' is not available. Functionality disabled.'
            assert_equal :unavailable, para.document.converter.instance_variable_get(:@asciimath_status)
          end
        end
      end

      test 'should not perform specialcharacters subs on asciimath macro content in Docbook output if asciimath gem not available' do
        asciimath_available = !(Asciidoctor::Helpers.require_library 'asciimath', true, :ignore).nil?
        input = 'asciimath:[a < b]'
        para = block_from_string input, backend: :docbook
        para.document.converter.instance_variable_set :@asciimath_status, :unavailable
        if asciimath_available
          old_asciimath = AsciiMath
          Object.send :remove_const, :AsciiMath
        end
        assert_equal '<inlineequation><mathphrase><![CDATA[a < b]]></mathphrase></inlineequation>', para.content
        Object.const_set :AsciiMath, old_asciimath if asciimath_available
      end

      test 'should honor explicit subslist on asciimath macro' do
        input = 'asciimath:attributes[{expr}]'
        para = block_from_string input, attributes: { 'expr' => 'x != 0' }
        assert_equal '\$x != 0\$', para.content
      end

      test 'should passthrough text in latexmath macro and surround with LaTeX math delimiters' do
        input = 'latexmath:[C = \alpha + \beta Y^{\gamma} + \epsilon]'
        para = block_from_string input
        assert_equal '\(C = \alpha + \beta Y^{\gamma} + \epsilon\)', para.content
      end

      test 'should strip legacy LaTeX math delimiters around latexmath content if present' do
        input = 'latexmath:[$C = \alpha + \beta Y^{\gamma} + \epsilon$]'
        para = block_from_string input
        assert_equal '\(C = \alpha + \beta Y^{\gamma} + \epsilon\)', para.content
      end

      test 'should not recognize latexmath macro with no content' do
        input = 'latexmath:[]'
        para = block_from_string input
        assert_equal 'latexmath:[]', para.content
      end

      test 'should unescape escaped square bracket in equation' do
        input = 'latexmath:[\sqrt[3\]{x}]'
        para = block_from_string input
        assert_equal '\(\sqrt[3]{x}\)', para.content
      end

      test 'should perform specialcharacters subs on latexmath macro in html backend by default' do
        input = 'latexmath:[a < b]'
        para = block_from_string input
        assert_equal '\(a &lt; b\)', para.content
      end

      test 'should not perform specialcharacters subs on latexmath macro content in docbook backend by default' do
        input = 'latexmath:[a < b]'
        para = block_from_string input, backend: :docbook
        assert_equal '<inlineequation><alt><![CDATA[a < b]]></alt><mathphrase><![CDATA[a < b]]></mathphrase></inlineequation>', para.content
      end

      test 'should honor explicit subslist on latexmath macro' do
        input = 'latexmath:attributes[{expr}]'
        para = block_from_string input, attributes: { 'expr' => '\sqrt{4} = 2' }
        assert_equal '\(\sqrt{4} = 2\)', para.content
      end

      test 'should passthrough math macro inside another passthrough' do
        input = 'the text `asciimath:[x = y]` should be passed through as +literal+ text'
        para = block_from_string input, attributes: { 'compat-mode' => '' }
        assert_equal 'the text <code>asciimath:[x = y]</code> should be passed through as <code>literal</code> text', para.content

        input = 'the text [x-]`asciimath:[x = y]` should be passed through as `literal` text'
        para = block_from_string input
        assert_equal 'the text <code>asciimath:[x = y]</code> should be passed through as <code>literal</code> text', para.content

        input = 'the text `+asciimath:[x = y]+` should be passed through as `literal` text'
        para = block_from_string input
        assert_equal 'the text <code>asciimath:[x = y]</code> should be passed through as <code>literal</code> text', para.content
      end

      test 'should not recognize stem macro with no content' do
        input = 'stem:[]'
        para = block_from_string input
        assert_equal input, para.content
      end

      test 'should passthrough text in stem macro and surround with AsciiMath delimiters if stem attribute is asciimath, empty, or not set' do
        [
          {},
          { 'stem' => '' },
          { 'stem' => 'asciimath' },
          { 'stem' => 'bogus' },
        ].each do |attributes|
          using_memory_logger do |logger|
            input = 'stem:[x/x={(1,if x!=0),(text{undefined},if x=0):}]'
            para = block_from_string input, attributes: (attributes.merge 'attribute-missing' => 'warn')
            assert_equal '\$x/x={(1,if x!=0),(text{undefined},if x=0):}\$', para.content
            assert_empty logger
          end
        end
      end

      test 'should passthrough text in stem macro and surround with LaTeX math delimiters if stem attribute is latexmath, latex, or tex' do
        [
          { 'stem' => 'latexmath' },
          { 'stem' => 'latex' },
          { 'stem' => 'tex' },
        ].each do |attributes|
          input = 'stem:[C = \alpha + \beta Y^{\gamma} + \epsilon]'
          para = block_from_string input, attributes: attributes
          assert_equal '\(C = \alpha + \beta Y^{\gamma} + \epsilon\)', para.content
        end
      end

      test 'should apply substitutions specified on stem macro' do
        ['stem:c,a[sqrt(x) <=> {solve-for-x}]', 'stem:n,-r[sqrt(x) <=> {solve-for-x}]'].each do |input|
          para = block_from_string input, attributes: { 'stem' => 'asciimath', 'solve-for-x' => '13' }
          assert_equal '\$sqrt(x) &lt;=&gt; 13\$', para.content
        end
      end

      test 'should replace passthroughs inside stem expression' do
        [
          ['stem:[+1+]', '\$1\$'],
          ['stem:[+\infty-(+\infty)]', '\$\infty-(\infty)\$'],
          ['stem:[+++\infty-(+\infty)++]', '\$+\infty-(+\infty)\$'],
        ].each do |input, expected|
          para = block_from_string input, attributes: { 'stem' => '' }
          assert_equal expected, para.content
        end
      end

      test 'should allow passthrough inside stem expression to be escaped' do
        [
          ['stem:[\+] and stem:[+]', '\$+\$ and \$+\$'],
          ['stem:[\+1+]', '\$+1+\$'],
        ].each do |input, expected|
          para = block_from_string input, attributes: { 'stem' => '' }
          assert_equal expected, para.content
        end
      end

      test 'should not recognize stem macro with invalid substitution list' do
        [',', '42', 'a,'].each do |subs|
          input = %(stem:#{subs}[x^2])
          para = block_from_string input, attributes: { 'stem' => 'asciimath' }
          assert_equal %(stem:#{subs}[x^2]), para.content
        end
      end
    end
  end

  context 'Replacements' do
    test 'unescapes XML entities' do
      para = block_from_string '< &quot; &there4; &#34; &#x22; >'
      assert_equal '&lt; &quot; &there4; &#34; &#x22; &gt;', para.apply_subs(para.source)
    end

    test 'replaces arrows' do
      para = block_from_string '<- -> <= => \<- \-> \<= \=>'
      assert_equal '&#8592; &#8594; &#8656; &#8658; &lt;- -&gt; &lt;= =&gt;', para.apply_subs(para.source)
    end

    test 'replaces dashes' do
      input = <<~'EOS'
      -- foo foo--bar foo\--bar foo -- bar foo \-- bar
      stuff in between
      -- foo
      stuff in between
      foo --
      stuff in between
      foo --
      EOS
      expected = <<~'EOS'.chop
      &#8201;&#8212;&#8201;foo foo&#8212;&#8203;bar foo--bar foo&#8201;&#8212;&#8201;bar foo -- bar
      stuff in between&#8201;&#8212;&#8201;foo
      stuff in between
      foo&#8201;&#8212;&#8201;stuff in between
      foo&#8201;&#8212;&#8201;
      EOS
      para = block_from_string input
      assert_equal expected, para.sub_replacements(para.source)
    end

    test 'replaces dashes between multibyte word characters' do
      para = block_from_string %(富--巴)
      expected = '富&#8212;&#8203;巴'
      assert_equal expected, para.sub_replacements(para.source)
    end

    test 'replaces marks' do
      para = block_from_string '(C) (R) (TM) \(C) \(R) \(TM)'
      assert_equal '&#169; &#174; &#8482; (C) (R) (TM)', para.sub_replacements(para.source)
    end

    test 'preserves entity references' do
      input = '&amp; &#169; &#10004; &#128512; &#x2022; &#x1f600;'
      result = convert_inline_string input
      assert_equal input, result
    end

    test 'only preserves named entities with two or more letters' do
      input = '&amp; &a; &gt;'
      result = convert_inline_string input
      assert_equal '&amp; &amp;a; &gt;', result
    end

    test 'replaces punctuation' do
      para = block_from_string %(John's Hideout is the Whites`' place... foo\\'bar)
      assert_equal "John&#8217;s Hideout is the Whites&#8217; place&#8230;&#8203; foo'bar", para.sub_replacements(para.source)
    end

    test 'should replace right single quote marks' do
      given = [
        %(`'Twas the night),
        %(a `'57 Chevy!),
        %(the whites`' place),
        %(the whites`'.),
        %(the whites`'--where the wild things are),
        %(the whites`'\nhave),
        %(It's Mary`'s little lamb.),
        %(consecutive single quotes '' are not modified),
        %(he is 6' tall),
        %(\\`'),
      ]
      expected = [
        %(&#8217;Twas the night),
        %(a &#8217;57 Chevy!),
        %(the whites&#8217; place),
        %(the whites&#8217;.),
        %(the whites&#8217;--where the wild things are),
        %(the whites&#8217;\nhave),
        %(It&#8217;s Mary&#8217;s little lamb.),
        %(consecutive single quotes '' are not modified),
        %(he is 6' tall),
        %(`'),
      ]
      given.size.times do |i|
        para = block_from_string given[i]
        assert_equal expected[i], para.sub_replacements(para.source)
      end
    end
  end

  context 'Post replacements' do
    test 'line break inserted after line with line break character' do
      para = block_from_string "First line +\nSecond line"
      result = para.apply_subs para.lines, (para.expand_subs :post_replacements)
      assert_equal 'First line<br>', result.first
    end

    test 'line break inserted after line wrap with hardbreaks enabled' do
      para = block_from_string "First line\nSecond line", attributes: { 'hardbreaks' => '' }
      result = para.apply_subs para.lines, (para.expand_subs :post_replacements)
      assert_equal 'First line<br>', result.first
    end

    test 'line break character stripped from end of line with hardbreaks enabled' do
      para = block_from_string "First line +\nSecond line", attributes: { 'hardbreaks' => '' }
      result = para.apply_subs para.lines, (para.expand_subs :post_replacements)
      assert_equal 'First line<br>', result.first
    end

    test 'line break not inserted for single line with hardbreaks enabled' do
      para = block_from_string 'First line', attributes: { 'hardbreaks' => '' }
      result = para.apply_subs para.lines, (para.expand_subs :post_replacements)
      assert_equal 'First line', result.first
    end
  end

  context 'Resolve subs' do
    test 'should resolve subs for block' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :paragraph
      block.attributes['subs'] = 'quotes,normal'
      block.commit_subs
      assert_equal [:quotes, :specialcharacters, :attributes, :replacements, :macros, :post_replacements], block.subs
    end

    test 'should resolve specialcharacters sub as highlight for source block when source highlighter is coderay' do
      doc = empty_document attributes: { 'source-highlighter' => 'coderay' }, parse: true
      block = Asciidoctor::Block.new doc, :listing, content_model: :verbatim
      block.style = 'source'
      block.attributes['subs'] = 'specialcharacters'
      block.attributes['language'] = 'ruby'
      block.commit_subs
      assert_equal [:highlight], block.subs
    end

    test 'should resolve specialcharacters sub as highlight for source block when source highlighter is pygments', if: ENV['PYGMENTS_VERSION'] do
      doc = empty_document attributes: { 'source-highlighter' => 'pygments' }, parse: true
      block = Asciidoctor::Block.new doc, :listing, content_model: :verbatim
      block.style = 'source'
      block.attributes['subs'] = 'specialcharacters'
      block.attributes['language'] = 'ruby'
      block.commit_subs
      assert_equal [:highlight], block.subs
    end

    test 'should not replace specialcharacters sub with highlight for source block when source highlighter is not set' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :listing, content_model: :verbatim
      block.style = 'source'
      block.attributes['subs'] = 'specialcharacters'
      block.attributes['language'] = 'ruby'
      block.commit_subs
      assert_equal [:specialcharacters], block.subs
    end

    test 'should not use subs if subs option passed to block constructor is nil' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :paragraph, source: '*bold* _italic_', subs: nil, attributes: { 'subs' => 'quotes' }
      assert_empty block.subs
      block.commit_subs
      assert_empty block.subs
    end

    test 'should not use subs if subs option passed to block constructor is empty array' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :paragraph, source: '*bold* _italic_', subs: [], attributes: { 'subs' => 'quotes' }
      assert_empty block.subs
      block.commit_subs
      assert_empty block.subs
    end

    test 'should use subs from subs option passed to block constructor' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :paragraph, source: '*bold* _italic_', subs: [:specialcharacters], attributes: { 'subs' => 'quotes' }
      assert_equal [:specialcharacters], block.subs
      block.commit_subs
      assert_equal [:specialcharacters], block.subs
    end

    test 'should use subs from subs attribute if subs option is not passed to block constructor' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :paragraph, source: '*bold* _italic_', attributes: { 'subs' => 'quotes' }
      assert_empty block.subs
      # in this case, we have to call commit_subs to resolve the subs
      block.commit_subs
      assert_equal [:quotes], block.subs
    end

    test 'should use subs from subs attribute if subs option passed to block constructor is :default' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :paragraph, source: '*bold* _italic_', subs: :default, attributes: { 'subs' => 'quotes' }
      assert_equal [:quotes], block.subs
      block.commit_subs
      assert_equal [:quotes], block.subs
    end

    test 'should use built-in subs if subs option passed to block constructor is :default and subs attribute is absent' do
      doc = empty_document parse: true
      block = Asciidoctor::Block.new doc, :paragraph, source: '*bold* _italic_', subs: :default
      assert_equal [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements], block.subs
      block.commit_subs
      assert_equal [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements], block.subs
    end
  end
end
