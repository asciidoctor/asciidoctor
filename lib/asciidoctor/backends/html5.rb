class Asciidoctor::BaseTemplate

  # create template matter to insert a style class from the role attribute if specified
  def style_class
    attrvalue(:role)
  end
end

module Asciidoctor::HTML5
class DocumentTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ::ERB.new <<-EOS
<%#encoding:UTF-8%>
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=<%= attr :encoding %>">
    <meta name="generator" content="Asciidoctor <%= attr 'asciidoctor-version' %>">
    <% if attr? :description %><meta name="description" content="<%= attr :description %>"><% end %>
    <% if attr? :keywords %><meta name="keywords" content="<%= attr :keywords %>"><% end %>
    <title><%= doctitle %></title>
    <% unless attr(:stylesheet, '').empty? %>
    <link rel="stylesheet" href="<%= attr(:stylesdir, '') + attr(:stylesheet) %>" type="text/css">
    <% end %>
  </head>
  <body class="<%= doctype %>">
    <% unless noheader %>
    <div id="header">
      <% if has_header? %>
      <% unless notitle %>
      <h1><%= header.title %></h1>
      <% end %>
      <% if attr? :author %><span id="author"><%= attr :author %></span><br><% end %>
      <% if attr? :email %><span id="email" class="monospaced">&lt;<%= attr :email %>&gt;</span><br><% end %>
      <% if attr? :revnumber %><span id="revnumber">version <%= attr :revnumber %><%= attr?(:revdate) ? ',' : '' %></span><% end %>
      <% if attr? :revdate %><span id="revdate"><%= attr :revdate %></span><% end %>
      <% if attr? :revremark %><br><span id="revremark"><%= attr :revremark %></span><% end %>
      <% end %>
    </div>
    <% end %>
    <div id="content">
<%= content %>
    </div>
    <div id="footer">
      <div id="footer-text">
        Last updated <%= attr :localdatetime %>
      </div>
    </div>
  </body>
</html>
    EOS
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
    @template ||= ::ERB.new <<-EOS
<%#encoding:UTF-8%>
<div id="preamble">
  <div class="sectionbody">
<%= content %>
  </div>
</div>
    EOS
  end
end

class SectionTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<% if level == 0 %>
<h1#{id}><%= title %></h1>
<%= content %>
<% else %>
<div class="sect<%= level %>#{style_class}">
  <h<%= level + 1 %>#{id}><% if attr? :numbered %><%= sectnum %> <% end %><%= title %></h<%= level + 1 %>>
  <% if level == 1 %>
  <div class="sectionbody">
<%= content %>
  </div>
  <% else %>
<%= content %>
  <% end %>
</div>
<% end %>
    EOS
  end
end

class BlockDlistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="dlist#{style_class}">
  <% if title %>
  <div class="title"><%= title %></div>
  <% end %>
  <dl>
    <% content.each do |dt, dd| %>
    <dt class="hdlist1">
      <%= dt.text %>
    </dt>
    <% unless dd.nil? %>
    <dd>
      <% unless dd.text.to_s.empty? %>
      <p><%= dd.text %></p>
      <% end %>
      <% if dd.has_section_body? %>
<%= dd.content %>
      <% end %>
    </dd>
    <% end %>
    <% end %>
  </dl>
</div>
    EOS
  end
end

class BlockListingTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="listingblock#{style_class}">
  <% if title %>
  <div class="title"><%= title %></div>
  <% end %>
  <div class="content monospaced">
    <pre class="highlight#{attrvalue(:language)}"><code><%= content.gsub("\n", LINE_FEED_ENTITY) %></code></pre>
  </div>
</div>
    EOS
  end
end

class BlockLiteralTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="literalblock#{style_class}">
  <% if title %>
  <div class="title"><%= title %></div>
  <% end %>
  <div class="content monospaced">
    <pre><%= content.gsub("\n", LINE_FEED_ENTITY) %></pre>
  </div>
</div>
    EOS
  end
end

class BlockAdmonitionTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="admonitionblock#{style_class}">
  <table>
    <tr>
      <td class="icon">
        <% if attr? :icons %>
        <img src="<%= icon_uri(attr :name) %>" alt="<%= attr :caption %>">
        <% else %>
        <div class="title"><%= attr :caption %></div>
        <% end %>
      </td>
      <td class="content">
        <% unless title.nil? %>
        <div class="title"><%= title %></div>
        <% end %>
        <%= content %>
      </td>
    </tr>
  </table>
</div>
    EOS
  end
end

class BlockParagraphTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="paragraph#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <p><%= content %></p>
</div>
    EOS
  end
end

class BlockSidebarTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="sidebarblock#{style_class}">
  <div class="content">
    <% unless title.nil? %>
    <div class="title"><%= title %></div>
    <% end %>
<%= content %>
  </div>
</div>
    EOS
  end
end

class BlockExampleTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="exampleblock#{style_class}">
  <div class="content">
    <% unless title.nil? %>
    <div class="title"><%= title %></div>
    <% end %>
<%= content %>
  </div>
</div>
    EOS
  end
end

class BlockOpenTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="openblock#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <div class="content">
<%= content %>
  </div>
</div>
    EOS
  end
end

class BlockPassTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
    EOS
  end
end

class BlockQuoteTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="quoteblock#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <div class="content">
<%= content %>
  </div>
  <div class="attribution">
    <% if attr? :citetitle %>
    <em><%= attr :citetitle %></em>
    <% end %>
    <% if attr? :attribution %>
    <% if attr? :citetitle %>
    <br/>
    <% end %>
    <%= '&#8212; ' + attr(:attribution) %>
    <% end %>
  </div>
</div>
    EOS
  end
end

class BlockVerseTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="verseblock#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <pre class="content"><%= content.gsub("\n", LINE_FEED_ENTITY) %></pre>
  <div class="attribution">
    <% if attr? :citetitle %>
    <em><%= attr :citetitle %></em>
    <% end %>
    <% if attr? :attribution %>
    <% if attr? :citetitle %>
    <br/>
    <% end %>
    <%= '&#8212; ' + attr(:attribution) %>
    <% end %>
  </div>
</div>
    EOS
  end
end

class BlockUlistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="ulist#{attrvalue(:style)}#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <ul>
  <% content.each do |li| %>
    <li>
      <p><%= li.text %></p>
      <% if li.has_section_body? %>
<%= li.content %>
      <% end %>
    </li>
  <% end %>
  </ul>
</div>
    EOS
  end
end

class BlockOlistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="olist <%= attr :style %>#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <ol class="<%= attr :style %>"#{attribute('start', :start)}>
  <% content.each do |li| %>
    <li>
      <p><%= li.text %></p>
      <% if li.has_section_body? %>
<%= li.content %>
      <% end %>
    </li>
  <% end %>
  </ol>
</div>
    EOS
  end
end

class BlockColistTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="colist <%= attr :style %>#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <ol>
  <% content.each do |li| %>
    <li>
      <p><%= li.text %></p>
    </li>
  <% end %>
  </ol>
</div>
    EOS
  end
end

class BlockImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="imageblock#{style_class}">
  <div class="content">
    <% if attr :link %>
    <a class="image" href="<%= attr :link %>"><img src="<%= image_uri(attr :target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}></a>
    <% else %>
    <img src="<%= image_uri(attr :target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}>
    <% end %>
  </div>
  <% if title %>
  <div class="title"><%= title %></div>
  <% end %>
</div>
    EOS
  end
end

class BlockRulerTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<hr>
    EOS
  end
end

class InlineBreakTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%= text %><br>
    EOS
  end
end

class InlineCalloutTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<b><%= text %></b>
    EOS
  end
end

class InlineQuotedTemplate < ::Asciidoctor::BaseTemplate
  QUOTED_TAGS = {
    :emphasis => ['<em>', '</em>'],
    :strong => ['<strong>', '</strong>'],
    :monospaced => ['<tt>', '</tt>'],
    :superscript => ['<sup>', '</sup>'],
    :subscript => ['<sub>', '</sub>'],
    :double => [Asciidoctor::INTRINSICS['ldquo'], Asciidoctor::INTRINSICS['rdquo']],
    :single => [Asciidoctor::INTRINSICS['lsquo'], Asciidoctor::INTRINSICS['rsquo']],
    :none => ['', '']
  }

  # we use double quotes for the class attribute to prevent quote processing
  # seems hackish, though AsciiDoc has this same issue
  def template
    @template ||= ERB.new <<-EOS
<%= #{self.class}::QUOTED_TAGS[type].first %><%
if attr? :role %><span#{attribute('class', :role)}><%
end %><%= text %><%
if attr? :role %></span><%
end %><%= #{self.class}::QUOTED_TAGS[type].last %>
    EOS
  end
end

class InlineAnchorTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= ERB.new <<-EOS
<%
if type == :xref
%><a href="#<%= target %>"><%= text || document.references[:ids].fetch(target, '[' + target + ']') %></a><%
elsif type == :ref
%><a id="<%= target %>"></a><%
else
%><a href="<%= target %>"><%= text %></a><%
end
%>
    EOS
  end
end

class InlineImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    # care is taken here to avoid a space inside the optional <a> tag
    @template ||= ERB.new <<-EOS
<span class="image#{style_class}">
  <%
  if attr :link %><a class="image" href="<%= attr :link %>"><%
  end %><img src="<%= image_uri(target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}#{attribute('title', :title)}><%
  if attr :link%></a><% end
  %>
</span>
    EOS
  end
end
end
