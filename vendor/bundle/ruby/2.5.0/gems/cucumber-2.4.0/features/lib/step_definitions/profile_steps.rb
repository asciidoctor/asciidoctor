Given /^the following profiles? (?:are|is) defined:$/ do |profiles|
  write_file 'cucumber.yml', profiles
end

Then /^the (.*) profile should be used$/ do |profile|
  step 'the stdout should contain:', profile
end

Then /^exactly these files should be loaded:\s*(.*)$/ do |files|
  expect(all_stdout.scan(/^  \* (.*\.rb)$/).flatten).to eq files.split(/,\s+/)
end

Then /^exactly these features should be run:\s*(.*)$/ do |files|
  expect(all_stdout.scan(/^  \* (.*\.feature)$/).flatten).to eq files.split(/,\s+/)
end
