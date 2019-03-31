require 'spec_helper'
require 'cucumber/formatter/duration'

module Cucumber
  module Formatter
    describe Duration do
      include Duration

      it "formats ms" do
        expect(format_duration(0.002103)).to eq '0m0.002s'
      end

      it "formats m" do
        expect(format_duration(61.002503)).to eq'1m1.003s'
      end

      it "formats h" do
        expect(format_duration(3661.002503)).to eq '61m1.003s'
      end
    end
  end
end
