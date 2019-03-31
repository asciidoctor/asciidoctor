require 'cucumber/formatter/progress'
require 'cucumber/step_definition_light'

module Cucumber
  module Formatter
    class Debug
      def initialize(runtime, io, options)
        @io = io
      end

      def log(message)
        return unless ENV['DEBUG']
        @io.puts "* #{message}"
      end

      def respond_to?(*args)
        true
      end

      def method_missing(name, *args)
        print(name)
      end

      def puts(*args)
        print("puts")
      end

    private

      def print(text)
        @io.puts text
      end
    end
  end
end
