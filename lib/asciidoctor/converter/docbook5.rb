module Asciidoctor
  # A built-in {Converter} implementation that generates DocBook 5 output
  # similar to the docbook45 backend from AsciiDoc Python, but migrated to the
  # DocBook 5 specification.
  class Converter::DocBook5Converter < Converter::BuiltIn
    def document node
      result = []
      root_tag_name = node.doctype
      result << '<?xml version="1.0" encoding="UTF-8"?>'
      if (doctype_line = doctype_declaration root_tag_name)
        result << doctype_line
      end
      result << '<?asciidoc-toc?>' if node.attr? 'toc'
      result << '<?asciidoc-numbered?>' if node.attr? 'sectnums'
      lang_attribute = (node.attr? 'nolang') ? nil : %( lang="#{node.attr 'lang', 'en'}")
      result << %(<#{root_tag_name}#{document_ns_attributes node}#{lang_attribute}>)
      result << (document_info_element node, root_tag_name)
      result << node.content if node.blocks?
      unless (footer_docinfo = node.docinfo :footer).empty?
        result << footer_docinfo
      end
      result << %(</#{root_tag_name}>)

      result * EOL
    end

    alias :embedded :content

    def section node
      tag_name = if node.special
        node.level <= 1 ? node.sectname : 'section'
      else
        node.document.doctype == 'book' && node.level <= 1 ? (node.level == 0 ? 'part' : 'chapter') : 'section'
      end
      %(<#{tag_name}#{common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{node.content}
</#{tag_name}>)
    end

    def admonition node
      %(<#{tag_name = node.attr 'name'}#{common_attributes node.id, node.role, node.reftext}>
#{title_tag node}#{resolve_content node}
</#{tag_name}>)
    end

    alias :audio :skip

    def colist node
      result = []
      result << %(<calloutlist#{common_attributes node.id, node.role, node.reftext}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each do |item|
        result << %(<callout arearefs="#{item.attr 'coids'}">)
        result << %(<para>#{item.text}</para>)
        result << item.content if item.blocks?
        result << '</callout>'
      end
      result << %(</calloutlist>)
      result * EOL
    end

    DLIST_TAGS = {
      'labeled' => {
        :list  => 'variablelist',
        :entry => 'varlistentry',
        :term  => 'term',
        :item  => 'listitem'
      },
      'qanda' => {
        :list  => 'qandaset',
        :entry => 'qandaentry',
        :label => 'question',
        :term  => 'simpara',
        :item  => 'answer'
      },
      'glossary' => {
        :list  => nil,
        :entry => 'glossentry',
        :term  => 'glossterm',
        :item  => 'glossdef'
      }
    }
    DLIST_TAGS.default = DLIST_TAGS['labeled']

    def dlist node
      result = []
      if node.style == 'horizontal'
        result << %(<#{tag_name = node.title? ? 'table' : 'informaltable'}#{common_attributes node.id, node.role, node.reftext} tabstyle="horizontal" frame="none" colsep="0" rowsep="0">
#{title_tag node}<tgroup cols="2">
<colspec colwidth="#{node.attr 'labelwidth', 15}*"/>
<colspec colwidth="#{node.attr 'itemwidth', 85}*"/>
<tbody valign="top">)
        node.items.each do |terms, dd|
          result << %(<row>
<entry>)
          [*terms].each do |dt|
            result << %(<simpara>#{dt.text}</simpara>)
          end
          result << %(</entry>
<entry>)
          unless dd.nil?
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
          result << %(<#{list_tag}#{common_attributes node.id, node.role, node.reftext}>)
          result << %(<title>#{node.title}</title>) if node.title?
        end

        node.items.each do |terms, dd|
          result << %(<#{entry_tag}>)
          result << %(<#{label_tag}>) if label_tag

          [*terms].each do |dt|
            result << %(<#{term_tag}>#{dt.text}</#{term_tag}>)
          end

          result << %(</#{label_tag}>) if label_tag
          result << %(<#{item_tag}>)
          unless dd.nil?
            result << %(<simpara>#{dd.text}</simpara>) if dd.text?
            result << dd.content if dd.blocks?
          end
          result << %(</#{item_tag}>)
          result << %(</#{entry_tag}>)
        end

        result << %(</#{list_tag}>) if list_tag
      end

      result * EOL
    end

    def example node
      if node.title?
        %(<example#{common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{resolve_content node}
</example>)
      else
        %(<informalexample#{common_attributes node.id, node.role, node.reftext}>
#{resolve_content node}
</informalexample>)
      end
    end

    def floating_title node
      %(<bridgehead#{common_attributes node.id, node.role, node.reftext} renderas="sect#{node.level}">#{node.title}</bridgehead>)
    end

    def image node
      width_attribute = (node.attr? 'width') ? %( contentwidth="#{node.attr 'width'}") : nil
      depth_attribute = (node.attr? 'height') ? %( contentdepth="#{node.attr 'height'}") : nil
      swidth_attribute = (node.attr? 'scaledwidth') ? %( width="#{node.attr 'scaledwidth'}" scalefit="1") : nil
      scale_attribute = (node.attr? 'scale') ? %( scale="#{node.attr 'scale'}") : nil
      align_attribute = (node.attr? 'align') ? %( align="#{node.attr 'align'}") : nil

      mediaobject = %(<mediaobject>
<imageobject>
<imagedata fileref="#{node.image_uri(node.attr 'target')}"#{width_attribute}#{depth_attribute}#{swidth_attribute}#{scale_attribute}#{align_attribute}/>
</imageobject>
<textobject><phrase>#{node.attr 'alt'}</phrase></textobject>
</mediaobject>)

      if node.title?
        %(<figure#{common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{mediaobject}
</figure>)
      else
        %(<informalfigure#{common_attributes node.id, node.role, node.reftext}>
#{mediaobject}
</informalfigure>)
      end
    end

    def listing node
      informal = !node.title?
      listing_attributes = (common_attributes node.id, node.role, node.reftext)
      if node.style == 'source' && (node.attr? 'language')
        numbering = (node.attr? 'linenums') ? 'numbered' : 'unnumbered'
        listing_content = %(<programlisting#{informal ? listing_attributes : nil} language="#{node.attr 'language', nil, false}" linenumbering="#{numbering}">#{node.content}</programlisting>)
      else
        listing_content = %(<screen#{informal ? listing_attributes : nil}>#{node.content}</screen>)
      end
      if informal
        listing_content
      else
        %(<formalpara#{listing_attributes}>
<title>#{node.title}</title>
<para>
#{listing_content}
</para>
</formalpara>)
      end
    end

    def literal node
      if node.title?
        %(<formalpara#{common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
<para>
<literallayout class="monospaced">#{node.content}</literallayout>
</para>
</formalpara>)
      else
        %(<literallayout#{common_attributes node.id, node.role, node.reftext} class="monospaced">#{node.content}</literallayout>)
      end
    end

    def stem node
      if (idx = node.subs.index :specialcharacters)
        node.subs.delete :specialcharacters
      end
      equation = node.content
      node.subs.insert idx, :specialcharacters if idx
      if node.style == 'latexmath'
        equation_data = %(<alt><![CDATA[#{equation}]]></alt>
<mediaobject><textobject><phrase></phrase></textobject></mediaobject>)
      # asciimath
      else
        # DocBook backends can't handle AsciiMath, so output raw expression in text object
        equation_data = %(<mediaobject><textobject><phrase><![CDATA[#{equation}]]></phrase></textobject></mediaobject>)
      end
      if node.title?
        %(<equation#{common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{equation_data}
</equation>)
      else
        %(<informalequation#{common_attributes node.id, node.role, node.reftext}>
#{equation_data}
</informalequation>)
      end
    end

    def olist node
      result = []
      num_attribute = node.style ? %( numeration="#{node.style}") : nil
      start_attribute = (node.attr? 'start') ? %( startingnumber="#{node.attr 'start'}") : nil
      result << %(<orderedlist#{common_attributes node.id, node.role, node.reftext}#{num_attribute}#{start_attribute}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each do |item|
        result << '<listitem>'
        result << %(<simpara>#{item.text}</simpara>)
        result << item.content if item.blocks?
        result << '</listitem>'
      end
      result << %(</orderedlist>)
      result * EOL
    end

    def open node
      case node.style
      when 'abstract'
        if node.parent == node.document && node.document.attr?('doctype', 'book')
          warn 'asciidoctor: WARNING: abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
          ''
        else
          %(<abstract>
#{title_tag node}#{resolve_content node}
</abstract>)
        end
      when 'partintro'
        unless node.level == 0 && node.parent.context == :section && node.document.doctype == 'book'
          warn 'asciidoctor: ERROR: partintro block can only be used when doctype is book and it\'s a child of a part section. Excluding block content.'
          ''
        else
          %(<partintro#{common_attributes node.id, node.role, node.reftext}>
#{title_tag node}#{resolve_content node}
</partintro>)
        end
      else
        node.content
      end
    end

    def page_break node
      '<simpara><?asciidoc-pagebreak?></simpara>'
    end

    def paragraph node
      if node.title?
        %(<formalpara#{common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
<para>#{node.content}</para>
</formalpara>)
      else
        %(<simpara#{common_attributes node.id, node.role, node.reftext}>#{node.content}</simpara>)
      end
    end

    def preamble node
      if node.document.doctype == 'book'
        %(<preface#{common_attributes node.id, node.role, node.reftext}>
#{title_tag node, false}#{node.content}
</preface>)
      else
        node.content
      end
    end

    def quote node
      result = []
      result << %(<blockquote#{common_attributes node.id, node.role, node.reftext}>)
      result << %(<title>#{node.title}</title>) if node.title?
      if (node.attr? 'attribution') || (node.attr? 'citetitle')
        result << '<attribution>'
        if node.attr? 'attribution'
          result << (node.attr 'attribution')
        end
        if node.attr? 'citetitle'
          result << %(<citetitle>#{node.attr 'citetitle'}</citetitle>)
        end
        result << '</attribution>'
      end
      result << (resolve_content node)
      result << '</blockquote>'
      result * EOL
    end

    def thematic_break node
      '<simpara><?asciidoc-hr?></simpara>'
    end

    def sidebar node
      %(<sidebar#{common_attributes node.id, node.role, node.reftext}>
#{title_tag node}#{resolve_content node}
</sidebar>)
    end

    TABLE_PI_NAMES = ['dbhtml', 'dbfo', 'dblatex']
    TABLE_SECTIONS = [:head, :foot, :body]

    def table node
      has_body = false
      result = []
      pgwide_attribute = (node.option? 'pgwide') ? ' pgwide="1"' : nil
      result << %(<#{tag_name = node.title? ? 'table' : 'informaltable'}#{common_attributes node.id, node.role, node.reftext}#{pgwide_attribute} frame="#{node.attr 'frame', 'all'}" rowsep="#{['none', 'cols'].include?(node.attr 'grid') ? 0 : 1}" colsep="#{['none', 'rows'].include?(node.attr 'grid') ? 0 : 1}">)
      result << %(<title>#{node.title}</title>) if tag_name == 'table'
      if (width = (node.attr? 'width') ? (node.attr 'width') : nil)
        TABLE_PI_NAMES.each do |pi_name|
          result << %(<?#{pi_name} table-width="#{width}"?>)
        end
      end
      result << %(<tgroup cols="#{node.attr 'colcount'}">)
      node.columns.each do |col|
        result << %(<colspec colname="col_#{col.attr 'colnumber'}" colwidth="#{col.attr(width ? 'colabswidth' : 'colpcwidth')}*"/>)
      end
      TABLE_SECTIONS.select {|tblsec| !node.rows[tblsec].empty? }.each do |tblsec|
        has_body = true if tblsec == :body
        result << %(<t#{tblsec}>)
        node.rows[tblsec].each do |row|
          result << '<row>'
          row.each do |cell|
            halign_attribute = (cell.attr? 'halign') ? %( align="#{cell.attr 'halign'}") : nil
            valign_attribute = (cell.attr? 'valign') ? %( valign="#{cell.attr 'valign'}") : nil
            colspan_attribute = cell.colspan ? %( namest="col_#{colnum = cell.column.attr 'colnumber'}" nameend="col_#{colnum + cell.colspan - 1}") : nil
            rowspan_attribute = cell.rowspan ? %( morerows="#{cell.rowspan - 1}") : nil
            # NOTE <entry> may not have whitespace (e.g., line breaks) as a direct descendant according to DocBook rules
            entry_start = %(<entry#{halign_attribute}#{valign_attribute}#{colspan_attribute}#{rowspan_attribute}>)
            cell_content = if tblsec == :head
              cell.text
            else
              case cell.style
              when :asciidoc
                cell.content
              when :verse
                %(<literallayout>#{cell.text}</literallayout>)
              when :literal
                %(<literallayout class="monospaced">#{cell.text}</literallayout>)
              when :header
                cell.content.map {|text| %(<simpara><emphasis role="strong">#{text}</emphasis></simpara>) }.join
              else
                cell.content.map {|text| %(<simpara>#{text}</simpara>) }.join
              end
            end
            entry_end = (node.document.attr? 'cellbgcolor') ? %(<?dbfo bgcolor="#{node.document.attr 'cellbgcolor'}"?></entry>) : '</entry>'
            result << %(#{entry_start}#{cell_content}#{entry_end})
          end
          result << '</row>'
        end
        result << %(</t#{tblsec}>)
      end
      result << '</tgroup>'
      result << %(</#{tag_name}>)

      warn 'asciidoctor: WARNING: tables must have at least one body row' unless has_body
      result * EOL
    end

    alias :toc :skip

    def ulist node
      result = []
      if node.style == 'bibliography'
        result << %(<bibliodiv#{common_attributes node.id, node.role, node.reftext}>)
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
        mark_attribute = mark_type ? %( mark="#{mark_type}") : nil
        result << %(<itemizedlist#{common_attributes node.id, node.role, node.reftext}#{mark_attribute}>)
        result << %(<title>#{node.title}</title>) if node.title?
        node.items.each do |item|
          text_marker = if checklist && (item.attr? 'checkbox')
            (item.attr? 'checked') ? '&#10003; ' : '&#10063; '
          else
            nil
          end
          result << '<listitem>'
          result << %(<simpara>#{text_marker}#{item.text}</simpara>)
          result << item.content if item.blocks?
          result << '</listitem>'
        end
        result << '</itemizedlist>'
      end

      result * EOL
    end

    def verse node
      result = []
      result << %(<blockquote#{common_attributes node.id, node.role, node.reftext}>)
      result << %(<title>#{node.title}</title>) if node.title?
      if (node.attr? 'attribution') || (node.attr? 'citetitle')
        result << '<attribution>'
        if node.attr? 'attribution'
          result << (node.attr 'attribution')
        end
        if node.attr? 'citetitle'
          result << %(<citetitle>#{node.attr 'citetitle'}</citetitle>)
        end
        result << '</attribution>'
      end
      result << %(<literallayout>#{node.content}</literallayout>)
      result << '</blockquote>'
      result * EOL
    end

    alias :video :skip

    def inline_anchor node
      case node.type
      when :ref
        %(<anchor#{common_attributes node.target, nil, node.text}/>)
      when :xref
        if node.attr? 'path', nil
          linkend = (node.attr 'fragment') || node.target
          (text = node.text) ? %(<link linkend="#{linkend}">#{text}</link>) : %(<xref linkend="#{linkend}"/>)
        else
          %(<link xlink:href="#{target}">#{node.text || (node.attr 'path')}</link>)
        end
      when :link
        %(<link xlink:href="#{node.target}">#{node.text}</link>)
      when :bibref
        %(<anchor#{common_attributes node.target, nil, "[#{node.target}]"}/>[#{node.target}])
      else
        warn %(asciidoctor: WARNING: unknown anchor type: #{node.type.inspect})
      end
    end

    def inline_break node
      %(#{node.text}<?asciidoc-br?>)
    end

    def inline_button node
      %(<guibutton>#{node.text}</guibutton>)
    end

    def inline_callout node
      %(<co#{common_attributes node.id}/>)
    end

    def inline_footnote node
      if node.type == :xref
        %(<footnoteref linkend="#{node.target}"/>)
      else
        %(<footnote#{common_attributes node.id}><simpara>#{node.text}</simpara></footnote>)
      end
    end

    def inline_image node
      width_attribute = (node.attr? 'width') ? %( contentwidth="#{node.attr 'width'}") : nil
      depth_attribute = (node.attr? 'height') ? %( contentdepth="#{node.attr 'height'}") : nil
      %(<inlinemediaobject>
<imageobject>
<imagedata fileref="#{node.type == 'icon' ? (node.icon_uri node.target) : (node.image_uri node.target)}"#{width_attribute}#{depth_attribute}/>
</imageobject>
<textobject><phrase>#{node.attr 'alt'}</phrase></textobject>
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
        result * EOL
      end
    end

    def inline_kbd node
      if (keys = node.attr 'keys').size == 1
        %(<keycap>#{keys[0]}</keycap>)
      else
        key_combo = keys.map {|key| %(<keycap>#{key}</keycap>) }.join
        %(<keycombo>#{key_combo}</keycombo>)
      end
    end

    def inline_menu node
      menu = node.attr 'menu'
      if !(submenus = node.attr 'submenus').empty?
        submenu_path = submenus.map {|submenu| %(<guisubmenu>#{submenu}</guisubmenu> ) }.join.chop
        %(<menuchoice><guimenu>#{menu}</guimenu> #{submenu_path} <guimenuitem>#{node.attr 'menuitem'}</guimenuitem></menuchoice>)
      elsif (menuitem = node.attr 'menuitem')
        %(<menuchoice><guimenu>#{menu}</guimenu> <guimenuitem>#{menuitem}</guimenuitem></menuchoice>)
      else
        %(<guimenu>#{menu}</guimenu>)
      end
    end

    QUOTE_TAGS = {
      :emphasis    => ['<emphasis>',               '</emphasis>',    true],
      :strong      => ['<emphasis role="strong">', '</emphasis>',    true],
      :monospaced  => ['<literal>',                '</literal>',     false],
      :superscript => ['<superscript>',            '</superscript>', false],
      :subscript   => ['<subscript>',              '</subscript>',   false],
      :double      => ['&#8220;',                  '&#8221;',        true],
      :single      => ['&#8216;',                  '&#8217;',        true],
      :mark        => ['<emphasis role="marked">', '</emphasis>',    false]
    }
    QUOTE_TAGS.default = [nil, nil, true]

    def inline_quoted node
      if (type = node.type) == :latexmath
        %(<inlineequation>
<alt><![CDATA[#{node.text}]]></alt>
<inlinemediaobject><textobject><phrase><![CDATA[#{node.text}]]></phrase></textobject></inlinemediaobject>
</inlineequation>)
      else
        open, close, supports_phrase = QUOTE_TAGS[type]
        text = node.text
        if (role = node.role)
          if supports_phrase
            quoted_text = %(#{open}<phrase role="#{role}">#{text}</phrase>#{close})
          else
            quoted_text = %(#{open.chop} role="#{role}">#{text}#{close})
          end
        else
          quoted_text = %(#{open}#{text}#{close})
        end

        node.id ? %(<anchor#{common_attributes node.id, nil, text}/>#{quoted_text}) : quoted_text
      end
    end

    def author_element doc, index = nil
      firstname_key = index ? %(firstname_#{index}) : 'firstname'
      middlename_key = index ? %(middlename_#{index}) : 'middlename'
      lastname_key = index ? %(lastname_#{index}) : 'lastname'
      email_key = index ? %(email_#{index}) : 'email'

      result = []
      result << '<author>'
      result << '<personname>'
      result << %(<firstname>#{doc.attr firstname_key}</firstname>) if doc.attr? firstname_key
      result << %(<othername>#{doc.attr middlename_key}</othername>) if doc.attr? middlename_key
      result << %(<surname>#{doc.attr lastname_key}</surname>) if doc.attr? lastname_key
      result << '</personname>'
      result << %(<email>#{doc.attr email_key}</email>) if doc.attr? email_key
      result << '</author>'

      result * EOL
    end

    def common_attributes id, role = nil, reftext = nil
      res = id ? %( xml:id="#{id}") : ''
      res = %(#{res} role="#{role}") if role
      res = %(#{res} xreflabel="#{reftext}") if reftext
      res
    end

    def doctype_declaration root_tag_name
      nil
    end

    def document_info_element doc, info_tag_prefix, use_info_tag_prefix = false
      info_tag_prefix = '' unless use_info_tag_prefix
      result = []
      result << %(<#{info_tag_prefix}info>)
      result << document_title_tags(doc.doctitle :partition => true, :use_fallback => true) unless doc.notitle
      result << %(<date>#{(doc.attr? 'revdate') ? (doc.attr 'revdate') : (doc.attr 'docdate')}</date>)
      if doc.has_header?
        if doc.attr? 'author'
          if (authorcount = (doc.attr 'authorcount').to_i) < 2
            result << (author_element doc)
            result << %(<authorinitials>#{doc.attr 'authorinitials'}</authorinitials>) if doc.attr? 'authorinitials'
          else
            result << '<authorgroup>'
            authorcount.times do |index|
              result << (author_element doc, index + 1)
            end
            result << '</authorgroup>'
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
        unless (header_docinfo = doc.docinfo :header).empty?
          result << header_docinfo
        end
        result << %(<orgname>#{doc.attr 'orgname'}</orgname>) if doc.attr? 'orgname'
      end
      result << %(</#{info_tag_prefix}info>)

      result * EOL
    end

    def document_ns_attributes doc
      ' xmlns="http://docbook.org/ns/docbook" xmlns:xlink="http://www.w3.org/1999/xlink" version="5.0"'
    end

    def document_title_tags title
      if title.subtitle?
        %(<title>#{title.main}</title>
<subtitle>#{title.subtitle}</subtitle>)
      else
        %(<title>#{title}</title>)
      end
    end

    # FIXME this should be handled through a template mechanism
    def resolve_content node
      node.content_model == :compound ? node.content : %(<simpara>#{node.content}</simpara>)
    end

    def title_tag node, optional = true
      !optional || node.title? ? %(<title>#{node.title}</title>\n) : nil
    end
  end
end
