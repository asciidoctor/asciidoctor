require 'cucumber/core/ast/step'
require 'cucumber/core/ast/outline_step'
require 'cucumber/core/ast/empty_multiline_argument'
require 'gherkin/dialect'

module Cucumber
  module Core
    module Ast
      describe Step do
        let(:step) do
          language, location, comments, keyword, name = *double
          multiline_arg = EmptyMultilineArgument.new
          Step.new(language, location, comments, keyword, name, multiline_arg)
        end

        describe "describing itself" do
          let(:visitor) { double }

          it "describes itself as a step" do
            expect( visitor ).to receive(:step).with(step)
            step.describe_to(visitor)
          end

          context "with no multiline argument" do
            it "does not try to describe any children" do
              allow( visitor ).to receive(:step).with(step).and_yield(visitor)
              step.describe_to(visitor)
            end
          end

          context "with a multiline argument" do
            let(:step) { Step.new(double, double, double, double, double, multiline_arg) }
            let(:multiline_arg) { double }

            it "tells its multiline argument to describe itself" do
              allow( visitor ).to receive(:step).with(step).and_yield(visitor)
              expect( multiline_arg ).to receive(:describe_to).with(visitor)
              step.describe_to(visitor)
            end
          end

        end

        describe 'comments' do
          it "has comments" do
            expect( step ).to respond_to(:comments)
          end
        end

        describe "backtrace line" do
          let(:step) { Step.new(double, "path/file.feature:10", double, "Given ", "this step passes", double) }

          it "knows how to form the backtrace line" do
            expect( step.backtrace_line ).to eq("path/file.feature:10:in `Given this step passes'")
          end

        end

        describe "actual keyword" do
          let(:language) { ::Gherkin::Dialect.for('en') }

          context "for keywords 'given', 'when' and 'then'" do
            let(:given_step) { Step.new(language, double, double, "Given ", double, double) }
            let(:when_step) { Step.new(language, double, double, "When ", double, double) }
            let(:then_step) { Step.new(language, double, double, "Then ", double, double) }

            it "returns the keyword itself" do
              expect( given_step.actual_keyword(nil) ).to eq("Given ")
              expect( when_step.actual_keyword(nil) ).to eq("When ")
              expect( then_step.actual_keyword(nil) ).to eq("Then ")
            end
          end

          context "for keyword 'and', 'but', and '*'" do
            let(:and_step) { Step.new(language, double, double, "And ", double, double) }
            let(:but_step) { Step.new(language, double, double, "But ", double, double) }
            let(:asterisk_step) { Step.new(language, double, double, "* ", double, double) }

            context "when the previous step keyword exist" do
              it "returns the previous step keyword" do
                expect( and_step.actual_keyword("Then ") ).to eq("Then ")
                expect( but_step.actual_keyword("Then ") ).to eq("Then ")
                expect( asterisk_step.actual_keyword("Then ") ).to eq("Then ")
              end
            end

            context "when the previous step keyword does not exist" do
              it "returns the 'given' keyword" do
                expect( and_step.actual_keyword(nil) ).to eq("Given ")
                expect( but_step.actual_keyword(nil) ).to eq("Given ")
                expect( asterisk_step.actual_keyword(nil) ).to eq("Given ")
              end
            end

          end

          context "for i18n languages" do
            let(:language) { ::Gherkin::Dialect.for('en-lol') }
            let(:and_step) { Step.new(language, double, double, "AN ", double, double) }

            it "returns the keyword in the correct language" do
              expect( and_step.actual_keyword(nil) ).to eq("I CAN HAZ ")
            end
          end
        end
      end

      describe ExpandedOutlineStep do
        let(:outline_step) { double }
        let(:step) do
          language, location, keyword, name = *double
          multiline_arg = EmptyMultilineArgument.new
          comments = []
          ExpandedOutlineStep.new(outline_step, language, location, comments, keyword, name, multiline_arg)
        end

        describe "describing itself" do
          let(:visitor) { double }

          it "describes itself as a step" do
            expect( visitor ).to receive(:step).with(step)
            step.describe_to(visitor)
          end

          context "with no multiline argument" do
            it "does not try to describe any children" do
              allow( visitor ).to receive(:step).with(step).and_yield(visitor)
              step.describe_to(visitor)
            end
          end

          context "with a multiline argument" do
            let(:step) { Step.new(double, double, double, double, double, multiline_arg) }
            let(:multiline_arg) { double }

            it "tells its multiline argument to describe itself" do
              allow( visitor ).to receive(:step).with(step).and_yield(visitor)
              expect( multiline_arg ).to receive(:describe_to).with(visitor)
              step.describe_to(visitor)
            end
          end

        end

        describe 'comments' do
          it "has comments" do
            expect( step ).to respond_to(:comments)
          end
        end

        describe "backtrace line" do
          let(:outline_step) { OutlineStep.new(double, "path/file.feature:5", double, "Given ", "this step <state>", double) }
          let(:step) { ExpandedOutlineStep.new(outline_step, double, "path/file.feature:10", double, "Given ", "this step passes", double) }

          it "includes the outline step in the backtrace line" do
            expect( step.backtrace_line ).to eq("path/file.feature:10:in `Given this step passes'\n" +
                                                "path/file.feature:5:in `Given this step <state>'")
          end

        end
      end
    end
  end
end

