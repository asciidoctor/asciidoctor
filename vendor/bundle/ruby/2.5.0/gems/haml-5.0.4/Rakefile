require "rake/clean"
require "rake/testtask"
require "bundler/gem_tasks"

task :default => :test

# FIXME: Redefining :test task to run test/options_test.rb in isolated process since it depends on whether Rails is loaded or not.
# Remove this task when we finished changing escape_html option to be true by default.
isolated_test = Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = %w[test/options_test.rb]
  t.warning = true
  t.verbose = true
end
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = Dir['test/*_test.rb'] + Dir['test/haml-spec/*_test.rb'] - isolated_test.file_list
  t.warning = true
  t.verbose = true
end

CLEAN.replace %w(pkg doc coverage .yardoc test/haml vendor)

desc "Benchmark Haml against ERB. TIMES=n sets the number of runs, default is 1000."
task :benchmark do
  sh "ruby benchmark.rb #{ENV['TIMES']}"
end

task :set_coverage_env do
  ENV["COVERAGE"] = "true"
end

desc "Run Simplecov"
task :coverage => [:set_coverage_env, :test]

task :submodules do
  if File.exist?(File.dirname(__FILE__) + "/.git")
    sh %{git submodule sync}
    sh %{git submodule update --init --recursive}
  end
end

namespace :doc do
  task :sass do
    require 'sass'
    Dir["yard/default/**/*.sass"].each do |sass|
      File.open(sass.gsub(/sass$/, 'css'), 'w') do |f|
        f.write(Sass::Engine.new(File.read(sass)).render)
      end
    end
  end

  desc "List all undocumented methods and classes."
  task :undocumented do
    command = 'yard --list --query '
    command << '"object.docstring.blank? && '
    command << '!(object.type == :method && object.is_alias?)"'
    sh command
  end
end

desc "Generate documentation"
task(:doc => 'doc:sass') {sh "yard"}

desc "Generate documentation incrementally"
task(:redoc) {sh "yard -c"}

desc <<END
Profile Haml.
  TIMES=n sets the number of runs. Defaults to 1000.
  FILE=str sets the file to profile. Defaults to 'standard'
  OUTPUT=str sets the ruby-prof output format.
    Can be Flat, CallInfo, or Graph. Defaults to Flat. Defaults to Flat.
END
task :profile do
  times  = (ENV['TIMES'] || '1000').to_i
  file   = ENV['FILE'] || 'test/templates/standard.haml'

  require 'bundler/setup'
  require 'ruby-prof'
  require 'haml'
  file = File.read(File.expand_path("../#{file}", __FILE__))
  obj = Object.new
  Haml::Engine.new(file).def_method(obj, :render)
  result = RubyProf.profile { times.times { obj.render } }

  RubyProf.const_get("#{(ENV['OUTPUT'] || 'Flat').capitalize}Printer").new(result).print
end

def gemfiles
  @gemfiles ||= begin
    Dir[File.dirname(__FILE__) + '/test/gemfiles/Gemfile.*'].
      reject {|f| f =~ /\.lock$/}.
      reject {|f| RUBY_VERSION < '1.9.3' && f =~ /Gemfile.rails-(\d+).\d+.x/ && $1.to_i > 3}
  end
end

def with_each_gemfile
  gemfiles.each do |gemfile|
    Bundler.with_clean_env do
      puts "Using gemfile: #{gemfile}"
      ENV['BUNDLE_GEMFILE'] = gemfile
      yield
    end
  end
end

namespace :test do
  namespace :bundles do
    desc "Install all dependencies necessary to test Haml."
    task :install do
      with_each_gemfile {sh "bundle"}
    end

    desc "Update all dependencies for testing Haml."
    task :update do
      with_each_gemfile {sh "bundle update"}
    end
  end

  desc "Test all supported versions of rails. This takes a while."
  task :rails_compatibility => 'test:bundles:install' do
    with_each_gemfile {sh "bundle exec rake test"}
  end
  task :rc => :rails_compatibility
end
