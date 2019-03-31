require 'cucumber/core/test/runner'
require 'cucumber/core/test/case'
require 'cucumber/core/test/step'
require 'cucumber/core/test/duration_matcher'

module Cucumber::Core::Test
  describe Runner do

    let(:test_case) { Case.new(test_steps, source) }
    let(:source)    { [double('ast node', location: double)] }
    let(:runner)    { Runner.new(report) }
    let(:report)    { double.as_null_object }
    let(:passing)   { Step.new([source]).with_action {} }
    let(:failing)   { Step.new([source]).with_action { raise exception } }
    let(:pending)   { Step.new([source]).with_action { raise Result::Pending.new("TODO") } }
    let(:skipping)  { Step.new([source]).with_action { raise Result::Skipped.new } }
    let(:undefined) { Step.new([source]) }
    let(:exception) { StandardError.new('test error') }

    before do
      allow(report).to receive(:before_test_case)
      allow(source).to receive(:location)
    end

    context "reporting the duration of a test case" do
      before do
        allow( Timer::MonotonicTime ).to receive(:time_in_nanoseconds).and_return(525702744080000, 525702744080001)
      end

      context "for a passing test case" do
        let(:test_steps) { [passing] }

        it "records the nanoseconds duration of the execution on the result" do
          expect( report ).to receive(:after_test_case) do |reported_test_case, result|
            expect( result.duration ).to be_duration 1
          end
          test_case.describe_to runner
        end
      end

      context "for a failing test case" do
        let(:test_steps) { [failing] }

        it "records the duration" do
          expect( report ).to receive(:after_test_case) do |reported_test_case, result|
            expect( result.duration ).to be_duration 1
          end
          test_case.describe_to runner
        end
      end
    end

    context "reporting the exception that failed a test case" do
      let(:test_steps) { [failing] }
      it "sets the exception on the result" do
        allow(report).to receive(:before_test_case)
        expect( report ).to receive(:after_test_case) do |reported_test_case, result|
          expect( result.exception ).to eq exception
        end
        test_case.describe_to runner
      end
    end

    context "with a single case" do
      context "without steps" do
        let(:test_steps) { [] }

        it "calls the report before running the case" do
          expect( report ).to receive(:before_test_case).with(test_case)
          test_case.describe_to runner
        end

        it "calls the report after running the case" do
          expect( report ).to receive(:after_test_case) do |reported_test_case, result|
            expect( reported_test_case ).to eq test_case
            expect( result ).to be_unknown
          end
          test_case.describe_to runner
        end
      end

      context 'with steps' do
        context 'that all pass' do
          let(:test_steps) { [ passing, passing ]  }

          it 'reports a passing test case' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result ).to be_passed
            end
            test_case.describe_to runner
          end
        end

        context 'an undefined step' do
          let(:test_steps) { [ undefined ]  }

          it 'reports an undefined test case' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result ).to be_undefined
            end
            allow( undefined.source.last ).to receive(:name)
            test_case.describe_to runner
          end

          it 'sets the message on the result' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result.message ).to eq("Undefined step: \"step name\"")
            end
            expect( undefined.source.last ).to receive(:name).and_return("step name")
            test_case.describe_to runner
          end

          it 'appends the backtrace of the result' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result.backtrace ).to eq(["step line"])
            end
            expect( undefined.source.last ).to receive(:backtrace_line).and_return("step line")
            allow( undefined.source.last ).to receive(:name)
            test_case.describe_to runner
          end
        end

        context 'a pending step' do
          let(:test_steps) { [ pending ] }

          it 'reports a pending test case' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result ).to be_pending
            end
            test_case.describe_to runner
          end

          it 'appends the backtrace of the result' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result.backtrace.last ).to eq("step line")
            end
            expect( pending.source.last ).to receive(:backtrace_line).and_return("step line")
            test_case.describe_to runner
          end
        end

        context "a skipping step" do
          let(:test_steps) { [skipping] }

          it "reports a skipped test case" do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result ).to be_skipped
            end
            test_case.describe_to runner
          end

          it 'appends the backtrace of the result' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result.backtrace.last ).to eq("step line")
            end
            expect( skipping.source.last ).to receive(:backtrace_line).and_return("step line")
            test_case.describe_to runner
          end
        end

        context 'that fail' do
          let(:test_steps) { [ failing ] }

          it 'reports a failing test case' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result ).to be_failed
            end
            test_case.describe_to runner
          end

          it 'appends the backtrace of the exception of the result' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result.exception.backtrace.last ).to eq("step line")
            end
            expect( failing.source.last ).to receive(:backtrace_line).and_return("step line")
            test_case.describe_to runner
          end
        end

        context 'where the first step fails' do
          let(:test_steps) { [ failing, passing ] }

          it 'executes the after hook at the end regardless of the failure' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result ).to be_failed
              expect( result.exception ).to eq exception
            end
            test_case.describe_to runner
          end

          it 'reports the first step as failed' do
            expect( report ).to receive(:after_test_step).with(failing, anything) do |test_step, result|
              expect( result ).to be_failed
            end
            test_case.describe_to runner
          end

          it 'reports the second step as skipped' do
            expect( report ).to receive(:after_test_step).with(passing, anything) do |test_step, result|
              expect( result ).to be_skipped
            end
            test_case.describe_to runner
          end

          it 'reports the test case as failed' do
            expect( report ).to receive(:after_test_case) do |test_case, result|
              expect( result ).to be_failed
              expect( result.exception ).to eq exception
            end
            test_case.describe_to runner
          end

          it 'skips, rather than executing the second step' do
            expect( passing ).not_to receive(:execute)
            expect( passing ).to receive(:skip)
            test_case.describe_to runner
          end
        end

      end
    end

    context 'with multiple test cases' do
      context 'when the first test case fails' do
        let(:first_test_case) { Case.new([failing], source) }
        let(:last_test_case)  { Case.new([passing], source) }
        let(:test_cases)      { [first_test_case, last_test_case] }

        it 'reports the results correctly for the following test case' do
          expect( report ).to receive(:after_test_case).with(last_test_case, anything) do |reported_test_case, result|
            expect( result ).to be_passed
          end

          test_cases.each { |c| c.describe_to runner }
        end
      end
    end

    context "passing latest result to a mapping" do
      it "passes a Failed result when the scenario is failing" do
        result_spy = nil
        hook_mapping = UnskippableAction.new do |last_result|
          result_spy = last_result
        end
        after_hook = Step.new([source], hook_mapping)
        failing_step = Step.new([source]).with_action { fail }
        test_case = Case.new([failing_step, after_hook], source)
        test_case.describe_to runner
        expect(result_spy).to be_failed
      end
    end

    require 'cucumber/core/test/around_hook'
    context "with around hooks" do
      it "passes normally when around hooks don't fail" do
        around_hook = AroundHook.new { |block| block.call }
        passing_step = Step.new([source]).with_action {}
        test_case = Case.new([passing_step], source, [around_hook])
        expect(report).to receive(:after_test_case).with(test_case, anything) do |reported_test_case, result|
          expect(result).to be_passed
        end
        test_case.describe_to runner
      end

      it "gets a failed result if the Around hook fails before the test case is run" do
        around_hook = AroundHook.new { |block| raise exception }
        passing_step = Step.new([source]).with_action {}
        test_case = Case.new([passing_step], source, [around_hook])
        expect(report).to receive(:after_test_case).with(test_case, anything) do |reported_test_case, result|
          expect(result).to be_failed
          expect(result.exception).to eq exception
        end
        test_case.describe_to runner
      end

      it "gets a failed result if the Around hook fails after the test case is run" do
        around_hook = AroundHook.new { |block| block.call; raise exception }
        passing_step = Step.new([source]).with_action {}
        test_case = Case.new([passing_step], source, [around_hook])
        expect(report).to receive(:after_test_case).with(test_case, anything) do |reported_test_case, result|
          expect(result).to be_failed
          expect(result.exception).to eq exception
        end
        test_case.describe_to runner
      end

      it "fails when a step fails if the around hook works" do
        around_hook = AroundHook.new { |block| block.call }
        failing_step = Step.new([source]).with_action { raise exception }
        test_case = Case.new([failing_step], source, [around_hook])
        expect(report).to receive(:after_test_case).with(test_case, anything) do |reported_test_case, result|
          expect(result).to be_failed
          expect(result.exception).to eq exception
        end
        test_case.describe_to runner
      end

      it "sends after_test_step for a step interrupted by (a timeout in) the around hook" do
        around_hook = AroundHook.new { |block| block.call; raise exception }
        passing_step = Step.new([source]).with_action {}
        test_case = Case.new([], source, [around_hook])
        allow(runner).to receive(:running_test_step).and_return(passing_step)
        expect(report).to receive(:after_test_step).with(passing_step, anything) do |reported_test_case, result|
          expect(result).to be_failed
          expect(result.exception).to eq exception
        end
        expect(report).to receive(:after_test_case).with(test_case, anything) do |reported_test_case, result|
          expect(result).to be_failed
          expect(result.exception).to eq exception
        end
        test_case.describe_to runner
      end
    end

  end
end
