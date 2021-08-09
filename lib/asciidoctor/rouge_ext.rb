# frozen_string_literal: true

require 'rouge' unless defined? Rouge.version

module Asciidoctor
module RougeExt
  module Formatters
    class HTMLTable < ::Rouge::Formatter
      def initialize delegate, opts
        @delegate = delegate
        @start_line = opts[:start_line] || 1
      end

      def stream tokens
        formatted_code = @delegate.format tokens
        formatted_code += LF unless formatted_code.end_with? LF, HangingEndSpanTagCs
        last_lineno = (first_lineno = @start_line) + (formatted_code.count LF) - 1 # assume number of newlines is constant
        lineno_format = %(%#{(::Math.log10 last_lineno).floor + 1}i)
        formatted_linenos = ((first_lineno..last_lineno).map {|lineno| sprintf lineno_format, lineno } << '').join LF
        yield %(<table class="linenotable"><tbody><tr><td class="linenos gl"><pre class="lineno">#{formatted_linenos}</pre></td><td class="code"><pre>#{formatted_code}</pre></td></tr></tbody></table>)
      end
    end

    class HTMLLineHighlighter < ::Rouge::Formatter
      def initialize delegate, opts
        @delegate = delegate
        @lines = opts[:lines] || []
      end

      def stream tokens
        (token_lines tokens).with_index 1 do |tokens_in_line, lineno|
          formatted_line = (@delegate.format tokens_in_line) + LF
          yield (@lines.include? lineno) ? %(<span class="hll">#{formatted_line}</span>) : formatted_line
        end
      end
    end

    LF = ?\n
    HangingEndSpanTagCs = %(#{LF}</span>)

    private_constant :HangingEndSpanTagCs, :LF
  end
end
end
