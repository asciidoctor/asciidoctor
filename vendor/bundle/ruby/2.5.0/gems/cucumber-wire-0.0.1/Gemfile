gemspec

source "https://rubygems.org"
unless ENV['CUCUMBER_USE_RELEASED_GEMS']
  # cucumber gem
  cucumber_path = File.expand_path("../../cucumber-ruby", __FILE__)
  if File.exist?(cucumber_path) && !ENV['CUCUMBER_USE_GIT']
    gem "cucumber", path: cucumber_path, branch: "remove-wire-protocol-to-plugin"
  else
    gem "cucumber", :git => "git://github.com/cucumber/cucumber-ruby.git", branch: "remove-wire-protocol-to-plugin"
  end

  # cucumber-core gem
  core_path = File.expand_path("../../cucumber-ruby-core", __FILE__)
  if File.exist?(core_path) && !ENV['CUCUMBER_USE_GIT_CORE']
    gem "cucumber-core", path: core_path
  else
    gem 'cucumber-core', :git => "git://github.com/cucumber/cucumber-ruby-core.git"
  end
end
