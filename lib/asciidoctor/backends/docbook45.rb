module Asciidoctor
  class BaseTemplate
    def tag(name, key, dynamic = false)
      type = key.is_a?(Symbol) ? :attr : :var
      key = key.to_s
      if type == :attr
        key_str = dynamic ? %("#{key}") : "'#{key}'"
        # example: <% if attr? 'foo' %><bar><%= attr 'foo' %></bar><% end %>
        %(<% if attr? #{key_str} %><#{name}><%= attr #{key_str} %></#{name}><% end %>)
      else
        # example: <% unless foo.to_s.empty? %><bar><%= foo %></bar><% end %>
        %(<% unless #{key}.to_s.empty? %><#{name}><%= #{key} %></#{name}><% end %>)
      end
    end

    def title_element node, optional = true
      !optional || node.title? ? %(<title>#{node.title}</title>\n) : nil
    end

    def title_tag(optional = true)
      if optional
        %(<%= title? ? "\n<title>\#{title}</title>" : nil %>)
      else
        %(\n<title><%= title %></title>)
      end
    end

    def common_attrs id, role = nil, reftext = nil
      res = ''
      if id
        res = (@backend == 'docbook5' ? %( xml:id="#{id}") : %( id="#{id}"))
      end
      if role
        res = %(#{res} role="#{role}")
      end
      if reftext
        res = %(#{res} xreflabel="#{reftext}")
      end
      res
    end

    def common_attrs_erb
      %q(<%= template.common_attrs(@id, role, reftext) %>)
    end

    def content(node)
      node.blocks? ? node.content : "<simpara>#{node.content}</simpara>"
    end

    def content_erb
      %q(<%= blocks? ? content : "<simpara>#{content}</simpara>" %>)
    end
  end

module DocBook45
class DocumentTemplate < BaseTemplate
  def title_tags(str)
    if str.include?(': ')
      title, _, subtitle = str.rpartition(': ')
      %(<title>#{title}</title>
<subtitle>#{subtitle}</subtitle>)
    else
      %(<title>#{str}</title>)
    end
  end

  def docinfo
    <<-EOF
<% unless notitle %><%= has_header? ? template.title_tags(@header.title) : %(<title>\#{attr 'untitled-label'}</title>) %><% end
if attr? :revdate %>
<date><%= attr :revdate %></date><%
else %>
<date><%= attr :docdate %></date><%
end
if has_header?
  if attr? :author
    if (attr :authorcount).to_i < 2 %>
#{author}
#{tag 'authorinitials', :authorinitials}<%
    else %>
<authorgroup><%
      (1..((attr :authorcount).to_i)).each do |idx| %>
#{author true}<%
      end %>
</authorgroup><%
    end
  end
  if (attr? :revdate) && ((attr? :revnumber) || (attr? :revremark)) %>
<revhistory>
<revision>
#{tag 'revnumber', :revnumber}
#{tag 'date', :revdate}
#{tag 'authorinitials', :authorinitials}
#{tag 'revremark', :revremark}
</revision>
</revhistory><%
  end %>
<%= docinfo %>
#{tag 'orgname', :orgname}<%
end %>
    EOF
  end

  def author indexed = false
    <<-EOF
<author>
#{tag 'firstname', indexed ? :"firstname_\#{idx}" : :firstname, indexed}
#{tag 'othername', indexed ? :"middlename_\#{idx}" : :middlename, indexed}
#{tag 'surname', indexed ? :"lastname_\#{idx}" : :lastname, indexed}
#{tag 'email', indexed ? :"email_\#{idx}" : :email, indexed}
</author>
    EOF
  end

  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE <%= doctype %> PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"><%
if attr? :toc %>
<?asciidoc-toc?><%
end
if attr? :numbered %>
<?asciidoc-numbered?><%
end
if doctype == 'book' %>
<book<% unless attr? :noxmlns %> xmlns="http://docbook.org/ns/docbook"<% end %><% unless attr? :nolang %> lang="<%= attr :lang, 'en' %>"<% end %>>
<bookinfo>
#{docinfo}
</bookinfo>
<%= content %><%= (docinfo_content = docinfo :footer).empty? ? nil : %(
\#{docinfo_content}) %>
</book><%
else %>
<article<% unless attr? :noxmlns %> xmlns="http://docbook.org/ns/docbook"<% end %><% unless attr? :nolang %> lang="<%= attr :lang, 'en' %>"<% end %>>
<articleinfo>
#{docinfo}
</articleinfo>
<%= content %><%= (docinfo_content = docinfo :footer).empty? ? nil : %(
\#{docinfo_content}) %>
</article><%
end %>
    EOF
  end
end

class EmbeddedTemplate < BaseTemplate
  def template
    :content
  end
end

class BlockTocTemplate < BaseTemplate
  include EmptyTemplate
end

class BlockPreambleTemplate < BaseTemplate
  def result node
    if node.document.doctype == 'book'
      %(<preface#{common_attrs node.id, node.role, node.reftext}>
#{title_element node, false}#{node.content}
</preface>)
    else
      node.content
    end
  end

  def template
    :invoke_result
  end
end

class SectionTemplate < BaseTemplate
  def result sec
    if sec.special
      tag = sec.level <= 1 ? sec.sectname : 'section'
    else
      tag = sec.document.doctype == 'book' && sec.level <= 1 ? (sec.level == 0 ? 'part' : 'chapter') : 'section'
    end
    %(<#{tag}#{common_attrs sec.id, sec.role, sec.reftext}>
<title>#{sec.title}</title>
#{sec.content}
</#{tag}>)
  end

  def template
    :invoke_result
  end
end

class BlockFloatingTitleTemplate < BaseTemplate
  def result node
    %(<bridgehead#{common_attrs node.id, node.role, node.reftext} renderas="sect#{node.level}">#{node.title}</bridgehead>)
  end

  def template
    :invoke_result
  end
end

class BlockParagraphTemplate < BaseTemplate
  def result node
    if node.title?
      %(<formalpara#{common_attrs node.id, node.role, node.reftext}>
<title>#{node.title}</title>
<para>#{node.content}</para>
</formalpara>)
    else
      %(<simpara#{common_attrs node.id, node.role, node.reftext}>#{node.content}</simpara>)
    end
  end

  def template
    :invoke_result
  end
end

class BlockAdmonitionTemplate < BaseTemplate
  def result node
    %(<#{tag_name = node.attr 'name'}#{common_attrs node.id, node.role, node.reftext}>
#{title_element node}#{content node}
</#{tag_name}>)
  end

  def template
    :invoke_result
  end
end

class BlockUlistTemplate < BaseTemplate
  def result node
    result_buffer = []
    if node.style == 'bibliography'
      result_buffer << %(<bibliodiv#{common_attrs node.id, node.role, node.reftext}>)
      result_buffer << %(<title>#{node.title}</title>) if node.title?
      node.items.each do |item|
        result_buffer << '<bibliomixed>'
        result_buffer << %(<bibliomisc>#{item.text}</bibliomisc>)
        result_buffer << item.content if item.blocks?
        result_buffer << '</bibliomixed>'
      end
      result_buffer << '</bibliodiv>'
    else
      mark_type = (checklist = node.option? 'checklist') ? 'none' : node.style
      mark_attribute = mark_type ? %( mark="#{mark_type}") : nil
      result_buffer << %(<itemizedlist#{common_attrs node.id, node.role, node.reftext}#{mark_attribute}>)
      result_buffer << %(<title>#{node.title}</title>) if node.title?
      node.items.each do |item|
        text_marker = if checklist && (item.attr? 'checkbox')
          (item.attr? 'checked') ? '&#x25A0; ' : '&#x25A1; '
        else
          nil
        end
        result_buffer << '<listitem>'
        result_buffer << %(<simpara>#{text_marker}#{item.text}</simpara>)
        result_buffer << item.content if item.blocks?
        result_buffer << '</listitem>'
      end
      result_buffer << '</itemizedlist>'
    end

    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockOlistTemplate < BaseTemplate
  def result node
    result_buffer = []
    num_attribute = node.style ? %( numeration="#{node.style}") : nil
    result_buffer << %(<orderedlist#{common_attrs node.id, node.role, node.reftext}#{num_attribute}>)
    result_buffer << %(<title>#{node.title}</title>) if node.title?
    node.items.each do |item|
      result_buffer << '<listitem>'
      result_buffer << %(<simpara>#{item.text}</simpara>)
      result_buffer << item.content if item.blocks?
      result_buffer << '</listitem>'
    end
    result_buffer << %(</orderedlist>)
    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockColistTemplate < BaseTemplate
  def result node
    result_buffer = []
    result_buffer << %(<calloutlist#{common_attrs node.id, node.role, node.reftext}>)
    result_buffer << %(<title>#{node.title}</title>) if node.title?
    node.items.each do |item|
      result_buffer << %(<callout arearefs="#{item.attr 'coids'}">)
      result_buffer << %(<para>#{item.text}</para>)
      result_buffer << item.content if item.blocks?
      result_buffer << '</callout>'
    end
    result_buffer << %(</calloutlist>)
    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockDlistTemplate < BaseTemplate
  LIST_TAGS = {
    'labeled' => {
      :list => 'variablelist',
      :entry => 'varlistentry',
      :term => 'term',
      :item => 'listitem'
    },
    'qanda' => {
      :list => 'qandaset',
      :entry => 'qandaentry',
      :label => 'question',
      :term => 'simpara',
      :item => 'answer'
    },
    'glossary' => {
      :list => nil,
      :entry => 'glossentry',
      :term => 'glossterm',
      :item => 'glossdef'
    }
  }

  LIST_TAGS_DEFAULT = LIST_TAGS['labeled']

  def result node
    result_buffer = []
    if node.style == 'horizontal'
      result_buffer << %(<#{tag_name = node.title? ? 'table' : 'informaltable'}#{common_attrs node.id, node.role, node.reftext} tabstyle="horizontal" frame="none" colsep="0" rowsep="0">
#{title_element node}<tgroup cols="2">
<colspec colwidth="#{node.attr 'labelwidth', 15}*"/>
<colspec colwidth="#{node.attr 'itemwidth', 85}*"/>
<tbody valign="top">)
      node.items.each do |terms, dd|
        result_buffer << %(<row>
<entry>)
        [*terms].each do |dt|
          result_buffer << %(<simpara>#{dt.text}</simpara>) 
        end
        result_buffer << %(</entry>
<entry>)
        unless dd.nil?
          result_buffer << %(<simpara>#{dd.text}</simpara>) if dd.text?
          result_buffer << dd.content if dd.blocks?
        end
        result_buffer << %(</entry>
</row>)
      end
      result_buffer << %(</tbody>
</tgroup>
</#{tag_name}>)
    else
      tags = LIST_TAGS[node.style] || LIST_TAGS_DEFAULT
      list_tag = tags[:list]
      entry_tag = tags[:entry]
      label_tag = tags[:label]
      term_tag = tags[:term]
      item_tag = tags[:item]
      if list_tag
        result_buffer << %(<#{list_tag}#{common_attrs node.id, node.role, node.reftext}>)
        result_buffer << %(<title>#{node.title}</title>) if node.title?
      end

      node.items.each do |terms, dd|
        result_buffer << %(<#{entry_tag}>)
        result_buffer << %(<#{label_tag}>) if label_tag

        [*terms].each do |dt|
          result_buffer << %(<#{term_tag}>#{dt.text}</#{term_tag}>) 
        end

        result_buffer << %(</#{label_tag}>) if label_tag
        result_buffer << %(<#{item_tag}>)
        unless dd.nil?
          result_buffer << %(<simpara>#{dd.text}</simpara>) if dd.text?
          result_buffer << dd.content if dd.blocks?
        end
        result_buffer << %(</#{item_tag}>)
        result_buffer << %(</#{entry_tag}>)
      end

      result_buffer << %(</#{list_tag}>) if list_tag
    end

    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockOpenTemplate < BaseTemplate
  def result node
    open_block(node, node.id, node.style, node.role, node.reftext, node.title? ? node.title : nil)
  end

  def open_block(node, id, style, role, reftext, title)
    case style
    when 'abstract'
      if node.parent == node.document && node.document.attr?('doctype', 'book')
        warn 'asciidoctor: WARNING: abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
        ''
      else
        %(<abstract>#{title && "\n<title>#{title}</title>"}
#{content node}
</abstract>)
      end
    when 'partintro'
      unless node.level == 0 && node.parent.context == :section && node.document.doctype == 'book'
        warn 'asciidoctor: ERROR: partintro block can only be used when doctype is book and it\'s a child of a part section. Excluding block content.'
        ''
      else
        %(<partintro#{common_attrs id, role, reftext}>#{title && "\n<title>#{title}</title>"}
#{content node}
</partintro>)
      end
    else
      node.content
    end
  end

  def template
    :invoke_result
  end
end

class BlockListingTemplate < BaseTemplate
  def result node
    informal = !node.title?
    listing_attributes = (common_attrs node.id, node.role, node.reftext)
    if node.style == 'source' && (node.attr? 'language')
      numbering = (node.attr? 'linenums') ? 'numbered' : 'unnumbered'
      listing_content = %(<programlisting#{informal ? listing_attributes : nil} language="#{node.attr 'language'}" linenumbering="#{numbering}">#{preserve_endlines node.content, node}</programlisting>)
    else
      listing_content = %(<screen#{informal ? listing_attributes : nil}>#{preserve_endlines node.content, node}</screen>)
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

  def template
    :invoke_result
  end
end

class BlockLiteralTemplate < BaseTemplate
  def result node
    if node.title?
      %(<formalpara#{common_attrs node.id, node.role, node.reftext}>
<title>#{node.title}</title>
<para>
<literallayout class="monospaced">#{preserve_endlines node.content, node}</literallayout>
</para>
</formalpara>)
    else
      %(<literallayout#{common_attrs node.id, node.role, node.reftext} class="monospaced">#{preserve_endlines node.content, node}</literallayout>)
    end
  end

  def template
    :invoke_result
  end
end

class BlockExampleTemplate < BaseTemplate
  def result node
    if node.title?
      %(<example#{common_attrs node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{content node}
</example>)
    else
      %(<informalexample#{common_attrs node.id, node.role, node.reftext}>
#{content node}
</informalexample>)
    end
  end

  def template
    :invoke_result
  end
end

class BlockSidebarTemplate < BaseTemplate
  def result node
    %(<sidebar#{common_attrs node.id, node.role, node.reftext}>
#{title_element node}#{content node}
</sidebar>)
  end

  def template
    :invoke_result
  end
end

class BlockQuoteTemplate < BaseTemplate
  def result node
    result_buffer = []
    result_buffer << %(<blockquote#{common_attrs node.id, node.role, node.reftext}>)
    result_buffer << %(<title>#{node.title}</title>) if node.title?
    if (node.attr? 'attribution') || (node.attr? 'citetitle')
      result_buffer << '<attribution>'
      if node.attr? 'attribution'
        result_buffer << (node.attr 'attribution')
      end
      if node.attr? 'citetitle'
        result_buffer << %(<citetitle>#{node.attr 'citetitle'}</citetitle>)
      end
      result_buffer << '</attribution>'
    end
    result_buffer << (content node)
    result_buffer << '</blockquote>'
    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockVerseTemplate < BaseTemplate
  def result node
    result_buffer = []
    result_buffer << %(<blockquote#{common_attrs node.id, node.role, node.reftext}>)
    result_buffer << %(<title>#{node.title}</title>) if node.title?
    if (node.attr? 'attribution') || (node.attr? 'citetitle')
      result_buffer << '<attribution>'
      if node.attr? 'attribution'
        result_buffer << (node.attr 'attribution')
      end
      if node.attr? 'citetitle'
        result_buffer << %(<citetitle>#{node.attr 'citetitle'}</citetitle>)
      end
      result_buffer << '</attribution>'
    end
    result_buffer << %(<literallayout>#{node.content}</literallayout>)
    result_buffer << '</blockquote>'
    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockPassTemplate < BaseTemplate
  def template
    :content
  end
end

class BlockMathTemplate < BaseTemplate
  def result node
    equation = node.content.strip
    if node.style == 'latexmath'
      equation_data = %(<alt><![CDATA[#{equation}]]></alt>
<mediaobject><textobject><phrase></phrase></textobject></mediaobject>)
    else # asciimath
      # DocBook backends can't handle AsciiMath, so output raw expression in text object
      equation_data = %(<mediaobject><textobject><phrase><![CDATA[#{equation}]]></phrase></textobject></mediaobject>)
    end
    if node.title?
      %(<equation#{common_attrs node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{equation_data}
</equation>)
    else
      %(<informalequation#{common_attrs node.id, node.role, node.reftext}>
#{equation_data}
</informalequation>)
    end
  end

  def template
    :invoke_result
  end
end

class BlockTableTemplate < BaseTemplate
  TABLE_PI_NAMES = ['dbhtml', 'dbfo', 'dblatex']
  TABLE_SECTIONS = [:head, :foot, :body]

  def result node
    result_buffer = []
    pgwide_attribute = (node.option? 'pgwide') ? ' pgwide="1"' : nil
    result_buffer << %(<#{tag_name = node.title? ? 'table' : 'informaltable'}#{common_attrs node.id, node.role, node.reftext}#{pgwide_attribute} frame="#{node.attr 'frame', 'all'}" rowsep="#{['none', 'cols'].include?(node.attr 'grid') ? 0 : 1}" colsep="#{['none', 'rows'].include?(node.attr 'grid') ? 0 : 1}">)
    result_buffer << %(<title>#{node.title}</title>) if tag_name == 'table'
    if (width = (node.attr? 'width') ? (node.attr 'width') : nil)
      TABLE_PI_NAMES.each do |pi_name|
        result_buffer << %(<?#{pi_name} table-width="#{width}"?>)
      end
    end
    result_buffer << %(<tgroup cols="#{node.attr 'colcount'}">)
    node.columns.each do |col|
      result_buffer << %(<colspec colname="col_#{col.attr 'colnumber'}" colwidth="#{col.attr(width ? 'colabswidth' : 'colpcwidth')}*"/>)
    end
    TABLE_SECTIONS.select {|tblsec| !node.rows[tblsec].empty? }.each do |tblsec|
      result_buffer << %(<t#{tblsec}>)
      node.rows[tblsec].each do |row|
        result_buffer << '<row>'
        row.each do |cell|
          halign_attribute = (cell.attr? 'halign') ? %( align="#{cell.attr 'halign'}") : nil
          valign_attribute = (cell.attr? 'valign') ? %( valign="#{cell.attr 'valign'}") : nil
          colspan_attribute = cell.colspan ? %( namest="col_#{colnum = cell.column.attr 'colnumber'}" nameend="col_#{colnum + cell.colspan - 1}") : nil
          rowspan_attribute = cell.rowspan ? %( morerows="#{cell.rowspan - 1}") : nil
          entry_start = %(<entry#{halign_attribute}#{valign_attribute}#{colspan_attribute}#{rowspan_attribute}>)
          cell_content = if tblsec == :head
            %(<simpara>#{cell.text}</simpara>)
          else
            case cell.style
            when :asciidoc
              cell.content
            when :verse
              %(<literallayout>#{preserve_endlines cell.text, node}</literallayout>)
            when :literal
              %(<literallayout class="monospaced">#{preserve_endlines cell.text, node}</literallayout>)
            when :header
              cell.content.map {|text| %(<simpara><emphasis role="strong">#{text}</emphasis></simpara>) }.join
            else
              cell.content.map {|text| %(<simpara>#{text}</simpara>) }.join
            end
          end
          entry_end = (node.document.attr? 'cellbgcolor') ? %(<?dbfo bgcolor="#{node.document.attr 'cellbgcolor'}"?></entry>) : '</entry>'
          result_buffer << %(#{entry_start}#{cell_content}#{entry_end})
        end
        result_buffer << '</row>'
      end
      result_buffer << %(</t#{tblsec}>)
    end
    result_buffer << '</tgroup>'
    result_buffer << %(</#{tag_name}>)

    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockImageTemplate < BaseTemplate
  def result node
    width_attribute = (node.attr? 'width') ? %( contentwidth="#{node.attr 'width'}") : nil
    depth_attribute = (node.attr? 'height') ? %( contentdepth="#{node.attr 'height'}") : nil
    swidth_attribute = (node.attr? 'scaledwidth') ? %( width="#{node.attr 'scaledwidth'}" scalefit="1") : nil
    scale_attribute = (node.attr? 'scale') ? %( scale="#{node.attr 'scale'}") : nil
    align_attribute = (node.attr? 'align') ? %( align="#{node.attr 'align'}") : nil

    %(<figure#{common_attrs node.id, node.role, node.reftext}>
#{title_element node}<mediaobject>
<imageobject>
<imagedata fileref="#{node.image_uri(node.attr 'target')}"#{width_attribute}#{depth_attribute}#{swidth_attribute}#{scale_attribute}#{align_attribute}/>
</imageobject>
<textobject><phrase>#{node.attr 'alt'}</phrase></textobject>
</mediaobject>
</figure>)
  end

  def template
    :invoke_result
  end
end

class BlockAudioTemplate < BaseTemplate
  include EmptyTemplate
end

class BlockVideoTemplate < BaseTemplate
  include EmptyTemplate
end

class BlockRulerTemplate < BaseTemplate
  def result node
    %(<simpara><?asciidoc-hr?></simpara>)
  end

  def template
    :invoke_result
  end
end

class BlockPageBreakTemplate < BaseTemplate
  def result node
    %(<simpara><?asciidoc-pagebreak?></simpara>)
  end

  def template
    :invoke_result
  end
end

class InlineBreakTemplate < BaseTemplate
  def result node
    %(#{@text}<?asciidoc-br?>)
  end

  def template
    :invoke_result
  end
end

class InlineQuotedTemplate < BaseTemplate
  NO_TAGS = [nil, nil]

  QUOTED_TAGS = {
    :emphasis => ['<emphasis>', '</emphasis>'],
    :strong => ['<emphasis role="strong">', '</emphasis>'],
    :monospaced => ['<literal>', '</literal>'],
    :superscript => ['<superscript>', '</superscript>'],
    :subscript => ['<subscript>', '</subscript>'],
    :double => ['&#8220;', '&#8221;'],
    :single => ['&#8216;', '&#8217;']
  }

  def quote_text(text, type, id, role)
    if type == :latexmath
      %(<inlineequation>
<alt><![CDATA[#{text}]]></alt>
<inlinemediaobject><textobject><phrase><![CDATA[#{text}]]></phrase></textobject></inlinemediaobject>
</inlineequation>)
    else
      start_tag, end_tag = QUOTED_TAGS[type] || NO_TAGS
      anchor = id.nil? ? nil : %(<anchor#{common_attrs id, nil, text}/>)
      if role
        quoted_text = "#{start_tag}<phrase role=\"#{role}\">#{text}</phrase>#{end_tag}"
      elsif start_tag.nil?
        quoted_text = text
      else
        quoted_text = %(#{start_tag}#{text}#{end_tag})
      end

      anchor.nil? ? quoted_text : %(#{anchor}#{quoted_text})
    end
  end

  def result node
    quote_text(node.text, node.type, node.id, node.role)
  end

  def template
    :invoke_result
  end
end

class InlineButtonTemplate < BaseTemplate
  def result node
    %(<guibutton>#{node.text}</guibutton>)
  end

  def template
    :invoke_result
  end
end

class InlineKbdTemplate < BaseTemplate
  def result node
    keys = node.attr 'keys'
    if keys.size == 1
      %(<keycap>#{keys.first}</keycap>)
    else
      key_combo = keys.map{|key| %(<keycap>#{key}</keycap>) }.join
      %(<keycombo>#{key_combo}</keycombo>)
    end
  end

  def template
    :invoke_result
  end
end

class InlineMenuTemplate < BaseTemplate
  def menu(menu, submenus, menuitem)
    if !submenus.empty?
      submenu_path = submenus.map{|submenu| %(<guisubmenu>#{submenu}</guisubmenu> ) }.join.chop
      %(<menuchoice><guimenu>#{menu}</guimenu> #{submenu_path} <guimenuitem>#{menuitem}</guimenuitem></menuchoice>)
    elsif !menuitem.nil?
      %(<menuchoice><guimenu>#{menu}</guimenu> <guimenuitem>#{menuitem}</guimenuitem></menuchoice>)
    else
      %(<guimenu>#{menu}</guimenu>)
    end
  end

  def result node
    menu(node.attr('menu'), node.attr('submenus'), node.attr('menuitem'))
  end

  def template
    :invoke_result
  end
end

class InlineAnchorTemplate < BaseTemplate
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

  def result node
    anchor(node.target, node.text, node.type, node)
  end

  def template
    :invoke_result
  end
end

class InlineImageTemplate < BaseTemplate
  def result node
    width_attribute = (node.attr? 'width') ? %( contentwidth="#{node.attr 'width'}") : nil
    depth_attribute = (node.attr? 'height') ? %( contentdepth="#{node.attr 'height'}") : nil
    %(<inlinemediaobject>
<imageobject>
<imagedata fileref="#{node.type == 'icon' ? (node.icon_uri node.target) : (node.image_uri node.target)}"#{width_attribute}#{depth_attribute}/>
</imageobject>
<textobject><phrase>#{node.attr 'alt'}</phrase></textobject>
</inlinemediaobject>)
  end

  def template
    :invoke_result
  end
end

class InlineFootnoteTemplate < BaseTemplate
  def result node
    if node.type == :xref
      %(<footnoteref linkend="#{node.target}"/>)
    else
      %(<footnote#{common_attrs node.id}><simpara>#{node.text}</simpara></footnote>)
    end
  end

  def template
    :invoke_result
  end
end

class InlineCalloutTemplate < BaseTemplate
  def result node
    %(<co#{common_attrs node.id, nil, nil}/>)
  end

  def template
    :invoke_result
  end
end

class InlineIndextermTemplate < BaseTemplate
  def result node
    if node.type == :visible
      %(<indexterm><primary>#{node.text}</primary></indexterm>#{node.text})
    else
      terms = node.attr 'terms'
      result_buffer = []
      if (numterms = terms.size) > 2
        result_buffer << %(<indexterm>
<primary>#{terms[0]}</primary><secondary>#{terms[1]}</secondary><tertiary>#{terms[2]}</tertiary>
</indexterm>)
      end
      if numterms > 1
        result_buffer << %(<indexterm>
<primary>#{terms[-2]}</primary><secondary>#{terms[-1]}</secondary>
</indexterm>)
      end
      result_buffer << %(<indexterm>
<primary>#{terms[-1]}</primary>
</indexterm>)
      result_buffer * EOL
    end
  end

  def template
    :invoke_result
  end
end

end # module DocBook45
end # module Asciidoctor
