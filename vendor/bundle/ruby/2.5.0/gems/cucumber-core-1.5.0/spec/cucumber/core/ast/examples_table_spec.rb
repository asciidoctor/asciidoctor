require 'cucumber/core/ast/examples_table'

module Cucumber::Core::Ast
  describe ExamplesTable do
    let(:location) { double(:to_s => 'file.feature:8') }
    let(:language) { double }
    let(:comments) { double }

    describe ExamplesTable::Header do
      let(:header) { ExamplesTable::Header.new(%w{foo bar baz}, location, comments) }

      describe 'location' do
        it 'knows the file and line number' do
          expect( header.file_colon_line ).to eq 'file.feature:8'
        end
      end

      describe 'comments' do
        it "has comments" do
          expect( header ).to respond_to(:comments)
        end
      end

      context 'building a row' do
        it 'includes the header values as keys' do
          expect( header.build_row(%w{1 2 3}, 1, location, language, comments) ).to eq ExamplesTable::Row.new({'foo' => '1', 'bar' => '2', 'baz' => '3'}, 1, location, language, comments)
        end
      end
    end
    describe ExamplesTable::Row do

      describe 'location' do
        it 'knows the file and line number' do
          row = ExamplesTable::Row.new({}, 1, location, language, comments)
          expect( row.file_colon_line ).to eq 'file.feature:8'
        end
      end

      describe 'language' do
        it "has a language" do
          expect( ExamplesTable::Row.new({}, 1, location, language, comments) ).to respond_to(:language)
        end
      end

      describe 'comments' do
        it "has comments" do
          expect( ExamplesTable::Row.new({}, 1, location, language, comments) ).to respond_to(:comments)
        end
      end

      describe "expanding a string" do
        context "when an argument matches" do
          it "replaces the argument with the value from the row" do
            row = ExamplesTable::Row.new({'arg' => 'replacement'}, 1, location, language, comments)
            text = 'this <arg> a test'
            expect( row.expand(text) ).to eq 'this replacement a test'
          end
        end

        context "when the replacement value is nil" do
          it "uses an empty string for the replacement" do
            row = ExamplesTable::Row.new({'color' => nil}, 1, location, language, comments)
            text = 'a <color> cucumber'
            expect( row.expand(text) ).to eq 'a  cucumber'
          end
        end

        context "when an argument does not match" do
          it "ignores the arguments that do not match" do
            row = ExamplesTable::Row.new({'x' => '1', 'y' => '2'}, 1, location, language, comments)
            text = 'foo <x> bar <z>'
            expect( row.expand(text) ).to eq 'foo 1 bar <z>'
          end
        end
      end

      describe 'accesing the values' do
        it 'returns the actual row values' do
          row = ExamplesTable::Row.new({'x' => '1', 'y' => '2'}, 1, location, language, comments)
          expect( row.values ).to eq ['1', '2']
        end
      end

      describe 'equality' do
        let(:data) { {} }
        let(:number) { double }
        let(:location) { double }
        let(:original) { ExamplesTable::Row.new(data, number, location, language, comments) }

        it 'is equal to another instance with the same data, number and location' do
          expect( original ).to eq ExamplesTable::Row.new(data, number, location, language, comments)
        end

        it 'is not equal to another instance with different data, number or location' do
          expect( original ).not_to eq ExamplesTable::Row.new({'x' => 'y'}, number, location, language, comments)
          expect( original ).not_to eq ExamplesTable::Row.new(data, double, location, language, comments)
          expect( original ).not_to eq ExamplesTable::Row.new(data, number, double, double, double)
        end

        it 'is not equal to another type of object' do
          expect( original ).not_to eq double(data: data, number: number, location: location, language: language)
        end

      end
    end
  end
end
