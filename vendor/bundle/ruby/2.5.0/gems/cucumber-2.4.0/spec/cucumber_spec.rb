require 'cucumber'

describe Cucumber do

  # Implementation is backported from ruby 2.0 when cucumber is used on ruby 1.9.
  # The tests will run on all implementations to ensure we have the same
  # feature set.
  describe 'Hash' do
    it "converts nil to empty {}" do
      expect(Cucumber::Hash(nil)).to eq({})
    end

    it "converts [] to {}" do
      expect(Cucumber::Hash([])).to eq({})
    end

    it "converts a hash to an equivalent hash" do
      original = {:a => 1, :b => 2}
      expect(Cucumber::Hash(original)).to eq({a: 1, b: 2})
    end

    it "converts an object with a to_hash method" do
      original = Object.new
      def original.to_hash
        {key: "value"}
      end

      expect(Cucumber::Hash(original)).to eq({key: "value"})
    end

    it "raises a TypeError for an object that does not have .to_hash" do
      original = %w(cannot convert to hash)

      expect { Cucumber::Hash(original) }.to raise_error TypeError
    end
  end
end


