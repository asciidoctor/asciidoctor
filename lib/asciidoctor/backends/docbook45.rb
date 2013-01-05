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
      # example: <% unless foo.nil? %><bar><%= foo %></bar><% end %>
      '<% unless ' + key + '.nil? %><' + name + '><%= ' + key + ' %></' + name + '><% end %>'
    end
  end
end

module Asciidoctor::DocBook45
class DocumentTemplate < ::Asciidoctor::BaseTemplate
  def docinfo
    <<-EOF
    <% if has_header? && !notitle %>
    #{tag 'title', 'header.name'}
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
      #{tag 'revdate', :revdate}
      #{tag 'authorinitials', :authorinitials}
      #{tag 'revremark', :revremark}
    </revhistory>
    <% end %>
    <% end %>
    EOF
  end

  def template
    @template ||= ::ERB.new <<-EOF
<%#encoding:UTF-8%>
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE <%= doctype %> PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">
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
    @template ||= ::ERB.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
  EOS
  end
end

class BlockPreambleTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ::ERB.new <<-EOF
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
    @template ||= ERB.new <<-EOF
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
    @template ||= ERB.new <<-EOF
<%#encoding:UTF-8%>
<% if title.nil? %>
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
    @template ||= ERB.new <<-EOF
<%#encoding:UTF-8%>
<<%= attr :name %>#{id}#{role}#{xreflabel}>
  #{title}
  <% if has_section_body? %>
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
    @template ||= ERB.new <<-EOF
<%#encoding:UTF-8%>
<itemizedlist#{id}#{role}#{xreflabel}>
  #{title}
  <% content.each do |li| %>
    <listitem>
      <simpara><%= li.text %></simpara>
      <% if li.has_section_body? %>
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
    @template ||= ERB.new <<-EOF
<%#encoding:UTF-8%>
<orderedlist#{id}#{role}#{xreflabel}#{attribute('numeration', :style)}>
  #{title}
  <% content.each do |li| %>
    <listitem>
      <simpara><%= li.text %></simpara>
      <% if li.has_section_body? %>
<%= li.content %>
      <% end %>
    </listitem>
  <% end %>
</orderedlist>
    EOF
  end
end

class BlockDlistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
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
      <simpara><%= dd.text %></simpara>
      <% if dd.has_section_body? %>
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
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
    EOS
  end
end

class BlockListingTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<%#encoding:UTF-8%>
<% if title.nil? %>
<programlisting#{id}#{role}#{xreflabel} language="<%= attr :language %>" linenumbering="<%= (attr? :linenums) ? 'numbered' : 'unnumbered' %>"><%= content.gsub("\n", LINE_FEED_ENTITY) %></programlisting>
<% else %>
<formalpara#{id}#{role}#{xreflabel}>
  <title><%= title %></title>
  <para>
    <programlisting language="<%= attr :language %>" linenumbering="<%= (attr? :linenums) ? 'numbered' : 'unnumbered' %>"><%= content.gsub("\n", LINE_FEED_ENTITY) %></programlisting>
  </para>
</formalpara>
<% end %>
    EOF
  end
end

class BlockLiteralTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<%#encoding:UTF-8%>
<% if title.nil? %>
<literallayout#{id}#{role}#{xreflabel} class="monospaced"><%= content.gsub("\n", LINE_FEED_ENTITY) %></literallayout>
<% else %>
<formalpara#{id}#{role}#{xreflabel}>
  <title><%= title %></title>
  <literallayout class="monospaced"><%= content.gsub("\n", LINE_FEED_ENTITY) %></literallayout>
</formalpara>
<% end %>
    EOF
  end
end

class BlockExampleTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
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
    @template ||= ERB.new <<-EOF
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
    @template ||= ERB.new <<-EOF
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
<%= content %>
</blockquote>
    EOF
  end
end

class BlockVerseTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
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

class BlockImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
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
    @template ||= ERB.new <<-EOF
<simpara><?asciidoc-hr?></simpara>
    EOF
  end
end

class InlineBreakTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
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
    @template ||= ERB.new <<-EOF
<%= #{self.class}::QUOTED_TAGS[type].first %><%
if attr? :role %><phrase#{role}><%
end %><%= text %><%
if attr? :role %></phrase><%
end %><%= #{self.class}::QUOTED_TAGS[type].last %>
    EOF
  end
end

class InlineAnchorTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<% if type == :xref
%><%
  if text.nil?
%><xref linkend="<%= target %>"/><%
  else
%><link linkend="<%= target %>"><%= text %></link><%
  end %><%
elsif type == :ref
%><anchor id="<%= target %>" xreflabel="<%= text %>"/><%
else
%><ulink url="<%= target %>"><%= text %></ulink><%
end %>
    EOF
  end
end

class InlineImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<inlinemediaobject>
  <imageobject>
    <imagedata fileref="<%= image_uri(target) %>"#{attribute('width', :width)}#{attribute('depth', :height)}/>
  </imageobject>
  <textobject><phrase><%= attr :alt %></phrase></textobject>
</inlinemediaobject>
    EOF
  end
end

class InlineCalloutTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<co#{id}/>
    EOF
  end
end
end
