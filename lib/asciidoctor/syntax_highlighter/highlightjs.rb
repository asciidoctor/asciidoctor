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
    asset_uri = opts[:asset_uri]
    base_uri = asset_uri[:highlightjs_uri].rpartition('/')[0]
    style_uri = "#{base_uri}/styles/#{doc.attr 'highlightjs-theme', 'github'}.min.css"
    languages_uri_path = "#{base_uri}/languages"

    if location == :head
      %(<link rel="stylesheet" href="#{style_uri}"#{opts[:self_closing_tag_slash]}>)
    else # :footer
      %(<script src="#{asset_uri[:highlightjs_uri]}"></script>
#{(doc.attr? 'highlightjs-languages') ? ((doc.attr 'highlightjs-languages').split ',').map {|lang| %(<script src="#{languages_uri_path}/#{lang.lstrip}.min.js"></script>\n) }.join : ''}<script>
if (!hljs.initHighlighting.called) {
  hljs.initHighlighting.called = true
  ;[].slice.call(document.querySelectorAll('pre.highlight > code[data-lang]')).forEach(function (el) { hljs.highlightBlock(el) })
}
</script>)
    end
  end
end
end
