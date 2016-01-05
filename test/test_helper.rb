# encoding: UTF-8
ASCIIDOCTOR_PROJECT_DIR = File.dirname File.dirname(__FILE__)
Dir.chdir ASCIIDOCTOR_PROJECT_DIR

if RUBY_VERSION < '1.9'
  require 'rubygems'
end

require 'simplecov' if ENV['COVERAGE'] == 'true'

require File.join(ASCIIDOCTOR_PROJECT_DIR, 'lib', 'asciidoctor')

require 'socket'
require 'nokogiri'
require 'tmpdir'

autoload :FileUtils, 'fileutils'
autoload :Pathname,  'pathname'

RE_XMLNS_ATTRIBUTE = / xmlns="[^"]+"/
RE_DOCTYPE = /\s*<!DOCTYPE (.*)/

require 'minitest/autorun'

# Minitest 4 doesn't have Minitest::Test
Minitest::Test = MiniTest::Unit::TestCase unless defined? Minitest::Test

class Minitest::Test
  def windows?
    RbConfig::CONFIG['host_os'] =~ /win|ming/
  end

  def disk_root
    "#{windows? ? File.expand_path(__FILE__).split('/').first : nil}/"
  end

  def empty_document options = {}
    if options[:parse]
      (Asciidoctor::Document.new [], options).parse
    else
      Asciidoctor::Document.new [], options
    end
  end

  def empty_safe_document options = {}
    options[:safe] = :safe
    Asciidoctor::Document.new [], options
  end

  def sample_doc_path(name)
    name = name.to_s
    unless name.include?('.')
      ['asciidoc', 'txt'].each do |ext|
        if File.exist?(fixture_path("#{name}.#{ext}"))
          name = "#{name}.#{ext}"
          break
        end
      end
    end
    fixture_path(name)
  end

  def fixture_path(name)
    File.join(File.expand_path(File.dirname(__FILE__)), 'fixtures', name)
  end

  def example_document(name, opts = {})
    document_from_string File.read(sample_doc_path(name)), opts
  end

  def assert_difference(expression, difference = 1, message = nil, &block)
    expressions = [expression]

    exps = expressions.map { |e|
      e.respond_to?(:call) ? e : lambda { eval(e, block.binding) }
    }
    before = exps.map { |e| e.call }

    yield

    expressions.zip(exps).each_with_index do |(code, e), i|
      error  = "#{code.inspect} didn't change by #{difference}"
      error  = "#{message}.\n#{error}" if message
      assert_equal(before[i] + difference, e.call, error)
    end
  end

  def xmlnodes_at_css(css, content, count = nil)
    xmlnodes_at_path(:css, css, content)
  end

  def xmlnodes_at_xpath(xpath, content, count = nil)
    xmlnodes_at_path(:xpath, xpath, content)
  end

  def xmlnodes_at_path(type, path, content, count = nil)
    doc = xmldoc_from_string content
    case type
      when :xpath
        namespaces = doc.respond_to?(:root) ? doc.root.namespaces : {}
        results = doc.xpath("#{path.sub('/', './')}", namespaces)
      when :css
        results = doc.css(path)
    end
    count == 1 ? results.first : results
  end

  # Generate an xpath attribute matcher that matches a name in the class attribute
  def contains_class(name)
    %(contains(concat(' ', normalize-space(@class), ' '), ' #{name} '))
  end

  def assert_css(css, content, count = nil)
    assert_path(:css, css, content, count)
  end

  def assert_xpath(xpath, content, count = nil)
    assert_path(:xpath, xpath, content, count)
  end

  def assert_path(type, path, content, count = nil)
    case type
    when :xpath
      type_name = 'XPath'
    when :css
      type_name = 'CSS'
    end

    results = xmlnodes_at_path type, path, content

    if (count == true || count == false)
      if (count != results)
        flunk "#{type_name} #{path} yielded #{results} rather than #{count} for:\n#{content}"
      else
        assert true
      end
    elsif (count && results.length != count)
      flunk "#{type_name} #{path} yielded #{results.length} elements rather than #{count} for:\n#{content}"
    elsif (count.nil? && results.empty?)
      flunk "#{type_name} #{path} not found in:\n#{content}"
    else
      assert true
    end
  end

  def xmldoc_from_string(content)
    if content.match(RE_XMLNS_ATTRIBUTE)
      doc = Nokogiri::XML::Document.parse(content)
    elsif !(doctype_match = content.match(RE_DOCTYPE))
      doc = Nokogiri::HTML::DocumentFragment.parse(content)
    elsif doctype_match[1].start_with? 'html'
      doc = Nokogiri::HTML::Document.parse(content)
    else
      doc = Nokogiri::XML::Document.parse(content)
    end
  end

  def document_from_string(src, opts = {})
    assign_default_test_options opts
    if opts[:parse]
      (Asciidoctor::Document.new src.lines.entries, opts).parse
    else
      Asciidoctor::Document.new src.lines.entries, opts
    end
  end

  def block_from_string(src, opts = {})
    opts[:header_footer] = false
    doc = document_from_string src, opts
    doc.blocks.first
  end

  def render_string(src, opts = {})
    keep_namespaces = opts.delete(:keep_namespaces)
    if keep_namespaces
      document_from_string(src, opts).render
    else
      # this is required because nokogiri is ignorant
      result = document_from_string(src, opts).render
      result = result.sub(RE_XMLNS_ATTRIBUTE, '') if result
      result
    end
  end

  def render_embedded_string(src, opts = {})
    opts[:header_footer] = false
    document_from_string(src, opts).render
  end

  def parse_header_metadata(source)
    reader = Asciidoctor::Reader.new source.split ::Asciidoctor::EOL
    [::Asciidoctor::Parser.parse_header_metadata(reader), reader]
  end

  def assign_default_test_options(opts)
    opts[:header_footer] = true unless opts.key? :header_footer
    opts[:parse] = true unless opts.key? :parse
    if opts[:header_footer]
      # don't embed stylesheet unless test requests the default behavior
      if opts.has_key? :linkcss_default
        opts.delete(:linkcss_default)
      else
        opts[:attributes] ||= {}
        opts[:attributes]['linkcss'] = ''
      end
    end
    if (template_dir = ENV['TEMPLATE_DIR'])
      opts[:template_dir] = template_dir unless opts.has_key? :template_dir
      #opts[:template_dir] = File.join(File.dirname(__FILE__), '..', '..', 'asciidoctor-backends', 'erb') unless opts.has_key? :template_dir
    end
    nil
  end

  # Expand the character for an entity such as &#8212; into a glyph
  # so it can be used to match in an XPath expression
  #
  # Examples
  #
  #   expand_entity 60
  #   # => "<"
  #
  # Returns the String entity expanded to its equivalent UTF-8 glyph
  def expand_entity(number)
    [number].pack('U*')
  end
  alias :entity :expand_entity

  def invoke_cli_with_filenames(argv = [], filenames = [], &block)

    filepaths = Array.new

    filenames.each { |filename|
      if filenames.nil?|| ::Pathname.new(filename).absolute?
        filepaths.push(filename)
      else
        filepaths.push(File.join(File.dirname(__FILE__), 'fixtures', filename))
      end
    }

    invoker = Asciidoctor::Cli::Invoker.new(argv + filepaths)

    invoker.invoke!(&block)
    invoker
  end

  def invoke_cli_to_buffer(argv = [], filename = 'sample.asciidoc', &block)
    invoke_cli(argv, filename, [StringIO.new, StringIO.new], &block)
  end

  def invoke_cli(argv = [], filename = 'sample.asciidoc', buffers = nil, &block)
    if filename.nil? || filename == '-' || ::Pathname.new(filename).absolute?
      filepath = filename
    else
      filepath = File.join(File.dirname(__FILE__), 'fixtures', filename)
    end
    invoker = Asciidoctor::Cli::Invoker.new(argv + [filepath])
    if buffers
      invoker.redirect_streams(*buffers)
    end
    invoker.invoke!(&block)
    invoker
  end

  def redirect_streams
    old_stdout, $stdout = $stdout, (tmp_stdout = ::StringIO.new)
    old_stderr, $stderr = $stderr, (tmp_stderr = ::StringIO.new)
    begin
      yield tmp_stdout, tmp_stderr
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end
  end

  def resolve_localhost
    (RUBY_VERSION < '1.9' || RUBY_ENGINE == 'rbx') ? Socket.gethostname :
        Socket.ip_address_list.find {|addr| addr.ipv4? }.ip_address
  end

  def using_test_webserver host = resolve_localhost, port = 9876
    server = TCPServer.new host, port
    base_dir = File.expand_path File.dirname __FILE__
    t = Thread.new do
      while (session = server.accept)
        request = session.gets
        resource = nil
        if (m = /GET (\S+) HTTP\/1\.1$/.match(request.chomp))
          resource = (resource = m[1]) == '' ? '.' : resource
        else
          session.print %(HTTP/1.1 405 Method Not Allowed\r\nContent-Type: text/plain\r\n\r\n)
          session.print %(405 - Method not allowed\n)
          session.close
          break
        end

        if resource == '/name/asciidoctor'
          session.print %(HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n)
          session.print %({"name": "asciidoctor"}\n)
        elsif File.file?(resource_file = (File.join base_dir, resource))
          mimetype = if (ext = ::File.extname(resource_file)[1..-1])
            ext == 'adoc' ? 'text/plain' : %(image/#{ext})
          else
            'text/plain'
          end
          session.print %(HTTP/1.1 200 OK\r\nContent-Type: #{mimetype}\r\n\r\n)
          File.open resource_file, 'rb' do |fd|
            until fd.eof? do
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
      begin
        server.shutdown
      # "Errno::ENOTCONN: Socket is not connected' is reported on some platforms; call #close instead of #shutdown
      rescue Errno::ENOTCONN
        server.close
      end
      t.exit
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
  def self.setup(&block)
    define_method :setup do
      super(&block)
      instance_eval(&block)
    end
  end

  def self.teardown(&block)
    define_method :teardown do
      instance_eval(&block)
      super(&block)
    end
  end

  def self.context(*name, &block)
    subclass = Class.new(self)
    remove_tests(subclass)
    subclass.class_eval(&block) if block_given?
    const_set(context_name(name.join(" ")), subclass)
  end

  def self.test(name, &block)
    define_method(test_name(name), &block)
  end

  class << self
    alias_method :should, :test
    alias_method :describe, :context
  end

private

  def self.context_name(name)
    "Test#{sanitize_name(name).gsub(/(^| )(\w)/) { $2.upcase }}".to_sym
  end

  def self.test_name(name)
    "test_#{sanitize_name(name).gsub(/\s+/,'_')}".to_sym
  end

  def self.sanitize_name(name)
    name.gsub(/\W+/, ' ').strip
  end

  def self.remove_tests(subclass)
    subclass.public_instance_methods.grep(/^test_/).each do |meth|
      subclass.send(:undef_method, meth.to_sym)
    end
  end
end

def context(*name, &block)
  Minitest::Test.context(name, &block)
end
