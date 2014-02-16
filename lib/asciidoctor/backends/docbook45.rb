require 'asciidoctor/backends/docbook5'

module Asciidoctor
module DocBook45
class DocumentTemplate < DocBook5::DocumentTemplate
  def namespace_attributes doc
    (doc.attr? 'noxmlns') ? nil : ' xmlns="http://docbook.org/ns/docbook"'
  end

  def author doc, index = nil
    firstname_key = index ? %(firstname_#{index}) : 'firstname'
    middlename_key = index ? %(middlename_#{index}) : 'middlename'
    lastname_key = index ? %(lastname_#{index}) : 'lastname'
    email_key = index ? %(email_#{index}) : 'email'

    result_buffer = []
    result_buffer << '<author>'
    result_buffer << %(<firstname>#{doc.attr firstname_key}</firstname>) if doc.attr? firstname_key
    result_buffer << %(<othername>#{doc.attr middlename_key}</othername>) if doc.attr? middlename_key
    result_buffer << %(<surname>#{doc.attr lastname_key}</surname>) if doc.attr? lastname_key
    result_buffer << %(<email>#{doc.attr email_key}</email>) if doc.attr? email_key
    result_buffer << '</author>'

    result_buffer * EOL
  end

  def docinfo_header doc, info_tag_prefix
    super doc, info_tag_prefix, true
  end

  def doctype_declaration root_tag_name
    %(<!DOCTYPE #{root_tag_name} PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">)
  end
end

class EmbeddedTemplate < DocBook5::EmbeddedTemplate; end
class BlockTocTemplate < DocBook5::BlockTocTemplate; end
class BlockPreambleTemplate < DocBook5::BlockPreambleTemplate; end
class SectionTemplate < DocBook5::SectionTemplate; end
class BlockFloatingTitleTemplate < DocBook5::BlockFloatingTitleTemplate; end
class BlockParagraphTemplate < DocBook5::BlockParagraphTemplate; end
class BlockAdmonitionTemplate < DocBook5::BlockAdmonitionTemplate; end
class BlockUlistTemplate < DocBook5::BlockUlistTemplate; end
class BlockOlistTemplate < DocBook5::BlockOlistTemplate; end
class BlockColistTemplate < DocBook5::BlockColistTemplate; end
class BlockDlistTemplate < DocBook5::BlockDlistTemplate; end
class BlockOpenTemplate < DocBook5::BlockOpenTemplate; end
class BlockListingTemplate < DocBook5::BlockListingTemplate; end
class BlockLiteralTemplate < DocBook5::BlockLiteralTemplate; end
class BlockExampleTemplate < DocBook5::BlockExampleTemplate; end
class BlockSidebarTemplate < DocBook5::BlockSidebarTemplate; end
class BlockQuoteTemplate < DocBook5::BlockQuoteTemplate; end
class BlockVerseTemplate < DocBook5::BlockVerseTemplate; end
class BlockPassTemplate < DocBook5::BlockPassTemplate; end
class BlockMathTemplate < DocBook5::BlockMathTemplate; end
class BlockTableTemplate < DocBook5::BlockTableTemplate; end
class BlockImageTemplate < DocBook5::BlockImageTemplate; end
class BlockAudioTemplate < DocBook5::BlockAudioTemplate; end
class BlockVideoTemplate < DocBook5::BlockVideoTemplate; end
class BlockRulerTemplate < DocBook5::BlockRulerTemplate; end
class BlockPageBreakTemplate < DocBook5::BlockPageBreakTemplate; end
class InlineBreakTemplate < DocBook5::InlineBreakTemplate; end
class InlineQuotedTemplate < DocBook5::InlineQuotedTemplate; end
class InlineButtonTemplate < DocBook5::InlineButtonTemplate; end
class InlineKbdTemplate < DocBook5::InlineKbdTemplate; end
class InlineMenuTemplate < DocBook5::InlineMenuTemplate; end
class InlineImageTemplate < DocBook5::InlineImageTemplate; end

class InlineAnchorTemplate < DocBook5::InlineAnchorTemplate
  def anchor(target, text, type, node)
    case type
    when :ref
      %(<anchor#{common_attrs target, nil, text}/>)
    when :xref
      if node.attr? 'path', nil
        linkend = (node.attr 'fragment') || target
        text.nil? ? %(<xref linkend="#{linkend}"/>) : %(<link linkend="#{linkend}">#{text}</link>)
      else
        text = text || (node.attr 'path')
        %(<ulink url="#{target}">#{text}</ulink>)
      end
    when :link
      %(<ulink url="#{target}">#{text}</ulink>)
    when :bibref
      %(<anchor#{common_attrs target, nil, "[#{target}]"}/>[#{target}])
    end
  end
end

class InlineFootnoteTemplate < DocBook5::InlineFootnoteTemplate; end
class InlineCalloutTemplate < DocBook5::InlineCalloutTemplate; end
class InlineIndextermTemplate < DocBook5::InlineIndextermTemplate; end

end # module DocBook45
end # module Asciidoctor
