require 'cucumber/core/test/timer'

module Cucumber
  module Core
    module Test
      class Runner
        attr_reader :report, :running_test_case, :running_test_step
        private :report, :running_test_case, :running_test_step

        def initialize(report)
          @report = report
        end

        def test_case(test_case, &descend)
          @running_test_case = RunningTestCase.new
          @running_test_step = nil
          report.before_test_case(test_case)
          descend.call(self)
          report.after_test_case(test_case, running_test_case.result)
          self
        end

        def test_step(test_step)
          @running_test_step = test_step
          report.before_test_step test_step
          step_result = running_test_case.execute(test_step)
          report.after_test_step test_step, step_result
          @running_test_step = nil
          self
        end

        def around_hook(hook, &continue)
          result = running_test_case.execute(hook, &continue)
          report.after_test_step running_test_step, result if running_test_step
          @running_test_step = nil
          self
        end

        def done
          report.done
          self
        end

        class RunningTestCase
          def initialize
            @timer = Timer.new.start
            @status = Status::Unknown.new(Result::Unknown.new)
          end

          def execute(test_step, &continue)
            status.execute(test_step, self, &continue)
          end

          def result
            status.result(@timer.duration)
          end

          def failed(step_result)
            @status = Status::Failing.new(step_result)
            self
          end

          def passed(step_result)
            @status = Status::Passing.new(step_result)
            self
          end

          def pending(message, step_result)
            @status = Status::Pending.new(step_result)
            self
          end

          def skipped(step_result)
            @status = Status::Skipping.new(step_result)
            self
          end

          def undefined(step_result)
            failed(step_result)
            self
          end

          def exception(step_exception, step_result)
            self
          end

          def duration(step_duration, step_result)
            self
          end

          attr_reader :status
          private :status

          module Status
            class Base
              attr_reader :step_result
              private :step_result

              def initialize(step_result)
                @step_result = step_result
              end

              def execute(test_step, monitor, &continue)
                result = test_step.execute(monitor.result, &continue)
                result = result.with_message(%(Undefined step: "#{test_step.name}")) if result.undefined?
                result = result.with_appended_backtrace(test_step.source.last) if IsStepVisitor.new(test_step).step?
                result.describe_to(monitor, result)
              end

              def result
                raise NoMethodError, "Override me"
              end
            end

            class Unknown < Base
              def result(duration)
                Result::Unknown.new
              end
            end

            class Passing < Base
              def result(duration)
                Result::Passed.new(duration)
              end
            end

            class Failing < Base
              def execute(test_step, monitor, &continue)
                test_step.skip(monitor.result)
              end

              def result(duration)
                step_result.with_duration(duration)
              end
            end

            Pending = Class.new(Failing)

            class Skipping < Failing
              def result(duration)
                step_result.with_duration(duration)
              end
            end
          end
        end

      end
    end
  end
end
