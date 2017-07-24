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
    yard.options = (IO.readlines '.yardopts').map {|l| l.chomp.delete('"').split ' ', 2 }.flatten if ::File.file? '.yardopts'
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

namespace :build do
desc 'Trigger builds for all dependent projects on Travis CI'
  task :dependents do
    if ENV['TRAVIS'].to_s == 'true'
      next unless ENV['TRAVIS_PULL_REQUEST'].to_s == 'false' &&
          ENV['TRAVIS_TAG'].to_s.empty? &&
          (ENV['TRAVIS_JOB_NUMBER'].to_s.end_with? '.1')
    end
    next unless (token = ENV['TRAVIS_TOKEN'])
    require 'net/http'
    %w(
      asciidoctor/asciidoctor.js
      asciidoctor/asciidoctorj
      asciidoctor/asciidoctorj/asciidoctorj-1.6.0
      asciidoctor/asciidoctor-diagram
    ).each do |project|
      org, name, branch = project.split '/', 3
      branch ||= 'master'
      header = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Travis-API-Version' => '3',
        'Authorization' => %(token #{token})
      }
      if (commit_hash = ENV['TRAVIS_COMMIT'])
        commit_memo = %( (#{commit_hash.slice 0, 8})\\n\\nhttps://github.com/#{ENV['TRAVIS_REPO_SLUG'] || 'asciidoctor/asciidoctor'}/commit/#{commit_hash})
      end
      payload = %({ "request": { "branch": "#{branch}", "message": "Build triggered by Asciidoctor#{commit_memo}" } })
      (http = Net::HTTP.new 'api.travis-ci.org', 443).use_ssl = true
      request = Net::HTTP::Post.new %(/repo/#{org}%2F#{name}/requests), header
      request.body = payload
      response = http.request request
      if response.code == '202'
        puts %(Successfully triggered build on #{project} repository)
      else
        warn %(Unable to trigger build on #{project} repository: #{response.code} - #{response.message})
      end
    end
  end
end
