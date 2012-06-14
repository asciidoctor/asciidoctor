# Public: Methods for managing items for Asciidoc olists, ulist, and dlists.
class Asciidoctor::ListItem
  # Public: Get the Array of Blocks from the list item's continuation.
  attr_reader :blocks

  # Public: Get/Set the String content.
  attr_accessor :content

  # Public: Get/Set the String list item anchor name.
  attr_accessor :anchor

  # Public: Initialize an Asciidoctor::ListItem object.
  #
  # content - the String content (default '')
  def initialize(content='')
    @content = content
    @blocks  = []
  end
end
