require 'cucumber/file_specs'

module Cucumber
  describe FileSpecs do
    let(:file_specs) { FileSpecs.new(["features/foo.feature:1:2:3", "features/bar.feature:4:5:6"]) }
    let(:locations) { file_specs.locations }
    let(:files) { file_specs.files }

    it "parses locations from multiple files" do
      expect(locations.length).to eq 6
      expect(locations).to eq [
        Cucumber::Core::Ast::Location.new("features/foo.feature", 1),
        Cucumber::Core::Ast::Location.new("features/foo.feature", 2),
        Cucumber::Core::Ast::Location.new("features/foo.feature", 3),
        Cucumber::Core::Ast::Location.new("features/bar.feature", 4),
        Cucumber::Core::Ast::Location.new("features/bar.feature", 5),
        Cucumber::Core::Ast::Location.new("features/bar.feature", 6),
      ]
    end

    it "parses file names from multiple file specs" do
      expect(files.length).to eq 2
      expect(files).to eq [
        "features/foo.feature",
        "features/bar.feature",
      ]
    end

    context "when files are not unique" do
      let(:file_specs) { FileSpecs.new(["features/foo.feature:4", "features/foo.feature:34"]) }

      it "parses unique file names" do
        expect(files.length).to eq 1
        expect(files).to eq ["features/foo.feature"]
      end
    end

    context "when no line number is specified" do
      let(:file_specs) { FileSpecs.new(["features/foo.feature", "features/bar.feature:34"]) }

      it "returns a wildcard location for that file" do
        expect(locations).to eq [
          Cucumber::Core::Ast::Location.new("features/foo.feature"),
          Cucumber::Core::Ast::Location.new("features/bar.feature", 34),
        ]
      end
    end

    context "when the same file is referenced more than once" do
      let(:file_specs) { FileSpecs.new(["features/foo.feature:10", "features/foo.feature:1"]) }

      it "returns locations in the order specified" do
        expect(locations).to eq [
          Cucumber::Core::Ast::Location.new("features/foo.feature", 10),
          Cucumber::Core::Ast::Location.new("features/foo.feature", 1),
        ]
      end
    end
  end
end
