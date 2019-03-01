# frozen_string_literal: true
require 'rouge' unless defined? Rouge.version

module Asciidoctor; module RougeExt; module Formatters
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
      lineno = 0
      token_lines tokens do |tokens_in_line|
        yield (@lines.include? lineno += 1) ? %(<span class="hll">#{@delegate.format tokens_in_line}#{LF}</span>) : %(#{@delegate.format tokens_in_line}#{LF})
      end
    end
  end

  LF = ?\n
  HangingEndSpanTagCs = %(#{LF}</span>)

  private_constant :HangingEndSpanTagCs, :LF
end; end; end
