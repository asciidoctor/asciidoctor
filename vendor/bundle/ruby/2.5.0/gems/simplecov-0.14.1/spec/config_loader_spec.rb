require "helper"

describe "loading config" do
  context "without ENV[HOME]" do
    it "shouldn't raise any errors" do
      home = ENV.delete("HOME")
      begin
        expect { load "simplecov/load_global_config.rb" }.not_to raise_error
      ensure
        ENV["HOME"] = home
      end
    end
  end
end
