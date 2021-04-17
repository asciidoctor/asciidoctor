require "asciidoctor"
require "asciidoctor/extensions"

class RFCStandardLinkInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
  enable_dsl

  named :rfc_standard_link
  match /\b(?:RFC ?)(?<target>[0-9]{1,4})\b/
  # content_model :text

  def process(parent, target, attrs)
    base_path = "https://tools.ietf.org/html/"
    create_anchor parent, %(RFC #{target}), type: :link, target: %(#{base_path}#{target})
  end
end

# Global registration via a group block.
Asciidoctor::Extensions.register do
  inline_macro RFCStandardLinkInlineMacro
end
