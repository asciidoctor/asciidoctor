require 'cucumber/gherkin/i18n'

module Cucumber
  module Formatter
    module LegacyApi

      # This is what's passed to the constructor of the formatters
      class RuntimeFacade < Struct.new(:results, :support_code, :configuration)
        def unmatched_step_definitions
          support_code.unmatched_step_definitions
        end

        def snippet_text(step_keyword, step_name, multiline_arg) #:nodoc:
          keyword = Cucumber::Gherkin::I18n.code_keyword_for(step_keyword).strip
          configuration.snippet_generators.map { |generator|
            generator.call(keyword, step_name, multiline_arg, configuration.snippet_type)
          }.join("\n")
        end

        def scenarios(status = nil)
          results.scenarios(status)
        end

        def steps(status = nil)
          results.steps(status)
        end
      end

    end
  end
end
