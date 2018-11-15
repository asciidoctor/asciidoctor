source 'https://rubygems.org'

# Look in asciidoctor.gemspec for runtime and development dependencies
gemspec

group :development do
  gem 'concurrent-ruby', '~> 1.0.0'
  # pin nokogiri because XPath behavior changed on JRuby starting in 1.8.3 (see sparklemotion/nokogiri#1803)
  gem 'nokogiri', '1.8.2' if RUBY_ENGINE == 'jruby'
end

group :doc do
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
  gem 'simplecov', '~> 0.14.1'
end
