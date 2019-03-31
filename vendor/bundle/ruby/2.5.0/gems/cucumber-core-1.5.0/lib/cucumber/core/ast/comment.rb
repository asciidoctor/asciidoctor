require 'cucumber/core/ast/location'

module Cucumber
  module Core
    module Ast
      class Comment
        include HasLocation

        attr_reader :location, :value
        private :value

        def initialize(location, value)
          @location = location
          @value = value
        end

        def to_s
          value
        end

        def inspect
          %{#<#{self.class} #{value} (#{location})}
        end
      end
    end
  end
end
