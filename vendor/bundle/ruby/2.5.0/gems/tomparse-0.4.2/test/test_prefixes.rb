require_relative 'helper'

testcase "Prefixes" do

  context "Internal" do

    setup do
      @tomdoc = TomParse::TomDoc.new(<<-END)
        # Internal: Some example text.
      END
    end

    test "internal?" do
      @tomdoc.assert.internal?
    end

    test "description" do
      @tomdoc.description.assert == "Some example text."
    end

  end

  context "Public" do

    setup do
      @tomdoc = TomParse::TomDoc.new(<<-END)
        # Public: Some example text.
      END
    end

    test "public?" do
      @tomdoc.assert.public?
    end

    test "description" do
      @tomdoc.description.assert == "Some example text."
    end

  end


end
