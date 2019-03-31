require 'cucumber/core/ast/outline_step'
require 'cucumber/core/ast/examples_table'
require 'cucumber/core/ast/data_table'
require 'cucumber/core/ast/doc_string'
require 'cucumber/core/ast/empty_multiline_argument'

module Cucumber
  module Core
    module Ast
      describe OutlineStep do
        let(:outline_step) { OutlineStep.new(language, location, comments, keyword, name, multiline_arg) }
        let(:language) { double }
        let(:location) { double }
        let(:comments)  { double }
        let(:keyword)  { double }
        let(:name)     { 'anything' }
        let(:multiline_arg) { EmptyMultilineArgument.new }

        describe 'location' do
          it "has a location" do
            expect( outline_step ).to respond_to(:location)
          end

          it 'knows the file and line' do
            allow( location ).to receive(:to_s) { 'file_name:8' }
            expect( outline_step.file_colon_line ).to eq 'file_name:8'
          end
        end

        describe 'comments' do
          it "has comments" do
            expect( outline_step ).to respond_to(:comments)
          end
        end

        describe "converting to a Step" do
          context "a single argument in the name" do
            let(:name) { 'a <color> cucumber' }

            it "replaces the argument" do
              row = ExamplesTable::Row.new({'color' => 'green'}, 1, location, language, comments)
              expect( outline_step.to_step(row).name ).to eq 'a green cucumber'
            end

          end

          context "when the step has a DataTable" do
            let(:outline_step) { OutlineStep.new(language, location, comments, keyword, name, table) }
            let(:name)  { "anything" }
            let(:table) { DataTable.new([['x', 'y'],['a', 'a <arg>']], Location.new('foo.feature', 23)) }

            it "replaces the arguments in the DataTable" do
              visitor = double
              allow( visitor ).to receive(:step).and_yield(visitor)
              expect( visitor ).to receive(:data_table) do |data_table|
                expect( data_table.raw ).to eq [['x', 'y'], ['a', 'a replacement']]
              end
              row = ExamplesTable::Row.new({'arg' => 'replacement'}, 1, location, language, comments)
              step = outline_step.to_step(row)
              step.describe_to(visitor)
            end
          end

          context "when the step has a DocString" do
            let(:location) { double }
            let(:outline_step) { OutlineStep.new(language, location, comments, keyword, name, doc_string) }
            let(:doc_string) { DocString.new('a <arg> that needs replacing', '', location) }
            let(:name) { 'anything' }

            it "replaces the arguments in the DocString" do
              visitor = double
              allow( visitor ).to receive(:step).and_yield(visitor)
              expect( visitor ).to receive(:doc_string) do |doc_string|
                expect( doc_string.content ).to eq "a replacement that needs replacing"
              end
              row = ExamplesTable::Row.new({'arg' => 'replacement'}, 1, location, language, comments)
              step = outline_step.to_step(row)
              step.describe_to(visitor)
            end
          end
        end
      end
    end
  end
end

