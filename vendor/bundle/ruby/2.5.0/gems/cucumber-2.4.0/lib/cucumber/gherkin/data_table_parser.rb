require 'gherkin/token_scanner'
require 'gherkin/parser'
require 'gherkin/dialect'

module Cucumber
  module Gherkin
    class DataTableParser
      def initialize(builder)
        @builder = builder
      end

      def parse(text)
        token_scanner = ::Gherkin::TokenScanner.new(feature_header + text)
        parser = ::Gherkin::Parser.new
        gherkin_document = parser.parse(token_scanner)

        gherkin_document[:feature][:children][0][:steps][0][:argument][:rows].each do |row|
          @builder.row(row[:cells].map { |cell| cell[:value] })
        end
      end

      def feature_header
        dialect = ::Gherkin::Dialect.for('en')
        %(#{dialect.feature_keywords[0]}:
            #{dialect.scenario_keywords[0]}:
              #{dialect.given_keywords[0]} x
         )
      end
    end
  end
end
