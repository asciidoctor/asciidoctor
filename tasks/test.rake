# frozen_string_literal: true
def prepare_test_env
  # rather than hardcoding gc settings in test task,
  # could use https://gist.github.com/benders/788695
  ENV['RUBY_GC_MALLOC_LIMIT'] = 128_000_000.to_s
  ENV['RUBY_GC_OLDMALLOC_LIMIT'] = 128_000_000.to_s
  ENV['RUBY_GC_HEAP_INIT_SLOTS'] = 750_000.to_s
  ENV['RUBY_GC_HEAP_FREE_SLOTS'] = 750_000.to_s
  ENV['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] = 50_000.to_s
  ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] = 2.to_s
end

begin
  require 'rake/testtask'
  Rake::TestTask.new :test do |t|
    prepare_test_env
    puts %(LANG: #{ENV['LANG']}) if ENV['CI']
    t.libs << 'test'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = true
    t.warning = true
  end
rescue LoadError
  warn $!.message
end

namespace :test do
  desc 'Run unit and feature tests'
  task all: [:test, :features]
end
