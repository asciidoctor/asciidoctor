require 'cucumber/core'
require 'cucumber/core/compiler'
require 'cucumber/core/gherkin/writer'

module Cucumber::Core
  describe Compiler do
    include Gherkin::Writer
    include Cucumber::Core

    def self.stubs(*names)
      names.each do |name|
        let(name) { double(name.to_s) }
      end
    end

    it "compiles a feature with a single scenario" do
      gherkin_documents = [
        gherkin do
          feature do
            scenario do
              step 'passing'
            end
          end
        end
      ]
      compile(gherkin_documents) do |visitor|
        expect( visitor ).to receive(:test_case).once.ordered.and_yield(visitor)
        expect( visitor ).to receive(:test_step).once.ordered
        expect( visitor ).to receive(:done).once.ordered
      end
    end

    it "compiles a feature with a background" do
      gherkin_documents = [
        gherkin do
          feature do
            background do
              step 'passing'
            end

            scenario do
              step 'passing'
            end
          end
        end
      ]
      compile(gherkin_documents) do |visitor|
        expect( visitor ).to receive(:test_case).once.ordered.and_yield(visitor)
        expect( visitor ).to receive(:test_step).exactly(2).times.ordered
        expect( visitor ).to receive(:done).once.ordered
      end
    end

    it "compiles multiple features" do
      gherkin_documents = [
        gherkin do
          feature do
            background do
              step 'passing'
            end
            scenario do
              step 'passing'
            end
          end
        end,
        gherkin do
          feature do
            background do
              step 'passing'
            end
            scenario do
              step 'passing'
            end
          end
        end
      ]
      compile(gherkin_documents) do |visitor|
        expect( visitor ).to receive(:test_case).once.ordered
        expect( visitor ).to receive(:test_step).twice.ordered
        expect( visitor ).to receive(:test_case).once.ordered
        expect( visitor ).to receive(:test_step).twice.ordered
        expect( visitor ).to receive(:done).once
      end
    end

    context "compiling scenario outlines" do
      it "compiles a scenario outline to test cases" do
        gherkin_documents = [
          gherkin do
            feature do
              background do
                step 'passing'
              end

              scenario_outline do
                step 'passing <arg>'
                step 'passing'

                examples 'examples 1' do
                  row 'arg'
                  row '1'
                  row '2'
                end

                examples 'examples 2' do
                  row 'arg'
                  row 'a'
                end
              end
            end
          end
        ]
        compile(gherkin_documents) do |visitor|
          expect( visitor ).to receive(:test_case).exactly(3).times.and_yield(visitor)
          expect( visitor ).to receive(:test_step).exactly(9).times
          expect( visitor ).to receive(:done).once
        end
      end

      it 'replaces arguments correctly when generating test steps' do
        gherkin_documents = [
          gherkin do
            feature do
              scenario_outline do
                step 'passing <arg1> with <arg2>'
                step 'as well as <arg3>'

                examples do
                  row 'arg1', 'arg2', 'arg3'
                  row '1',    '2',    '3'
                end
              end
            end
          end
        ]

        compile(gherkin_documents) do |visitor|
          expect( visitor ).to receive(:test_step) do |test_step|
            visit_source(test_step) do |source_visitor|
              expect( source_visitor ).to receive(:step) do |step|
                expect(step.name).to eq 'passing 1 with 2'
              end
            end
          end.once.ordered

          expect( visitor ).to receive(:test_step) do |test_step|
            visit_source(test_step) do |source_visitor|
              expect( source_visitor ).to receive(:step) do |step|
                expect(step.name).to eq 'as well as 3'
              end
            end
          end.once.ordered

          expect( visitor ).to receive(:done).once.ordered
        end
      end
    end

    describe Compiler::FeatureCompiler do
      let(:receiver) { double('receiver') }
      let(:compiler) { Compiler::FeatureCompiler.new(receiver) }

      context "a scenario with a background" do
        stubs(:feature,
                :background,
                  :background_step,
                :scenario,
                  :scenario_step)

        it "sets the source correctly on the test steps" do
          expect( receiver ).to receive(:on_background_step).with(
            [feature, background, background_step]
          )
          expect( receiver ).to receive(:on_step).with(
            [feature, scenario, scenario_step]
          )
          expect( receiver ).to receive(:on_test_case).with(
            [feature, scenario]
          )
          compiler.feature(feature) do |f|
            f.background(background) do |b|
              b.step background_step
            end
            f.scenario(scenario) do |s|
              s.step scenario_step
            end
          end
        end
      end

      context "a scenario outline" do
        stubs(:feature,
                :background,
                  :background_step,
                :scenario_outline,
                  :outline_step,
                  :examples_table_1,
                    :examples_table_1_row_1,
                      :outline_ast_step,
                  :examples_table_2,
                    :examples_table_2_row_1,
             )

        it "sets the source correctly on the test steps" do
          allow( outline_step ).to receive(:to_step) { outline_ast_step }
          expect( receiver ).to receive(:on_step).with(
            [feature, scenario_outline, examples_table_1, examples_table_1_row_1, outline_ast_step]
          ).ordered
          expect( receiver ).to receive(:on_test_case).with(
            [feature, scenario_outline, examples_table_1, examples_table_1_row_1]
          ).ordered
          expect( receiver ).to receive(:on_step).with(
            [feature, scenario_outline, examples_table_2, examples_table_2_row_1, outline_ast_step]
          ).ordered
          expect( receiver ).to receive(:on_test_case).with(
            [feature, scenario_outline, examples_table_2, examples_table_2_row_1]
          ).ordered
          compiler.feature(feature) do |f|
            f.scenario_outline(scenario_outline) do |o|
              o.outline_step outline_step
              o.examples_table(examples_table_1) do |t|
                t.examples_table_row(examples_table_1_row_1)
              end
              o.examples_table(examples_table_2) do |t|
                t.examples_table_row(examples_table_2_row_1)
              end
            end
          end
        end
      end
    end

    def visit_source(node)
      visitor = double.as_null_object
      yield visitor
      node.describe_source_to(visitor)
    end

    def compile(gherkin_documents)
      visitor = double
      allow( visitor ).to receive(:test_suite).and_yield(visitor)
      allow( visitor ).to receive(:test_case).and_yield(visitor)
      yield visitor
      super(gherkin_documents, visitor)
    end

  end
end

