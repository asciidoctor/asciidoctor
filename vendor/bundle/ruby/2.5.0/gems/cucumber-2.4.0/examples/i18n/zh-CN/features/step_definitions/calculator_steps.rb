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

Given /在计算器上输入(\d+)/ do |n|
  @calc.push n.to_i
end

When /按(.*)键/ do |op|
  if op == '加号'
    @result = @calc.send "add"
  end
end

Then /屏幕上显示的结果应该是是(.*)/ do |result|
  @result.should == result.to_f
end
