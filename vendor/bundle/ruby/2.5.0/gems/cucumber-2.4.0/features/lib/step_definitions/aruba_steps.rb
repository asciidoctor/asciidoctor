Given('a Gemfile with:') do |content|
  path = File.expand_path(current_dir + "/Gemfile")
  write_file path, content
  set_env "BUNDLE_GEMFILE", path
end

Then(/^it should (pass|fail)$/) do |result|
  assert_success result == 'pass'
end

Then(/^"([^"]*)" should not be required$/) do |file_name|
  expect(all_output).not_to include("* #{file_name}")
end

Then(/^"([^"]*)" should be required$/) do |file_name|
  expect(all_output).to include("* #{file_name}")
end

Then /^it fails before running features with:$/ do |expected|
  assert_matching_output("\\A#{expected}", all_output)
  assert_success(false)
end

Then(/^the output includes the message "(.*)"$/) do |message|
  expect(all_output).to include(message)
end
