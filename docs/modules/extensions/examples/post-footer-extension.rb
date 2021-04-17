require 'asciidoctor'
require 'asciidoctor/extensions'

class CopyrightFooterPostprocessor < Asciidoctor::Extensions::Postprocessor

  def initialize copyright
    super()
    @copyright = copyright
  end

  enable_dsl

  def process document, output
    content = (document.attr 'copyright') || @copyright
    if document.basebackend? 'html'
      replacement = %(<div id="footer-text">\\1<br>\n#{content}\n</div>)
      output = output.sub(/<div id="footer-text">(.*?)<\/div>/m, replacement)
    elsif document.basebackend? 'docbook'
      replacement = %(<simpara>#{content}</simpara>\n\\1)
      output = output.sub(/(<\/(?:article|book)>)/, replacement)
    end
    output
  end
end

# self-registering
Asciidoctor::Extensions.register do
  postprocessor CopyrightFooterPostprocessor.new('Copyright Acme, Inc.')
end
