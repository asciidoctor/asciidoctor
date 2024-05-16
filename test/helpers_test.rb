# frozen_string_literal: true

require_relative 'test_helper'

context 'Helpers' do
  context 'URI Encoding' do
    test 'should URI encode non-word characters generally' do
      given = ' !*/%&?\\='
      expect = '%20%21%2A%2F%25%26%3F%5C%3D'
      assert_equal expect, (Asciidoctor::Helpers.encode_uri_component given)
    end

    test 'should not URI encode select non-word characters' do
      # NOTE Ruby 2.5 and up stopped encoding ~
      given = '-.'
      expect = given
      assert_equal expect, (Asciidoctor::Helpers.encode_uri_component given)
    end
  end

  context 'URIs and Paths' do
    test 'rootname should return file name without extension' do
      assert_equal 'main', Asciidoctor::Helpers.rootname('main.adoc')
      assert_equal 'docs/main', Asciidoctor::Helpers.rootname('docs/main.adoc')
    end

    test 'rootname should file name if it has no extension' do
      assert_equal 'main', Asciidoctor::Helpers.rootname('main')
      assert_equal 'docs/main', Asciidoctor::Helpers.rootname('docs/main')
    end

    test 'rootname should ignore dot not in last segment' do
      assert_equal 'include.d/main', Asciidoctor::Helpers.rootname('include.d/main')
      assert_equal 'include.d/main', Asciidoctor::Helpers.rootname('include.d/main.adoc')
    end

    test 'extname? should return whether path contains an extname' do
      assert Asciidoctor::Helpers.extname?('document.adoc')
      assert Asciidoctor::Helpers.extname?('path/to/document.adoc')
      assert_nil Asciidoctor::Helpers.extname?('basename')
      refute Asciidoctor::Helpers.extname?('include.d/basename')
    end

    test 'UriSniffRx should detect URIs' do
      assert Asciidoctor::UriSniffRx =~ 'http://example.com'
      assert Asciidoctor::UriSniffRx =~ 'https://example.com'
      assert Asciidoctor::UriSniffRx =~ 'data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs='
    end

    test 'UriSniffRx should not detect an absolute Windows path as a URI' do
      assert Asciidoctor::UriSniffRx !~ 'c:/sample.adoc'
      assert Asciidoctor::UriSniffRx !~ 'c:\\sample.adoc'
    end

    test 'uriish? should not detect a classloader path as a URI on JRuby' do
      input = 'uri:classloader:/sample.png'
      assert Asciidoctor::UriSniffRx =~ input
      if jruby?
        refute Asciidoctor::Helpers.uriish? input
      else
        assert Asciidoctor::Helpers.uriish? input
      end
    end

    test 'UriSniffRx should not detect URI that does not start on first line' do
      assert Asciidoctor::UriSniffRx !~ %(text\nhttps://example.org)
    end
  end

  context 'Type Resolution' do
    test 'should get class for top-level class name' do
      clazz = Asciidoctor::Helpers.class_for_name 'String'
      refute_nil clazz
      assert_equal String, clazz
    end

    test 'should get class for class name in module' do
      clazz = Asciidoctor::Helpers.class_for_name 'Asciidoctor::Document'
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should get class for class name resolved from root' do
      clazz = Asciidoctor::Helpers.class_for_name '::Asciidoctor::Document'
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should raise exception if cannot find class for name' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.class_for_name 'InvalidModule::InvalidClass'
      end
      assert_match %r/^Could not resolve class for name: InvalidModule::InvalidClass$/, ex.message
    end

    test 'should raise exception if constant name is invalid' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.class_for_name 'foobar'
      end
      assert_match %r/^Could not resolve class for name: foobar$/, ex.message
    end

    test 'should raise exception if class not found in scope' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.class_for_name 'Asciidoctor::Extensions::String'
      end
      assert_match %r/^Could not resolve class for name: Asciidoctor::Extensions::String/, ex.message
    end

    test 'should raise exception if name resolves to module' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.class_for_name 'Asciidoctor::Extensions'
      end
      assert_match %r/^Could not resolve class for name: Asciidoctor::Extensions/, ex.message
    end

    test 'should resolve class if class is given' do
      clazz = Asciidoctor::Helpers.resolve_class Asciidoctor::Document
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should resolve class if class from string' do
      clazz = Asciidoctor::Helpers.resolve_class 'Asciidoctor::Document'
      refute_nil clazz
      assert_equal Asciidoctor::Document, clazz
    end

    test 'should not resolve class if not in scope' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.resolve_class 'Asciidoctor::Extensions::String'
      end
      assert_match %r/^Could not resolve class for name: Asciidoctor::Extensions::String$/, ex.message
    end
  end

  context 'Require Library' do
    test 'should include backtrace in LoadError thrown by Helpers.require_library' do
      ex = assert_raises LoadError do
        Asciidoctor::Helpers.require_library 'does-not-exist'
      end
      expected_message = %(asciidoctor: FAILED: required gem 'does-not-exist' is not available. Processing aborted.)
      expected_cause_message = %r/^(?:no such file to load|cannot load such file) -- does-not-exist$/
      assert_equal expected_message, ex.message
      assert_match expected_cause_message, ex.cause.message
      if (ex.respond_to? :full_message) && !jruby? && (Gem::Version.new RUBY_VERSION) >= (Gem::Version.new '2.7.0')
        assert_match %r/helpers\.rb.*in.*require_library/, ex.full_message
        assert_match %r/(?:no such file to load|cannot load such file) -- does-not-exist/, ex.full_message
      else
        assert_match %r/helpers\.rb.*in.*require_library/, (ex.backtrace.join ?\n)
        assert_match %r/helpers\.rb.*in.*require_library/, (ex.cause.backtrace.join ?\n)
      end
    end
  end
end
