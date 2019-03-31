require_relative 'helper'

testcase "Examples" do

  context "plural form one example" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Examples
        #   multiplex('Tom', 4)
        #   # => 'TomTomTomTom'
        #
        # Returns something or another.
      }
    end

    test "there is one examples" do
      @comment.examples.size.assert == 1
    end

    test "the example" do
      @comment.examples.first.assert == "multiplex('Tom', 4)\n# => 'TomTomTomTom'"
    end
  end

  context "plural form multiple examples" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Examples
        #   multiplex('Tom', 4)
        #   # => 'TomTomTomTom'
        #
        #   multiplex('Bo', 2)
        #   # => 'BoBo'
        #
        # Returns something or another.
      }
    end

    test "there are two examples" do
      @comment.examples.size.assert == 2
    end

    test "the first example" do
      @comment.examples.first.assert == "multiplex('Tom', 4)\n# => 'TomTomTomTom'"
    end

    test "the second example" do
      @comment.examples.last.assert == "multiplex('Bo', 2)\n# => 'BoBo'"
    end
  end

  context "singular form" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Example
        #   answer = multiplex('Tom', 4)
        #
        #   return answer
        #
        # Returns something or another.
      }
    end

    test "there is one example" do
      @comment.examples.size.assert == 1
    end

    test "the example" do
      @comment.examples.first.assert == "answer = multiplex('Tom', 4)\n\nreturn answer"
    end
  end

  context "multiple example clauses" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Examples
        #   multiplex('Tom', 4)
        #   # => 'TomTomTomTom'
        #
        #   multiplex('Bo', 2)
        #   # => 'BoBo'
        #
        # Example
        #   answer = multiplex('Tom', 4)
        #
        #   return answer
        #
        # Returns something or another.
      }
    end

    test "there are three examples" do
      @comment.examples.size.assert == 3
    end
  end

  context "handles whitespace in examples" do
    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Examples
        #
        #   def multiplex(str, length)
        #     str * length
        #   end
      }
    end

    test "correctly handles whitespace with examples" do
      eg = @comment.examples[0].to_s
      eg.assert == "def multiplex(str, length)\n  str * length\nend"
    end
  end

end
