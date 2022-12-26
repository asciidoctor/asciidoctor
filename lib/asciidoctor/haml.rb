# frozen_string_literal: true

require 'haml'

module Asciidoctor
  module Haml
    if ::Haml::VERSION >= '6'
      QUOTE_ATTR = :attr_quote
      Template = ::Haml::Template
    else
      QUOTE_ATTR = :attr_wrapper
      Template = ::Tilt::Template
    end
  end
end
