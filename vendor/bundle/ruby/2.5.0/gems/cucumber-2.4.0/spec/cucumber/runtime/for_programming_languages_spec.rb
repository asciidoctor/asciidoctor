require 'spec_helper'

module Cucumber
  describe Runtime::ForProgrammingLanguages do

    let(:user_interface)  { double('user interface') }
    subject               { Runtime::SupportCode.new(user_interface) }
    let(:runtime_facade)  { Runtime::ForProgrammingLanguages.new(subject, user_interface) }

    describe "#doc_string" do

      it 'defaults to a blank content-type' do
        str = runtime_facade.doc_string('DOC')
        expect(str).to be_kind_of(MultilineArgument::DocString)
        expect(str.content_type).to eq('')
      end

      it 'can have a content type' do
        str = runtime_facade.doc_string('DOC','ruby')
        expect(str.content_type).to eq('ruby')
      end

    end

    describe "#table" do

      it 'produces Ast::Table by #table' do
        expect(runtime_facade.table(%{
      | account | description | amount |
      | INT-100 | Taxi        | 114    |
      | CUC-101 | Peeler      | 22     |
        })).to be_kind_of(MultilineArgument::DataTable)
      end
    end
  end
end
