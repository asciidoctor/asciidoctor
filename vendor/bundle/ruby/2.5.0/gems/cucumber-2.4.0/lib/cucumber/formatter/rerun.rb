require 'cucumber/formatter/io'

module Cucumber
  module Formatter
    class Rerun
      include Formatter::Io

      def initialize(runtime, path_or_io, options)
        @io = ensure_io(path_or_io)
        @failures = {}
        @options = options
      end

      def after_test_case(test_case, result)
        return if result.ok?(@options[:strict])
        @failures[test_case.location.file] ||= []
        @failures[test_case.location.file] << test_case.location.line
      end

      def done
        return if @failures.empty?
        @io.print file_failures.join(' ')
      end

      [:before_test_case, :before_test_step, :after_test_step].each do |method|
        define_method(method) { |*| }
      end

      private
      def file_failures
        @failures.map { |file, lines| [file, lines].join(':') }
      end
    end
  end
end
