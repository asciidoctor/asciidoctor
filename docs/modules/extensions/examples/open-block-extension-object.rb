require 'asciidoctor'
require 'asciidoctor/extensions'

class OpenBlock < Asciidoctor::Extensions::BlockProcessor

  def initialize default_role
    super
    @default_role = default_role
  end

  enable_dsl

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

class OpenBlockGroup < Asciidoctor::Extensions::Group
  def initialize *default_role
    @default_roles = *default_role
  end

  def activate registry
    @default_roles.each do |default_role|
      registry.block (OpenBlock.new default_role), %(#{default_role}block).to_sym
    end
  end
end

# Self registering
# For maximum flexibility put this in a different file.
Asciidoctor::Extensions.register OpenBlockGroup.new 'bar', 'baz'
