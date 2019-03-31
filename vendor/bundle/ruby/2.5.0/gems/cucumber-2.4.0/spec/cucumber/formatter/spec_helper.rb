module Cucumber
  module Formatter
    module SpecHelperDsl
      attr_reader :feature_content, :step_defs, :feature_filename

      def define_feature(string, feature_file = 'spec.feature')
        @feature_content = string
        @feature_filename = feature_file
      end

      def define_steps(&block)
        @step_defs = block
      end
    end

    require 'cucumber/core'
    module SpecHelper
      include Core

      def run_defined_feature
        define_steps
        actual_runtime.visitor = report

        receiver = Test::Runner.new(report)
        filters = [
          Filters::ActivateSteps.new(
            StepMatchSearch.new(actual_runtime.support_code.ruby.method(:step_matches), actual_runtime.configuration),
            actual_runtime.configuration
          ),
          Filters::ApplyAfterStepHooks.new(actual_runtime.support_code),
          Filters::ApplyBeforeHooks.new(actual_runtime.support_code),
          Filters::ApplyAfterHooks.new(actual_runtime.support_code),
          Filters::ApplyAroundHooks.new(actual_runtime.support_code),
          Filters::PrepareWorld.new(actual_runtime)
        ]
        compile [gherkin_doc], receiver, filters
      end

      require 'cucumber/formatter/event_bus_report'
      def event_bus_report
        @event_bus_report ||= Formatter::EventBusReport.new(actual_runtime.configuration)
      end

      require 'cucumber/formatter/legacy_api/adapter'
      def report
        @report ||= LegacyApi::Adapter.new(
          Fanout.new([@formatter, event_bus_report]),
          actual_runtime.results,
          actual_runtime.configuration)
      end

      require 'cucumber/core/gherkin/document'
      def gherkin_doc
        Core::Gherkin::Document.new(self.class.feature_filename, gherkin)
      end

      def gherkin
        self.class.feature_content || raise("No feature content defined!")
      end

      def runtime
        @runtime_facade ||= LegacyApi::RuntimeFacade.new(actual_runtime.results, actual_runtime.support_code, actual_runtime.configuration)
      end

      def actual_runtime
        @runtime ||= Runtime.new(options)
      end

      def define_steps
        return unless step_defs = self.class.step_defs
        rb = runtime.support_code.ruby
        dsl = Object.new
        dsl.extend RbSupport::RbDsl
        dsl.instance_exec &step_defs
      end

      def options
        {}
      end
    end
  end
end
