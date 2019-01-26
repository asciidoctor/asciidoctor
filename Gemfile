source 'https://rubygems.org'

# Look in asciidoctor.gemspec for runtime and development dependencies
gemspec

group :development do
  gem 'pygments.rb' if ENV['PYGMENTS']
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
  gem 'simplecov', '~> 0.16.0'
end
