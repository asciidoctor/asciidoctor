# -*- encoding: utf-8 -*-
# stub: haml 5.0.4 ruby lib

Gem::Specification.new do |s|
  s.name = "haml".freeze
  s.version = "5.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Natalie Weizenbaum".freeze, "Hampton Catlin".freeze, "Norman Clarke".freeze, "Akira Matsuda".freeze]
  s.date = "2017-10-13"
  s.description = "Haml (HTML Abstraction Markup Language) is a layer on top of HTML or XML that's\ndesigned to express the structure of documents in a non-repetitive, elegant, and\neasy way by using indentation rather than closing tags and allowing Ruby to be\nembedded with ease. It was originally envisioned as a plugin for Ruby on Rails,\nbut it can function as a stand-alone templating engine.\n".freeze
  s.email = ["haml@googlegroups.com".freeze, "norman@njclarke.com".freeze]
  s.executables = ["haml".freeze]
  s.files = ["bin/haml".freeze]
  s.homepage = "http://haml.info/".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "2.7.8".freeze
  s.summary = "An elegant, structured (X)HTML/XML templating engine.".freeze

  s.installed_by_version = "2.7.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<temple>.freeze, [">= 0.8.0"])
      s.add_runtime_dependency(%q<tilt>.freeze, [">= 0"])
      s.add_development_dependency(%q<rails>.freeze, [">= 4.0.0"])
      s.add_development_dependency(%q<rbench>.freeze, [">= 0"])
      s.add_development_dependency(%q<minitest>.freeze, [">= 4.0"])
      s.add_development_dependency(%q<nokogiri>.freeze, [">= 0"])
    else
      s.add_dependency(%q<temple>.freeze, [">= 0.8.0"])
      s.add_dependency(%q<tilt>.freeze, [">= 0"])
      s.add_dependency(%q<rails>.freeze, [">= 4.0.0"])
      s.add_dependency(%q<rbench>.freeze, [">= 0"])
      s.add_dependency(%q<minitest>.freeze, [">= 4.0"])
      s.add_dependency(%q<nokogiri>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<temple>.freeze, [">= 0.8.0"])
    s.add_dependency(%q<tilt>.freeze, [">= 0"])
    s.add_dependency(%q<rails>.freeze, [">= 4.0.0"])
    s.add_dependency(%q<rbench>.freeze, [">= 0"])
    s.add_dependency(%q<minitest>.freeze, [">= 4.0"])
    s.add_dependency(%q<nokogiri>.freeze, [">= 0"])
  end
end
