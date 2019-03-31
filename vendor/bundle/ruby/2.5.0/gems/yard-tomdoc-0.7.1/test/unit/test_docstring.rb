require 'helper.rb'

require "yard"
require "yard-tomdoc"

describe YARD::Docstring do

  make_docstring = Proc.new do |comment|
    if YARD::VERSION == '0.8.0'
      YARD::DocstringParser.new.parse(comment, self).to_docstring
    else
      YARD::Docstring.new(comment)
    end
  end

  before do
    comment = <<-eof
# Duplicate some text an arbitrary number of times.
# 
# text  - The String to be duplicated.
# count - The Integer number of times to duplicate the text.
# options - Options (default: {})
#         :a - Option a
#         :b - Option b
# 
# Examples
#   multiplex('Tom', 4)
#   # => 'TomTomTomTom'
#
# Returns the duplicated String.
#
# Raises ArgumentError if something bad happened
eof

    @docstring = make_docstring[comment]
  end

  it "should fill docstring with description" do
    @docstring.assert == "Duplicate some text an arbitrary number of times."
  end

  it "should fill param tags" do
    tags = @docstring.tags(:param)
    tags.size.assert == 3
    tags[0].name.assert == 'text'
    tags[1].name.assert == 'count'
    tags[2].name.assert == 'options'
  end

  it "should fill options tags" do
    tags = @docstring.tags(:option)
    tags.size.assert == 2
    tags[0].name.assert == 'options'
    tags[0].pair.name.assert == ':a'
    tags[0].pair.text.assert == 'Option a'
    tags[1].name.assert == 'options'
    tags[1].pair.name.assert == ':b'
    tags[1].pair.text.assert == 'Option b'
  end

  it "should fill examples tags" do
    @docstring.tags(:example).size.assert == 1
    @docstring.tag(:example).text.assert == "multiplex('Tom', 4)\n# => 'TomTomTomTom'"
  end
  
  it "should fill return tag" do
    @docstring.tag(:return).text.assert == "the duplicated String."
  end

  it "should fill raise tag" do
    @docstring.tag(:raise).text.assert == "ArgumentError if something bad happened"
  end

  describe "Internal description" do

    it "should fill api private tag" do
      docstring = make_docstring["# Internal: It will do a big things in future"]
      docstring.tag(:api).text.assert == "private"
    end

  end

  describe "Deprecated description" do

    it "should fill deprecated tag" do
      docstring = make_docstring["# Deprecated: Some description."]
      docstring.tag(:deprecated).text.assert == "Do not use this in new code, and replace it when updating old code."
    end

  end

end

