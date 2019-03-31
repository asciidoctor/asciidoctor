require 'spec_helper'
require 'cucumber/rake/task'
require 'rake'

module Cucumber
  module Rake
    describe Task do

      describe "#cucumber_opts" do
        before { subject.cucumber_opts = opts }

        context "when set via array" do
          let(:opts) { %w[ foo bar ] }
          it { expect(subject.cucumber_opts).to be opts }
        end

        context "when set via space-delimited string" do
          let(:opts) { "foo bar" }
          it { expect(subject.cucumber_opts).to eq %w[ foo bar ] }
        end
      end

      describe "#cucumber_opts_with_profile" do
        before do
          subject.cucumber_opts = opts
          subject.profile = profile
        end

        context "with cucumber_opts" do
          let(:opts) { %w[ foo bar ] }

          context "without profile" do
            let(:profile) { nil }

            it "should return just cucumber_opts" do
              expect(subject.cucumber_opts_with_profile).to be opts
            end
          end

          context "with profile" do
            let(:profile) { "fancy" }

            it "should combine opts and profile into an array, prepending --profile option" do
              expect(subject.cucumber_opts_with_profile).to eq %w[ foo bar --profile fancy ]
            end
          end

          context "with multiple profiles" do
            let(:profile) { %w[ fancy pants ] }

            it "should combine opts and each profile into an array, prepending --profile option" do
              expect(subject.cucumber_opts_with_profile).to eq %w[ foo bar --profile fancy --profile pants ]
            end
          end
        end

        context "without cucumber_opts" do
          let(:opts) { nil }

          context "without profile" do
            let(:profile) { nil }

            it { expect(subject.cucumber_opts_with_profile).to eq [] }
          end

          context "with profile" do
            let(:profile) { "fancy" }

            it "should combine opts and profile into an array, prepending --profile option" do
              expect(subject.cucumber_opts_with_profile).to eq %w[ --profile fancy ]
            end
          end

          context "with multiple profiles" do
            let(:profile) { %w[ fancy pants ] }

            it "should combine opts and each profile into an array, prepending --profile option" do
              expect(subject.cucumber_opts_with_profile).to eq %w[ --profile fancy --profile pants ]
            end
          end
        end
      end
    end
  end
end
