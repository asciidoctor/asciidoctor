require 'cucumber/core/filter'

module Cucumber
  module Core
    module Test
      class TagFilter < Filter.new(:filter_expressions)

        def test_case(test_case)
          test_cases << test_case
          if test_case.match_tags?(filter_expressions)
            test_case.describe_to(receiver)
          end
          self
        end

        def done
          tag_limits.enforce(test_cases)
          receiver.done
          self
        end

        private

        def test_cases
          @test_cases ||= TestCases.new
        end

        def tag_limits
          @tag_limits ||= TagLimits.new(filter_expressions)
        end

        class TestCases
          attr_reader :test_cases_by_tag_name
          private :test_cases_by_tag_name
          def initialize
            @test_cases_by_tag_name = Hash.new { [] }
          end

          def <<(test_case)
            test_case.tags.each do |tag|
              test_cases_by_tag_name[tag.name] += [test_case]
            end
            self
          end

          def with_tag_name(tag_name)
            test_cases_by_tag_name[tag_name]
          end
        end

        class TagLimits
          TAG_MATCHER = /^
            (?:~)?                 #The tag negation symbol "~". This is optional and not captured.
            (?<tag_name>\@\w+)     #Captures the tag name including the "@" symbol.
            \:                     #The seperator, ":", between the tag name and the limit.
            (?<limit>\d+)          #Caputres the limit number.
          $/x

          attr_reader :limit_list
          private :limit_list
          def initialize(filter_expressions)
            @limit_list = Array(filter_expressions).flat_map do |raw_expression|
              raw_expression.split(/\s*,\s*/)
            end.map do |filter_expression|
              TAG_MATCHER.match(filter_expression)
            end.compact.each_with_object({}) do |matchdata, limit_list|
              limit_list[matchdata[:tag_name]] = Integer(matchdata[:limit])
            end
          end

          def enforce(test_cases)
            limit_breaches = limit_list.reduce([]) do |breaches, (tag_name, limit)|
              tag_count = test_cases.with_tag_name(tag_name).count
              if tag_count > limit
                tag_locations = test_cases.with_tag_name(tag_name).map(&:location)
                breaches << TagLimitBreach.new(
                  tag_count,
                  limit,
                  tag_name,
                  tag_locations
                )
              end
              breaches
            end
            raise TagExcess.new(limit_breaches) if limit_breaches.any?
            self
          end
        end

        TagLimitBreach = Struct.new(
          :tag_count,
          :tag_limit,
          :tag_name,
          :tag_locations
        ) do

          def message
            "#{tag_name} occurred #{tag_count} times, but the limit was set to #{tag_limit}\n  " +
              tag_locations.map(&:to_s).join("\n  ")
          end
          alias :to_s :message
        end

        class TagExcess < StandardError
          def initialize(limit_breaches)
            super(limit_breaches.map(&:to_s).join("\n"))
          end
        end
      end
    end
  end
end
