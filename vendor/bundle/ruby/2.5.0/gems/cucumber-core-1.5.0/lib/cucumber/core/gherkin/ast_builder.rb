require 'cucumber/core/ast'
require 'cucumber/core/platform'

module Cucumber
  module Core
    module Gherkin
      # Builds an AST of a feature by listening to events from the
      # Gherkin parser.
      class AstBuilder

        def initialize(uri)
          @uri = uri
        end

        def feature(attributes)
          DocumentBuilder.new(file, attributes).feature
        end

        private

        def file
          @uri
        end

        class Builder
          attr_reader :file, :attributes, :comments, :line
          private     :file, :attributes, :comments, :line

          def initialize(file, attributes)
            @file = file
            @attributes = rubify_keys(attributes.dup)
            @comments = []
            @line = @attributes[:location][:line]
          end

          def handle_comments(comments)
            remaining_comments = []
            comments.each do |comment|
              if line > comment.location.line
                @comments << comment
              else
                remaining_comments << comment
              end
            end
            children.each { |child| remaining_comments = child.handle_comments(remaining_comments) }
            remaining_comments
          end

          private

          def keyword
            attributes[:keyword]
          end

          def name
            attributes[:name]
          end

          def description
            attributes[:description] ||= ""
          end

          def tags
            attributes[:tags].map do |tag|
              Ast::Tag.new(
                Ast::Location.new(file, tag[:location][:line]),
                tag[:name])
            end
          end

          def location
            Ast::Location.new(file, attributes[:location][:line])
          end

          def children
            []
          end

          def rubify_keys(hash)
            hash.keys.each do |key|
              if key.downcase != key
                hash[underscore(key).to_sym] = hash.delete(key)
              end
            end
            return hash
          end

          def underscore(string)
            string.to_s.gsub(/::/, '/').
              gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
              gsub(/([a-z\d])([A-Z])/,'\1_\2').
              tr("-", "_").
              downcase
          end
        end

        class DocumentBuilder < Builder
          def initialize(file, attributes)
            @file = file
            @attributes = rubify_keys(attributes.dup)
          end

          def feature
            return Ast::NullFeature.new unless attributes[:feature]
            feature_builder = FeatureBuilder.new(file, attributes[:feature])
            feature_builder.handle_comments(all_comments)
            feature_builder.result
          end

          def all_comments
            attributes[:comments].map do |comment|
              Ast::Comment.new(
                Ast::Location.new(file, comment[:location][:line]),
                comment[:text]
              )
            end
          end
        end

        class FeatureBuilder < Builder
          attr_reader :language, :feature_element_builders

          def initialize(*)
            super
            @language = Ast::LanguageDelegator.new(attributes[:language], ::Gherkin::Dialect.for(attributes[:language]))
            @feature_element_builders = attributes[:children].map do |child|
              case child[:type]
              when :Background
                BackgroundBuilder.new(file, child)
              when :Scenario
                ScenarioBuilder.new(file, child)
              else 
                ScenarioOutlineBuilder.new(file, child)
              end
            end
          end

          def result
            Ast::Feature.new(
              language,
              location,
              comments,
              tags,
              keyword,
              name,
              description,
              feature_elements
            )
          end

          private

          def feature_elements
            feature_element_builders.map { |builder| builder.result(language) }
          end

          def children
            feature_element_builders
          end
        end

        class BackgroundBuilder < Builder
          attr_reader :step_builders

          def initialize(*)
            super
            @step_builders = attributes[:steps].map { |step| StepBuilder.new(file, step) }
          end

          def result(language)
            Ast::Background.new(
              location,
              comments,
              keyword,
              name,
              description,
              steps(language)
            )
          end

          def steps(language)
            step_builders.map { |builder| builder.result(language) }
          end

          def children
            step_builders
          end
        end

        class ScenarioBuilder < Builder
          attr_reader :step_builders

          def initialize(*)
            super
            @step_builders = attributes[:steps].map { |step| StepBuilder.new(file, step) }
          end

          def result(language)
            Ast::Scenario.new(
              location,
              comments,
              tags,
              keyword,
              name,
              description,
              steps(language)
            )
          end

          def steps(language)
            step_builders.map { |builder| builder.result(language) }
          end

          def children
            step_builders
          end
        end

        class StepBuilder < Builder
          attr_reader :multiline_argument_builder

          def initialize(*)
            super
            @multiline_argument_builder = attributes[:argument] ? argument_builder(attributes[:argument]) : nil
          end

          def result(language)
            Ast::Step.new(
              language,
              location,
              comments,
              keyword,
              attributes[:text],
              multiline_argument
            )
          end

          def multiline_argument
            return Ast::EmptyMultilineArgument.new unless multiline_argument_builder
            multiline_argument_builder.result
          end

          def children
            return [] unless multiline_argument_builder
            [multiline_argument_builder]
          end

          private

          def argument_builder(attributes)
            attributes[:type] == :DataTable ? DataTableBuilder.new(file, attributes) : DocStringBuilder.new(file, attributes) 
          end
        end

        class OutlineStepBuilder < StepBuilder
          def result(language)
            Ast::OutlineStep.new(
              language,
              location,
              comments,
              keyword,
              attributes[:text],
              multiline_argument
            )
          end
        end

        class ScenarioOutlineBuilder < Builder
          attr_reader :step_builders, :example_builders

          def initialize(*)
            super
            @step_builders = attributes[:steps].map { |step| OutlineStepBuilder.new(file, step) }
            @example_builders = attributes[:examples].map { |example| ExamplesTableBuilder.new(file, example) }
          end

          def result(language)
            Ast::ScenarioOutline.new(
              location,
              comments,
              tags,
              keyword,
              name,
              description,
              steps(language),
              examples(language)
            )
          end

          def steps(language)
            step_builders.map { |builder| builder.result(language) }
          end

          def examples(language)
            example_builders.map { |builder| builder.result(language) }
          end

          def children
            step_builders + example_builders
          end
        end

        class ExamplesTableBuilder < Builder
          attr_reader :header_builder, :example_rows_builders

          def initialize(*)
            super
            @header_builder = HeaderBuilder.new(file, attributes[:table_header])
            @example_rows_builders = attributes[:table_body].map do |row_attributes|
              ExampleRowBuilder.new(file, row_attributes)
            end
          end

          def result(language)
            Ast::Examples.new(
              location,
              comments,
              tags,
              keyword,
              name,
              description,
              header,
              example_rows(language)
            )
          end

          private

          def header
            @header = header_builder.result
          end

          def example_rows(language)
            example_rows_builders.each.with_index.map { |builder, index| builder.result(language, header, index) }
          end

          class HeaderBuilder < Builder
            def result
              cells = attributes[:cells].map { |c| c[:value] }
              Ast::ExamplesTable::Header.new(cells, location, comments)
            end
          end

          def children
            [header_builder] + example_rows_builders
          end

          class ExampleRowBuilder < Builder
            def result(language, header, index)
              cells = attributes[:cells].map { |c| c[:value] }
              header.build_row(cells, index + 1, location, language, comments)
            end
          end
        end

        class DataTableBuilder < Builder
          def result
            Ast::DataTable.new(
              rows,
              location
            )
          end

          def rows
            attributes[:rows] = attributes[:rows].map { |r| r[:cells].map { |c| c[:value] } }
          end
        end

        class DocStringBuilder < Builder
          def result
            Ast::DocString.new(
              attributes[:content],
              attributes[:content_type],
              doc_string_location
            )
          end

          def doc_string_location
            start_line = attributes[:location][:line]
            end_line = start_line + attributes[:content].each_line.to_a.length + 1
            Ast::Location.new(file, start_line..end_line)
          end
        end

      end
    end
  end
end
