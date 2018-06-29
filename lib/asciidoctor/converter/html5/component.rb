module Asciidoctor
  module Converter
    module Html5
      class Component
        def initialize(node, void_element_slash)
          @node = node
          @void_element_slash = void_element_slash
        end

        protected

        def void_element_slash
          @void_element_slash
        end

        def node
          @node
        end
      end
    end
  end
end
