require 'spec_helper'
require 'cucumber/formatter/ansicolor'

module Cucumber
  module Formatter
    describe ANSIColor do
      include ANSIColor

      it "wraps passed_param with bold green and reset to green" do
        expect(passed_param("foo")).to eq "\e[32m\e[1mfoo\e[0m\e[0m\e[32m"
      end

      it "wraps passed in green" do
        expect(passed("foo")).to eq "\e[32mfoo\e[0m"
      end

      it "does not reset passed if there are no arguments" do
        expect(passed).to eq "\e[32m"
      end

      it "wraps comments in grey" do
        expect(comment("foo")).to eq "\e[90mfoo\e[0m"
      end

      it "does not generate ansi codes when colors are disabled" do
        ::Cucumber::Term::ANSIColor.coloring = false

        expect(passed("foo")).to eq "foo"
      end
    end
  end
end
