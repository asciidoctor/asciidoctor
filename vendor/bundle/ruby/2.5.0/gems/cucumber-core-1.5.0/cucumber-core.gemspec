# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "cucumber/core/version"

Gem::Specification.new do |s|
  s.name        = 'cucumber-core'
  s.version     = Cucumber::Core::Version
  s.authors     = ["Aslak Hellesøy", "Matt Wynne", "Steve Tooke", "Oleg Sukhodolsky", "Tom Brand"]
  s.description = 'Core library for the Cucumber BDD app'
  s.summary     = "cucumber-core-#{s.version}"
  s.email       = 'cukes@googlegroups.com'
  s.homepage    = "http://cukes.info"
  s.platform    = Gem::Platform::RUBY
  s.license     = "MIT"
  s.required_ruby_version = ">= 1.9.3"

  s.add_dependency 'gherkin', '~> 4.0'

  s.add_development_dependency 'bundler',   '>= 1.3.5'
  s.add_development_dependency 'rake',      '>= 0.9.2'
  s.add_development_dependency 'rspec',     '~> 3'
  s.add_development_dependency 'unindent',  '>= 1.0'
  s.add_development_dependency 'kramdown',  '~> 1.4.2'

  # For coverage reports
  s.add_development_dependency 'coveralls', '~> 0.7'

  s.rubygems_version = ">= 1.6.1"
  s.files            = `git ls-files`.split("\n").reject {|path| path =~ /\.gitignore$/ }
  s.test_files       = `git ls-files -- spec/*`.split("\n")
  s.rdoc_options     = ["--charset=UTF-8"]
  s.require_path     = "lib"
end
