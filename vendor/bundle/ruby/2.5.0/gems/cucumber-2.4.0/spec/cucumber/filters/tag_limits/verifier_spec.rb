require "cucumber/filters/tag_limits"

describe Cucumber::Filters::TagLimits::Verifier do
  describe "#verify!" do
    subject(:verifier) { Cucumber::Filters::TagLimits::Verifier.new(tag_limits) }
    let(:test_case_index) { double(:test_case_index) }

    context "the tag counts exceed the tag limits" do
      let(:tag_limits) do
        {
          "@exceed_me" => 1
        }
      end

      let(:locations) do
        [
          double(:location, to_s: "path/to/some.feature:3"),
          double(:location, to_s: "path/to/some/other.feature:8"),
        ]
      end

      before do
        allow(test_case_index).to receive(:count_by_tag_name).with("@exceed_me") { 2 }
        allow(test_case_index).to receive(:locations_of_tag_name).with("@exceed_me") { locations }
      end

      it "raises a TagLimitExceeded error with the locations of the tags" do
        expect {
          verifier.verify!(test_case_index)
        }.to raise_error(
          Cucumber::Filters::TagLimitExceededError,
          "@exceed_me occurred 2 times, but the limit was set to 1\n" +
          "  path/to/some.feature:3\n" +
          "  path/to/some/other.feature:8"
        )
      end
    end

    context "the tag counts do not exceed the tag limits" do
      let(:tag_limits) do
        {
          "@dont_exceed_me" => 2
        }
      end

      before do
        allow(test_case_index).to receive(:count_by_tag_name).with("@dont_exceed_me") { 1 }
      end

      it "does not raise an error" do
        expect {
          verifier.verify!(test_case_index)
        }.to_not raise_error
      end
    end
  end
end
