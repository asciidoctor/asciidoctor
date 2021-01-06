# tag::extension[]
require "asciidoctor"
require "asciidoctor/extensions"

class RFCStandardLinkInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
  use_dsl

  named :rfc_standard_link
  match /\bRFC ?([0-9]{1,4})/
  parse_content_as :text

  def process(parent, target, attrs)
    base_path = 'https://tools.ietf.org/html/'
    create_anchor parent, target, type: :link, target: base_path + target.gsub(/\s+/, '')
  end
end
# end::extension[]

# tag::usage[]
Asciidoctor::Extensions.register do
  inline_macro RFCStandardLinkInlineMacro
end

source = '= Standards are Funny

Check out for example RFC 1882 at Christmas, RFC1927 when I forget the space.
Not to mention RFC 2549, a personal favorite.'

doc = Asciidoctor.load source

puts doc.convert
# end::usage[]
