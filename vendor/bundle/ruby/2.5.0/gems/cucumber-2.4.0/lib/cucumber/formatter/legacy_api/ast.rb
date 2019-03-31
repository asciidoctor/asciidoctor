module Cucumber
  module Formatter
    module LegacyApi
      # Adapters to pass to the legacy API formatters that provide the interface
      # of the old AST classes
      module Ast

        # Acts as a null object, or a base class
        class Node
          def initialize(node = nil)
            @node = node
          end

          def accept(formatter)
          end

          attr_reader :node
          private :node
        end

        # Null object for HeaderRow language.
        # ExampleTableRow#keyword is never called on them,
        # but this will pass silently if it happens anyway
        class NullLanguage
          def method_missing(*args, &block)
            self
          end

          def to_ary
            ['']
          end
        end

        class HookResultCollection
          def initialize
            @children = []
          end

          def accept(formatter)
            @children.each { |child| child.accept(formatter) }
          end

          def send_output_to(formatter)
            @children.each { |child| child.send_output_to(formatter) }
          end

          def describe_exception_to(formatter)
            @children.each { |child| child.describe_exception_to(formatter) }
          end

          def <<(child)
            @children << child
          end
        end

        Comments = Struct.new(:comments) do
          def accept(formatter)
            return if comments.empty?
            formatter.before_comment comments
            comments.each do |comment|
              formatter.comment_line comment.to_s.strip
            end
            formatter.after_comment comments
          end
        end

        class HookResult
          def initialize(result, messages, embeddings)
            @result, @messages, @embeddings = result, messages, embeddings
            @already_accepted = false
          end

          def accept(formatter)
            unless @already_accepted
              send_output_to(formatter)
              describe_exception_to(formatter)
            end
            self
          end

          def send_output_to(formatter)
            unless @already_accepted
              @messages.each { |message| formatter.puts(message) }
              @embeddings.each { |embedding| embedding.send_to_formatter(formatter) }
            end
          end

          def describe_exception_to(formatter)
            unless @already_accepted
              @result.describe_exception_to(formatter)
              @already_accepted = true
            end
          end
        end

        StepInvocation = Struct.new(:step_match,
                                    :status,
                                    :duration,
                                    :exception,
                                    :indent,
                                    :background,
                                    :step,
                                    :messages,
                                    :embeddings) do
          extend Forwardable

          def_delegators :step, :keyword, :name, :multiline_arg, :location

          def accept(formatter)
            formatter.before_step(self)
            Ast::Comments.new(step.comments).accept(formatter)
            messages.each { |message| formatter.puts(message) }
            embeddings.each { |embedding| embedding.send_to_formatter(formatter) }
            formatter.before_step_result *step_result_attributes
            print_step_name(formatter)
            Ast::MultilineArg.for(multiline_arg).accept(formatter)
            print_exception(formatter)
            formatter.after_step_result *step_result_attributes
            formatter.after_step(self)
          end

          def step_result_attributes
            legacy_multiline_arg = if multiline_arg.kind_of?(Core::Ast::EmptyMultilineArgument)
              nil
            else
              step.multiline_arg
            end
            [keyword, step_match, legacy_multiline_arg, status, exception, source_indent, background, file_colon_line]
          end

          def failed?
            status != :passed
          end

          def passed?
            status == :passed
          end

          def dom_id

          end

          def actual_keyword(previous_step_keyword = nil)
            step.actual_keyword(previous_step_keyword)
          end

          def file_colon_line
            location.to_s
          end

          def backtrace_line
            step_match.backtrace_line
          end

          def step_invocation
            self
          end

          private

          def source_indent
            indent.of(self)
          end

          def print_step_name(formatter)
            formatter.step_name(
              keyword,
              step_match,
              status,
              source_indent,
              background,
              location.to_s)
          end

          def print_exception(formatter)
            return unless exception
            raise exception if ENV['FAIL_FAST']
            formatter.exception(exception, status)
          end
        end

        class StepInvocations < Array
          def failed?
            any?(&:failed?)
          end

          def passed?
            all?(&:passed?)
          end

          def status
            return :passed if passed?
            failed_step.status
          end

          def exception
            failed_step.exception if failed_step
          end

          private

          def failed_step
            detect(&:failed?)
          end
        end

        class DataTableRow
          def initialize(row, line)
            @values = row
            @line = line
          end

          def dom_id
            "row_#{line}"
          end

          def accept(formatter)
            formatter.before_table_row(self)
            values.each do |value|
              formatter.before_table_cell(value)
              formatter.table_cell_value(value, status)
              formatter.after_table_cell(value)
            end
            formatter.after_table_row(self)
          end

          def status
            :skipped
          end

          def exception
            nil
          end

          attr_reader :values, :line
          private :values, :line
        end

        ExampleTableRow = Struct.new(:exception, :status, :cells, :location, :language) do
          def name
            '| ' + cells.join(' | ') + ' |'
          end

          def failed?
            status == :failed
          end

          def line
            location.line
          end

          def keyword
            # This method is only called when used for the scenario name line with
            # the expand option, and on that line the keyword is "Scenario"
            language.scenario_keywords[0]
          end
        end

        class LegacyTableRow < DataTableRow
          def accept(formatter)
            formatter.before_table_row(self)
            values.each do |value|
              formatter.before_table_cell(value.value)
              formatter.table_cell_value(value.value, value.status)
              formatter.after_table_cell(value.value)
            end
            formatter.after_table_row(self)
          end
        end

        Tags = Struct.new(:tags) do
          def accept(formatter)
            formatter.before_tags tags
            tags.each do |tag|
              formatter.tag_name tag.name
            end
            formatter.after_tags tags
          end
        end

        Scenario = Struct.new(:status, :name, :location) do
          def backtrace_line(step_name = "#{name}", line = self.location.line)
            "#{location.on_line(line)}:in `#{step_name}'"
          end

          def failed?
            :failed == status
          end

          def line
            location.line
          end
        end

        ScenarioOutline = Struct.new(:status, :name, :location) do
          def backtrace_line(step_name = "#{name}", line = self.location.line)
            "#{location.on_line(line)}:in `#{step_name}'"
          end

          def failed?
            :failed == status
          end

          def line
            location.line
          end
        end

        module MultilineArg
          class << self
            def for(node)
              Builder.new(node).result
            end
          end

          class Builder
            def initialize(node)
              node.describe_to(self)
            end

            def doc_string(node)
              @result = DocString.new(node)
            end

            def data_table(node)
              @result = DataTable.new(node)
            end

            def legacy_table(node)
              @result = LegacyTable.new(node)
            end

            def result
              @result || Node.new(nil)
            end
          end

          class DocString < Node
            def accept(formatter)
              formatter.before_multiline_arg node
              formatter.doc_string(node)
              formatter.after_multiline_arg node
            end
          end

          class DataTable < Cucumber::MultilineArgument::DataTable
            def node
              @ast_table
            end

            def accept(formatter)
              formatter.before_multiline_arg self
              node.raw.each_with_index do |row, index|
                line = node.location.line + index
                DataTableRow.new(row, line).accept(formatter)
              end
              formatter.after_multiline_arg self
            end
          end
        end

        class LegacyTable < SimpleDelegator
          def accept(formatter)
            formatter.before_multiline_arg self
            cells_rows.each_with_index do |row, index|
              line = location.line + index
              LegacyTableRow.new(row, line).accept(formatter)
            end
            formatter.after_multiline_arg self
          end
        end

        Features = Struct.new(:duration)

        class Background < SimpleDelegator
          def initialize(feature, node)
            super node
            @feature = feature
          end

          def feature
            @feature
          end
        end

      end
    end
  end
end
