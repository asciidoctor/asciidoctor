require "cucumber/filters/tag_limits"

describe Cucumber::Filters::TagLimits do
  subject(:filter) { Cucumber::Filters::TagLimits.new(tag_limits, receiver) }

  let(:tag_limits) { double(:tag_limits) }
  let(:receiver) { double(:receiver) }

  let(:gated_receiver) { double(:gated_receiver) }
  let(:test_case_index) { double(:test_case_index) }
  let(:test_case) { double(:test_case) }

  before do
    allow(Cucumber::Filters::GatedReceiver).to receive(:new).with(receiver) { gated_receiver }
    allow(Cucumber::Filters::TagLimits::TestCaseIndex).to receive(:new) { test_case_index }
  end

  describe "#test_case" do
    before do
      allow(test_case_index).to receive(:add)
      allow(gated_receiver).to receive(:test_case)
    end

    it "indexes the test case" do
      expect(test_case_index).to receive(:add).with(test_case)
      filter.test_case(test_case)
    end

    it "adds the test case to the gated receiver" do
      expect(gated_receiver).to receive(:test_case).with(test_case)
      filter.test_case(test_case)
    end
  end

  describe "#done" do
    let(:verifier) { double(:verifier) }

    before do
      allow(Cucumber::Filters::TagLimits::Verifier).to receive(:new).with(tag_limits) { verifier }
      allow(gated_receiver).to receive(:done)
    end

    it "verifies tag limits have not been exceeded" do
      expect(verifier).to receive(:verify!).with(test_case_index)
      filter.done
    end

    context "the verifier verifies successfully" do
      before do
        allow(verifier).to receive(:verify!).with(test_case_index)
      end

      it "calls done on the receiver gate" do
        expect(gated_receiver).to receive(:done)
        filter.done
      end
    end
  end
end
