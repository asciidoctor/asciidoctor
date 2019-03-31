module Cucumber

  # Events tell you what's happening while Cucumber runs your features.
  #
  # They're designed to be read-only, appropriate for writing formatters and other
  # output tools. If you need to be able to influence the result of a scenario, use a hook instead.
  #
  # To subscribe to an event, use {Cucumber::Configuration#on_event}
  #
  # @example
  #   AfterConfiguration do |config|
  #     config.on_event :after_test_step do |event|
  #       puts event.result
  #     end
  #   end
  module Events
  end
end

Dir[File.dirname(__FILE__) + '/events/*.rb'].map(&method(:require))
