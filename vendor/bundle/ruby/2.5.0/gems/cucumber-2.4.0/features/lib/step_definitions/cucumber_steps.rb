Given /^a directory without standard Cucumber project directory structure$/ do
  in_current_dir do
    FileUtils.rm_rf 'features' if File.directory?('features')
  end
end

Given /^a scenario with a step that looks like this:$/ do |string|
  create_feature do
    create_scenario { string }
  end
end

Given(/^a scenario with a step that looks like this in japanese:$/) do |string|
  create_feature_ja do
    create_scenario_ja { string }
  end
end

Given(/^the standard step definitions$/) do
  write_file 'features/step_definitions/steps.rb',

  <<-STEPS
  Given(/^this step passes$/)          { }
  Given(/^this step raises an error$/) { raise 'error' }
  Given(/^this step is pending$/)      { pending }
  Given(/^this step fails$/)           { fail }
  Given(/^this step is a table step$/) {|t| }
  STEPS
end

Given /^a step definition that looks like this:$/ do |string|
  create_step_definition { string }
end

Given /^a scenario "([^\"]*)" that passes$/ do |name|
  write_file "features/#{name}.feature",
  <<-FEATURE
  Feature: #{name}
    Scenario: #{name}
      Given it passes
  FEATURE

  write_file "features/step_definitions/#{name}_steps.rb",
  <<-STEPS
  Given(/^it passes$/) { expect(true).to be true }
  STEPS
end

Given /^a scenario "([^\"]*)" that fails$/ do |name|
  write_file "features/#{name}.feature",
  <<-FEATURE
  Feature: #{name}
    Scenario: #{name}
      Given it fails
  FEATURE

  write_file "features/step_definitions/#{name}_steps.rb",
  <<-STEPS
  Given(/^it fails$/) { expect(false).to be true }
  STEPS
end

When /^I run the feature with the (\w+) formatter$/ do |formatter|
  expect(features.length).to eq 1
  run_feature features.first, formatter
end

Then /^the stderr should contain a warning message$/ do
  expect(all_stderr).to include("[warning]")
end

module CucumberHelper
  def run_feature(filename = 'features/a_feature.feature', formatter = 'progress')
    run_simple "#{Cucumber::BINARY} #{filename} --format #{formatter}", false
  end
end

World(CucumberHelper)
