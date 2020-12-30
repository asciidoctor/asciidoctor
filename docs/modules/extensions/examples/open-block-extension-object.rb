require 'asciidoctor'
require 'asciidoctor/extensions'

class OpenBlock < Asciidoctor::Extensions::BlockProcessor

  def initialize default_role
    super
    @default_role = default_role
  end

  enable_dsl

  named :openblock
  contexts :listing, :paragraph
  positional_attributes 'role'

  def process parent, reader, attributes
    attributes['role'] = (role = attributes['role']) ? %(#{@default_role} #{role}) : default_role
    result = create_open_block parent, nil, attributes
    attributes.delete 'role'
    attributes.delete 1
    parse_content result, reader.read_lines, attributes
  end
end

# Self registering
# bar_block = OpenBlock.new 'bar'
Asciidoctor::Extensions.register do
  block OpenBlock.new('bar'), :barblock
  block OpenBlock.new('baz'), :bazblock
end
