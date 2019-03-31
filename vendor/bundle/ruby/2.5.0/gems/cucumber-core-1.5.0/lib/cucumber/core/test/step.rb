require 'cucumber/core/test/result'
require 'cucumber/core/test/action'

module Cucumber
  module Core
    module Test
      class Step
        attr_reader :source

        def initialize(source, action = Test::UndefinedAction.new(source.last.location))
          raise ArgumentError if source.any?(&:nil?)
          @source, @action = source, action
        end

        def describe_to(visitor, *args)
          visitor.test_step(self, *args)
        end

        def describe_source_to(visitor, *args)
          source.reverse.each do |node|
            node.describe_to(visitor, *args)
          end
          self
        end

        def skip(*args)
          @action.skip(*args)
        end

        def execute(*args)
          @action.execute(*args)
        end

        def with_action(location = nil, &block)
          self.class.new(source, Test::Action.new(location, &block))
        end

        def name
          source.last.name
        end

        def location
          source.last.location
        end

        def action_location
          @action.location
        end

        def inspect
          "#<#{self.class}: #{location}>"
        end

      end

      class IsStepVisitor
        def initialize(test_step)
          @is_step = false
          test_step.describe_to(self)
        end

        def step?
          @is_step
        end

        def test_step(*)
          @is_step = true
        end

        def method_missing(*)
          self
        end
      end
    end
  end
end
