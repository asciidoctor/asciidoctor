require 'spec_helper'
require 'cucumber/rb_support/snippet'

module Cucumber
  module RbSupport
    describe Snippet do
      let(:code_keyword) { "Given" }

      before do
        @pattern = 'we have a missing step'
        @multiline_argument = Core::Ast::EmptyMultilineArgument.new
      end

      let(:snippet) do
        snippet_class.new(code_keyword, @pattern, @multiline_argument)
      end

      def unindented(s)
        s.split("\n")[1..-2].join("\n").indent(-10)
      end

      describe Snippet::Regexp do
        let(:snippet_class) { Snippet::Regexp }
        let(:snippet_text) { snippet.to_s }

        it "wraps snippet patterns in parentheses" do
          @pattern = 'A "string" with 4 spaces'

          expect(snippet_text).to eq unindented(%{
          Given(/^A "([^"]*)" with (\\d+) spaces$/) do |arg1, arg2|
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end

        it "recognises numbers in name and make according regexp" do
          @pattern = 'Cloud 9 yeah'

          expect(snippet_text).to eq unindented(%{
          Given(/^Cloud (\\d+) yeah$/) do |arg1|
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end

        it "recognises a mix of ints, strings and why not a table too" do
          @pattern = 'I have 9 "awesome" cukes in 37 "boxes"'
          @multiline_argument = Core::Ast::DataTable.new([[]], Core::Ast::Location.new(''))

          expect(snippet_text).to eq unindented(%{
          Given(/^I have (\\d+) "([^"]*)" cukes in (\\d+) "([^"]*)"$/) do |arg1, arg2, arg3, arg4, table|
            # table is a Cucumber::MultilineArgument::DataTable
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end

        it "recognises quotes in name and make according regexp" do
          @pattern = 'A "first" arg'

          expect(snippet_text).to eq unindented(%{
          Given(/^A "([^"]*)" arg$/) do |arg1|
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end

        it "recognises several quoted words in name and make according regexp and args" do
          @pattern = 'A "first" and "second" arg'

          expect(snippet_text).to eq unindented(%{
          Given(/^A "([^"]*)" and "([^"]*)" arg$/) do |arg1, arg2|
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end

        it "does not use quote group when there are no quotes" do
          @pattern = 'A first arg'

          expect(snippet_text).to eq unindented(%{
          Given(/^A first arg$/) do
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end

        it "is helpful with tables" do
          @pattern = 'A "first" arg'
          @multiline_argument = Core::Ast::DataTable.new([[]], Core::Ast::Location.new(""))

          expect(snippet_text).to eq unindented(%{
          Given(/^A "([^"]*)" arg$/) do |arg1, table|
            # table is a Cucumber::MultilineArgument::DataTable
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end

        it "is helpful with doc string" do
          @pattern = 'A "first" arg'
          @multiline_argument = MultilineArgument.from("", Core::Ast::Location.new(""))

          expect(snippet_text).to eq unindented(%{
          Given(/^A "([^"]*)" arg$/) do |arg1, string|
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end
      end

      describe Snippet::Classic do
        let(:snippet_class) { Snippet::Classic }

        it "renders snippet as unwrapped regular expression" do
          expect(snippet.to_s).to eq unindented(%{
          Given /^we have a missing step$/ do
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end
      end

      describe Snippet::Percent do
        let(:snippet_class) { Snippet::Percent }

        it "renders snippet as percent-style regular expression" do
          expect(snippet.to_s).to eq unindented(%{
          Given %r{^we have a missing step$} do
            pending # Write code here that turns the phrase above into concrete actions
          end
          })
        end
      end
    end
  end
end
