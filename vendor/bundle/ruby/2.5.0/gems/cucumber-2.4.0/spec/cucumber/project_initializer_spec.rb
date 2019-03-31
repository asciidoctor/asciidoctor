require 'spec_helper'
require 'tmpdir'

module Cucumber
  describe ProjectInitializer, :isolated_home => true do
    let(:command_line_config) { ProjectInitializer.new }

    before do
      allow(command_line_config).to receive(:puts)
    end

    context "no files created" do
      around(:example) do |example|

        dir = Dir.mktmpdir
        original_dir = Dir.pwd
        begin
          FileUtils.cd dir
          example.call
        ensure
          FileUtils.cd original_dir
          FileUtils.rm_rf dir
        end
      end

      it "should create features directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+create\s+features$)
        command_line_config.run
      end

      it "should create step_definitions directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+create\s+features/step_definitions$)
        command_line_config.run
      end

      it "should create support directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+create\s+features/support$)
        command_line_config.run
      end

      it "should create env.rb directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+create\s+features/support/env.rb$)
        command_line_config.run
      end

    end

    context "files created" do
      around(:example) do |example|
        dir = Dir.mktmpdir
        FileUtils.mkdir_p "#{dir}/features"
        FileUtils.mkdir_p "#{dir}/features/step_definitions"
        FileUtils.mkdir_p "#{dir}/features/support"
        FileUtils.touch "#{dir}/features/support/env.rb"
        original_dir = Dir.pwd
        begin
          FileUtils.cd dir
          example.call
        ensure
          FileUtils.cd original_dir
          FileUtils.rm_rf dir
        end
      end

      it "should not create features directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+exist\s+features$)
        command_line_config.run
      end

      it "should not create step_definitions directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+exist\s+features/step_definitions$)
        command_line_config.run
      end

      it "should not create support directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+exist\s+features/support$)
        command_line_config.run
      end

      it "should not create env.rb directory" do
        expect(command_line_config).to receive(:puts).with %r(^\s+exist\s+features/support/env.rb$)
        command_line_config.run
      end

    end
  end
end