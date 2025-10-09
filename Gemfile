# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor.gemspec for runtime and development dependencies
gemspec

group :development do
  # asciimath is needed for testing AsciiMath in DocBook backend; Asciidoctor supports asciimath >= 1.0.0
  gem 'asciimath', (ENV.fetch 'ASCIIMATH_VERSION', '~> 2.0')
  # coderay is needed for testing source highlighting
  gem 'coderay', '~> 1.1.0'
  gem 'haml', ENV['HAML_VERSION'] if ENV.key? 'HAML_VERSION'
  gem 'open-uri-cached', '~> 1.0.0'
  # pygments.rb is needed for testing source highlighting; Asciidoctor supports pygments.rb >= 1.2.0
  gem 'pygments.rb', ENV['PYGMENTS_VERSION'] if ENV.key? 'PYGMENTS_VERSION'
  # rouge is needed for testing source highlighting; Asciidoctor supports rouge >= 2
  gem 'rouge', (ENV.fetch 'ROUGE_VERSION', '~> 3.0')
  if RUBY_ENGINE == 'truffleruby'
    gem 'nokogiri', '~> 1.10.0'
  elsif (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.6.0')
    gem 'nokogiri', '~> 1.12.0'
  elsif (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.7.0')
    gem 'nokogiri', '~> 1.13.0'
  end
  gem 'minitest', '~> 5.14.0' if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.6.0')
end

group :docs do
  gem 'yard'
  gem 'yard-tomdoc'
end

group :lint do
  gem 'rubocop', '~> 1.81.0', require: false
  gem 'rubocop-minitest', '~> 0.38.0', require: false
  gem 'rubocop-rake', '~> 0.7.0', require: false
end

group :coverage do
  gem 'simplecov', '~> 0.16.0'
end
