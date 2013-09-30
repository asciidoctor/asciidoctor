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

  s.files             = `git ls-files -z -- */* {CHANGELOG,LICENSE,README,Rakefile}*`.split "\0"
  s.executables       = s.files.grep(/^bin\//) { |f| File.basename f }
  s.test_files        = s.files.grep /^test\/.*_test\.rb$/
  s.require_paths     = %w[lib]

  s.has_rdoc          = true
  s.rdoc_options      = ['--charset=UTF-8']
  #s.extra_rdoc_files  = %w[CHANGELOG.adoc LICENSE README.adoc]
  s.extra_rdoc_files  = %w[LICENSE]

  # erubis is needed for testing use of alternative eRuby impls
  # tilt, slim and haml are needed for testing custom templates
  # coderay is needed for testing syntax highlighting
  s.add_development_dependency 'coderay'
  s.add_development_dependency 'erubis'
  s.add_development_dependency 'haml'
  s.add_development_dependency 'nokogiri', '~> 1.5.10'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc', '~> 3.12'
  s.add_development_dependency 'slim'
  s.add_development_dependency 'tilt'
end
