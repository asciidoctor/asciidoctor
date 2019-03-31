module Cucumber
  module RbSupport
    module Snippet

      ARGUMENT_PATTERNS = ['"([^"]*)"', '(\d+)']

      class Generator
        def self.register_on(configuration)
          configuration.snippet_generators << new
        end

        def call(code_keyword, step_name, multiline_arg, snippet_type = :regexp)
          snippet_class = typed_snippet_class(snippet_type)
          snippet_class.new(code_keyword, step_name, multiline_arg).to_s
        end

        def typed_snippet_class(type)
          SNIPPET_TYPES.fetch(type || :regexp)
        end
      end

      class BaseSnippet

        def initialize(code_keyword, pattern, multiline_argument)
          @number_of_arguments = 0
          @code_keyword = code_keyword
          @pattern = replace_and_count_capturing_groups(pattern)
          @multiline_argument = MultilineArgumentSnippet.new(multiline_argument)
        end

        def to_s
          "#{step} #{do_block}"
        end

        def step
          "#{code_keyword}#{typed_pattern}"
        end

        def self.cli_option_string(type)
          "%-7s: %-28s e.g. %s" % [type, description, example]
        end

        private

        attr_reader :code_keyword, :pattern, :multiline_argument, :number_of_arguments

        def replace_and_count_capturing_groups(pattern)
          modified_pattern = ::Regexp.escape(pattern).gsub('\ ', ' ').gsub('/', '\/')

          ARGUMENT_PATTERNS.each do |argument_pattern|
            modified_pattern.gsub!(::Regexp.new(argument_pattern), argument_pattern)
            @number_of_arguments += modified_pattern.scan(argument_pattern).length
          end

          modified_pattern
        end

        def do_block
          do_block = ""
          do_block << "do#{arguments}\n"
          multiline_argument.append_comment_to(do_block)
          do_block << "  pending # Write code here that turns the phrase above into concrete actions\n"
          do_block << "end"
          do_block
        end

        def arguments
          block_args = (0...number_of_arguments).map { |n| "arg#{n+1}" }
          multiline_argument.append_block_argument_to(block_args)
          block_args.empty? ? "" : " |#{block_args.join(", ")}|"
        end

        def self.example
          new("Given", "missing step", MultilineArgument::None.new).step
        end

      end

      class Regexp < BaseSnippet
        def typed_pattern
          "(/^#{pattern}$/)"
        end

        def self.description
          "Snippets with parentheses"
        end
      end

      class Classic < BaseSnippet
        def typed_pattern
          " /^#{pattern}$/"
        end

        def self.description
          "Snippets without parentheses. Note that these cause a warning from modern versions of Ruby."
        end
      end

      class Percent < BaseSnippet
        def typed_pattern
          " %r{^#{pattern}$}"
        end

        def self.description
          "Snippets with percent regexp"
        end
      end

      SNIPPET_TYPES = {
        :regexp => Regexp,
        :classic => Classic,
        :percent => Percent
      }

      module MultilineArgumentSnippet

        def self.new(multiline_argument)
          builder = Builder.new
          multiline_argument.describe_to(builder)
          builder.result
        end

        class Builder
          def doc_string(*args)
            @result = DocString.new
          end

          def data_table(table, *args)
            @result = DataTable.new(table)
          end

          def result
            @result || None.new
          end
        end

        class DocString
          def append_block_argument_to(array)
            array << 'string'
          end

          def append_comment_to(string)
          end
        end

        class DataTable
          def initialize(table)
            @table = table
          end

          def append_block_argument_to(array)
            array << 'table'
          end

          def append_comment_to(string)
            string << "  # table is a #{Cucumber::MultilineArgument::DataTable.to_s}\n"
          end
        end

        class None
          def append_block_argument_to(array)
          end

          def append_comment_to(string)
          end
        end
      end
    end
  end
end
