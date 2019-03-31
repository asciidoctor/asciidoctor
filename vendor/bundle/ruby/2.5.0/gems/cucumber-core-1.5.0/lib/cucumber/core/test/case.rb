require 'cucumber/core/test/result'
require 'cucumber/core/gherkin/tag_expression'
require 'cucumber/core/ast/location'

module Cucumber
  module Core
    module Test
      class Case
        attr_reader :source, :test_steps, :around_hooks

        def initialize(test_steps, source, around_hooks = [])
          raise ArgumentError.new("test_steps should be an Array but is a #{test_steps.class}") unless test_steps.kind_of?(Array)
          @test_steps = test_steps
          @source = source
          @around_hooks = around_hooks
        end

        def step_count
          test_steps.count
        end

        def describe_to(visitor, *args)
          visitor.test_case(self, *args) do |child_visitor|
            compose_around_hooks(child_visitor, *args) do
              test_steps.each do |test_step|
                test_step.describe_to(child_visitor, *args)
              end
            end
          end
          self
        end

        def describe_source_to(visitor, *args)
          source.reverse.each do |node|
            node.describe_to(visitor, *args)
          end
          self
        end

        def with_steps(test_steps)
          self.class.new(test_steps, source, around_hooks)
        end

        def with_around_hooks(around_hooks)
          self.class.new(test_steps, source, around_hooks)
        end

        def name
          @name ||= NameBuilder.new(self).result
        end
        
        def keyword
          @keyword ||= NameBuilder.new(self).keyword
        end

        def tags
          @tags ||= TagCollector.new(self).result
        end

        def match_tags?(*expressions)
          Cucumber::Core::Gherkin::TagExpression.new(expressions.flatten).evaluate(tags)
        end

        def match_name?(name_regexp)
          source.any? { |node| node.respond_to?(:name) && node.name =~ name_regexp }
        end

        def language
          feature.language
        end

        def location
          source.last.location
        end

        def match_locations?(queried_locations)
          queried_locations.any? { |queried_location|
            all_source.any? { |node|
              node.all_locations.any? { |location|
                queried_location.match? location
              }
            }
          }
        end

        def all_locations
          @all_locations ||= Ast::Location.merge(all_source.map(&:all_locations).flatten)
        end

        def all_source
          @all_source ||= (source + test_steps.map(&:source)).flatten.uniq
        end

        def inspect
          "#<#{self.class}: #{location}>"
        end

        def feature
          source.first
        end

        private

        def compose_around_hooks(visitor, *args, &block)
          around_hooks.reverse.reduce(block) do |continue, hook|
            -> { hook.describe_to(visitor, *args, &continue) }
          end.call
        end

        class NameBuilder
          attr_reader :result
          attr_reader :keyword

          def initialize(test_case)
            test_case.describe_source_to self
          end

          def feature(*)
            self
          end

          def scenario(scenario)
            @result = scenario.name
            @keyword = scenario.keyword
            self
          end

          def scenario_outline(outline)
            @result = outline.name + @result
            @keyword = outline.keyword
            self
          end

          def examples_table(table)
            name = table.name.strip
            name = table.keyword if name.length == 0
            @result = ", #{name}" + @result
            self
          end

          def examples_table_row(row)
            @result = " (##{row.number})"
            self
          end
        end

        class TagCollector
          attr_reader :result

          def initialize(test_case)
            @result = []
            test_case.describe_source_to self
          end

          [:feature, :scenario, :scenario_outline, :examples_table].each do |node_name|
            define_method(node_name) do |node|
              @result = node.tags + @result
              self
            end
          end

          def examples_table_row(*)
          end
        end

      end
    end
  end
end
