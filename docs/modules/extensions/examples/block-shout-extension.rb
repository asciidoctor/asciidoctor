require 'asciidoctor'
require 'asciidoctor/extensions'

class ShoutBlock < Asciidoctor::Extensions::BlockProcessor
  PeriodRx = /\.(?= |$)/

  enable_dsl

  named :shout
  contexts :paragraph
  positional_attributes 'vol'
  content_model :simple

  def process parent, reader, attrs
    volume = ((attrs.delete 'vol') || 1).to_i
    create_paragraph parent, (reader.lines.map {|l| l.upcase.gsub PeriodRx, '!' * volume }), attrs
  end
end

# self-registering
Asciidoctor::Extensions.register do
  block ShoutBlock
end
