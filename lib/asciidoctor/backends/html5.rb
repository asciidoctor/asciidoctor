class Asciidoctor::BaseTemplate

  # create template matter to insert a style class from the role attribute if specified
  def style_class
    attrvalue(:role)
  end
end

module Asciidoctor::HTML5
class DocumentTemplate < ::Asciidoctor::BaseTemplate
  def render_outline(node, to_depth = 2)
    toc_level = nil
    sections = node.sections
    unless sections.empty?
      toc_level, indent = ''
      unless node.is_a?(::Asciidoctor::Document)
        indent = '    ' * (node.document.doctype == 'book' ? node.level + 1 : node.level)
      end
      toc_level << "#{indent}<ol>\n"
      sections.each do |section|
        toc_level << "#{indent}  <li><a href=\"##{section.id}\">#{section.sectnum} #{section.title}</a></li>\n"
        if section.level < to_depth && (child_toc_level = render_outline(section, to_depth))
          toc_level << "#{indent}  <li>\n#{child_toc_level}\n#{indent}  </li>\n"
        end
      end
      toc_level << "#{indent}</ol>"
    end
    toc_level
  end

  # Internal: Generate the default stylesheet for CodeRay
  #
  # returns the default CodeRay stylesheet as a String
  def default_coderay_stylesheet
    Asciidoctor.require_library 'coderay'
    ::CodeRay::Encoders[:html]::CSS.new(:default).stylesheet
  end

  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=<%= attr :encoding %>">
    <meta name="generator" content="Asciidoctor <%= attr 'asciidoctor-version' %>">
    <% if attr? :description %><meta name="description" content="<%= attr :description %>"><% end %>
    <% if attr? :keywords %><meta name="keywords" content="<%= attr :keywords %>"><% end %>
    <title><%= doctitle %></title>
    <% if attr? :toc %>
    <style>
#toc > ol { padding-left: 0; }
#toc ol { list-style-type: none; }
    </style>
    <% end %>
    <% unless attr(:stylesheet, '').empty? %>
    <link rel="stylesheet" href="<%= File.join((attr :stylesdir, '.'), (attr :stylesheet)) %>">
    <% end %>
    <%
    case attr 'source-highlighter' %><%
    when 'coderay' %>
    <style>
pre.highlight { border: none; background-color: #F8F8F8; }
pre.highlight code, pre.highlight pre { color: #333; }
pre.highlight span.line-numbers { display: inline-block; margin-right: 4px; padding: 1px 4px; }
pre.highlight .line-numbers { background-color: #D5F6F6; color: gray; }
pre.highlight .line-numbers pre { color: gray; }
<% if (attr 'coderay-css', 'class') == 'class' %><%= template.default_coderay_stylesheet %><% end %>
    </style><%
    when 'highlightjs' %>
    <link rel="stylesheet" href="<%= (attr :highlightjsdir, 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.3') %>/styles/<%= (attr 'highlightjs-theme', 'default') %>.min.css">
    <style>
pre code { background-color: #F8F8F8; padding: 0; }
    </style>
    <script src="<%= (attr :highlightjsdir, 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.3') %>/highlight.min.js"></script>
    <script>hljs.initHighlightingOnLoad();</script>
    <% end %>
  </head>
  <body#{attribute('id', :'css-signature')} class="<%= doctype %>"<% if attr? 'max-width' %> style="max-width: <%= attr 'max-width' %>;"<% end %>>
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
      <% if attr? :toc %>
      <div id="toc">
        <div id="toctitle"><%= attr 'toc-title', 'Table of Contents' %></div>
<%= template.render_outline(self, (attr :toclevels, 2).to_i) %>
      </div>
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
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
    EOS
  end
end

class BlockPreambleTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<% if level == 0 %>
<h1#{id}><%= title %></h1>
<%= content %>
<% else %>
<div class="sect<%= @level %>#{style_class}">
  <h<%= @level + 1 %>#{id}><% if attr? :numbered %><%= sectnum %> <% end %><%= title %></h<%= @level + 1 %>>
  <% if @level == 1 %>
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
    @template ||= @eruby.new <<-EOS
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
      <% if dd.text? %>
      <p><%= dd.text %></p>
      <% end %>
      <% if dd.blocks? %>
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
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="listingblock#{style_class}">
  <% if title %>
  <div class="title"><%= title %></div>
  <% end %>
  <div class="content monospaced">
    <% if (attr :style) == 'source' %>
    <pre class="highlight<% if attr('source-highlighter') == 'coderay' %> CodeRay<% end %>"><code#{attribute('class', :language)}><%= template.preserve_endlines(content, self) %></code></pre>
    <% else %>
    <pre><%= template.preserve_endlines(content, self) %></pre>
    <% end %>
  </div>
</div>
    EOS
  end
end

class BlockLiteralTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="literalblock#{style_class}">
  <% if title %>
  <div class="title"><%= title %></div>
  <% end %>
  <div class="content monospaced">
    <pre><%= template.preserve_endlines(content, self) %></pre>
  </div>
</div>
    EOS
  end
end

class BlockAdmonitionTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<%= content %>
    EOS
  end
end

class BlockQuoteTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="verseblock#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <pre class="content"><%= template.preserve_endlines(content, self) %></pre>
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
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="ulist#{attrvalue(:style)}#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <ul>
  <% content.each do |li| %>
    <li>
      <p><%= li.text %></p>
      <% if li.blocks? %>
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
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<div#{id} class="olist <%= attr :style %>#{style_class}">
  <% unless title.nil? %>
  <div class="title"><%= title %></div>
  <% end %>
  <ol class="<%= attr :style %>"#{attribute('start', :start)}>
  <% content.each do |li| %>
    <li>
      <p><%= li.text %></p>
      <% if li.blocks? %>
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
    @template ||= @eruby.new <<-EOS
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

class BlockTableTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%>
<table#{id} class="tableblock frame-<%= attr :frame, 'all' %> grid-<%= attr :grid, 'all'%>#{style_class}" style="<%
if !(attr? 'autowidth-option') %>width: <%= attr :tablepcwidth %>%; <% end %><%
if attr? :float %>float: <%= attr :float %>; <% end %>">
  <% if title? %>
  <caption class="title"><%= title %></caption>
  <% end %>
  <% if (attr :rowcount) >= 0 %> 
  <colgroup>
    <% if attr? 'autowidth-option' %>
    <% @columns.each do |col| %>
    <col>
    <% end %>
    <% else %>
    <% @columns.each do |col| %>
    <col style="width: <%= col.attr :colpcwidth %>%;">
    <% end %>
    <% end %>
  </colgroup>
  <% [:head, :foot, :body].select {|tsec| !rows[tsec].empty? }.each do |tsec| %>
  <t<%= tsec %>>
    <% @rows[tsec].each do |row| %>
    <tr>
      <% row.each do |cell| %>
      <<%= tsec == :head ? 'th' : 'td' %> class="tableblock halign-<%= cell.attr :halign %> valign-<%= cell.attr :valign %>"#{attribute('colspan', 'cell.colspan')}#{attribute('rowspan', 'cell.rowspan')}><%
      if tsec == :head %><%= cell.text %><% else %><%
      case cell.attr(:style)
        when :asciidoc %><div><%= cell.content %></div><%
        when :verse %><div class="verse"><%= template.preserve_endlines(cell.text, self) %></div><%
        when :literal %><div class="literal monospaced"><pre><%= template.preserve_endlines(cell.text, self) %></pre></div><%
        when :header %><% cell.content.each do |text| %><p class="tableblock header"><%= text %></p><% end %><%
        else %><% cell.content.each do |text| %><p class="tableblock"><%= text %></p><% end %><%
      end %><% end %></<%= tsec == :head ? 'th' : 'td' %>>
      <% end %>
    </tr>
    <% end %>
  </t<%= tsec %>>
  <% end %>
  <% end %>
</table>
    EOS
  end
end

class BlockImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
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
    @template ||= @eruby.new <<-EOS
<hr>
    EOS
  end
end

class InlineBreakTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%= text %><br>
    EOS
  end
end

class InlineCalloutTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
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

  def template
    @template ||= @eruby.new <<-EOS
<% tags = template.class::QUOTED_TAGS[@type] %><%= tags.first %><%
if attr? :role %><span#{attribute('class', :role)}><%
end %><%= @text %><%
if attr? :role %></span><%
end %><%= tags.last %>
    EOS
  end
end

class InlineAnchorTemplate < ::Asciidoctor::BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%
if type == :xref
%><a href="#<%= @target %>"><%= @text || @document.references[:ids].fetch(@target, '[' + @target + ']') %></a><%
elsif @type == :ref
%><a id="<%= @target %>"></a><%
else
%><a href="<%= @target %>"><%= @text %></a><%
end
%>
    EOS
  end
end

class InlineImageTemplate < ::Asciidoctor::BaseTemplate
  def template
    # care is taken here to avoid a space inside the optional <a> tag
    @template ||= @eruby.new <<-EOS
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
