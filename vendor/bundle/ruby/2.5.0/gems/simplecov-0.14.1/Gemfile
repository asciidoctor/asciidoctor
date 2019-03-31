source "https://rubygems.org"

# Uncomment this to use local copy of simplecov-html in development when checked out
# gem 'simplecov-html', :path => ::File.dirname(__FILE__) + '/../simplecov-html'

# Uncomment this to use development version of html formatter from github
# gem 'simplecov-html', :github => 'colszowka/simplecov-html'

gem "rake", Gem::Version.new(RUBY_VERSION) < Gem::Version.new("1.9.3") ? "~>10.3" : ">= 10.3"

group :test do
  gem "rspec", ">= 3.2"
  # Older versions of some gems required for Ruby 1.8.7 support
  platforms :ruby_18 do
    gem "activesupport", "~> 3.2.21"
    gem "i18n", "~> 0.6.11"
  end
  platforms :ruby_18, :ruby_19 do
    gem "mime-types", "~> 1.25"
    gem "addressable", "~> 2.3.0"
  end
  platforms :ruby_18, :ruby_19, :ruby_20, :ruby_21 do
    gem "rack", "~> 1.6"
  end
  platforms :jruby, :ruby_19, :ruby_20, :ruby_21, :ruby_22, :ruby_23, :ruby_24, :ruby_25 do
    gem "aruba", "~> 0.7.4"
    gem "capybara"
    gem "nokogiri", RUBY_VERSION < "2.1" ? "~> 1.6.0" : ">= 1.7"
    gem "cucumber"
    gem "phantomjs", "~> 2.1"
    gem "poltergeist"
    gem "rubocop" unless RUBY_VERSION.start_with?("1.")
    gem "test-unit"
  end
  gem "json", RUBY_VERSION.start_with?("1.") ? "~> 1.8" : "~> 2.0"
end

gemspec
