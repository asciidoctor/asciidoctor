require 'asciidoctor'
require 'asciidoctor/extensions'

nestableGroup = proc do
  block do
    named :nestable
    contexts :example, :paragraph

    process do |parent, reader, attributes|
      create_open_block parent, reader.read_lines, attributes
    end
  end
end

# Self registering code
# For maximum flexibility put this in a different file.
Asciidoctor::Extensions.register nestableGroup