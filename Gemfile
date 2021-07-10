# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor.gemspec for runtime and development dependencies
gemspec

group :development do
  gem 'asciimath', ENV['ASCIIMATH_VERSION'] if ENV.key? 'ASCIIMATH_VERSION'
  # coderay is needed for testing syntax highlighting
  gem 'coderay', '~> 1.1.0'
  gem 'haml', '~> 4.0' if RUBY_ENGINE == 'truffleruby'
  gem 'pygments.rb', ENV['PYGMENTS_VERSION'] if ENV.key? 'PYGMENTS_VERSION'
  # Asciidoctor supports Rouge >= 2
  gem 'rouge', (ENV.fetch 'ROUGE_VERSION', '~> 3.0')
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

group :ci do
  gem 'json', '~> 2.2.0' if RUBY_ENGINE == 'truffleruby'
  gem 'simplecov', '~> 0.16.0'
end
