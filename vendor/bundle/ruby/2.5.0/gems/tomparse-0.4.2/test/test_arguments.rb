require_relative 'helper'

testcase "Arguments" do

  context "single line argument without heading" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # text - The String to be duplicated.
        #
        # Returns the duplicated String when the count is > 1.
      }
    end
    test "knows args size" do
      @comment.args.size.assert == 1
    end
    test "knows args name" do
      @comment.args.first.name.assert == :text
    end
    test "knows args description" do
      @comment.args.first.description.assert == "The String to be duplicated."
    end
    test "knows args optionality" do
      @comment.args.first.refute.optional?
    end
    test "know description" do
      @comment.description == "Duplicate some text an abitrary number of times."
    end
  end

  context "multi-line argument without heading" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # text - The String to be duplicated.
        #        And its description continues.
        #
        # Returns the duplicated String when the count is > 1.
      }
    end
    test "knows args size" do
      @comment.args.size.assert == 1
    end
    test "knows args name" do
      @comment.args.first.name.assert == :text
    end
    test "knows args description" do
      @comment.args.first.description.assert == "The String to be duplicated. And its description continues."
    end
    test "knows args optionality" do
      @comment.args.first.refute.optional?
    end
    test "know description" do
      @comment.description == "Duplicate some text an abitrary number of times."
    end
  end

  context "multiple arguments without heading" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # text - The String to be duplicated.
        #        And its description continues.
        # num  - The Number to be duplicated. 
        #        And it continues too. (optional)
        #
        # Returns the duplicated String when the count is > 1.
      }
    end
    test "knows args size" do
      @comment.args.size.assert == 2
    end
    test "knows args name" do
      @comment.args[0].name.assert == :text
      @comment.args[1].name.assert == :num
    end
    test "knows args description" do
      @comment.args[0].description.assert == "The String to be duplicated. And its description continues."
      @comment.args[1].description.assert == "The Number to be duplicated. And it continues too. (optional)"
    end
    test "knows args optionality" do
      @comment.args[0].refute.optional?
      @comment.args[1].assert.optional?
    end
    test "know description" do
      @comment.description == "Duplicate some text an abitrary number of times."
    end
  end

  context "single line argument with heading" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Arguments
        #   text - The String to be duplicated.
        #
        # Returns the duplicated String when the count is > 1.
      }
    end
    test "knows args size" do
      @comment.args.size.assert == 1
    end
    test "knows args name" do
      @comment.args.first.name.assert == :text
    end
    test "knows args description" do
      @comment.args.first.description.assert == "The String to be duplicated."
    end
    test "knows args optionality" do
      @comment.args.first.refute.optional?
    end
    test "know description" do
      @comment.description == "Duplicate some text an abitrary number of times."
    end
  end

  context "multi-line argument with heading" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Arguments
        #   text - The String to be duplicated.
        #          And its description continues.
        #
        # Returns the duplicated String when the count is > 1.
      }
    end
    test "knows args size" do
      @comment.args.size.assert == 1
    end
    test "knows args name" do
      @comment.args.first.name.assert == :text
    end
    test "knows args description" do
      @comment.args.first.description.assert == "The String to be duplicated. And its description continues."
    end
    test "knows args optionality" do
      @comment.args.first.refute.optional?
    end
    test "know description" do
      @comment.description == "Duplicate some text an abitrary number of times."
    end
  end

  context "multiple arguments without heading" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Arguments
        #   text - The String to be duplicated.
        #          And its description continues.
        #   num  - The Number to be duplicated. 
        #          And it continues too. (optional)
        #
        # Returns the duplicated String when the count is > 1.
      }
    end
    test "knows args size" do
      @comment.args.size.assert == 2
    end
    test "knows args name" do
      @comment.args[0].name.assert == :text
      @comment.args[1].name.assert == :num
    end
    test "knows args description" do
      @comment.args[0].description.assert == "The String to be duplicated. And its description continues."
      @comment.args[1].description.assert == "The Number to be duplicated. And it continues too. (optional)"
    end
    test "knows args optionality" do
      @comment.args[0].refute.optional?
      @comment.args[1].assert.optional?
    end
    test "know description" do
      @comment.description == "Duplicate some text an abitrary number of times."
    end
  end

  context "when description has visibility indicator" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Public: Duplicate some text an abitrary number of times.
        #
        # text - The String to be duplicated.
        #        And its description continues.
        # num  - The Number to be duplicated. 
        #        And it continues too.
        #
        # Returns the duplicated String when the count is > 1.
      }
    end
    test "knows args size" do
      @comment.args.size.assert == 2
    end
    test "knows args name" do
      @comment.args[0].name.assert == :text
      @comment.args[1].name.assert == :num
    end
    test "knows args description" do
      @comment.args[0].description.assert == "The String to be duplicated. And its description continues."
      @comment.args[1].description.assert == "The Number to be duplicated. And it continues too."
    end
    test "knows args optionality" do
      @comment.args[0].refute.optional?
      @comment.args[1].refute.optional?
    end
    test "know description" do
      @comment.description == "Duplicate some text an abitrary number of times."
    end
  end

end
