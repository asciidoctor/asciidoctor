# -*- encoding: utf-8 -*-
# stub: yard-tomdoc 0.7.1 ruby lib

Gem::Specification.new do |s|
  s.name = "yard-tomdoc".freeze
  s.version = "0.7.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Trans".freeze, "Loren Segal".freeze]
  s.date = "2013-02-16"
  s.description = "Use TomDoc documentation format with YARD.".freeze
  s.email = ["transfire@gmail.com".freeze]
  s.extra_rdoc_files = ["LICENSE.txt".freeze, "HISTORY.md".freeze, "README.md".freeze]
  s.files = ["HISTORY.md".freeze, "LICENSE.txt".freeze, "README.md".freeze]
  s.homepage = "http://rubyworks.github.com/yard-tomdoc".freeze
  s.licenses = ["MIT".freeze, "MIT".freeze]
  s.rubygems_version = "2.7.8".freeze
  s.summary = "TomDoc for YARD".freeze

  s.installed_by_version = "2.7.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<yard>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<tomparse>.freeze, [">= 0.4.0"])
      s.add_development_dependency(%q<detroit>.freeze, [">= 0"])
      s.add_development_dependency(%q<dotopts>.freeze, [">= 0"])
      s.add_development_dependency(%q<spectroscope>.freeze, [">= 0"])
      s.add_development_dependency(%q<ae>.freeze, [">= 0"])
    else
      s.add_dependency(%q<yard>.freeze, [">= 0"])
      s.add_dependency(%q<tomparse>.freeze, [">= 0.4.0"])
      s.add_dependency(%q<detroit>.freeze, [">= 0"])
      s.add_dependency(%q<dotopts>.freeze, [">= 0"])
      s.add_dependency(%q<spectroscope>.freeze, [">= 0"])
      s.add_dependency(%q<ae>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<tomparse>.freeze, [">= 0.4.0"])
    s.add_dependency(%q<detroit>.freeze, [">= 0"])
    s.add_dependency(%q<dotopts>.freeze, [">= 0"])
    s.add_dependency(%q<spectroscope>.freeze, [">= 0"])
    s.add_dependency(%q<ae>.freeze, [">= 0"])
  end
end
