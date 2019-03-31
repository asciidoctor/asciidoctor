require 'spec_helper'
require 'cucumber/step_argument'

module Cucumber
  describe StepArgument do
    it "creates 2 arguments" do
      arguments = StepArgument.arguments_from(/I (\w+) (\w+)/, "I like fish")

      expect(arguments.map{|argument| [argument.val, argument.offset]}).to eq [["like", 2], ["fish", 7]]
    end

    it "creates 2 arguments when first group is optional" do
      arguments = StepArgument.arguments_from(/should( not)? be flashed '([^']*?)'$/, "I should be flashed 'Login failed.'")

      expect(arguments.map{|argument| [argument.val, argument.offset]}).to eq [[nil, nil], ["Login failed.", 21]]
    end
  end
end
