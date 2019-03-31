# encoding: utf-8
begin require 'rspec/expectations'; rescue LoadError; require 'spec/expectations'; end
require 'cucumber/formatter/unicode'
$:.unshift(File.dirname(__FILE__) + '/../../lib')
require 'calculator'

Before do
  @calc = Calculator.new
end

After do
end

Given /मैं गणक में (\d+) डालता हूँ/ do |n|
  @calc.push n.to_i
end

When /मैं (\w+) दबाता हूँ/ do |op|
  @result = @calc.send op
end

Then /परिणाम (.*) परदे पर प्रदशित होना चाहिए/ do |result|
  @result.should == result.to_f
end
