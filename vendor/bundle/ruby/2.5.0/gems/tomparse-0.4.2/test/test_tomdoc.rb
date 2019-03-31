require_relative 'helper'

testcase TomParse::TomDoc do

  context "general parsing" do

    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # text    - The String to be duplicated.
        # count   - The Integer number of times to
        #           duplicate the text.
        # reverse - An optional Boolean indicating
        #           whether to reverse the result text or not.
        # options - Options (default: {})
        #           :insert_spaces - Whether to insert spaces
        #           :upcase - Convert the string to upper case
        # blk - The block.
        #
        # Examples
        #   multiplex('Tom', 4)
        #   # => 'TomTomTomTom'
        #
        #   multiplex('Bo', 2)
        #   # => 'BoBo'
        #
        #   multiplex('Chris', -1)
        #   # => nil
        #
        # Returns the duplicated String when the count is > 1.
        # Returns the atomic mass of the element as a Float. The value is in
        #   unified atomic mass units.
        # Returns nil when the count is < 1.
        # Raises ExpectedString if the first argument is not a String.
        # Raises ExpectedInteger if the second argument is not an Integer.
      }
    end

    test "parses a description" do
      @comment.description.assert == "Duplicate some text an abitrary number of times."
    end

    test "parses args" do
      @comment.args.size.assert == 5
    end

    test "know a hash arg's options" do
      @comment.args[3].options.size.assert == 2
      @comment.args[3].options.first.name.assert == :':insert_spaces'
      @comment.args[3].options[1].name.assert == :':upcase'
      @comment.args[3].options.first.description.assert == 'Whether to insert spaces'
      @comment.args[3].options[1].description.assert == 'Convert the string to upper case'
    end

    test "knows an arg's name" do
      @comment.args.first.name.assert == :text
      @comment.args[1].name.assert == :count
      @comment.args[2].name.assert == :reverse
      @comment.args[3].name.assert == :options
    end

    test "knows an arg's description" do
      @comment.args[1].description.assert == 'The Integer number of times to duplicate the text.'

      reverse = 'An optional Boolean indicating whether to reverse the'
      reverse << ' result text or not.'
      @comment.args[2].description.assert == reverse
    end

    test "knows an arg's optionality" do
      refute @comment.args.first.optional?
      assert @comment.args[2].optional?
    end

    test "knows how many examples there are" do
      @comment.examples.size.assert == 3
    end

    test "knows each example" do
      @comment.examples[1].to_s.assert == "multiplex('Bo', 2)\n# => 'BoBo'"
    end

    test "knows how many return examples there are" do
      @comment.returns.size.assert == 3
    end

    test "knows if the method raises anything" do
      @comment.raises.size.assert == 2
    end

    test "knows each return example" do
      rtn = @comment.returns.first.to_s
      rtn.assert == "Returns the duplicated String when the count is > 1."

      string = ''
      string << "Returns the atomic mass of the element as a Float. "
      string << "The value is in unified atomic mass units."
      @comment.returns[1].to_s.assert == string

      @comment.returns[2].to_s.assert == "Returns nil when the count is < 1."
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

  context "without arguments or examples" do

    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Returns the duplicated String.
      }
    end

    test "knows what to do when there are no args" do
      @comment.args.size.assert == 0
    end

    test "knows what to do when there are no examples" do
      @comment.examples.size.assert == 0
    end

    test "knows what to do when there are no return examples" do
      @comment.examples.size.assert == 0
    end

  end


  context "invalid documentation" do

    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Examples
        #
        #   multiplex('Tom', 4)
        #   # => 'TomTomTomTom'
        #
        #   multiplex('Bo', 2)
        #   # => 'BoBo'
      }
    end

    test "knows when TomDoc is invalid" do
      expect TomParse::ParseError do
        @comment.validate
      end
    end

  end


  context "without comment marker" do

    setup do
      @comment = TomParse::TomDoc.new %{
        Duplicate some text an abitrary number of times.
  
        Yields the Integer index of the iteration.
        
        Signature
        
          find_by_<field>[_and_<field>...](args)
        
        field - A field name.
      }
    end

    test "can handle comments without comment marker" do
      @comment.description.assert == "Duplicate some text an abitrary number of times."
    end

  end

end
