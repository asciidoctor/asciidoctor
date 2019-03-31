require 'spec_helper'

module Cucumber
  describe Configuration do
    describe ".default" do
      subject { Configuration.default }

      it "has an autoload_code_paths containing the standard support and step_definitions folders" do
        expect(subject.autoload_code_paths).to include('features/support')
        expect(subject.autoload_code_paths).to include('features/step_definitions')
      end
    end

    describe "with custom user options" do
      let(:user_options) { { :autoload_code_paths => ['foo/bar/baz'] } }
      subject { Configuration.new(user_options) }

      it "allows you to override the defaults" do
        expect(subject.autoload_code_paths).to eq ['foo/bar/baz']
      end
    end

    context "selecting files to load" do

      def given_the_following_files(*files)
        allow(File).to receive(:directory?) { true }
        allow(File).to receive(:file?) { true }
        allow(Dir).to receive(:[]) { files }
      end

      it "requires env.rb files first" do
        configuration = Configuration.new
        given_the_following_files("/features/support/a_file.rb","/features/support/env.rb")

        expect(configuration.support_to_load).to eq [
          "/features/support/env.rb",
          "/features/support/a_file.rb"
        ]
      end

      it "does not require env.rb files when dry run" do
        configuration = Configuration.new(dry_run: true)
        given_the_following_files("/features/support/a_file.rb","/features/support/env.rb")

        expect(configuration.support_to_load).to eq [
          "/features/support/a_file.rb"
        ]
      end

      it "requires step defs in vendor/{plugins,gems}/*/cucumber/*.rb" do
        given_the_following_files("/vendor/gems/gem_a/cucumber/bar.rb",
                                  "/vendor/plugins/plugin_a/cucumber/foo.rb")

        configuration = Configuration.new

        expect(configuration.step_defs_to_load).to eq [
          "/vendor/gems/gem_a/cucumber/bar.rb",
          "/vendor/plugins/plugin_a/cucumber/foo.rb"
        ]
      end

      describe "--exclude" do

        it "excludes a ruby file from requiring when the name matches exactly" do
          given_the_following_files("/features/support/a_file.rb","/features/support/env.rb")

          configuration = Configuration.new(excludes: [/a_file.rb/])

          expect(configuration.all_files_to_load).to eq [
            "/features/support/env.rb"
          ]
        end

        it "excludes all ruby files that match the provided patterns from requiring" do
          given_the_following_files("/features/support/foof.rb","/features/support/bar.rb",
                                    "/features/support/food.rb","/features/blah.rb",
                                    "/features/support/fooz.rb")

          configuration = Configuration.new(excludes: [/foo[df]/, /blah/])

          expect(configuration.all_files_to_load).to eq [
            "/features/support/bar.rb",
            "/features/support/fooz.rb"
          ]
        end
      end

    end

    context "selecting feature files" do

      it "preserves the order of the feature files" do
        configuration = Configuration.new(paths: %w{b.feature c.feature a.feature})

        expect(configuration.feature_files).to eq ["b.feature", "c.feature", "a.feature"]
      end

      it "searchs for all features in the specified directory" do
        allow(File).to receive(:directory?) { true }
        allow(Dir).to receive(:[]).with("feature_directory/**/*.feature") { ["cucumber.feature"] }

        configuration = Configuration.new(paths: %w{feature_directory/})

        expect(configuration.feature_files).to eq ["cucumber.feature"]
      end

      it "defaults to the features directory when no feature file are provided" do
        allow(File).to receive(:directory?) { true }
        allow(Dir).to receive(:[]).with("features/**/*.feature") { ["cucumber.feature"] }

        configuration = Configuration.new(paths: [])

        expect(configuration.feature_files).to eq ["cucumber.feature"]
      end

      it "gets the feature files from the rerun file" do
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:file?).and_return(true)
        allow(IO).to receive(:read).and_return(
          "cucumber.feature:1:3\ncucumber.feature:5 cucumber.feature:10\n"\
          "domain folder/different cuke.feature:134 domain folder/cuke.feature:1\n"\
          "domain folder/different cuke.feature:4:5 bar.feature")

        configuration = Configuration.new(paths: %w{@rerun.txt})

        expect(configuration.feature_files).to eq [
          "cucumber.feature:1:3",
          "cucumber.feature:5",
          "cucumber.feature:10",
          "domain folder/different cuke.feature:134",
          "domain folder/cuke.feature:1",
          "domain folder/different cuke.feature:4:5",
          "bar.feature"]
      end
    end

    describe "#with_options" do
      it "returns a copy of the configuration with new options" do
        old_out_stream = double('Old out_stream')
        new_out_stream = double('New out_stream')
        config = Configuration.new(out_stream: old_out_stream).with_options(out_stream: new_out_stream)
        expect(config.out_stream).to eq new_out_stream
      end
    end

  end
end
