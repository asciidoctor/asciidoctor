# -*- encoding: utf-8 -*-
# stub: rake 10.0.4 ruby lib

Gem::Specification.new do |s|
  s.name = "rake".freeze
  s.version = "10.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.2".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jim Weirich".freeze]
  s.date = "2013-03-25"
  s.description = "Rake is a Make-like program implemented in Ruby. Tasks and dependencies arespecified in standard Ruby syntax.".freeze
  s.email = "jim@weirichhouse.org".freeze
  s.executables = ["rake".freeze]
  s.extra_rdoc_files = ["README.rdoc".freeze, "MIT-LICENSE".freeze, "TODO".freeze, "CHANGES".freeze, "doc/command_line_usage.rdoc".freeze, "doc/glossary.rdoc".freeze, "doc/proto_rake.rdoc".freeze, "doc/rakefile.rdoc".freeze, "doc/rational.rdoc".freeze, "doc/release_notes/rake-0.4.14.rdoc".freeze, "doc/release_notes/rake-0.4.15.rdoc".freeze, "doc/release_notes/rake-0.5.0.rdoc".freeze, "doc/release_notes/rake-0.5.3.rdoc".freeze, "doc/release_notes/rake-0.5.4.rdoc".freeze, "doc/release_notes/rake-0.6.0.rdoc".freeze, "doc/release_notes/rake-0.7.0.rdoc".freeze, "doc/release_notes/rake-0.7.1.rdoc".freeze, "doc/release_notes/rake-0.7.2.rdoc".freeze, "doc/release_notes/rake-0.7.3.rdoc".freeze, "doc/release_notes/rake-0.8.0.rdoc".freeze, "doc/release_notes/rake-0.8.2.rdoc".freeze, "doc/release_notes/rake-0.8.3.rdoc".freeze, "doc/release_notes/rake-0.8.4.rdoc".freeze, "doc/release_notes/rake-0.8.5.rdoc".freeze, "doc/release_notes/rake-0.8.6.rdoc".freeze, "doc/release_notes/rake-0.8.7.rdoc".freeze, "doc/release_notes/rake-0.9.0.rdoc".freeze, "doc/release_notes/rake-0.9.1.rdoc".freeze, "doc/release_notes/rake-0.9.2.2.rdoc".freeze, "doc/release_notes/rake-0.9.2.rdoc".freeze, "doc/release_notes/rake-0.9.3.rdoc".freeze, "doc/release_notes/rake-0.9.4.rdoc".freeze, "doc/release_notes/rake-0.9.5.rdoc".freeze, "doc/release_notes/rake-0.9.6.rdoc".freeze, "doc/release_notes/rake-10.0.0.rdoc".freeze, "doc/release_notes/rake-10.0.1.rdoc".freeze, "doc/release_notes/rake-10.0.2.rdoc".freeze, "doc/release_notes/rake-10.0.3.rdoc".freeze]
  s.files = ["CHANGES".freeze, "MIT-LICENSE".freeze, "README.rdoc".freeze, "TODO".freeze, "bin/rake".freeze, "doc/command_line_usage.rdoc".freeze, "doc/glossary.rdoc".freeze, "doc/proto_rake.rdoc".freeze, "doc/rakefile.rdoc".freeze, "doc/rational.rdoc".freeze, "doc/release_notes/rake-0.4.14.rdoc".freeze, "doc/release_notes/rake-0.4.15.rdoc".freeze, "doc/release_notes/rake-0.5.0.rdoc".freeze, "doc/release_notes/rake-0.5.3.rdoc".freeze, "doc/release_notes/rake-0.5.4.rdoc".freeze, "doc/release_notes/rake-0.6.0.rdoc".freeze, "doc/release_notes/rake-0.7.0.rdoc".freeze, "doc/release_notes/rake-0.7.1.rdoc".freeze, "doc/release_notes/rake-0.7.2.rdoc".freeze, "doc/release_notes/rake-0.7.3.rdoc".freeze, "doc/release_notes/rake-0.8.0.rdoc".freeze, "doc/release_notes/rake-0.8.2.rdoc".freeze, "doc/release_notes/rake-0.8.3.rdoc".freeze, "doc/release_notes/rake-0.8.4.rdoc".freeze, "doc/release_notes/rake-0.8.5.rdoc".freeze, "doc/release_notes/rake-0.8.6.rdoc".freeze, "doc/release_notes/rake-0.8.7.rdoc".freeze, "doc/release_notes/rake-0.9.0.rdoc".freeze, "doc/release_notes/rake-0.9.1.rdoc".freeze, "doc/release_notes/rake-0.9.2.2.rdoc".freeze, "doc/release_notes/rake-0.9.2.rdoc".freeze, "doc/release_notes/rake-0.9.3.rdoc".freeze, "doc/release_notes/rake-0.9.4.rdoc".freeze, "doc/release_notes/rake-0.9.5.rdoc".freeze, "doc/release_notes/rake-0.9.6.rdoc".freeze, "doc/release_notes/rake-10.0.0.rdoc".freeze, "doc/release_notes/rake-10.0.1.rdoc".freeze, "doc/release_notes/rake-10.0.2.rdoc".freeze, "doc/release_notes/rake-10.0.3.rdoc".freeze]
  s.homepage = "http://rake.rubyforge.org".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--line-numbers".freeze, "--show-hash".freeze, "--main".freeze, "README.rdoc".freeze, "--title".freeze, "Rake -- Ruby Make".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.6".freeze)
  s.rubyforge_project = "rake".freeze
  s.rubygems_version = "2.7.8".freeze
  s.summary = "Ruby based make-like utility.".freeze

  s.installed_by_version = "2.7.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>.freeze, ["~> 2.1"])
    else
      s.add_dependency(%q<minitest>.freeze, ["~> 2.1"])
    end
  else
    s.add_dependency(%q<minitest>.freeze, ["~> 2.1"])
  end
end
