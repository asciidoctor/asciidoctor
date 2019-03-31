require_relative 'helper'

testcase "Tags" do

  context "TODO" do

    setup do
      @tomdoc = TomParse::TomDoc.new(<<-END)
        # This is an example of tags.
        #
        # TODO: Something we have to do.
      END
    end

    test "tags has todo" do
      @tomdoc.tags.size.assert == 1
      @tomdoc.tags.assert.include? ['TODO', 'Something we have to do.']
    end

  end

  context "FOO" do

    setup do
      @tomdoc = TomParse::TomDoc.new(<<-END)
        # This is an example of tags.
        #
        # Foo: They can be anything really.
      END
    end

    test "tags has foo" do
      @tomdoc.tags.size.assert == 1
      @tomdoc.tags.assert.include? ['Foo', 'They can be anything really.']
    end

  end


end
