# encoding: iso-8859-1
# Ideally we would use Norwegian keywords here, but that won't work unless this file is UTF-8 encoded.
# Alternatively it would be possible to use Norwegian keywords and encode the file as UTF-8.
#
# In both cases, stepdef arguments will be sent in as UTF-8, regardless of what encoding is used.
Given /^jeg drikker en "([^"]*)"$/ do |drink|
  expect(drink).to eq 'øl'.encode('UTF-8')
end

When /^skal de andre si "([^"]*)"$/ do |greeting|
  expect(greeting).to eq 'skål'.encode('UTF-8')
end
