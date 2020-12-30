require 'asciidoctor'
require 'asciidoctor/extensions'

# Self registering
Asciidoctor::Extensions.register do
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
# Asciidoctor::Extensions.register do
#   block do
#     named :wrap
#     on_context :open
#     process do |parent, reader, attrs|
#       wrap = create_open_block parent, nil, attrs
#       parse_content wrap, reader.read_lines
#     end
#   end
# end
