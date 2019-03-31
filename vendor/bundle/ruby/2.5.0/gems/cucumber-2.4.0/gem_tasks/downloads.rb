require 'httparty'
require 'multi_json'

IO.read(File.dirname(__FILE__) + '/versions.txt').each_line do |version|
  json = HTTParty.get("http://rubygems.org/api/v1/downloads/cucumber-#{version.strip}.json")
  puts MultiJson.load(json.body)['version_downloads']
end
