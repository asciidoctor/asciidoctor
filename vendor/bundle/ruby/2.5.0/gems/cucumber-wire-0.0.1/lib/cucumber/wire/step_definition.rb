require 'cucumber/core/ast/location'

module Cucumber
  module Wire
    class StepDefinition
      attr_reader :regexp_source, :location

      def initialize(connection, data)
        @connection = connection
        @id              = data['id']
        @regexp_source   = data['regexp'] || "Unknown"
        @location        = Core::Ast::Location.from_file_colon_line(data['source'] || "unknown:0")
      end

      def invoke(args)
        @connection.invoke(@id, args)
      end

    end
  end
end
