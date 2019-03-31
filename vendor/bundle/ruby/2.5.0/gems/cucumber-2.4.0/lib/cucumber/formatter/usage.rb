require 'cucumber/formatter/progress'
require 'cucumber/step_definition_light'

module Cucumber
  module Formatter
    class Usage < Progress
      include Console

      class StepDefKey < StepDefinitionLight
        attr_accessor :mean_duration, :status
      end

      def initialize(runtime, path_or_io, options)
        @runtime = runtime
        @io = ensure_io(path_or_io)
        @options = options
        @stepdef_to_match = Hash.new { |h, stepdef_key| h[stepdef_key] = [] }
        @total_duration = 0
        @matches = {}
        runtime.configuration.on_event :step_match do |event|
          @matches[event.test_step.source] = event.step_match
        end
      end

      def after_test_step(test_step, result)
        return if HookQueryVisitor.new(test_step).hook?

        step_match = @matches[test_step.source]
        step_definition = step_match.step_definition
        stepdef_key = StepDefKey.new(step_definition.regexp_source, step_definition.location)
        unless @stepdef_to_match[stepdef_key].map { |key| key[:location] }.include? test_step.location
          duration = DurationExtractor.new(result).result_duration

          @stepdef_to_match[stepdef_key] << {
            keyword: test_step.source.last.keyword,
            step_match: step_match,
            status: result.to_sym,
            location: test_step.location,
            duration: duration
          }
        end
        super
      end

      private

      def print_summary
        add_unused_stepdefs
        aggregate_info

        if @options[:dry_run]
          keys = @stepdef_to_match.keys.sort {|a,b| a.regexp_source <=> b.regexp_source}
        else
          keys = @stepdef_to_match.keys.sort {|a,b| a.mean_duration <=> b.mean_duration}.reverse
        end

        keys.each do |stepdef_key|
          print_step_definition(stepdef_key)

          if @stepdef_to_match[stepdef_key].any?
            print_steps(stepdef_key)
          else
            @io.puts("  " + format_string("NOT MATCHED BY ANY STEPS", :failed))
          end
        end
        @io.puts
        super
      end

      def print_step_definition(stepdef_key)
        @io.print format_string(sprintf("%.7f", stepdef_key.mean_duration), :skipped) + " " unless @options[:dry_run]
        @io.print format_string(stepdef_key.regexp_source, stepdef_key.status)
        if @options[:source]
          indent = max_length - stepdef_key.regexp_source.unpack('U*').length
          line_comment = "   # #{stepdef_key.location}".indent(indent)
          @io.print(format_string(line_comment, :comment))
        end
        @io.puts
      end

      def print_steps(stepdef_key)
        @stepdef_to_match[stepdef_key].each do |step|
          @io.print "  "
          @io.print format_string(sprintf("%.7f", step[:duration]), :skipped) + " " unless @options[:dry_run]
          @io.print format_step(step[:keyword], step[:step_match], step[:status], nil)
          if @options[:source]
            indent = max_length - (step[:keyword].unpack('U*').length + step[:step_match].format_args.unpack('U*').length)
            line_comment = " # #{step[:location]}".indent(indent)
            @io.print(format_string(line_comment, :comment))
          end
          @io.puts
        end
      end

      def max_length
        [max_stepdef_length, max_step_length].compact.max
      end

      def max_stepdef_length
        @stepdef_to_match.keys.flatten.map{|key| key.regexp_source.unpack('U*').length}.max
      end

      def max_step_length
        @stepdef_to_match.values.to_a.flatten.map do |step|
          step[:keyword].unpack('U*').length + step[:step_match].format_args.unpack('U*').length
        end.max
      end

      def aggregate_info
        @stepdef_to_match.each do |key, steps|
          if steps.empty?
            key.status = :skipped
            key.mean_duration = 0
          else
            key.status = worst_status(steps.map{ |step| step[:status] })
            total_duration = steps.inject(0) {|sum, step| step[:duration] + sum}
            key.mean_duration = total_duration / steps.length
          end
        end
      end

      def worst_status(statuses)
        [:passed, :undefined, :pending, :skipped, :failed].find do |status|
          statuses.include?(status)
        end
      end

      def add_unused_stepdefs
        @runtime.unmatched_step_definitions.each do |step_definition|
          stepdef_key = StepDefKey.new(step_definition.regexp_source, step_definition.location)
          @stepdef_to_match[stepdef_key] = []
        end
      end
    end
  end
end
