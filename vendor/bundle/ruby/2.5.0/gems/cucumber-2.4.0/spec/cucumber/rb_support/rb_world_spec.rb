require 'spec_helper'
require 'cucumber/formatter/spec_helper'
require 'cucumber/formatter/pretty'

module Cucumber
  module RbSupport
    describe RbWorld do
      extend Cucumber::Formatter::SpecHelperDsl
      include Cucumber::Formatter::SpecHelper

      describe 'Handling puts in step definitions' do
        before(:each) do
          Cucumber::Term::ANSIColor.coloring = false
          @out = StringIO.new
          @formatter = Cucumber::Formatter::Pretty.new(runtime, @out, {})
          run_defined_feature
        end

        describe 'when modifying the printed variable after the call to puts' do
          define_feature <<-FEATURE
        Feature: Banana party

          Scenario: Monkey eats banana
            When puts is called twice for the same variable
          FEATURE

          define_steps do
            When(/^puts is called twice for the same variable$/) do
              foo = 'a'
              puts foo
              foo.upcase!
              puts foo
            end
          end

          it 'prints the variable value at the time puts was called' do
            expect( @out.string ).to include <<OUTPUT
    When puts is called twice for the same variable
      a
      A
OUTPUT
          end
        end
      end
    end
  end
end
