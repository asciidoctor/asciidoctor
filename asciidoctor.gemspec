# encoding: UTF-8
begin
  require File.expand_path '../lib/asciidoctor/version', __FILE__
rescue LoadError
  require 'asciidoctor/version'
end

require 'open3' unless defined? Open3

Gem::Specification.new do |s|
  s.name = 'asciidoctor'
  s.version = Asciidoctor::VERSION
  s.summary = 'An implementation of the AsciiDoc text processor and publishing toolchain in Ruby'
  s.description = 'A fast, open source text processor and publishing toolchain, written in Ruby, for converting AsciiDoc content to HTML5, DocBook 5 (or 4.5) and other formats.'
  s.authors = ['Dan Allen', 'Sarah White', 'Ryan Waldron', 'Jason Porter', 'Nick Hengeveld', 'Jeremy McAnally']
  s.email = ['dan.j.allen@gmail.com']
  s.homepage = 'http://asciidoctor.org'
  s.license = 'MIT'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/asciidoctor/asciidoctor/issues',
    'changelog_uri' => 'https://github.com/asciidoctor/asciidoctor/blob/master/CHANGELOG.adoc',
    'mailing_list_uri' => 'http://discuss.asciidoctor.org',
    'source_code_uri' => 'https://github.com/asciidoctor/asciidoctor'
  }

  files = begin
    (result = Open3.popen3('git ls-files -z') {|_, out| out.read }.split %(\0)).empty? ? Dir['**/*'] : result
  rescue
    Dir['**/*']
  end
  s.files = files.grep(/^(?:(?:data|lib|man)\/.+|Gemfile|Rakefile|LICENSE|(?:CHANGELOG|CONTRIBUTING|README(?:-\w+)?)\.adoc|#{s.name}\.gemspec)$/)
  s.executables = files.grep(/^bin\//).map {|f| File.basename f }
  s.require_paths = ['lib']
  s.test_files = files.grep(/^(?:(?:features|test)\/.+)$/)
  s.has_rdoc = true
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['CHANGELOG.adoc', 'CONTRIBUTING.adoc', 'LICENSE']

  # asciimath is needed for testing AsciiMath in DocBook backend
  s.add_development_dependency 'asciimath', '~> 1.0.0'
  # coderay is needed for testing syntax highlighting
  s.add_development_dependency 'coderay', '~> 1.1.0'
  s.add_development_dependency 'cucumber', '~> 2.4.0'
  # erubis is needed for testing use of alternative eRuby impls
  s.add_development_dependency 'erubis', '~> 2.7.0'
  # haml is needed for testing custom templates
  s.add_development_dependency 'haml', '~> 5.0.0'
  s.add_development_dependency 'nokogiri', '~> 1.8.0'
  s.add_development_dependency 'rake', '~> 10.0.0'
  s.add_development_dependency 'rspec-expectations', '~> 2.14.0'
  # slim is needed for testing custom templates
  s.add_development_dependency 'slim', '~> 3.0.0'
  s.add_development_dependency 'thread_safe', '~> 0.3.0'
  # tilt is needed for testing custom templates
  s.add_development_dependency 'tilt', '~> 2.0.0'
  s.add_development_dependency 'minitest', '~> 5.3.0'
end
