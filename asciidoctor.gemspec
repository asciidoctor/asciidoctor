# -*- encoding: utf-8 -*-
require File.expand_path '../lib/asciidoctor/version', __FILE__

Gem::Specification.new do |s|
  s.name              = 'asciidoctor'
  s.version           = Asciidoctor::VERSION
  s.rubyforge_project = s.name

  s.summary           = 'An implementation of the AsciiDoc text processor and publishing toolchain in Ruby'
  s.description       = <<-EOS
A fast, open source text processor and publishing toolchain, written in Ruby, for transforming AsciiDoc markup into HTML 5, DocBook 4.5, DocBook 5.0 and custom output formats.
  EOS

  s.authors           = ['Dan Allen', 'Sarah White', 'Ryan Waldron', 'Jason Porter', 'Nick Hengeveld', 'Jeremy McAnally']
  s.email             = ['dan.j.allen@gmail.com']
  s.homepage          = 'http://asciidoctor.org'
  s.license           = 'MIT'

  begin
  s.files             = `git ls-files -z -- */* {CHANGELOG,LICENSE,README,Rakefile}*`.split "\0"
  rescue
  s.files             = Dir['**/*']
  end
  #s.executables       = s.files.grep(/^bin\//) { |f| File.basename f }
  s.executables       = ['asciidoctor', 'asciidoctor-safe']
  s.test_files        = s.files.grep(/^(?:test\/.*_test\.rb|features\/.*\.(?:feature|rb))$/)
  s.require_paths     = %w(lib)

  s.has_rdoc          = true
  s.rdoc_options      = ['--charset=UTF-8']
  #s.extra_rdoc_files  = %w(CHANGELOG.adoc LICENSE README.adoc)
  s.extra_rdoc_files  = %w(LICENSE)

  # erubis is needed for testing use of alternative eRuby impls
  # tilt, slim and haml are needed for testing custom templates
  # coderay is needed for testing syntax highlighting
  s.add_development_dependency 'coderay', '~> 1.1.0'
  s.add_development_dependency 'cucumber', '~> 1.3.1'
  s.add_development_dependency 'erubis', '~> 2.7.0'
  s.add_development_dependency 'haml', '~> 4.0.0'
  s.add_development_dependency 'nokogiri', '~> 1.5.10'
  s.add_development_dependency 'rake', '~> 10.0.0'
  s.add_development_dependency 'rspec-expectations', '~> 2.14.0'
  s.add_development_dependency 'slim', '~> 2.0.0'
  s.add_development_dependency 'thread_safe', '~> 0.1.3'
  s.add_development_dependency 'tilt', '~> 2.0.0'
  s.add_development_dependency 'yard', '~> 0.8.7'
  s.add_development_dependency 'yard-tomdoc', '~> 0.7.0'
  s.add_development_dependency 'minitest', '~> 5.3.0'
  if RUBY_VERSION == '2.1.0' && RUBY_ENGINE == 'rbx'
    s.add_development_dependency 'racc', '~> 1.4.10'
  end
end
