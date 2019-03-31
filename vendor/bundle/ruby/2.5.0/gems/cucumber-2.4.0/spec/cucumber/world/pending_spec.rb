require 'spec_helper'
require 'cucumber/rb_support/rb_language'
require 'cucumber/configuration'

module Cucumber
  describe 'Pending' do
    before(:each) do
      l = RbSupport::RbLanguage.new(Runtime.new, Configuration.new)
      l.begin_rb_scenario(double('scenario').as_null_object)
      @world = l.current_world
    end

    it 'raises a Pending if no block is supplied' do
      expect(-> {
        @world.pending "TODO"
      }).to raise_error(Cucumber::Pending, /TODO/)
    end

    it 'raises a Pending if a supplied block fails as expected' do
      expect(-> {
        @world.pending "TODO" do
        raise "oops"
        end
      }).to raise_error(Cucumber::Pending, /TODO/)
    end

    it 'raises a Pending if a supplied block fails as expected with a double' do
      expect do
        @world.pending "TODO" do
          m = double('thing')
          expect(m).to receive(:foo)
          RSpec::Mocks.verify
        end
      end.to raise_error(Cucumber::Pending, /TODO/)
      # The teardown is needed so that the message expectation does not bubble up.
      RSpec::Mocks.teardown 
    end

    it 'raises a Pending if a supplied block starts working' do
      expect(-> {
        @world.pending "TODO" do
        # success!
        end
      }).to raise_error(Cucumber::Pending, /TODO/)
    end
  end
end
