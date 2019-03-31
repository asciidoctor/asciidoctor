require 'aruba/cucumber'
require 'aruba/in_process'
require 'aruba/spawn_process'
require 'cucumber/cli/main'

Before('@spawn') do
  Aruba.process = Aruba::SpawnProcess
end

Before('~@spawn') do
  Aruba::InProcess.main_class = Cucumber::Cli::Main
  Aruba.process = Aruba::InProcess
end

Before do
  # Make sure bin/cucumber runs with SimpleCov enabled
  # set_env('SIMPLECOV', 'true')

  # Set a longer timeout for aruba, and a really long one if running on JRuby
  @aruba_timeout_seconds = Cucumber::JRUBY ? 35 : 15
end
