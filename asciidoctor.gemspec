begin
  require_relative 'lib/asciidoctor/version'
rescue LoadError
  require 'asciidoctor/version'
end

Gem::Specification.new do |s|
  s.name = 'asciidoctor'
  s.version = Asciidoctor::VERSION
  s.summary = 'An implementation of the AsciiDoc text processor and publishing toolchain'
  s.description = 'A fast, open source text processor and publishing toolchain for converting AsciiDoc content to HTML 5, DocBook 5, and other formats.'
  s.authors = ['Dan Allen', 'Sarah White', 'Ryan Waldron', 'Jason Porter', 'Nick Hengeveld', 'Jeremy McAnally']
  s.email = ['dan.j.allen@gmail.com']
  s.homepage = 'https://asciidoctor.org'
  s.license = 'MIT'
  # NOTE required ruby version is informational only; it's not enforced since it can't be overridden and can cause builds to break
  #s.required_ruby_version = '>= 2.3.0'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/asciidoctor/asciidoctor/issues',
    'changelog_uri' => 'https://github.com/asciidoctor/asciidoctor/blob/HEAD/CHANGELOG.adoc',
    'mailing_list_uri' => 'https://chat.asciidoctor.org',
    'source_code_uri' => 'https://github.com/asciidoctor/asciidoctor'
  }

  # NOTE the logic to build the list of files is designed to produce a usable package even when the git command is not available
  begin
    files = (result = `git ls-files -z`.split ?\0).empty? ? Dir['**/*'] : result
  rescue
    files = Dir['**/*']
  end
  s.files = files.grep %r/^(?:(?:data|lib|man)\/.+|LICENSE|(?:CHANGELOG|README(?:-\w+)?)\.adoc|\.yardopts|#{s.name}\.gemspec)$/
  s.executables = (files.grep %r/^bin\//).map {|f| File.basename f }
  s.require_paths = ['lib']
  #s.test_files = files.grep %r/^(?:features|test)\/.+$/

  # concurrent-ruby, haml, slim, and tilt are needed for testing custom templates
  s.add_development_dependency 'concurrent-ruby', '~> 1.1.0'
  s.add_development_dependency 'cucumber', '~> 3.1.0'
  # erubi is needed for testing alternate eRuby impls
  s.add_development_dependency 'erubi', '~> 1.10.0'
  s.add_development_dependency 'haml', '~> 6.1.0'
  s.add_development_dependency 'minitest', '~> 5.14.0'
  s.add_development_dependency 'nokogiri', '~> 1.13.0'
  s.add_development_dependency 'rake', '~> 12.3.0'
  s.add_development_dependency 'slim', '~> 4.1.0'
  s.add_development_dependency 'tilt', '~> 2.0.0'
end
