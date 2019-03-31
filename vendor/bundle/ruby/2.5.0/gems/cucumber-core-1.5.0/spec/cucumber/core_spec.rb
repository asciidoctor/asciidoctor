require 'report_api_spy'
require 'cucumber/core'
require 'cucumber/core/filter'
require 'cucumber/core/gherkin/writer'
require 'cucumber/core/platform'
require 'cucumber/core/report/summary'
require 'cucumber/core/test/around_hook'
require 'cucumber/core/test/filters/activate_steps_for_self_test'

module Cucumber
  describe Core do
    include Core
    include Core::Gherkin::Writer

    describe "compiling features to a test suite" do

      it "compiles two scenarios into two test cases" do
        visitor = ReportAPISpy.new

        compile([
          gherkin do
            feature do
              background do
                step
              end
              scenario do
                step
              end
              scenario do
                step
                step
              end
            end
          end
        ], visitor)

        expect( visitor.messages ).to eq [
          :test_case,
          :test_step,
          :test_step,
          :test_case,
          :test_step,
          :test_step,
          :test_step,
          :done,
        ]
      end

      it "filters out test cases based on a tag expression" do
        visitor = double.as_null_object
        expect( visitor ).to receive(:test_case) do |test_case|
          expect( test_case.name ).to eq 'foo, bar (#1)'
        end.exactly(1).times

        gherkin = gherkin do
          feature do
            scenario tags: '@b' do
              step
            end

            scenario_outline 'foo' do
              step '<arg>'

              examples tags: '@a'do
                row 'arg'
                row 'x'
              end

              examples 'bar', tags: '@a @b' do
                row 'arg'
                row 'y'
              end
            end
          end
        end

        compile [gherkin], visitor, [Cucumber::Core::Test::TagFilter.new(['@a', '@b'])]
      end

      describe 'with tag filters that have limits' do
        let(:visitor) { double.as_null_object }
        let(:gherkin_doc) do
          gherkin do
            feature tags: '@feature' do
              scenario tags: '@one @three' do
                step
              end

              scenario tags: '@one' do
                step
              end

              scenario_outline  do
                step '<arg>'

                examples tags: '@three'do
                  row 'arg'
                  row 'x'
                end
              end

              scenario tags: '@ignore' do
                step
              end
            end
          end
        end

        require 'unindent'
        def expect_tag_excess(error_message)
          expect {
            compile [gherkin_doc], visitor, tag_filters
          }.to raise_error(
            Cucumber::Core::Test::TagFilter::TagExcess, error_message.unindent.chomp
          )
        end

        context 'on scenarios' do
          let(:tag_filters) {
            [ Cucumber::Core::Test::TagFilter.new(['@one:1']) ]
          }

          it 'raises a tag excess error with the location of the test cases' do
            expect_tag_excess <<-STR
              @one occurred 2 times, but the limit was set to 1
                features/test.feature:5
                features/test.feature:9
            STR
          end
        end

        context 'on scenario outlines' do
          let(:tag_filters) {
            [ Cucumber::Core::Test::TagFilter.new(['@three:1']) ]
          }

          it 'raises a tag excess error with the location of the test cases' do
            expect_tag_excess <<-STR
              @three occurred 2 times, but the limit was set to 1
                features/test.feature:5
                features/test.feature:18
            STR
          end
        end

        context 'on a feature with scenarios' do
          let(:tag_filters) {
            [ Cucumber::Core::Test::TagFilter.new(['@feature:2']) ]
          }

          it 'raises a tag excess error with the location of the test cases' do
            expect_tag_excess <<-STR
              @feature occurred 4 times, but the limit was set to 2
                features/test.feature:5
                features/test.feature:9
                features/test.feature:18
                features/test.feature:21
            STR
          end
        end

        context 'with negated tags' do
          let(:tag_filters) {
            [ Cucumber::Core::Test::TagFilter.new(['~@one:1']) ]
          }

          it 'raises a tag excess error with the location of the test cases' do
            expect_tag_excess <<-STR
              @one occurred 2 times, but the limit was set to 1
                features/test.feature:5
                features/test.feature:9
            STR
          end
        end

        context 'whith multiple tag limits' do
          let(:tag_filters) {
            [ Cucumber::Core::Test::TagFilter.new(['@one:1, @three:1', '~@feature:3']) ]
          }

          it 'raises a tag excess error with the location of the test cases' do
            expect_tag_excess <<-STR
              @one occurred 2 times, but the limit was set to 1
                features/test.feature:5
                features/test.feature:9
              @three occurred 2 times, but the limit was set to 1
                features/test.feature:5
                features/test.feature:18
              @feature occurred 4 times, but the limit was set to 3
                features/test.feature:5
                features/test.feature:9
                features/test.feature:18
                features/test.feature:21
            STR
          end
        end

      end

    end

    describe "executing a test suite" do
      context "without hooks" do
        it "executes the test cases in the suite" do
          gherkin = gherkin do
            feature 'Feature name' do
              scenario 'The one that passes' do
                step 'passing'
              end

              scenario 'The one that fails' do
                step 'passing'
                step 'failing'
                step 'passing'
                step 'undefined'
              end
            end
          end
          report = Core::Report::Summary.new

          execute [gherkin], report, [Core::Test::Filters::ActivateStepsForSelfTest.new]

          expect( report.test_cases.total           ).to eq 2
          expect( report.test_cases.total_passed    ).to eq 1
          expect( report.test_cases.total_failed    ).to eq 1
          expect( report.test_steps.total           ).to eq 5
          expect( report.test_steps.total_failed    ).to eq 1
          expect( report.test_steps.total_passed    ).to eq 2
          expect( report.test_steps.total_skipped   ).to eq 1
          expect( report.test_steps.total_undefined ).to eq 1
        end
      end

      context "with around hooks" do
        class WithAroundHooks < Core::Filter.new(:logger)
          def test_case(test_case)
            base_step = Core::Test::Step.new(test_case.source)
            test_steps = [
              base_step.with_action { logger << :step },
            ]

            around_hook = Core::Test::AroundHook.new do |run_scenario|
              logger << :before_all
              run_scenario.call
              logger << :middle
              run_scenario.call
              logger << :after_all
            end
            test_case.with_steps(test_steps).with_around_hooks([around_hook]).describe_to(receiver)
          end
        end

        it "executes the test cases in the suite" do
          gherkin = gherkin do
            feature do
              scenario do
                step
              end
            end
          end
          report = Core::Report::Summary.new
          logger = []

          execute [gherkin], report, [WithAroundHooks.new(logger)]

          expect( report.test_cases.total        ).to eq 1
          expect( report.test_cases.total_passed ).to eq 1
          expect( report.test_cases.total_failed ).to eq 0
          expect( logger ).to eq [
            :before_all,
              :step,
            :middle,
              :step,
            :after_all
          ]
        end
      end

      require 'cucumber/core/test/filters'
      it "filters test cases by tag" do
        gherkin = gherkin do
          feature do
            scenario do
              step
            end

            scenario tags: '@a @b' do
              step
            end

            scenario tags: '@a' do
              step
            end
          end
        end
        report = Core::Report::Summary.new

        execute [gherkin], report, [ Cucumber::Core::Test::TagFilter.new(['@a']) ]

        expect( report.test_cases.total ).to eq 2
      end

      it "filters test cases by name" do
        gherkin = gherkin do
          feature 'first feature' do
            scenario 'first scenario' do
              step 'missing'
            end
            scenario 'second' do
              step 'missing'
            end
          end
        end
        report = Core::Report::Summary.new

        execute [gherkin], report, [ Cucumber::Core::Test::NameFilter.new([/scenario/]) ]

        expect( report.test_cases.total ).to eq 1
      end

    end
  end
end
