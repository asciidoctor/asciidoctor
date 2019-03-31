require 'cucumber/configuration'
require 'cucumber/runtime'
require 'cucumber/formatter/spec_helper'
require 'cucumber/formatter/event_bus_report'

module Cucumber
  module Formatter
    describe EventBusReport do
      extend SpecHelperDsl
      include SpecHelper

      context "With no options" do
        let(:config) { Cucumber::Configuration.new }

        before(:each) do
          @formatter = EventBusReport.new(config)
        end

        describe "given a single feature" do

          describe "a scenario with a single passing step" do
            define_feature <<-FEATURE
          Feature:
            Scenario: Test Scenario
              Given passing
            FEATURE

            define_steps do
              Given(/pass/) {}
            end

            it "emits a BeforeTestCase event" do
              received_event = nil
              config.on_event Cucumber::Events::BeforeTestCase do |event|
                received_event = event
              end
              run_defined_feature
              expect(received_event.test_case.name).to eq "Test Scenario"
            end

            it "emits a BeforeTestStep event" do
              received_event = nil
              config.on_event Cucumber::Events::BeforeTestStep do |event|
                received_event = event
              end
              run_defined_feature
              expect(received_event.test_case.name).to eq "Test Scenario"
              expect(received_event.test_step.name).to eq "passing"
            end

            it "emits an AfterTestStep event with a passed result" do
              received_event = nil
              config.on_event Cucumber::Events::AfterTestStep do |event|
                received_event = event
              end
              run_defined_feature
              expect(received_event.test_case.name).to eq "Test Scenario"
              expect(received_event.test_step.name).to eq "passing"
              expect(received_event.result).to be_passed
            end

            it "emits an AfterTestCase event with a passed result" do
              received_event = nil
              config.on_event Cucumber::Events::AfterTestCase do |event|
                received_event = event
              end
              run_defined_feature
              expect(received_event.test_case.name).to eq "Test Scenario"
              expect(received_event.result).to be_passed
            end

            it "emits a Done event when the test run is finished" do
              received_event = nil
              config.on_event Cucumber::Events::FinishedTesting do |event|
                received_event = event
              end
              run_defined_feature
              expect(received_event).not_to be_nil
            end
          end
        end
      end
    end
  end
end



