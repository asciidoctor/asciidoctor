require 'fileutils'
require 'test/unit'

require "#{File.expand_path(File.dirname(__FILE__))}/../lib/waldo.rb"

require 'mocha'
require 'htmlentities'

class Test::Unit::TestCase
  def sample_file_path(name)
    name = name.to_s
    File.join(File.dirname(__FILE__), "fixtures", "files", (name.include?(".") ? name : "#{name}.#{name}"))
  end

  def sample_doc_path(name)
    name = name.to_s
    File.join(File.dirname(__FILE__), "fixtures", (name.include?(".") ? name : "#{name}.txt"))
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
end

# test/spec/mini 3
# http://gist.github.com/25455
# chris@ozmm.org
# file:lib/test/spec/mini.rb
def context(*args, &block)
  return super unless (name = args.first) && block

  klass = Class.new(Test::Unit::TestCase) do
    def self.test(name, &block)
      define_method("test_#{name.gsub(/\W/,'_')}", &block) if block
    end

    def self.xtest(*args) end

    def self.setup(&block) define_method(:setup, &block) end

    def self.teardown(&block) define_method(:teardown, &block) end
  end

  (class << klass; self end).send(:define_method, :name) { name.gsub(/\W/,'_') }
  
  $contexts << klass
  
  klass.class_eval &block
end

$contexts = []
