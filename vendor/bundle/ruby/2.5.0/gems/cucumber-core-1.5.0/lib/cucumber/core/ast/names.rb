module Cucumber
  module Core
    module Ast
      module Names
        attr_reader :description, :name

        def legacy_conflated_name_and_description
          s = name
          s += "\n#{@description}" if @description != ""
          s
        end

        def to_s
          name
        end

        def inspect
          keyword_and_name = [keyword, name].join(": ")
          %{#<#{self.class} "#{keyword_and_name}" (#{location})>}
        end
      end
    end
  end
end
