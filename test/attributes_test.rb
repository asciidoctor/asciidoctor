# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context 'Attributes' do
  context 'Assignment' do
    test 'creates an attribute' do
      doc = document_from_string(':frog: Tanglefoot')
      assert_equal 'Tanglefoot', doc.attributes['frog']
    end

    test 'requires a space after colon following attribute name' do
      doc = document_from_string 'foo:bar'
      assert_equal nil, doc.attributes['foo']
    end

    test 'creates an attribute by fusing a legacy multi-line value' do
      str = <<-EOS
:description: This is the first      +
              Ruby implementation of +
              AsciiDoc.
      EOS
      doc = document_from_string(str)
      assert_equal 'This is the first Ruby implementation of AsciiDoc.', doc.attributes['description']
    end

    test 'creates an attribute by fusing a multi-line value' do
      str = <<-EOS
:description: This is the first \\
              Ruby implementation of \\
              AsciiDoc.
      EOS
      doc = document_from_string(str)
      assert_equal 'This is the first Ruby implementation of AsciiDoc.', doc.attributes['description']
    end

    test 'honors line break characters in multi-line values' do
      str = <<-EOS
:signature: Linus Torvalds + \\
Linux Hacker + \\
linus.torvalds@example.com
      EOS
      doc = document_from_string(str)
      assert_equal %(Linus Torvalds +\nLinux Hacker +\nlinus.torvalds@example.com), doc.attributes['signature']
    end

    test 'should delete an attribute that ends with !' do
      doc = document_from_string(":frog: Tanglefoot\n:frog!:")
      assert_equal nil, doc.attributes['frog']
    end

    test 'should delete an attribute that ends with ! set via API' do
      doc = document_from_string(":frog: Tanglefoot", :attributes => {'frog!' => ''})
      assert_equal nil, doc.attributes['frog']
    end

    test 'should delete an attribute that begins with !' do
      doc = document_from_string(":frog: Tanglefoot\n:!frog:")
      assert_equal nil, doc.attributes['frog']
    end

    test 'should delete an attribute that begins with ! set via API' do
      doc = document_from_string(":frog: Tanglefoot", :attributes => {'!frog' => ''})
      assert_equal nil, doc.attributes['frog']
    end

    test 'should delete an attribute set via API to nil value' do
      doc = document_from_string(":frog: Tanglefoot", :attributes => {'frog' => nil})
      assert_equal nil, doc.attributes['frog']
    end

    test "doesn't choke when deleting a non-existing attribute" do
      doc = document_from_string(':frog!:')
      assert_equal nil, doc.attributes['frog']
    end

    test "replaces special characters in attribute value" do
      doc = document_from_string(":xml-busters: <>&")
      assert_equal '&lt;&gt;&amp;', doc.attributes['xml-busters']
    end

    test "performs attribute substitution on attribute value" do
      doc = document_from_string(":version: 1.0\n:release: Asciidoctor {version}")
      assert_equal 'Asciidoctor 1.0', doc.attributes['release']
    end

    test "assigns attribute to empty string if substitution fails to resolve attribute" do
      doc = document_from_string ":release: Asciidoctor {version}", :attributes => { 'attribute-missing' => 'drop-line' }
      assert_equal '', doc.attributes['release']
    end

    test "assigns multi-line attribute to empty string if substitution fails to resolve attribute" do
      doc = document_from_string ":release: Asciidoctor +\n          {version}", :attributes => { 'attribute-missing' => 'drop-line' }
      assert_equal '', doc.attributes['release']
    end

    test 'resolves user-home attribute if safe mode is less than SERVER' do
      input = <<-EOS
:imagesdir: {user-home}/etc/images

{imagesdir}
EOS
      output = render_embedded_string input, :doctype => :inline, :safe => :safe
      if RUBY_VERSION >= '1.9'
        assert_equal %(#{Dir.home}/etc/images), output
      else
        assert_equal %(#{ENV['HOME']}/etc/images), output
      end
    end

    test 'user-home attribute resolves to . if safe mode is SERVER or greater' do
      input = <<-EOS
:imagesdir: {user-home}/etc/images

{imagesdir}
EOS
      output = render_embedded_string input, :doctype => :inline, :safe => :server
      if RUBY_VERSION >= '1.9'
        assert_equal %(./etc/images), output
      else
        assert_equal %(./etc/images), output
      end
    end

    test "apply custom substitutions to text in passthrough macro and assign to attribute" do
      doc = document_from_string(":xml-busters: pass:[<>&]")
      assert_equal '<>&', doc.attributes['xml-busters']
      doc = document_from_string(":xml-busters: pass:none[<>&]")
      assert_equal '<>&', doc.attributes['xml-busters']
      doc = document_from_string(":xml-busters: pass:specialcharacters[<>&]")
      assert_equal '&lt;&gt;&amp;', doc.attributes['xml-busters']
    end

    test "attribute is treated as defined until it's not" do
      input = <<-EOS
:holygrail:
ifdef::holygrail[]
The holy grail has been found!
endif::holygrail[]

:holygrail!:
ifndef::holygrail[]
Buggers! What happened to the grail?
endif::holygrail[]
      EOS
      output = render_string input
      assert_xpath '//p', output, 2
      assert_xpath '(//p)[1][text() = "The holy grail has been found!"]', output, 1
      assert_xpath '(//p)[2][text() = "Buggers! What happened to the grail?"]', output, 1
    end

    # Validates requirement: "Header attributes are overridden by command-line attributes."
    test 'attribute defined in document options overrides attribute in document' do
      doc = document_from_string(':cash: money', :attributes => {'cash' => 'heroes'})
      assert_equal 'heroes', doc.attributes['cash']
    end

    test 'attribute defined in document options cannot be unassigned in document' do
      doc = document_from_string(':cash!:', :attributes => {'cash' => 'heroes'})
      assert_equal 'heroes', doc.attributes['cash']
    end

    test 'attribute undefined in document options cannot be assigned in document' do
      doc = document_from_string(':cash: money', :attributes => {'cash!' => '' })
      assert_equal nil, doc.attributes['cash']
      doc = document_from_string(':cash: money', :attributes => {'cash' => nil })
      assert_equal nil, doc.attributes['cash']
    end

    test 'backend and doctype attributes are set by default in default configuration' do
      input = <<-EOS
= Document Title
Author Name

content
      EOS

      doc = document_from_string input
      expect = {
        'backend' => 'html5',
        'backend-html5' => '',
        'backend-html5-doctype-article' => '',
        'outfilesuffix' => '.html',
        'basebackend' => 'html',
        'basebackend-html' => '',
        'basebackend-html-doctype-article' => '',
        'doctype' => 'article',
        'doctype-article' => '',
        'filetype' => 'html',
        'filetype-html' => ''
      }
      expect.each do |key, val|
        assert doc.attributes.key? key
        assert_equal val, doc.attributes[key]
      end
    end

    test 'backend and doctype attributes are set by default in custom configuration' do
      input = <<-EOS
= Document Title
Author Name

content
      EOS

      doc = document_from_string input, :doctype => 'book', :backend => 'docbook'
      expect = {
        'backend' => 'docbook5',
        'backend-docbook5' => '',
        'backend-docbook5-doctype-book' => '',
        'outfilesuffix' => '.xml',
        'basebackend' => 'docbook',
        'basebackend-docbook' => '',
        'basebackend-docbook-doctype-book' => '',
        'doctype' => 'book',
        'doctype-book' => '',
        'filetype' => 'xml',
        'filetype-xml' => ''
      }
      expect.each do |key, val|
        assert doc.attributes.key? key
        assert_equal val, doc.attributes[key]
      end
    end

    test 'backend attributes are updated if backend attribute is defined in document and safe mode is less than SERVER' do
      input = <<-EOS
= Document Title
Author Name
:backend: docbook
:doctype: book

content
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE
      expect = {
        'backend' => 'docbook5',
        'backend-docbook5' => '',
        'backend-docbook5-doctype-book' => '',
        'outfilesuffix' => '.xml',
        'basebackend' => 'docbook',
        'basebackend-docbook' => '',
        'basebackend-docbook-doctype-book' => '',
        'doctype' => 'book',
        'doctype-book' => '',
        'filetype' => 'xml',
        'filetype-xml' => ''
      }
      expect.each do |key, val|
        assert doc.attributes.key?(key)
        assert_equal val, doc.attributes[key]
      end

      assert !doc.attributes.key?('backend-html5')
      assert !doc.attributes.key?('backend-html5-doctype-article')
      assert !doc.attributes.key?('basebackend-html')
      assert !doc.attributes.key?('basebackend-html-doctype-article')
      assert !doc.attributes.key?('doctype-article')
      assert !doc.attributes.key?('filetype-html')
    end

    test 'backend attributes defined in document options overrides backend attribute in document' do
      doc = document_from_string(':backend: docbook45', :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'backend' => 'html5'})
      assert_equal 'html5', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-html5'
      assert_equal 'html', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-html'
    end

    test 'set_attr should not overwrite existing key if overwrite is false' do
      node = Asciidoctor::Block.new nil, :paragraph, :attributes => { 'foo' => 'bar' }
      assert_equal 'bar', (node.attr 'foo')
      node.set_attr 'foo', 'baz', false
      assert_equal 'bar', (node.attr 'foo')
    end

    test 'set_attr should overwrite existing key by default' do
      node = Asciidoctor::Block.new nil, :paragraph, :attributes => { 'foo' => 'bar' }
      assert_equal 'bar', (node.attr 'foo')
      node.set_attr 'foo', 'baz'
      assert_equal 'baz', (node.attr 'foo')
    end

    test 'verify toc attribute matrix' do
      expected_data = <<-EOS
#attributes                               |toc|toc-position|toc-placement|toc-class
toc                                       |   |nil         |auto         |nil
toc=header                                |   |nil         |auto         |nil
toc=beeboo                                |   |nil         |auto         |nil
toc=left                                  |   |left        |auto         |toc2
toc2                                      |   |left        |auto         |toc2
toc=right                                 |   |right       |auto         |toc2
toc=preamble                              |   |content     |preamble     |nil
toc=macro                                 |   |content     |macro        |nil
toc toc-placement=macro toc-position=left |   |content     |macro        |nil
toc toc-placement!                        |   |content     |macro        |nil
      EOS

      expected = expected_data.strip.lines.map {|l|
        next if l.start_with? '#'
        l.split('|').map {|e| (e = e.strip) == 'nil' ? nil : e }
      }.compact

      expected.each do |expect|
        raw_attrs, toc, toc_position, toc_placement, toc_class = expect
        attrs = Hash[*(raw_attrs.split ' ').map {|e| e.include?('=') ? e.split('=') : [e, ''] }.flatten]
        doc = document_from_string '', :attributes => attrs
        toc ? (assert doc.attr?('toc', toc)) : (assert !doc.attr?('toc')) 
        toc_position ? (assert doc.attr?('toc-position', toc_position)) : (assert !doc.attr?('toc-position')) 
        toc_placement ? (assert doc.attr?('toc-placement', toc_placement)) : (assert !doc.attr?('toc-placement')) 
        toc_class ? (assert doc.attr?('toc-class', toc_class)) : (assert !doc.attr?('toc-class')) 
      end
    end
  end

  context 'Interpolation' do

    test "render properly with simple names" do
      html = render_string(":frog: Tanglefoot\n:my_super-hero: Spiderman\n\nYo, {frog}!\nBeat {my_super-hero}!")
      result = Nokogiri::HTML(html)
      assert_equal "Yo, Tanglefoot!\nBeat Spiderman!", result.css("p").first.content.strip
    end

    test 'attribute lookup is not case sensitive' do
      input = <<-EOS
:He-Man: The most powerful man in the universe

He-Man: {He-Man}

She-Ra: {She-Ra}
      EOS
      result = render_embedded_string input, :attributes => {'She-Ra' => 'The Princess of Power'}
      assert_xpath '//p[text()="He-Man: The most powerful man in the universe"]', result, 1
      assert_xpath '//p[text()="She-Ra: The Princess of Power"]', result, 1
    end

    test "render properly with single character name" do
      html = render_string(":r: Ruby\n\nR is for {r}!")
      result = Nokogiri::HTML(html)
      assert_equal 'R is for Ruby!', result.css("p").first.content.strip
    end

    test "collapses spaces in attribute names" do
      input = <<-EOS
Main Header
===========
:My frog: Tanglefoot

Yo, {myfrog}!
      EOS
      output = render_string input
      assert_xpath '(//p)[1][text()="Yo, Tanglefoot!"]', output, 1
    end

    test "ignores lines with bad attributes if attribute-missing is drop-line" do
      input = <<-EOS
:attribute-missing: drop-line

This is
blah blah {foobarbaz}
all there is.
      EOS
      html = render_embedded_string input
      result = Nokogiri::HTML(html)
      refute_match(/blah blah/m, result.css("p").first.content.strip)
    end

    test "attribute value gets interpretted when rendering" do
      doc = document_from_string(":google: http://google.com[Google]\n\n{google}")
      assert_equal 'http://google.com[Google]', doc.attributes['google']
      output = doc.render
      assert_xpath '//a[@href="http://google.com"][text() = "Google"]', output, 1
    end

    test 'should drop line with reference to missing attribute if attribute-missing attribute is drop-line' do
      input = <<-EOS
:attribute-missing: drop-line

Line 1: This line should appear in the output.
Line 2: Oh no, a {bogus-attribute}! This line should not appear in the output.
      EOS

      output = render_embedded_string input
      assert_match(/Line 1/, output)
      refute_match(/Line 2/, output)
    end

    test 'should not drop line with reference to missing attribute by default' do
      input = <<-EOS
Line 1: This line should appear in the output.
Line 2: A {bogus-attribute}! This time, this line should appear in the output.
      EOS

      output = render_embedded_string input
      assert_match(/Line 1/, output)
      assert_match(/Line 2/, output)
      assert_match(/\{bogus-attribute\}/, output)
    end

    test 'should drop line with attribute unassignment by default' do
      input = <<-EOS
:a:

Line 1: This line should appear in the output.
Line 2: {set:a!}This line should not appear in the output.
      EOS

      output = render_embedded_string input
      assert_match(/Line 1/, output)
      refute_match(/Line 2/, output)
    end

    test 'should not drop line with attribute unassignment if attribute-undefined is drop' do
      input = <<-EOS
:attribute-undefined: drop
:a:

Line 1: This line should appear in the output.
Line 2: {set:a!}This line should not appear in the output.
      EOS

      output = render_embedded_string input
      assert_match(/Line 1/, output)
      assert_match(/Line 2/, output)
      refute_match(/\{set:a!\}/, output)
    end

    test "substitutes inside unordered list items" do
      html = render_string(":foo: bar\n* snort at the {foo}\n* yawn")
      result = Nokogiri::HTML(html)
      assert_match(/snort at the bar/, result.css("li").first.content.strip)
    end

    test 'substitutes inside section title' do
      output = render_string(":prefix: Cool\n\n== {prefix} Title\n\ncontent")
      result = Nokogiri::HTML(output)
      assert_match(/Cool Title/, result.css('h2').first.content)
      assert_match(/_cool_title/, result.css('h2').first.attr('id'))
    end

    test 'interpolates attribute defined in header inside attribute entry in header' do
      input = <<-EOS
= Title
Author Name
:attribute-a: value
:attribute-b: {attribute-a}

preamble
      EOS
      doc = document_from_string(input, :parse_header_only => true)
      assert_equal 'value', doc.attributes['attribute-b']
    end

    test 'interpolates author attribute inside attribute entry in header' do
      input = <<-EOS
= Title
Author Name
:name: {author}

preamble
      EOS
      doc = document_from_string(input, :parse_header_only => true)
      assert_equal 'Author Name', doc.attributes['name']
    end

    test 'interpolates revinfo attribute inside attribute entry in header' do
      input = <<-EOS
= Title
Author Name
2013-01-01
:date: {revdate}

preamble
      EOS
      doc = document_from_string(input, :parse_header_only => true)
      assert_equal '2013-01-01', doc.attributes['date']
    end

    test 'attribute entries can resolve previously defined attributes' do
      input = <<-EOS
= Title
Author Name
v1.0, 2010-01-01: First release!
:a: value
:a2: {a}
:revdate2: {revdate}

{a} == {a2}

{revdate} == {revdate2}
      EOS

      doc = document_from_string input
      assert_equal '2010-01-01', doc.attr('revdate')
      assert_equal '2010-01-01', doc.attr('revdate2')
      assert_equal 'value', doc.attr('a')
      assert_equal 'value', doc.attr('a2')

      output = doc.render
      assert output.include?('value == value')
      assert output.include?('2010-01-01 == 2010-01-01')
    end

    test 'substitutes inside block title' do
      input = <<-EOS
:gem_name: asciidoctor

.Require the +{gem_name}+ gem
To use {gem_name}, the first thing to do is to import it in your Ruby source file.
      EOS
      output = render_embedded_string input, :attributes => {'compat-mode' => ''}
      assert_xpath '//*[@class="title"]/code[text()="asciidoctor"]', output, 1

      input = <<-EOS
:gem_name: asciidoctor

.Require the `{gem_name}` gem
To use {gem_name}, the first thing to do is to import it in your Ruby source file.
      EOS
      output = render_embedded_string input
      assert_xpath '//*[@class="title"]/code[text()="asciidoctor"]', output, 1
    end

    test 'renders attribute until it is deleted' do
      input = <<-EOS
:foo: bar

Crossing the {foo}.

:foo!:

Belly up to the {foo}.
      EOS
      output = render_embedded_string input
      assert_xpath '//p[text()="Crossing the bar."]', output, 1
      assert_xpath '//p[text()="Belly up to the bar."]', output, 0
    end

    test 'does not disturb attribute-looking things escaped with backslash' do
      html = render_string(":foo: bar\nThis is a \\{foo} day.")
      result = Nokogiri::HTML(html)
      assert_equal 'This is a {foo} day.', result.css('p').first.content.strip
    end

    test 'does not disturb attribute-looking things escaped with literals' do
      html = render_string(":foo: bar\nThis is a +++{foo}+++ day.")
      result = Nokogiri::HTML(html)
      assert_equal 'This is a {foo} day.', result.css('p').first.content.strip
    end

    test 'does not substitute attributes inside listing blocks' do
      input = <<-EOS
:forecast: snow 

----
puts 'The forecast for today is {forecast}'
----
      EOS
      output = render_string(input)
      assert_match(/\{forecast\}/, output)
    end

    test 'does not substitute attributes inside literal blocks' do
       input = <<-EOS
:foo: bar

....
You insert the text {foo} to expand the value
of the attribute named foo in your document.
....
       EOS
      output = render_string(input)
      assert_match(/\{foo\}/, output)
    end

    test 'does not show docdir and shows relative docfile if safe mode is SERVER or greater' do
      input = <<-EOS
* docdir: {docdir}
* docfile: {docfile}
      EOS

      docdir = Dir.pwd
      docfile = File.join(docdir, 'sample.asciidoc')
      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docdir' => docdir, 'docfile' => docfile}
      assert_xpath '//li[1]/p[text()="docdir: "]', output, 1
      assert_xpath '//li[2]/p[text()="docfile: sample.asciidoc"]', output, 1
    end

    test 'shows absolute docdir and docfile paths if safe mode is less than SERVER' do
      input = <<-EOS
* docdir: {docdir}
* docfile: {docfile}
      EOS

      docdir = Dir.pwd
      docfile = File.join(docdir, 'sample.asciidoc')
      output = render_embedded_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => docdir, 'docfile' => docfile}
      assert_xpath %(//li[1]/p[text()="docdir: #{docdir}"]), output, 1
      assert_xpath %(//li[2]/p[text()="docfile: #{docfile}"]), output, 1
    end

    test 'assigns attribute defined in attribute reference with set prefix and value' do
      input = '{set:foo:bar}{foo}' 
      output = render_embedded_string input 
      assert_xpath '//p', output, 1
      assert_xpath '//p[text()="bar"]', output, 1
    end

    test 'assigns attribute defined in attribute reference with set prefix and no value' do
      input = "{set:foo}\n{foo}yes"
      output = render_embedded_string input 
      assert_xpath '//p', output, 1
      assert_xpath '//p[normalize-space(text())="yes"]', output, 1
    end

    test 'assigns attribute defined in attribute reference with set prefix and empty value' do
      input = "{set:foo:}\n{foo}yes"
      output = render_embedded_string input 
      assert_xpath '//p', output, 1
      assert_xpath '//p[normalize-space(text())="yes"]', output, 1
    end

    test 'unassigns attribute defined in attribute reference with set prefix' do
      input = <<-EOS
:attribute-missing: drop-line
:foo:

{set:foo!}
{foo}yes
      EOS
      output = render_embedded_string input
      assert_xpath '//p', output, 1
      assert_xpath '//p/child::text()', output, 0
    end
  end

  context "Intrinsic attributes" do

    test "substitute intrinsics" do
      Asciidoctor::INTRINSIC_ATTRIBUTES.each_pair do |key, value|
        html = render_string("Look, a {#{key}} is here")
        # can't use Nokogiri because it interprets the HTML entities and we can't match them
        assert_match(/Look, a #{Regexp.escape(value)} is here/, html)
      end
    end

    test "don't escape intrinsic substitutions" do
      html = render_string('happy{nbsp}together')
      assert_match(/happy&#160;together/, html)
    end

    test "escape special characters" do
      html = render_string('<node>&</node>')
      assert_match(/&lt;node&gt;&amp;&lt;\/node&gt;/, html)
    end

    test 'creates counter' do
      input = <<-EOS
{counter:mycounter}
      EOS

      doc = document_from_string input
      output = doc.render
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="1"]', output, 1
    end

    test 'creates counter silently' do
      input = <<-EOS
{counter2:mycounter}
      EOS

      doc = document_from_string input
      output = doc.render
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="1"]', output, 0
    end

    test 'creates counter with numeric seed value' do
      input = <<-EOS
{counter2:mycounter:10}
      EOS

      doc = document_from_string input
      doc.render
      assert_equal 10, doc.attributes['mycounter']
    end

    test 'creates counter with character seed value' do
      input = <<-EOS
{counter2:mycounter:A}
      EOS

      doc = document_from_string input
      doc.render
      assert_equal 'A', doc.attributes['mycounter']
    end

    test 'increments counter with numeric value' do
      input = <<-EOS
:mycounter: 1

{counter:mycounter}

{mycounter}
      EOS

      doc = document_from_string input
      output = doc.render
      assert_equal 2, doc.attributes['mycounter']
      assert_xpath '//p[text()="2"]', output, 2
    end

    test 'increments counter with character value' do
      input = <<-EOS
:mycounter: @

{counter:mycounter}

{mycounter}
      EOS

      doc = document_from_string input
      output = doc.render
      assert_equal 'A', doc.attributes['mycounter']
      assert_xpath '//p[text()="A"]', output, 2
    end
    
    test 'counter uses 0 as seed value if seed attribute is nil' do
      input = <<-EOS
:mycounter:

{counter:mycounter}

{mycounter}
      EOS

      doc = document_from_string input
      output = doc.render :header_footer => false
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="1"]', output, 2
    end

    test 'counter value can be reset by attribute entry' do
      input = <<-EOS
:mycounter:

before: {counter:mycounter} {counter:mycounter} {counter:mycounter}

:mycounter!:

after: {counter:mycounter}
      EOS

      doc = document_from_string input
      output = doc.render :header_footer => false
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="before: 1 2 3"]', output, 1
      assert_xpath '//p[text()="after: 1"]', output, 1
    end
  end

  context 'Block attributes' do
    test 'positional attributes assigned to block' do
      input = <<-EOS
[quote, author, source]
____
A famous quote.
____
      EOS
      doc = document_from_string(input)
      qb = doc.blocks.first
      assert_equal 'quote', qb.style
      assert_equal 'author', qb.attr('attribution')
      assert_equal 'author', qb.attr(:attribution)
      assert_equal 'author', qb.attributes['attribution']
      assert_equal 'source', qb.attributes['citetitle']
    end

    test 'normal substitutions are performed on single-quoted positional attribute' do
      input = <<-EOS
[quote, author, 'http://wikipedia.org[source]']
____
A famous quote.
____
      EOS
      doc = document_from_string(input)
      qb = doc.blocks.first
      assert_equal 'quote', qb.style
      assert_equal 'author', qb.attr('attribution')
      assert_equal 'author', qb.attr(:attribution)
      assert_equal 'author', qb.attributes['attribution']
      assert_equal '<a href="http://wikipedia.org">source</a>', qb.attributes['citetitle']
    end

    test 'normal substitutions are performed on single-quoted named attribute' do
      input = <<-EOS
[quote, author, citetitle='http://wikipedia.org[source]']
____
A famous quote.
____
      EOS
      doc = document_from_string(input)
      qb = doc.blocks.first
      assert_equal 'quote', qb.style
      assert_equal 'author', qb.attr('attribution')
      assert_equal 'author', qb.attr(:attribution)
      assert_equal 'author', qb.attributes['attribution']
      assert_equal '<a href="http://wikipedia.org">source</a>', qb.attributes['citetitle']
    end

    test 'normal substitutions are performed once on single-quoted named title attribute' do
      input = <<-EOS
[title='*title*']
content
      EOS
      output = render_embedded_string input
      assert_xpath '//*[@class="title"]/strong[text()="title"]', output, 1
    end

    test 'attribute list may begin with space' do
      input = <<-EOS
[ quote]
____
A famous quote.
____
      EOS

      doc = document_from_string input
      qb = doc.blocks.first
      assert_equal 'quote', qb.style
    end

    test 'attribute list may begin with comma' do
      input = <<-EOS
[, author, source]
____
A famous quote.
____
      EOS

      doc = document_from_string input
      qb = doc.blocks.first
      assert_equal 'quote', qb.style
      assert_equal 'author', qb.attributes['attribution']
      assert_equal 'source', qb.attributes['citetitle']
    end

    test 'first attribute in list may be double quoted' do
      input = <<-EOS
["quote", "author", "source", role="famous"]
____
A famous quote.
____
      EOS

      doc = document_from_string input
      qb = doc.blocks.first
      assert_equal 'quote', qb.style
      assert_equal 'author', qb.attributes['attribution']
      assert_equal 'source', qb.attributes['citetitle']
      assert_equal 'famous', qb.attributes['role']
    end

    test 'first attribute in list may be single quoted' do
      input = <<-EOS
['quote', 'author', 'source', role='famous']
____
A famous quote.
____
      EOS

      doc = document_from_string input
      qb = doc.blocks.first
      assert_equal 'quote', qb.style
      assert_equal 'author', qb.attributes['attribution']
      assert_equal 'source', qb.attributes['citetitle']
      assert_equal 'famous', qb.attributes['role']
    end

    test 'attribute with value None without quotes is ignored' do
      input = <<-EOS
[id=None]
paragraph
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      assert !para.attributes.has_key?('id')
    end

    test 'role? returns true if role is assigned' do
      input = <<-EOS
[role="lead"]
A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert p.role?
    end

    test 'role? can check for exact role name match' do
      input = <<-EOS
[role="lead"]
A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert p.role?('lead')
      p2 = doc.blocks.last
      assert !p2.role?('final')
    end

    test 'has_role? can check for precense of role name' do
      input = <<-EOS
[role="lead abstract"]
A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert !p.role?('lead')
      assert p.has_role?('lead')
    end

    test 'roles returns array of role names' do
      input = <<-EOS
[role="story lead"]
A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert_equal ['story', 'lead'], p.roles
    end

    test 'roles returns empty array if role attribute is not set' do
      input = <<-EOS
A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert_equal [], p.roles
    end

    test "Attribute substitutions are performed on attribute list before parsing attributes" do
      input = <<-EOS
:lead: role="lead"

[{lead}]
A paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal 'lead', para.attributes['role']
    end

    test 'id, role and options attributes can be specified on block style using shorthand syntax' do
      input = <<-EOS
[normal#first.lead%step]
A normal paragraph.
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal 'first', para.attributes['id']
      assert_equal 'lead', para.attributes['role']
      assert_equal 'step', para.attributes['options']
      assert para.attributes.has_key?('step-option')
    end

    test 'multiple roles and options can be specified in block style using shorthand syntax' do
      input = <<-EOS
[.role1%option1.role2%option2]
Text
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      assert_equal 'role1 role2', para.attributes['role']
      assert_equal 'option1,option2', para.attributes['options']
      assert para.attributes.has_key?('option1-option')
      assert para.attributes.has_key?('option2-option')
    end

    test 'option can be specified in first position of block style using shorthand syntax' do
      input = <<-EOS
[%interactive]
- [x] checked
      EOS

      doc = document_from_string input
      list = doc.blocks.first
      assert_equal 'interactive', list.attributes['options']
      assert list.attributes.has_key?('interactive-option')
      assert list.attributes[1] == '%interactive'
    end

    test 'id and role attributes can be specified on section style using shorthand syntax' do
      input = <<-EOS
[dedication#dedication.small]
== Section
Content.
      EOS
      output = render_embedded_string input
      assert_xpath '/div[@class="sect1 small"]', output, 1
      assert_xpath '/div[@class="sect1 small"]/h2[@id="dedication"]', output, 1
    end

    test 'id attribute specified using shorthand syntax should not create a special section' do
      input = <<-EOS
[#idname]
== Section

content
      EOS

      doc = document_from_string input, :backend => 'docbook45'
      section = doc.blocks[0]
      refute_nil section
      assert_equal :section, section.context
      assert !section.special
      output = doc.convert
      assert_css 'section', output, 1
      assert_css 'section#idname', output, 1
    end

    test "Block attributes are additive" do
      input = <<-EOS
[id='foo']
[role='lead']
A paragraph.
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal 'foo', para.id
      assert_equal 'lead', para.attributes['role']
    end

    test "Last wins for id attribute" do
      input = <<-EOS
[[bar]]
[[foo]]
== Section

paragraph

[[baz]]
[id='coolio']
=== Section
      EOS
      doc = document_from_string(input)
      sec = doc.first_section
      assert_equal 'foo', sec.id
      subsec = sec.blocks.last
      assert_equal 'coolio', subsec.id
    end

    test 'block id above document title sets id on document' do
      input = <<-EOS
[[reference]]
Reference Manual
================
:css-signature: refguide

preamble
      EOS
      doc = document_from_string input
      assert_equal 'reference', doc.id 
      assert_equal 'refguide', doc.attr('css-signature')
      output = doc.render
      assert_xpath '//body[@id="reference"]', output, 1
    end

    test "trailing block attributes tranfer to the following section" do
      input = <<-EOS
[[one]]

== Section One

paragraph

[[sub]]
// try to mess this up!

=== Sub-section

paragraph

[role='classy']

////
block comment
////

== Section Two

content
      EOS
      doc = document_from_string(input)
      section_one = doc.blocks.first
      assert_equal 'one', section_one.id
      subsection = section_one.blocks.last
      assert_equal 'sub', subsection.id
      section_two = doc.blocks.last
      assert_equal 'classy', section_two.attr(:role)
    end
  end

end
