# -*- encoding: utf-8 -*-
# stub: tomparse 0.4.2 ruby lib

Gem::Specification.new do |s|
  s.name = "tomparse".freeze
  s.version = "0.4.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["trans".freeze]
  s.date = "2013-02-15"
  s.description = "TomParse provides no other functionality than to take a code comment\nand parse it in to a convenient object-oriented structure in accordance\nwith TomDoc standard.".freeze
  s.email = ["transfire@gmail.com".freeze]
  s.extra_rdoc_files = ["LICENSE.txt".freeze, "HISTORY.md".freeze, "README.md".freeze]
  s.files = ["HISTORY.md".freeze, "LICENSE.txt".freeze, "README.md".freeze]
  s.homepage = "http://rubyworks.github.com/tomparse".freeze
  s.licenses = ["BSD-2-Clause".freeze]
  s.rubygems_version = "2.7.8".freeze
  s.summary = "TomDoc parser for Ruby".freeze

  s.installed_by_version = "2.7.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<citron>.freeze, [">= 0"])
      s.add_development_dependency(%q<ae>.freeze, [">= 0"])
      s.add_development_dependency(%q<detroit>.freeze, [">= 0"])
    else
      s.add_dependency(%q<citron>.freeze, [">= 0"])
      s.add_dependency(%q<ae>.freeze, [">= 0"])
      s.add_dependency(%q<detroit>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<citron>.freeze, [">= 0"])
    s.add_dependency(%q<ae>.freeze, [">= 0"])
    s.add_dependency(%q<detroit>.freeze, [">= 0"])
  end
end
