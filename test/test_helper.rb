require 'fileutils'
require 'test/unit'

require "#{File.expand_path(File.dirname(__FILE__))}/../lib/waldo.rb"

require 'mocha'
require 'htmlentities'
require 'nokogiri'

class Test::Unit::TestCase
  def sample_file_path(name)
    name = name.to_s
    File.join(File.dirname(__FILE__), "fixtures", "files", (name.include?(".") ? name : "#{name}.#{name}"))
  end

  def sample_doc_path(name)
    name = name.to_s
    File.join(File.dirname(__FILE__), "fixtures", (name.include?(".") ? name : "#{name}.txt"))
  end

  def example_document(name)
    Asciidoc::Document.new(File.readlines(sample_doc_path(name)))
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

  def assert_xpath(xpath, html)
    if Nokogiri::HTML::DocumentFragment.parse(html).xpath(".#{xpath}").empty?
      fail "XPath #{xpath} not found in:\n#{html}"
    else
      assert true
    end
  end

  def render_string(src)
    Asciidoc::Document.new(src.split("\n")).render
  end
end

##
# test/spec/mini 5
# http://gist.github.com/307649
# chris@ozmm.org
#
def context(*args, &block)
  return super unless (name = args.first) && block

  klass = Class.new(Test::Unit::TestCase) do
    def self.test(name, &block)
      define_method("test_#{name.to_s.gsub(/\W/,'_')}", &block) if block
    end
    def self.xtest(*args) end
    def self.context(*args, &block) instance_eval(&block) end
    def self.setup(&block)
      define_method(:setup) { self.class.setups.each { |s| instance_eval(&s) } }
      setups << block
    end
    def self.setups; @setups ||= [] end
    def self.teardown(&block) define_method(:teardown, &block) end
  end

  (class << klass; self end).send(:define_method, :name) { name.gsub(/\W/,'_') }
  
  klass.class_eval &block
end
