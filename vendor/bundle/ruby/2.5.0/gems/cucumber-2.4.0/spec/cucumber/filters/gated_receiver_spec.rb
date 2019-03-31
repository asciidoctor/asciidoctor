require "cucumber/filters/gated_receiver"

describe Cucumber::Filters::GatedReceiver do
  subject(:gated_receiver) { Cucumber::Filters::GatedReceiver.new(receiver) }

  let(:receiver) { double(:receiver) }
  let(:test_cases){ [double(:test_case), double(:test_case)] }

  describe "#test_case" do
    it "does not immediately describe the test case to the receiver" do
      test_cases.each do |test_case|
        expect(test_case).to_not receive(:describe_to).with(receiver)
      end

      test_cases.each do |test_case|
        gated_receiver.test_case(test_case)
      end
    end
  end

  describe "#done" do
    before do
      test_cases.each do |test_case|
        gated_receiver.test_case(test_case)
      end

      test_cases.each do |test_case|
        allow(test_case).to receive(:describe_to).with(receiver)
      end

      allow(receiver).to receive(:done)
    end

    it "describes all test cases to the receiver" do
      test_cases.each do |test_case|
        expect(test_case).to receive(:describe_to).with(receiver)
      end

      gated_receiver.done
    end

    it "calls done on the receiver" do
      expect(receiver).to receive(:done)
      gated_receiver.done
    end
  end
end
