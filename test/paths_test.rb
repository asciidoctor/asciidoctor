# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context 'Path Resolver' do
  context 'Web Paths' do
    def setup
      @resolver = Asciidoctor::PathResolver.new
    end

    test 'target with absolute path' do
      assert_equal '/images', @resolver.web_path('/images')
      assert_equal '/images', @resolver.web_path('/images', '')
      assert_equal '/images', @resolver.web_path('/images', nil)
    end

    test 'target with relative path' do
      assert_equal 'images', @resolver.web_path('images')
      assert_equal 'images', @resolver.web_path('images', '')
      assert_equal 'images', @resolver.web_path('images', nil)
    end

    test 'target with hidden relative path' do
      assert_equal '.images', @resolver.web_path('.images')
      assert_equal '.images', @resolver.web_path('.images', '')
      assert_equal '.images', @resolver.web_path('.images', nil)
    end

    test 'target with path relative to current directory' do
      assert_equal './images', @resolver.web_path('./images')
      assert_equal './images', @resolver.web_path('./images', '')
      assert_equal './images', @resolver.web_path('./images', nil)
    end

    test 'target with absolute path ignores start path' do
      assert_equal '/images', @resolver.web_path('/images', 'foo')
      assert_equal '/images', @resolver.web_path('/images', '/foo')
      assert_equal '/images', @resolver.web_path('/images', './foo')
    end

    test 'target with relative path appended to start path' do
      assert_equal 'assets/images', @resolver.web_path('images', 'assets')
      assert_equal '/assets/images', @resolver.web_path('images', '/assets')
      #assert_equal '/assets/images/tiger.png', @resolver.web_path('tiger.png', '/assets//images')
      assert_equal './assets/images', @resolver.web_path('images', './assets')
      assert_equal '/theme.css', @resolver.web_path('theme.css', '/')
      assert_equal '/css/theme.css', @resolver.web_path('theme.css', '/css/')
    end

    test 'target with path relative to current directory appended to start path' do
      assert_equal 'assets/images', @resolver.web_path('./images', 'assets')
      assert_equal '/assets/images', @resolver.web_path('./images', '/assets')
      assert_equal './assets/images', @resolver.web_path('./images', './assets')
    end

    test 'target with relative path appended to url start path' do
      assert_equal 'http://www.example.com/assets/images', @resolver.web_path('images', 'http://www.example.com/assets')
    end

    # enable if we want to allow web_path to detect and preserve a target URI
    #test 'target with file url appended to relative path' do
    #  assert_equal 'file:///home/username/styles/asciidoctor.css', @resolver.web_path('file:///home/username/styles/asciidoctor.css', '.')
    #end

    # enable if we want to allow web_path to detect and preserve a target URI
    #test 'target with http url appended to relative path' do
    #  assert_equal 'http://example.com/asciidoctor.css', @resolver.web_path('http://example.com/asciidoctor.css', '.')
    #end

    test 'normalize target' do
      assert_equal '../images', @resolver.web_path('../images/../images')
    end

    test 'append target to start path and normalize' do
      assert_equal '../images', @resolver.web_path('../images/../images', '../images')
      assert_equal '../../images', @resolver.web_path('../images', '..')
    end

    test 'normalize parent directory that follows root' do
      assert_equal '/tiger.png', @resolver.web_path('/../tiger.png')
      assert_equal '/tiger.png', @resolver.web_path('/../../tiger.png')
    end

    test 'uses start when target is empty' do
      assert_equal 'assets/images', @resolver.web_path('', 'assets/images')
      assert_equal 'assets/images', @resolver.web_path(nil, 'assets/images')
    end

    test 'posixifies windows paths' do
      @resolver.file_separator = '\\'
      assert_equal '/images', @resolver.web_path('\\images')
      assert_equal '../images', @resolver.web_path('..\\images')
      assert_equal '/images', @resolver.web_path('\\..\\images')
      assert_equal 'assets/images', @resolver.web_path('assets\\images')
      assert_equal '../assets/images', @resolver.web_path('assets\\images', '..\\images\\..')
    end

    test 'URL encode spaces in path' do
      assert_equal 'assets%20and%20stuff/lots%20of%20images', @resolver.web_path('lots of images', 'assets and stuff')
    end
  end

  context 'System Paths' do
    JAIL = '/home/doctor/docs'
    default_logger = Asciidoctor::LoggerManager.logger

    def setup
      @resolver = Asciidoctor::PathResolver.new
      @logger = (Asciidoctor::LoggerManager.logger = Asciidoctor::MemoryLogger.new)
    end

    teardown do
      Asciidoctor::LoggerManager.logger = default_logger
    end

    test 'raises security error if jail is not an absolute path' do
      begin
        @resolver.system_path('images/tiger.png', '/etc', 'foo')
        flunk 'Expecting SecurityError to be raised'
      rescue SecurityError
      end
    end

    #test 'raises security error if jail is not a canoncial path' do
    #  begin
    #    @resolver.system_path('images/tiger.png', '/etc', %(#{JAIL}/../foo))
    #    flunk 'Expecting SecurityError to be raised'
    #  rescue SecurityError
    #  end
    #end

    test 'prevents access to paths outside of jail' do
      result = @resolver.system_path '../../../../../css', %(#{JAIL}/assets/stylesheets), JAIL
      assert_equal %(#{JAIL}/css), result
      assert_message @logger, :WARN, 'path has illegal reference to ancestor of jail; recovering automatically'

      @logger.clear
      result = @resolver.system_path '/../../../../../css', %(#{JAIL}/assets/stylesheets), JAIL
      assert_equal %(#{JAIL}/css), result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'

      @logger.clear
      result = @resolver.system_path '../../../css', '../../..', JAIL
      assert_equal %(#{JAIL}/css), result
      assert_message @logger, :WARN, 'path has illegal reference to ancestor of jail; recovering automatically'
    end

    test 'throws exception for illegal path access if recover is false' do
      begin
        @resolver.system_path('../../../../../css', "#{JAIL}/assets/stylesheets", JAIL, :recover => false)
        flunk 'Expecting SecurityError to be raised'
      rescue SecurityError
      end
    end

    test 'resolves start path if target is empty' do
      assert_equal "#{JAIL}/assets/stylesheets", @resolver.system_path('', "#{JAIL}/assets/stylesheets", JAIL)
      assert_equal "#{JAIL}/assets/stylesheets", @resolver.system_path(nil, "#{JAIL}/assets/stylesheets", JAIL)
    end

    test 'expands parent references in start path if target is empty' do
      assert_equal "#{JAIL}/stylesheets", @resolver.system_path('', "#{JAIL}/assets/../stylesheets", JAIL)
    end

    test 'expands parent references in start path if target is not empty' do
      assert_equal "#{JAIL}/stylesheets/site.css", @resolver.system_path('site.css', "#{JAIL}/assets/../stylesheets", JAIL)
    end

    test 'resolves start path if target is dot' do
      assert_equal "#{JAIL}/assets/stylesheets", @resolver.system_path('.', "#{JAIL}/assets/stylesheets", JAIL)
      assert_equal "#{JAIL}/assets/stylesheets", @resolver.system_path('./', "#{JAIL}/assets/stylesheets", JAIL)
    end

    test 'treats absolute target outside of jail as relative when jail is specified' do
      result = @resolver.system_path '/', "#{JAIL}/assets/stylesheets", JAIL
      assert_equal JAIL, result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'

      @logger.clear
      result = @resolver.system_path '/foo', "#{JAIL}/assets/stylesheets", JAIL
      assert_equal "#{JAIL}/foo", result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'

      @logger.clear
      result = @resolver.system_path '/../foo', "#{JAIL}/assets/stylesheets", JAIL
      assert_equal "#{JAIL}/foo", result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'

      @logger.clear
      @resolver.file_separator = '\\'
      result = @resolver.system_path 'baz.adoc', 'C:/foo', 'C:/bar'
      assert_equal 'C:/bar/baz.adoc', result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'
    end

    test 'allows use of absolute target or start if resolved path is sub-path of jail' do
      assert_equal "#{JAIL}/my/path", @resolver.system_path("#{JAIL}/my/path", '', JAIL)
      assert_equal "#{JAIL}/my/path", @resolver.system_path("#{JAIL}/my/path", nil, JAIL)
      assert_equal "#{JAIL}/my/path", @resolver.system_path('', "#{JAIL}/my/path", JAIL)
      assert_equal "#{JAIL}/my/path", @resolver.system_path(nil, "#{JAIL}/my/path", JAIL)
      assert_equal "#{JAIL}/my/path", @resolver.system_path('path', "#{JAIL}/my", JAIL)
      assert_equal '/foo/bar/baz.adoc', @resolver.system_path('/foo/bar/baz.adoc', nil, '/')
      assert_equal '/foo/bar/baz.adoc', @resolver.system_path('baz.adoc', '/foo/bar', '/')
      assert_equal '/foo/bar/baz.adoc', @resolver.system_path('baz.adoc', 'foo/bar', '/')
    end

    test 'uses jail path if start path is empty' do
      assert_equal "#{JAIL}/images/tiger.png", @resolver.system_path('images/tiger.png', '', JAIL)
      assert_equal "#{JAIL}/images/tiger.png", @resolver.system_path('images/tiger.png', nil, JAIL)
    end

    test 'warns if start is not contained within jail' do
      result = @resolver.system_path 'images/tiger.png', '/etc', JAIL
      assert_equal %(#{JAIL}/images/tiger.png), result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'

      @logger.clear
      result = @resolver.system_path '.', '/etc', JAIL
      assert_equal JAIL, result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'

      @logger.clear
      @resolver.file_separator = '\\'
      result = @resolver.system_path '.', 'C:/foo', 'C:/bar'
      assert_equal 'C:/bar', result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'
    end

    test 'allows start path to be parent of jail if resolved target is inside jail' do
      assert_equal "#{JAIL}/foo/path", @resolver.system_path('foo/path', JAIL, "#{JAIL}/foo")
      @resolver.file_separator = '\\'
      assert_equal "C:/dev/project/README.adoc", @resolver.system_path('project/README.adoc', 'C:/dev', 'C:/dev/project')
    end

    test 'relocates target to jail if resolved value fails outside of jail' do
      result = @resolver.system_path 'bar/baz.adoc', JAIL, "#{JAIL}/foo"
      assert_equal %(#{JAIL}/foo/bar/baz.adoc), result
      assert_message @logger, :WARN, 'path is outside of jail; recovering automatically'

      @logger.clear
      @resolver.file_separator = '\\'
      result = @resolver.system_path 'bar/baz.adoc', 'D:/', 'C:/foo'
      assert_equal 'C:/foo/bar/baz.adoc', result
      assert_message @logger, :WARN, '~outside of jail root'
    end

    test 'raises security error if start is not contained within jail and recover is disabled' do
      begin
        @resolver.system_path('images/tiger.png', '/etc', JAIL, :recover => false)
        flunk 'Expecting SecurityError to be raised'
      rescue SecurityError
      end

      begin
        @resolver.system_path('.', '/etc', JAIL, :recover => false)
        flunk 'Expecting SecurityError to be raised'
      rescue SecurityError
      end
    end

    test 'expands parent references in absolute path if jail is not specified' do
      assert_equal '/etc/stylesheet.css', @resolver.system_path('/usr/share/../../etc/stylesheet.css')
    end

    test 'resolves absolute directory if jail is not specified' do
      assert_equal '/usr/share/stylesheet.css', @resolver.system_path('/usr/share/stylesheet.css', '/home/dallen/docs/assets/stylesheets')
    end

    test 'resolves ancestor directory of start if jail is not specified' do
      assert_equal '/usr/share/stylesheet.css', @resolver.system_path('../../../../../usr/share/stylesheet.css', '/home/dallen/docs/assets/stylesheets')
    end

    test 'resolves absolute path if start is absolute and target is relative' do
      assert_equal '/usr/share/assets/stylesheet.css', @resolver.system_path('assets/stylesheet.css', '/usr/share')
    end

    test 'resolves absolute UNC path if start is absolute and target is relative' do
      assert_equal '//QA/c$/users/asciidoctor/assets/stylesheet.css', @resolver.system_path('assets/stylesheet.css', '//QA/c$/users/asciidoctor')
    end

    test 'resolves relative target relative to current directory if start is empty' do
      pwd = File.expand_path(Dir.pwd)
      assert_equal "#{pwd}/images/tiger.png", @resolver.system_path('images/tiger.png', '')
      assert_equal "#{pwd}/images/tiger.png", @resolver.system_path('images/tiger.png', nil)
      assert_equal "#{pwd}/images/tiger.png", @resolver.system_path('images/tiger.png')
    end

    test 'resolves relative hidden target relative to current directory if start is empty' do
      pwd = File.expand_path(Dir.pwd)
      assert_equal "#{pwd}/.images/tiger.png", @resolver.system_path('.images/tiger.png', '')
      assert_equal "#{pwd}/.images/tiger.png", @resolver.system_path('.images/tiger.png', nil)
    end

    test 'resolves and normalizes start when target is empty' do
      pwd = File.expand_path Dir.pwd
      assert_equal '/home/doctor/docs', (@resolver.system_path '', '/home/doctor/docs')
      assert_equal '/home/doctor/docs', (@resolver.system_path '', '/home/doctor/./docs')
      assert_equal '/home/doctor/docs', (@resolver.system_path nil, '/home/doctor/docs')
      assert_equal '/home/doctor/docs', (@resolver.system_path nil, '/home/doctor/./docs')
      assert_equal %(#{pwd}/assets/images), (@resolver.system_path nil, 'assets/images')
      @resolver.system_path '', '../assets/images', JAIL
      assert_message @logger, :WARN, 'path has illegal reference to ancestor of jail; recovering automatically'
    end

    test 'posixifies windows paths' do
      @resolver.file_separator = '\\'
      assert_equal "#{JAIL}/assets/css", @resolver.system_path('..\\css', 'assets\\stylesheets', JAIL)
    end

    test 'resolves windows paths when file separator is backlash' do
      @resolver.file_separator = '\\'

      assert_equal 'C:/data/docs', (@resolver.system_path '..', 'C:\\data\\docs\\assets', 'C:\\data\\docs')

      result = @resolver.system_path '..\\..', 'C:\\data\\docs\\assets', 'C:\\data\\docs'
      assert_equal 'C:/data/docs', result
      assert_message @logger, :WARN, 'path has illegal reference to ancestor of jail; recovering automatically'

      @logger.clear
      result = @resolver.system_path '..\\..\\css', 'C:\\data\\docs\\assets', 'C:\\data\\docs'
      assert_equal 'C:/data/docs/css', result
      assert_message @logger, :WARN, 'path has illegal reference to ancestor of jail; recovering automatically'
    end

    test 'should calculate relative path' do
      filename = @resolver.system_path('part1/chapter1/section1.adoc', nil, JAIL)
      assert_equal "#{JAIL}/part1/chapter1/section1.adoc", filename
      assert_equal 'part1/chapter1/section1.adoc', @resolver.relative_path(filename, JAIL)
    end

    test 'should resolve relative path to filename if does not share common root with base directory' do
      filename = '/docs/partials'
      base_dir = '/home/user/docs'
      result = @resolver.relative_path filename, base_dir
      assert_equal filename, result
    end

    test 'should resolve relative path relative to base dir in unsafe mode' do
      base_dir = fixture_path 'base'
      doc = empty_document :base_dir => base_dir, :safe => Asciidoctor::SafeMode::UNSAFE
      expected = ::File.join base_dir, 'images', 'tiger.png'
      actual = doc.normalize_system_path 'tiger.png', 'images'
      assert_equal expected, actual
    end

    test 'should resolve absolute path as absolute in unsafe mode' do
      base_dir = fixture_path 'base'
      doc = empty_document :base_dir => base_dir, :safe => Asciidoctor::SafeMode::UNSAFE
      actual = doc.normalize_system_path 'tiger.png', '/etc/images'
      assert_equal '/etc/images/tiger.png', actual
    end
  end

  context 'Helpers' do
    test 'rootname should return file name without extension' do
      assert_equal 'master', Asciidoctor::Helpers.rootname('master.adoc')
      assert_equal 'docs/master', Asciidoctor::Helpers.rootname('docs/master.adoc')
    end

    test 'rootname should file name if it has no extension' do
      assert_equal 'master', Asciidoctor::Helpers.rootname('master')
      assert_equal 'docs/master', Asciidoctor::Helpers.rootname('docs/master')
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
end
