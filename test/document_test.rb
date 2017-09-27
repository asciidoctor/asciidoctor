# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

BUILT_IN_ELEMENTS = %w(admonition audio colist dlist document embedded example floating_title image inline_anchor inline_break inline_button inline_callout inline_footnote inline_image inline_indexterm inline_kbd inline_menu inline_quoted listing literal stem olist open page_break paragraph pass preamble quote section sidebar table thematic_break toc ulist verse video)

context 'Document' do

  context 'Example document' do
    test 'document title' do
      doc = example_document(:asciidoc_index)
      assert_equal 'AsciiDoc Home Page', doc.doctitle
      assert_equal 'AsciiDoc Home Page', doc.name
      refute_nil doc.header
      assert_equal :section, doc.header.context
      assert_equal 'header', doc.header.sectname
      assert_equal 14, doc.blocks.size
      assert_equal :preamble, doc.blocks[0].context
      assert_equal :section, doc.blocks[1].context

      # verify compat-mode is set when atx-style doctitle is used
      result = doc.blocks[0].convert
      assert_xpath %q(//em[text()="Stuart Rackham"]), result, 1
    end
  end

  context 'Default settings' do
    test 'safe mode level set to SECURE by default' do
      doc = empty_document
      assert_equal Asciidoctor::SafeMode::SECURE, doc.safe
    end

    test 'safe mode level set using string' do
      doc = empty_document :safe => 'server'
      assert_equal Asciidoctor::SafeMode::SERVER, doc.safe

      doc = empty_document :safe => 'foo'
      assert_equal Asciidoctor::SafeMode::SECURE, doc.safe
    end

    test 'safe mode level set using symbol' do
      doc = empty_document :safe => :server
      assert_equal Asciidoctor::SafeMode::SERVER, doc.safe

      doc = empty_document :safe => :foo
      assert_equal Asciidoctor::SafeMode::SECURE, doc.safe
    end

    test 'safe mode level set using integer' do
      doc = empty_document :safe => 10
      assert_equal Asciidoctor::SafeMode::SERVER, doc.safe

      doc = empty_document :safe => 100
      assert_equal 100, doc.safe
    end

    test 'safe mode attributes are set on document' do
      doc = empty_document
      assert_equal Asciidoctor::SafeMode::SECURE, doc.attr('safe-mode-level')
      assert_equal 'secure', doc.attr('safe-mode-name')
      assert doc.attr?('safe-mode-secure')
      refute doc.attr?('safe-mode-unsafe')
      refute doc.attr?('safe-mode-safe')
      refute doc.attr?('safe-mode-server')
    end

    test 'safe mode level can be set in the constructor' do
      doc = Asciidoctor::Document.new [], :safe => Asciidoctor::SafeMode::SAFE
      assert_equal Asciidoctor::SafeMode::SAFE, doc.safe
    end

    test 'safe model level cannot be modified' do
      doc = empty_document
      begin
        doc.safe = Asciidoctor::SafeMode::UNSAFE
        flunk 'safe mode property of Asciidoctor::Document should not be writable!'
      rescue
      end
    end

    test 'toc and sectnums should be enabled by default for DocBook backend' do
      doc = document_from_string 'content', :backend => 'docbook', :parse => true
      assert doc.attr?('toc')
      assert doc.attr?('sectnums')
      result = doc.convert
      assert_match('<?asciidoc-toc?>', result)
      assert_match('<?asciidoc-numbered?>', result)
    end

    test 'maxdepth attribute should be set on asciidoc-toc and asciidoc-numbered processing instructions in DocBook backend' do
      doc = document_from_string 'content', :backend => 'docbook', :parse => true, :attributes => {'toclevels' => '1', 'sectnumlevels' => '1' }
      assert doc.attr?('toc')
      assert doc.attr?('sectnums')
      result = doc.convert
      assert_match('<?asciidoc-toc maxdepth="1"?>', result)
      assert_match('<?asciidoc-numbered maxdepth="1"?>', result)
    end

    test 'should be able to disable toc and sectnums in document header for DocBook backend' do
      input = <<-EOS
= Document Title
:toc!:
:sectnums!:
      EOS
      doc = document_from_string input, :backend => 'docbook'
      refute doc.attr?('toc')
      refute doc.attr?('sectnums')
    end

    test 'noheader attribute should suppress info element when converting to DocBook' do
      input = <<-EOS
= Document Title
:noheader:

content
      EOS
      result = render_string input, :backend => 'docbook'
      assert_xpath '/article', result, 1
      assert_xpath '/article/info', result, 0
    end

    test 'should be able to disable section numbering using numbered attribute in document header for DocBook backend' do
      input = <<-EOS
= Document Title
:numbered!:
      EOS
      doc = document_from_string input, :backend => 'docbook'
      refute doc.attr?('sectnums')
    end
  end

  context 'Docinfo files' do
    test 'should include docinfo files for html backend' do
      sample_input_path = fixture_path('basic.asciidoc')

      cases = {
        'docinfo'                => { :head_script => 1, :meta => 0, :top_link => 0, :footer_script => 1 },
        'docinfo=private'        => { :head_script => 1, :meta => 0, :top_link => 0, :footer_script => 1 },
        'docinfo1'               => { :head_script => 0, :meta => 1, :top_link => 1, :footer_script => 0 },
        'docinfo=shared'         => { :head_script => 0, :meta => 1, :top_link => 1, :footer_script => 0 },
        'docinfo2'               => { :head_script => 1, :meta => 1, :top_link => 1, :footer_script => 1 },
        'docinfo docinfo2'       => { :head_script => 1, :meta => 1, :top_link => 1, :footer_script => 1 },
        'docinfo=private,shared' => { :head_script => 1, :meta => 1, :top_link => 1, :footer_script => 1 },
        'docinfo=private-head'   => { :head_script => 1, :meta => 0, :top_link => 0, :footer_script => 0 },
        'docinfo=shared-head'    => { :head_script => 0, :meta => 1, :top_link => 0, :footer_script => 0 },
        'docinfo=private-footer' => { :head_script => 0, :meta => 0, :top_link => 0, :footer_script => 1 },
        'docinfo=shared-footer'  => { :head_script => 0, :meta => 0, :top_link => 1, :footer_script => 0 },
        'docinfo=private-head\ ,\ shared-footer' => { :head_script => 1, :meta => 0, :top_link => 1, :footer_script => 0 }
      }

      cases.each do |attr_val, markup|
        output = Asciidoctor.convert_file sample_input_path, :to_file => false,
            :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => %(linkcss copycss! #{attr_val})
        refute_empty output
        assert_css 'script[src="modernizr.js"]', output, markup[:head_script]
        assert_css 'meta[http-equiv="imagetoolbar"]', output, markup[:meta]
        assert_css 'body > a#top', output, markup[:top_link]
        assert_css 'body > script', output, markup[:footer_script]
      end
    end

    test 'should include docinfo footer even if nofooter attribute is set' do
      sample_input_path = fixture_path('basic.asciidoc')
      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo1' => '', 'nofooter' => ''}
      refute_empty output
      assert_css 'body > a#top', output, 1
    end

    test 'should include docinfo files for html backend with custom docinfodir' do
      sample_input_path = fixture_path('basic.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
                                        :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo' => '', 'docinfodir' => 'custom-docinfodir'}
      refute_empty output
      assert_css 'script[src="bootstrap.js"]', output, 1
      assert_css 'meta[name="robots"]', output, 0

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
                                        :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo1' => '', 'docinfodir' => 'custom-docinfodir'}
      refute_empty output
      assert_css 'script[src="bootstrap.js"]', output, 0
      assert_css 'meta[name="robots"]', output, 1

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
                                        :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo2' => '', 'docinfodir' => './custom-docinfodir'}
      refute_empty output
      assert_css 'script[src="bootstrap.js"]', output, 1
      assert_css 'meta[name="robots"]', output, 1

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
                                        :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo2' => '', 'docinfodir' => 'custom-docinfodir/subfolder'}
      refute_empty output
      assert_css 'script[src="bootstrap.js"]', output, 0
      assert_css 'meta[name="robots"]', output, 0
    end

    test 'should include docinfo files for docbook backend' do
      sample_input_path = fixture_path('basic.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo' => ''}
      refute_empty output
      assert_css 'productname', output, 0
      assert_css 'copyright', output, 1

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo1' => ''}
      refute_empty output
      assert_css 'productname', output, 1
      assert_xpath '//xmlns:productname[text()="Asciidoctor™"]', output, 1
      assert_css 'edition', output, 1
      assert_xpath '//xmlns:edition[text()="1.0"]', output, 1 # verifies substitutions are performed
      assert_css 'copyright', output, 0

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo2' => ''}
      refute_empty output
      assert_css 'productname', output, 1
      assert_xpath '//xmlns:productname[text()="Asciidoctor™"]', output, 1
      assert_css 'edition', output, 1
      assert_xpath '//xmlns:edition[text()="1.0"]', output, 1 # verifies substitutions are performed
      assert_css 'copyright', output, 1
    end

    test 'should include docinfo footer files for html backend' do
      sample_input_path = fixture_path('basic.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo' => ''}
      refute_empty output
      assert_css 'body script', output, 1
      assert_css 'a#top', output, 0

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo1' => ''}
      refute_empty output
      assert_css 'body script', output, 0
      assert_css 'a#top', output, 1

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo2' => ''}
      refute_empty output
      assert_css 'body script', output, 1
      assert_css 'a#top', output, 1
    end

    test 'should include docinfo footer files for docbook backend' do
      sample_input_path = fixture_path('basic.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo' => ''}
      refute_empty output
      assert_css 'article > revhistory', output, 1
      assert_xpath '/xmlns:article/xmlns:revhistory/xmlns:revision/xmlns:revnumber[text()="1.0"]', output, 1 # verifies substitutions are performed
      assert_css 'glossary#_glossary', output, 0

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo1' => ''}
      refute_empty output
      assert_css 'article > revhistory', output, 0
      assert_css 'glossary#_glossary', output, 1

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo2' => ''}
      refute_empty output
      assert_css 'article > revhistory', output, 1
      assert_xpath '/xmlns:article/xmlns:revhistory/xmlns:revision/xmlns:revnumber[text()="1.0"]', output, 1 # verifies substitutions are performed
      assert_css 'glossary#_glossary', output, 1
    end

    # WARNING this test manipulates runtime settings; should probably be run in forked process
    test 'should force encoding of docinfo files to UTF-8' do
      sample_input_path = fixture_path('basic.asciidoc')

      if RUBY_VERSION >= '1.9'
        default_external_old = Encoding.default_external
        force_encoding_old = Asciidoctor::FORCE_ENCODING
        verbose_old = $VERBOSE
      end
      begin
        if RUBY_VERSION >= '1.9'
          $VERBOSE = nil # disable warnings since we have to modify constants
          Encoding.default_external = 'US-ASCII'
          Asciidoctor::FORCE_ENCODING = true
        end
        output = Asciidoctor.convert_file sample_input_path, :to_file => false,
            :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER, :attributes => {'docinfo2' => ''}
        refute_empty output
        assert_css 'productname', output, 1
        assert_css 'edition', output, 1
        assert_xpath '//xmlns:edition[text()="1.0"]', output, 1 # verifies substitutions are performed
        assert_css 'copyright', output, 1
      ensure
        if RUBY_VERSION >= '1.9'
          Encoding.default_external = default_external_old
          Asciidoctor::FORCE_ENCODING = force_encoding_old
          $VERBOSE = verbose_old
        end
      end
    end

    test 'should not include docinfo files by default' do
      sample_input_path = fixture_path('basic.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :safe => Asciidoctor::SafeMode::SERVER
      refute_empty output
      assert_css 'script[src="modernizr.js"]', output, 0
      assert_css 'meta[http-equiv="imagetoolbar"]', output, 0

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :safe => Asciidoctor::SafeMode::SERVER
      refute_empty output
      assert_css 'productname', output, 0
      assert_css 'copyright', output, 0
    end

    test 'should not include docinfo files if safe mode is SECURE or greater' do
      sample_input_path = fixture_path('basic.asciidoc')

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :attributes => {'docinfo2' => ''}
      refute_empty output
      assert_css 'script[src="modernizr.js"]', output, 0
      assert_css 'meta[http-equiv="imagetoolbar"]', output, 0

      output = Asciidoctor.convert_file sample_input_path, :to_file => false,
          :header_footer => true, :backend => 'docbook', :attributes => {'docinfo2' => ''}
      refute_empty output
      assert_css 'productname', output, 0
      assert_css 'copyright', output, 0
    end

    test 'should substitute attributes in docinfo files by default' do
      sample_input_path = fixture_path 'subs.adoc'
      output, warnings = redirect_streams do |_, err|
        output = Asciidoctor.convert_file sample_input_path,
            :to_file => false,
            :header_footer => true,
            :safe => :server,
            :attributes => { 'docinfo' => '', 'bootstrap-version' => nil, 'linkcss' => '', 'attribute-missing' => 'drop-line' }
        [output, err.string]
      end
      refute_empty output
      assert_css 'script', output, 0
      assert_xpath %(//meta[@name="copyright"][@content="(C) OpenDevise"]), output, 1
      assert_includes warnings, 'dropping line containing reference to missing attribute'
    end

    test 'should apply explicit substitutions to docinfo files' do
      sample_input_path = fixture_path 'subs.adoc'
      output = Asciidoctor.convert_file sample_input_path,
          :to_file => false,
          :header_footer => true,
          :safe => :server,
          :attributes => { 'docinfo' => '', 'docinfosubs' => 'attributes,replacements', 'linkcss' => '' }
      refute_empty output
      assert_css 'script[src="bootstrap.3.2.0.min.js"]', output, 1
      assert_xpath %(//meta[@name="copyright"][@content="#{decode_char 169} OpenDevise"]), output, 1
    end
  end

  context 'MathJax' do
    test 'should add MathJax script to HTML head if stem attribute is set' do
      output = render_string '', :attributes => {'stem' => ''}
      assert_match('<script type="text/x-mathjax-config">', output)
      assert_match('inlineMath: [["\\\\(", "\\\\)"]]', output)
      assert_match('displayMath: [["\\\\[", "\\\\]"]]', output)
      assert_match('delimiters: [["\\\\$", "\\\\$"]]', output)
    end
  end

  context 'Converter' do
    test 'built-in HTML5 views are registered by default' do
      doc = document_from_string ''
      assert_equal 'html5', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-html5'
      assert_equal 'html', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-html'
      converter = doc.converter
      assert_kind_of Asciidoctor::Converter::Html5Converter, converter
      BUILT_IN_ELEMENTS.each do |element|
        assert_respond_to converter, element
      end
    end

    test 'built-in DocBook45 views are registered when backend is docbook45' do
      doc = document_from_string '', :attributes => {'backend' => 'docbook45'}
      converter = doc.converter
      assert_equal 'docbook45', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-docbook45'
      assert_equal 'docbook', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-docbook'
      converter = doc.converter
      assert_kind_of Asciidoctor::Converter::DocBook45Converter, converter
      BUILT_IN_ELEMENTS.each do |element|
        assert_respond_to converter, element
      end
    end

    test 'built-in DocBook5 views are registered when backend is docbook5' do
      doc = document_from_string '', :attributes => {'backend' => 'docbook5'}
      converter = doc.converter
      assert_equal 'docbook5', doc.attributes['backend']
      assert doc.attributes.has_key? 'backend-docbook5'
      assert_equal 'docbook', doc.attributes['basebackend']
      assert doc.attributes.has_key? 'basebackend-docbook'
      converter = doc.converter
      assert_kind_of Asciidoctor::Converter::DocBook5Converter, converter
      BUILT_IN_ELEMENTS.each do |element|
        assert_respond_to converter, element
      end
    end

    test 'should add favicon if favicon attribute is set' do
      {
        '' => %w(favicon.ico image/x-icon),
        '/favicon.ico' => %w(/favicon.ico image/x-icon),
        '/img/favicon.png' => %w(/img/favicon.png image/png)
      }.each {|val, (href, type)|
        result = render_string %(= Untitled), :attributes => { 'favicon' => val }
        assert_css 'link[rel="shortcut icon"]', result, 1
        assert_css %(link[rel="shortcut icon"][href="#{href}"]), result, 1
        assert_css %(link[rel="shortcut icon"][type="#{type}"]), result, 1
      }
    end
  end

  context 'Structure' do
    test 'document with no doctitle' do
      doc = document_from_string('Snorf')
      assert_nil doc.doctitle
      assert_nil doc.name
      refute doc.has_header?
      assert_nil doc.header
    end

    test 'should enable compat mode for document with legacy doctitle' do
      input = <<-EOS
Document Title
==============

+content+
      EOS

      doc = document_from_string input
      assert(doc.attr? 'compat-mode')
      result = doc.convert
      assert_xpath '//code[text()="content"]', result, 1
    end

    test 'should not enable compat mode for document with legacy doctitle if compat mode disable by header' do
      input = <<-EOS
Document Title
==============
:compat-mode!:

+content+
      EOS

      doc = document_from_string input
      assert_nil(doc.attr 'compat-mode')
      result = doc.convert
      assert_xpath '//code[text()="content"]', result, 0
    end

    test 'should not enable compat mode for document with legacy doctitle if compat mode is locked by API' do
      input = <<-EOS
Document Title
==============

+content+
      EOS

      doc = document_from_string input, :attributes => { 'compat-mode' => nil }
      assert(doc.attribute_locked? 'compat-mode')
      assert_nil(doc.attr 'compat-mode')
      result = doc.convert
      assert_xpath '//code[text()="content"]', result, 0
    end

    test 'title partition API with default separator' do
      title = Asciidoctor::Document::Title.new 'Main Title: And More: Subtitle'
      assert_equal 'Main Title: And More', title.main
      assert_equal 'Subtitle', title.subtitle
    end

    test 'title partition API with custom separator' do
      title = Asciidoctor::Document::Title.new 'Main Title:: And More:: Subtitle', :separator => '::'
      assert_equal 'Main Title:: And More', title.main
      assert_equal 'Subtitle', title.subtitle
    end

    test 'document with subtitle' do
      input = <<-EOS
= Main Title: *Subtitle*
Author Name

content
      EOS

      doc = document_from_string input
      title = doc.doctitle :partition => true, :sanitize => true
      assert title.subtitle?
      assert title.sanitized?
      assert_equal 'Main Title', title.main
      assert_equal 'Subtitle', title.subtitle
    end

    test 'document with subtitle and custom separator' do
      input = <<-EOS
[separator=::]
= Main Title:: *Subtitle*
Author Name

content
      EOS

      doc = document_from_string input
      title = doc.doctitle :partition => true, :sanitize => true
      assert title.subtitle?
      assert title.sanitized?
      assert_equal 'Main Title', title.main
      assert_equal 'Subtitle', title.subtitle
    end

    test 'should not honor custom separator for doctitle if attribute is locked by API' do
      input = <<-EOS
[separator=::]
= Main Title - *Subtitle*
Author Name

content
      EOS

      doc = document_from_string input, :attributes => { 'title-separator' => ' -' }
      title = doc.doctitle :partition => true, :sanitize => true
      assert title.subtitle?
      assert title.sanitized?
      assert_equal 'Main Title', title.main
      assert_equal 'Subtitle', title.subtitle
    end

    test 'document with doctitle defined as attribute entry' do
     input = <<-EOS
:doctitle: Document Title

preamble

== First Section
     EOS
     doc = document_from_string input
     assert_equal 'Document Title', doc.doctitle
     assert doc.has_header?
     assert_equal 'Document Title', doc.header.title
     assert_equal 'Document Title', doc.first_section.title
    end

    test 'document with doctitle defined as attribute entry followed by block with title' do
      input = <<-EOS
:doctitle: Document Title

.Block title
Block content
      EOS

      doc = document_from_string input
      assert_equal 'Document Title', doc.doctitle
      assert doc.has_header?
      assert_equal 1, doc.blocks.size
      assert_equal :paragraph, doc.blocks[0].context
      assert_equal 'Block title', doc.blocks[0].title
    end

    test 'document with title attribute entry overrides doctitle' do
     input = <<-EOS
= Document Title
:title: Override

{doctitle}

== First Section
     EOS
     doc = document_from_string input
     assert_equal 'Override', doc.doctitle
     assert_equal 'Override', doc.title
     assert doc.has_header?
     assert_equal 'Document Title', doc.header.title
     assert_equal 'Document Title', doc.first_section.title
     assert_xpath '//*[@id="preamble"]//p[text()="Document Title"]', doc.render, 1
    end

    test 'document with title attribute entry overrides doctitle attribute entry' do
     input = <<-EOS
= Document Title
:snapshot: {doctitle}
:doctitle: doctitle
:title: Override

{snapshot}, {doctitle}

== First Section
     EOS
     doc = document_from_string input
     assert_equal 'Override', doc.doctitle
     assert_equal 'Override', doc.title
     assert doc.has_header?
     assert_equal 'doctitle', doc.header.title
     assert_equal 'doctitle', doc.first_section.title
     assert_xpath '//*[@id="preamble"]//p[text()="Document Title, doctitle"]', doc.render, 1
    end

    test 'document with doctitle attribute entry overrides header title and doctitle' do
     input = <<-EOS
= Document Title
:snapshot: {doctitle}
:doctitle: Override

{snapshot}, {doctitle}

== First Section
     EOS
     doc = document_from_string input
     assert_equal 'Override', doc.doctitle
     assert_nil doc.attributes['title']
     assert doc.has_header?
     assert_equal 'Override', doc.header.title
     assert_equal 'Override', doc.first_section.title
     assert_xpath '//*[@id="preamble"]//p[text()="Document Title, Override"]', doc.render, 1
    end

    test 'doctitle attribute entry above header overrides header title and doctitle' do
     input = <<-EOS
:doctitle: Override
= Document Title

{doctitle}

== First Section
     EOS
     doc = document_from_string input
     assert_equal 'Override', doc.doctitle
     assert_nil doc.attributes['title']
     assert doc.has_header?
     assert_equal 'Override', doc.header.title
     assert_equal 'Override', doc.first_section.title
     assert_xpath '//*[@id="preamble"]//p[text()="Override"]', doc.render, 1
    end

    test 'should recognize document title when preceded by blank lines' do
      input = <<-EOS
:doctype: book

= Title

preamble

== Section 1

text
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_css '#header h1', output, 1
      assert_css '#content h1', output, 0
    end

    test 'should sanitize contents of HTML title element' do
      input = <<-EOS
= *Document* image:logo.png[] _Title_ image:another-logo.png[another logo]

content
      EOS

      output = render_string input
      assert_xpath '/html/head/title[text()="Document Title"]', output, 1
      nodes = xmlnodes_at_xpath('//*[@id="header"]/h1', output)
      assert_equal 1, nodes.size
      assert_match('<h1><strong>Document</strong> <span class="image"><img src="logo.png" alt="logo"></span> <em>Title</em> <span class="image"><img src="another-logo.png" alt="another logo"></span></h1>', output)
    end

    test 'should not choke on empty source' do
      doc = Asciidoctor::Document.new ''
      assert_empty doc.blocks
      assert_nil doc.doctitle
      refute doc.has_header?
      assert_nil doc.header
    end

    test 'should not choke on nil source' do
      doc = Asciidoctor::Document.new nil
      assert_empty doc.blocks
      assert_nil doc.doctitle
      refute doc.has_header?
      assert_nil doc.header
    end

    test 'with metadata' do
      input = <<-EOS
= AsciiDoc
Stuart Rackham <founder@asciidoc.org>
v8.6.8, 2012-07-12: See changelog.
:description: AsciiDoc user guide
:keywords: asciidoc,documentation
:copyright: Stuart Rackham

== Version 8.6.8

more info...
      EOS
      output = render_string input
      assert_xpath '//meta[@name="author"][@content="Stuart Rackham"]', output, 1
      assert_xpath '//meta[@name="description"][@content="AsciiDoc user guide"]', output, 1
      assert_xpath '//meta[@name="keywords"][@content="asciidoc,documentation"]', output, 1
      assert_xpath '//meta[@name="copyright"][@content="Stuart Rackham"]', output, 1
      assert_xpath '//*[@id="header"]/*[@class="details"]/span[@id="author"][text() = "Stuart Rackham"]', output, 1
      assert_xpath '//*[@id="header"]/*[@class="details"]/span[@id="email"]/a[@href="mailto:founder@asciidoc.org"][text() = "founder@asciidoc.org"]', output, 1
      assert_xpath '//*[@id="header"]/*[@class="details"]/span[@id="revnumber"][text() = "version 8.6.8,"]', output, 1
      assert_xpath '//*[@id="header"]/*[@class="details"]/span[@id="revdate"][text() = "2012-07-12"]', output, 1
      assert_xpath '//*[@id="header"]/*[@class="details"]/span[@id="revremark"][text() = "See changelog."]', output, 1
    end

    test 'should parse revision line if date is empty' do
      input = <<-EOS
= Document Title
Author Name
v1.0.0,:remark

content
      EOS

      doc = document_from_string input
      assert_equal '1.0.0', doc.attributes['revnumber']
      assert_nil doc.attributes['revdate']
      assert_equal 'remark', doc.attributes['revremark']
    end

    test 'should include revision history if revdate and revnumber is set' do
      input = <<-EOS
= Document Title
Author Name
:revdate: 2011-11-11
:revnumber: 1.0

content
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'revhistory', output, 1
      assert_css 'revhistory > revision', output, 1
      assert_css 'revhistory > revision > date', output, 1
      assert_css 'revhistory > revision > revnumber', output, 1
    end

    test 'should include revision history if revdate and revremark is set' do
      input = <<-EOS
= Document Title
Author Name
:revdate: 2011-11-11
:revremark: features!

content
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'revhistory', output, 1
      assert_css 'revhistory > revision', output, 1
      assert_css 'revhistory > revision > date', output, 1
      assert_css 'revhistory > revision > revremark', output, 1
    end

    test 'should not include revision history if revdate is not set' do
      input = <<-EOS
= Document Title
Author Name
:revnumber: 1.0

content
      EOS

      output = render_string input, :backend => 'docbook'
      assert_css 'revhistory', output, 0
    end

    test 'with metadata to DocBook45' do
      input = <<-EOS
= AsciiDoc
Stuart Rackham <founder@asciidoc.org>
v8.6.8, 2012-07-12: See changelog.

== Version 8.6.8

more info...
      EOS
      output = render_string input, :backend => 'docbook45'
      assert_xpath '/article/articleinfo', output, 1
      assert_xpath '/article/articleinfo/title[text() = "AsciiDoc"]', output, 1
      assert_xpath '/article/articleinfo/date[text() = "2012-07-12"]', output, 1
      assert_xpath '/article/articleinfo/author/firstname[text() = "Stuart"]', output, 1
      assert_xpath '/article/articleinfo/author/surname[text() = "Rackham"]', output, 1
      assert_xpath '/article/articleinfo/author/email[text() = "founder@asciidoc.org"]', output, 1
      assert_xpath '/article/articleinfo/revhistory', output, 1
      assert_xpath '/article/articleinfo/revhistory/revision', output, 1
      assert_xpath '/article/articleinfo/revhistory/revision/revnumber[text() = "8.6.8"]', output, 1
      assert_xpath '/article/articleinfo/revhistory/revision/date[text() = "2012-07-12"]', output, 1
      assert_xpath '/article/articleinfo/revhistory/revision/authorinitials[text() = "SR"]', output, 1
      assert_xpath '/article/articleinfo/revhistory/revision/revremark[text() = "See changelog."]', output, 1
    end

    test 'with metadata to DocBook5' do
      input = <<-EOS
= AsciiDoc
Stuart Rackham <founder@asciidoc.org>

== Version 8.6.8

more info...
      EOS
      output = render_string input, :backend => 'docbook5'
      assert_xpath '/article/info', output, 1
      assert_xpath '/article/info/title[text() = "AsciiDoc"]', output, 1
      assert_xpath '/article/info/author/personname', output, 1
      assert_xpath '/article/info/author/personname/firstname[text() = "Stuart"]', output, 1
      assert_xpath '/article/info/author/personname/surname[text() = "Rackham"]', output, 1
      assert_xpath '/article/info/author/email[text() = "founder@asciidoc.org"]', output, 1
    end

    test 'with author defined using attribute entry to DocBook 4.5' do
      input = <<-EOS
= Document Title
:author: Doc Writer
:email: thedoctor@asciidoc.org

content
      EOS

      output = render_string input, :backend => 'docbook45'
      assert_xpath '//articleinfo/author', output, 1
      assert_xpath '//articleinfo/author/firstname[text() = "Doc"]', output, 1
      assert_xpath '//articleinfo/author/surname[text() = "Writer"]', output, 1
      assert_xpath '//articleinfo/author/email[text() = "thedoctor@asciidoc.org"]', output, 1
      assert_xpath '//articleinfo/authorinitials[text() = "DW"]', output, 1
    end

    test 'should sanitize content of HTML meta authors tag' do
      input = <<-EOS
= Document Title
:author: pass:n[http://example.org/community/team.html[Ze *Product* team]]

content
      EOS

      output = render_string input
      assert_xpath '//meta[@name="author"][@content="Ze Product team"]', output, 1
    end

    test 'should include multiple authors in HTML output' do
      input = <<-EOS
= Document Title
Doc Writer <thedoctor@asciidoc.org>; Junior Writer <junior@asciidoctor.org>

content
      EOS

      output = render_string input
      assert_xpath '//span[@id="author"]', output, 1
      assert_xpath '//span[@id="author"][text()="Doc Writer"]', output, 1
      assert_xpath '//span[@id="email"]', output, 1
      assert_xpath '//span[@id="email"]/a', output, 1
      assert_xpath '//span[@id="email"]/a[@href="mailto:thedoctor@asciidoc.org"][text()="thedoctor@asciidoc.org"]', output, 1
      assert_xpath '//span[@id="author2"]', output, 1
      assert_xpath '//span[@id="author2"][text()="Junior Writer"]', output, 1
      assert_xpath '//span[@id="email2"]', output, 1
      assert_xpath '//span[@id="email2"]/a', output, 1
      assert_xpath '//span[@id="email2"]/a[@href="mailto:junior@asciidoctor.org"][text()="junior@asciidoctor.org"]', output, 1
    end

    test 'should create authorgroup in DocBook when multiple authors' do
      input = <<-EOS
= Document Title
Doc Writer <thedoctor@asciidoc.org>; Junior Writer <junior@asciidoctor.org>

content
      EOS

      output = render_string input, :backend => 'docbook45'
      assert_xpath '//articleinfo/author', output, 0
      assert_xpath '//articleinfo/authorgroup', output, 1
      assert_xpath '//articleinfo/authorgroup/author', output, 2
      assert_xpath '//articleinfo/authorgroup/author[1]/firstname[text() = "Doc"]', output, 1
      assert_xpath '//articleinfo/authorgroup/author[2]/firstname[text() = "Junior"]', output, 1
    end

    test 'with authors defined using attribute entry to DocBook' do
      input = <<-EOS
= Document Title
:authors: Doc Writer; Junior Writer
:email_1: thedoctor@asciidoc.org
:email_2: junior@asciidoc.org

content
      EOS

      output = render_string input, :backend => 'docbook45'
      assert_xpath '//articleinfo/author', output, 0
      assert_xpath '//articleinfo/authorgroup', output, 1
      assert_xpath '//articleinfo/authorgroup/author', output, 2
      assert_xpath '(//articleinfo/authorgroup/author)[1]/firstname[text() = "Doc"]', output, 1
      assert_xpath '(//articleinfo/authorgroup/author)[1]/email[text() = "thedoctor@asciidoc.org"]', output, 1
      assert_xpath '(//articleinfo/authorgroup/author)[2]/firstname[text() = "Junior"]', output, 1
      assert_xpath '(//articleinfo/authorgroup/author)[2]/email[text() = "junior@asciidoc.org"]', output, 1
    end

    test 'with header footer' do
      doc = document_from_string "= Title\n\nparagraph"
      refute doc.attr?('embedded')
      result = doc.render
      assert_xpath '/html', result, 1
      assert_xpath '//*[@id="header"]', result, 1
      assert_xpath '//*[@id="header"]/h1', result, 1
      assert_xpath '//*[@id="footer"]', result, 1
      assert_xpath '//*[@id="content"]', result, 1
    end

    test 'does not render footer if nofooter is set' do
      input = <<-EOS
:nofooter:

content
      EOS

      result = render_string input
      assert_xpath '//*[@id="footer"]', result, 0
    end

    test 'can disable last updated in footer' do
      doc = document_from_string "= Document Title\n\npreamble", :attributes => {'last-update-label!' => ''}
      result = doc.render
      assert_xpath '//*[@id="footer-text"]', result, 1
      assert_xpath '//*[@id="footer-text"][normalize-space(text())=""]', result, 1
    end

    test 'no header footer' do
      doc = document_from_string "= Document Title\n\ncontent", :header_footer => false
      assert doc.attr?('embedded')
      result = doc.render
      assert_xpath '/html', result, 0
      assert_xpath '/h1', result, 0
      assert_xpath '/*[@id="header"]', result, 0
      assert_xpath '/*[@id="footer"]', result, 0
      assert_xpath '/*[@class="paragraph"]', result, 1
    end

    test 'enable title in embedded document by unassigning notitle attribute' do
      input = <<-EOS
= Document Title

content
      EOS

      result = render_embedded_string input, :attributes => {'notitle!' => ''}
      assert_xpath '/html', result, 0
      assert_xpath '/h1', result, 1
      assert_xpath '/*[@id="header"]', result, 0
      assert_xpath '/*[@id="footer"]', result, 0
      assert_xpath '/*[@class="paragraph"]', result, 1
      assert_xpath '(/*)[1]/self::h1', result, 1
      assert_xpath '(/*)[2]/self::*[@class="paragraph"]', result, 1
    end

    test 'enable title in embedded document by assigning showtitle attribute' do
      input = <<-EOS
= Document Title

content
      EOS

      result = render_embedded_string input, :attributes => {'showtitle' => ''}
      assert_xpath '/html', result, 0
      assert_xpath '/h1', result, 1
      assert_xpath '/*[@id="header"]', result, 0
      assert_xpath '/*[@id="footer"]', result, 0
      assert_xpath '/*[@class="paragraph"]', result, 1
      assert_xpath '(/*)[1]/self::h1', result, 1
      assert_xpath '(/*)[2]/self::*[@class="paragraph"]', result, 1
    end

    test 'parse header only' do
      input = <<-EOS
= Document Title
Author Name
:foo: bar

preamble
      EOS

      doc = document_from_string input, :parse_header_only => true
      assert_equal 'Document Title', doc.doctitle
      assert_equal 'Author Name', doc.author
      assert_equal 'bar', doc.attributes['foo']
      # there would be at least 1 block had it parsed beyond the header
      assert_equal 0, doc.blocks.size
    end

    test 'renders footnotes in footer' do
      input = <<-EOS
A footnote footnote:[An example footnote.];
a second footnote with a reference ID footnoteref:[note2,Second footnote.];
finally a reference to the second footnote footnoteref:[note2].
      EOS

      output = render_string input
      assert_css '#footnotes', output, 1
      assert_css '#footnotes .footnote', output, 2
      assert_css '#footnotes .footnote#_footnote_1', output, 1
      assert_xpath '//div[@id="footnotes"]/div[@id="_footnote_1"]/a[@href="#_footnoteref_1"][text()="1"]', output, 1
      text = xmlnodes_at_xpath '//div[@id="footnotes"]/div[@id="_footnote_1"]/text()', output
      assert_equal '. An example footnote.', text.text.strip
      assert_css '#footnotes .footnote#_footnote_2', output, 1
      assert_xpath '//div[@id="footnotes"]/div[@id="_footnote_2"]/a[@href="#_footnoteref_2"][text()="2"]', output, 1
      text = xmlnodes_at_xpath '//div[@id="footnotes"]/div[@id="_footnote_2"]/text()', output
      assert_equal '. Second footnote.', text.text.strip
    end

    test 'renders footnotes block in embedded document by default' do
      input = <<-EOS
Text that has supporting information{empty}footnote:[An example footnote.].
      EOS

      output = render_embedded_string input
      assert_css '#footnotes', output, 1
      assert_css '#footnotes .footnote', output, 1
      assert_css '#footnotes .footnote#_footnote_1', output, 1
      assert_xpath '/div[@id="footnotes"]/div[@id="_footnote_1"]/a[@href="#_footnoteref_1"][text()="1"]', output, 1
      text = xmlnodes_at_xpath '/div[@id="footnotes"]/div[@id="_footnote_1"]/text()', output
      assert_equal '. An example footnote.', text.text.strip
    end

    test 'does not render footnotes block in embedded document if nofootnotes attribute is set' do
      input = <<-EOS
Text that has supporting information{empty}footnote:[An example footnote.].
      EOS

      output = render_embedded_string input, :attributes => {'nofootnotes' => ''}
      assert_css '#footnotes', output, 0
    end
  end

  context 'Catalog' do
    test 'document catalog is aliased as references' do
      input = <<-EOS
= Document Title

== Section A

content

== Section B

content{blank}footnote:[commentary]
      EOS

      doc = document_from_string input
      refute_nil doc.catalog
      assert_equal [:footnotes, :ids, :images, :includes, :indexterms, :links, :refs, :callouts].to_set, doc.catalog.keys.to_set
      assert_same doc.catalog, doc.references
      assert_same doc.catalog[:footnotes], doc.references[:footnotes]
      assert_same doc.catalog[:ids], doc.references[:ids]
      assert_equal 'Section A', doc.references[:ids]['_section_a']
    end
  end

  context 'Backends and Doctypes' do
    test 'html5 backend doctype article' do
      result = render_string("= Title\n\nparagraph", :attributes => {'backend' => 'html5'})
      assert_xpath '/html', result, 1
      assert_xpath '/html/body[@class="article"]', result, 1
      assert_xpath '/html//*[@id="header"]/h1[text() = "Title"]', result, 1
      assert_xpath '/html//*[@id="content"]//p[text() = "paragraph"]', result, 1
    end

    test 'html5 backend doctype book' do
      result = render_string("= Title\n\nparagraph", :attributes => {'backend' => 'html5', 'doctype' => 'book'})
      assert_xpath '/html', result, 1
      assert_xpath '/html/body[@class="book"]', result, 1
      assert_xpath '/html//*[@id="header"]/h1[text() = "Title"]', result, 1
      assert_xpath '/html//*[@id="content"]//p[text() = "paragraph"]', result, 1
    end

    test 'xhtml5 backend should map to html5 and set htmlsyntax to xml' do
      input = <<-EOS
content
      EOS
      doc = document_from_string input, :backend => :xhtml5
      assert_equal 'html5', doc.backend
      assert_equal 'xml', (doc.attr 'htmlsyntax')
    end

    test 'xhtml backend should map to html5 and set htmlsyntax to xml' do
      input = <<-EOS
content
      EOS
      doc = document_from_string input, :backend => :xhtml
      assert_equal 'html5', doc.backend
      assert_equal 'xml', (doc.attr 'htmlsyntax')
    end

    test 'honor htmlsyntax attribute passed via API if backend is html' do
      input = <<-EOS
---
      EOS
      doc = document_from_string input, :safe => :safe, :attributes => { 'htmlsyntax' => 'xml' }
      assert_equal 'html5', doc.backend
      assert_equal 'xml', (doc.attr 'htmlsyntax')
      result = doc.convert :header_footer => false
      assert_equal '<hr/>', result
    end

    test 'honor htmlsyntax attribute in document header if followed by backend attribute' do
      input = <<-EOS
:htmlsyntax: xml
:backend: html5

---
      EOS
      doc = document_from_string input, :safe => :safe
      assert_equal 'html5', doc.backend
      assert_equal 'xml', (doc.attr 'htmlsyntax')
      result = doc.convert :header_footer => false
      assert_equal '<hr/>', result
    end

    test 'does not honor htmlsyntax attribute in document header if not followed by backend attribute' do
      input = <<-EOS
:backend: html5
:htmlsyntax: xml

---
      EOS
      result = render_embedded_string input, :safe => :safe
      assert_equal '<hr>', result
    end

    test 'should close all short tags when htmlsyntax is xml' do
      input = <<-EOS
= Document Title
Author Name
v1.0, 2001-01-01
:icons:

image:tiger.png[]

image::tiger.png[]

* [x] one
* [ ] two

|===
|A |B
|===

[horizontal, labelwidth="25%", itemwidth="75%"]
term:: description

NOTE: note

[quote,Author,Source]
____
Quote me.
____

[verse,Author,Source]
____
A tall tale.
____

[options="autoplay,loop"]
video::screencast.ogg[]

video::12345[vimeo]

[options="autoplay,loop"]
audio::podcast.ogg[]

one +
two

'''
      EOS
      result = render_string input, :safe => :safe, :backend => :xhtml
      begin
        Nokogiri::XML::Document.parse(result) {|config|
          config.options = Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET
        }
      rescue => e
        flunk "xhtml5 backend did not generate well-formed XML: #{e.message}\n#{result}"
      end
    end

    test 'xhtml backend should emit elements in proper namespace' do
      input = <<-EOS
content
      EOS
      result = render_string input, :safe => :safe, :backend => :xhtml, :keep_namespaces => true
      assert_xpath '//*[not(namespace-uri() = "http://www.w3.org/1999/xhtml")]', result, 0
    end

    test 'docbook45 backend doctype article' do
      input = <<-EOS
= Title

preamble

== First Section

section body
      EOS
      result = render_string(input, :attributes => {'backend' => 'docbook45'})
      assert_xpath '/article', result, 1
      assert_xpath '/article/articleinfo/title[text() = "Title"]', result, 1
      assert_xpath '/article/simpara[text() = "preamble"]', result, 1
      assert_xpath '/article/section', result, 1
      assert_xpath '/article/section[@id = "_first_section"]/title[text() = "First Section"]', result, 1
      assert_xpath '/article/section[@id = "_first_section"]/simpara[text() = "section body"]', result, 1
    end

    test 'docbook45 backend doctype article no title' do
      result = render_string('text', :attributes => {'backend' => 'docbook45'})
      assert_xpath '/article', result, 1
      assert_xpath '/article/articleinfo/date', result, 1
      assert_xpath '/article/simpara[text() = "text"]', result, 1
    end

    test 'docbook45 backend doctype article no xmlns' do
      result = render_string('text', :keep_namespaces => true, :attributes => {'backend' => 'docbook45', 'doctype' => 'article'})
      refute_match(RE_XMLNS_ATTRIBUTE, result)
    end

    test 'docbook45 backend doctype manpage' do
      input = <<-EOS
= asciidoctor(1)

== NAME

asciidoctor - Process text

== SYNOPSIS

some text

== First Section

section body
      EOS
      result = render_string(input, :attributes => {'backend' => 'docbook45', 'doctype' => 'manpage'})
      assert_xpath '/refentry', result, 1
      assert_xpath '/refentry/refentryinfo/title[text() = "asciidoctor(1)"]', result, 1
      assert_xpath '/refentry/refmeta/refentrytitle[text() = "asciidoctor"]', result, 1
      assert_xpath '/refentry/refmeta/manvolnum[text() = "1"]', result, 1
      assert_xpath '/refentry/refnamediv/refname[text() = "asciidoctor"]', result, 1
      assert_xpath '/refentry/refnamediv/refpurpose[text() = "Process text"]', result, 1
      assert_xpath '/refentry/refsynopsisdiv', result, 1
      assert_xpath '/refentry/refsynopsisdiv/simpara[text() = "some text"]', result, 1
      assert_xpath '/refentry/refsection', result, 1
      assert_xpath '/refentry/refsection[@id = "_first_section"]/title[text() = "First Section"]', result, 1
      assert_xpath '/refentry/refsection[@id = "_first_section"]/simpara[text() = "section body"]', result, 1
    end

    test 'docbook45 backend doctype book' do
      input = <<-EOS
= Title

preamble

== First Chapter

chapter body
      EOS
      result = render_string(input, :attributes => {'backend' => 'docbook45', 'doctype' => 'book'})
      assert_xpath '/book', result, 1
      assert_xpath '/book/bookinfo/title[text() = "Title"]', result, 1
      assert_xpath '/book/preface/simpara[text() = "preamble"]', result, 1
      assert_xpath '/book/chapter', result, 1
      assert_xpath '/book/chapter[@id = "_first_chapter"]/title[text() = "First Chapter"]', result, 1
      assert_xpath '/book/chapter[@id = "_first_chapter"]/simpara[text() = "chapter body"]', result, 1
    end

    test 'docbook45 backend doctype book no title' do
      result = render_string('text', :attributes => {'backend' => 'docbook45', 'doctype' => 'book'})
      assert_xpath '/book', result, 1
      assert_xpath '/book/bookinfo/date', result, 1
      # NOTE simpara cannot be a direct child of book, so content must be treated as a preface
      assert_xpath '/book/preface/simpara[text() = "text"]', result, 1
    end

    test 'docbook45 backend doctype book no xmlns' do
      result = render_string('text', :keep_namespaces => true, :attributes => {'backend' => 'docbook45', 'doctype' => 'book'})
      refute_match(RE_XMLNS_ATTRIBUTE, result)
    end

    test 'docbook45 backend parses out subtitle' do
      input = <<-EOS
= Document Title: Subtitle
:doctype: book

text
      EOS
      result = render_string input, :backend => 'docbook45'
      assert_xpath '/book', result, 1
      assert_xpath '/book/bookinfo/title[text() = "Document Title"]', result, 1
      assert_xpath '/book/bookinfo/subtitle[text() = "Subtitle"]', result, 1
    end

    test 'docbook5 backend doctype article' do
      input = <<-EOS
= Title
Author Name

preamble

== First Section

section body
      EOS
      result = render_string(input, :keep_namespaces => true, :attributes => {'backend' => 'docbook5'})
      assert_xpath '/xmlns:article', result, 1
      doc = xmlnodes_at_xpath('/xmlns:article', result, 1)
      assert_equal 'http://docbook.org/ns/docbook', doc.namespaces['xmlns']
      assert_equal 'http://www.w3.org/1999/xlink', doc.namespaces['xmlns:xl']
      assert_xpath '/xmlns:article[@version="5.0"]', result, 1
      assert_xpath '/xmlns:article/xmlns:info/xmlns:title[text() = "Title"]', result, 1
      assert_xpath '/xmlns:article/xmlns:simpara[text() = "preamble"]', result, 1
      assert_xpath '/xmlns:article/xmlns:section', result, 1
      section = xmlnodes_at_xpath('/xmlns:article/xmlns:section', result, 1)
      # nokogiri can't make up its mind
      id_attr = section.attribute('id') || section.attribute('xml:id')
      refute_nil id_attr
      refute_nil id_attr.namespace
      assert_equal 'xml', id_attr.namespace.prefix
      assert_equal '_first_section', id_attr.value
    end

    test 'docbook5 backend doctype manpage' do
      input = <<-EOS
= asciidoctor(1)

== NAME

asciidoctor - Process text

== SYNOPSIS

some text

== First Section

section body
      EOS
      result = render_string(input, :keep_namespaces => true, :attributes => {'backend' => 'docbook5', 'doctype' => 'manpage'})
      assert_xpath '/xmlns:refentry', result, 1
      doc = xmlnodes_at_xpath('/xmlns:refentry', result, 1)
      assert_equal 'http://docbook.org/ns/docbook', doc.namespaces['xmlns']
      assert_equal 'http://www.w3.org/1999/xlink', doc.namespaces['xmlns:xl']
      assert_xpath '/xmlns:refentry[@version="5.0"]', result, 1
      assert_xpath '/xmlns:refentry/xmlns:info/xmlns:title[text() = "asciidoctor(1)"]', result, 1
      assert_xpath '/xmlns:refentry/xmlns:refmeta/xmlns:refentrytitle[text() = "asciidoctor"]', result, 1
      assert_xpath '/xmlns:refentry/xmlns:refmeta/xmlns:manvolnum[text() = "1"]', result, 1
      assert_xpath '/xmlns:refentry/xmlns:refnamediv/xmlns:refname[text() = "asciidoctor"]', result, 1
      assert_xpath '/xmlns:refentry/xmlns:refnamediv/xmlns:refpurpose[text() = "Process text"]', result, 1
      assert_xpath '/xmlns:refentry/xmlns:refsynopsisdiv', result, 1
      assert_xpath '/xmlns:refentry/xmlns:refsynopsisdiv/xmlns:simpara[text() = "some text"]', result, 1
      assert_xpath '/xmlns:refentry/xmlns:refsection', result, 1
      section = xmlnodes_at_xpath('/xmlns:refentry/xmlns:refsection', result, 1)
      # nokogiri can't make up its mind
      id_attr = section.attribute('id') || section.attribute('xml:id')
      refute_nil id_attr
      refute_nil id_attr.namespace
      assert_equal 'xml', id_attr.namespace.prefix
      assert_equal '_first_section', id_attr.value
    end

    test 'docbook5 backend doctype book' do
      input = <<-EOS
= Title
Author Name

preamble

== First Chapter

chapter body
      EOS
      result = render_string(input, :keep_namespaces => true, :attributes => {'backend' => 'docbook5', 'doctype' => 'book'})
      assert_xpath '/xmlns:book', result, 1
      doc = xmlnodes_at_xpath('/xmlns:book', result, 1)
      assert_equal 'http://docbook.org/ns/docbook', doc.namespaces['xmlns']
      assert_equal 'http://www.w3.org/1999/xlink', doc.namespaces['xmlns:xl']
      assert_xpath '/xmlns:book[@version="5.0"]', result, 1
      assert_xpath '/xmlns:book/xmlns:info/xmlns:title[text() = "Title"]', result, 1
      assert_xpath '/xmlns:book/xmlns:preface/xmlns:simpara[text() = "preamble"]', result, 1
      assert_xpath '/xmlns:book/xmlns:chapter', result, 1
      chapter = xmlnodes_at_xpath('/xmlns:book/xmlns:chapter', result, 1)
      # nokogiri can't make up its mind
      id_attr = chapter.attribute('id') || chapter.attribute('xml:id')
      refute_nil id_attr
      refute_nil id_attr.namespace
      assert_equal 'xml', id_attr.namespace.prefix
      assert_equal '_first_chapter', id_attr.value
    end

    test 'adds refname to DocBook output for each name defined in NAME section of manpage' do
      input = <<-EOS
= eve(1)
Andrew Stanton
v1.0.0
:doctype: manpage
:manmanual: EVE
:mansource: EVE

== NAME

eve, islifeform - analyzes an image to determine if it's a picture of a life form

== SYNOPSIS

*eve* ['OPTION']... 'FILE'...
      EOS

      result = render_string input, :backend => 'docbook5'
      assert_xpath '/refentry/refnamediv/refname', result, 2
      assert_xpath '(/refentry/refnamediv/refname)[1][text()="eve"]', result, 1
      assert_xpath '(/refentry/refnamediv/refname)[2][text()="islifeform"]', result, 1
    end

    test 'adds a front and back cover image to DocBook 5 when doctype is book' do
      input = <<-EOS
= Title
:doctype: book
:imagesdir: images
:front-cover-image: image:front-cover.jpg[scaledwidth=210mm]
:back-cover-image: image:back-cover.jpg[scaledwidth=210mm]

preamble

== First Chapter

chapter body
      EOS

      result = render_string input, :attributes => {'backend' => 'docbook5'}
      assert_xpath '//info/cover[@role="front"]', result, 1
      assert_xpath '//info/cover[@role="front"]//imagedata[@fileref="images/front-cover.jpg"]', result, 1
      assert_xpath '//info/cover[@role="back"]', result, 1
      assert_xpath '//info/cover[@role="back"]//imagedata[@fileref="images/back-cover.jpg"]', result, 1
    end

    test 'should be able to set backend using :backend option key' do
      doc = empty_document :backend => 'html5'
      assert_equal 'html5', doc.attributes['backend']
    end

    test ':backend option should override backend attribute' do
      doc = empty_document :backend => 'html5', :attributes => {'backend' => 'docbook45'}
      assert_equal 'html5', doc.attributes['backend']
    end

    test 'should be able to set doctype using :doctype option key' do
      doc = empty_document :doctype => 'book'
      assert_equal 'book', doc.attributes['doctype']
    end

    test ':doctype option should override doctype attribute' do
      doc = empty_document :doctype => 'book', :attributes => {'doctype' => 'article'}
      assert_equal 'book', doc.attributes['doctype']
    end

    test 'do not override explicit author initials' do
      input = <<-EOS
= AsciiDoc
Stuart Rackham <founder@asciidoc.org>
:Author Initials: SJR

more info...
      EOS
      output = render_string input, :attributes => {'backend' => 'docbook45'}
      assert_xpath '/article/articleinfo/authorinitials[text()="SJR"]', output, 1
    end

    test 'attribute entry can appear immediately after document title' do
      input = <<-EOS
Reference Guide
===============
:toc:

preamble
      EOS
      doc = document_from_string input
      assert doc.attr?('toc')
      assert_equal '', doc.attr('toc')
    end

    test 'attribute entry can appear before author line under document title' do
      input = <<-EOS
Reference Guide
===============
:toc:
Dan Allen

preamble
      EOS
      doc = document_from_string input
      assert doc.attr?('toc')
      assert_equal '', doc.attr('toc')
      assert_equal 'Dan Allen', doc.attr('author')
    end

    test 'should parse mantitle and manvolnum from document title for manpage doctype' do
      input = <<-EOS
= asciidoctor ( 1 )
:doctype: manpage

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats
      EOS

      doc = document_from_string input
      assert_equal 'asciidoctor', doc.attr('mantitle')
      assert_equal '1', doc.attr('manvolnum')
    end

    test 'should perform attribute substitution on mantitle in manpage doctype' do
      input = <<-EOS
= {app}(1)
:doctype: manpage
:app: asciidoctor

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats
      EOS

      doc = document_from_string input
      assert_equal 'asciidoctor', doc.attr('mantitle')
    end

    test 'should consume name section as manname and manpurpose for manpage doctype' do
      input = <<-EOS
= asciidoctor(1)
:doctype: manpage

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats
      EOS

      doc = document_from_string input
      assert_equal 'asciidoctor', doc.attr('manname')
      assert_equal 'converts AsciiDoc source files to HTML, DocBook and other formats', doc.attr('manpurpose')
      assert_equal 0, doc.blocks.size
    end

    test 'should set docname and outfilesuffix from manname and manvolnum for manpage backend and doctype' do
      input = <<-EOS
= asciidoctor(1)
:doctype: manpage

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats
      EOS

      doc = document_from_string input, :backend => 'manpage'
      assert_equal 'asciidoctor', doc.attributes['docname']
      assert_equal '.1', doc.attributes['outfilesuffix']
    end

    test 'should mark synopsis as special section in manpage doctype' do
      input = <<-EOS
= asciidoctor(1)
:doctype: manpage

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats

== SYNOPSIS

*asciidoctor* ['OPTION']... 'FILE'..
      EOS

      doc = document_from_string input
      synopsis_section = doc.blocks.first
      refute_nil synopsis_section
      assert_equal :section, synopsis_section.context
      assert synopsis_section.special
      assert_equal 'synopsis', synopsis_section.sectname
    end

    test 'should output special header block in HTML for manpage doctype' do
      input = <<-EOS
= asciidoctor(1)
:doctype: manpage

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats

== SYNOPSIS

*asciidoctor* ['OPTION']... 'FILE'..
      EOS

      output = render_string input
      assert_css 'body.manpage', output, 1
      assert_xpath '//body/*[@id="header"]/h1[text()="asciidoctor(1) Manual Page"]', output, 1
      assert_xpath '//body/*[@id="header"]/h1/following-sibling::h2[text()="NAME"]', output, 1
      assert_xpath '//h2[text()="NAME"]/following-sibling::*[@class="sectionbody"]', output, 1
      assert_xpath '//h2[text()="NAME"]/following-sibling::*[@class="sectionbody"]/p[text()="asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats"]', output, 1
      assert_xpath '//*[@id="content"]/*[@class="sect1"]/h2[text()="SYNOPSIS"]', output, 1
    end

    test 'should output special header block in embeddable HTML for manpage doctype' do
      input = <<-EOS
= asciidoctor(1)
:doctype: manpage
:showtitle:

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats

== SYNOPSIS

*asciidoctor* ['OPTION']... 'FILE'..
      EOS

      output = render_embedded_string input
      assert_xpath '/h1[text()="asciidoctor(1) Manual Page"]', output, 1
      assert_xpath '/h1/following-sibling::h2[text()="NAME"]', output, 1
      assert_xpath '/h2[text()="NAME"]/following-sibling::*[@class="sectionbody"]', output, 1
      assert_xpath '/h2[text()="NAME"]/following-sibling::*[@class="sectionbody"]/p[text()="asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats"]', output, 1
    end
  end

  context 'Secure Asset Path' do
    test 'allows us to specify a path relative to the current dir' do
      doc = empty_document
      legit_path = Dir.pwd + '/foo'
      assert_equal legit_path, doc.normalize_asset_path(legit_path)
    end

    test 'keeps naughty absolute paths from getting outside' do
      naughty_path = "#{disk_root}etc/passwd"
      doc = empty_document
      secure_path = doc.normalize_asset_path(naughty_path)
      refute_equal naughty_path, secure_path
      assert_match(/^#{doc.base_dir}/, secure_path)
    end

    test 'keeps naughty relative paths from getting outside' do
      naughty_path = 'safe/ok/../../../../../etc/passwd'
      doc = empty_document
      secure_path = redirect_streams { doc.normalize_asset_path(naughty_path) }
      refute_equal naughty_path, secure_path
      assert_match(/^#{doc.base_dir}/, secure_path)
    end

    test 'should raise an exception when a converter cannot be resolved before conversion' do
      input = <<-EOS
= Document Title

text
      EOS
      exception = assert_raises NotImplementedError do
        Asciidoctor.convert input, :backend => 'unknownBackend'
      end
      assert_includes exception.message, 'missing converter for backend \'unknownBackend\''
    end

    test 'should raise an exception when a converter cannot be resolved while parsing' do
      input = <<-EOS
= Document Title

== A _Big_ Section

text
      EOS
      exception = assert_raises NotImplementedError do
        Asciidoctor.convert input, :backend => 'unknownBackend'
      end
      assert_includes exception.message, 'missing converter for backend \'unknownBackend\''
    end
  end

  context 'Timing report' do
    test 'print_report does not lose precision' do
      timings = Asciidoctor::Timings.new
      log = timings.instance_variable_get(:@log)
      log[:read] = 0.00001
      log[:parse] = 0.00003
      log[:convert] = 0.00005
      timings.print_report(sink = StringIO.new)
      expect = ['0.00004', '0.00005', '0.00009']
      result = sink.string.split("\n").map {|l| l.sub(/.*:\s*([\d.]+)/, '\1') }
      assert_equal expect, result
    end

    test 'print_report should print 0 for untimed phases' do
      Asciidoctor::Timings.new.print_report(sink = StringIO.new)
      expect = [].fill('0.00000', 0..2)
      result = sink.string.split("\n").map {|l| l.sub(/.*:\s*([\d.]+)/, '\1') }
      assert_equal expect, result
    end
  end
end
