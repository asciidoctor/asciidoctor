require 'cucumber/core/ast/names'
require 'cucumber/core/ast/location'
require 'cucumber/core/ast/describes_itself'

module Cucumber
  module Core
    module Ast
      class Background
        include Names
        include HasLocation
        include DescribesItself

        def initialize(location, comments, keyword, name, description, raw_steps)
          @location = location
          @comments = comments
          @keyword = keyword
          @name = name
          @description = description
          @raw_steps = raw_steps
        end

        attr_reader :description, :raw_steps
        private     :raw_steps

        attr_reader :comments, :keyword, :location

        def children
          raw_steps
        end

        private

        def description_for_visitors
          :background
        end

      end
    end
  end
end
