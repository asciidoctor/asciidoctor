require_relative 'helper'

testcase "Description" do

  context "description only" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Has this initial paragraph.
      }
    end

    test "correctly handles description only" do
      @comment.description.assert == "Has this initial paragraph."
    end
  end

  context "simple description with other things" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Has this initial paragraph, that continues on to
        # a new line.
        #
        # Examples
        #
        #   foo('bar')
      }
    end

    test "correctly handles description" do
      @comment.description.assert == "Has this initial paragraph, that continues on to\na new line."
    end
  end

  context "handles multiple paragraph descriptions" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Has an initial paragraph.
        #
        # Has another paragraph in the description.
        #
        # Examples
        #
        #   def multiplex(str, length)
        #     str * length
        #   end
      }
    end

    test "correctly handles multiple paragraphs" do
      @comment.description.assert == "Has an initial paragraph.\n\nHas another paragraph in the description."
    end
  end

end
