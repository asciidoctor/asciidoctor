require "cucumber/filters/tag_limits"

describe Cucumber::Filters::TagLimits::TestCaseIndex do
  subject(:index) { Cucumber::Filters::TagLimits::TestCaseIndex.new }

  let(:test_cases) do
    [
      double(:test_case, tags: [tag_one], location: a_location_of_tag_one),
      double(:test_case, tags: [tag_one, tag_two], location: a_location_of_tag_one_and_tag_two)
    ]
  end

  let(:tag_one) { double(:tag_one, name: "@one") }
  let(:tag_two) { double(:tag_two, name: "@two") }

  let(:a_location_of_tag_one) { double(:a_location_of_tag_one) }
  let(:a_location_of_tag_one_and_tag_two) { double(:a_location_of_tag_one_and_tag_two) }

  before do
    test_cases.map do |test_case|
      index.add(test_case)
    end
  end

  describe "#count_by_tag_name" do
    it "returns the number of test cases with the tag" do
      expect(index.count_by_tag_name("@one")).to eq(2)
      expect(index.count_by_tag_name("@two")).to eq(1)
    end
  end

  describe "#locations_by_tag_name" do
    it "returns the locations of test cases with the tag" do
      expect(index.locations_of_tag_name("@one")).to eq([a_location_of_tag_one, a_location_of_tag_one_and_tag_two])
      expect(index.locations_of_tag_name("@two")).to eq([a_location_of_tag_one_and_tag_two])
    end
  end
end
