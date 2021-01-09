require 'asciidoctor'
require 'asciidoctor/extensions'

class ManInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
  enable_dsl

  named :man
  name_positional_attributes 'volnum'

  def process parent, target, attrs
    text = manname = target
    suffix = ''
    target = %(#{manname}.html)
    suffix = if (volnum = attrs['volnum'])
      "(#{volnum})"
    else
      nil
    end
    parent.document.register :links, target
    create_anchor parent, text, type: :link, target: %(#{target}#{suffix})
  end
end

# Self-registering
Asciidoctor::Extensions.register do
  inline_macro ManInlineMacro
end
