require 'spec_helper'
require 'cucumber/formatter/spec_helper'
require 'cucumber/formatter/debug'
require 'cucumber/cli/options'

module Cucumber
  module Formatter
    describe Debug do
      extend SpecHelperDsl
      include SpecHelper

        before(:each) do
          Cucumber::Term::ANSIColor.coloring = false
          @out = StringIO.new
          @formatter = Debug.new(runtime, @out, {})
        end

        describe "given a single feature" do
          before(:each) { run_defined_feature }

          describe "with a scenario" do
            define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats banana
              Given there are bananas
            FEATURE

            it "outputs the events as expected" do
              expect(@out.string).to eq(<<EXPECTED)
before_test_case
before_features
before_feature
before_tags
after_tags
feature_name
before_test_step
after_test_step
before_test_step
before_feature_element
before_tags
after_tags
scenario_name
before_steps
before_step
before_step_result
step_name
after_step_result
after_step
after_test_step
after_steps
after_feature_element
after_test_case
after_feature
after_features
done
EXPECTED
            end
          end
        end
    end

  end
end
