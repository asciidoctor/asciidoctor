require 'asciidoctor'
require 'asciidoctor/extensions'

class OpenBlock < Asciidoctor::Extensions::BlockProcessor
  enable_dsl

  named :openblock
  contexts :listing, :paragraph
  positional_attributes 'role'

  def process parent, reader, attributes
    # puts attributes
    result = create_open_block parent, nil, attributes
    attributes.delete 'role'
    attributes.delete 1
    parse_content result, reader.read_lines, attributes
  end
end

class OpenBlockGroup < Asciidoctor::Extensions::Group

  def activate registry
    registry.block OpenBlock
  end
end

# Here's the group implemented as a proc:
# openBlockGroup = proc do
#   block OpenBlock
# end

# Self registering
# For maximum flexibility put this in a different file.
Asciidoctor::Extensions.register openBlockGroup
