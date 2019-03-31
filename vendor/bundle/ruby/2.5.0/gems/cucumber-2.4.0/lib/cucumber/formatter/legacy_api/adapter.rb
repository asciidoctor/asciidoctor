require 'forwardable'
require 'delegate'
require 'cucumber/errors'
require 'cucumber/multiline_argument'
require 'cucumber/formatter/backtrace_filter'
require 'cucumber/formatter/legacy_api/ast'

module Cucumber
  module Formatter
    module LegacyApi

      Adapter = Struct.new(:formatter, :results, :config) do
        extend Forwardable

        def initialize(*)
          super
          @matches = collect_matches
        end

        def_delegators :formatter,
          :ask

        def_delegators :printer,
          :embed

        def before_test_case(test_case)
          formatter.before_test_case(test_case)
          printer.before_test_case(test_case)
        end

        def before_test_step(test_step)
          formatter.before_test_step(test_step)
          printer.before_test_step(test_step)
        end

        def after_test_step(test_step, result)
          printer.after_test_step(test_step, result)
          formatter.after_test_step(test_step, result.with_filtered_backtrace(Cucumber::Formatter::BacktraceFilter))
        end

        def after_test_case(test_case, result)
          record_test_case_result(test_case, result)
          printer.after_test_case(test_case, result)
          formatter.after_test_case(test_case, result.with_filtered_backtrace(Cucumber::Formatter::BacktraceFilter))
        end

        def puts(*messages)
          printer.puts(messages)
        end

        def done
          printer.after
          formatter.done
        end

        private

        def printer
          @printer ||= FeaturesPrinter.new(formatter, results, config, @matches).before
        end

        def record_test_case_result(test_case, result)
          scenario = LegacyResultBuilder.new(result).scenario("#{test_case.keyword}: #{test_case.name}", test_case.location)
          results.scenario_visited(scenario)
        end

        def collect_matches
          result = {}
          config.on_event(:step_match) do |event|
            result[event.test_step.source.last] = event.step_match
          end
          result
        end

        require 'cucumber/core/test/timer'
        FeaturesPrinter = Struct.new(:formatter, :results, :config, :matches) do
          extend Forwardable

          def before
            timer.start
            formatter.before_features(nil)
            self
          end

          def before_test_case(test_case)
            test_case.describe_source_to(self)
            @child.before_test_case(test_case)
          end

          def before_test_step(*args)
            @child.before_test_step(*args)
          end

          def after_test_step(test_step, result)
            @child.after_test_step(test_step, result)
          end

          def after_test_case(*args)
            @child.after_test_case(*args)
          end

          def feature(node, *)
            if node != @current_feature
              @child.after if @child
              @child = FeaturePrinter.new(formatter, results, matches, config, node).before
              @current_feature = node
            end
          end

          def scenario(node, *)
          end

          def scenario_outline(node, *)
          end

          def examples_table(node, *)
          end

          def examples_table_row(node, *)
          end

          def after
            @child.after if @child
            formatter.after_features Ast::Features.new(timer.sec)
            self
          end

          def puts(messages)
            @child.puts(messages)
          end

          def embed(src, mime_type, label)
            @child.embed(src, mime_type, label)
          end

          private

          def timer
            @timer ||= Cucumber::Core::Test::Timer.new
          end

        end

        module TestCaseSource
          def self.for(test_case, result)
            collector = Collector.new
            test_case.describe_source_to collector, result
            collector.result.freeze
          end

          class Collector
            attr_reader :result

            def initialize
              @result = CaseSource.new
            end

            def method_missing(name, node, test_case_result, *args)
              result.send "#{name}=", node
            end
          end

          require 'ostruct'
          class CaseSource < OpenStruct
          end
        end

        module TestStepSource
          def self.for(test_step, result)
            collector = Collector.new
            test_step.describe_source_to collector, result
            collector.result.freeze
          end

          class Collector
            attr_reader :result

            def initialize
              @result = StepSource.new
            end

            def method_missing(name, node, step_result, *args)
              result.send "#{name}=", node
              result.send "#{name}_result=", LegacyResultBuilder.new(step_result)
            end
          end

          require 'ostruct'
          class StepSource < OpenStruct
            def build_step_invocation(indent, matches, config, messages, embeddings)
              step_result.step_invocation(
                matches.fetch(step) { NoStepMatch.new(step, step.name) },
                step,
                indent,
                background,
                config,
                messages,
                embeddings
              )
            end
          end

        end

        Embedding = Struct.new(:src, :mime_type, :label) do

          def send_to_formatter(formatter)
            formatter.embed(src, mime_type, label)
          end
        end

        FeaturePrinter = Struct.new(:formatter, :results, :matches, :config, :node) do

          def before
            formatter.before_feature(node)
            language_comment = node.language.iso_code != 'en' ? ["# language: #{node.language.iso_code}"] : []
            Ast::Comments.new(language_comment + node.comments).accept(formatter)
            Ast::Tags.new(node.tags).accept(formatter)
            formatter.feature_name node.keyword, node.legacy_conflated_name_and_description
            @delayed_messages = []
            @delayed_embeddings = []
            self
          end

          attr_reader :current_test_step_source

          def before_test_case(test_case)
            @before_hook_results = Ast::HookResultCollection.new
            @test_step_results = []
          end

          def before_test_step(test_step)
          end

          def after_test_step(test_step, result)
            @current_test_step_source = TestStepSource.for(test_step, result)
            # TODO: stop calling self, and describe source to another object
            test_step.describe_source_to(self, result)
            print_step
            @test_step_results << result
          end

          def after_test_case(test_case, test_case_result)
            if current_test_step_source && current_test_step_source.step_result.nil?
              switch_step_container
            end

            if test_case_result.failed? && !any_test_steps_failed?
              # around hook must have failed. Print the error.
              switch_step_container(TestCaseSource.for(test_case, test_case_result))
              LegacyResultBuilder.new(test_case_result).describe_exception_to formatter
            end

            # messages and embedding should already have been handled, but just in case...
            @delayed_messages.each { |message| formatter.puts(message) }
            @delayed_embeddings.each { |embedding| embedding.send_to_formatter(formatter) }
            @delayed_messages = []
            @delayed_embeddings = []

            @child.after_test_case(test_case, test_case_result) if @child
            @previous_test_case_background = @current_test_case_background
            @previous_test_case_scenario_outline = current_test_step_source && current_test_step_source.scenario_outline
          end

          def before_hook(location, result)
            @before_hook_results << Ast::HookResult.new(LegacyResultBuilder.new(result), @delayed_messages, @delayed_embeddings)
            @delayed_messages = []
            @delayed_embeddings = []
          end

          def after_hook(location, result)
            # if the scenario has no steps, we can hit this before we've created the scenario printer
            # ideally we should call switch_step_container in before_step_step
            switch_step_container if !@child 
            @child.after_hook Ast::HookResult.new(LegacyResultBuilder.new(result), @delayed_messages, @delayed_embeddings)
            @delayed_messages = []
            @delayed_embeddings = []
          end

          def after_step_hook(hook, result)
            p current_test_step_source if current_test_step_source.step.nil?
            line = current_test_step_source.step.backtrace_line
            @child.after_step_hook Ast::HookResult.new(LegacyResultBuilder.new(result).
              append_to_exception_backtrace(line), @delayed_messages, @delayed_embeddings)
            @delayed_messages = []
            @delayed_embeddings = []
          end

          def background(node, *)
            @current_test_case_background = node
          end

          def puts(messages)
            @delayed_messages.push *messages
          end

          def embed(src, mime_type, label)
            @delayed_embeddings.push Embedding.new(src, mime_type, label)
          end

          def step(*);end
          def scenario(*);end
          def scenario_outline(*);end
          def examples_table(*);end
          def examples_table_row(*);end
          def feature(*);end

          def after
            @child.after if @child
            formatter.after_feature(node)
            self
          end

          private

          attr_reader :before_hook_results
          private :before_hook_results

          def any_test_steps_failed?
            @test_step_results.any? &:failed?
          end

          def switch_step_container(source = current_test_step_source)
            switch_to_child select_step_container(source), source
          end

          def select_step_container(source)
            if source.background
              if same_background_as_previous_test_case?(source)
                HiddenBackgroundPrinter.new(formatter, source.background)
              else
                BackgroundPrinter.new(formatter, node, source.background, before_hook_results)
              end
            elsif source.scenario
              ScenarioPrinter.new(formatter, source.scenario, before_hook_results)
            elsif source.scenario_outline
              if same_scenario_outline_as_previous_test_case?(source) and @previous_outline_child
                @previous_outline_child
              else
                ScenarioOutlinePrinter.new(formatter, config, source.scenario_outline)
              end
            else
              raise 'unknown step container'
            end
          end

          def same_background_as_previous_test_case?(source)
            source.background == @previous_test_case_background
          end

          def same_scenario_outline_as_previous_test_case?(source)
            source.scenario_outline == @previous_test_case_scenario_outline
          end

          def print_step
            return unless current_test_step_source.step_result
            switch_step_container

            if current_test_step_source.scenario_outline
              @child.examples_table(current_test_step_source.examples_table)
              @child.examples_table_row(current_test_step_source.examples_table_row, before_hook_results)
            end

            if @failed_hidden_background_step
              indent = Indent.new(@child.node)
              step_invocation = @failed_hidden_background_step.build_step_invocation(indent, matches, config, messages = [], embeddings = [])
              @child.step_invocation(step_invocation, @failed_hidden_background_step)
              @failed_hidden_background_step = nil
            end

            unless @last_step == current_test_step_source.step
              indent ||= Indent.new(@child.node)
              step_invocation = current_test_step_source.build_step_invocation(indent, matches, config, @delayed_messages, @delayed_embeddings)
              results.step_visited step_invocation
              @child.step_invocation(step_invocation, current_test_step_source)
              @last_step = current_test_step_source.step
            end
            @delayed_messages = []
            @delayed_embeddings = []
          end

          def switch_to_child(child, source)
            return if @child == child
            if @child
              if from_first_background(@child)
                @first_background_failed = @child.failed?
              elsif from_hidden_background(@child)
                if not @first_background_failed
                  @failed_hidden_background_step = @child.get_failed_step_source
                end
                if @previous_outline_child
                  @previous_outline_child.after unless same_scenario_outline_as_previous_test_case?(source)
                end
              end
              unless from_scenario_outline_to_hidden_backgroud(@child, child)
                @child.after 
                @previous_outline_child = nil
              else
                @previous_outline_child = @child
              end
            end
            child.before unless to_scenario_outline(child) and same_scenario_outline_as_previous_test_case?(source)
            @child = child
          end

          def from_scenario_outline_to_hidden_backgroud(from, to)
            from.class.name == ScenarioOutlinePrinter.name and
            to.class.name == HiddenBackgroundPrinter.name
          end

          def from_first_background(from)
            from.class.name == BackgroundPrinter.name
          end

          def from_hidden_background(from)
            from.class.name == HiddenBackgroundPrinter.name
          end

          def to_scenario_outline(to)
            to.class.name == ScenarioOutlinePrinter.name
          end

        end

        module PrintsAfterHooks
          def after_hook_results
            @after_hook_results ||= Ast::HookResultCollection.new
          end

          def after_hook(result)
            after_hook_results << result
          end
        end

        # Basic printer used by default
        class AfterHookPrinter
          attr_reader :formatter

          def initialize(formatter)
            @formatter = formatter
          end

          include PrintsAfterHooks

          def after
            after_hook_results.accept(formatter)
          end
        end

        BackgroundPrinter = Struct.new(:formatter, :feature, :node, :before_hook_results) do

          def after_test_case(*)
          end

          def after_hook(*)
          end

          def before
            formatter.before_background Ast::Background.new(feature, node)
            Ast::Comments.new(node.comments).accept(formatter)
            formatter.background_name node.keyword, node.legacy_conflated_name_and_description, node.location.to_s, indent.of(node)
            before_hook_results.accept(formatter)
            self
          end

          def after_step_hook(result)
            result.accept formatter
          end

          def step_invocation(step_invocation, source)
            @child ||= StepsPrinter.new(formatter).before
            @child.step_invocation step_invocation
            if source.step_result.status == :failed
              @failed = true
            end
          end

          def after
            @child.after if @child
            formatter.after_background(Ast::Background.new(feature, node))
            self
          end

          def failed?
            @failed
          end

          private

          def indent
            @indent ||= Indent.new(node)
          end
        end

        # Printer to handle background steps for anything but the first scenario in a
        # feature. These steps should not be printed.
        class HiddenBackgroundPrinter < Struct.new(:formatter, :node)
          def get_failed_step_source
            return @source_of_failed_step
          end

          def step_invocation(step_invocation, source)
            if source.step_result.status == :failed
              @source_of_failed_step = source
            end
          end

          def before;self;end
          def after;self;end
          def before_hook(*);end
          def after_hook(*);end
          def after_step_hook(*);end
          def examples_table(*);end
          def after_test_case(*);end
        end

        ScenarioPrinter = Struct.new(:formatter, :node, :before_hook_results) do
          include PrintsAfterHooks

          def before
            formatter.before_feature_element(node)
            Ast::Comments.new(node.comments).accept(formatter)
            Ast::Tags.new(node.tags).accept(formatter)
            formatter.scenario_name node.keyword, node.legacy_conflated_name_and_description, node.location.to_s, indent.of(node)
            before_hook_results.accept(formatter)
            self
          end

          def step_invocation(step_invocation, source)
            @child ||= StepsPrinter.new(formatter).before
            @child.step_invocation step_invocation
          end

          def after_step_hook(result)
            result.accept formatter
          end

          def after_test_case(test_case, result)
            @test_case_result = result
            after
          end

          def after
            return if @done
            @child.after if @child
            scenario = LegacyResultBuilder.new(@test_case_result).scenario(node.name, node.location)
            after_hook_results.accept(formatter)
            formatter.after_feature_element(scenario)
            @done = true
            self
          end

          private

          def indent
            @indent ||= Indent.new(node)
          end
        end

        StepsPrinter = Struct.new(:formatter) do
          def before
            formatter.before_steps(nil)
            self
          end

          def step_invocation(step_invocation)
            steps << step_invocation
            step_invocation.accept(formatter)
            self
          end

          def after
            formatter.after_steps(steps)
            self
          end

          private

          def steps
            @steps ||= Ast::StepInvocations.new
          end

        end

        ScenarioOutlinePrinter = Struct.new(:formatter, :configuration, :node) do
          extend Forwardable
          def_delegators :@child, :after_hook, :after_step_hook

          def before
            formatter.before_feature_element(node)
            Ast::Comments.new(node.comments).accept(formatter)
            Ast::Tags.new(node.tags).accept(formatter)
            formatter.scenario_name node.keyword, node.legacy_conflated_name_and_description, node.location.to_s, indent.of(node)
            OutlineStepsPrinter.new(formatter, configuration, indent).print(node)
            self
          end

          def step_invocation(step_invocation, source)
            node, result = source.step, source.step_result
            @last_step_result = result
            @child.step_invocation(step_invocation, source)
          end

          def examples_table(examples_table)
            @child ||= ExamplesArrayPrinter.new(formatter, configuration).before
            @child.examples_table(examples_table)
          end

          def examples_table_row(node, before_hook_results)
            @child.examples_table_row(node, before_hook_results)
          end

          def after_test_case(test_case, result)
            @child.after_test_case(test_case, result)
          end

          def after
            @child.after if @child
            # TODO - the last step result might not accurately reflect the
            # overall scenario result.
            scenario_outline = last_step_result.scenario_outline(node.name, node.location)
            formatter.after_feature_element(scenario_outline)
            self
          end

          private

          def last_step_result
            @last_step_result || Core::Test::Result::Unknown.new
          end

          def indent
            @indent ||= Indent.new(node)
          end
        end

        OutlineStepsPrinter = Struct.new(:formatter, :configuration, :indent, :outline) do
          def print(node)
            node.describe_to self
            steps_printer.after
          end

          def scenario_outline(node, &descend)
            descend.call(self)
          end

          def outline_step(step)
            step_match = NoStepMatch.new(step, step.name)
            step_invocation = LegacyResultBuilder.new(Core::Test::Result::Skipped.new).
              step_invocation(step_match, step, indent, background = nil, configuration, messages = [], embeddings = [])
            steps_printer.step_invocation step_invocation
          end

          def examples_table(*);end

          private

          def steps_printer
            @steps_printer ||= StepsPrinter.new(formatter).before
          end
        end

        ExamplesArrayPrinter = Struct.new(:formatter, :configuration) do
          extend Forwardable
          def_delegators :@child, :step_invocation, :after_hook, :after_step_hook, :after_test_case, :examples_table_row

          def before
            formatter.before_examples_array(:examples_array)
            self
          end

          def examples_table(examples_table)
            return if examples_table == @current
            @child.after if @child
            @child = ExamplesTablePrinter.new(formatter, configuration, examples_table).before
            @current = examples_table
          end

          def after
            @child.after if @child
            formatter.after_examples_array
            self
          end
        end

        ExamplesTablePrinter = Struct.new(:formatter, :configuration, :node) do
          extend Forwardable
          def_delegators :@child, :step_invocation, :after_hook, :after_step_hook, :after_test_case

          def before
            formatter.before_examples(node)
            Ast::Comments.new(node.comments).accept(formatter)
            Ast::Tags.new(node.tags).accept(formatter)
            formatter.examples_name(node.keyword, node.legacy_conflated_name_and_description)
            formatter.before_outline_table(legacy_table)
            if !configuration.expand?
              HeaderTableRowPrinter.new(formatter, ExampleTableRow.new(node.header), Ast::Node.new).before.after
            end
            self
          end

          def examples_table_row(examples_table_row, before_hook_results)
            return if examples_table_row == @current
            @child.after if @child
            row = ExampleTableRow.new(examples_table_row)
            if !configuration.expand?
              @child = TableRowPrinter.new(formatter, row, before_hook_results).before
            else
              @child = ExpandTableRowPrinter.new(formatter, row, before_hook_results).before
            end
            @current = examples_table_row
          end

          def after_test_case(*args)
            @child.after_test_case(*args)
          end

          def after
            @child.after if @child
            formatter.after_outline_table(node)
            formatter.after_examples(node)
            self
          end

          private

          def legacy_table
            LegacyTable.new(node)
          end

          class ExampleTableRow < SimpleDelegator
            def dom_id
              file_colon_line.gsub(/[\/\.:]/, '_')
            end
          end

          LegacyTable = Struct.new(:node) do
            def col_width(index)
              max_width = FindMaxWidth.new(index)
              node.describe_to max_width
              max_width.result
            end

            require 'cucumber/gherkin/formatter/escaping'
            FindMaxWidth = Struct.new(:index) do
              include ::Cucumber::Gherkin::Formatter::Escaping

              def examples_table(table, &descend)
                @result = char_length_of(table.header.values[index])
                descend.call(self)
              end

              def examples_table_row(row, &descend)
                width = char_length_of(row.values[index])
                @result = width if width > result
              end

              def result
                @result ||= 0
              end

              private
              def char_length_of(cell)
                escape_cell(cell).unpack('U*').length
              end
            end
          end
        end

        class TableRowPrinterBase < Struct.new(:formatter, :node, :before_hook_results)
          include PrintsAfterHooks

          def after_step_hook(result)
            @after_step_hook_result ||= Ast::HookResultCollection.new
            @after_step_hook_result << result
          end

          def after_test_case(*args)
            after
          end

          private

          def indent
            :not_needed
          end

          def legacy_table_row
            Ast::ExampleTableRow.new(exception, @status, node.values, node.location, node.language)
          end

          def exception
            return nil unless @failed_step
            @failed_step.exception
          end
        end

        class HeaderTableRowPrinter < TableRowPrinterBase
          def legacy_table_row
            Ast::ExampleTableRow.new(exception, @status, node.values, node.location, Ast::NullLanguage.new)
          end

          def before
            Ast::Comments.new(node.comments).accept(formatter)
            formatter.before_table_row(node)
            self
          end

          def after
            node.values.each do |value|
              formatter.before_table_cell(value)
              formatter.table_cell_value(value, :skipped_param)
              formatter.after_table_cell(value)
            end
            formatter.after_table_row(legacy_table_row)
            self
          end
        end


        class TableRowPrinter < TableRowPrinterBase
          def before
            before_hook_results.accept(formatter)
            Ast::Comments.new(node.comments).accept(formatter)
            formatter.before_table_row(node)
            self
          end

          def step_invocation(step_invocation, source)
            result = source.step_result
            step_invocation.messages.each { |message| formatter.puts(message) }
            step_invocation.embeddings.each { |embedding| embedding.send_to_formatter(formatter) }
            @failed_step = step_invocation if result.status == :failed
            @status = step_invocation.status unless already_failed?
          end

          def after
            return if @done
            @child.after if @child
            node.values.each do |value|
              formatter.before_table_cell(value)
              formatter.table_cell_value(value, @status || :skipped)
              formatter.after_table_cell(value)
            end
            @after_step_hook_result.send_output_to(formatter) if @after_step_hook_result
            after_hook_results.send_output_to(formatter)
            formatter.after_table_row(legacy_table_row)
            @after_step_hook_result.describe_exception_to(formatter) if @after_step_hook_result
            after_hook_results.describe_exception_to(formatter)
            @done = true
            self
          end

          private

          def already_failed?
            @status == :failed || @status == :undefined || @status == :pending
          end
        end

        class ExpandTableRowPrinter < TableRowPrinterBase
          def before
            before_hook_results.accept(formatter)
            self
          end

          def step_invocation(step_invocation, source)
            result = source.step_result
            @table_row ||= legacy_table_row
            step_invocation.indent.record_width_of(@table_row)
            if !@scenario_name_printed
              print_scenario_name(step_invocation, @table_row)
              @scenario_name_printed = true
            end
            step_invocation.accept(formatter)
            @failed_step = step_invocation if result.status == :failed
            @status = step_invocation.status unless @status == :failed
          end

          def after
            return if @done
            @child.after if @child
            @after_step_hook_result.accept(formatter) if @after_step_hook_result
            after_hook_results.accept(formatter)
            @done = true
            self
          end

          private

          def print_scenario_name(step_invocation, table_row)
            formatter.scenario_name table_row.keyword, table_row.name, node.location.to_s, step_invocation.indent.of(table_row)
          end
        end

        class Indent
          def initialize(node)
            @widths = []
            node.describe_to(self)
          end

          [:background, :scenario, :scenario_outline].each do |node_name|
            define_method(node_name) do |node, &descend|
            record_width_of node
            descend.call(self)
            end
          end

          [:step, :outline_step].each do |node_name|
            define_method(node_name) do |node|
              record_width_of node
            end
          end

          def examples_table(*); end
          def examples_table_row(*); end

          def of(node)
            # The length of the instantiated steps in --expand mode are currently
            # not included in the calculation of max => make sure to return >= 1
            [1, max - node.name.length - node.keyword.length].max
          end

          def record_width_of(node)
            @widths << node.keyword.length + node.name.length + 1
          end

          private

          def max
            @widths.max
          end
        end

        class LegacyResultBuilder
          attr_reader :status
          def initialize(result)
            @result = result
            @result.describe_to(self)
          end

          def passed
            @status = :passed
          end

          def failed
            @status = :failed
          end

          def undefined
            @status = :undefined
          end

          def skipped
            @status = :skipped
          end

          def pending(exception, *)
            @exception = exception
            @status = :pending
          end

          def exception(exception, *)
            @exception = exception
          end

          def append_to_exception_backtrace(line)
            @exception.set_backtrace(@exception.backtrace + [line.to_s]) if @exception
            return self
          end

          def duration(duration, *)
            @duration = duration
          end

          def step_invocation(step_match, step, indent, background, configuration, messages, embeddings)
            Ast::StepInvocation.new(step_match, @status, @duration, step_exception(step, configuration), indent, background, step, messages, embeddings)
          end

          def scenario(name, location)
            Ast::Scenario.new(@status, name, location)
          end

          def scenario_outline(name, location)
            Ast::ScenarioOutline.new(@status, name, location)
          end

          def describe_exception_to(formatter)
            formatter.exception(filtered_exception, @status) if @exception
          end

          private

          def step_exception(step, configuration)
            return filtered_step_exception(step) if @exception
            return nil unless @status == :undefined && configuration.strict?
            @exception = Cucumber::Undefined.from(@result, step.name)
            @exception.backtrace << step.backtrace_line
            filtered_step_exception(step)
          end

          def filtered_exception
            Cucumber::Formatter::BacktraceFilter.new(@exception.dup).exception
          end

          def filtered_step_exception(step)
            exception = filtered_exception
            return Cucumber::Formatter::BacktraceFilter.new(exception).exception
          end
        end

      end

    end
  end
end
