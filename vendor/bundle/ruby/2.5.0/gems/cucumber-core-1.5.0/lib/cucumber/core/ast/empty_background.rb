module Cucumber
  module Core
    module Ast
      class EmptyBackground
        def describe_to(*)
          self
        end

        def inspect
          "#<#{self.class.name}>"
        end
      end
    end
  end
end

