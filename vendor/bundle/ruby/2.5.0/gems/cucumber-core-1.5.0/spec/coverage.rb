require 'simplecov'
formatters = [ SimpleCov::Formatter::HTMLFormatter ]

if ENV['TRAVIS']
  require 'coveralls'
  formatters << Coveralls::SimpleCov::Formatter
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[*formatters]
SimpleCov.start
