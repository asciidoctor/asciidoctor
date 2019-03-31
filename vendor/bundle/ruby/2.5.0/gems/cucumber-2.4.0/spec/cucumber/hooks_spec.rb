require 'cucumber/hooks'
module Cucumber::Hooks
  shared_examples_for 'a source node' do
    it "responds to name" do
      expect( subject.name ).to be_a(String)
    end

    it "responds to location" do
      expect( subject.location ).to eq(location)
    end

    it "responds to match_locations?" do
      expect( subject.match_locations? [location] ).to be_truthy
      expect( subject.match_locations? [] ).to be_falsey
    end
  end

  require 'cucumber/core/ast/location'
  describe BeforeHook do
    subject { BeforeHook.new(location) }
    let(:location) { Cucumber::Core::Ast::Location.new('hooks.rb', 1) }
    it_behaves_like 'a source node'
  end

  describe AfterHook do
    subject { AfterHook.new(location) }
    let(:location) { Cucumber::Core::Ast::Location.new('hooks.rb', 1) }
    it_behaves_like 'a source node'
  end
end
