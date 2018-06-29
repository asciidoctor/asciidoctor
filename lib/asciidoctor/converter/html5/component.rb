module Asciidoctor
  module Converter
    module Html5
      class Component
        def initialize(node, void_element_slash)
          @node = node
          @void_element_slash = void_element_slash
        end

        def to_html
          @output = []
          render
          @output
        end

        protected

        def render
          raise "#{__method__} is not implemented by #{self.class}"
        end

        def output(line)
          @output << line if line
        end

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
