require_relative 'helper'

testcase "Yields" do

  setup do  
    @comment = TomParse::TomDoc.new %{
      # Duplicate some text an abitrary number of times.
      #
      # Yields the Integer index of the iteration.
    }
  end

  test "knows what the method yields" do
    @comment.yields.assert == "Yields the Integer index of the iteration."
  end

end
