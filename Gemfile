# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor.gemspec for runtime and development dependencies
gemspec

group :development do
  gem 'asciimath', ENV['ASCIIMATH_VERSION'] if ENV.key? 'ASCIIMATH_VERSION'
  gem 'haml', '~> 4.0' if RUBY_ENGINE == 'truffleruby'
  gem 'pygments.rb', ENV['PYGMENTS_VERSION'] if ENV.key? 'PYGMENTS_VERSION'
  gem 'rouge', ENV['ROUGE_VERSION'] if ENV.key? 'ROUGE_VERSION'
end

group :docs do
  gem 'yard'
  gem 'yard-tomdoc'
end

# enable this group to use Guard for continuous testing
# after removing comments, run `bundle install` then `guard`
#group :guardtest do
#  gem 'guard'
#  gem 'guard-test'
#  gem 'libnotify'
#  gem 'listen', :github => 'guard/listen'
#end

group :lint do
  gem 'rubocop', '~> 1.17.0', require: false
  gem 'rubocop-minitest', '~> 0.13.0', require: false
  gem 'rubocop-rake', '~> 0.5.0', require: false
end unless (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.5.0')

group :ci do
  gem 'json', '~> 2.2.0' if RUBY_ENGINE == 'truffleruby'
  gem 'simplecov', '~> 0.16.0'
end
