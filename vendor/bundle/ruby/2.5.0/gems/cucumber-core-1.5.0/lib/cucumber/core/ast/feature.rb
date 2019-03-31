require 'cucumber/core/ast/describes_itself'
require 'cucumber/core/ast/names'
require 'cucumber/core/ast/location'
require 'gherkin/dialect'

module Cucumber
  module Core
    module Ast
      # Represents the root node of a parsed feature.
      class Feature
        include Names
        include HasLocation
        include DescribesItself

        attr_reader :language, :location, :background,
                    :comments, :tags, :keyword, :description,
                    :feature_elements

        def initialize(language, location, comments, tags, keyword, name, description, feature_elements)
          @language = language
          @location = location
          @background = BackgroundFinder.new(feature_elements).result
          @comments = comments
          @tags = tags
          @keyword = keyword
          @name = name
          @description = description
          @feature_elements = feature_elements
        end

        def children
          @feature_elements
        end

        def short_name
          first_line = name.split(/\n/)[0]
          if first_line =~ /#{language.feature_keywords}:(.*)/
            $1.strip
          else
            first_line
          end
        end

        def to_sexp
          sexp = [:feature, file, name]
          comment = @comment.to_sexp
          sexp += [comment] if comment
          tags = @tags.to_sexp
          sexp += tags if tags.any?
          sexp += @feature_elements.map{|fe| fe.to_sexp}
          sexp
        end

        private

        def description_for_visitors
          :feature
        end

      end

      class NullFeature
        def method_missing(*args, &block)
          self
        end
      end

      class BackgroundFinder
        def initialize(feature_elements)
          @background = nil
          feature_elements[0].describe_to(self) unless feature_elements.empty?
        end

        def background(background)
          @background = background
        end

        def result
          @background ? @background : EmptyBackground.new
        end

        def method_missing(*)
        end
      end

      require 'delegate'
      class LanguageDelegator < SimpleDelegator
        attr_reader :iso_code

        def initialize(iso_code, obj)
          super(obj)
          @iso_code = iso_code
        end
      end
    end
  end
end
