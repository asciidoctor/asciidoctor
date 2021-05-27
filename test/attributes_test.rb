# frozen_string_literal: true
require_relative 'test_helper'

context 'Attributes' do
  default_logger = Asciidoctor::LoggerManager.logger

  setup do
    Asciidoctor::LoggerManager.logger = (@logger = Asciidoctor::MemoryLogger.new)
  end

  teardown do
    Asciidoctor::LoggerManager.logger = default_logger
  end

  context 'Assignment' do
    test 'creates an attribute' do
      doc = document_from_string(':frog: Tanglefoot')
      assert_equal 'Tanglefoot', doc.attributes['frog']
    end

    test 'requires a space after colon following attribute name' do
      doc = document_from_string 'foo:bar'
      assert_nil doc.attributes['foo']
    end

    # NOTE AsciiDoc.py recognizes this entry
    test 'does not recognize attribute entry if name contains colon' do
      input = ':foo:bar: baz'
      doc = document_from_string input
      refute doc.attr?('foo:bar')
      assert_equal 1, doc.blocks.size
      assert_equal :paragraph, doc.blocks[0].context
    end

    # NOTE AsciiDoc.py recognizes this entry
    test 'does not recognize attribute entry if name ends with colon' do
      input = ':foo:: bar'
      doc = document_from_string input
      refute doc.attr?('foo:')
      assert_equal 1, doc.blocks.size
      assert_equal :dlist, doc.blocks[0].context
    end

    # NOTE AsciiDoc.py does not recognize this entry
    test 'allows any word character defined by Unicode in an attribute name' do
      [['café', 'a coffee shop'], ['سمن', %(سازمان مردمنهاد)]].each do |(name, value)|
        str = <<~EOS
        :#{name}: #{value}

        {#{name}}
        EOS
        result = convert_string_to_embedded str
        assert_includes result, %(<p>#{value}</p>)
      end
    end

    test 'creates an attribute by fusing a legacy multi-line value' do
      str = <<~'EOS'
      :description: This is the first      +
                    Ruby implementation of +
                    AsciiDoc.
      EOS
      doc = document_from_string(str)
      assert_equal 'This is the first Ruby implementation of AsciiDoc.', doc.attributes['description']
    end

    test 'creates an attribute by fusing a multi-line value' do
      str = <<~'EOS'
      :description: This is the first \
                    Ruby implementation of \
                    AsciiDoc.
      EOS
      doc = document_from_string(str)
      assert_equal 'This is the first Ruby implementation of AsciiDoc.', doc.attributes['description']
    end

    test 'honors line break characters in multi-line values' do
      str = <<~'EOS'
      :signature: Linus Torvalds + \
      Linux Hacker + \
      linus.torvalds@example.com
      EOS
      doc = document_from_string(str)
      assert_equal %(Linus Torvalds +\nLinux Hacker +\nlinus.torvalds@example.com), doc.attributes['signature']
    end

    test 'should allow pass macro to surround a multi-line value that contains line breaks' do
      str = <<~'EOS'
      :signature: pass:a[{author} + \
      {title} + \
      {email}]
      EOS
      doc = document_from_string str, attributes: { 'author' => 'Linus Torvalds', 'title' => 'Linux Hacker', 'email' => 'linus.torvalds@example.com' }
      assert_equal %(Linus Torvalds +\nLinux Hacker +\nlinus.torvalds@example.com), (doc.attr 'signature')
    end

    test 'should delete an attribute that ends with !' do
      doc = document_from_string(":frog: Tanglefoot\n:frog!:")
      assert_nil doc.attributes['frog']
    end

    test 'should delete an attribute that ends with ! set via API' do
      doc = document_from_string(":frog: Tanglefoot", attributes: { 'frog!' => '' })
      assert_nil doc.attributes['frog']
    end

    test 'should delete an attribute that begins with !' do
      doc = document_from_string(":frog: Tanglefoot\n:!frog:")
      assert_nil doc.attributes['frog']
    end

    test 'should delete an attribute that begins with ! set via API' do
      doc = document_from_string(":frog: Tanglefoot", attributes: { '!frog' => '' })
      assert_nil doc.attributes['frog']
    end

    test 'should delete an attribute set via API to nil value' do
      doc = document_from_string(":frog: Tanglefoot", attributes: { 'frog' => nil })
      assert_nil doc.attributes['frog']
    end

    test "doesn't choke when deleting a non-existing attribute" do
      doc = document_from_string(':frog!:')
      assert_nil doc.attributes['frog']
    end

    test "replaces special characters in attribute value" do
      doc = document_from_string(":xml-busters: <>&")
      assert_equal '&lt;&gt;&amp;', doc.attributes['xml-busters']
    end

    test "performs attribute substitution on attribute value" do
      doc = document_from_string(":version: 1.0\n:release: Asciidoctor {version}")
      assert_equal 'Asciidoctor 1.0', doc.attributes['release']
    end

    test 'assigns attribute to empty string if substitution fails to resolve attribute' do
      input = ':release: Asciidoctor {version}'
      document_from_string input, attributes: { 'attribute-missing' => 'drop-line' }
      assert_message @logger, :INFO, 'dropping line containing reference to missing attribute: version'
    end

    test 'assigns multi-line attribute to empty string if substitution fails to resolve attribute' do
      input = <<~'EOS'
      :release: Asciidoctor +
                {version}
      EOS
      doc = document_from_string input, attributes: { 'attribute-missing' => 'drop-line' }
      assert_equal '', doc.attributes['release']
      assert_message @logger, :INFO, 'dropping line containing reference to missing attribute: version'
    end

    test 'resolves attributes inside attribute value within header' do
      input = <<~'EOS'
      = Document Title
      :big: big
      :bigfoot: {big}foot

      {bigfoot}
      EOS

      result = convert_string_to_embedded input
      assert_includes result, 'bigfoot'
    end

    test 'resolves attributes and pass macro inside attribute value outside header' do
      input = <<~'EOS'
      = Document Title

      content

      :big: pass:a,q[_big_]
      :bigfoot: {big}foot
      {bigfoot}
      EOS

      result = convert_string_to_embedded input
      assert_includes result, '<em>big</em>foot'
    end

    test 'should limit maximum size of attribute value if safe mode is SECURE' do
      expected = 'a' * 4096
      input = <<~EOS
      :name: #{'a' * 5000}

      {name}
      EOS

      result = convert_inline_string input
      assert_equal expected, result
      assert_equal 4096, result.bytesize
    end

    test 'should handle multibyte characters when limiting attribute value size' do
      expected = '日本'
      input = <<~'EOS'
      :name: 日本語

      {name}
      EOS

      result = convert_inline_string input, attributes: { 'max-attribute-value-size' => 6 }
      assert_equal expected, result
      assert_equal 6, result.bytesize
    end

    test 'should not mangle multibyte characters when limiting attribute value size' do
      expected = '日本'
      input = <<~'EOS'
      :name: 日本語

      {name}
      EOS

      result = convert_inline_string input, attributes: { 'max-attribute-value-size' => 8 }
      assert_equal expected, result
      assert_equal 6, result.bytesize
    end

    test 'should allow maximize size of attribute value to be disabled' do
      expected = 'a' * 5000
      input = <<~EOS
      :name: #{'a' * 5000}

      {name}
      EOS

      result = convert_inline_string input, attributes: { 'max-attribute-value-size' => nil }
      assert_equal expected, result
      assert_equal 5000, result.bytesize
    end

    test 'resolves user-home attribute if safe mode is less than SERVER' do
      input = <<~'EOS'
      :imagesdir: {user-home}/etc/images

      {imagesdir}
      EOS
      output = convert_inline_string input, safe: :safe
      assert_equal %(#{Asciidoctor::USER_HOME}/etc/images), output
    end

    test 'user-home attribute resolves to . if safe mode is SERVER or greater' do
      input = <<~'EOS'
      :imagesdir: {user-home}/etc/images

      {imagesdir}
      EOS
      output = convert_inline_string input, safe: :server
      assert_equal './etc/images', output
    end

    test 'user-home attribute can be overridden by API if safe mode is less than SERVER' do
      input = <<~'EOS'
      Go {user-home}!
      EOS
      output = convert_inline_string input, attributes: { 'user-home' => '/home' }
      assert_equal 'Go /home!', output
    end

    test 'user-home attribute can be overridden by API if safe mode is SERVER or greater' do
      input = <<~'EOS'
      Go {user-home}!
      EOS
      output = convert_inline_string input, safe: :server, attributes: { 'user-home' => '/home' }
      assert_equal 'Go /home!', output
    end

    test "apply custom substitutions to text in passthrough macro and assign to attribute" do
      doc = document_from_string(":xml-busters: pass:[<>&]")
      assert_equal '<>&', doc.attributes['xml-busters']
      doc = document_from_string(":xml-busters: pass:none[<>&]")
      assert_equal '<>&', doc.attributes['xml-busters']
      doc = document_from_string(":xml-busters: pass:specialcharacters[<>&]")
      assert_equal '&lt;&gt;&amp;', doc.attributes['xml-busters']
      doc = document_from_string(":xml-busters: pass:n,-c[<(C)>]")
      assert_equal '<&#169;>', doc.attributes['xml-busters']
    end

    test 'should not recognize pass macro with invalid substitution list in attribute value' do
      [',', '42', 'a,'].each do |subs|
        doc = document_from_string %(:pass-fail: pass:#{subs}[whale])
        assert_equal %(pass:#{subs}[whale]), doc.attributes['pass-fail']
      end
    end

    test "attribute is treated as defined until it's not" do
      input = <<~'EOS'
      :holygrail:
      ifdef::holygrail[]
      The holy grail has been found!
      endif::holygrail[]

      :holygrail!:
      ifndef::holygrail[]
      Buggers! What happened to the grail?
      endif::holygrail[]
      EOS
      output = convert_string input
      assert_xpath '//p', output, 2
      assert_xpath '(//p)[1][text() = "The holy grail has been found!"]', output, 1
      assert_xpath '(//p)[2][text() = "Buggers! What happened to the grail?"]', output, 1
    end

    test 'attribute set via API overrides attribute set in document' do
      doc = document_from_string(':cash: money', attributes: { 'cash' => 'heroes' })
      assert_equal 'heroes', doc.attributes['cash']
    end

    test 'attribute set via API cannot be unset by document' do
      doc = document_from_string(':cash!:', attributes: { 'cash' => 'heroes' })
      assert_equal 'heroes', doc.attributes['cash']
    end

    test 'attribute soft set via API using modifier on name can be overridden by document' do
      doc = document_from_string(':cash: money', attributes: { 'cash@' => 'heroes' })
      assert_equal 'money', doc.attributes['cash']
    end

    test 'attribute soft set via API using modifier on value can be overridden by document' do
      doc = document_from_string(':cash: money', attributes: { 'cash' => 'heroes@' })
      assert_equal 'money', doc.attributes['cash']
    end

    test 'attribute soft set via API using modifier on name can be unset by document' do
      doc = document_from_string(':cash!:', attributes: { 'cash@' => 'heroes' })
      assert_nil doc.attributes['cash']
      doc = document_from_string(':cash!:', attributes: { 'cash@' => true })
      assert_nil doc.attributes['cash']
    end

    test 'attribute soft set via API using modifier on value can be unset by document' do
      doc = document_from_string(':cash!:', attributes: { 'cash' => 'heroes@' })
      assert_nil doc.attributes['cash']
    end

    test 'attribute unset via API cannot be set by document' do
      [
        { 'cash!' => '' },
        { '!cash' => '' },
        { 'cash' => nil },
      ].each do |attributes|
        doc = document_from_string(':cash: money', attributes: attributes)
        assert_nil doc.attributes['cash']
      end
    end

    test 'attribute soft unset via API can be set by document' do
      [
        { 'cash!@' => '' },
        { '!cash@' => '' },
        { 'cash!' => '@' },
        { '!cash' => '@' },
        { 'cash' => false },
      ].each do |attributes|
        doc = document_from_string(':cash: money', attributes: attributes)
        assert_equal 'money', doc.attributes['cash']
      end
    end

    test 'can soft unset built-in attribute from API and still override in document' do
      [
        { 'sectids!@' => '' },
        { '!sectids@' => '' },
        { 'sectids!' => '@' },
        { '!sectids' => '@' },
        { 'sectids' => false },
      ].each do |attributes|
        doc = document_from_string '== Heading', attributes: attributes
        refute doc.attr?('sectids')
        assert_css '#_heading', (doc.convert standalone: false), 0
        doc = document_from_string %(:sectids:\n\n== Heading), attributes: attributes
        assert doc.attr?('sectids')
        assert_css '#_heading', (doc.convert standalone: false), 1
      end
    end

    test 'backend and doctype attributes are set by default in default configuration' do
      input = <<~'EOS'
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
        'filetype-html' => '',
      }
      expect.each do |key, val|
        assert doc.attributes.key? key
        assert_equal val, doc.attributes[key]
      end
    end

    test 'backend and doctype attributes are set by default in custom configuration' do
      input = <<~'EOS'
      = Document Title
      Author Name

      content
      EOS

      doc = document_from_string input, doctype: 'book', backend: 'docbook'
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
        'filetype-xml' => '',
      }
      expect.each do |key, val|
        assert doc.attributes.key? key
        assert_equal val, doc.attributes[key]
      end
    end

    test 'backend attributes are updated if backend attribute is defined in document and safe mode is less than SERVER' do
      input = <<~'EOS'
      = Document Title
      Author Name
      :backend: docbook
      :doctype: book

      content
      EOS

      doc = document_from_string input, safe: Asciidoctor::SafeMode::SAFE
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
        'filetype-xml' => '',
      }
      expect.each do |key, val|
        assert doc.attributes.key?(key)
        assert_equal val, doc.attributes[key]
      end

      refute doc.attributes.key?('backend-html5')
      refute doc.attributes.key?('backend-html5-doctype-article')
      refute doc.attributes.key?('basebackend-html')
      refute doc.attributes.key?('basebackend-html-doctype-article')
      refute doc.attributes.key?('doctype-article')
      refute doc.attributes.key?('filetype-html')
    end

    test 'backend attributes defined in document options overrides backend attribute in document' do
      doc = document_from_string(':backend: docbook5', safe: Asciidoctor::SafeMode::SAFE, attributes: { 'backend' => 'html5' })
      assert_equal 'html5', doc.attributes['backend']
      assert doc.attributes.key? 'backend-html5'
      assert_equal 'html', doc.attributes['basebackend']
      assert doc.attributes.key? 'basebackend-html'
    end

    test 'can only access a positional attribute from the attributes hash' do
      node = Asciidoctor::Block.new nil, :paragraph, attributes: { 1 => 'position 1' }
      assert_nil node.attr(1)
      refute node.attr?(1)
      assert_equal 'position 1', node.attributes[1]
    end

    test 'attr should not retrieve attribute from document if not set on block' do
      doc = document_from_string 'paragraph', attributes: { 'name' => 'value' }
      para = doc.blocks[0]
      assert_nil para.attr 'name'
    end

    test 'attr looks for attribute on document if fallback name is true' do
      doc = document_from_string 'paragraph', attributes: { 'name' => 'value' }
      para = doc.blocks[0]
      assert_equal 'value', (para.attr 'name', nil, true)
    end

    test 'attr uses fallback name when looking for attribute on document' do
      doc = document_from_string 'paragraph', attributes: { 'alt-name' => 'value' }
      para = doc.blocks[0]
      assert_equal 'value', (para.attr 'name', nil, 'alt-name')
    end

    test 'attr? should not check for attribute on document if not set on block' do
      doc = document_from_string 'paragraph', attributes: { 'name' => 'value' }
      para = doc.blocks[0]
      refute para.attr? 'name'
    end

    test 'attr? checks for attribute on document if fallback name is true' do
      doc = document_from_string 'paragraph', attributes: { 'name' => 'value' }
      para = doc.blocks[0]
      assert para.attr? 'name', nil, true
    end

    test 'attr? checks for fallback name when looking for attribute on document' do
      doc = document_from_string 'paragraph', attributes: { 'alt-name' => 'value' }
      para = doc.blocks[0]
      assert para.attr? 'name', nil, 'alt-name'
    end

    test 'set_attr should set value to empty string if no value is specified' do
      node = Asciidoctor::Block.new nil, :paragraph, attributes: {}
      node.set_attr 'foo'
      assert_equal '', (node.attr 'foo')
    end

    test 'remove_attr should remove attribute and return previous value' do
      doc = empty_document
      node = Asciidoctor::Block.new doc, :paragraph, attributes: { 'foo' => 'bar' }
      assert_equal 'bar', (node.remove_attr 'foo')
      assert_nil node.attr('foo')
    end

    test 'set_attr should not overwrite existing key if overwrite is false' do
      node = Asciidoctor::Block.new nil, :paragraph, attributes: { 'foo' => 'bar' }
      assert_equal 'bar', (node.attr 'foo')
      node.set_attr 'foo', 'baz', false
      assert_equal 'bar', (node.attr 'foo')
    end

    test 'set_attr should overwrite existing key by default' do
      node = Asciidoctor::Block.new nil, :paragraph, attributes: { 'foo' => 'bar' }
      assert_equal 'bar', (node.attr 'foo')
      node.set_attr 'foo', 'baz'
      assert_equal 'baz', (node.attr 'foo')
    end

    test 'set_attr should set header attribute in loaded document' do
      input = <<~'EOS'
      :uri: http://example.org

      {uri}
      EOS

      doc = Asciidoctor.load input, attributes: { 'uri' => 'https://github.com' }
      doc.set_attr 'uri', 'https://google.com'
      output = doc.convert
      assert_xpath '//a[@href="https://google.com"]', output, 1
    end

    test 'set_attribute should set attribute if key is not locked' do
      doc = empty_document
      refute doc.attr? 'foo'
      res = doc.set_attribute 'foo', 'baz'
      assert res
      assert_equal 'baz', (doc.attr 'foo')
    end

    test 'set_attribute should not set key if key is locked' do
      doc = empty_document attributes: { 'foo' => 'bar' }
      assert_equal 'bar', (doc.attr 'foo')
      res = doc.set_attribute 'foo', 'baz'
      refute res
      assert_equal 'bar', (doc.attr 'foo')
    end

    test 'set_attribute should update backend attributes' do
      doc = empty_document attributes: { 'backend' => 'html5@' }
      assert_equal '', (doc.attr 'backend-html5')
      res = doc.set_attribute 'backend', 'docbook5'
      assert res
      refute doc.attr? 'backend-html5'
      assert_equal '', (doc.attr 'backend-docbook5')
    end

    test 'verify toc attribute matrix' do
      expected_data = <<~'EOS'
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

      expected = expected_data.lines.map do |l|
        next if l.start_with? '#'
        l.split('|').map {|e| (e = e.strip) == 'nil' ? nil : e }
      end.compact

      expected.each do |expect|
        raw_attrs, toc, toc_position, toc_placement, toc_class = expect
        attrs = Hash[*raw_attrs.split.map {|e| e.include?('=') ? e.split('=', 2) : [e, ''] }.flatten]
        doc = document_from_string '', attributes: attrs
        toc ? (assert doc.attr?('toc', toc)) : (refute doc.attr?('toc'))
        toc_position ? (assert doc.attr?('toc-position', toc_position)) : (refute doc.attr?('toc-position'))
        toc_placement ? (assert doc.attr?('toc-placement', toc_placement)) : (refute doc.attr?('toc-placement'))
        toc_class ? (assert doc.attr?('toc-class', toc_class)) : (refute doc.attr?('toc-class'))
      end
    end
  end

  context 'Interpolation' do

    test "convert properly with simple names" do
      html = convert_string(":frog: Tanglefoot\n:my_super-hero: Spiderman\n\nYo, {frog}!\nBeat {my_super-hero}!")
      assert_xpath %(//p[text()="Yo, Tanglefoot!\nBeat Spiderman!"]), html, 1
    end

    test 'attribute lookup is not case sensitive' do
      input = <<~'EOS'
      :He-Man: The most powerful man in the universe

      He-Man: {He-Man}

      She-Ra: {She-Ra}
      EOS
      result = convert_string_to_embedded input, attributes: { 'She-Ra' => 'The Princess of Power' }
      assert_xpath '//p[text()="He-Man: The most powerful man in the universe"]', result, 1
      assert_xpath '//p[text()="She-Ra: The Princess of Power"]', result, 1
    end

    test "convert properly with single character name" do
      html = convert_string(":r: Ruby\n\nR is for {r}!")
      assert_xpath %(//p[text()="R is for Ruby!"]), html, 1
    end

    test "collapses spaces in attribute names" do
      input = <<~'EOS'
      Main Header
      ===========
      :My frog: Tanglefoot

      Yo, {myfrog}!
      EOS
      output = convert_string input
      assert_xpath '(//p)[1][text()="Yo, Tanglefoot!"]', output, 1
    end

    test 'ignores lines with bad attributes if attribute-missing is drop-line' do
      input = <<~'EOS'
      :attribute-missing: drop-line

      This is
      blah blah {foobarbaz}
      all there is.
      EOS
      output = convert_string_to_embedded input
      para = xmlnodes_at_css 'p', output, 1
      refute_includes 'blah blah', para.content
      assert_message @logger, :INFO, 'dropping line containing reference to missing attribute: foobarbaz'
    end

    test "attribute value gets interpretted when converting" do
      doc = document_from_string(":google: http://google.com[Google]\n\n{google}")
      assert_equal 'http://google.com[Google]', doc.attributes['google']
      output = doc.convert
      assert_xpath '//a[@href="http://google.com"][text() = "Google"]', output, 1
    end

    test 'should drop line with reference to missing attribute if attribute-missing attribute is drop-line' do
      input = <<~'EOS'
      :attribute-missing: drop-line

      Line 1: This line should appear in the output.
      Line 2: Oh no, a {bogus-attribute}! This line should not appear in the output.
      EOS

      output = convert_string_to_embedded input
      assert_match(/Line 1/, output)
      refute_match(/Line 2/, output)
      assert_message @logger, :INFO, 'dropping line containing reference to missing attribute: bogus-attribute'
    end

    test 'should not drop line with reference to missing attribute by default' do
      input = <<~'EOS'
      Line 1: This line should appear in the output.
      Line 2: A {bogus-attribute}! This time, this line should appear in the output.
      EOS

      output = convert_string_to_embedded input
      assert_match(/Line 1/, output)
      assert_match(/Line 2/, output)
      assert_match(/\{bogus-attribute\}/, output)
    end

    test 'should drop line with attribute unassignment by default' do
      input = <<~'EOS'
      :a:

      Line 1: This line should appear in the output.
      Line 2: {set:a!}This line should not appear in the output.
      EOS

      output = convert_string_to_embedded input
      assert_match(/Line 1/, output)
      refute_match(/Line 2/, output)
    end

    test 'should not drop line with attribute unassignment if attribute-undefined is drop' do
      input = <<~'EOS'
      :attribute-undefined: drop
      :a:

      Line 1: This line should appear in the output.
      Line 2: {set:a!}This line should appear in the output.
      EOS

      output = convert_string_to_embedded input
      assert_match(/Line 1/, output)
      assert_match(/Line 2/, output)
      refute_match(/\{set:a!\}/, output)
    end

    test 'should drop line that only contains attribute assignment' do
      input = <<~'EOS'
      Line 1
      {set:a}
      Line 2
      EOS

      output = convert_string_to_embedded input
      assert_xpath %(//p[text()="Line 1\nLine 2"]), output, 1
    end

    test 'should drop line that only contains unresolved attribute when attribute-missing is drop' do
      input = <<~'EOS'
      Line 1
      {unresolved}
      Line 2
      EOS

      output = convert_string_to_embedded input, attributes: { 'attribute-missing' => 'drop' }
      assert_xpath %(//p[text()="Line 1\nLine 2"]), output, 1
    end

    test "substitutes inside unordered list items" do
      html = convert_string(":foo: bar\n* snort at the {foo}\n* yawn")
      assert_xpath %(//li/p[text()="snort at the bar"]), html, 1
    end

    test 'substitutes inside section title' do
      output = convert_string(":prefix: Cool\n\n== {prefix} Title\n\ncontent")
      assert_xpath '//h2[text()="Cool Title"]', output, 1
      assert_css 'h2#_cool_title', output, 1
    end

    test 'interpolates attribute defined in header inside attribute entry in header' do
      input = <<~'EOS'
      = Title
      Author Name
      :attribute-a: value
      :attribute-b: {attribute-a}

      preamble
      EOS
      doc = document_from_string(input, parse_header_only: true)
      assert_equal 'value', doc.attributes['attribute-b']
    end

    test 'interpolates author attribute inside attribute entry in header' do
      input = <<~'EOS'
      = Title
      Author Name
      :name: {author}

      preamble
      EOS
      doc = document_from_string(input, parse_header_only: true)
      assert_equal 'Author Name', doc.attributes['name']
    end

    test 'interpolates revinfo attribute inside attribute entry in header' do
      input = <<~'EOS'
      = Title
      Author Name
      2013-01-01
      :date: {revdate}

      preamble
      EOS
      doc = document_from_string(input, parse_header_only: true)
      assert_equal '2013-01-01', doc.attributes['date']
    end

    test 'attribute entries can resolve previously defined attributes' do
      input = <<~'EOS'
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

      output = doc.convert
      assert_includes output, 'value == value'
      assert_includes output, '2010-01-01 == 2010-01-01'
    end

    test 'should warn if unterminated block comment is detected in document header' do
      input = <<~'EOS'
      = Document Title
      :foo: bar
      ////
      :hey: there

      content
      EOS
      doc = document_from_string input
      assert_nil doc.attr('hey')
      assert_message @logger, :WARN, '<stdin>: line 3: unterminated comment block', Hash
    end

    test 'substitutes inside block title' do
      input = <<~'EOS'
      :gem_name: asciidoctor

      .Require the +{gem_name}+ gem
      To use {gem_name}, the first thing to do is to import it in your Ruby source file.
      EOS
      output = convert_string_to_embedded input, attributes: { 'compat-mode' => '' }
      assert_xpath '//*[@class="title"]/code[text()="asciidoctor"]', output, 1

      input = <<~'EOS'
      :gem_name: asciidoctor

      .Require the `{gem_name}` gem
      To use {gem_name}, the first thing to do is to import it in your Ruby source file.
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//*[@class="title"]/code[text()="asciidoctor"]', output, 1
    end

    test 'sets attribute until it is deleted' do
      input = <<~'EOS'
      :foo: bar

      Crossing the {foo}.

      :foo!:

      Belly up to the {foo}.
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//p[text()="Crossing the bar."]', output, 1
      assert_xpath '//p[text()="Belly up to the bar."]', output, 0
    end

    test 'should allow compat-mode to be set and unset in middle of document' do
      input = <<~'EOS'
      :foo: bar

      [[paragraph-a]]
      `{foo}`

      :compat-mode!:

      [[paragraph-b]]
      `{foo}`

      :compat-mode:

      [[paragraph-c]]
      `{foo}`
      EOS

      result = convert_string_to_embedded input, attributes: { 'compat-mode' => '@' }
      assert_xpath '/*[@id="paragraph-a"]//code[text()="{foo}"]', result, 1
      assert_xpath '/*[@id="paragraph-b"]//code[text()="bar"]', result, 1
      assert_xpath '/*[@id="paragraph-c"]//code[text()="{foo}"]', result, 1
    end

    test 'does not disturb attribute-looking things escaped with backslash' do
      html = convert_string(":foo: bar\nThis is a \\{foo} day.")
      assert_xpath '//p[text()="This is a {foo} day."]', html, 1
    end

    test 'does not disturb attribute-looking things escaped with literals' do
      html = convert_string(":foo: bar\nThis is a +++{foo}+++ day.")
      assert_xpath '//p[text()="This is a {foo} day."]', html, 1
    end

    test 'does not substitute attributes inside listing blocks' do
      input = <<~'EOS'
      :forecast: snow

      ----
      puts 'The forecast for today is {forecast}'
      ----
      EOS
      output = convert_string(input)
      assert_match(/\{forecast\}/, output)
    end

    test 'does not substitute attributes inside literal blocks' do
      input = <<~'EOS'
      :foo: bar

      ....
      You insert the text {foo} to expand the value
      of the attribute named foo in your document.
      ....
      EOS
      output = convert_string(input)
      assert_match(/\{foo\}/, output)
    end

    test 'does not show docdir and shows relative docfile if safe mode is SERVER or greater' do
      input = <<~'EOS'
      * docdir: {docdir}
      * docfile: {docfile}
      EOS

      docdir = Dir.pwd
      docfile = File.join(docdir, 'sample.adoc')
      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SERVER, attributes: { 'docdir' => docdir, 'docfile' => docfile }
      assert_xpath '//li[1]/p[text()="docdir: "]', output, 1
      assert_xpath '//li[2]/p[text()="docfile: sample.adoc"]', output, 1
    end

    test 'shows absolute docdir and docfile paths if safe mode is less than SERVER' do
      input = <<~'EOS'
      * docdir: {docdir}
      * docfile: {docfile}
      EOS

      docdir = Dir.pwd
      docfile = File.join(docdir, 'sample.adoc')
      output = convert_string_to_embedded input, safe: Asciidoctor::SafeMode::SAFE, attributes: { 'docdir' => docdir, 'docfile' => docfile }
      assert_xpath %(//li[1]/p[text()="docdir: #{docdir}"]), output, 1
      assert_xpath %(//li[2]/p[text()="docfile: #{docfile}"]), output, 1
    end

    test 'assigns attribute defined in attribute reference with set prefix and value' do
      input = '{set:foo:bar}{foo}'
      output = convert_string_to_embedded input
      assert_xpath '//p', output, 1
      assert_xpath '//p[text()="bar"]', output, 1
    end

    test 'assigns attribute defined in attribute reference with set prefix and no value' do
      input = "{set:foo}\n{foo}yes"
      output = convert_string_to_embedded input
      assert_xpath '//p', output, 1
      assert_xpath '//p[normalize-space(text())="yes"]', output, 1
    end

    test 'assigns attribute defined in attribute reference with set prefix and empty value' do
      input = "{set:foo:}\n{foo}yes"
      output = convert_string_to_embedded input
      assert_xpath '//p', output, 1
      assert_xpath '//p[normalize-space(text())="yes"]', output, 1
    end

    test 'unassigns attribute defined in attribute reference with set prefix' do
      input = <<~'EOS'
      :attribute-missing: drop-line
      :foo:

      {set:foo!}
      {foo}yes
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//p', output, 1
      assert_xpath '//p/child::text()', output, 0
      assert_message @logger, :INFO, 'dropping line containing reference to missing attribute: foo'
    end
  end

  context "Intrinsic attributes" do

    test "substitute intrinsics" do
      Asciidoctor::INTRINSIC_ATTRIBUTES.each_pair do |key, value|
        html = convert_string("Look, a {#{key}} is here")
        # can't use Nokogiri because it interprets the HTML entities and we can't match them
        assert_match(/Look, a #{Regexp.escape(value)} is here/, html)
      end
    end

    test "don't escape intrinsic substitutions" do
      html = convert_string('happy{nbsp}together')
      assert_match(/happy&#160;together/, html)
    end

    test "escape special characters" do
      html = convert_string('<node>&</node>')
      assert_match(/&lt;node&gt;&amp;&lt;\/node&gt;/, html)
    end

    test 'creates counter' do
      input = '{counter:mycounter}'

      doc = document_from_string input
      output = doc.convert
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="1"]', output, 1
    end

    test 'creates counter silently' do
      input = '{counter2:mycounter}'

      doc = document_from_string input
      output = doc.convert
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="1"]', output, 0
    end

    test 'creates counter with numeric seed value' do
      input = '{counter2:mycounter:10}'

      doc = document_from_string input
      doc.convert
      assert_equal 10, doc.attributes['mycounter']
    end

    test 'creates counter with character seed value' do
      input = '{counter2:mycounter:A}'

      doc = document_from_string input
      doc.convert
      assert_equal 'A', doc.attributes['mycounter']
    end

    test 'can seed counter to start at 1' do
      input = <<~'EOS'
      :mycounter: 0

      {counter:mycounter}
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//p[text()="1"]', output, 1
    end

    test 'can seed counter to start at A' do
      input = <<~'EOS'
      :mycounter: @

      {counter:mycounter}
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//p[text()="A"]', output, 1
    end

    test 'increments counter with positive numeric value' do
      input = <<~'EOS'
      [subs=attributes]
      ++++
      {counter:mycounter:1}
      {counter:mycounter}
      {counter:mycounter}
      {mycounter}
      ++++
      EOS

      doc = document_from_string input, standalone: false
      output = doc.convert
      assert_equal 3, doc.attributes['mycounter']
      assert_equal %w(1 2 3 3), output.lines.map {|l| l.rstrip }
    end

    test 'increments counter with negative numeric value' do
      input = <<~'EOS'
      [subs=attributes]
      ++++
      {counter:mycounter:-2}
      {counter:mycounter}
      {counter:mycounter}
      {mycounter}
      ++++
      EOS

      doc = document_from_string input, standalone: false
      output = doc.convert
      assert_equal 0, doc.attributes['mycounter']
      assert_equal %w(-2 -1 0 0), output.lines.map {|l| l.rstrip }
    end

    test 'increments counter with ASCII character value' do
      input = <<~'EOS'
      [subs=attributes]
      ++++
      {counter:mycounter:A}
      {counter:mycounter}
      {counter:mycounter}
      {mycounter}
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_equal %w(A B C C), output.lines.map {|l| l.rstrip }
    end

    test 'increments counter with non-ASCII character value' do
      input = <<~'EOS'
      [subs=attributes]
      ++++
      {counter:mycounter:é}
      {counter:mycounter}
      {counter:mycounter}
      {mycounter}
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_equal %w(é ê ë ë), output.lines.map {|l| l.rstrip }
    end

    test 'increments counter with emoji character value' do
      input = <<~'EOS'
      [subs=attributes]
      ++++
      {counter:smiley:😋}
      {counter:smiley}
      {counter:smiley}
      {smiley}
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_equal %w(😋 😌 😍 😍), output.lines.map {|l| l.rstrip }
    end

    test 'increments counter with multi-character value' do
      input = <<~'EOS'
      [subs=attributes]
      ++++
      {counter:math:1x}
      {counter:math}
      {counter:math}
      {math}
      ++++
      EOS

      output = convert_string_to_embedded input
      assert_equal %w(1x 1y 1z 1z), output.lines.map {|l| l.rstrip }
    end

    test 'counter uses 0 as seed value if seed attribute is nil' do
      input = <<~'EOS'
      :mycounter:

      {counter:mycounter}

      {mycounter}
      EOS

      doc = document_from_string input
      output = doc.convert standalone: false
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="1"]', output, 2
    end

    test 'counter value can be reset by attribute entry' do
      input = <<~'EOS'
      :mycounter:

      before: {counter:mycounter} {counter:mycounter} {counter:mycounter}

      :mycounter!:

      after: {counter:mycounter}
      EOS

      doc = document_from_string input
      output = doc.convert standalone: false
      assert_equal 1, doc.attributes['mycounter']
      assert_xpath '//p[text()="before: 1 2 3"]', output, 1
      assert_xpath '//p[text()="after: 1"]', output, 1
    end

    test 'counter value can be advanced by attribute entry' do
      input = <<~'EOS'
      before: {counter:mycounter}

      :mycounter: 10

      after: {counter:mycounter}
      EOS

      doc = document_from_string input
      output = doc.convert standalone: false
      assert_equal 11, doc.attributes['mycounter']
      assert_xpath '//p[text()="before: 1"]', output, 1
      assert_xpath '//p[text()="after: 11"]', output, 1
    end

    test 'nested document should use counter from parent document' do
      input = <<~'EOS'
      .Title for Foo
      image::foo.jpg[]

      [cols="2*a"]
      |===
      |
      .Title for Bar
      image::bar.jpg[]

      |
      .Title for Baz
      image::baz.jpg[]
      |===

      .Title for Qux
      image::qux.jpg[]
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//div[@class="title"]', output, 4
      assert_xpath '//div[@class="title"][text() = "Figure 1. Title for Foo"]', output, 1
      assert_xpath '//div[@class="title"][text() = "Figure 2. Title for Bar"]', output, 1
      assert_xpath '//div[@class="title"][text() = "Figure 3. Title for Baz"]', output, 1
      assert_xpath '//div[@class="title"][text() = "Figure 4. Title for Qux"]', output, 1
    end

    test 'should not allow counter to modify locked attribute' do
      input = <<~'EOS'
      {counter:foo:ignored} is not {foo}
      EOS

      output = convert_string_to_embedded input, attributes: { 'foo' => 'bar' }
      assert_xpath '//p[text()="bas is not bar"]', output, 1
    end

    test 'should not allow counter2 to modify locked attribute' do
      input = <<~'EOS'
      {counter2:foo:ignored}{foo}
      EOS

      output = convert_string_to_embedded input, attributes: { 'foo' => 'bar' }
      assert_xpath '//p[text()="bar"]', output, 1
    end

    test 'should not allow counter to modify built-in locked attribute' do
      input = <<~'EOS'
      {counter:max-include-depth:128} is one more than {max-include-depth}
      EOS

      doc = document_from_string input, standalone: false
      output = doc.convert
      assert_xpath '//p[text()="65 is one more than 64"]', output, 1
      assert_equal 64, doc.attributes['max-include-depth']
    end

    test 'should not allow counter2 to modify built-in locked attribute' do
      input = <<~'EOS'
      {counter2:max-include-depth:128}{max-include-depth}
      EOS

      doc = document_from_string input, standalone: false
      output = doc.convert
      assert_xpath '//p[text()="64"]', output, 1
      assert_equal 64, doc.attributes['max-include-depth']
    end
  end

  context 'Block attributes' do
    test 'parses attribute names as name token' do
      input = <<~'EOS'
      [normal,foo="bar",_foo="_bar",foo1="bar1",foo-foo="bar-bar",foo.foo="bar.bar"]
      content
      EOS

      block = block_from_string input
      assert_equal 'bar', block.attr('foo')
      assert_equal '_bar', block.attr('_foo')
      assert_equal 'bar1', block.attr('foo1')
      assert_equal 'bar-bar', block.attr('foo-foo')
      assert_equal 'bar.bar', block.attr('foo.foo')
    end

    test 'positional attributes assigned to block' do
      input = <<~'EOS'
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
      input = <<~'EOS'
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
      input = <<~'EOS'
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
      input = <<~'EOS'
      [title='*title*']
      content
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//*[@class="title"]/strong[text()="title"]', output, 1
    end

    test 'attribute list may not begin with space' do
      input = <<~'EOS'
      [ quote]
      ____
      A famous quote.
      ____
      EOS

      doc = document_from_string input
      b1 = doc.blocks.first
      assert_equal ['[ quote]'], b1.lines
    end

    test 'attribute list may begin with comma' do
      input = <<~'EOS'
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
      input = <<~'EOS'
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
      input = <<~'EOS'
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
      input = <<~'EOS'
      [id=None]
      paragraph
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      refute para.attributes.key?('id')
    end

    test 'role? returns true if role is assigned' do
      input = <<~'EOS'
      [role="lead"]
      A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert p.role?
    end

    test 'role? does not return true if role attribute is set on document' do
      input = <<~'EOS'
      :role: lead

      A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      refute p.role?
    end

    test 'role? can check for exact role name match' do
      input = <<~'EOS'
      [role="lead"]
      A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert p.role?('lead')
      p2 = doc.blocks.last
      refute p2.role?('final')
    end

    test 'has_role? can check for precense of role name' do
      input = <<~'EOS'
      [role="lead abstract"]
      A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      refute p.role?('lead')
      assert p.has_role?('lead')
    end

    test 'has_role? does not look for role defined as document attribute' do
      input = <<~'EOS'
      :role: lead abstract

      A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      refute p.has_role?('lead')
    end

    test 'roles returns array of role names' do
      input = <<~'EOS'
      [role="story lead"]
      A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert_equal ['story', 'lead'], p.roles
    end

    test 'roles returns empty array if role attribute is not set' do
      input = 'a paragraph'

      doc = document_from_string input
      p = doc.blocks.first
      assert_equal [], p.roles
    end

    test 'roles does not return value of roles document attribute' do
      input = <<~'EOS'
      :role: story lead

      A paragraph
      EOS

      doc = document_from_string input
      p = doc.blocks.first
      assert_equal [], p.roles
    end

    test 'roles= sets the role attribute on the node' do
      doc = document_from_string 'a paragraph'
      p = doc.blocks.first
      p.role = 'foobar'
      assert_equal 'foobar', (p.attr 'role')
    end

    test 'roles= coerces array value to a space-separated string' do
      doc = document_from_string 'a paragraph'
      p = doc.blocks.first
      p.role = %w(foo bar)
      assert_equal 'foo bar', (p.attr 'role')
    end

    test "Attribute substitutions are performed on attribute list before parsing attributes" do
      input = <<~'EOS'
      :lead: role="lead"

      [{lead}]
      A paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal 'lead', para.attributes['role']
    end

    test 'id, role and options attributes can be specified on block style using shorthand syntax' do
      input = <<~'EOS'
      [literal#first.lead%step]
      A literal paragraph.
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal :literal, para.context
      assert_equal 'first', para.attributes['id']
      assert_equal 'lead', para.attributes['role']
      assert para.attributes.key?('step-option')
      refute para.attributes.key?('options')
    end

    test 'id, role and options attributes can be specified using shorthand syntax on block style using multiple block attribute lines' do
      input = <<~'EOS'
      [literal]
      [#first]
      [.lead]
      [%step]
      A literal paragraph.
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      assert_equal :literal, para.context
      assert_equal 'first', para.attributes['id']
      assert_equal 'lead', para.attributes['role']
      assert para.attributes.key?('step-option')
      refute para.attributes.key?('options')
    end

    test 'multiple roles and options can be specified in block style using shorthand syntax' do
      input = <<~'EOS'
      [.role1%option1.role2%option2]
      Text
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      assert_equal 'role1 role2', para.attributes['role']
      assert para.attributes.key?('option1-option')
      assert para.attributes.key?('option2-option')
      refute para.attributes.key?('options')
    end

    test 'options specified using shorthand syntax on block style across multiple lines should be additive' do
      input = <<~'EOS'
      [%option1]
      [%option2]
      Text
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      assert para.attributes.key?('option1-option')
      assert para.attributes.key?('option2-option')
      refute para.attributes.key?('options')
    end

    test 'roles specified using shorthand syntax on block style across multiple lines should be additive' do
      input = <<~'EOS'
      [.role1]
      [.role2.role3]
      Text
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      assert_equal 'role1 role2 role3', para.attributes['role']
    end

    test 'setting a role using the role attribute replaces any existing roles' do
      input = <<~'EOS'
      [.role1]
      [role=role2]
      [.role3]
      Text
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      assert_equal 'role2 role3', para.attributes['role']
    end

    test 'setting a role using the shorthand syntax on block style should not clear the ID' do
      input = <<~'EOS'
      [#id]
      [.role]
      Text
      EOS

      doc = document_from_string input
      para = doc.blocks.first
      assert_equal 'id', para.id
      assert_equal 'role', para.role
    end

    test 'a role can be added using add_role when the node has no roles' do
      input = 'A normal paragraph'
      doc = document_from_string(input)
      para = doc.blocks.first
      res = para.add_role 'role1'
      assert res
      assert_equal 'role1', para.attributes['role']
      assert para.has_role? 'role1'
    end

    test 'a role can be added using add_role when the node already has a role' do
      input = <<~'EOS'
      [.role1]
      A normal paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      res = para.add_role 'role2'
      assert res
      assert_equal 'role1 role2', para.attributes['role']
      assert para.has_role? 'role1'
      assert para.has_role? 'role2'
    end

    test 'a role is not added using add_role if the node already has that role' do
      input = <<~'EOS'
      [.role1]
      A normal paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      res = para.add_role 'role1'
      refute res
      assert_equal 'role1', para.attributes['role']
      assert para.has_role? 'role1'
    end

    test 'an existing role can be removed using remove_role' do
      input = <<~'EOS'
      [.role1.role2]
      A normal paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      res = para.remove_role 'role1'
      assert res
      assert_equal 'role2', para.attributes['role']
      assert para.has_role? 'role2'
      refute para.has_role?('role1')
    end

    test 'roles are removed when last role is removed using remove_role' do
      input = <<~'EOS'
      [.role1]
      A normal paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      res = para.remove_role 'role1'
      assert res
      refute para.role?
      assert_nil para.attributes['role']
      refute para.has_role? 'role1'
    end

    test 'roles are not changed when a non-existent role is removed using remove_role' do
      input = <<~'EOS'
      [.role1]
      A normal paragraph
      EOS
      doc = document_from_string(input)
      para = doc.blocks.first
      res = para.remove_role 'role2'
      refute res
      assert_equal 'role1', para.attributes['role']
      assert para.has_role? 'role1'
      refute para.has_role?('role2')
    end

    test 'roles are not changed when using remove_role if the node has no roles' do
      input = 'A normal paragraph'
      doc = document_from_string(input)
      para = doc.blocks.first
      res = para.remove_role 'role1'
      refute res
      assert_nil para.attributes['role']
      refute para.has_role?('role1')
    end

    test 'option can be specified in first position of block style using shorthand syntax' do
      input = <<~'EOS'
      [%interactive]
      - [x] checked
      EOS

      doc = document_from_string input
      list = doc.blocks.first
      assert list.attributes.key? 'interactive-option'
      refute list.attributes.key? 'options'
    end

    test 'id and role attributes can be specified on section style using shorthand syntax' do
      input = <<~'EOS'
      [dedication#dedication.small]
      == Section
      Content.
      EOS
      output = convert_string_to_embedded input
      assert_xpath '/div[@class="sect1 small"]', output, 1
      assert_xpath '/div[@class="sect1 small"]/h2[@id="dedication"]', output, 1
    end

    test 'id attribute specified using shorthand syntax should not create a special section' do
      input = <<~'EOS'
      [#idname]
      == Section

      content
      EOS

      doc = document_from_string input, backend: 'docbook'
      section = doc.blocks[0]
      refute_nil section
      assert_equal :section, section.context
      refute section.special
      output = doc.convert
      assert_css 'article:root > section', output, 1
      assert_css 'article:root > section[xml|id="idname"]', output, 1
    end

    test "Block attributes are additive" do
      input = <<~'EOS'
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
      input = <<~'EOS'
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

    test "trailing block attributes transfer to the following section" do
      input = <<~'EOS'
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
