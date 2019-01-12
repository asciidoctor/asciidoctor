module Asciidoctor
  class SyntaxHighlighter::HtmlPipeline < SyntaxHighlighter::Base
    register_for 'html-pipeline'

    def format node, lang, opts
      %(<pre#{lang ? %[ lang="#{lang}"] : ''}><code>#{node.content}</code></pre>)
    end
  end
end
