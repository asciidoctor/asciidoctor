# frozen_string_literal: true
ASCIIDOCTOR_TEST_DIR = File.absolute_path __dir__
ASCIIDOCTOR_LIB_DIR = ENV['ASCIIDOCTOR_LIB_DIR'] || (File.join ASCIIDOCTOR_TEST_DIR, '../lib')

require 'simplecov' if ENV['COVERAGE'] == 'true'

require File.join ASCIIDOCTOR_LIB_DIR, 'asciidoctor'
Dir.chdir Asciidoctor::ROOT_DIR

require 'nokogiri'
# NOTE rouge has all sorts of warnings we don't want to see, so silence them
proc do
  old_verbose, $VERBOSE = $VERBOSE, nil
  require 'rouge'
  $VERBOSE = old_verbose
end.call
require 'socket'
require 'tempfile'
require 'tmpdir'

autoload :FileUtils, 'fileutils'
autoload :Pathname,  'pathname'

RE_XMLNS_ATTRIBUTE = / xmlns="[^"]+"/
RE_DOCTYPE = /\s*<!DOCTYPE (.*)/

require 'minitest/autorun'

# Minitest 4 doesn't have Minitest::Test
Minitest::Test = MiniTest::Unit::TestCase unless defined? Minitest::Test

class Minitest::Test
  def jruby?
    RUBY_ENGINE == 'jruby'
  end

  def self.jruby_9_1_windows?
    RUBY_ENGINE == 'jruby' && windows? && (JRUBY_VERSION.start_with? '9.1.')
  end

  def jruby_9_1_windows?
    Minitest::Test.jruby_9_1_windows?
  end

  def self.windows?
    /mswin|msys|mingw/.match? RbConfig::CONFIG['host_os']
  end

  def windows?
    Minitest::Test.windows?
  end

  def disk_root
    %(#{windows? ? (Asciidoctor::ROOT_DIR.partition '/')[0] : ''}/)
  end

  def empty_document options = {}
    options[:parse] ? (Asciidoctor::Document.new [], options).parse : (Asciidoctor::Document.new [], options)
  end

  def empty_safe_document options = {}
    Asciidoctor::Document.new [], (options.merge safe: :safe)
  end

  def sample_doc_path name
    unless (name = name.to_s).include? '.'
      %w(adoc asciidoc txt).each do |ext|
        if File.exist? fixture_path %(#{name}.#{ext})
          name = %(#{name}.#{ext})
          break
        end
      end
    end
    fixture_path name
  end

  def bindir
    File.join Asciidoctor::ROOT_DIR, 'bin'
  end

  def testdir
    ASCIIDOCTOR_TEST_DIR
  end

  def fixturedir
    File.join testdir, 'fixtures'
  end

  def fixture_path name
    File.join fixturedir, name
  end

  def example_document name, opts = {}
    document_from_string (File.read (sample_doc_path name), mode: Asciidoctor::FILE_READ_MODE), opts
  end

  def xmlnodes_at_css css, content, count = nil
    xmlnodes_at_path :css, css, content, count
  end

  def xmlnodes_at_xpath xpath, content, count = nil
    xmlnodes_at_path :xpath, xpath, content, count
  end

  def xmlnodes_at_path type, path, content, count = nil
    doc = xmldoc_from_string content
    case type
    when :xpath
      namespaces = (doc.respond_to? :root) ? doc.root.namespaces : {}
      results = doc.xpath (path.sub '/', './'), namespaces
    when :css
      results = doc.css path
    end
    count == 1 ? results.first : results
  end

  # Generate an xpath attribute matcher that matches a name in the class attribute
  def contains_class name
    %(contains(concat(' ', normalize-space(@class), ' '), ' #{name} '))
  end

  def assert_css css, content, count = nil
    assert_path :css, css, content, count
  end

  def assert_xpath xpath, content, count = nil
    assert_path :xpath, xpath, content, count
  end

  def assert_path type, path, content, count = nil
    case type
    when :xpath
      type_name = 'XPath'
    when :css
      type_name = 'CSS'
    end

    results = xmlnodes_at_path type, path, content

    if count == true || count == false
      if count == results
        assert true
      else
        flunk %(#{type_name} #{path} yielded #{results} rather than #{count} for:\n#{content})
      end
    elsif count && results.size != count
      flunk %(#{type_name} #{path} yielded #{results.size} elements rather than #{count} for:\n#{content})
    elsif count.nil? && results.empty?
      flunk %(#{type_name} #{path} not found in:\n#{content})
    else
      assert true
    end
  end

  def assert_include expected, actual
    assert_includes actual, expected
  end

  def refute_include not_expected, actual
    refute_includes actual, not_expected
  end

  def assert_message logger, severity, expected_message, kind = String, idx = nil
    unless idx
      assert_equal 1, logger.messages.size
      idx = 0
    end
    message = logger.messages[idx]
    assert_equal severity, message[:severity]
    assert_kind_of kind, message[:message]
    if kind == String
      actual_message = message[:message]
    else
      refute_nil message[:message][:source_location]
      actual_message = message[:message].inspect
    end
    if expected_message.start_with? '~'
      assert_includes actual_message, expected_message[1..-1]
    else
      assert_equal expected_message, actual_message
    end
  end

  def assert_messages logger, expected_messages
    assert_equal expected_messages.size, logger.messages.size
    expected_messages.each_with_index do |expected_message_details, idx|
      severity, expected_message, kind = expected_message_details
      assert_message logger, severity, expected_message, (kind || String), idx
    end
  end

  def xmldoc_from_string content
    if (content.start_with? '<?xml ') || (RE_XMLNS_ATTRIBUTE.match? content)
      Nokogiri::XML::Document.parse content
    elsif RE_DOCTYPE !~ content
      Nokogiri::HTML::DocumentFragment.parse content
    elsif $1.start_with? 'html'
      Nokogiri::HTML::Document.parse content
    else
      Nokogiri::XML::Document.parse content
    end
  end

  def document_from_string src, opts = {}
    assign_default_test_options opts
    opts[:parse] ? (Asciidoctor::Document.new src.lines, opts).parse : (Asciidoctor::Document.new src.lines, opts)
  end

  def block_from_string src, opts = {}
    (document_from_string src, (opts.merge standalone: false)).blocks.first
  end

  def convert_string src, opts = {}
    keep_namespaces = opts.delete :keep_namespaces
    if keep_namespaces
      (document_from_string src, opts).convert
    else
      # this is required because nokogiri is easily confused by namespaces
      result = (document_from_string src, opts).convert
      result ? (result.sub RE_XMLNS_ATTRIBUTE, '') : result
    end
  end

  def convert_string_to_embedded src, opts = {}
    (document_from_string src, (opts.merge standalone: false)).convert
  end

  def convert_inline_string src, opts = {}
    (document_from_string src, (opts.merge doctype: :inline)).convert
  end

  def parse_header_metadata source, doc = nil
    reader = Asciidoctor::Reader.new source.split Asciidoctor::LF
    [(Asciidoctor::Parser.parse_header_metadata reader, doc), reader]
  end

  def assign_default_test_options opts
    opts[:standalone] = true unless opts.key? :standalone
    opts[:parse] = true unless opts.key? :parse
    if opts[:standalone]
      # don't embed stylesheet unless test requests the default behavior
      if opts.key? :linkcss_default
        opts.delete :linkcss_default
      else
        opts[:attributes] ||= {}
        opts[:attributes]['linkcss'] = ''
      end
    end
    if (template_dir = ENV['TEMPLATE_DIR'])
      opts[:template_dir] = template_dir unless opts.key? :template_dir
    end
    nil
  end

  # Decode the numeric character reference, such as 8212, to a Unicode glyph
  # so it may be used in an XPath expression.
  #
  # Examples
  #
  #   decode_char 60
  #   # => "<"
  #
  # Returns the decoded String that corresponds to the numeric character reference
  def decode_char number
    [number].pack 'U1'
  end

  def invoke_cli_with_filenames argv = [], filenames = [], &block
    filepaths = []

    filenames.each do |filename|
      if filenames.nil? || (Pathname.new filename).absolute?
        filepaths << filename
      else
        filepaths << (fixture_path filename)
      end
    end

    invoker = Asciidoctor::Cli::Invoker.new argv + filepaths
    invoker.invoke!(&block)
    invoker
  end

  def invoke_cli_to_buffer argv = [], filename = 'sample.adoc', &block
    invoke_cli argv, filename, [StringIO.new, StringIO.new], &block
  end

  def invoke_cli argv = [], filename = 'sample.adoc', buffers = nil, &block
    if filename.nil? || filename == '-' || (Pathname.new filename).absolute?
      filepath = filename
    else
      filepath = fixture_path filename
    end
    invoker = Asciidoctor::Cli::Invoker.new argv + [filepath]
    invoker.redirect_streams(*buffers) if buffers
    invoker.invoke!(&block)
    invoker
  end

  def redirect_streams
    old_stdout, $stdout = $stdout, StringIO.new
    old_stderr, $stderr = $stderr, StringIO.new
    old_logger = Asciidoctor::LoggerManager.logger
    old_logger_level = old_logger.level
    new_logger = (Asciidoctor::LoggerManager.logger = Asciidoctor::Logger.new $stderr)
    new_logger.level = old_logger_level
    yield $stdout, $stderr
  ensure
    $stdout, $stderr = old_stdout, old_stderr
    Asciidoctor::LoggerManager.logger = old_logger
  end

  def resolve_localhost
    Socket.ip_address_list.find(&:ipv4?).ip_address
  end

  def using_memory_logger level = nil
    old_logger = Asciidoctor::LoggerManager.logger
    memory_logger = Asciidoctor::MemoryLogger.new
    memory_logger.level = level if level
    begin
      Asciidoctor::LoggerManager.logger = memory_logger
      yield memory_logger
    ensure
      Asciidoctor::LoggerManager.logger = old_logger
    end
  end

  def in_verbose_mode
    begin
      old_logger_level, Asciidoctor::LoggerManager.logger.level = Asciidoctor::LoggerManager.logger.level, Logger::Severity::DEBUG
      yield
    ensure
      Asciidoctor::LoggerManager.logger.level = old_logger_level
    end
  end

  def asciidoctor_cmd ruby_args = nil
    [Gem.ruby, *ruby_args, (File.join bindir, 'asciidoctor')]
  end

  # NOTE run_command fails on JRuby 9.1 for Windows with the following error:
  # Java::JavaLang::ClassCastException at org.jruby.util.ShellLauncher.getModifiedEnv(ShellLauncher.java:271)
  def run_command cmd, *args, &block
    if Array === cmd
      args.unshift(*cmd)
      cmd = args.shift
    end
    kw_args = Hash === args[-1] ? args.pop : {}
    env = kw_args[:env]
    (env ||= {})['RUBYOPT'] = nil unless kw_args[:use_bundler]
    # JRuby 9.1 on Windows doesn't support popen options; therefore, test cannot capture / assert on stderr
    opts = jruby_9_1_windows? ? {} : { err: [:child, :out] }
    if env
      # NOTE while JRuby 9.2.10.0 implements support for unsetenv_others, it doesn't work in child
      #if jruby? && (Gem::Version.new JRUBY_VERSION) < (Gem::Version.new '9.2.10.0')
      if jruby?
        begin
          old_env, env = ENV.merge, (ENV.merge env)
          env.each {|key, val| env.delete key if val.nil? } if env.value? nil
          ENV.replace env
          popen [cmd, *args, opts], &block
        ensure
          ENV.replace old_env
        end
      elsif env.value? nil
        env = env.each_with_object ENV.to_h do |(key, val), accum|
          val.nil? ? (accum.delete key) : (accum[key] = val)
        end
        popen [env, cmd, *args, (opts.merge unsetenv_others: true)], &block
      else
        popen [env, cmd, *args, opts], &block
      end
    else
      popen [cmd, *args, opts], &block
    end
  end

  def popen args, &block
    # When block is passed to IO.popen, JRuby for Windows does not return value of block as return value
    if jruby? && windows?
      result = nil
      IO.popen args do |io|
        result = yield io
      end
      result
    else
      IO.popen args, &block
    end
  end

  def using_test_webserver host = resolve_localhost, port = 9876
    base_dir = testdir
    server = TCPServer.new host, port
    server_thread = Thread.start do
      while (session = server.accept)
        request = session.gets
        if /^GET (\S+) HTTP\/1\.1$/ =~ request.chomp
          resource = (resource = $1) == '' ? '.' : resource
        else
          session.print %(HTTP/1.1 405 Method Not Allowed\r\nContent-Type: text/plain\r\n\r\n)
          session.print %(405 - Method not allowed\n)
          session.close
          next
        end
        if resource == '/name/asciidoctor'
          session.print %(HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n)
          session.print %({"name": "asciidoctor"}\n)
        elsif File.file?(resource_file = (File.join base_dir, resource))
          mimetype = if (ext = File.extname(resource_file)[1..-1])
            ext == 'adoc' ? 'text/plain' : %(image/#{ext})
          else
            'text/plain'
          end
          session.print %(HTTP/1.1 200 OK\r\nContent-Type: #{mimetype}\r\n\r\n)
          File.open resource_file, Asciidoctor::FILE_READ_MODE do |fd|
            until fd.eof?
              buffer = fd.read 256
              session.write buffer
            end
          end
        else
          session.print %(HTTP/1.1 404 File Not Found\r\nContent-Type: text/plain\r\n\r\n)
          session.print %(404 - Resource not found.\n)
        end
        session.close
      end
    end
    begin
      yield
    ensure
      server_thread.exit
      server_thread.value
      server.close
    end
  end
end

###
#
# Context goodness provided by @citrusbyte's contest.
# See https://github.com/citrusbyte/contest
#
###

# Contest adds +teardown+, +test+ and +context+ as class methods, and the
# instance methods +setup+ and +teardown+ now iterate on the corresponding
# blocks. Note that all setup and teardown blocks must be defined with the
# block syntax. Adding setup or teardown instance methods defeats the purpose
# of this library.
class Minitest::Test
  class << self
    def setup &block
      define_method :setup do
        super(&block)
        instance_eval(&block)
      end
    end

    def teardown &block
      define_method :teardown do
        instance_eval(&block)
        super(&block)
      end
    end

    def context name, opts = {}, &block
      if opts.key? :if
        return unless opts[:if]
      elsif opts.key? :unless
        return if opts[:unless]
      end
      subclass = Class.new self
      remove_tests subclass
      subclass.class_eval(&block) if block_given?
      const_set (context_name name), subclass
    end

    def test name, opts = {}, &block
      if opts.key? :if
        return unless opts[:if]
      elsif opts.key? :unless
        return if opts[:unless]
      end
      define_method (test_name name), &block
    end

    def remove_tests subclass
      subclass.public_instance_methods.each do |m|
        subclass.send :undef_method, m if m.to_s.start_with? 'test_'
      end
    end

    alias should test
    alias describe context

    private

    def context_name name
      %(Test#{(sanitize_name name).gsub(/(^| )(\w)/) { $2.upcase }}).to_sym
    end

    def test_name name
      %(test_#{(sanitize_name name).gsub %r/\s+/, '_'}).to_sym
    end

    def sanitize_name name
      (name.gsub %r/\W+/, ' ').strip
    end
  end
end

def context name, &block
  Minitest::Test.context name, &block
end
