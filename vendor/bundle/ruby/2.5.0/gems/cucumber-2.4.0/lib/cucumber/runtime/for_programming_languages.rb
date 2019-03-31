require 'forwardable'
require 'cucumber/core/ast/doc_string'
require 'cucumber/core/ast/data_table'

module Cucumber
  class Runtime
    # This is what a programming language will consider to be a runtime.
    #
    # It's a thin class that directs the handul of methods needed by the
    # programming languages to the right place.
    class ForProgrammingLanguages
      extend Forwardable

      attr_reader :support_code

      def initialize(support_code, user_interface)
        @support_code, @user_interface = support_code, user_interface
      end

      def_delegators :@user_interface,
        :embed,
        :ask,
        :puts,
        :features_paths,
        :step_match

      def_delegators :@support_code,
        :invoke_dynamic_steps,
        :invoke_dynamic_step,
        :load_programming_language

      # Returns a Cucumber::MultilineArgument::DataTable for +text_or_table+, which can either
      # be a String:
      #
      #   table(%{
      #     | account | description | amount |
      #     | INT-100 | Taxi        | 114    |
      #     | CUC-101 | Peeler      | 22     |
      #   })
      #
      # or a 2D Array:
      #
      #   table([
      #     %w{ account description amount },
      #     %w{ INT-100 Taxi        114    },
      #     %w{ CUC-101 Peeler      22     }
      #   ])
      #
      def table(text_or_table, file=nil, line=0)
        if !file
          location = Core::Ast::Location.of_caller
        else
          location = Core::Ast::Location.new(file, line)
        end
        MultilineArgument::DataTable.from(text_or_table, location)
      end

      # Returns a Cucumber::MultilineArgument::DocString for +body+.
      #
      def doc_string(body, content_type='', line_offset=0)
        location = Core::Ast::Location.of_caller
        MultilineArgument.doc_string(body, content_type, location)
      end
    end
  end
end
