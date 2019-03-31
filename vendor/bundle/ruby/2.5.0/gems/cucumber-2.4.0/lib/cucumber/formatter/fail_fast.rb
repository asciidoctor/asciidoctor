require 'cucumber/formatter/io'
require 'cucumber/formatter/console'

module Cucumber
  module Formatter

    class FailFast

      def initialize(configuration)
        configuration.on_event :after_test_case do |event|
          Cucumber.wants_to_quit = true unless event.result.ok?(configuration.strict?)
        end
      end

    end

  end
end
