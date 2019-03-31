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

Δεδομένου ότι /έχω εισάγει (\d+) στην αριθμομηχανή/ do |n|
  @calc.push n.to_i
end

Όταν /πατάω (\w+)/ do |op|
  @result = @calc.send op
end

Τότε /το αποτέλεσμα στην οθόνη πρέπει να είναι (.*)/ do |result|
  @result.should == result.to_f
end