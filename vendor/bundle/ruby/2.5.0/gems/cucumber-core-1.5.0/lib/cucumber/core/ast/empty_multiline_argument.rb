module Cucumber
  module Core
    module Ast
      class EmptyMultilineArgument
        def describe_to(*)
          self
        end

        def data_table?
          false
        end

        def doc_string?
          false
        end

        def map(&block)
          self
        end

        def all_locations
          []
        end

        def to_sexp
          []
        end

        def inspect
          "#<#{self.class}>"
        end
      end
    end
  end
end

