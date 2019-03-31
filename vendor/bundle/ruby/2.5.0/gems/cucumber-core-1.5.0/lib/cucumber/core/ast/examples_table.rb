require 'cucumber/core/ast/describes_itself'
require 'cucumber/core/ast/location'
require 'cucumber/core/ast/names'

module Cucumber
  module Core
    module Ast

      class ExamplesTable
        include Names
        include HasLocation
        include DescribesItself

        def initialize(location, comments, tags, keyword, name, description, header, example_rows)
          @location = location
          @comments = comments
          @tags = tags
          @keyword = keyword
          @name = name
          @description = description
          @header = header
          @example_rows = example_rows
        end

        attr_reader :location, :tags, :keyword, :comments,
                    :header, :example_rows

        private

        def description_for_visitors
          :examples_table
        end

        def children
          @example_rows
        end

        class Header
          include HasLocation

          attr_reader :comments

          def initialize(cells, location, comments)
            @cells = cells
            @location = location
            @comments = comments
          end

          def values
            @cells
          end

          def build_row(row_cells, number, location, language, comments)
            Row.new(Hash[@cells.zip(row_cells)], number, location, language, comments)
          end

          def inspect
            "#<#{self.class} #{values} (#{location})>"
          end
        end

        class Row
          include DescribesItself
          include HasLocation

          attr_reader :number, :language, :comments

          def initialize(data, number, location, language, comments)
            raise ArgumentError, data.to_s unless data.is_a?(Hash)
            @data = data
            @number = number
            @location = location
            @language = language
            @comments = comments
          end

          def ==(other)
            return false unless other.class == self.class
            other.number == number &&
              other.location == location &&
              other.data == data
          end

          def values
            @data.values
          end

          def expand(string)
            result = string.dup
            @data.each do |key, value|
              result.gsub!("<#{key}>", value.to_s)
            end
            result
          end

          def inspect
            "#<#{self.class}: #{@data.inspect} (#{location})>"
          end

          protected

          attr_reader :data

          private

          def description_for_visitors
            :examples_table_row
          end
        end
      end
      class Examples < ExamplesTable; end
    end
  end
end
