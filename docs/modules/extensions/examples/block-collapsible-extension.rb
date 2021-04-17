require 'asciidoctor'
require 'asciidoctor/extensions'

class CollapsibleBlock < Asciidoctor::Extensions::BlockProcessor
  enable_dsl

  named :collapsible
  contexts :listing
  positional_attributes 'language'

  def process parent, reader, attrs
    lang = attrs.delete 'language'
    attrs['title'] ||= 'Show Listing'
    example = create_example_block parent, [], attrs, content_model: :compound
    example.set_option 'collapsible'
    listing = create_listing_block example, reader.readlines, nil
    if lang
      listing.style = 'source'
      listing.set_attr 'language', lang
      listing.commit_subs
    end
    example << listing
    example
  end
end

Asciidoctor::Extensions.register do
  block CollapsibleBlock
end
