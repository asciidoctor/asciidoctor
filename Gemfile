source 'https://rubygems.org'

# Look in asciidoctor.gemspec for runtime and development dependencies
gemspec

group :development do
  if (ruby_version = Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.1.0')
    if ruby_version < (Gem::Version.new '2.0.0')
      gem 'haml', '~> 4.0.0'
      if ruby_version < (Gem::Version.new '1.9.3')
        gem 'cucumber', '~> 1.3.0'
        gem 'nokogiri', '~> 1.5.0'
        gem 'slim', '~> 2.1.0'
        gem 'tilt', '2.0.7'
      else
        gem 'nokogiri', '~> 1.6.0'
        gem 'slim', '<= 3.0.7'
      end
    else
      gem 'nokogiri', '~> 1.6.0'
    end
  elsif ruby_version < (Gem::Version.new '2.2.0')
    gem 'nokogiri', '~> 1.7.0' if Gem::Platform.local =~ 'x86-mingw32' || Gem::Platform.local =~ 'x64-mingw32'
  end
  gem 'racc', '~> 1.4.0' if RUBY_VERSION == '2.1.0' && RUBY_ENGINE == 'rbx'
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
  if ENV['SHIPPABLE']
    gem 'simplecov-csv', '~> 0.1.3'
    gem 'ci_reporter', '~> 2.0.0'
    gem 'ci_reporter_minitest', '~> 1.0.0'
    #gem 'ci_reporter_cucumber', '~> 1.0.0'
  end
end
