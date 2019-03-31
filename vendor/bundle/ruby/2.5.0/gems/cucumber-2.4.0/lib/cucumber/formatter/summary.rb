module Cucumber
  module Formatter
    module Summary

      def scenario_summary(runtime, &block)
        scenarios_proc = lambda{|status| runtime.scenarios(status)}
        dump_count(runtime.scenarios.length, "scenario") + dump_status_counts(scenarios_proc, &block)
      end

      def step_summary(runtime, &block)
        steps_proc = lambda{|status| runtime.steps(status)}
        dump_count(runtime.steps.length, "step") + dump_status_counts(steps_proc, &block)
      end

      private

      def dump_status_counts(find_elements_proc)
        counts = [:failed, :skipped, :undefined, :pending, :passed].map do |status|
          elements = find_elements_proc.call(status)
          elements.any? ? yield("#{elements.length} #{status.to_s}", status) : nil
        end.compact
        if counts.any?
          " (#{counts.join(', ')})"
        else
          ""
        end
      end

      def dump_count(count, what, state=nil)
        [count, state, "#{what}#{count == 1 ? '' : 's'}"].compact.join(" ")
      end

    end
  end
end
