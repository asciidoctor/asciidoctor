require 'cucumber'
require 'cucumber/filters/retry'
require 'cucumber/core/gherkin/writer'
require 'cucumber/configuration'
require 'cucumber/core/test/case'
require 'cucumber/core'
require 'cucumber/events'

describe Cucumber::Filters::Retry do
  include Cucumber::Core::Gherkin::Writer
  include Cucumber::Core
  include Cucumber::Events

  let(:configuration) { Cucumber::Configuration.new(:retry => 2) }
  let(:test_case) { Cucumber::Core::Test::Case.new([double('test steps')], double('source').as_null_object) }
  let(:receiver) { double('receiver').as_null_object }
  let(:filter) { Cucumber::Filters::Retry.new(configuration, receiver) }
  let(:fail) { Cucumber::Events::AfterTestCase.new(test_case, double('result', :failed? => true, :ok? => false)) }
  let(:pass) { Cucumber::Events::AfterTestCase.new(test_case, double('result', :failed? => false, :ok? => true)) }

  it { is_expected.to respond_to(:test_case) }
  it { is_expected.to respond_to(:with_receiver) }
  it { is_expected.to respond_to(:done) }

  context "general" do
    before(:each) do
      filter.with_receiver(receiver)
    end

    it "registers the :after_test_case event" do
      expect(configuration).to receive(:on_event).with(:after_test_case)
      filter.test_case(test_case)
    end
  end

  context "passing test case" do
    it "describes the test case once" do
      expect(test_case).to receive(:describe_to).with(receiver)
      filter.test_case(test_case)
      configuration.notify(pass)
    end
  end

  context "failing test case" do
    it "describes the test case the specified number of times" do
      expect(receiver).to receive(:test_case) {|test_case|
        configuration.notify(fail)
      }.exactly(3).times

      filter.test_case(test_case)
    end
  end

  context "flaky test cases" do

    context "a little flaky" do
      it "describes the test case twice" do
        results = [fail, pass]
        expect(receiver).to receive(:test_case) {|test_case|
          configuration.notify(results.shift)
        }.exactly(2).times

        filter.test_case(test_case)
      end
    end

    context "really flaky" do
      it "describes the test case 3 times" do
        results = [fail, fail, pass]

        expect(receiver).to receive(:test_case) {|test_case|
          configuration.notify(results.shift)
        }.exactly(3).times

        filter.test_case(test_case)
      end
    end
  end
end
