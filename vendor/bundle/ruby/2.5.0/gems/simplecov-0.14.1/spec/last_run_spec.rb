require "helper"

if SimpleCov.usable?
  describe SimpleCov::LastRun do
    subject { SimpleCov::LastRun }

    it "defines a last_run_path" do
      expect(subject.last_run_path).to include "tmp/coverage/.last_run.json"
    end

    it "writes json to its last_run_path that can be parsed again" do
      structure = [{"key" => "value"}]
      subject.write(structure)
      file_contents = File.read(subject.last_run_path)
      expect(JSON.parse(file_contents)).to eq structure
    end

    context "reading" do
      context "but the last_run file does not exist" do
        before { File.delete(subject.last_run_path) if File.exist?(subject.last_run_path) }

        it "returns nil" do
          expect(subject.read).to be_nil
        end
      end

      context "a non empty result" do
        before { subject.write([]) }

        it "reads json from its last_run_path" do
          expect(subject.read).to eq([])
        end
      end

      context "an empty result" do
        before do
          File.open(subject.last_run_path, "w+") do |f|
            f.puts ""
          end
        end

        it "returns nil" do
          expect(subject.read).to be_nil
        end
      end
    end
  end
end
