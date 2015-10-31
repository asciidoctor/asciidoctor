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
  Rake::TestTask.new(:test) do |test|
    prepare_test_env
    puts %(LANG: #{ENV['LANG']}) if ENV.key? 'TRAVIS_BUILD_ID'
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
    test.warning = true
  end
  task :default => :test
rescue LoadError
end

=begin
# Run tests with Encoding.default_external set to US-ASCII
begin
  Rake::TestTask.new(:test_us_ascii) do |test|
    prepare_test_env
    puts "LANG: #{ENV['LANG']}"
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.ruby_opts << '-EUS-ASCII' if RUBY_VERSION >= '1.9'
    test.verbose = true
    test.warning = true
  end
rescue LoadError
end
=end

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features) do |t|
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
  task :all => [:test,:features]
end

=begin
begin
  require 'rdoc/task'
  RDoc::Task.new do |rdoc|
    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "Asciidoctor #{Asciidoctor::VERSION}"
    rdoc.markup = 'tomdoc' if rdoc.respond_to?(:markup)
    rdoc.rdoc_files.include('LICENSE.adoc', 'lib/**/*.rb')
  end
rescue LoadError
end
=end

begin
  require 'yard'
  require 'yard-tomdoc'
  require './lib/asciidoctor'
  require './lib/asciidoctor/extensions'

  # Prevent YARD from breaking command statements in literal paragraphs
  class CommandBlockPostprocessor < Asciidoctor::Extensions::Postprocessor
    def process document, output
      output.gsub(/<pre>\$ (.+?)<\/pre>/m, '<pre class="command code"><span class="const">$</span> \1</pre>')
    end
  end
  Asciidoctor::Extensions.register do
    postprocessor CommandBlockPostprocessor
  end

  # register .adoc extension for AsciiDoc markup helper
  YARD::Templates::Helpers::MarkupHelper::MARKUP_EXTENSIONS[:asciidoc] = %w(adoc)
  YARD::Rake::YardocTask.new do |yard|
    yard.files = %w(
        lib/**/*.rb
        -
        CHANGELOG.adoc
        LICENSE.adoc
    )
    # --no-highlight enabled to prevent verbatim blocks in AsciiDoc that begin with $ from being dropped
    # need to patch htmlify method to not attempt to syntax highlight blocks (or fix what's wrong)
    yard.options = (IO.readlines '.yardopts').map {|l| l.chomp.delete('"').split ' ', 2 }.flatten
  end
rescue LoadError
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
