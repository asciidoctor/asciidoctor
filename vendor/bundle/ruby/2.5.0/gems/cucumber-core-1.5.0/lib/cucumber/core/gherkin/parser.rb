require 'gherkin/parser'
require 'gherkin/token_scanner'
require 'gherkin/errors'
require 'cucumber/core/gherkin/ast_builder'
require 'cucumber/core/ast'

module Cucumber
  module Core
    module Gherkin
      ParseError = Class.new(StandardError)

      class Parser
        attr_reader :receiver
        private     :receiver

        def initialize(receiver)
          @receiver = receiver
        end

        def document(document)
          parser  = ::Gherkin::Parser.new
          scanner = ::Gherkin::TokenScanner.new(document.body)
          core_builder = AstBuilder.new(document.uri)

          begin
            result = parser.parse(scanner)

            receiver.feature core_builder.feature(result)
          rescue *PARSER_ERRORS => e
            raise Core::Gherkin::ParseError.new("#{document.uri}: #{e.message}")
          end
        end

        def done
          receiver.done
          self
        end

        private

        PARSER_ERRORS = ::Gherkin::ParserError

      end
    end
  end
end
