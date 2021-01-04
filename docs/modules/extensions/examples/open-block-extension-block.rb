require 'asciidoctor'
require 'asciidoctor/extensions'

openBlockGroup = proc do
  block do
    named :openblock
    contexts :listing, :paragraph
    positional_attributes 'role'

    process do |parent, reader, attributes|
      result = create_open_block parent, nil, attributes
      attributes.delete 'role'
      attributes.delete 1
      parse_content result, reader.read_lines, attributes
    end
  end
end

# Self registering code
# For maximum flexibility put this in a different file.
Asciidoctor::Extensions.register openBlockGroup