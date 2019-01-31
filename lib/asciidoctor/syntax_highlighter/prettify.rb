module Asciidoctor
class SyntaxHighlighter::PrettifyAdapter < SyntaxHighlighter::Base
  register_for 'prettify'

  def initialize *args
    super
    @pre_class = 'prettyprint'
  end

  def format node, lang, opts
    if node.attr? 'linenums', nil, false
      opts[:transform] = -> pre, _ { pre['class'] += %( #{(start = node.attr 'start', nil, false) ? %[linenums:#{start}] : 'linenums'}) }
    end
    super
  end

  def docinfo? location
    location == :footer
  end

  def docinfo location, doc, opts
    base_url = doc.attr 'prettifydir', %(#{opts[:cdn_base_url]}/prettify/r298)
    prettify_theme_url = ((prettify_theme = doc.attr 'prettify-theme', 'prettify').start_with? 'http://', 'https://') ? prettify_theme : %(#{base_url}/#{prettify_theme}.min.css)
    %(<link rel="stylesheet" href="#{prettify_theme_url}"#{opts[:self_closing_tag_slash]}>
<script src="#{base_url}/run_prettify.min.js"></script>)
  end
end
end
