require 'cucumber/core/gherkin/parser'
require 'cucumber/core/gherkin/document'
require 'cucumber/core/compiler'
require 'cucumber/core/test/runner'

module Cucumber
  module Core

    def execute(gherkin_documents, report, filters = [])
      receiver = Test::Runner.new(report)
      compile gherkin_documents, receiver, filters
      self
    end

    def compile(gherkin_documents, last_receiver, filters = [])
      first_receiver = compose(filters, last_receiver)
      compiler = Compiler.new(first_receiver)
      parse gherkin_documents, compiler
      self
    end

    private

    def parse(gherkin_documents, compiler)
      parser = Core::Gherkin::Parser.new(compiler)
      gherkin_documents.each do |document|
        parser.document document
      end
      parser.done
      self
    end

    def compose(filters, last_receiver)
      filters.reverse.reduce(last_receiver) do |receiver, filter|
        filter.with_receiver(receiver)
      end
    end

  end
end
