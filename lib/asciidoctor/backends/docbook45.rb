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

    def title_tag(optional = true)
      if optional
        %(<%= title? ? "\n<title>\#{title}</title>" : nil %>)
      else
        %(\n<title><%= title %></title>)
      end
    end

    def common_attrs(id, role, reftext)
      %(#{id && " #{@backend == 'docbook5' ? 'xml:id' : 'id'}=\"#{id}\""}#{role && " role=\"#{role}\""}#{reftext && " xreflabel=\"#{reftext}\""})
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
  if (attr? :revnumber) || (attr? :revremark) %>
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
  def result(node)
    ''
  end

  def template
    :invoke_result
  end
end

class BlockPreambleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%
if @document.doctype == 'book' %><preface#{common_attrs_erb}>#{title_tag false}
<%= content %>
</preface><%
else %>
<%= content %><%
end %>
    EOF
  end
end

class SectionTemplate < BaseTemplate
  def result(sec)
    if sec.special
      tag = sec.level <= 1 ? sec.sectname : 'section'
    else
      tag = sec.document.doctype == 'book' && sec.level <= 1 ? (sec.level == 0 ? 'part' : 'chapter') : 'section'
    end
    %(<#{tag}#{common_attrs(sec.id, sec.role, sec.reftext)}>
#{sec.title? ? "<title>#{sec.title}</title>" : nil}
#{sec.content}
</#{tag}>)
  end

  def template
    :invoke_result
  end
end

class BlockFloatingTitleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><bridgehead#{common_attrs_erb} renderas="sect<%= @level %>"><%= title %></bridgehead>
    EOS
  end
end

class BlockParagraphTemplate < BaseTemplate
  def paragraph(id, style, role, reftext, title, content)
    if !title.nil?
      %(<formalpara#{common_attrs(id, role, reftext)}>
<title>#{title}</title>
<para>#{content}</para>
</formalpara>)
    else
      %(<simpara#{common_attrs(id, role, reftext)}>#{content}</simpara>)
    end
  end

  def result(node)
    paragraph(node.id, node.style, node.role, node.reftext, (node.title? ? node.title : nil), node.content)
  end

  def template
    :invoke_result
  end
end

class BlockAdmonitionTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><<%= attr :name %>#{common_attrs_erb}>#{title_tag}
#{content_erb}
</<%= attr :name %>>
    EOF
  end
end

class BlockUlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%
if @style == 'bibliography'
%><bibliodiv#{common_attrs_erb}>#{title_tag}<%
  items.each do |li| %>
<bibliomixed>
<bibliomisc><%= li.text %></bibliomisc><%
    if li.blocks? %>
<%= li.content %><%
    end %>
</bibliomixed><%
  end %>
</bibliodiv><%
else
checklist = (option? 'checklist')
mark = checklist ? 'none' : @style
%><itemizedlist#{common_attrs_erb}<%= mark ? %( mark="\#{mark}") : nil %>>#{title_tag}<%
  items.each do |li| %>
<listitem>
<simpara><%= checklist && (li.attr? 'checkbox') ? ((li.attr? 'checked') ? '&#x25A0; ' : '&#x25A1; ') : nil %><%= li.text %></simpara><%
    if li.blocks? %>
<%= li.content %><%
    end %>
</listitem><%
  end %>
</itemizedlist><%
end %>
    EOF
  end
end

class BlockOlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><orderedlist#{common_attrs_erb}#{attribute('numeration', '@style')}>#{title_tag}<%
  items.each do |li| %>
<listitem>
<simpara><%= li.text %></simpara><%
    if li.blocks? %>
<%= li.content %><%
    end %>
</listitem><%
end %>
</orderedlist>
    EOF
  end
end

class BlockColistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><calloutlist#{common_attrs_erb}>#{title_tag}
  <% items.each do |li| %>
  <callout arearefs="<%= li.attr :coids %>">
    <para><%= li.text %></para>
    <% if li.blocks? %>
<%= li.content %>
    <% end %>
  </callout>
  <% end %>
</calloutlist>
    EOF
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

  def template
    # TODO may want to refactor ListItem content to hold multiple terms
    # that change would drastically simplify this template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%
if @style == 'horizontal'
%><<%= (tag = title? ? 'table' : 'informaltable') %>#{common_attrs_erb} tabstyle="horizontal" frame="none" colsep="0" rowsep="0">#{title_tag}
<tgroup cols="2">
<colspec colwidth="<%= attr :labelwidth, 15 %>*"/>
<colspec colwidth="<%= attr :labelwidth, 85 %>*"/>
<tbody valign="top"><%
  items.each do |terms, dd| %>
<row>
<entry><%
    [*terms].each do |dt| %>
<simpara><%= dt.text %></simpara><%
    end %>
</entry>
<entry><%
    unless dd.nil?
      if dd.text? %>
<simpara><%= dd.text %></simpara><%
      end
      if dd.blocks? %>
<%= dd.content %><%
      end
    end %>
</entry>
</row><%
  end %>
</tbody>
</tgroup>
</<%= tag %>><%
else
  tags = (template.class::LIST_TAGS[@style] || template.class::LIST_TAGS['labeled'])
  if tags[:list]
%><<%= tags[:list] %>#{common_attrs_erb}>#{title_tag}<%
  end
  items.each do |terms, dd| %>
<<%= tags[:entry] %>><%
    if tags.has_key? :label %>
<<%= tags[:label] %>><%
    end
    [*terms].each do |dt| %>
<<%= tags[:term] %>><%= dt.text %></<%= tags[:term] %>><%
    end
    if tags.has_key? :label %>
</<%= tags[:label] %>><%
    end %>
<<%= tags[:item] %>><%
    unless dd.nil?
      if dd.text? %>
<simpara><%= dd.text %></simpara><%
      end
      if dd.blocks? %>
<%= dd.content %><%
      end
    end %>
</<%= tags[:item] %>>
</<%= tags[:entry] %>><%
  end
  if tags[:list] %>
</<%= tags[:list] %>><%
  end
end %>
    EOF
  end
end

class BlockOpenTemplate < BaseTemplate
  def result(node)
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
      unless node.document.attr?('doctype', 'book') && node.parent.is_a?(Asciidoctor::Section) && node.level == 0
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
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%
if !title?
  if @style == 'source' && (attr? 'language')
%><programlisting#{common_attrs_erb}#{attribute('language', :language)} linenumbering="<%= (attr? :linenums) ? 'numbered' : 'unnumbered' %>"><%= template.preserve_endlines(content, self) %></programlisting><%
  else
%><screen#{common_attrs_erb}><%= template.preserve_endlines(content, self) %></screen><%
  end
else
%><formalpara#{common_attrs_erb}>#{title_tag false}
<para><%
  if @style == 'source' && (attr? 'language') %>
<programlisting language="<%= attr 'language' %>" linenumbering="<%= (attr? :linenums) ? 'numbered' : 'unnumbered' %>"><%= template.preserve_endlines(content, self) %></programlisting><%
  else %>
<screen><%= template.preserve_endlines(content, self) %></screen><%
  end %>
</para>
</formalpara><%
end %>
    EOF
  end
end

class BlockLiteralTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><% if !title? %>
<literallayout#{common_attrs_erb} class="monospaced"><%= template.preserve_endlines(content, self) %></literallayout>
<% else %>
<formalpara#{common_attrs_erb}>#{title_tag false}
  <para>
    <literallayout class="monospaced"><%= template.preserve_endlines(content, self) %></literallayout>
  </para>
</formalpara>
<% end %>
    EOF
  end
end

class BlockExampleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><<%= (tag_name = title? ? 'example' : 'informalexample') %>#{common_attrs_erb}>#{title_tag}
#{content_erb}
</<%= tag_name %>>
    EOF
  end
end

class BlockSidebarTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><sidebar#{common_attrs_erb}>#{title_tag}
#{content_erb}
</sidebar>
    EOF
  end
end

class BlockQuoteTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><blockquote#{common_attrs_erb}>#{title_tag}
  <% if (attr? :attribution) || (attr? :citetitle) %>
  <attribution>
    <% if attr? :attribution %>
    <%= (attr :attribution) %>
    <% end %>
    #{tag 'citetitle', :citetitle}
  </attribution>
  <% end %>
#{content_erb}
</blockquote>
    EOF
  end
end

class BlockVerseTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><blockquote#{common_attrs_erb}>#{title_tag}
  <% if (attr? :attribution) || (attr? :citetitle) %>
  <attribution>
    <% if attr? :attribution %>
    <%= (attr :attribution) %>
    <% end %>
    #{tag 'citetitle', :citetitle}
  </attribution>
  <% end %>
  <literallayout><%= content %></literallayout>
</blockquote>
    EOF
  end
end

class BlockPassTemplate < BaseTemplate
  def template
    :content
  end
end

class BlockTableTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><<%= (tag_name = title? ? 'table' : 'informaltable') %>#{common_attrs_erb} frame="<%= attr :frame, 'all'%>"
    rowsep="<%= ['none', 'cols'].include?(attr :grid) ? 0 : 1 %>" colsep="<%= ['none', 'rows'].include?(attr :grid) ? 0 : 1 %>">#{title_tag}
  <% if attr? :width %>
  <?dbhtml table-width="<%= attr :width %>"?>
  <?dbfo table-width="<%= attr :width %>"?>
  <?dblatex table-width="<%= attr :width %>"?>
  <% end %>
  <tgroup cols="<%= attr :colcount %>">
    <% @columns.each do |col| %>
    <colspec colname="col_<%= col.attr :colnumber %>" colwidth="<%= col.attr((attr? :width) ? :colabswidth : :colpcwidth) %>*"/>
    <% end %>
    <% [:head, :foot, :body].select {|tblsec| !rows[tblsec].empty? }.each do |tblsec| %>
    <t<%= tblsec %>>
      <% @rows[tblsec].each do |row| %>
      <row>
        <% row.each do |cell| %>
        <entry#{attribute('align', 'cell.attr :halign')}#{attribute('valign', 'cell.attr :valign')}<%
        if cell.colspan %> namest="col_<%= cell.column.attr :colnumber %>" nameend="col_<%= (cell.column.attr :colnumber) + cell.colspan - 1 %>"<%
        end %><% if cell.rowspan %> morerows="<%= cell.rowspan - 1 %>"<% end %>><%
        cell_content = ''
        if tblsec == :head %><% cell_content = cell.text %><%
        else %><%
        case cell.style
          when :asciidoc %><% cell_content = cell.content %><%
          when :verse %><% cell_content = %(<literallayout>\#{template.preserve_endlines(cell.text, self)}</literallayout>) %><%
          when :literal %><% cell_content = %(<literallayout class="monospaced">\#{template.preserve_endlines(cell.text, self)}</literallayout>) %><%
          when :header %><% cell.content.each do |text| %><% cell_content = %(\#{cell_content\}<simpara><emphasis role="strong">\#{text}</emphasis></simpara>) %><% end %><%
          else %><% cell.content.each do |text| %><% cell_content = %(\#{cell_content}<simpara>\#{text}</simpara>) %><% end %><%
        %><% end %><% end %><%= (@document.attr? 'cellbgcolor') ? %(<?dbfo bgcolor="\#{@document.attr 'cellbgcolor'}"?>) : nil %><%= cell_content %></entry>
        <% end %>
      </row>
      <% end %>
    </t<%= tblsec %>>
    <% end %>
  </tgroup>
</<%= tag_name %>>
    EOS
  end
end

class BlockImageTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%#encoding:UTF-8%><figure#{common_attrs_erb}>#{title_tag}
  <mediaobject>
    <imageobject>
      <imagedata fileref="<%= image_uri(attr :target) %>"#{attribute('contentwidth', :width)}#{attribute('contentdepth', :height)}/>
    </imageobject>
    <textobject><phrase><%= attr :alt %></phrase></textobject>
  </mediaobject>
</figure>
    EOF
  end
end

class BlockAudioTemplate < BaseTemplate
  include EmptyTemplate
end

class BlockVideoTemplate < BaseTemplate
  include EmptyTemplate
end

class BlockRulerTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><simpara><?asciidoc-hr?></simpara>
    EOF
  end
end

class BlockPageBreakTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><simpara><?asciidoc-pagebreak?></simpara>
    EOF
  end
end

class InlineBreakTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%= @text %><?asciidoc-br?>
    EOF
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
    start_tag, end_tag = QUOTED_TAGS[type] || NO_TAGS
    anchor = id.nil? ? nil : %(<anchor#{common_attrs id, nil, text}/>)
    if role
      quoted_text = "#{start_tag}<phrase role=\"#{role}\">#{text}</phrase>#{end_tag}"
    elsif start_tag.nil?
      quoted_text = text
    else
      quoted_text = "#{start_tag}#{text}#{end_tag}"
    end

    anchor.nil? ? quoted_text : %(#{anchor}#{quoted_text})
  end

  def result(node)
    quote_text(node.text, node.type, node.id, node.role)
  end

  def template
    :invoke_result
  end
end

class InlineButtonTemplate < BaseTemplate
  def result(node)
    %(<guibutton>#{node.text}</guibutton>)
  end

  def template
    :invoke_result
  end
end

class InlineKbdTemplate < BaseTemplate
  def result(node)
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

  def result(node)
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

  def result(node)
    anchor(node.target, node.text, node.type, node)
  end

  def template
    :invoke_result
  end
end

class InlineImageTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><inlinemediaobject>
  <imageobject>
    <imagedata fileref="<%= @type == 'icon' ? icon_uri(@target) : image_uri(@target) %>"#{attribute('width', :width)}#{attribute('depth', :height)}/>
  </imageobject>
  <textobject><phrase><%= attr :alt %></phrase></textobject>
</inlinemediaobject>
    EOF
  end
end

class InlineFootnoteTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><%
if @type == :xref
%><footnoteref linkend="<%= @target %>"/><%
else
%><footnote<%= template.common_attrs(@id, nil, nil) %>><simpara><%= @text %></simpara></footnote><%
end %>
    EOS
  end
end

class InlineCalloutTemplate < BaseTemplate
  def result(node)
    %(<co#{common_attrs node.id, nil, nil}/>)
  end

  def template
    :invoke_result
  end
end

class InlineIndextermTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><% if @type == :visible %><indexterm><primary><%= @text %></primary></indexterm><%= @text %><%
else %><% terms = (attr :terms); numterms = terms.size %><%
if numterms > 2 %><indexterm>
  <primary><%= terms[0] %></primary><secondary><%= terms[1] %></secondary><tertiary><%= terms[2] %></tertiary>
</indexterm>
<% end %><%
if numterms > 1 %><indexterm>
  <primary><%= terms[-2] %></primary><secondary><%= terms[-1] %></secondary>
</indexterm>
<% end %><indexterm>
  <primary><%= terms[-1] %></primary>
</indexterm><% end %>
    EOS
  end
end

end # module DocBook45
end # module Asciidoctor
