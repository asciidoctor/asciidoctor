require 'asciidoctor'
require 'asciidoctor/extensions'

class Nestable < Asciidoctor::Extensions::BlockProcessor

  def initialize default_role
    super
    @default_role = default_role
  end

  enable_dsl

  contexts :example, :paragraph

  def process parent, reader, attributes
    attributes['role'] = (role = attributes['role']) ? %(#{@default_role} #{role}) : default_role
    create_open_block parent, reader.read_lines, attributes
  end
end

class NestableGroup < Asciidoctor::Extensions::Group
  def initialize *default_role
    @default_roles = *default_role
  end

  def activate registry
    @default_roles.each do |default_role|
      registry.block (Nestable.new default_role), %(#{default_role}block).to_sym
    end
  end
end

# Self registering
# For maximum flexibility put this in a different file.
Asciidoctor::Extensions.register NestableGroup.new 'bar', 'baz'
