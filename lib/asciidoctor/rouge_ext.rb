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
        return unless (last_lineno = (formatted_lines[-1] || [])[0])
        lineno_width = last_lineno.length
        formatted_lines.each {|(lineno, line)| yield %(<span class="linenos">#{lineno.rjust lineno_width}</span>#{line}) }
      end
    end

    class HTMLTableLineNumberer < ::Rouge::Formatter
      def initialize delegate, opts
        @delegate = delegate
        @start_line = opts[:start_line] || 1
      end

      def stream tokens
        formatted_lines = (@delegate.to_enum :stream, tokens).with_index(@start_line).with_object({}) {|(line, lineno), accum| accum[lineno.to_s] = line }
        return unless (last_lineno = formatted_lines.keys[-1])
        lineno_width = last_lineno.length
        formatted_linenos = formatted_lines.keys.map {|lineno| (lineno.rjust lineno_width) + LF }
        yield %(<table class="linenotable"><tbody><tr><td class="linenos gl"><pre class="lineno">#{formatted_linenos.join}</pre></td><td class="code"><pre>#{formatted_lines.values.join}</pre></td></tr></tbody></table>)
      end
    end

    LF = ?\n

    private_constant :LF
  end
end
end
