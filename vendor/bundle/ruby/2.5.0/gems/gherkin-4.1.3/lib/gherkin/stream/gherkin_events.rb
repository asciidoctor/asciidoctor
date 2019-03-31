require 'gherkin/parser'
require 'gherkin/pickles/compiler'

module Gherkin
  module Stream
    class GherkinEvents
      def initialize(options)
        @options = options
        @parser = Gherkin::Parser.new
        @compiler = Gherkin::Pickles::Compiler.new
      end

      def enum(source_event)
        Enumerator.new do |y|
          uri = source_event['uri']
          source = source_event['data']
          begin
            gherkin_document = @parser.parse(source)

            if (@options[:print_source])
              y.yield source_event
            end
            if (@options[:print_ast])
              y.yield({
                type: 'gherkin-document',
                uri: uri,
                document: gherkin_document
              })
            end
            if (@options[:print_pickles])
              pickles = @compiler.compile(gherkin_document)
              pickles.each do |pickle|
                y.yield({
                  type: 'pickle',
                  uri: uri,
                  pickle: pickle
                })
              end
            end
          rescue Gherkin::CompositeParserException => e
            yield_errors(y, e.errors, uri)
          rescue Gherkin::ParserError => e
            yield_errors(y, [e], uri)
          end
        end
      end

      def yield_errors(y, errors, uri)
        errors.each do |error|
          y.yield({
            type: 'attachment',
            source: {
              uri: uri,
              start: {
                line: error.location[:line],
                column: error.location[:column]
              }
            },
            data: error.message,
            media: {
              encoding: 'utf-8',
              type: 'text/vnd.cucumber.stacktrace+plain'
            }
          })
        end
      end
    end
  end
end
