require 'asciidoctor'
require 'asciidoctor/extensions'

class Nestable < Asciidoctor::Extensions::BlockProcessor
  enable_dsl

  named :nestable
  contexts :example, :paragraph

  def process parent, reader, attributes
    create_open_block parent, reader.read_lines, attributes
  end
end

class NestableGroup < Asciidoctor::Extensions::Group

  def activate registry
    registry.block Nestable
  end
end

# Here's the group implemented as a proc:
# nestableGroup = proc do
#   block Nestable
# end

# Self registering
# For maximum flexibility put this in a different file.
Asciidoctor::Extensions.register NestableGroup
