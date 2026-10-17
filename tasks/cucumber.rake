# frozen_string_literal: true

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new :features do |t|
    t.cucumber_opts = %w(-f progress)
    t.cucumber_opts << '--publish-quiet' unless (Gem::Version.new Cucumber::VERSION) < (Gem::Version.new '5.0.0')
    t.cucumber_opts << '--no-color' if ENV['CI']
  end
rescue LoadError
  warn $!.message
end
