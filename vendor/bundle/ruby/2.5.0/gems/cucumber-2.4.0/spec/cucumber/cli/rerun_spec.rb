require 'spec_helper'

module Cucumber
  module Cli
    describe RerunFile do

      let(:rerun_file) { RerunFile.new('@rerun.txt') }

      it "expects rerun files to have a leading @" do
        allow(File).to receive(:file?) { true }
        expect(RerunFile.can_read?('rerun.txt')).to eq false
        expect(RerunFile.can_read?('@rerun.txt')).to eq true
      end

      it "does not treat directories as rerun files" do
        allow(File).to receive(:file?) { false }
        expect(RerunFile.can_read?('@rerun.txt')).to eq false
      end

      it "removes leading @ character from filename" do
        expect(rerun_file.path).to eq 'rerun.txt'
      end

      context "rerun file containing single feature" do
        before(:each) do
          allow(IO).to receive(:read).and_return("cucumber.feature")
        end

        it "produces an array containing a single feature file path" do
          expect(rerun_file.features).to eq %w(cucumber.feature)
        end
      end

      context "contains multiple features on multiple lines" do
        before(:each) do
          allow(IO).to receive(:read).and_return("cucumber.feature\nfoo.feature")
        end

        it "produces an array containing multiple feature file paths" do
          expect(rerun_file.features).to eq %w(cucumber.feature foo.feature)
        end
      end

      context "contains multiple features on same line" do
        before(:each) do
          allow(IO).to receive(:read).and_return("cucumber.feature foo.feature")
        end

        it "produces an array containing multiple feature file paths" do
          expect(rerun_file.features).to eq %w(cucumber.feature foo.feature)
        end
      end

      context "contains multiple scenarios on same line" do
        before(:each) do
          allow(IO).to receive(:read).and_return("cucumber.feature:8 foo.feature:8:16")
        end

        it "produces an array containing multiple feature file paths with scenario lines" do
          expect(rerun_file.features).to eq %w(cucumber.feature:8 foo.feature:8:16)
        end
      end

      context "contains features with spaces in file names" do
        before(:each) do
          allow(IO).to receive(:read).and_return("cucumber test.feature:8 foo.feature:8:16")
        end

        it "produces an array containing multiple feature file paths with scenario lines" do
          expect(rerun_file.features).to eq ['cucumber test.feature:8', 'foo.feature:8:16']
        end
      end

      context "contains multiple scenarios without spaces between them" do
        before(:each) do
          allow(IO).to receive(:read).and_return("cucumber test.feature:8foo.feature:8:16")
        end

        it "produces an array containing multiple feature file paths with scenario lines" do
          expect(rerun_file.features).to eq ['cucumber test.feature:8', 'foo.feature:8:16']
        end
      end
    end
  end
end
