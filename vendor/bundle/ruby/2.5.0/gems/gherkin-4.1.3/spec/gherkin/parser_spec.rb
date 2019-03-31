require 'gherkin/parser'
require 'gherkin/token_scanner'
require 'gherkin/token_matcher'
require 'gherkin/ast_builder'
require 'gherkin/errors'
require 'rspec'

module Gherkin
  describe Parser do
    it "parses a simple feature" do
      parser = Parser.new
      scanner = TokenScanner.new("Feature: test")
      ast = parser.parse(scanner)
      expect(ast).to eq({
        feature: {
          type: :Feature,
          tags: [],
          location: {line: 1, column: 1},
          language: "en",
          keyword: "Feature",
          name: "test",
          children: []
        },
        comments: [],
        type: :GherkinDocument
      })
    end

    it "parses a complex feature" do
      # This should include every significant type of thing within the language
      feature_text = "@feature_tag\n" +
                     "Feature: feature name\n" +
                     "  feature description\n" +
                     "\n" +
                     "   Background: background name\n" +
                     "    background description\n" +
                     "    * a step\n" +
          "\n" +
                     "  @scenario_tag\n" +
                     "  Scenario: scenario name\n" +
                     "    scenario description\n" +
                     "    * a step with a table\n" +
                     "      | a table |\n" +
                     "\n" +
                     "  @outline_tag\n" +
                     "  Scenario Outline: outline name\n" +
                     "    outline description\n" +
                     "    * a step with a doc string\n" +
                     "      \"\"\" content_type\n" +
                     "        lots of text\n" +
                     "      \"\"\"\n" +
                     "                # Random file comment\n" +
                     "  @example_tag\n" +
                     "  Examples: examples name\n" +
                     "    examples description\n" +
                     "    | param |\n" +
                     "    | value |\n"

      parser = Parser.new
      scanner = TokenScanner.new(feature_text)
      ast = parser.parse(scanner)

      expect(ast).to eq({
                         feature: {type: :Feature,
                          tags: [{type: :Tag,
                                  location: {line: 1, column: 1},
                                  name: "@feature_tag"}],
                          location: {line: 2, column: 1},
                          language: "en",
                          keyword: "Feature",
                          name: "feature name",
                          description: "  feature description",
                          children: [{type: :Background,
                                                 location: {line: 5, column: 4},
                                                 keyword: "Background",
                                                 name: "background name",
                                                 description: "    background description",
                                                 steps: [{type: :Step,
                                                          location: {line: 7, column: 5},
                                                          keyword: "* ",
                                                          text: "a step"}]},
                                                {type: :Scenario,
                                                 tags: [{type: :Tag,
                                                         location: {line: 9, column: 3},
                                                         name: "@scenario_tag"}],
                                                 location: {line: 10, column: 3},
                                                 keyword: "Scenario",
                                                 name: "scenario name",
                                                 description: "    scenario description",
                                                 steps: [{type: :Step,
                                                          location: {line: 12, column: 5},
                                                          keyword: "* ",
                                                          text: "a step with a table",
                                                          argument: {type: :DataTable,
                                                                     location: {line: 13, column: 7},
                                                                     rows: [{type: :TableRow,
                                                                             location: {line: 13, column: 7},
                                                                             cells: [{type: :TableCell,
                                                                                      location: {line: 13, column: 9},
                                                                                      value: "a table"}]}]}}]},
                                                {type: :ScenarioOutline,
                                                 tags: [{type: :Tag,
                                                         location: {line: 15, column: 3},
                                                         name: "@outline_tag"}],
                                                 location: {line: 16, column: 3},
                                                 keyword: "Scenario Outline",
                                                 name: "outline name",
                                                 description: "    outline description",
                                                 steps: [{type: :Step,
                                                          location: {line: 18, column: 5},
                                                          keyword: "* ",
                                                          text: "a step with a doc string",
                                                          argument: {type: :DocString,
                                                                     location: {line: 19, column: 7},
                                                                     contentType: "content_type",
                                                                     content: "  lots of text"}}],
                                                 examples: [{type: :Examples,
                                                             tags: [{type: :Tag,
                                                                     location: {line: 23, column: 3},
                                                                     name: "@example_tag"}],
                                                             location: {line: 24, column: 3},
                                                             keyword: "Examples",
                                                             name: "examples name",
                                                             description: "    examples description",
                                                             tableHeader: {type: :TableRow,
                                                                           location: {line: 26, column: 5},
                                                                           cells: [{type: :TableCell,
                                                                                    location: {line: 26, column: 7},
                                                                                    value: "param"}]},
                                                             tableBody: [{type: :TableRow,
                                                                          location: {line: 27, column: 5},
                                                                          cells: [{type: :TableCell,
                                                                                   location: {line: 27, column: 7},
                                                                                   value: "value"}]}]}]}],
                          },
                          comments: [{type: :Comment,
                                      location: {line: 22, column: 1},
                                      text: "                # Random file comment"}],
                          type: :GherkinDocument}
                     )
    end

    it "parses string feature" do
      parser = Parser.new
      ast = parser.parse("Feature: test")
      expect(ast).to eq({
        feature: {
          type: :Feature,
          tags: [],
          location: {line: 1, column: 1},
          language: "en",
          keyword: "Feature",
          name: "test",
          children: []
        },
        comments: [],
        type: :GherkinDocument
      })
    end

    it "parses io feature" do
      parser = Parser.new
      ast = parser.parse(StringIO.new("Feature: test"))
      expect(ast).to eq({
        feature: {
          type: :Feature,
          tags: [],
          location: {line: 1, column: 1},
          language: "en",
          keyword: "Feature",
          name: "test",
          children: []
        },
        comments: [],
        type: :GherkinDocument
      })
    end

    it "can parse multiple features" do
      parser = Parser.new
      ast1 = parser.parse(TokenScanner.new("Feature: test"))
      ast2 = parser.parse(TokenScanner.new("Feature: test2"))

      expect(ast1).to eq({
        feature: {
          type: :Feature,
          tags: [],
          location: {line: 1, column: 1},
          language: "en",
          keyword: "Feature",
          name: "test",
          children: []
        },
        comments: [],
        type: :GherkinDocument
      })
      expect(ast2).to eq({
        feature: {
          type: :Feature,
          tags: [],
          location: {line: 1, column: 1},
          language: "en",
          keyword: "Feature",
          name: "test2",
          children: []
        },
        comments: [],
        type: :GherkinDocument
      })
    end

    it "can parse feature after parse error" do
      parser = Parser.new
      matcher = TokenMatcher.new

      expect { parser.parse(TokenScanner.new("# a comment\n" +
                                             "Feature: Foo\n" +
                                             "  Scenario: Bar\n" +
                                             "    Given x\n" +
                                             "      ```\n" +
                                             "      unclosed docstring\n"),
                            matcher)
      }.to raise_error(ParserError)
      ast = parser.parse(TokenScanner.new("Feature: Foo\n" +
                                          "  Scenario: Bar\n" +
                                          "    Given x\n" +
                                          '      """' + "\n" +
                                          "      closed docstring\n" +
                                          '      """' + "\n"),
                         matcher)

      expect(ast).to eq({
        feature: {
          type: :Feature,
          tags: [],
          location: {line: 1, column: 1},
          language: "en",
          keyword: "Feature",
          name: "Foo",
          children: [{
            :type=>:Scenario,
            :tags=>[],
            :location=>{:line=>2, :column=>3},
            :keyword=>"Scenario",
            :name=>"Bar",
            :steps=>[{
              :type=>:Step,
              :location=>{:line=>3, :column=>5},
              :keyword=>"Given ",
              :text=>"x",
              :argument=>{:type=>:DocString,
                          :location=>{:line=>4, :column=>7},
                          :content=>"closed docstring"}}]}]
        },
        comments: [],
        type: :GherkinDocument
      })
    end

    it "can change the default language" do
      parser = Parser.new
      matcher = TokenMatcher.new("no")
      scanner = TokenScanner.new("Egenskap: i18n support")
      ast = parser.parse(scanner, matcher)
      expect(ast).to eq({
        feature: {
          type: :Feature,
          tags: [],
          location: {line: 1, column: 1},
          language: "no",
          keyword: "Egenskap",
          name: "i18n support",
          children: []
        },
        comments: [],
        type: :GherkinDocument
      })
    end
  end
end
