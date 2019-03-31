require 'pathname'
require 'cucumber/core/ast/location'
require 'cucumber/core/test/around_hook'

module Cucumber

  # Hooks quack enough like `Cucumber::Core::Ast` source nodes that we can use them as
  # source for test steps
  module Hooks

    class << self
      def before_hook(source, location, &block)
        build_hook_step(source, location, block, BeforeHook, Core::Test::UnskippableAction)
      end

      def after_hook(source, location, &block)
        build_hook_step(source, location, block, AfterHook, Core::Test::UnskippableAction)
      end

      def after_step_hook(source, location, &block)
        raise ArgumentError unless source.last.kind_of?(Core::Ast::Step)
        build_hook_step(source, location, block, AfterStepHook, Core::Test::Action)
      end

      def around_hook(source, &block)
        Core::Test::AroundHook.new(&block)
      end

      private

      def build_hook_step(source, location, block, hook_type, action_type)
        action = action_type.new(location, &block)
        hook = hook_type.new(action.location)
        Core::Test::Step.new(source + [hook], action)
      end
    end

    class AfterHook
      attr_reader :location

      def initialize(location)
        @location = location
      end

      def name
        "After hook"
      end

      def match_locations?(queried_locations)
        queried_locations.any? { |other_location| other_location.match?(location) }
      end

      def describe_to(visitor, *args)
        visitor.after_hook(self, *args)
      end
    end

    class BeforeHook
      attr_reader :location

      def initialize(location)
        @location = location
      end

      def name
        "Before hook"
      end

      def match_locations?(queried_locations)
        queried_locations.any? { |other_location| other_location.match?(location) }
      end

      def describe_to(visitor, *args)
        visitor.before_hook(self, *args)
      end
    end

    class AfterStepHook
      attr_reader :location

      def initialize(location)
        @location = location
      end

      def name
        "AfterStep hook"
      end

      def match_locations?(queried_locations)
        queried_locations.any? { |other_location| other_location.match?(location) }
      end

      def describe_to(visitor, *args)
        visitor.after_step_hook(self, *args)
      end
    end

  end
end
