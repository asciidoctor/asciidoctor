# frozen_string_literal: true
module Asciidoctor
# A built-in {Converter} implementation that generates DocBook 5 output. The output is inspired by the output produced
# by the docbook45 backend from AsciiDoc Python, except it has been migrated to the DocBook 5 specification.
class Converter::DocBook5Converter < Converter::Base
  register_for 'docbook5'

  # default represents variablelist
  (DLIST_TAGS = {
    'qanda' => { list:  'qandaset', entry: 'qandaentry', label: 'question', term:  'simpara', item:  'answer' },
    'glossary' => { list:  nil, entry: 'glossentry', term:  'glossterm', item:  'glossdef' },
  }).default = { list:  'variablelist', entry: 'varlistentry', term: 'term', item:  'listitem' }

  (QUOTE_TAGS = {
    monospaced:  ['<literal>', '</literal>'],
    emphasis:    ['<emphasis>', '</emphasis>', true],
    strong:      ['<emphasis role="strong">', '</emphasis>', true],
    double:      ['<quote>', '</quote>', true],
    single:      ['<quote>', '</quote>', true],
    mark:        ['<emphasis role="marked">', '</emphasis>'],
    superscript: ['<superscript>', '</superscript>'],
    subscript:   ['<subscript>', '</subscript>'],
  }).default = ['', '', true]

  MANPAGE_SECTION_TAGS = { 'section' => 'refsection', 'synopsis' => 'refsynopsisdiv' }
  TABLE_PI_NAMES = ['dbhtml', 'dbfo', 'dblatex']

  CopyrightRx = /^(.+?)(?: ((?:\d{4}\-)?\d{4}))?$/
  ImageMacroRx = /^image::?(.+?)\[(.*?)\]$/

  def initialize backend, opts = {}
    @backend = backend
    init_backend_traits basebackend: 'docbook', filetype: 'xml', outfilesuffix: '.xml', supports_templates: true
  end

  def document node
    result = ['<?xml version="1.0" encoding="UTF-8"?>']
    if node.attr? 'toc'
      if node.attr? 'toclevels'
        result << %(<?asciidoc-toc maxdepth="#{node.attr 'toclevels'}"?>)
      else
        result << '<?asciidoc-toc?>'
      end
    end
    if node.attr? 'sectnums'
      if node.attr? 'sectnumlevels'
        result << %(<?asciidoc-numbered maxdepth="#{node.attr 'sectnumlevels'}"?>)
      else
        result << '<?asciidoc-numbered?>'
      end
    end
    lang_attribute = (node.attr? 'nolang') ? '' : %( xml:lang="#{node.attr 'lang', 'en'}")
    if (root_tag_name = node.doctype) == 'manpage'
      root_tag_name = 'refentry'
    end
    result << %(<#{root_tag_name} xmlns="http://docbook.org/ns/docbook" xmlns:xl="http://www.w3.org/1999/xlink" version="5.0"#{lang_attribute}#{_common_attributes node.id}>)
    result << (_document_info_tag node) unless node.noheader
    unless (docinfo_content = node.docinfo :header).empty?
      result << docinfo_content
    end
    result << node.content if node.blocks?
    unless (docinfo_content = node.docinfo :footer).empty?
      result << docinfo_content
    end
    result << %(</#{root_tag_name}>)
    result.join LF
  end

  alias embedded _content_only

  def section node
    if node.document.doctype == 'manpage'
      tag_name = MANPAGE_SECTION_TAGS[tag_name = node.sectname] || tag_name
    else
      tag_name = node.sectname
    end
    title_el = node.special && (node.option? 'untitled') ? '' : %(<title>#{node.title}</title>\n)
    %(<#{tag_name}#{_common_attributes node.id, node.role, node.reftext}>
#{title_el}#{node.content}
</#{tag_name}>)
  end

  def admonition node
    %(<#{tag_name = node.attr 'name'}#{_common_attributes node.id, node.role, node.reftext}>
#{_title_tag node}#{_enclose_content node}
</#{tag_name}>)
  end

  alias audio _skip

  def colist node
    result = []
    result << %(<calloutlist#{_common_attributes node.id, node.role, node.reftext}>)
    result << %(<title>#{node.title}</title>) if node.title?
    node.items.each do |item|
      result << %(<callout arearefs="#{item.attr 'coids'}">)
      result << %(<para>#{item.text}</para>)
      result << item.content if item.blocks?
      result << '</callout>'
    end
    result << %(</calloutlist>)
    result.join LF
  end

  def dlist node
    result = []
    if node.style == 'horizontal'
      result << %(<#{tag_name = node.title? ? 'table' : 'informaltable'}#{_common_attributes node.id, node.role, node.reftext} tabstyle="horizontal" frame="none" colsep="0" rowsep="0">
#{_title_tag node}<tgroup cols="2">
<colspec colwidth="#{node.attr 'labelwidth', 15}*"/>
<colspec colwidth="#{node.attr 'itemwidth', 85}*"/>
<tbody valign="top">)
      node.items.each do |terms, dd|
        result << %(<row>
<entry>)
        terms.each {|dt| result << %(<simpara>#{dt.text}</simpara>) }
        result << %(</entry>
<entry>)
        if dd
          result << %(<simpara>#{dd.text}</simpara>) if dd.text?
          result << dd.content if dd.blocks?
        end
        result << %(</entry>
</row>)
      end
      result << %(</tbody>
</tgroup>
</#{tag_name}>)
    else
      tags = DLIST_TAGS[node.style]
      list_tag = tags[:list]
      entry_tag = tags[:entry]
      label_tag = tags[:label]
      term_tag = tags[:term]
      item_tag = tags[:item]
      if list_tag
        result << %(<#{list_tag}#{_common_attributes node.id, node.role, node.reftext}>)
        result << %(<title>#{node.title}</title>) if node.title?
      end

      node.items.each do |terms, dd|
        result << %(<#{entry_tag}>)
        result << %(<#{label_tag}>) if label_tag
        terms.each {|dt| result << %(<#{term_tag}>#{dt.text}</#{term_tag}>) }
        result << %(</#{label_tag}>) if label_tag
        result << %(<#{item_tag}>)
        if dd
          result << %(<simpara>#{dd.text}</simpara>) if dd.text?
          result << dd.content if dd.blocks?
        end
        result << %(</#{item_tag}>)
        result << %(</#{entry_tag}>)
      end

      result << %(</#{list_tag}>) if list_tag
    end

    result.join LF
  end

  def example node
    if node.title?
      %(<example#{_common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{_enclose_content node}
</example>)
    else
      %(<informalexample#{_common_attributes node.id, node.role, node.reftext}>
#{_enclose_content node}
</informalexample>)
    end
  end

  def floating_title node
    %(<bridgehead#{_common_attributes node.id, node.role, node.reftext} renderas="sect#{node.level}">#{node.title}</bridgehead>)
  end

  def image node
    # NOTE according to the DocBook spec, content area, scaling, and scaling to fit are mutually exclusive
    # See http://tdg.docbook.org/tdg/4.5/imagedata-x.html#d0e79635
    if node.attr? 'scaledwidth'
      width_attribute = %( width="#{node.attr 'scaledwidth'}")
      depth_attribute = ''
      scale_attribute = ''
    elsif node.attr? 'scale'
      # QUESTION should we set the viewport using width and depth? (the scaled image would be contained within this box)
      #width_attribute = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : ''
      #depth_attribute = (node.attr? 'height') ? %( depth="#{node.attr 'height'}") : ''
      scale_attribute = %( scale="#{node.attr 'scale'}")
    else
      width_attribute = (node.attr? 'width') ? %( contentwidth="#{node.attr 'width'}") : ''
      depth_attribute = (node.attr? 'height') ? %( contentdepth="#{node.attr 'height'}") : ''
      scale_attribute = ''
    end
    align_attribute = (node.attr? 'align') ? %( align="#{node.attr 'align'}") : ''

    mediaobject = %(<mediaobject>
<imageobject>
<imagedata fileref="#{node.image_uri(node.attr 'target')}"#{width_attribute}#{depth_attribute}#{scale_attribute}#{align_attribute}/>
</imageobject>
<textobject><phrase>#{node.alt}</phrase></textobject>
</mediaobject>)

    if node.title?
      %(<figure#{_common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{mediaobject}
</figure>)
    else
      %(<informalfigure#{_common_attributes node.id, node.role, node.reftext}>
#{mediaobject}
</informalfigure>)
    end
  end

  def listing node
    informal = !node.title?
    common_attrs = _common_attributes node.id, node.role, node.reftext
    if node.style == 'source'
      if (attrs = node.attributes).key? 'linenums'
        numbering_attrs = (attrs.key? 'start') ? %( linenumbering="numbered" startinglinenumber="#{attrs['start'].to_i}") : ' linenumbering="numbered"'
      else
        numbering_attrs = ' linenumbering="unnumbered"'
      end
      if attrs.key? 'language'
        wrapped_content = %(<programlisting#{informal ? common_attrs : ''} language="#{attrs['language']}"#{numbering_attrs}>#{node.content}</programlisting>)
      else
        wrapped_content = %(<screen#{informal ? common_attrs : ''}#{numbering_attrs}>#{node.content}</screen>)
      end
    else
      wrapped_content = %(<screen#{informal ? common_attrs : ''}>#{node.content}</screen>)
    end
    informal ? wrapped_content : %(<formalpara#{common_attrs}>
<title>#{node.title}</title>
<para>
#{wrapped_content}
</para>
</formalpara>)
  end

  def literal node
    if node.title?
      %(<formalpara#{_common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
<para>
<literallayout class="monospaced">#{node.content}</literallayout>
</para>
</formalpara>)
    else
      %(<literallayout#{_common_attributes node.id, node.role, node.reftext} class="monospaced">#{node.content}</literallayout>)
    end
  end

  alias pass _content_only

  def stem node
    if (idx = node.subs.index :specialcharacters)
      node.subs.delete_at idx
      equation = node.content || ''
      idx > 0 ? (node.subs.insert idx, :specialcharacters) : (node.subs.unshift :specialcharacters)
    else
      equation = node.content || ''
    end
    if node.style == 'asciimath'
      # NOTE fop requires jeuclid to process mathml markup
      equation_data = _asciimath_available? ? ((::AsciiMath.parse equation).to_mathml 'mml:', 'xmlns:mml' => 'http://www.w3.org/1998/Math/MathML') : %(<mathphrase><![CDATA[#{equation}]]></mathphrase>)
    else
      # unhandled math; pass source to alt and required mathphrase element; dblatex will process alt as LaTeX math
      equation_data = %(<alt><![CDATA[#{equation}]]></alt>
<mathphrase><![CDATA[#{equation}]]></mathphrase>)
    end
    if node.title?
      %(<equation#{_common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{equation_data}
</equation>)
    else
      # WARNING dblatex displays the <informalequation> element inline instead of block as documented (except w/ mathml)
      %(<informalequation#{_common_attributes node.id, node.role, node.reftext}>
#{equation_data}
</informalequation>)
    end
  end

  def olist node
    result = []
    num_attribute = node.style ? %( numeration="#{node.style}") : ''
    start_attribute = (node.attr? 'start') ? %( startingnumber="#{node.attr 'start'}") : ''
    result << %(<orderedlist#{_common_attributes node.id, node.role, node.reftext}#{num_attribute}#{start_attribute}>)
    result << %(<title>#{node.title}</title>) if node.title?
    node.items.each do |item|
      result << %(<listitem#{_common_attributes item.id, item.role}>)
      result << %(<simpara>#{item.text}</simpara>)
      result << item.content if item.blocks?
      result << '</listitem>'
    end
    result << %(</orderedlist>)
    result.join LF
  end

  def open node
    case node.style
    when 'abstract'
      if node.parent == node.document && node.document.doctype == 'book'
        logger.warn 'abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
        ''
      else
        %(<abstract>
#{_title_tag node}#{_enclose_content node}
</abstract>)
      end
    when 'partintro'
      unless node.level == 0 && node.parent.context == :section && node.document.doctype == 'book'
        logger.error 'partintro block can only be used when doctype is book and must be a child of a book part. Excluding block content.'
        ''
      else
        %(<partintro#{_common_attributes node.id, node.role, node.reftext}>
#{_title_tag node}#{_enclose_content node}
</partintro>)
      end
    else
      reftext = node.reftext if (id = node.id)
      role = node.role
      if node.title?
        %(<formalpara#{_common_attributes id, role, reftext}>
<title>#{node.title}</title>
<para>#{content_spacer = node.content_model == :compound ? LF : ''}#{node.content}#{content_spacer}</para>
</formalpara>)
      elsif id || role
        if node.content_model == :compound
          %(<para#{_common_attributes id, role, reftext}>
#{node.content}
</para>)
        else
          %(<simpara#{_common_attributes id, role, reftext}>#{node.content}</simpara>)
        end
      else
        _enclose_content node
      end
    end
  end

  def page_break node
    '<simpara><?asciidoc-pagebreak?></simpara>'
  end

  def paragraph node
    if node.title?
      %(<formalpara#{_common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
<para>#{node.content}</para>
</formalpara>)
    else
      %(<simpara#{_common_attributes node.id, node.role, node.reftext}>#{node.content}</simpara>)
    end
  end

  def preamble node
    if node.document.doctype == 'book'
      %(<preface#{_common_attributes node.id, node.role, node.reftext}>
#{_title_tag node, false}#{node.content}
</preface>)
    else
      node.content
    end
  end

  def quote node
    _blockquote_tag(node, (node.has_role? 'epigraph') && 'epigraph') { _enclose_content node }
  end

  def thematic_break node
    '<simpara><?asciidoc-hr?></simpara>'
  end

  def sidebar node
    %(<sidebar#{_common_attributes node.id, node.role, node.reftext}>
#{_title_tag node}#{_enclose_content node}
</sidebar>)
  end

  def table node
    has_body = false
    result = []
    pgwide_attribute = (node.option? 'pgwide') ? ' pgwide="1"' : ''
    if (frame = node.attr 'frame', 'all', 'table-frame') == 'ends'
      frame = 'topbot'
    end
    grid = node.attr 'grid', nil, 'table-grid'
    result << %(<#{tag_name = node.title? ? 'table' : 'informaltable'}#{_common_attributes node.id, node.role, node.reftext}#{pgwide_attribute} frame="#{frame}" rowsep="#{['none', 'cols'].include?(grid) ? 0 : 1}" colsep="#{['none', 'rows'].include?(grid) ? 0 : 1}"#{(node.attr? 'orientation', 'landscape', 'table-orientation') ? ' orient="land"' : ''}>)
    if (node.option? 'unbreakable')
      result << '<?dbfo keep-together="always"?>'
    elsif (node.option? 'breakable')
      result << '<?dbfo keep-together="auto"?>'
    end
    result << %(<title>#{node.title}</title>) if tag_name == 'table'
    col_width_key = if (width = (node.attr? 'width') ? (node.attr 'width') : nil)
      TABLE_PI_NAMES.each do |pi_name|
        result << %(<?#{pi_name} table-width="#{width}"?>)
      end
      'colabswidth'
    else
      'colpcwidth'
    end
    result << %(<tgroup cols="#{node.attr 'colcount'}">)
    node.columns.each do |col|
      result << %(<colspec colname="col_#{col.attr 'colnumber'}" colwidth="#{col.attr col_width_key}*"/>)
    end
    node.rows.to_h.each do |tsec, rows|
      next if rows.empty?
      has_body = true if tsec == :body
      result << %(<t#{tsec}>)
      rows.each do |row|
        result << '<row>'
        row.each do |cell|
          halign_attribute = (cell.attr? 'halign') ? %( align="#{cell.attr 'halign'}") : ''
          valign_attribute = (cell.attr? 'valign') ? %( valign="#{cell.attr 'valign'}") : ''
          colspan_attribute = cell.colspan ? %( namest="col_#{colnum = cell.column.attr 'colnumber'}" nameend="col_#{colnum + cell.colspan - 1}") : ''
          rowspan_attribute = cell.rowspan ? %( morerows="#{cell.rowspan - 1}") : ''
          # NOTE <entry> may not have whitespace (e.g., line breaks) as a direct descendant according to DocBook rules
          entry_start = %(<entry#{halign_attribute}#{valign_attribute}#{colspan_attribute}#{rowspan_attribute}>)
          if tsec == :head
            cell_content = cell.text
          else
            case cell.style
            when :asciidoc
              cell_content = cell.content
            when :literal
              cell_content = %(<literallayout class="monospaced">#{cell.text}</literallayout>)
            when :header
              cell_content = (cell_content = cell.content).empty? ? '' : %(<simpara><emphasis role="strong">#{cell_content.join '</emphasis></simpara><simpara><emphasis role="strong">'}</emphasis></simpara>)
            else
              cell_content = (cell_content = cell.content).empty? ? '' : %(<simpara>#{cell_content.join '</simpara><simpara>'}</simpara>)
            end
          end
          entry_end = (node.document.attr? 'cellbgcolor') ? %(<?dbfo bgcolor="#{node.document.attr 'cellbgcolor'}"?></entry>) : '</entry>'
          result << %(#{entry_start}#{cell_content}#{entry_end})
        end
        result << '</row>'
      end
      result << %(</t#{tsec}>)
    end
    result << '</tgroup>'
    result << %(</#{tag_name}>)

    logger.warn 'tables must have at least one body row' unless has_body
    result.join LF
  end

  alias toc _skip

  def ulist node
    result = []
    if node.style == 'bibliography'
      result << %(<bibliodiv#{_common_attributes node.id, node.role, node.reftext}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each do |item|
        result << '<bibliomixed>'
        result << %(<bibliomisc>#{item.text}</bibliomisc>)
        result << item.content if item.blocks?
        result << '</bibliomixed>'
      end
      result << '</bibliodiv>'
    else
      mark_type = (checklist = node.option? 'checklist') ? 'none' : node.style
      mark_attribute = mark_type ? %( mark="#{mark_type}") : ''
      result << %(<itemizedlist#{_common_attributes node.id, node.role, node.reftext}#{mark_attribute}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each do |item|
        text_marker = (item.attr? 'checked') ? '&#10003; ' : '&#10063; ' if checklist && (item.attr? 'checkbox')
        result << %(<listitem#{_common_attributes item.id, item.role}>)
        result << %(<simpara>#{text_marker || ''}#{item.text}</simpara>)
        result << item.content if item.blocks?
        result << '</listitem>'
      end
      result << '</itemizedlist>'
    end
    result.join LF
  end

  def verse node
    _blockquote_tag(node, (node.has_role? 'epigraph') && 'epigraph') { %(<literallayout>#{node.content}</literallayout>) }
  end

  alias video _skip

  def inline_anchor node
    case node.type
    when :ref
      %(<anchor#{_common_attributes((id = node.id), nil, node.reftext || %([#{id}]))}/>)
    when :xref
      if (path = node.attributes['path'])
        # QUESTION should we use refid as fallback text instead? (like the html5 backend?)
        %(<link xl:href="#{node.target}">#{node.text || path}</link>)
      else
        linkend = node.attributes['fragment'] || node.target
        (text = node.text) ? %(<link linkend="#{linkend}">#{text}</link>) : %(<xref linkend="#{linkend}"/>)
      end
    when :link
      %(<link xl:href="#{node.target}">#{node.text}</link>)
    when :bibref
      %(<anchor#{_common_attributes node.id, nil, "[#{node.reftext || node.id}]"}/>#{text})
    else
      logger.warn %(unknown anchor type: #{node.type.inspect})
      nil
    end
  end

  def inline_break node
    %(#{node.text}<?asciidoc-br?>)
  end

  def inline_button node
    %(<guibutton>#{node.text}</guibutton>)
  end

  def inline_callout node
    %(<co#{_common_attributes node.id}/>)
  end

  def inline_footnote node
    if node.type == :xref
      %(<footnoteref linkend="#{node.target}"/>)
    else
      %(<footnote#{_common_attributes node.id}><simpara>#{node.text}</simpara></footnote>)
    end
  end

  def inline_image node
    width_attribute = (node.attr? 'width') ? %( contentwidth="#{node.attr 'width'}") : ''
    depth_attribute = (node.attr? 'height') ? %( contentdepth="#{node.attr 'height'}") : ''
    %(<inlinemediaobject>
<imageobject>
<imagedata fileref="#{node.type == 'icon' ? (node.icon_uri node.target) : (node.image_uri node.target)}"#{width_attribute}#{depth_attribute}/>
</imageobject>
<textobject><phrase>#{node.alt}</phrase></textobject>
</inlinemediaobject>)
  end

  def inline_indexterm node
    if node.type == :visible
      %(<indexterm><primary>#{node.text}</primary></indexterm>#{node.text})
    else
      terms = node.attr 'terms'
      result = []
      if (numterms = terms.size) > 2
        result << %(<indexterm>
<primary>#{terms[0]}</primary><secondary>#{terms[1]}</secondary><tertiary>#{terms[2]}</tertiary>
</indexterm>)
      end
      if numterms > 1
        result << %(<indexterm>
<primary>#{terms[-2]}</primary><secondary>#{terms[-1]}</secondary>
</indexterm>)
      end
      result << %(<indexterm>
<primary>#{terms[-1]}</primary>
</indexterm>)
      result.join LF
    end
  end

  def inline_kbd node
    if (keys = node.attr 'keys').size == 1
      %(<keycap>#{keys[0]}</keycap>)
    else
      %(<keycombo><keycap>#{keys.join '</keycap><keycap>'}</keycap></keycombo>)
    end
  end

  def inline_menu node
    menu = node.attr 'menu'
    if (submenus = node.attr 'submenus').empty?
      if (menuitem = node.attr 'menuitem')
        %(<menuchoice><guimenu>#{menu}</guimenu> <guimenuitem>#{menuitem}</guimenuitem></menuchoice>)
      else
        %(<guimenu>#{menu}</guimenu>)
      end
    else
      %(<menuchoice><guimenu>#{menu}</guimenu> <guisubmenu>#{submenus.join '</guisubmenu> <guisubmenu>'}</guisubmenu> <guimenuitem>#{node.attr 'menuitem'}</guimenuitem></menuchoice>)
    end
  end

  def inline_quoted node
    if (type = node.type) == :asciimath
      # NOTE fop requires jeuclid to process mathml markup
      _asciimath_available? ? %(<inlineequation>#{(::AsciiMath.parse node.text).to_mathml 'mml:', 'xmlns:mml' => 'http://www.w3.org/1998/Math/MathML'}</inlineequation>) : %(<inlineequation><mathphrase><![CDATA[#{node.text}]]></mathphrase></inlineequation>)
    elsif type == :latexmath
      # unhandled math; pass source to alt and required mathphrase element; dblatex will process alt as LaTeX math
      %(<inlineequation><alt><![CDATA[#{equation = node.text}]]></alt><mathphrase><![CDATA[#{equation}]]></mathphrase></inlineequation>)
    else
      open, close, supports_phrase = QUOTE_TAGS[type]
      text = node.text
      if node.role
        if supports_phrase
          quoted_text = %(#{open}<phrase role="#{node.role}">#{text}</phrase>#{close})
        else
          quoted_text = %(#{open.chop} role="#{node.role}">#{text}#{close})
        end
      else
        quoted_text = %(#{open}#{text}#{close})
      end

      node.id ? %(<anchor#{_common_attributes node.id, nil, text}/>#{quoted_text}) : quoted_text
    end
  end

  private

  def _common_attributes id, role = nil, reftext = nil
    if id
      attrs = %( xml:id="#{id}"#{role ? %[ role="#{role}"] : ''})
    elsif role
      attrs = %( role="#{role}")
    else
      attrs = ''
    end
    if reftext
      if (reftext.include? '<') && ((reftext = reftext.gsub XmlSanitizeRx, '').include? ' ')
        reftext = (reftext.squeeze ' ').strip
      end
      reftext = (reftext.gsub '"', '&quot;') if reftext.include? '"'
      %(#{attrs} xreflabel="#{reftext}")
    else
      attrs
    end
  end

  def _author_tag author
    result = []
    result << '<author>'
    result << '<personname>'
    result << %(<firstname>#{author.firstname}</firstname>) if author.firstname
    result << %(<othername>#{author.middlename}</othername>) if author.middlename
    result << %(<surname>#{author.lastname}</surname>) if author.lastname
    result << '</personname>'
    result << %(<email>#{author.email}</email>) if author.email
    result << '</author>'
    result.join LF
  end

  def _document_info_tag doc
    result = ['<info>']
    unless doc.notitle
      if (title = doc.doctitle partition: true, use_fallback: true).subtitle?
        result << %(<title>#{title.main}</title>
<subtitle>#{title.subtitle}</subtitle>)
      else
        result << %(<title>#{title}</title>)
      end
    end
    if (date = (doc.attr? 'revdate') ? (doc.attr 'revdate') : ((doc.attr? 'reproducible') ? nil : (doc.attr 'docdate')))
      result << %(<date>#{date}</date>)
    end
    if doc.attr? 'copyright'
      CopyrightRx =~ (doc.attr 'copyright')
      result << '<copyright>'
      result << %(<holder>#{$1}</holder>)
      result << %(<year>#{$2}</year>) if $2
      result << '</copyright>'
    end
    if doc.header?
      unless (authors = doc.authors).empty?
        if authors.size > 1
          result << '<authorgroup>'
          authors.each {|author| result << (_author_tag author) }
          result << '</authorgroup>'
        else
          result << _author_tag(author = authors[0])
          result << %(<authorinitials>#{author.initials}</authorinitials>) if author.initials
        end
      end
      if (doc.attr? 'revdate') && ((doc.attr? 'revnumber') || (doc.attr? 'revremark'))
        result << %(<revhistory>
<revision>)
        result << %(<revnumber>#{doc.attr 'revnumber'}</revnumber>) if doc.attr? 'revnumber'
        result << %(<date>#{doc.attr 'revdate'}</date>) if doc.attr? 'revdate'
        result << %(<authorinitials>#{doc.attr 'authorinitials'}</authorinitials>) if doc.attr? 'authorinitials'
        result << %(<revremark>#{doc.attr 'revremark'}</revremark>) if doc.attr? 'revremark'
        result << %(</revision>
</revhistory>)
      end
      if (doc.attr? 'front-cover-image') || (doc.attr? 'back-cover-image')
        if (back_cover_tag = _cover_tag doc, 'back')
          result << (_cover_tag doc, 'front', true)
          result << back_cover_tag
        elsif (front_cover_tag = _cover_tag doc, 'front')
          result << front_cover_tag
        end
      end
      result << %(<orgname>#{doc.attr 'orgname'}</orgname>) if doc.attr? 'orgname'
      unless (docinfo_content = doc.docinfo).empty?
        result << docinfo_content
      end
    end
    result << '</info>'

    if doc.doctype == 'manpage'
      result << '<refmeta>'
      result << %(<refentrytitle>#{doc.attr 'mantitle'}</refentrytitle>) if doc.attr? 'mantitle'
      result << %(<manvolnum>#{doc.attr 'manvolnum'}</manvolnum>) if doc.attr? 'manvolnum'
      result << %(<refmiscinfo class="source">#{doc.attr 'mansource', '&#160;'}</refmiscinfo>)
      result << %(<refmiscinfo class="manual">#{doc.attr 'manmanual', '&#160;'}</refmiscinfo>)
      result << '</refmeta>'
      result << '<refnamediv>'
      result += (doc.attr 'mannames').map {|n| %(<refname>#{n}</refname>) } if doc.attr? 'mannames'
      result << %(<refpurpose>#{doc.attr 'manpurpose'}</refpurpose>) if doc.attr? 'manpurpose'
      result << '</refnamediv>'
    end

    result.join LF
  end

  # FIXME this should be handled through a template mechanism
  def _enclose_content node
    node.content_model == :compound ? node.content : %(<simpara>#{node.content}</simpara>)
  end

  def _title_tag node, optional = true
    !optional || node.title? ? %(<title>#{node.title}</title>\n) : ''
  end

  def _cover_tag doc, face, use_placeholder = false
    if (cover_image = doc.attr %(#{face}-cover-image))
      width_attr = ''
      depth_attr = ''
      if (cover_image.include? ':') && ImageMacroRx =~ cover_image
        cover_image = doc.image_uri $1
        unless $2.empty?
          attrs = (AttributeList.new $2).parse ['alt', 'width', 'height']
          if attrs.key? 'scaledwidth'
            # NOTE scalefit="1" is the default in this case
            width_attr = %( width="#{attrs['scaledwidth']}")
          else
            width_attr = %( contentwidth="#{attrs['width']}") if attrs.key? 'width'
            depth_attr = %( contentdepth="#{attrs['height']}") if attrs.key? 'height'
          end
        end
      end
      %(<cover role="#{face}">
<mediaobject>
<imageobject>
<imagedata fileref="#{cover_image}"#{width_attr}#{depth_attr}/>
</imageobject>
</mediaobject>
</cover>)
    elsif use_placeholder
      %(<cover role="#{face}"/>)
    end
  end

  def _blockquote_tag node, tag_name = nil
    if tag_name
      start_tag, end_tag = %(<#{tag_name}), %(</#{tag_name}>)
    else
      start_tag, end_tag = '<blockquote', '</blockquote>'
    end
    result = [%(#{start_tag}#{_common_attributes node.id, node.role, node.reftext}>)]
    result << %(<title>#{node.title}</title>) if node.title?
    if (node.attr? 'attribution') || (node.attr? 'citetitle')
      result << '<attribution>'
      result << (node.attr 'attribution') if node.attr? 'attribution'
      result << %(<citetitle>#{node.attr 'citetitle'}</citetitle>) if node.attr? 'citetitle'
      result << '</attribution>'
    end
    result << yield
    result << end_tag
    result.join LF
  end

  def _asciimath_available?
    (@asciimath_status ||= _load_asciimath) == :loaded
  end

  def _load_asciimath
    (defined? ::AsciiMath.parse) ? :loaded : (Helpers.require_library 'asciimath', true, :warn).nil? ? :unavailable : :loaded
  end
end
end
