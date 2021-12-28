# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor.gemspec for runtime and development dependencies
gemspec

group :development do
  # asciimath is needed for testing AsciiMath in DocBook backend; Asciidoctor supports asciimath >= 1.0.0
  gem 'asciimath', (ENV.fetch 'ASCIIMATH_VERSION', '~> 2.0')
  # coderay is needed for testing source highlighting
  gem 'coderay', '~> 1.1.0'
  gem 'haml', '~> 4.0' if RUBY_ENGINE == 'truffleruby'
  gem 'open-uri-cached', '~> 1.0.0'
  # pygments.rb is needed for testing source highlighting; Asciidoctor supports pygments.rb >= 1.2.0
  gem 'pygments.rb', ENV['PYGMENTS_VERSION'] if ENV.key? 'PYGMENTS_VERSION'
  # rouge is needed for testing source highlighting; Asciidoctor supports rouge >= 2
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

group :lint do
  gem 'rubocop', '~> 1.22.0', require: false
  gem 'rubocop-minitest', '~> 0.15.0', require: false
  gem 'rubocop-rake', '~> 0.6.0', require: false
end unless (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.5.0')

group :ci do
  gem 'json', '~> 2.2.0' if RUBY_ENGINE == 'truffleruby'
  gem 'simplecov', '~> 0.16.0'
end
