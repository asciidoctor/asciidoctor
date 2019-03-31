require 'spec_helper'
require 'cucumber/formatter/spec_helper'

require 'cucumber/formatter/junit'
require 'nokogiri'

module Cucumber
  module Formatter
    describe Junit do
      extend SpecHelperDsl
      include SpecHelper

      class TestDoubleJunitFormatter < Junit
        attr_reader :written_files

        def write_file(feature_filename, data)
          @written_files ||= {}
          @written_files[feature_filename] = data
        end
      end

      context "With no options" do
        before(:each) do
          allow(File).to receive(:directory?) { true }
          @formatter = TestDoubleJunitFormatter.new(actual_runtime.configuration.with_options(out_stream: ''))
        end

        after(:each) do
          $stdout = STDOUT
        end

        describe "is able to strip control chars from cdata" do
          before(:each) do
            run_defined_feature
            @doc = Nokogiri.XML(@formatter.written_files.values.first)
          end
          define_feature "
              Feature: One passing scenario, one failing scenario

                Scenario: Passing
                  Given a passing ctrl scenario
            "
          class Junit
            def before_step(step)
              if step.name.match("a passing ctrl scenario")
                Interceptor::Pipe.unwrap! :stdout
                @fake_io = $stdout = StringIO.new
                $stdout.sync = true
                @interceptedout = Interceptor::Pipe.wrap(:stdout)
              end
            end

            def after_step(step)
              if step.name.match("a passing ctrl scenario")
                @interceptedout.write("boo\b\cx\e\a\f boo ")
                $stdout = STDOUT
                @fake_io.close
              end
            end
          end

          it { expect(@doc.xpath('//testsuite/testcase/system-out').first.content).to match(/\s+boo boo\s+/) }
        end

        describe "a feature with no name" do
          define_feature <<-FEATURE
            Feature:
              Scenario: Passing
                Given a passing scenario
          FEATURE

          it "raises an exception" do
            expect(-> {
              run_defined_feature
            }).to raise_error(Junit::UnNamedFeatureError)
          end
        end

        describe "given a single feature" do
          before(:each) do
            run_defined_feature
            @doc = Nokogiri.XML(@formatter.written_files.values.first)
          end

          describe "with a single scenario" do
            define_feature <<-FEATURE
              Feature: One passing scenario, one failing scenario

                Scenario: Passing
                  Given a passing scenario
            FEATURE

            it { expect(@doc.to_s).to match /One passing scenario, one failing scenario/ }

            it 'has not a root system-out node' do
              expect(@doc.xpath('//testsuite/system-out').size).to eq 0
            end

            it 'has not a root system-err node' do
              expect(@doc.xpath('//testsuite/system-err').size).to eq 0
            end

            it 'has a system-out node under <testcase/>' do
              expect(@doc.xpath('//testcase/system-out').size).to eq 1
            end

            it 'has a system-err node under <testcase/>' do
              expect(@doc.xpath('//testcase/system-err').size).to eq 1
            end
          end

          describe "with a scenario in a subdirectory" do
            define_feature %{
              Feature: One passing scenario, one failing scenario

                Scenario: Passing
                  Given a passing scenario
            }, File.join('features', 'some', 'path', 'spec.feature')

            it 'writes the filename including the subdirectory' do
              expect(@formatter.written_files.keys.first).to eq File.join('', 'TEST-features-some-path-spec.xml')
            end
          end

          describe "with a scenario outline table" do
            define_steps do
              Given(/.*/) {  }
            end

            define_feature <<-FEATURE
              Feature: Eat things when hungry

                Scenario Outline: Eat things
                  Given <Things>
                  And stuff:
                    | foo |
                    | bar |

                Examples: Good
                  | Things   |
                  | Cucumber |
                  | Whisky   |
                Examples: Evil
                  | Things   |
                  | Big Mac  |
            FEATURE

            it { expect(@doc.to_s).to match /Eat things when hungry/ }
            it { expect(@doc.to_s).to match /Cucumber/ }
            it { expect(@doc.to_s).to match /Whisky/ }
            it { expect(@doc.to_s).to match /Big Mac/ }
            it { expect(@doc.to_s).not_to match /Things/ }
            it { expect(@doc.to_s).not_to match /Good|Evil/ }
            it { expect(@doc.to_s).not_to match /type="skipped"/}
          end

          describe "scenario with skipped test in junit report" do
            define_feature <<-FEATURE
              Feature: junit report with skipped test

                Scenario Outline: skip a test and junit report of the same
                  Given a <skip> scenario

                Examples:
                  | skip   |
                  | undefined |
                  | still undefined  |
            FEATURE

            it { expect(@doc.to_s).to match /skipped="2"/}
          end

          describe "with a regular data table scenario" do
            define_steps do
              Given(/the following items on a shortlist/) { |table| }
              When(/I go.*/) {  }
              Then(/I should have visited at least/) { |table| }
            end

            define_feature <<-FEATURE
              Feature: Shortlist

                Scenario: Procure items
                  Given the following items on a shortlist:
                    | item    |
                    | milk    |
                    | cookies |
                  When I get some..
                  Then I'll eat 'em

            FEATURE
            # these type of tables shouldn't crash (or generate test cases)
            it { expect(@doc.to_s).not_to match /milk/ }
            it { expect(@doc.to_s).not_to match /cookies/ }
          end
        end
      end
      
      context "In --expand mode" do
        let(:runtime)   { Runtime.new({:expand => true}) }
        before(:each) do
          allow(File).to receive(:directory?) { true }
          @formatter = TestDoubleJunitFormatter.new(actual_runtime.configuration.with_options(out_stream: '', :expand => true))
        end

        after(:each) do
          $stdout = STDOUT
        end

        describe "given a single feature" do
          before(:each) do
            run_defined_feature
            @doc = Nokogiri.XML(@formatter.written_files.values.first)
          end
          
          describe "with a scenario outline table" do
            define_steps do
              Given(/.*/) {  }
            end

            define_feature <<-FEATURE
              Feature: Eat things when hungry

                Scenario Outline: Eat things
                  Given <Things>
                  And stuff:
                    | foo |
                    | bar |

                Examples: Good
                  | Things   |
                  | Cucumber |
                  | Whisky   |
                Examples: Evil
                  | Things   |
                  | Big Mac  |
            FEATURE

            it { expect(@doc.to_s).to match /Eat things when hungry/ }
            it { expect(@doc.to_s).to match /Cucumber/ }
            it { expect(@doc.to_s).to match /Whisky/ }
            it { expect(@doc.to_s).to match /Big Mac/ }
            it { expect(@doc.to_s).not_to match /Things/ }
            it { expect(@doc.to_s).not_to match /Good|Evil/ }
            it { expect(@doc.to_s).not_to match /type="skipped"/}
          end
        end
        
      end
    end
  end
end
