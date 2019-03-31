When(/^I run the following Ruby code:$/) do |code|
  run_simple %{ruby -e "#{code}"}
end
