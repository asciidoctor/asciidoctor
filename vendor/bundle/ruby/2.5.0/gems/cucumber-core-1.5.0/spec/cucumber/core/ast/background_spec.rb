require 'cucumber/core/ast/background'
module Cucumber::Core::Ast
  describe Background do
    it "has a useful inspect" do
      location = Location.new("features/a_feature.feature", 3)
      background = Background.new(location, double, "Background", "the name", double, [])
      expect(background.inspect).to eq(%{#<Cucumber::Core::Ast::Background "Background: the name" (#{location})>})
    end
  end
end
