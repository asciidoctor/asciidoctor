require 'asciidoctor/backends/docbook45'
# NOTE once we decide to make DocBook 5 the default, we'll load the files the other way around

module Asciidoctor

module DocBook5
class DocumentTemplate < DocBook45::DocumentTemplate
  def namespace_attributes doc
    ' xmlns="http://docbook.org/ns/docbook" xmlns:xlink="http://www.w3.org/1999/xlink" version="5.0"'
  end

  def docinfo_header doc, info_tag_prefix
    super doc
  end

  def author doc, index = nil
    firstname_key = index ? %(firstname_#{index}) : 'firstname'
    middlename_key = index ? %(middlename_#{index}) : 'middlename'
    lastname_key = index ? %(lastname_#{index}) : 'lastname'
    email_key = index ? %(email_#{index}) : 'email'

    result_buffer = []
    result_buffer << '<author>'
    result_buffer << '<personname>'
    result_buffer << %(<firstname>#{doc.attr firstname_key}</firstname>) if doc.attr? firstname_key
    result_buffer << %(<othername>#{doc.attr middlename_key}</othername>) if doc.attr? middlename_key
    result_buffer << %(<surname>#{doc.attr lastname_key}</surname>) if doc.attr? lastname_key
    result_buffer << '</personname>'
    result_buffer << %(<email>#{doc.attr email_key}</email>) if doc.attr? email_key
    result_buffer << '</author>'

    result_buffer * EOL
  end
end
class EmbeddedTemplate < DocBook45::EmbeddedTemplate; end
class BlockTocTemplate < DocBook45::BlockTocTemplate; end
class BlockPreambleTemplate < DocBook45::BlockPreambleTemplate; end
class SectionTemplate < DocBook45::SectionTemplate; end
class BlockFloatingTitleTemplate < DocBook45::BlockFloatingTitleTemplate; end
class BlockParagraphTemplate < DocBook45::BlockParagraphTemplate; end
class BlockAdmonitionTemplate < DocBook45::BlockAdmonitionTemplate; end
class BlockUlistTemplate < DocBook45::BlockUlistTemplate; end
class BlockOlistTemplate < DocBook45::BlockOlistTemplate; end
class BlockColistTemplate < DocBook45::BlockColistTemplate; end
class BlockDlistTemplate < DocBook45::BlockDlistTemplate; end
class BlockOpenTemplate < DocBook45::BlockOpenTemplate; end
class BlockListingTemplate < DocBook45::BlockListingTemplate; end
class BlockLiteralTemplate < DocBook45::BlockLiteralTemplate; end
class BlockExampleTemplate < DocBook45::BlockExampleTemplate; end
class BlockSidebarTemplate < DocBook45::BlockSidebarTemplate; end
class BlockQuoteTemplate < DocBook45::BlockQuoteTemplate; end
class BlockVerseTemplate < DocBook45::BlockVerseTemplate; end
class BlockPassTemplate < DocBook45::BlockPassTemplate; end
class BlockMathTemplate < DocBook45::BlockMathTemplate; end
class BlockTableTemplate < DocBook45::BlockTableTemplate; end
class BlockImageTemplate < DocBook45::BlockImageTemplate; end
class BlockAudioTemplate < DocBook45::BlockAudioTemplate; end
class BlockVideoTemplate < DocBook45::BlockVideoTemplate; end
class BlockRulerTemplate < DocBook45::BlockRulerTemplate; end
class BlockPageBreakTemplate < DocBook45::BlockPageBreakTemplate; end
class InlineBreakTemplate < DocBook45::InlineBreakTemplate; end
class InlineQuotedTemplate < DocBook45::InlineQuotedTemplate; end
class InlineButtonTemplate < DocBook45::InlineButtonTemplate; end
class InlineKbdTemplate < DocBook45::InlineKbdTemplate; end
class InlineMenuTemplate < DocBook45::InlineMenuTemplate; end
class InlineAnchorTemplate < DocBook45::InlineAnchorTemplate
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
        %(<link xlink:href="#{target}">#{text}</link>)
      end
    when :link
      %(<link xlink:href="#{target}">#{text}</link>)
    when :bibref
      %(<anchor#{common_attrs target, nil, "[#{target}]"}/>[#{target}])
    end
  end
end
class InlineImageTemplate < DocBook45::InlineImageTemplate; end
class InlineFootnoteTemplate < DocBook45::InlineFootnoteTemplate; end
class InlineCalloutTemplate < DocBook45::InlineCalloutTemplate; end
class InlineIndextermTemplate < DocBook45::InlineIndextermTemplate; end
end # module DocBook5
end # module Asciidoctor
