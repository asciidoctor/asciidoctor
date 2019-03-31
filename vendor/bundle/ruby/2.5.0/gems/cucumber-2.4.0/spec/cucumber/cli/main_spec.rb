require 'spec_helper'
require 'yaml'

module Cucumber
  module Cli
    describe Main do
      before(:each) do
        allow(File).to receive(:exist?) { false } # When Configuration checks for cucumber.yml
        allow(Dir).to receive(:[]) { [] } # to prevent cucumber's features dir to being laoded
      end

      let(:args)   { [] }
      let(:stdin)  { StringIO.new }
      let(:stdout) { StringIO.new }
      let(:stderr) { StringIO.new }
      let(:kernel) { double(:kernel) }
      subject { Main.new(args, stdin, stdout, stderr, kernel)}

      describe "#execute!" do
        context "passed an existing runtime" do
          let(:existing_runtime) { double('runtime').as_null_object }

          def do_execute
            subject.execute!(existing_runtime)
          end

          it "configures that runtime" do
            expected_configuration = double('Configuration').as_null_object

            allow(Configuration).to receive(:new) { expected_configuration }
            expect(existing_runtime).to receive(:configure).with(expected_configuration)
            expect(kernel).to receive(:exit).with(1)

            do_execute
          end

          it "uses that runtime for running and reporting results" do
            expected_results = double('results', :failure? => true)

            expect(existing_runtime).to receive(:run!)
            allow(existing_runtime).to receive(:results) { expected_results }
            expect(kernel).to receive(:exit).with(1)

            do_execute
          end
        end

        context "interrupted with ctrl-c" do
          after do
            Cucumber.wants_to_quit = false
          end

          it "exits with error code" do
            results = double('results', :failure? => false)

            allow_any_instance_of(Runtime).to receive(:run!)
            allow_any_instance_of(Runtime).to receive(:results) { results }

            Cucumber.wants_to_quit = true

            expect(kernel).to receive(:exit).with(2)

            subject.execute!
          end
        end
      end

      [ProfilesNotDefinedError, YmlLoadError, ProfileNotFound].each do |exception_klass|
        it "rescues #{exception_klass}, prints the message to the error stream" do
          configuration = double('configuration')

          allow(Configuration).to receive(:new) { configuration }
          allow(configuration).to receive(:parse!).and_raise(exception_klass.new("error message"))
          allow(kernel).to receive(:exit).with(2)

          subject.execute!

          expect(stderr.string).to eq "error message\n"
        end
      end
    end
  end
end
