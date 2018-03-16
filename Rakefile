require File.expand_path '../lib/asciidoctor/version', __FILE__

def prepare_test_env
  # rather than hardcoding gc settings in test task,
  # could use https://gist.github.com/benders/788695
  ENV['RUBY_GC_MALLOC_LIMIT'] = 128_000_000.to_s
  ENV['RUBY_GC_OLDMALLOC_LIMIT'] = 128_000_000.to_s
  if RUBY_VERSION >= '2.1'
    ENV['RUBY_GC_HEAP_INIT_SLOTS'] = 800_000.to_s
    ENV['RUBY_GC_HEAP_FREE_SLOTS'] = 800_000.to_s
    ENV['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] = 250_000.to_s
    ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] = 1.25.to_s
  else
    ENV['RUBY_FREE_MIN'] = 800_000.to_s
  end
end

begin
  require 'rake/testtask'
  Rake::TestTask.new(:test) do |t|
    prepare_test_env
    puts %(LANG: #{ENV['LANG']}) if ENV.key? 'TRAVIS_BUILD_ID'
    t.libs << 'test'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = true
    t.warning = true
  end
  task :default => 'test:all'
rescue LoadError
end

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features) do |t|
    t.cucumber_opts = %w(-f progress)
  end
rescue LoadError
end

def ci_setup_tasks
  tasks = []
  begin
    require 'ci/reporter/rake/minitest'
    tasks << 'ci:setup:minitest'
    # FIXME reporter for Cucumber tests not activating
    #require 'ci/reporter/rake/cucumber'
    #tasks << 'ci:setup:cucumber'
  rescue LoadError
  end if ENV['SHIPPABLE'] && RUBY_VERSION >= '1.9.3'
  tasks
end

desc 'Activates coverage and JUnit-style XML reports for tests'
task :coverage => ci_setup_tasks do
  # exclude coverage run for Ruby 1.8.7 or (disabled) if running on Travis CI
  ENV['COVERAGE'] = 'true' if RUBY_VERSION >= '1.9.3' # && (ENV['SHIPPABLE'] || !ENV['TRAVIS_BUILD_ID'])
  ENV['CI_REPORTS'] = 'shippable/testresults'
  ENV['COVERAGE_REPORTS'] = 'shippable/codecoverage'
end

namespace :test do
  desc 'Run unit and feature tests'
  task :all => [:test, :features]
end

begin
  require 'bundler/gem_tasks'

  # Enhance the release task to create an explicit commit for the release
  #Rake::Task[:release].enhance [:commit_release]

  # NOTE you don't need to push after updating version and committing locally
  # WARNING no longer works; it's now necessary to get master in a state ready for tagging
  task :commit_release do
    Bundler::GemHelper.new.send(:guard_clean)
    sh "git commit --allow-empty -a -m 'Release #{Asciidoctor::VERSION}'"
  end
rescue LoadError
end

desc 'Open an irb session preloaded with this library'
task :console do
  sh 'bundle console', :verbose => false
end
