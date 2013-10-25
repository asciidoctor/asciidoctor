require File.expand_path '../lib/asciidoctor/version', __FILE__

def prepare_test_env
  # rather than hardcoding gc settings in test task,
  # could use https://gist.github.com/benders/788695
  ENV['RUBY_GC_MALLOC_LIMIT'] = '90000000'
  ENV['RUBY_FREE_MIN'] = '200000'
end

begin
  require 'rake/testtask'
  Rake::TestTask.new(:test) do |test|
    prepare_test_env
    puts "LANG: #{ENV['LANG']}"
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
    test.warning = true
  end
  task :default => :test
rescue LoadError
end

=begin
# Run tests with Encoding::default_external set to US-ASCII
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

begin
  require 'rdoc/task'
  RDoc::Task.new do |rdoc|
    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "Asciidoctor #{Asciidoctor::VERSION}"
    rdoc.markup = 'tomdoc' if rdoc.respond_to?(:markup)
    #rdoc.rdoc_files.include('CHANGELOG', 'LICENSE', 'README.adoc', 'lib/**/*.rb')
    rdoc.rdoc_files.include('LICENSE', 'lib/**/*.rb')
  end
rescue LoadError
end

begin
  require 'bundler/gem_tasks'

  # Enhance the release task to create an explicit commit for the release
  Rake::Task[:release].enhance [:commit_release]

  task :commit_release do
    Bundler::GemHelper.new.send(:guard_clean)
    sh "git commit --allow-empty -a -m 'Release #{Asciidoctor::VERSION}'"
  end
rescue LoadError
end

desc 'Open an irb session preloaded with this library'
task :console do
  sh "bundle console", :verbose => false
end
