class Asciidoctor::BaseTemplate
  def role
    attribute('role', :role)
  end

  def xreflabel
    attribute('xreflabel', :reftext)
  end

  def title
    tag('title', 'title')
  end

  def tag(name, key)
    type = key.is_a?(Symbol) ? :attr : :var
    key = key.to_s
    if type == :attr
      # example: <% if attr? 'foo' %><bar><%= attr 'foo' %></bar><% end %>
      '<% if attr? \'' + key + '\' %><' + name + '><%= attr \'' + key + '\' %></' + name + '><% end %>'
    else
      # example: <% unless foo.to_s.empty? %><bar><%= foo %></bar><% end %>
      '<% unless ' + key + '.to_s.empty? %><' + name + '><%= ' + key + ' %></' + name + '><% end %>'
    end
  end
end

module Asciidoctor::DocBook45
class DocumentTemplate < ::Asciidoctor::BaseTemplate
  def docinfo
    <<-EOF
    <% if has_header? && !notitle %>
    #{tag 'title', '@header.name'}
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
<%#encoding:UTF-8%>
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE <%= doctype %> PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">
<% if attr? :toc %><?asciidoc-toc?><% end %>
<% if attr? :numbered %><?asciidoc-numbered?><% end %>
<% if doctype == 'book' %>
<book lang="en">
  <bookinfo>
#{docinfo}
  </bookinfo>
<%= content %>
</book>
<% else %>
<article lang="en">
  <articleinfo>
#{docinfo}
  </articleinfo>
<%= content %>
</article>
<% end %>
    EOF
  end
end

class EmbeddedTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
  EOS
  end
end

class BlockPreambleTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<% if document.doctype == 'book' %>
<preface#{id}#{role}#{xreflabel}>
  <title><%= title %></title>
<%= content %>
</preface>
<% else %>
<%= content %>
<% end %>
    EOF
  end
end

class SectionTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<<%= document.doctype == 'book' && level <= 1 ? 'chapter' : 'section' %>#{id}#{role}#{xreflabel}>
  #{title}
<%= content %>
</<%= document.doctype == 'book' && level <= 1 ? 'chapter' : 'section' %>>
    EOF
  end
end

class BlockParagraphTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<% if !title? %>
<simpara#{id}#{role}#{xreflabel}><%= content %></simpara>
<% else %>
<formalpara#{id}#{role}#{xreflabel}>
  <title><%= title %></title>
  <para><%= content %></para>
</formalpara>
<% end %>
    EOF
  end
end

class BlockAdmonitionTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<<%= attr :name %>#{id}#{role}#{xreflabel}>
  #{title}
  <% if blocks? %>
<%= content %>
  <% else %>
  <simpara><%= content.chomp %></simpara>
  <% end %>
</<%= attr :name %>>
    EOF
  end
end

class BlockUlistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<itemizedlist#{id}#{role}#{xreflabel}>
  #{title}
  <% content.each do |li| %>
    <listitem>
      <simpara><%= li.text %></simpara>
      <% if li.blocks? %>
<%= li.content %>
      <% end %>
    </listitem>
  <% end %>
</itemizedlist>
    EOF
  end
end

class BlockOlistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<orderedlist#{id}#{role}#{xreflabel}#{attribute('numeration', :style)}>
  #{title}
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

class BlockColistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<calloutlist#{id}#{role}#{xreflabel}>
  #{title}
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

class BlockDlistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<variablelist#{id}#{role}#{xreflabel}>
  #{title}
  <% content.each do |dt, dd| %>
  <varlistentry>
    <term>
      <%= dt.text %>
    </term>
    <% unless dd.nil? %>
    <listitem>
      <% if dd.text? %>
      <simpara><%= dd.text %></simpara>
      <% end %>
      <% if dd.blocks? %>
<%= dd.content %>
      <% end %>
    </listitem>
    <% end %>
  </varlistentry>
  <% end %>
</variablelist>
    EOF
  end
end

class BlockOpenTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
    EOS
  end
end

class BlockListingTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<% if !title? %>
<% if (attr :style) == 'source' %>
<programlisting#{id}#{role}#{xreflabel}#{attribute('language', :language)} linenumbering="<%= (attr? :linenums) ? 'numbered' : 'unnumbered' %>"><%= template.preserve_endlines(content, self) %></programlisting>
<% else %>
<screen#{id}#{role}#{xreflabel}><%= template.preserve_endlines(content, self) %></screen>
<% end %>
<% else %>
<formalpara#{id}#{role}#{xreflabel}>
  <title><%= title %></title>
  <para>
    <% if (attr :style) == 'source' %>
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

class BlockLiteralTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<% if !title? %>
<literallayout#{id}#{role}#{xreflabel} class="monospaced"><%= template.preserve_endlines(content, self) %></literallayout>
<% else %>
<formalpara#{id}#{role}#{xreflabel}>
  <title><%= title %></title>
  <para>
    <literallayout class="monospaced"><%= template.preserve_endlines(content, self) %></literallayout>
  </para>
</formalpara>
<% end %>
    EOF
  end
end

class BlockExampleTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<example#{id}#{role}#{xreflabel}>
  #{title}
<%= content %>
</example>
    EOF
  end
end

class BlockSidebarTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<sidebar#{id}#{role}#{xreflabel}>
  #{title}
<%= content %>
</sidebar>
    EOF
  end
end

class BlockQuoteTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<blockquote#{id}#{role}#{xreflabel}>
  #{title}
  <% if (attr? :attribution) || (attr? :citetitle) %>
  <attribution>
    <% if attr? :attribution %>
    <%= attr(:attribution) %>
    <% end %>
    #{tag 'citetitle', :citetitle}
  </attribution>
  <% end %>
<% if !buffer.nil? %>
<simpara><%= content %></simpara>
<% else %>
<%= content %>
<% end %>
</blockquote>
    EOF
  end
end

class BlockVerseTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<blockquote#{id}#{role}#{xreflabel}>
  #{title}
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

class BlockPassTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
    EOS
  end
end

class BlockTableTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<<%= title? ? 'table' : 'informaltable'%>#{id}#{role}#{xreflabel} frame="<%= attr :frame, 'all'%>"
    rowsep="<%= ['none', 'cols'].include?(attr :grid) ? 0 : 1 %>" colsep="<%= ['none', 'rows'].include?(attr :grid) ? 0 : 1 %>">
  #{title}
  <% if attr? :width %>
  <?dbhtml table-width="<%= attr :width %>"?>
  <?dbfo table-width="<%= attr :width %>"?>
  <?dblatex table-width="<%= attr :width %>"?>
  <% end %>
  <tgroup cols="<%= attr :colcount %>">
    <% @columns.each do |col| %>
    <colspec colname="col_<%= col.attr :colnumber %>" colwidth="<%= col.attr((attr? :width) ? :colabswidth : :colpcwidth) %>*"/>
    <% end %>
    <% [:head, :foot, :body].select {|tsec| !rows[tsec].empty? }.each do |tsec| %>
    <t<%= tsec %>>
      <% @rows[tsec].each do |row| %>
      <row>
        <% row.each do |cell| %>
        <entry#{attribute('align', 'cell.attr :halign')}#{attribute('valign', 'cell.attr :valign')}<%
        if cell.colspan %> namest="col_<%= cell.column.attr :colnumber %>" nameend="col_<%= (cell.column.attr :colnumber) + cell.colspan - 1 %>"<%
        end %><% if cell.rowspan %> morerows="<%= cell.rowspan - 1 %>"<% end %>><%
        if tsec == :head %><%= cell.text %><%
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
    </t<%= tsec %>>
    <% end %>
  </tgroup>
</<%= title? ? 'table' : 'informaltable'%>>
    EOS
  end
end

class BlockImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%#encoding:UTF-8%>
<figure#{id}#{role}#{xreflabel}>
  #{title}
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

class BlockRulerTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<simpara><?asciidoc-hr?></simpara>
    EOF
  end
end

class InlineBreakTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<%= text %><?asciidoc-br?>
    EOF
  end
end

class InlineQuotedTemplate < ::Asciidoctor::BaseTemplate
  QUOTED_TAGS = {
    :emphasis => ['<emphasis>', '</emphasis>'],
    :strong => ['<emphasis role="strong">', '</emphasis>'],
    :monospaced => ['<literal>', '</literal>'],
    :superscript => ['<superscript>', '</superscript>'],
    :subscript => ['<subscript>', '</subscript>'],
    :double => [Asciidoctor::INTRINSICS['ldquo'], Asciidoctor::INTRINSICS['rdquo']],
    :single => [Asciidoctor::INTRINSICS['lsquo'], Asciidoctor::INTRINSICS['rsquo']],
    :none => ['', '']
  }

  def template
    @template ||= @eruby.new <<-EOF
<% tags = template.class::QUOTED_TAGS[@type] %><%= tags.first %><%
if attr? :role %><phrase#{role}><%
end %><%= @text %><%
if attr? :role %></phrase><%
end %><%= tags.last %>
    EOF
  end
end

class InlineAnchorTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<% if @type == :xref
%><%
  if @text.nil?
%><xref linkend="<%= @target %>"/><%
  else
%><link linkend="<%= @target %>"><%= @text %></link><%
  end %><%
elsif @type == :ref
%><anchor id="<%= @target %>" xreflabel="<%= @text %>"/><%
else
%><ulink url="<%= @target %>"><%= @text %></ulink><%
end %>
    EOF
  end
end

class InlineImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<inlinemediaobject>
  <imageobject>
    <imagedata fileref="<%= image_uri(@target) %>"#{attribute('width', :width)}#{attribute('depth', :height)}/>
  </imageobject>
  <textobject><phrase><%= attr :alt %></phrase></textobject>
</inlinemediaobject>
    EOF
  end
end

class InlineCalloutTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOF
<co#{id}/>
    EOF
  end
end
end
