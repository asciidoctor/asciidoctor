require 'cucumber/core/test/step'

module Cucumber::Core::Test
  describe Step do

    describe "describing itself" do
      let(:step_or_hook) { double }
      before(:each) do
        allow( step_or_hook ).to receive(:location)
      end

      it "describes itself to a visitor" do
        visitor = double
        args = double
        test_step = Step.new([step_or_hook])
        expect( visitor ).to receive(:test_step).with(test_step, args)
        test_step.describe_to(visitor, args)
      end

      it "describes its source to a visitor" do
        feature, scenario = double, double
        visitor = double
        args = double
        expect( feature      ).to receive(:describe_to).with(visitor, args)
        expect( scenario     ).to receive(:describe_to).with(visitor, args)
        expect( step_or_hook ).to receive(:describe_to).with(visitor, args)
        test_step = Step.new([feature, scenario, step_or_hook])
        test_step.describe_source_to(visitor, args)
      end
    end

    describe "executing" do
      let(:ast_step) { double }
      before(:each) do
        allow( ast_step ).to receive(:location)
      end

      it "passes arbitrary arguments to the action's block" do
        args_spy = nil
        expected_args = [double, double]
        test_step = Step.new([ast_step]).with_action do |*actual_args|
          args_spy = actual_args
        end
        test_step.execute(*expected_args)
        expect(args_spy).to eq expected_args
      end

      context "when a passing action exists" do
        it "returns a passing result" do
          test_step = Step.new([ast_step]).with_action {}
          expect( test_step.execute ).to be_passed
        end
      end

      context "when a failing action exists" do
        let(:exception) { StandardError.new('oops') }

        it "returns a failing result" do
          test_step = Step.new([ast_step]).with_action { raise exception }
          result = test_step.execute
          expect( result           ).to be_failed
          expect( result.exception ).to eq exception
        end
      end

      context "with no action" do
        it "returns an Undefined result" do
          test_step = Step.new([ast_step])
          result = test_step.execute
          expect( result           ).to be_undefined
        end
      end
    end

    it "exposes the name and location of the AST step or hook as attributes" do
      name, location = double, double
      step_or_hook = double(name: name, location: location)
      test_step = Step.new([step_or_hook])
      expect( test_step.name     ).to eq name
      expect( test_step.location ).to eq location
    end

    it "exposes the location of the action as attribute" do
      location = double
      action = double(location: location)
      test_step = Step.new([double], action)
      expect( test_step.action_location ).to eq location
    end

  end
end
