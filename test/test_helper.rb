require 'fileutils'
require 'pathname'
require 'test/unit'

require "#{File.expand_path(File.dirname(__FILE__))}/../lib/asciidoctor.rb"

begin
  require 'mocha/setup'
rescue LoadError
  require 'mocha'
end
require 'htmlentities'
require 'nokogiri'
require 'pending'

ENV['SUPPRESS_DEBUG'] ||= 'true'

class Test::Unit::TestCase
  def windows?
    RbConfig::CONFIG['host_os'] =~ /win|ming/
  end

  def disk_root
    "#{windows? ? File.expand_path(__FILE__).split('/').first : nil}/"
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
    opts[:header_footer] = true unless opts.has_key?(:header_footer)
    Asciidoctor::Document.new(File.readlines(sample_doc_path(name)), opts)
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

  def xmlnodes_at_xpath(css, content, count = nil)
    xmlnodes_at_path(:xpath, css, content)
  end

  def xmlnodes_at_path(type, path, content, count = nil)
    doc = xmldoc_from_string content
    case type
      when :xpath
        results = doc.xpath("#{path.sub('/', './')}")
      when :css
        results = doc.css(path)
    end
    count == 1 ? results.first : results
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

    if (count && results.length != count)
      flunk "#{type_name} #{path} yielded #{results.length} elements rather than #{count} for:\n#{content}"
    elsif (count.nil? && results.empty?)
      flunk "#{type_name} #{path} not found in:\n#{content}"
    else
      assert true
    end
  end

  def xmldoc_from_string(content)
    match = content.match(/\s*<!DOCTYPE (.*)/)
    if !match
      doc = Nokogiri::HTML::DocumentFragment.parse(content)
    elsif match[1].start_with? 'html'
      doc = Nokogiri::HTML::Document.parse(content)
    else
      doc = Nokogiri::XML::Document.parse(content)
    end
  end

  def document_from_string(src, opts = {})
    opts[:header_footer] = true unless opts.has_key?(:header_footer)
    Asciidoctor::Document.new(src.lines.entries, opts)
  end

  def block_from_string(src, opts = {})
    opts[:header_footer] = false
    doc = Asciidoctor::Document.new(src.lines.entries, opts)
    doc.blocks.first
  end

  def render_string(src, opts = {})
    document_from_string(src, opts).render
  end

  def render_embedded_string(src, opts = {})
    opts[:header_footer] = false
    document_from_string(src, opts).render
  end

  def parse_header_metadata(source)
    reader = Asciidoctor::Reader.new source.lines.entries
    [Asciidoctor::Lexer.parse_header_metadata(reader), reader]
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
    old_stdout = $stdout
    old_stderr = $stderr
    stdout = StringIO.new
    stderr = StringIO.new
    $stdout = stdout
    $stderr = stderr
    begin
      yield(stdout, stderr)
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end
  end
end

###
# 
# Context goodness provided by @citrusbyte's contest
#
###

# Test::Unit loads a default test if the suite is empty, whose purpose is to
# fail. Since having empty contexts is a common practice, we decided to
# overwrite TestSuite#empty? in order to allow them. Having a failure when no
# tests have been defined seems counter-intuitive.
class Test::Unit::TestSuite
  def empty?
    false
  end
end

# Contest adds +teardown+, +test+ and +context+ as class methods, and the
# instance methods +setup+ and +teardown+ now iterate on the corresponding
# blocks. Note that all setup and teardown blocks must be defined with the
# block syntax. Adding setup or teardown instance methods defeats the purpose
# of this library.
class Test::Unit::TestCase
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
  Test::Unit::TestCase.context(name, &block)
end
