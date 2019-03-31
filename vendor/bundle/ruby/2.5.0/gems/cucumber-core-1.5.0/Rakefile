# encoding: utf-8
require 'rubygems'
require 'bundler'
Bundler::GemHelper.install_tasks

$:.unshift File.expand_path("../lib", __FILE__)

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.ruby_opts  = %w[-r./spec/coverage -w]
end

require_relative 'spec/capture_warnings'
include CaptureWarnings
namespace :spec do
  task :warnings do
    report_warnings do
      Rake::Task['spec'].invoke
    end
  end

  desc "run (slow) performance tests"
  RSpec::Core::RakeTask.new(:slow) do |t|
    t.rspec_opts = %w[--tag slow]
  end
end

task default: ['spec:warnings', 'spec:slow']
