require 'cucumber/core/test/case'
require 'cucumber/core/test/step'

module Cucumber
  module Core

    # Compiles the AST into test cases
    class Compiler
      attr_reader :receiver
      private     :receiver

      def initialize(receiver)
        @receiver = receiver
      end

      def feature(feature)
        compiler = FeatureCompiler.new(TestCaseBuilder.new(receiver))
        feature.describe_to(compiler)
        self
      end

      def done
        receiver.done
        self
      end

      # @private
      class TestCaseBuilder
        attr_reader :receiver
        private     :receiver

        def initialize(receiver)
          @receiver = receiver
        end

        def on_background_step(source)
          background_test_steps << Test::Step.new(source)
          self
        end

        def on_step(source)
          test_steps << Test::Step.new(source)
          self
        end

        def on_test_case(source)
          Test::Case.new(test_steps, source).describe_to(receiver)
          @test_steps = nil
          self
        end

        private

        def background_test_steps
          @background_test_steps ||= []
        end

        def test_steps
          @test_steps ||= background_test_steps.dup
        end
      end

      # @private
      class FeatureCompiler
        attr_reader :receiver
        private     :receiver

        def initialize(receiver)
          @receiver = receiver
        end

        def feature(feature, &descend)
          @feature = feature
          descend.call(self)
          self
        end

        def background(background, &descend)
          source = [@feature, background]
          compiler = BackgroundCompiler.new(source, receiver)
          descend.call(compiler)
          self
        end

        def scenario(scenario, &descend)
          source = [@feature, scenario]
          scenario_compiler = ScenarioCompiler.new(source, receiver)
          descend.call(scenario_compiler)
          receiver.on_test_case(source)
          self
        end

        def scenario_outline(scenario_outline, &descend)
          source = [@feature, scenario_outline]
          compiler = ScenarioOutlineCompiler.new(source, receiver)
          descend.call(compiler)
          self
        end
      end

      # @private
      class ScenarioOutlineCompiler
        attr_reader :source, :receiver
        private     :source, :receiver

        def initialize(source, receiver)
          @source   = source
          @receiver = receiver
        end

        def outline_step(outline_step)
          outline_steps << outline_step
          self
        end

        def examples_table(examples_table, &descend)
          @examples_table = examples_table
          descend.call(self)
          self
        end

        def examples_table_row(row)
          steps(row).each do |step|
            receiver.on_step(source + [@examples_table, row, step])
          end
          receiver.on_test_case(source + [@examples_table, row])
          self
        end

        private

        def steps(row)
          outline_steps.map { |s| s.to_step(row) }
        end

        def outline_steps
          @outline_steps ||= []
        end
      end

      # @private
      class ScenarioCompiler
        attr_reader :source, :receiver
        private     :source, :receiver

        def initialize(source, receiver)
          @source   = source
          @receiver = receiver
        end

        def step(step)
          receiver.on_step(source + [step])
          self
        end
      end

      # @private
      class BackgroundCompiler
        attr_reader :source, :receiver
        private     :source, :receiver

        def initialize(source, receiver)
          @source   = source
          @receiver = receiver
        end

        def step(step)
          receiver.on_background_step(source + [step])
          self
        end
      end

    end
  end
end
