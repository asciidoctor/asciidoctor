require 'spectroscope'
require 'ae'
require 'fileutils'

if ENV['simplecov']
  require 'simplecov'
  SimpleCov.command_name 'Ruby Tests'
  SimpleCov.start do
    coverage_dir('log/coverage')
  end
end

