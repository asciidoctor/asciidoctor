require 'asciidoctor'
require 'asciidoctor/extensions'

# Self registering
Asciidoctor::Extensions.register do
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

  block OpenBlock
end
