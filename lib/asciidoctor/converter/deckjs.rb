module Asciidoctor

  class Converter::DeckjsConverter < Converter::Base
    def convert node, template_name = nil, opts = {}
      Slide.render(node)
    end
  end
end