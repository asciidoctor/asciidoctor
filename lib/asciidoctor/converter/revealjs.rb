module Asciidoctor

  class Converter::RevealjsConverter < Converter::Base
    def convert node, template_name = nil, opts = {}
      Slide.render(node)
    end
  end
end