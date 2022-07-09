# frozen_string_literal: true
module Asciidoctor
class SyntaxHighlighter::HighlightJsAdapter < SyntaxHighlighter::Base
  register_for 'highlightjs', 'highlight.js'

  def initialize *args
    super
    @name = @pre_class = 'highlightjs'
  end

  def format node, lang, opts
    super node, lang, (opts.merge transform: proc {|_, code| code['class'] = %(language-#{lang || 'none'} hljs) })
  end

  def docinfo? location
    true
  end

  def docinfo location, doc, opts
    base_url = doc.attr 'highlightjsdir', %(#{opts[:cdn_base_url]}/highlight.js/#{HIGHLIGHT_JS_VERSION})
    if location == :head
      %(<link rel="stylesheet" href="#{base_url}/styles/#{doc.attr 'highlightjs-theme', 'github'}.min.css"#{opts[:self_closing_tag_slash]}>)
    else # :footer
      %(<script src="#{base_url}/highlight.min.js"></script>
#{(doc.attr? 'highlightjs-languages') ? ((doc.attr 'highlightjs-languages').split ',').map {|lang| %[<script src="#{base_url}/languages/#{lang.lstrip}.min.js"></script>\n] }.join : ''}<script>
if (!hljs.initHighlighting.called) {
  hljs.initHighlighting.called = true
  ;[].slice.call(document.querySelectorAll('pre.highlight > code[data-lang]')).forEach(function (el) { hljs.highlightBlock(el) })
}
</script>)
    end
  end
end
end
