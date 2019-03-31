require 'cucumber/formatter/ansicolor'
require 'cucumber/formatter/duration'
require 'cucumber/formatter/summary'

module Cucumber
  module Formatter

    # This module contains helper methods that are used by formatters that
    # print output to the terminal.
    #
    # FORMAT is a hash of Proc objects, keyed by step-definition types, e.g.
    # "FORMAT[:passed]".  The Proc is called for each line of the step's
    # output.
    #
    # format_step calls format_string, format_string calls format_for to obtain
    # the formatting Proc.
    #
    # Example:
    #
    # The ANSI color console formatter defines a map of step-type to output
    # color (e.g. "passed" to "green"), then builds methods named for the
    # step-types (e.g. "def passed"), which themselves wrap the corresponding
    # color-named methods provided by Term::ANSIColor (e.g. "def red").
    #
    # During output, each line is processed by passing it to the formatter Proc
    # which returns the formatted (e.g. colored) string.

    module Console
      extend ANSIColor
      include Duration
      include Summary

      def format_step(keyword, step_match, status, source_indent)
        comment = if source_indent
          c = ('# ' + step_match.location.to_s).indent(source_indent)
          format_string(c, :comment)
        else
          ''
        end

        format = format_for(status, :param)
        line = keyword + step_match.format_args(format) + comment
        format_string(line, status)
      end

      def format_string(o, status)
        fmt = format_for(status)
        o.to_s.split("\n").map do |line|
          if Proc === fmt
            fmt.call(line)
          else
            fmt % line
          end
        end.join("\n")
      end

      def print_steps(status)
        print_elements(runtime.steps(status), status, 'steps')
      end

      def print_elements(elements, status, kind)
        if elements.any?
          @io.puts(format_string("(::) #{status} #{kind} (::)", status))
          @io.puts
          @io.flush
        end

        elements.each_with_index do |element, i|
          if status == :failed
            print_exception(element.exception, status, 0)
          else
            message = linebreaks(element.backtrace_line, ENV['CUCUMBER_TRUNCATE_OUTPUT'].to_i)
            @io.puts(format_string(message, status))
          end
          @io.puts
          @io.flush
        end
      end

      def print_stats(features, options)
        duration = features ? features.duration : nil
        print_statistics(duration, options)
      end

      def print_statistics(duration, options)
        failures = collect_failing_scenarios(runtime)
        if !failures.empty?
          print_failing_scenarios(failures, options.custom_profiles, options[:source])
        end

        @io.puts scenario_summary(runtime) {|status_count, status| format_string(status_count, status)}
        @io.puts step_summary(runtime) {|status_count, status| format_string(status_count, status)}
        @io.puts(format_duration(duration)) if duration && options[:duration]

        if runtime.configuration.randomize?
          @io.puts
          @io.puts "Randomized with seed #{runtime.configuration.seed}"
        end

        @io.flush
      end

      def collect_failing_scenarios(runtime)
        # TODO: brittle - stop coupling to types
        scenario_class = LegacyApi::Ast::Scenario
        example_table_class = Core::Ast::ExamplesTable

        runtime.scenarios(:failed).select do |s|
          [scenario_class, example_table_class].include?(s.class)
        end.map do |s|
          s.is_a?(example_table_class)? s.scenario_outline : s
        end
      end

      def print_failing_scenarios(failures, custom_profiles, given_source)
        @io.puts format_string("Failing Scenarios:", :failed)
        failures.each do |failure|
          profiles_string = custom_profiles.empty? ? '' : (custom_profiles.map{|profile| "-p #{profile}" }).join(' ') + ' '
          source = given_source ? format_string(" # " + failure.name, :comment) : ''
          @io.puts format_string("cucumber #{profiles_string}" + failure.location, :failed) + source
        end
        @io.puts
      end

      def print_exception(e, status, indent)
        message = "#{e.message} (#{e.class})".force_encoding("UTF-8")
        message = linebreaks(message, ENV['CUCUMBER_TRUNCATE_OUTPUT'].to_i)

        string = "#{message}\n#{e.backtrace.join("\n")}".indent(indent)
        @io.puts(format_string(string, status))
      end

      # http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/10655
      def linebreaks(s, max)
        return s unless max && max > 0
        s.gsub(/.{1,#{max}}(?:\s|\Z)/){($& + 5.chr).gsub(/\n\005/,"\n").gsub(/\005/,"\n")}.rstrip
      end

      def collect_snippet_data(test_step, result)
        # collect snippet data for undefined steps
        unless hook?(test_step)
          keyword = test_step.source.last.actual_keyword(@previous_step_keyword)
          @previous_step_keyword = keyword
          if result.undefined?
            @snippets_input << Console::SnippetData.new(keyword, test_step.source.last)
          end
        end
      end

      def print_snippets(options)
        return unless options[:snippets]
        return if runtime.steps(:undefined).empty?

        snippets = @snippets_input.map do |data|
          @runtime.snippet_text(data.actual_keyword, data.step.name, data.step.multiline_arg)
        end.uniq

        text = "\nYou can implement step definitions for undefined steps with these snippets:\n\n"
        text += snippets.join("\n\n")
        @io.puts format_string(text, :undefined)

        @io.puts
        @io.flush
      end

      def print_passing_wip(options)
        return unless options[:wip]
        passed = runtime.scenarios(:passed)
        if passed.any?
          @io.puts format_string("\nThe --wip switch was used, so I didn't expect anything to pass. These scenarios passed:", :failed)
          print_elements(passed, :passed, "scenarios")
        else
          @io.puts format_string("\nThe --wip switch was used, so the failures were expected. All is good.\n", :passed)
        end
      end

      def embed(file, mime_type, label)
        # no-op
      end

      #define @delayed_messages = [] in your Formatter if you want to
      #activate this feature
      def puts(*messages)
        if @delayed_messages
          @delayed_messages += messages
        else
          if @io
            @io.puts
            messages.each do |message|
              @io.puts(format_string(message, :tag))
            end
            @io.flush
          end
        end
      end

      def print_messages
        @delayed_messages.each {|message| print_message(message)}
        empty_messages
      end

      def print_table_row_messages
        return if @delayed_messages.empty?
        @io.print(format_string(@delayed_messages.join(', '), :tag).indent(2))
        @io.flush
        empty_messages
      end

      def print_message(message)
        @io.puts(format_string(message, :tag).indent(@indent))
        @io.flush
      end

      def empty_messages
        @delayed_messages = []
      end

      def print_profile_information
        return if @options[:skip_profile_information] || @options[:profiles].nil? || @options[:profiles].empty?
        profiles = @options[:profiles]
        profiles_sentence = ''
        profiles_sentence = profiles.size == 1 ? profiles.first :
          "#{profiles[0...-1].join(', ')} and #{profiles.last}"

        @io.puts "Using the #{profiles_sentence} profile#{'s' if profiles.size> 1}..."
      end

      private

      FORMATS = Hash.new{ |hash, format| hash[format] = method(format).to_proc }

      def format_for(*keys)
        key = keys.join('_').to_sym
        fmt = FORMATS[key]
        raise "No format for #{key.inspect}: #{FORMATS.inspect}" if fmt.nil?
        fmt
      end

      def hook?(test_step)
        not test_step.source.last.respond_to?(:actual_keyword)
      end

      class SnippetData
        attr_reader :actual_keyword, :step
        def initialize(actual_keyword, step)
          @actual_keyword, @step = actual_keyword, step
        end
      end

    end
  end
end
