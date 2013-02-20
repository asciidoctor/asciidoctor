module Asciidoctor
  class BaseTemplate
    def tag(name, key)
      type = key.is_a?(Symbol) ? :attr : :var
      key = key.to_s
      if type == :attr
        # example: <% if attr? 'foo' %><bar><%= attr 'foo' %></bar><% end %>
        %(<% if attr? '#{key}' %><#{name}><%= attr '#{key}' %></#{name}><% end %>)
      else
        # example: <% unless foo.to_s.empty? %><bar><%= foo %></bar><% end %>
        %(<% unless #{key}.to_s.empty? %><#{name}><%= #{key} %></#{name}><% end %>)
      end
    end

    def title_tag(optional = true)
      if optional
        %q{<%= title? ? "<title>#{title}</title>" : '' %>}
      else
        %q{<title><%= title %></title>}
      end
    end

    def common_attrs(id, role, reftext)
      %(#{id && " id=\"#{id}\""}#{role && " role=\"#{role}\""}#{reftext && " xreflabel=\"#{reftext}\""})
    end

    def common_attrs_erb
      %q{<%= template.common_attrs(@id, (attr 'role'), (attr 'reftext')) %>}
    end
  end

module DocBook45
class DocumentTemplate < BaseTemplate
  def docinfo
    <<-EOF
    <% if has_header? && !notitle %>
    #{tag 'title', '@header.title'}
    <% end %>
    <% if attr? :revdate %>
    <date><%= attr :revdate %></date>
    <% else %>
    <date><%= attr :docdate %></date>
    <% end %>
    <% if has_header? %>
    <% if attr? :author %>
    <author>
      #{tag 'firstname', :firstname}
      #{tag 'othername', :middlename}
      #{tag 'surname', :lastname}
      #{tag 'email', :email}
    </author>
    #{tag 'authorinitials', :authorinitials}
    <% end %>
    <% if (attr? :revnumber) || (attr? :revremark) %>
    <revhistory>
      #{tag 'revision', :revnumber}
      #{tag 'date', :revdate}
      #{tag 'authorinitials', :authorinitials}
      #{tag 'revremark', :revremark}
    </revhistory>
    <% end %>
    <% end %>
    EOF
  end

  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE <%= doctype %> PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">
<% if attr? :toc %><?asciidoc-toc?><% end %>
<% if attr? :numbered %><?asciidoc-numbered?><% end %>
<% if doctype == 'book' %>
<book<% unless attr? :nolang %> lang="<%= attr :lang, 'en' %>"<% end %>>
  <bookinfo>
#{docinfo}
  </bookinfo>
<%= content %>
</book>
<% else %>
<article<% unless attr? :nolang %> lang="<%= attr :lang, 'en' %>"<% end %>>
  <articleinfo>
#{docinfo}
  </articleinfo>
<%= content %>
</article>
<% end %>
    EOF
  end
end

class EmbeddedTemplate < BaseTemplate
  def template
    :content
  end
end

class BlockPreambleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><% if @document.doctype == 'book' %>
<preface#{common_attrs_erb}>
  <title><%= title %></title>
<%= content %>
</preface>
<% else %>
<%= content %>
<% end %>
    EOF
  end
end

class SectionTemplate < BaseTemplate
  def section(sec)
    if sec.special
      tag = sec.level <= 1 ? sec.sectname : 'section'
    else
      tag = sec.document.doctype == 'book' && sec.level <= 1 ? 'chapter' : 'section'
    end
    %(<#{tag}#{common_attrs(sec.id, (sec.attr 'role'), (sec.attr 'reftext'))}>
  #{sec.title? ? "<title>#{sec.title}</title>" : nil}
  #{sec.content}
</#{tag}>)
  end

  def template
    # hot piece of code, optimized for speed
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%= template.section(self) %>
    EOF
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

  def paragraph(id, role, reftext, title, content)
    if title
      %(<formalpara#{common_attrs(id, role, reftext)}>
  <title>#{title}</title>
  <para>#{content}</para>
</formalpara>)
    else
      %(<simpara#{common_attrs(id, role, reftext)}>#{content}</simpara>)
    end
  end

  def template
    # very hot piece of code, optimized for speed
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%= template.paragraph(@id, (attr 'role'), (attr 'reftext'), title? ? title : nil, content) %>
    EOF
  end
end

class BlockAdmonitionTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><<%= attr :name %>#{common_attrs_erb}>
  #{title_tag}
  <% if blocks? %>
<%= content %>
  <% else %>
  <simpara><%= content.chomp %></simpara>
  <% end %>
</<%= attr :name %>>
    EOF
  end
end

class BlockUlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><% if attr? :style, 'bibliography' %>
<bibliodiv#{common_attrs_erb}>
  #{title_tag}
  <% content.each do |li| %>
    <bibliomixed>
      <bibliomisc><%= li.text %></bibliomisc>
      <% if li.blocks? %>
<%= li.content %>
      <% end %>
    </bibliomixed>
  <% end %>
</bibliodiv>
<% else %>
<itemizedlist#{common_attrs_erb}>
  #{title_tag}
  <% content.each do |li| %>
    <listitem>
      <simpara><%= li.text %></simpara>
      <% if li.blocks? %>
<%= li.content %>
      <% end %>
    </listitem>
  <% end %>
</itemizedlist>
<% end %>
    EOF
  end
end

class BlockOlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><orderedlist#{common_attrs_erb}#{attribute('numeration', :style)}>
  #{title_tag}
  <% content.each do |li| %>
    <listitem>
      <simpara><%= li.text %></simpara>
      <% if li.blocks? %>
<%= li.content %>
      <% end %>
    </listitem>
  <% end %>
</orderedlist>
    EOF
  end
end

class BlockColistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><calloutlist#{common_attrs_erb}>
  #{title_tag}
  <% content.each do |li| %>
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
      :term => 'question',
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
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><% tags = (template.class::LIST_TAGS[attr :style] || template.class::LIST_TAGS['labeled']) %>
<% if tags[:list] %><<%= tags[:list] %>#{common_attrs_erb}><% end %>
  #{title_tag}
  <% content.each do |dt, dd| %>
  <<%= tags[:entry] %>>
    <<%= tags[:term] %>>
      <%= dt.text %>
    </<%= tags[:term] %>>
    <% unless dd.nil? %>
    <<%= tags[:item] %>>
      <% if dd.text? %>
      <simpara><%= dd.text %></simpara>
      <% end %>
      <% if dd.blocks? %>
<%= dd.content %>
      <% end %>
    </<%= tags[:item] %>>
    <% end %>
  </<%= tags[:entry] %>>
  <% end %>
<% if tags[:list] %></<%= tags[:list] %>><% end %>
    EOF
  end
end

class BlockOpenTemplate < BaseTemplate
  def template
    :content
  end
end

class BlockListingTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><% if !title? %>
<% if attr? :style, 'source' %>
<programlisting#{common_attrs_erb}#{attribute('language', :language)} linenumbering="<%= (attr? :linenums) ? 'numbered' : 'unnumbered' %>"><%= template.preserve_endlines(content, self) %></programlisting>
<% else %>
<screen#{common_attrs_erb}><%= template.preserve_endlines(content, self) %></screen>
<% end %>
<% else %>
<formalpara#{common_attrs_erb}>
  #{title_tag false}
  <para>
    <% if attr :style, 'source' %>
    <programlisting language="<%= attr :language %>" linenumbering="<%= (attr? :linenums) ? 'numbered' : 'unnumbered' %>"><%= template.preserve_endlines(content, self) %></programlisting>
    <% else %>
    <screen><%= template.preserve_endlines(content, self) %></screen>
    <% end %>
  </para>
</formalpara>
<% end %>
    EOF
  end
end

class BlockLiteralTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><% if !title? %>
<literallayout#{common_attrs_erb} class="monospaced"><%= template.preserve_endlines(content, self) %></literallayout>
<% else %>
<formalpara#{common_attrs_erb}>
  #{title_tag false}
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
<%#encoding:UTF-8%><example#{common_attrs_erb}>
  #{title_tag}
<%= content %>
</example>
    EOF
  end
end

class BlockSidebarTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><sidebar#{common_attrs_erb}>
  #{title_tag}
<%= content %>
</sidebar>
    EOF
  end
end

class BlockQuoteTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><blockquote#{common_attrs_erb}>
  #{title_tag}
  <% if (attr? :attribution) || (attr? :citetitle) %>
  <attribution>
    <% if attr? :attribution %>
    <%= attr(:attribution) %>
    <% end %>
    #{tag 'citetitle', :citetitle}
  </attribution>
  <% end %>
<% if !@buffer.nil? %>
<simpara><%= content %></simpara>
<% else %>
<%= content %>
<% end %>
</blockquote>
    EOF
  end
end

class BlockVerseTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><blockquote#{common_attrs_erb}>
  #{title_tag}
  <% if (attr? :attribution) || (attr? :citetitle) %>
  <attribution>
    <% if attr? :attribution %>
    <%= attr(:attribution) %>
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
<%#encoding:UTF-8%><<%= title? ? 'table' : 'informaltable'%>#{common_attrs_erb} frame="<%= attr :frame, 'all'%>"
    rowsep="<%= ['none', 'cols'].include?(attr :grid) ? 0 : 1 %>" colsep="<%= ['none', 'rows'].include?(attr :grid) ? 0 : 1 %>">
  #{title_tag}
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
        if tblsec == :head %><%= cell.text %><%
        else %><%
        case cell.attr(:style)
          when :asciidoc %><%= cell.content %><%
          when :verse %><literallayout><%= template.preserve_endlines(cell.text, self) %></literallayout><%
          when :literal %><literallayout class="monospaced"><%= template.preserve_endlines(cell.text, self) %></literallayout><%
          when :header %><% cell.content.each do |text| %><simpara><emphasis role="strong"><%= text %></emphasis></simpara><% end %><%
          else %><% cell.content.each do |text| %><simpara><%= text %></simpara><% end %><%
        %><% end %><% end %></entry>
        <% end %>
      </row>
      <% end %>
    </t<%= tblsec %>>
    <% end %>
  </tgroup>
</<%= title? ? 'table' : 'informaltable'%>>
    EOS
  end
end

class BlockImageTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%#encoding:UTF-8%><figure#{common_attrs_erb}>
  #{title_tag}
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
  QUOTED_TAGS = {
    :emphasis => ['<emphasis>', '</emphasis>'],
    :strong => ['<emphasis role="strong">', '</emphasis>'],
    :monospaced => ['<literal>', '</literal>'],
    :superscript => ['<superscript>', '</superscript>'],
    :subscript => ['<subscript>', '</subscript>'],
    :double => ['&#8220;', '&#8221;'],
    :single => ['&#8216;', '&#8217;']
    #:none => ['', '']
  }

  def quote(text, type, role)
    start_tag, end_tag = QUOTED_TAGS[type] || ['', '']
    if role
      "#{start_tag}<phrase role=\"#{role}\">#{text}</phrase>#{end_tag}"
    else
      "#{start_tag}#{text}#{end_tag}"
    end
  end

  def template
    # very hot piece of code, optimized for speed
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><%= template.quote(@text, @type, attr('role')) %>
    EOF
  end
end

class InlineAnchorTemplate < BaseTemplate
  def anchor(target, text, type)
    case type
    when :ref
      %(<anchor id="#{target}" xreflabel="#{text}"/>)
    when :xref
      text.nil? ? %(<xref linkend="#{target}"/>) : %(<link linkend="#{target}">#{text}</link>)
    when :link
      %(<ulink url="#{target}">#{text}</ulink>)
    when :bibref
      %(<anchor id="#{target}" xreflabel="[#{target}]"/>[#{target}])
    end
  end

  def template
    # hot piece of code, optimized for speed
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><%= template.anchor(@target, @text, @type) %>
    EOS
  end
end

class InlineImageTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><inlinemediaobject>
  <imageobject>
    <imagedata fileref="<%= image_uri(@target) %>"#{attribute('width', :width)}#{attribute('depth', :height)}/>
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
%><footnote#{id}><simpara><%= @text %></simpara></footnote><%
end %>
    EOS
  end
end

class InlineCalloutTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%><co#{id}/>
    EOF
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
  <primary><%= terms[numterms - 2] %></primary><secondary><%= terms[numterms - 1] %></secondary>
</indexterm>
<% end %><indexterm>
  <primary><%= terms[numterms - 1] %></primary>
</indexterm><% end %>
    EOS
  end
end

end # module DocBook45
end # module Asciidoctor
