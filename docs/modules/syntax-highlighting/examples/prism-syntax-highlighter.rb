class PrismSyntaxHighlighter < Asciidoctor::SyntaxHighlighter::Base
  register_for 'prism'

  def format node, lang, opts
    opts[:transform] = proc do |pre, code|
      code['class'] = %(language-#{lang}) if lang
    end
    super
  end

  def docinfo? location
    location == :footer
  end

  def docinfo location, doc, opts
    base_url = doc.attr 'prismdir', %(#{opts[:cdn_base_url]}/prism/1.15.0)
    slash = opts[:self_closing_tag_slash]
    unless (theme_name = doc.attr 'prism-style', 'prism') == 'prism'
      theme_name = %(prism-#{theme_name})
    end
    %(<link rel="stylesheet" href="#{base_url}/themes/#{theme_name}.min.css"#{slash}>
<script src="#{base_url}/prism.min.js"></script>
<script src="#{base_url}/components/prism-ruby.min.js"></script>)
  end
end
