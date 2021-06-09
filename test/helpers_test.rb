# frozen_string_literal: true

require_relative 'test_helper'

context 'Helpers' do
  context 'URI Encoding' do
    test 'should URI encode non-word characters generally' do
      given = ' !*/%&?\\='
      expect = '+%21%2A%2F%25%26%3F%5C%3D'
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
      assert_equal 'master', Asciidoctor::Helpers.rootname('master.adoc')
      assert_equal 'docs/master', Asciidoctor::Helpers.rootname('docs/master.adoc')
    end

    test 'rootname should file name if it has no extension' do
      assert_equal 'master', Asciidoctor::Helpers.rootname('master')
      assert_equal 'docs/master', Asciidoctor::Helpers.rootname('docs/master')
    end

    test 'rootname should ignore dot not in last segment' do
      assert_equal 'include.d/master', Asciidoctor::Helpers.rootname('include.d/master')
      assert_equal 'include.d/master', Asciidoctor::Helpers.rootname('include.d/master.adoc')
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
      assert_equal 'Could not resolve class for name: InvalidModule::InvalidClass', ex.message
    end

    test 'should raise exception if constant name is invalid' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.class_for_name 'foobar'
      end
      assert_equal 'Could not resolve class for name: foobar', ex.message
    end

    test 'should raise exception if class not found in scope' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.class_for_name 'Asciidoctor::Extensions::String'
      end
      assert_equal 'Could not resolve class for name: Asciidoctor::Extensions::String', ex.message
    end

    test 'should raise exception if name resolves to module' do
      ex = assert_raises NameError do
        Asciidoctor::Helpers.class_for_name 'Asciidoctor::Extensions'
      end
      assert_equal 'Could not resolve class for name: Asciidoctor::Extensions', ex.message
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
      ex = assert_raises do
        Asciidoctor::Helpers.resolve_class 'Asciidoctor::Extensions::String'
      end
      assert_equal 'Could not resolve class for name: Asciidoctor::Extensions::String', ex.message
    end
  end
end
