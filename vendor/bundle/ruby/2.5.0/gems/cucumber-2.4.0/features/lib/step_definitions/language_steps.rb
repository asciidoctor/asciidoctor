# encoding: utf-8

Then(/^cucumber lists all the supported languages$/) do
  sample_languages = ["Arabic", "български", "Pirate", "English", "日本語"]
  sample_languages.each do |language|
    expect(all_output.force_encoding('utf-8')).to include(language)
  end
end
