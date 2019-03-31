
module Cucumber
  module Core
    module Gherkin
      class Document
        attr_reader :uri, :body

        def initialize(uri, body)
          @uri = uri
          @body = body
        end

        def to_s
          body
        end

        def ==(other)
          to_s == other.to_s
        end
      end
    end
  end
end
