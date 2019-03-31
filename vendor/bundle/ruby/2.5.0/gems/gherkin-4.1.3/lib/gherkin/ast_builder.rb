require 'gherkin/ast_node'

module Gherkin
  class AstBuilder
    def initialize
      reset
    end

    def reset
      @stack = [AstNode.new(:None)]
      @comments = []
    end

    def start_rule(rule_type)
      @stack.push AstNode.new(rule_type)
    end

    def end_rule(rule_type)
      node = @stack.pop
      current_node.add(node.rule_type, transform_node(node))
    end

    def build(token)
      if token.matched_type == :Comment
        @comments.push({
          type: :Comment,
          location: get_location(token),
          text: token.matched_text
        })
      else
        current_node.add(token.matched_type, token)
      end
    end

    def get_result
      current_node.get_single(:GherkinDocument)
    end

    def current_node
      @stack.last
    end

    def get_location(token, column=nil)
      # TODO: translated from JS... is it right?
      (column.nil? || column.zero?) ? token.location : {line: token.location[:line], column: column}
    end

    def get_tags(node)
      tags = []
      tags_node = node.get_single(:Tags)
      return tags unless tags_node

      tags_node.get_tokens(:TagLine).each do |token|
        token.matched_items.each do |tag_item|
          tags.push({
            type: :Tag,
            location: get_location(token, tag_item.column),
            name: tag_item.text
          })
        end
      end

      tags
    end

    def get_table_rows(node)
      rows = node.get_tokens(:TableRow).map do |token|
        {
          type: :TableRow,
          location: get_location(token),
          cells: get_cells(token)
        }
      end
      ensure_cell_count(rows);
      rows
    end

    def ensure_cell_count(rows)
      return if rows.empty?
      cell_count = rows[0][:cells].length
      rows.each do |row|
          if (row[:cells].length != cell_count)
            raise AstBuilderException.new("inconsistent cell count within the table", row[:location]);
          end
      end
    end

    def get_cells(table_row_token)
      table_row_token.matched_items.map do |cell_item|
        {
          type: :TableCell,
          location: get_location(table_row_token, cell_item.column),
          value: cell_item.text
        }
      end
    end

    def get_description(node)
      node.get_single(:Description)
    end

    def get_steps(node)
      node.get_items(:Step)
    end

    def transform_node(node)
      case node.rule_type
      when :Step
        step_line = node.get_token(:StepLine)
        step_argument = node.get_single(:DataTable) || node.get_single(:DocString) || nil

        reject_nils(
          type: node.rule_type,
          location: get_location(step_line),
          keyword: step_line.matched_keyword,
          text: step_line.matched_text,
          argument: step_argument
        )
      when :DocString
        separator_token = node.get_tokens(:DocStringSeparator)[0]
        content_type = separator_token.matched_text == '' ? nil : separator_token.matched_text
        line_tokens = node.get_tokens(:Other)
        content = line_tokens.map { |t| t.matched_text }.join("\n")

        reject_nils(
          type: node.rule_type,
          location: get_location(separator_token),
          contentType: content_type,
          content: content
        )
      when :DataTable
        rows = get_table_rows(node)
        reject_nils(
          type: node.rule_type,
          location: rows[0][:location],
          rows: rows,
        )
      when :Background
        background_line = node.get_token(:BackgroundLine)
        description = get_description(node)
        steps = get_steps(node)

        reject_nils(
          type: node.rule_type,
          location: get_location(background_line),
          keyword: background_line.matched_keyword,
          name: background_line.matched_text,
          description: description,
          steps: steps
        )
      when :Scenario_Definition
        tags = get_tags(node)
        scenario_node = node.get_single(:Scenario)
        if(scenario_node)
          scenario_line = scenario_node.get_token(:ScenarioLine)
          description = get_description(scenario_node)
          steps = get_steps(scenario_node)

          reject_nils(
            type: scenario_node.rule_type,
            tags: tags,
            location: get_location(scenario_line),
            keyword: scenario_line.matched_keyword,
            name: scenario_line.matched_text,
            description: description,
            steps: steps
          )
        else
          scenario_outline_node = node.get_single(:ScenarioOutline)
          raise 'Internal grammar error' unless scenario_outline_node

          scenario_outline_line = scenario_outline_node.get_token(:ScenarioOutlineLine)
          description = get_description(scenario_outline_node)
          steps = get_steps(scenario_outline_node)
          examples = scenario_outline_node.get_items(:Examples_Definition)

          reject_nils(
            type: scenario_outline_node.rule_type,
            tags: tags,
            location: get_location(scenario_outline_line),
            keyword: scenario_outline_line.matched_keyword,
            name: scenario_outline_line.matched_text,
            description: description,
            steps: steps,
            examples: examples
          )
        end
      when :Examples_Definition
        tags = get_tags(node)
        examples_node = node.get_single(:Examples)
        examples_line = examples_node.get_token(:ExamplesLine)
        description = get_description(examples_node)
        examples_table = examples_node.get_single(:Examples_Table)

        reject_nils(
          type: examples_node.rule_type,
          tags: tags,
          location: get_location(examples_line),
          keyword: examples_line.matched_keyword,
          name: examples_line.matched_text,
          description: description,
          tableHeader: !examples_table.nil? ? examples_table[:tableHeader] : nil,
          tableBody: !examples_table.nil? ? examples_table[:tableBody] : nil
        )
      when :Examples_Table
        rows = get_table_rows(node)

        reject_nils(
          tableHeader: rows.first,
          tableBody: rows[1..-1]
        )
      when :Description
        line_tokens = node.get_tokens(:Other)
        # Trim trailing empty lines
        last_non_empty = line_tokens.rindex { |token| !token.line.trimmed_line_text.empty? }
        description = line_tokens[0..last_non_empty].map { |token| token.matched_text }.join("\n")
        return description
      when :Feature
        header = node.get_single(:Feature_Header)
        return unless header
        tags = get_tags(header)
        feature_line = header.get_token(:FeatureLine)
        return unless feature_line
        children = []
        background = node.get_single(:Background)
        children.push(background) if background
        children.concat(node.get_items(:Scenario_Definition))
        description = get_description(header)
        language = feature_line.matched_gherkin_dialect

        reject_nils(
          type: node.rule_type,
          tags: tags,
          location: get_location(feature_line),
          language: language,
          keyword: feature_line.matched_keyword,
          name: feature_line.matched_text,
          description: description,
          children: children,
        )
      when :GherkinDocument
        feature = node.get_single(:Feature)
        reject_nils(
          type: node.rule_type,
          feature: feature,
          comments: @comments
        )
      else
        return node
      end
    end

    def reject_nils(values)
      values.reject { |k,v| v.nil? }
    end
  end
end
