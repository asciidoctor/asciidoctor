# encoding: UTF-8

module Cucumber
  module Core
    module Test
      module Result

        # Defines to_sym on a result class for the given result type
        #
        # Defines predicate methods on a result class with only the given one
        # returning true
        def self.query_methods(result_type)
          Module.new do
            define_method :to_sym do
              result_type
            end

            [:passed, :failed, :undefined, :unknown, :skipped, :pending].each do |possible_result_type|
              define_method("#{possible_result_type}?") do
                possible_result_type == to_sym
              end
            end
          end
        end

        # Null object for results. Represents the state where we haven't run anything yet
        class Unknown
          include Result.query_methods :unknown

          def describe_to(visitor, *args)
            self
          end
        end

        class Passed
          include Result.query_methods :passed
          attr_accessor :duration

          def initialize(duration)
            raise ArgumentError unless duration
            @duration = duration
          end

          def describe_to(visitor, *args)
            visitor.passed(*args)
            visitor.duration(duration, *args)
            self
          end

          def to_s
            "✓"
          end

          def ok?(be_strict = false)
            true
          end

          def with_appended_backtrace(step)
            self
          end

          def with_filtered_backtrace(filter)
            self
          end
        end

        class Failed
          include Result.query_methods :failed
          attr_reader :duration, :exception

          def initialize(duration, exception)
            raise ArgumentError unless duration
            raise ArgumentError unless exception
            @duration = duration
            @exception = exception
          end

          def describe_to(visitor, *args)
            visitor.failed(*args)
            visitor.duration(duration, *args)
            visitor.exception(exception, *args) if exception
            self
          end

          def to_s
            "✗"
          end

          def ok?(be_strict = false)
            false
          end

          def with_duration(new_duration)
            self.class.new(new_duration, exception)
          end

          def with_appended_backtrace(step)
            exception.backtrace << step.backtrace_line if step.respond_to?(:backtrace_line)
            self
          end

          def with_filtered_backtrace(filter)
            self.class.new(duration, filter.new(exception.dup).exception)
          end
        end

        # Base class for exceptions that can be raised in a step defintion causing
        # the step to have that result.
        class Raisable < StandardError
          attr_reader :message, :duration

          def initialize(message = "", duration = UnknownDuration.new, backtrace = nil)
            @message, @duration = message, duration
            super(message)
            set_backtrace(backtrace) if backtrace
          end

          def with_message(new_message)
            self.class.new(new_message, duration, backtrace)
          end

          def with_duration(new_duration)
            self.class.new(message, new_duration, backtrace)
          end

          def with_appended_backtrace(step)
            return self unless step.respond_to?(:backtrace_line)
            set_backtrace([]) unless backtrace
            backtrace << step.backtrace_line
            self
          end

          def with_filtered_backtrace(filter)
            return self unless backtrace
            filter.new(dup).exception
          end
        end

        class Undefined < Raisable
          include Result.query_methods :undefined

          def describe_to(visitor, *args)
            visitor.undefined(*args)
            visitor.duration(duration, *args)
            self
          end

          def to_s
            "?"
          end

          def ok?(be_strict = false)
            !be_strict
          end
        end

        class Skipped < Raisable
          include Result.query_methods :skipped

          def describe_to(visitor, *args)
            visitor.skipped(*args)
            visitor.duration(duration, *args)
            self
          end

          def to_s
            "-"
          end

          def ok?(be_strict = false)
            true
          end
        end

        class Pending < Raisable
          include Result.query_methods :pending

          def describe_to(visitor, *args)
            visitor.pending(self, *args)
            visitor.duration(duration, *args)
            self
          end

          def to_s
            "P"
          end

          def ok?(be_strict = false)
            !be_strict
          end
        end

        #
        # An object that responds to the description protocol from the results
        # and collects summary information.
        #
        # e.g.
        #     summary = Result::Summary.new
        #     Result::Passed.new(0).describe_to(summary)
        #     puts summary.total_passed
        #     => 1
        #
        class Summary
          attr_reader :exceptions, :durations

          def initialize
            @totals = Hash.new { 0 }
            @exceptions = []
            @durations = []
          end

          def method_missing(name, *args)
            if name =~ /^total_/
              get_total(name)
            else
              increment_total(name)
            end
          end

          def exception(exception)
            @exceptions << exception
            self
          end

          def duration(duration)
            @durations << duration
            self
          end

          def total(for_status = nil)
            if for_status
              @totals.fetch(for_status) { 0 }
            else
              @totals.reduce(0) { |total, status| total += status[1] }
            end
          end

          private

          def get_total(method_name)
            status = method_name.to_s.gsub('total_', '').to_sym
            return @totals.fetch(status) { 0 }
          end

          def increment_total(status)
            @totals[status] += 1
            self
          end
        end

        class Duration
          attr_reader :nanoseconds

          def initialize(nanoseconds)
            @nanoseconds = nanoseconds
          end
        end

        class UnknownDuration
          def tap(&block)
            self
          end

          def nanoseconds
            raise "#nanoseconds only allowed to be used in #tap block"
          end
        end
      end
    end
  end
end
