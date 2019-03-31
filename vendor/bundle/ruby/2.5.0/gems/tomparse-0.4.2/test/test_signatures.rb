require_relative 'helper'

testcase "Signatures" do

  context "singular term" do

    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Signature
        #
        #   find(name)
        #   find(name=>pattern)
        #
      }
    end

    test "knows if the method has alternate signatures" do
      @comment.signatures.size.assert == 2
      @comment.signatures.first.assert == "find(name)"
      @comment.signatures.last.assert == "find(name=>pattern)"
    end

  end

  context "plural term" do

    setup do
      @comment = TomParse::TomDoc.new %{
        # Duplicate some text an abitrary number of times.
        #
        # Signatures
        #
        #   find_by_<field>[_and_<field>...](args)
        #
      }
    end

    test "knows if the method has alternate signatures" do
      @comment.signatures.size.assert == 1
      @comment.signatures.first.assert == "find_by_<field>[_and_<field>...](args)"
    end

  end

  #test "knows the fields associated with signatures" do
  #  @comment.signature_fields.size.assert == 1
  #
  #  arg = @comment.signature_fields.first
  #  arg.name.assert == :field
  #  arg.description.assert == "A field name."
  #end

end
