# frozen_string_literal: true

require 'rouge' unless defined? Rouge.version

module Asciidoctor
module RougeExt
  module Formatters
    class HTMLLineHighlighter < ::Rouge::Formatter
      def initialize delegate, opts
        @delegate = delegate
        @lines = opts[:lines] || []
      end

      def stream tokens
        if @lines.empty?
          token_lines(tokens) {|tokens_in_line| yield (@delegate.format tokens_in_line) + LF }
        else
          (token_lines tokens).with_index 1 do |tokens_in_line, lineno|
            formatted_line = (@delegate.format tokens_in_line) + LF
            yield (@lines.include? lineno) ? %(<span class="hll">#{formatted_line}</span>) : formatted_line
          end
        end
      end
    end

    class HTMLLineNumberer < ::Rouge::Formatter
      def initialize delegate, opts
        @delegate = delegate
        @start_line = opts[:start_line] || 1
      end

      def stream tokens
        formatted_lines = (@delegate.to_enum :stream, tokens).map.with_index(@start_line) {|line, lineno| [lineno.to_s, line] }
        return if (last_idx = formatted_lines.size - 1) < 0
        lineno_width = formatted_lines[last_idx][0].length
        formatted_lines.each {|(lineno, line)| yield %(<span class="linenos">#{lineno.rjust lineno_width}</span>#{line}) }
      end
    end

    class HTMLTableLineNumberer < ::Rouge::Formatter
      def initialize delegate, opts
        @delegate = delegate
        @start_line = opts[:start_line] || 1
      end

      def stream tokens
        return if (last_idx = (formatted_lines = (@delegate.to_enum :stream, tokens).to_a).size - 1) < 0
        formatted_lines.each_with_index do |line, idx|
          tr = %(<tr><td class="linenos"><pre>#{idx + @start_line}</pre></td><td class="code"><pre>#{line}</pre></td></tr>)
          yield (idx == 0 ? %(<table class="linenotable"><tbody>#{tr}) : (idx == last_idx ? %(#{tr}</tbody></table>) : tr))
        end
      end
    end

    LF = ?\n

    private_constant :LF
  end
end
end
