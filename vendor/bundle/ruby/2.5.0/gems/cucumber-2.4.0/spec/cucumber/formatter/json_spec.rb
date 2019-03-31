require 'spec_helper'
require 'cucumber/formatter/spec_helper'
require 'cucumber/formatter/json'
require 'cucumber/cli/options'
require 'multi_json'

module Cucumber
  module Formatter
    describe Json do
      extend SpecHelperDsl
      include SpecHelper

      context "Given a single feature" do
        before(:each) do
          @out = StringIO.new
          @formatter = Json.new(actual_runtime.configuration.with_options(out_stream: @out))
          run_defined_feature
        end

        describe "with a scenario with no steps" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
            FEATURE

          it "outputs the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario"}]}]})
          end
        end

        describe "with a scenario with an undefined step" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          it "outputs the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec.feature:4"},
                      "result": {"status": "undefined"}}]}]}]})
          end
        end

        describe "with a scenario with a passed step" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Given(/^there are bananas$/) {}
          end

          it "outputs the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:86"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario with a failed step" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Given(/^there are bananas$/) { raise "no bananas" }
          end

          it "outputs the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:123"},
                      "result": {"status": "failed",
                                 "error_message": "no bananas (RuntimeError)\\n./spec/cucumber/formatter/json_spec.rb:123:in `/^there are bananas$/'\\nspec.feature:4:in `Given there are bananas'",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario with a pending step" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Given(/^there are bananas$/) { pending }
          end

          it "outputs the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:161"},
                      "result": {"status": "pending",
                                 "error_message": "TODO (Cucumber::Pending)\\n./spec/cucumber/formatter/json_spec.rb:161:in `/^there are bananas$/'\\nspec.feature:4:in `Given there are bananas'",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario outline with one example" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario Outline: Monkey eats bananas
              Given there are <fruit>

              Examples: Fruit Table
              |  fruit  |
              | bananas |
            FEATURE

          define_steps do
            Given(/^there are bananas$/) {}
          end

          it "outputs the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas;fruit-table;2",
                   "keyword": "Scenario Outline",
                   "name": "Monkey eats bananas",
                   "line": 8,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 8,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:203"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with tags in the feature file" do
          define_feature <<-FEATURE
          @f
          Feature: Banana party

            @s
            Scenario: Monkey eats bananas
              Given there are bananas

            @so
            Scenario Outline: Monkey eats bananas
              Given there are <fruit>

              @ex
              Examples: Fruit Table
              |  fruit  |
              | bananas |
            FEATURE

          define_steps do
            Given(/^there are bananas$/) {}
          end

          it "the tags are included in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 2,
                "description": "",
                "tags": [{"name": "@f",
                          "line": 1}],
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 5,
                   "description": "",
                   "tags": [{"name": "@f",
                             "line": 1},
                            {"name": "@s",
                             "line": 4}],
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 6,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:251"},
                      "result": {"status": "passed",
                                 "duration": 1}}]},
                   {"id": "banana-party;monkey-eats-bananas;fruit-table;2",
                   "keyword": "Scenario Outline",
                   "name": "Monkey eats bananas",
                   "line": 15,
                   "description": "",
                   "tags": [{"name": "@f",
                             "line": 1},
                            {"name": "@so",
                             "line": 8},
                            {"name": "@ex",
                             "line": 12}],
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 15,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:251"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with comments in the feature file" do
          define_feature <<-FEATURE
          #feature comment
          Feature: Banana party

            #background comment
            Background: There are bananas
              Given there are bananas

            #scenario comment
            Scenario: Monkey eats bananas
              #step comment1
              Then the monkey eats bananas

            #scenario outline comment
            Scenario Outline: Monkey eats bananas
              #step comment2
              Then the monkey eats <fruit>

              #examples table comment
              Examples: Fruit Table
              |  fruit  |
              #examples table row comment
              | bananas |
            FEATURE

          define_steps do
            Given(/^there are bananas$/) {}
            Then(/^the monkey eats bananas$/) {}
          end

          it "the comments are included in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 2,
                "description": "",
                "comments": [{"value": "#feature comment",
                              "line": 1}],
                "elements":
                 [{"keyword": "Background",
                   "name": "There are bananas",
                   "line": 5,
                   "description": "",
                   "comments": [{"value": "#background comment",
                                 "line": 4}],
                   "type": "background",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 6,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:331"},
                      "result": {"status": "passed",
                                 "duration": 1}}]},
                  {"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 9,
                   "description": "",
                   "comments": [{"value": "#scenario comment",
                                 "line": 8}],
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Then ",
                      "name": "the monkey eats bananas",
                      "line": 11,
                      "comments": [{"value": "#step comment1",
                                    "line": 10}],
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:332"},
                      "result": {"status": "passed",
                                 "duration": 1}}]},
                  {"keyword": "Background",
                   "name": "There are bananas",
                   "line": 5,
                   "description": "",
                   "comments": [{"value": "#background comment",
                                 "line": 4}],
                   "type": "background",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 6,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:331"},
                      "result": {"status": "passed",
                                 "duration": 1}}]},
                   {"id": "banana-party;monkey-eats-bananas;fruit-table;2",
                   "keyword": "Scenario Outline",
                   "name": "Monkey eats bananas",
                   "line": 22,
                   "description": "",
                   "comments": [{"value": "#scenario outline comment",
                                 "line": 13},
                                {"value": "#examples table comment",
                                 "line": 18},
                                {"value": "#examples table row comment",
                                 "line": 21}],
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Then ",
                      "name": "the monkey eats bananas",
                      "line": 22,
                      "comments": [{"value": "#step comment2",
                                    "line": 15}],
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:332"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario with a step with a doc string" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
                """
                the doc string
                """
            FEATURE

          define_steps do
            Given(/^there are bananas$/) { |s| s }
          end

          it "includes the doc string in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "doc_string": {"value": "the doc string",
                                     "content_type": "",
                                     "line": 5},
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:427"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario with a step that use puts" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Given(/^there are bananas$/) { puts "from step" }
          end

          it "includes the output from the step in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "output": ["from step"],
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:467"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a background" do
          define_feature <<-FEATURE
          Feature: Banana party

            Background: There are bananas
              Given there are bananas

            Scenario: Monkey eats bananas
              Then the monkey eats bananas

            Scenario: Monkey eats more bananas
              Then the monkey eats more bananas
            FEATURE

          it "includes the background in the json data each time it is executed" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"keyword": "Background",
                   "name": "There are bananas",
                   "line": 3,
                   "description": "",
                   "type": "background",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec.feature:4"},
                      "result": {"status": "undefined"}}]},
                  {"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 6,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Then ",
                      "name": "the monkey eats bananas",
                      "line": 7,
                      "match": {"location": "spec.feature:7"},
                      "result": {"status": "undefined"}}]},
                  {"keyword": "Background",
                   "name": "There are bananas",
                   "line": 3,
                   "description": "",
                   "type": "background",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec.feature:4"},
                      "result": {"status": "undefined"}}]},
                  {"id": "banana-party;monkey-eats-more-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats more bananas",
                   "line": 9,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Then ",
                      "name": "the monkey eats more bananas",
                      "line": 10,
                      "match": {"location": "spec.feature:10"},
                      "result": {"status": "undefined"}}]}]}]})
          end
        end

        describe "with a scenario with a step that embeds data directly" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Given(/^there are bananas$/) { data = "YWJj"
              embed data, "mime-type;base64" }
          end

          it "includes the data from the step in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "embeddings": [{"mime_type": "mime-type",
                                      "data": "YWJj"}],
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:577"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario with a step that embeds a file" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Given(/^there are bananas$/) {
              RSpec::Mocks.allow_message(File, :file?) { true }
              f1 = RSpec::Mocks::Double.new
              RSpec::Mocks.allow_message(File, :open)  { |&block| block.call(f1) }
              RSpec::Mocks.allow_message(f1, :read)  { "foo" }
              embed('out/snapshot.jpeg', 'image/png')
            }
          end

          it "includes the file content in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "embeddings": [{"mime_type": "image/png",
                                      "data": "Zm9v"}],
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:617"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario with hooks" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Before() {}
            Before() {}
            After() {}
            After() {}
            AfterStep() {}
            AfterStep() {}
            Around() { |scenario, block| block.call }
            Given(/^there are bananas$/) {}
          end

          it "includes all hooks except the around hook in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "before":
                    [{"match": {"location": "spec/cucumber/formatter/json_spec.rb:662"},
                      "result": {"status": "passed",
                                 "duration": 1}},
                     {"match": {"location": "spec/cucumber/formatter/json_spec.rb:663"},
                      "result": {"status": "passed",
                                 "duration": 1}}],
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:669"},
                      "result": {"status": "passed",
                                 "duration": 1},
                      "after":
                       [{"match": {"location": "spec/cucumber/formatter/json_spec.rb:666"},
                         "result": {"status": "passed",
                                    "duration": 1}},
                        {"match": {"location": "spec/cucumber/formatter/json_spec.rb:667"},
                         "result": {"status": "passed",
                                    "duration": 1}}]}],
                   "after":
                    [{"match": {"location": "spec/cucumber/formatter/json_spec.rb:665"},
                      "result": {"status": "passed",
                                 "duration": 1}},
                     {"match": {"location": "spec/cucumber/formatter/json_spec.rb:664"},
                      "result": {"status": "passed",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario when only an around hook is failing" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
            FEATURE

          define_steps do
            Around() { |scenario, block| block.call; raise RuntimeError, "error" }
            Given(/^there are bananas$/) {}
          end

          it "includes the around hook result in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                    [{"keyword": "Given ",
                      "name": "there are bananas",
                      "line": 4,
                      "match": {"location": "spec/cucumber/formatter/json_spec.rb:728"},
                      "result": {"status": "passed",
                                 "duration": 1}}],
                   "around":
                    [{"match": {"location": "unknown_hook_location:1"},
                      "result": {"status": "failed",
                                 "error_message": "error (RuntimeError)\\n./spec/cucumber/formatter/json_spec.rb:727:in `Around'",
                                 "duration": 1}}]}]}]})
          end
        end

        describe "with a scenario with a step with a data table" do
          define_feature <<-FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
                | aa | bb |
                | cc | dd |
            FEATURE

          define_steps do
            Given(/^there are bananas$/) { |s| s }
          end

          it "includes the doc string in the json data" do
            expect(load_normalised_json(@out)).to eq MultiJson.load(%{
              [{"id": "banana-party",
                "uri": "spec.feature",
                "keyword": "Feature",
                "name": "Banana party",
                "line": 1,
                "description": "",
                "elements":
                 [{"id": "banana-party;monkey-eats-bananas",
                   "keyword": "Scenario",
                   "name": "Monkey eats bananas",
                   "line": 3,
                   "description": "",
                   "type": "scenario",
                   "steps":
                     [{"keyword": "Given ",
                       "name": "there are bananas",
                       "line": 4,
                       "rows": 
                         [{"cells": ["aa", "bb"]}, 
                          {"cells": ["cc", "dd"]}],
                       "match": {"location": "spec/cucumber/formatter/json_spec.rb:772"},
                       "result": {"status": "passed",
                                  "duration": 1}}]}]}]})
          end
        end
      end

      def load_normalised_json(out)
        normalise_json(MultiJson.load(out.string))
      end

      def normalise_json(json)
        #make sure duration was captured (should be >= 0)
        #then set it to what is "expected" since duration is dynamic
        json.each do |feature|
          elements = feature.fetch('elements') { [] }
          elements.each do |scenario|
            ['steps', 'before', 'after', 'around'].each do |type|
              if scenario[type]
                scenario[type].each do |step_or_hook|
                  normalise_json_step_or_hook(step_or_hook)
                  if step_or_hook['after']
                    step_or_hook['after'].each do |hook|
                      normalise_json_step_or_hook(hook)
                    end
                  end
                end
              end
            end
          end
        end
      end

      def normalise_json_step_or_hook(step_or_hook)
        if step_or_hook['result']
          if step_or_hook['result']['duration']
            expect(step_or_hook['result']['duration']).to be >= 0
            step_or_hook['result']['duration'] = 1
          end
        end
      end

    end
  end
end
