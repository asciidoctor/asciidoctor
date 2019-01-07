begin
  require_relative 'lib/asciidoctor/version'
rescue LoadError
  require 'asciidoctor/version'
end

require 'open3' unless defined? Open3.popen3

Gem::Specification.new do |s|
  s.name = 'asciidoctor'
  s.version = Asciidoctor::VERSION
  s.summary = 'An implementation of the AsciiDoc text processor and publishing toolchain in Ruby'
  s.description = 'A fast, open source text processor and publishing toolchain, written in Ruby, for converting AsciiDoc content to HTML5, DocBook 5 (or 4.5) and other formats.'
  s.authors = ['Dan Allen', 'Sarah White', 'Ryan Waldron', 'Jason Porter', 'Nick Hengeveld', 'Jeremy McAnally']
  s.email = ['dan.j.allen@gmail.com']
  s.homepage = 'http://asciidoctor.org'
  s.license = 'MIT'
  # NOTE the required ruby version is informational only; we don't enforce it because it can't be overridden and can cause builds to break
  #s.required_ruby_version = '>= 2.3.0'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/asciidoctor/asciidoctor/issues',
    'changelog_uri' => 'https://github.com/asciidoctor/asciidoctor/blob/master/CHANGELOG.adoc',
    'mailing_list_uri' => 'http://discuss.asciidoctor.org',
    'source_code_uri' => 'https://github.com/asciidoctor/asciidoctor'
  }

  # NOTE the logic to build the list of files is designed to produce a usable package even when the git command is not available
  files = begin
    # NOTE popen3 is used instead of backticks to fail properly when used with JRuby
    (result = Open3.popen3('git ls-files -z') {|_, out| out.read }.split %(\0)).empty? ? Dir['**/*'] : result
  rescue
    Dir['**/*']
  end
  s.files = files.grep %r/^(?:(?:data|lib|man)\/.+|Gemfile|Rakefile|LICENSE|(?:CHANGELOG|CONTRIBUTING|README(?:-\w+)?)\.adoc|#{s.name}\.gemspec)$/
  s.executables = (files.grep %r/^bin\//).map {|f| File.basename f }
  s.require_paths = ['lib']
  s.test_files = files.grep %r/^(?:(?:features|test)\/.+)$/
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['CHANGELOG.adoc', 'CONTRIBUTING.adoc', 'LICENSE']

  # asciimath is needed for testing AsciiMath in DocBook backend
  s.add_development_dependency 'asciimath', '~> 1.0.0'
  # coderay is needed for testing syntax highlighting
  s.add_development_dependency 'coderay', '~> 1.1.0'
  # concurrent-ruby, haml, slim, and tilt are needed for testing custom templates
  s.add_development_dependency 'concurrent-ruby', '~> 1.1.0'
  s.add_development_dependency 'cucumber', '~> 3.1.0'
  # erubis is needed for testing alternate eRuby impls
  s.add_development_dependency 'erubis', '~> 2.7.0'
  s.add_development_dependency 'haml', '~> 5.0.0'
  s.add_development_dependency 'minitest', '~> 5.11.0'
  s.add_development_dependency 'nokogiri', '~> 1.10.0'
  s.add_development_dependency 'rake', '~> 12.3.0'
  s.add_development_dependency 'rspec-expectations', '~> 3.8.0'
  s.add_development_dependency 'slim', '~> 4.0.0'
  s.add_development_dependency 'tilt', '~> 2.0.0'
end
