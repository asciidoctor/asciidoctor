require 'spec_helper'
require 'cucumber/rb_support/rb_language'

module Cucumber
  module RbSupport
    describe RbStepDefinition do
      let(:user_interface) { double('user interface') }
      let(:support_code)   { Cucumber::Runtime::SupportCode.new(user_interface) }
      let(:rb)             { support_code.ruby }
      let(:scenario)       { double('scenario', iso_code: 'en').as_null_object }
      let(:dsl) do
        rb
        Object.new.extend(Cucumber::RbSupport::RbDsl)
      end

      before do
        rb.begin_scenario(scenario)
        $inside = nil
      end

      def run_step(text)
        step_match(text).invoke(MultilineArgument::None.new)
      end

      def step_match(text)
        StepMatchSearch.new(rb.method(:step_matches), Configuration.default).call(text).first
      end

      it "allows calling of other steps" do
        dsl.Given(/Outside/) do
          step "Inside"
        end
        dsl.Given(/Inside/) do
          $inside = true
        end

        run_step "Outside"

        expect($inside).to be true
      end

      it "allows calling of other steps with inline arg" do
        dsl.Given(/Outside/) do
          location = Core::Ast::Location.new(__FILE__, __LINE__)
          step "Inside", table([['inside']])
        end
        dsl.Given(/Inside/) do |t|
          $inside = t.raw[0][0]
        end

        run_step "Outside"

        expect($inside).to eq 'inside'
      end

      context "mapping to world methods" do
        it "calls a method on the world when specified with a symbol" do
          expect(rb.current_world).to receive(:with_symbol)

          dsl.Given(/With symbol/, :with_symbol)

          run_step "With symbol"
        end

        it "calls a method on a specified object" do
          target = double('target')

          allow(rb.current_world).to receive(:target) { target }

          dsl.Given(/With symbol on block/, :with_symbol, :on => lambda { target })

          expect(target).to receive(:with_symbol)

          run_step "With symbol on block"
        end

        it "calls a method on a specified world attribute" do
          target = double('target')

          allow(rb.current_world).to receive(:target) { target }

          dsl.Given(/With symbol on symbol/, :with_symbol, :on => :target)

          expect(target).to receive(:with_symbol)

          run_step "With symbol on symbol"
        end

        it "has the correct location" do
          dsl.Given /With symbol/, :with_symbol
          expect(step_match("With symbol").file_colon_line).to eq "spec/cucumber/rb_support/rb_step_definition_spec.rb:#{__LINE__-1}"
        end
      end

      it "raises UndefinedDynamicStep when inside step is not defined" do
        dsl.Given(/Outside/) do
          step 'Inside'
        end

        expect(-> {
          run_step "Outside"
        }).to raise_error(Cucumber::UndefinedDynamicStep)
      end

      it "raises UndefinedDynamicStep when an undefined step is parsed dynamically" do
        dsl.Given(/Outside/) do
          steps %{
            Given Inside
          }
        end

        expect(-> {
          run_step "Outside"
        }).to raise_error(Cucumber::UndefinedDynamicStep)
      end

      it "raises UndefinedDynamicStep when an undefined step with doc string is parsed dynamically" do
        dsl.Given(/Outside/) do
          steps %{
            Given Inside
            """
            abc
            """
          }
        end

        expect(-> {
          run_step "Outside"
        }).to raise_error(Cucumber::UndefinedDynamicStep)
      end

      it "raises UndefinedDynamicStep when an undefined step with data table is parsed dynamically" do
        dsl.Given(/Outside/) do
          steps %{
            Given Inside
             | a |
             | 1 |
          }
        end

        expect(-> {
          run_step "Outside"
        }).to raise_error(Cucumber::UndefinedDynamicStep)
      end

      it "allows forced pending" do
        dsl.Given(/Outside/) do
          pending("Do me!")
        end

        expect(-> {
          run_step "Outside"
        }).to raise_error(Cucumber::Pending, "Do me!")
      end

      it "raises ArityMismatchError when the number of capture groups differs from the number of step arguments" do
        dsl.Given(/No group: \w+/) do |arg|
        end

        expect(-> {
          run_step "No group: arg"
        }).to raise_error(Cucumber::ArityMismatchError)
      end

      it "does not modify the step_match arg when arg is modified in a step" do
        dsl.Given(/My car is (.*)/) do |colour|
          colour << "xxx"
        end

        step_name = "My car is white"
        step_args = step_match(step_name).args

        expect(-> {
          run_step step_name
        }).not_to change{ step_args.first }
      end

      it "allows puts" do
        expect(user_interface).to  receive(:puts).with('wasup')
        dsl.Given(/Loud/) do
          puts 'wasup'
        end
        run_step "Loud"
      end

      it "recognizes $arg style captures" do
        arg_value = "wow!"
        dsl.Given "capture this: $arg" do |arg|
          expect(arg).to eq arg_value
        end
        run_step "capture this: wow!"
      end

      it "has a JSON representation of the signature" do
        expect(RbStepDefinition.new(rb, /I CAN HAZ (\d+) CUKES/i, lambda{}, {}).to_hash).to eq({ 'source' => "I CAN HAZ (\\d+) CUKES", 'flags' => 'i' })
      end
    end
  end
end
