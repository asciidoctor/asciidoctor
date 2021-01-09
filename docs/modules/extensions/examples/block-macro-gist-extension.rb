require 'asciidoctor'
require 'asciidoctor/extensions'

class GistBlockMacro < Asciidoctor::Extensions::BlockMacroProcessor
  enable_dsl

  named :gist

  def process parent, target, attrs
    title_html = (attrs.has_key? 'title') ?
                   %(<div class="title">#{attrs['title']}</div>\n) : nil

    html = %(<div class="openblock gist">
#{title_html}<div class="content">
<script src="https://gist.github.com/#{target}.js"></script>
</div>
</div>)

    create_pass_block parent, html, attrs, subs: nil
  end
end

# Self-registering
Asciidoctor::Extensions.register do
  block_macro GistBlockMacro if document.basebackend? 'html'
end
