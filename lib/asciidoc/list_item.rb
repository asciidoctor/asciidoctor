# Public: Methods for managing items for Asciidoc olists, ulist, and dlists.
class Asciidoc::ListItem
  # Public: Get the Array of Blocks from the list item's continuation.
  attr_reader :blocks

  # Public: Get/Set the String content.
  attr_accessor :content

  # Public: Get/Set the String list item anchor name.
  attr_accessor :anchor

  # Public: Initialize an Asciidoc::ListItem object.
  #
  # content - the String content (default '')
  def initialize(content='')
    @content = content
    @blocks  = []
  end
end
