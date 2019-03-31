require 'gherkin/token_scanner'
require 'gherkin/token_matcher'
require 'gherkin/parser'
require 'gherkin/dialect'

module Cucumber
  module Gherkin
    class StepsParser
      def initialize(builder, language)
        @builder = builder
        @language = language
      end

      def parse(text)
        dialect = ::Gherkin::Dialect.for(@language)
        token_matcher = ::Gherkin::TokenMatcher.new(@language)
        token_scanner = ::Gherkin::TokenScanner.new(feature_header(dialect) + text)
        parser = ::Gherkin::Parser.new
        gherkin_document = parser.parse(token_scanner, token_matcher)

        @builder.steps(gherkin_document[:feature][:children][0][:steps])
      end

      def feature_header(dialect)
        %(#{dialect.feature_keywords[0]}:
            #{dialect.scenario_keywords[0]}:
         )
      end
    end
  end
end
