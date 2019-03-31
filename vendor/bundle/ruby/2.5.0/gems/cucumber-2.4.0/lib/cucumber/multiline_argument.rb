require 'delegate'
require 'cucumber/multiline_argument/data_table'
require 'cucumber/multiline_argument/doc_string'

module Cucumber
  module MultilineArgument

    class << self
      def from_core(node)
        builder.wrap(node)
      end

      def from(argument, location=nil)
        location ||= Core::Ast::Location.of_caller
        case argument
        when String
          doc_string(argument, 'text/plain', location)
        when Array
          location = location.on_line(argument.first.line..argument.last.line)
          data_table(argument.map{ |row| row.cells }, location)
        when DataTable, DocString, None
          argument
        when nil
          None.new
        else
          raise ArgumentError, "Don't know how to convert #{argument.class} #{argument.inspect} into a MultilineArgument"
        end
      end

      def doc_string(argument, content_type, location)
        builder.doc_string(Core::Ast::DocString.new(argument, content_type, location))
      end

      def data_table(data, location)
        builder.data_table(Core::Ast::DataTable.new(data, location))
      end

      private

      def builder
        @builder ||= Builder.new
      end

      class Builder
        def wrap(node)
          @result = None.new
          node.describe_to(self)
          @result
        end

        def doc_string(node, *args)
          @result = DocString.new(node)
        end

        def data_table(node, *args)
          @result = DataTable.new(node)
        end
      end
    end

    class None
      def append_to(array)
      end

      def describe_to(visitor)
      end
    end
  end
end

require 'cucumber/ast'
