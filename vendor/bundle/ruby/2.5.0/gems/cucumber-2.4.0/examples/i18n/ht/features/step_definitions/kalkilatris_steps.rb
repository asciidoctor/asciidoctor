
# encoding: utf-8
begin require 'rspec/expectations'; rescue LoadError; require 'spec/expectations'; end 
require 'cucumber/formatter/unicode'
$:.unshift(File.dirname(__FILE__) + '/../../lib')
require 'kalkilatris'

Before do
  @kalk = Kalkilatris.new
end

After do
end

Sipoze /Mwen te antre nan (\d+) nan kalkilatris la/ do |n|
  @kalk.push n.to_i
end

Lè /Mwen peze (\w+)/ do |op|
  @result = @kalk.send op
end

Lè sa a /Rezilta a ta dwe (.*) sou ekran an/ do |result|
  @result.should == result.to_f
end
