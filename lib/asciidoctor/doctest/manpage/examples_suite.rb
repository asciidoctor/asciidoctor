require 'asciidoctor/doctest/base_examples_suite'
require 'asciidoctor/doctest/core_ext'
module Asciidoctor::DocTest
  module ManPage
    class ExamplesSuite < BaseExamplesSuite
      def initialize(file_ext: '.1', **kwargs)
        super file_ext: file_ext, **kwargs
      end
      # TODO use more specific delimiter for example's header to not interfere
      # with comments in LaTeX output.
      def parse(input, group_name)
        examples = []
        current = create_example(nil)
        input.each_line do |line|
          case line.chomp!
          when /^\.\"\s*\.([^ \n]+)/
            name = $1
            current.content.chomp!
            examples << (current = create_example([group_name, name]))
          else
            current.content.concat(line, "\n")
          end
        end
        examples
      end
      def serialize(examples)
        Array.wrap(examples).map { |exmpl|
          lines = [".#{exmpl.local_name}", *exmpl.desc.lines.map(&:chomp)]
          exmpl.opts.each do |name, vals|
            Array.wrap(vals).each do |val|
              lines << (val == true ? ":#{name}:" : ":#{name}: #{val}")
            end
          end
          lines.map_send(:prepend, '." ')
          lines.push(exmpl.to_s) unless exmpl.empty?
          lines.join("\n") + "\n"
        }.join("\n")
      end
      # TODO implement some postprocessing to filter out boilerplate
      def convert_example(example, opts, renderer)
        content = renderer.render(example.to_s)
        create_example example.name, content: content, opts: opts
      end
    end
  end
end
