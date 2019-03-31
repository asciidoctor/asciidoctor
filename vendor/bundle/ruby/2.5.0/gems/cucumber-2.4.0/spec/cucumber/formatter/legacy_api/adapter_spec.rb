require 'cucumber/formatter/legacy_api/adapter'
require 'cucumber/core'
require 'cucumber/core/gherkin/writer'
require 'cucumber/runtime/step_hooks'
require 'cucumber/runtime/before_hooks'
require 'cucumber/runtime/after_hooks'
require 'cucumber/filters'
require 'spec_helper'

module Cucumber
  module Formatter::LegacyApi
    describe Adapter do
      include Core::Gherkin::Writer
      include Core

      let(:report)    { Adapter.new(formatter, runtime.results, runtime.configuration) }
      let(:formatter) { double('formatter').as_null_object }
      let(:runtime)   { Runtime.new }
      let(:step_match_search) { SimpleStepDefinitionSearch.new }

      Failure = Class.new(StandardError)

      class SimpleStepMatch
        def initialize(&block)
          @block = block
        end

        def activate(test_step)
          test_step.with_action &@block
        end
      end

      class SimpleStepDefinitionSearch
        def call(name)
          if name =~ /pass/
            return [SimpleStepMatch.new {}]
          end

          if name =~ /fail/
            return [SimpleStepMatch.new { raise Failure }]
          end

          []
        end
      end

      class HookWrapper
        def initialize(proc)
          @proc = proc
        end

        def source_location
          @proc.source_location
        end

        def location
          source_location
        end

        def invoke(pseudo_method, arguments, &block)
          @proc.call
        end
      end

      class AddBeforeAndAfterHooks < Core::Filter.new
        def test_case(test_case)
          steps = before_hooks(test_case.source) +
            test_case.test_steps +
            after_hooks(test_case.source)
          test_case.with_steps(steps).describe_to receiver
        end

        private

        def before_hooks(source)
          # The adapter is built on the assumption that each test case will have at least one step. This is annoying
          # for tests, but a safe assumption for production use as we always add one hook to initialize the world.
          hook = proc {}
          [ Hooks.before_hook(source, hook.source_location, &hook) ]
        end

        def after_hooks(source)
          # We add an after hook to make sure the adapter can cope with it
          hook = proc {}
          [ Hooks.after_hook(source, hook.source_location, &hook) ]
        end
      end

      context 'message order' do
        let(:formatter) { MessageSpy.new }

        it 'two features' do
          gherkin_docs = [
            gherkin do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end,
            gherkin do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end,
          ]
          runner = Core::Test::Runner.new(report)
          compile gherkin_docs, runner, default_filters
          expect( formatter.legacy_messages ).to eq [
            :before_features,
              :before_feature,
                :before_tags,
                :after_tags,
                :feature_name,
                :before_feature_element,
                  :before_tags,
                  :after_tags,
                  :scenario_name,
                  :before_steps,
                    :before_step,
                      :before_step_result,
                      :step_name,
                      :after_step_result,
                    :after_step,
                  :after_steps,
                :after_feature_element,
              :after_feature,
              :before_feature,
                :before_tags,
                :after_tags,
                :feature_name,
                :before_feature_element,
                  :before_tags,
                  :after_tags,
                  :scenario_name,
                  :before_steps,
                    :before_step,
                      :before_step_result,
                      :step_name,
                      :after_step_result,
                    :after_step,
                  :after_steps,
                :after_feature_element,
              :after_feature,
            :after_features,
          ]
        end

        it 'a scenario with no steps' do
          execute_gherkin do
            feature do
              scenario
            end
          end

          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                      :after_tags,
                    :scenario_name,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a scenario with no steps coming after another scenario' do
          execute_gherkin do
            feature do
              scenario do
                step 'passing'
              end
              scenario
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                      :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                        :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                      :after_tags,
                    :scenario_name,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a scenario with one step' do
          execute_gherkin do
            feature do
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                      :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                        :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a scenario with two steps, one of them failing' do
          execute_gherkin do
            feature do
              scenario do
                step 'passing'
                step 'failing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
              :before_feature,
              :before_tags,
              :after_tags,
              :feature_name,
              :before_feature_element,
              :before_tags,
              :after_tags,
              :scenario_name,
              :before_steps,
              :before_step,
              :before_step_result,
              :step_name,
              :after_step_result,
              :after_step,
              :before_step,
              :before_step_result,
              :step_name,
              :exception,
              :after_step_result,
              :after_step,
              :after_steps,
              :after_feature_element,
              :after_feature,
              :after_features,
          ]
        end

        it 'a feature with two scenarios' do
          execute_gherkin do
            feature do
              scenario do
                step 'passing'
              end
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background and an empty scenario' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario
            end
          end
          expect( formatter.legacy_messages ).to eq [
            :before_features,
              :before_feature,
                :before_tags,
                :after_tags,
                :feature_name,
                :before_background,
                  :background_name,
                  :before_steps,
                    :before_step,
                      :before_step_result,
                        :step_name,
                      :after_step_result,
                    :after_step,
                  :after_steps,
                :after_background,
                :before_feature_element,
                  :before_tags,
                  :after_tags,
                  :scenario_name,
                :after_feature_element,
              :after_feature,
            :after_features,
          ]
        end

        it 'a feature with a background and two scenarios' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario do
                step 'passing'
              end
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background and one scenario and one scenario outline' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario do
                step 'passing'
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background and one scenario outline and one scenario' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background and two scenario outlines' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background and one scenario outline with two rows' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background and one scenario outline with two examples tables' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
                examples do
                  row 'result'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background with two steps' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
                step 'passing'
              end
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'a feature with a background' do
          execute_gherkin do
            feature do
              background do
                step 'passing'
              end
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
              :before_feature,
              :before_tags,
              :after_tags,
              :feature_name,
              :before_background,
              :background_name,
              :before_steps,
              :before_step,
              :before_step_result,
              :step_name,
              :after_step_result,
              :after_step,
              :after_steps,
              :after_background,
              :before_feature_element,
              :before_tags,
              :after_tags,
              :scenario_name,
              :before_steps,
              :before_step,
              :before_step_result,
              :step_name,
              :after_step_result,
              :after_step,
              :after_steps,
              :after_feature_element,
              :after_feature,
              :after_features,
          ]
        end

        it 'scenario outline' do
          execute_gherkin do
            feature do
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'scenario outline after scenario' do
          execute_gherkin do
            feature do
              scenario do
                step 'passing'
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
          ]
        end

        it 'scenario outline before scenario' do
          execute_gherkin do
            feature do
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ]
        end

        it 'scenario outline two rows' do
          execute_gherkin do
            feature do
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ]
        end

        it 'scenario outline two examples tables' do
          execute_gherkin do
            feature do
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
                examples do
                  row 'result'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ]
        end

        it 'two scenario outline' do
          execute_gherkin do
            feature do
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'pass'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ]
        end

        it 'failing scenario outline' do
          execute_gherkin do
            feature do
              scenario_outline do
                step '<result>ing'
                examples do
                  row 'result'
                  row 'fail'
                end
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ]
        end

        it 'a feature with a failing background and two scenarios' do
          execute_gherkin do
            feature do
              background do
                step 'failing'
              end
              scenario do
                step 'passing'
              end
              scenario do
                step 'passing'
              end
            end
          end
          expect( formatter.legacy_messages ).to eq [
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_background,
                    :background_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                          :exception,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_background,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ]
        end

        context 'in expand mode' do
          let(:runtime) { Runtime.new expand: true }
          let(:formatter) { MessageSpy.new }

          it 'scenario outline two rows' do
            execute_gherkin do
              feature do
                scenario_outline do
                  step '<result>ing'
                  examples do
                    row 'result'
                    row 'pass'
                    row 'pass'
                  end
                end
              end
            end
            expect( formatter.legacy_messages ).to eq [
                :before_features,
                  :before_feature,
                    :before_tags,
                    :after_tags,
                    :feature_name,
                    :before_feature_element,
                      :before_tags,
                      :after_tags,
                      :scenario_name,
                      :before_steps,
                        :before_step,
                          :before_step_result,
                            :step_name,
                          :after_step_result,
                        :after_step,
                      :after_steps,
                      :before_examples_array,
                        :before_examples,
                          :before_tags,
                          :after_tags,
                          :examples_name,
                          :before_outline_table,
                            :scenario_name,
                            :before_step,
                              :before_step_result,
                                :step_name,
                              :after_step_result,
                            :after_step,
                            :scenario_name,
                            :before_step,
                              :before_step_result,
                                :step_name,
                              :after_step_result,
                            :after_step,
                          :after_outline_table,
                        :after_examples,
                      :after_examples_array,
                    :after_feature_element,
                  :after_feature,
                :after_features,
              ]
          end
        end

        context 'with exception in after step hook' do

          class FailingAfterStepHook
            def find_after_step_hooks(test_case)
              failing_hook = HookWrapper.new(proc { raise Failure })
              Runtime::StepHooks.new [failing_hook]
            end
          end

          it 'prints the exception within the step' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyAfterStepHooks.new(FailingAfterStepHook.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end
            expect( formatter.legacy_messages ).to eq([
                :before_features,
                  :before_feature,
                    :before_tags,
                    :after_tags,
                    :feature_name,
                    :before_feature_element,
                      :before_tags,
                      :after_tags,
                      :scenario_name,
                      :before_steps,
                        :before_step,
                          :before_step_result,
                          :step_name,
                          :after_step_result,
                        :after_step,
                        :exception,
                      :after_steps,
                    :after_feature_element,
                  :after_feature,
                :after_features,
                ])
          end
        end

        context 'with exception in a single before hook' do
          class FailingBeforeHook
            def apply_before_hooks(test_case)
              failing_hook = HookWrapper.new(proc { raise Failure })
              Runtime::BeforeHooks.new([failing_hook], RunningTestCase.new(test_case)).apply_to(test_case)
            end
          end

          it 'prints the exception after the scenario name' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyBeforeHooks.new(FailingBeforeHook.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
                :before_features,
                  :before_feature,
                    :before_tags,
                    :after_tags,
                    :feature_name,
                    :before_feature_element,
                      :before_tags,
                      :after_tags,
                      :scenario_name,
                      :exception,
                      :before_steps,
                        :before_step,
                          :before_step_result,
                          :step_name,
                          :after_step_result,
                        :after_step,
                      :after_steps,
                    :after_feature_element,
                  :after_feature,
                :after_features,
                ])
          end

          it 'prints the exception after the background name' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyBeforeHooks.new(FailingBeforeHook.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                background do
                  step 'passing'
                end
                scenario do
                  step 'passing'
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
                :before_features,
                  :before_feature,
                    :before_tags,
                    :after_tags,
                    :feature_name,
                    :before_background,
                      :background_name,
                      :exception,
                      :before_steps,
                        :before_step,
                          :before_step_result,
                            :step_name,
                          :after_step_result,
                        :after_step,
                      :after_steps,
                    :after_background,
                    :before_feature_element,
                      :before_tags,
                      :after_tags,
                      :scenario_name,
                      :before_steps,
                        :before_step,
                          :before_step_result,
                          :step_name,
                          :after_step_result,
                        :after_step,
                      :after_steps,
                    :after_feature_element,
                  :after_feature,
                :after_features,
                ])
          end


          it 'prints the exception before the examples table row' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyBeforeHooks.new(FailingBeforeHook.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario_outline do
                  step '<status>ing'
                  examples do
                    row 'status'
                    row 'pass'
                  end
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
                :before_features,
                  :before_feature,
                    :before_tags,
                    :after_tags,
                    :feature_name,
                    :before_feature_element,
                      :before_tags,
                      :after_tags,
                      :scenario_name,
                      :before_steps,
                        :before_step,
                          :before_step_result,
                            :step_name,
                          :after_step_result,
                        :after_step,
                      :after_steps,
                      :before_examples_array,
                        :before_examples,
                          :before_tags,
                          :after_tags,
                          :examples_name,
                          :before_outline_table,
                            :before_table_row,
                              :before_table_cell,
                                :table_cell_value,
                              :after_table_cell,
                            :after_table_row,
                            :exception,
                            :before_table_row,
                              :before_table_cell,
                                :table_cell_value,
                              :after_table_cell,
                            :after_table_row,
                          :after_outline_table,
                        :after_examples,
                      :after_examples_array,
                    :after_feature_element,
                  :after_feature,
                :after_features,
              ])
          end
        end

        context 'with exception in the first of several before hooks' do
          # This proves that the second before hook's result doesn't overwrite
          # the result of the first one.
          class FailingAndPassingBeforeHooks
            def apply_before_hooks(test_case)
              failing_hook = HookWrapper.new(proc { raise Failure })
              passing_hook = HookWrapper.new(proc {})
              Runtime::BeforeHooks.new([failing_hook, passing_hook], RunningTestCase.new(test_case)).apply_to(test_case)
            end
          end

          it 'prints the exception after the scenario name' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyBeforeHooks.new(FailingAndPassingBeforeHooks.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
                :before_features,
                  :before_feature,
                    :before_tags,
                    :after_tags,
                    :feature_name,
                    :before_feature_element,
                      :before_tags,
                      :after_tags,
                      :scenario_name,
                      :exception,
                      :before_steps,
                        :before_step,
                          :before_step_result,
                          :step_name,
                          :after_step_result,
                        :after_step,
                      :after_steps,
                    :after_feature_element,
                  :after_feature,
                :after_features,
                ])
          end
        end

        context 'with exception in after hooks' do

          class FailingAfterHook
            def apply_after_hooks(test_case)
              failing_hook = HookWrapper.new(proc { raise Failure })
              Runtime::AfterHooks.new([failing_hook], RunningTestCase.new(test_case)).apply_to(test_case)
            end
          end

          it 'prints the exception after the steps' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyAfterHooks.new(FailingAfterHook.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                        :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :exception,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ])
          end

          it 'prints the exception after the examples table row' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyAfterHooks.new(FailingAfterHook.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario_outline do
                  step '<status>ing'
                  examples do
                    row 'status'
                    row 'pass'
                  end
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                          :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :before_examples_array,
                      :before_examples,
                        :before_tags,
                        :after_tags,
                        :examples_name,
                        :before_outline_table,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :before_table_row,
                            :before_table_cell,
                              :table_cell_value,
                            :after_table_cell,
                          :after_table_row,
                          :exception,
                        :after_outline_table,
                      :after_examples,
                    :after_examples_array,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ])
          end
        end

        context 'with exception in the first of several after hooks' do
          class FailingThenPassingAfterHooks
            def apply_after_hooks(test_case)
              failing_hook = HookWrapper.new(proc { raise Failure })
              passing_hook = HookWrapper.new(proc {})
              Runtime::AfterHooks.new([failing_hook, passing_hook], RunningTestCase.new(test_case)).apply_to(test_case)
            end
          end

          it 'prints the exception after the steps' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyAfterHooks.new(FailingThenPassingAfterHooks.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                      :before_step,
                        :before_step_result,
                        :step_name,
                        :after_step_result,
                      :after_step,
                    :after_steps,
                    :exception,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ])
          end
        end

        context 'with an exception in an after hook but no steps' do
          it 'prints the exception after the scenario name' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyAfterHooks.new(FailingAfterHook.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :exception,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ])
          end
        end

        context 'with an exception in an around hook before the test case is run' do
          class FailingAroundHookBeforeRunningTestCase
            def find_around_hooks(test_case)
              [
                Hooks.around_hook(test_case.source) { raise Failure }
              ]
            end
          end

          it 'prints the exception after the scenario name' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyAroundHooks.new(FailingAroundHookBeforeRunningTestCase.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :exception,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ])
          end
        end

        context 'with an exception in an around hook after the test case is run' do
          class FailingAroundHookAfterRunningTestCase
            def find_around_hooks(test_case)
              [
                Hooks.around_hook(test_case.source) { |run_test_case| run_test_case.call; raise Failure }
              ]
            end
          end

          it 'prints the exception after the scenario name' do
            filters = [
              Filters::ActivateSteps.new(step_match_search, runtime.configuration),
              Filters::ApplyAroundHooks.new(FailingAroundHookAfterRunningTestCase.new),
              AddBeforeAndAfterHooks.new
            ]
            execute_gherkin(filters) do
              feature do
                scenario do
                  step
                end
              end
            end

            expect( formatter.legacy_messages ).to eq([
              :before_features,
                :before_feature,
                  :before_tags,
                  :after_tags,
                  :feature_name,
                  :before_feature_element,
                    :before_tags,
                    :after_tags,
                    :scenario_name,
                    :before_steps,
                    :before_step,
                    :before_step_result,
                    :step_name,
                    :after_step_result,
                    :after_step,
                    :exception,
                    :after_steps,
                  :after_feature_element,
                :after_feature,
              :after_features,
            ])
          end
        end
      end

      describe 'before_step_result message' do
        context 'when the step matches' do
          it "sends the step match to the formatter" do
            expect(formatter).to receive(:before_step_result) do |_, step_match, *|
              expect(step_match).to be_a SimpleStepMatch
            end
            execute_gherkin do
              feature do
                scenario do
                  step 'passing'
                end
              end
            end
          end
        end

        context "when the step doesn't match" do
          it "sends a null object to the formatter" do
          end
        end
      end

      it 'passes nil as the multiline arg when there is none' do
        expect(formatter).to receive(:after_step_result) do |keyword, step_match, multiline_arg, status, exception, source_indent, background, file_colon_line|
          expect(multiline_arg).to be_nil
        end
        execute_gherkin do
          feature do
            scenario do
              step 'passing'
            end
          end
        end
      end

      context "after_feature_element callback" do
        it 'passes an object reflecting the status of the scenario' do
          expect( formatter ).to receive(:after_feature_element).once do |scenario|
            expect( scenario ).to be_failed
          end
          execute_gherkin do
            feature do
              scenario do
                step 'failing'
                step 'this will be skipped'
              end
            end
          end
        end
      end

      context 'in strict mode' do
        let(:runtime) { Runtime.new strict: true }

        it 'passes an exception to the formatter for undefined steps' do
          expect( formatter ).to receive(:exception) do |exception|
            expect( exception.message ).to eq %{Undefined step: "this step is undefined"}
          end
          execute_gherkin do
            feature do
              scenario do
                step 'this step is undefined'
              end
            end
          end
        end
      end

      class MessageSpy
        attr_reader :messages

        def initialize
          @messages = []
        end

        def legacy_messages
          @messages - [
            :before_test_step,
            :before_test_case,
            :after_test_step,
            :after_test_case,
            :done
          ]
        end

        def method_missing(message, *args)
          @messages << message
        end

        def respond_to_missing?(name, include_private = false)
          true
        end
      end

      def execute_gherkin(filters = default_filters, &gherkin)
        runner = Core::Test::Runner.new(report)
        compile [gherkin(&gherkin)], runner, filters
      end

      def default_filters
        [
          Filters::ActivateSteps.new(step_match_search, runtime.configuration),
          AddBeforeAndAfterHooks.new
        ]
      end

    end
  end
end
