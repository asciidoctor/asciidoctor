Given /^a scenario "([^\"]*)" that fails once, then passes$/ do |name|
  write_file "features/#{name}.feature",
  <<-FEATURE
  Feature: #{name}
    Scenario: #{name}
      Given it fails once, then passes
  FEATURE

  write_file "features/step_defnitions/#{name}_steps.rb",
  <<-STEPS
  Given(/^it fails once, then passes$/) do
    $#{name.downcase} ||= 0
    $#{name.downcase} += 1
    expect($#{name.downcase}).to eql 2
  end
  STEPS
end

Given /^a scenario "([^\"]*)" that fails twice, then passes$/ do |name|
  write_file "features/#{name}.feature",
  <<-FEATURE
  Feature: #{name}
    Scenario: #{name}
      Given it fails twice, then passes
  FEATURE

  write_file "features/step_definitions/#{name}_steps.rb",
  <<-STEPS
  Given(/^it fails twice, then passes$/) do
    $#{name.downcase} ||= 0
    $#{name.downcase} += 1
    expect($#{name.downcase}).to eql 3
  end
  STEPS
end
