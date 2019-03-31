require 'builder'
require 'cucumber/formatter/backtrace_filter'
require 'cucumber/formatter/io'
require 'cucumber/formatter/interceptor'
require 'fileutils'

module Cucumber
  module Formatter
    # The formatter used for <tt>--format junit</tt>
    class Junit

      include Io

      class UnNamedFeatureError < StandardError
        def initialize(feature_file)
          super("The feature in '#{feature_file}' does not have a name. The JUnit XML format requires a name for the testsuite element.")
        end
      end

      def initialize(config)
        config.on_event :before_test_case, &method(:on_before_test_case)
        config.on_event :after_test_case, &method(:on_after_test_case)
        config.on_event :after_test_step, &method(:on_after_test_step)
        config.on_event :finished_testing, &method(:on_finished_testing)
        @reportdir = ensure_dir(config.out_stream, "junit")
        @config = config
        @features_data = Hash.new { |h,k| h[k] = {
          feature: nil,
          failures: 0,
          errors: 0,
          tests: 0,
          skipped: 0,
          time: 0,
          builder: Builder::XmlMarkup.new(:indent => 2)
        }}
      end

      def on_before_test_case(event)
        test_case = event.test_case
        unless same_feature_as_previous_test_case?(test_case.feature)
          start_feature(test_case.feature)
        end
        @failing_step_source = nil
        # In order to fill out <system-err/> and <system-out/>, we need to
        # intercept the $stderr and $stdout
        @interceptedout = Interceptor::Pipe.wrap(:stdout)
        @interceptederr = Interceptor::Pipe.wrap(:stderr)
      end

      def on_after_test_step(event)
        return if @failing_step_source

        @failing_step_source = event.test_step.source.last unless event.result.ok?(@config.strict?)
      end

      def on_after_test_case(event)
        test_case = event.test_case
        result = event.result.with_filtered_backtrace(Cucumber::Formatter::BacktraceFilter)
        test_case_name = NameBuilder.new(test_case)
        scenario = test_case_name.scenario_name
        scenario_designation = "#{scenario}#{test_case_name.name_suffix}"
        output = create_output_string(test_case, scenario, result, test_case_name.row_name)
        build_testcase(result, scenario_designation, output)

        Interceptor::Pipe.unwrap! :stdout
        Interceptor::Pipe.unwrap! :stderr
      end

      def on_finished_testing(event)
        @features_data.each { |file, data| end_feature(data) }
      end

      private

      def same_feature_as_previous_test_case?(feature)
        @current_feature_data && @current_feature_data[:feature].file == feature.file && @current_feature_data[:feature].location == feature.location
      end

      def start_feature(feature)
        raise UnNamedFeatureError.new(feature.file) if feature.name.empty?
        @current_feature_data = @features_data[feature.file]
        @current_feature_data[:feature] = feature unless @current_feature_data[:feature]
      end

      def end_feature(feature_data)
        @testsuite = Builder::XmlMarkup.new(:indent => 2)
        @testsuite.instruct!
        @testsuite.testsuite(
          :failures => feature_data[:failures],
          :errors => feature_data[:errors],
          :skipped => feature_data[:skipped],
          :tests => feature_data[:tests],
          :time => "%.6f" % feature_data[:time],
          :name => feature_data[:feature].name ) do
          @testsuite << feature_data[:builder].target!
        end

        write_file(feature_result_filename(feature_data[:feature].file), @testsuite.target!)
      end

      def create_output_string(test_case, scenario, result, row_name)
        output = "#{test_case.keyword}: #{scenario}\n\n"
        return output if result.ok?(@config.strict?)
        if test_case.keyword == "Scenario"
          output += "#{@failing_step_source.keyword}" unless hook?(@failing_step_source)
          output += "#{@failing_step_source.name}\n"
        else
          output += "Example row: #{row_name}\n"
        end
        output + "\nMessage:\n"
      end

      def hook?(step)
        ["Before hook", "After hook", "AfterStep hook"].include? step.name
      end

      def build_testcase(result, scenario_designation, output)
        duration = ResultBuilder.new(result).test_case_duration
        @current_feature_data[:time] += duration
        classname = @current_feature_data[:feature].name
        name = scenario_designation

        @current_feature_data[:builder].testcase(:classname => classname, :name => name, :time => "%.6f" % duration) do
          if !result.passed? && result.ok?(@config.strict?)
            @current_feature_data[:builder].skipped
            @current_feature_data[:skipped] += 1
          elsif !result.passed?
            status = result.to_sym
            exception = get_backtrace_object(result)
            @current_feature_data[:builder].failure(:message => "#{status} #{name}", :type => status) do
              @current_feature_data[:builder].cdata! output
              @current_feature_data[:builder].cdata!(format_exception(exception)) if exception
            end
            @current_feature_data[:failures] += 1
          end
          @current_feature_data[:builder].tag!('system-out') do
            @current_feature_data[:builder].cdata! strip_control_chars(@interceptedout.buffer.join)
          end
          @current_feature_data[:builder].tag!('system-err') do
            @current_feature_data[:builder].cdata! strip_control_chars(@interceptederr.buffer.join)
          end
        end
        @current_feature_data[:tests] += 1
      end

      def get_backtrace_object(result)
        if result.failed?
          return result.exception
        elsif result.backtrace
          return result
        else
          return nil
        end
      end

      def format_exception(exception)
        (["#{exception.message} (#{exception.class})"] + exception.backtrace).join("\n")
      end

      def feature_result_filename(feature_file)
        File.join(@reportdir, "TEST-#{basename(feature_file)}.xml")
      end

      def basename(feature_file)
        File.basename(feature_file.gsub(/[\\\/]/, '-'), '.feature')
      end

      def write_file(feature_filename, data)
        File.open(feature_filename, 'w') { |file| file.write(data) }
      end

      # strip control chars from cdata, to make it safe for external parsers
      def strip_control_chars(cdata)
        cdata.scan(/[[:print:]\t\n\r]/).join
      end

    end

    class NameBuilder
      attr_reader :scenario_name, :name_suffix, :row_name

      def initialize(test_case)
        @name_suffix = ""
        @row_name = ""
        test_case.describe_source_to self
      end

      def feature(*)
        self
      end

      def scenario(scenario)
        @scenario_name = (scenario.name.nil? || scenario.name == "") ? "Unnamed scenario" : scenario.name
        self
      end

      def scenario_outline(outline)
        @scenario_name = (outline.name.nil? || outline.name == "") ? "Unnamed scenario outline" : outline.name
        self
      end

      def examples_table(*)
        self
      end

      def examples_table_row(row)
        @row_name = '| ' + row.values.join(' | ') + ' |'
        @name_suffix = " (outline example : #{@row_name})"
        self
      end
    end

    class ResultBuilder
      attr_reader :test_case_duration
      def initialize(result)
        @test_case_duration = 0
        result.describe_to(self)
      end

      def passed(*) end

      def failed(*) end

      def undefined(*) end

      def skipped(*) end

      def pending(*) end

      def exception(*) end

      def duration(duration, *)
        duration.tap { |duration| @test_case_duration = duration.nanoseconds / 10**9.0 }
      end
    end

  end
end
