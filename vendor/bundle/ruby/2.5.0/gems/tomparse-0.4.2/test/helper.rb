require 'citron'
require 'ae'

if ENV['coverage']
  require 'simplecov'
  SimpleCov.command_name 'tomparse'
  SimpleCov.start do
    coverage_dir 'log/coverage'
  end
end

require 'tomparse'

