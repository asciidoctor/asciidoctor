require 'asciidoctor'
require 'asciidoctor/extensions'
require 'open-uri'

class UriIncludeProcessor < Asciidoctor::Extensions::IncludeProcessor
  def handles? target
    (target.start_with? 'http://') or (target.start_with? 'https://')
  end

  def process doc, reader, target, attributes
    content = (open target).readlines
    reader.push_include content, target, target, 1, attributes
    reader
  end
end

# Self-registering
Asciidoctor::Extensions.register do
  include_processor UriIncludeProcessor
end