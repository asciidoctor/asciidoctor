module Asciidoctor
class BaseTemplate

  # create template matter to insert a style class from the role attribute if specified
  def role_class
    attrvalue(:role)
  end

  # create template matter to insert a style class from the style attribute if specified
  def style_class(sibling = true)
    attrvalue(:style, sibling)
  end

  def title_div(opts = {})
    %(<% if title? %><div class="title">#{opts.has_key?(:caption) ? '<%= @caption %>' : ''}<%= title %></div><% end %>)
  end
end

module HTML5
class DocumentTemplate < BaseTemplate
  def self.outline(node, to_depth = 2)
    toc_level = nil
    sections = node.sections
    unless sections.empty?
      toc_level, indent = ''
      nested = true
      unless node.is_a?(Document)
        if node.document.doctype == 'book'
          indent = '    ' * node.level unless node.level == 0
          nested = node.level > 0
        else
          indent = '    ' * node.level
        end
      end
      toc_level << "#{indent}<ol>\n" if nested
      sections.each do |section|
        toc_level << "#{indent}  <li><a href=\"##{section.id}\">#{!section.special && section.level > 0 ? "#{section.sectnum} " : ''}#{section.attr('caption')}#{section.title}</a></li>\n"
        if section.level < to_depth && (child_toc_level = outline(section, to_depth))
          if section.document.doctype != 'book' || section.level > 0
            toc_level << "#{indent}  <li>\n#{child_toc_level}\n#{indent}  </li>\n"
          else
            toc_level << "#{indent}#{child_toc_level}\n"
          end
        end
      end
      toc_level << "#{indent}</ol>" if nested
    end
    toc_level
  end

  # Internal: Generate the default stylesheet for CodeRay
  #
  # returns the default CodeRay stylesheet as a String
  def self.default_coderay_stylesheet
    Helpers.require_library 'coderay'
    ::CodeRay::Encoders[:html]::CSS.new(:default).stylesheet
  end

  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><!DOCTYPE html>
<html<% unless attr? :nolang %> lang="<%= attr :lang, 'en' %>"<% end %>>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=<%= attr :encoding %>">
    <meta name="generator" content="Asciidoctor <%= attr 'asciidoctor-version' %>">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <% if attr? :description %>
    <meta name="description" content="<%= attr :description %>">
    <% end %>
    <% if attr? :keywords %>
    <meta name="keywords" content="<%= attr :keywords %>">
    <% end %>
    <title><%= doctitle %></title>
    <% if DEFAULT_STYLESHEET_KEYS.include?(attr 'stylesheet') %>
    <% if @safe >= SafeMode::SECURE || (attr? 'linkcss') %>
    <link rel="stylesheet" href="<%= normalize_web_path(DEFAULT_STYLESHEET_NAME, (attr :stylesdir, '')) %>">
    <% else %>
    <style>
<%= read_asset DEFAULT_STYLESHEET_PATH %>
    </style>
    <% end %>
    <% elsif attr? :stylesheet %>
    <% if attr? 'linkcss' %>
    <link rel="stylesheet" href="<%= normalize_web_path((attr :stylesheet), attr(:stylesdir, '')) %>">
    <% else %>
    <style>
<%= read_asset normalize_system_path(attr(:stylesheet), attr(:stylesdir, '')), true %>
    </style>
    <% end %>
    <% end %>
    <% case attr 'source-highlighter' %><%
    when 'coderay' %>
    <% if (attr 'coderay-css', 'class') == 'class' %>
    <style>
<%= template.class.default_coderay_stylesheet %>
    </style>
    <% end %><%
    when 'highlightjs' %>
    <link rel="stylesheet" href="<%= (attr :highlightjsdir, 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.3') %>/styles/<%= (attr 'highlightjs-theme', 'default') %>.min.css">
    <script src="<%= (attr :highlightjsdir, 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.3') %>/highlight.min.js"></script>
    <script>hljs.initHighlightingOnLoad()</script>
    <% end %>
<%= docinfo %>
  </head>
  <body#{id} class="<%= doctype %>"<% if attr? 'max-width' %> style="max-width: <%= attr 'max-width' %>;"<% end %>>
    <% unless noheader %>
    <div id="header">
      <% if has_header? %>
      <% unless notitle %>
      <h1><%= @header.title %></h1>
      <% end %>
      <% if attr? :author %><span id="author"><%= attr :author %></span><br>
      <% if attr? :email %><span id="email"><%= sub_macros(attr :email) %></span><br><% end %><% end %>
      <% if attr? :revnumber %><span id="revnumber">version <%= attr :revnumber %><%= attr?(:revdate) ? ',' : '' %></span><% end %>
      <% if attr? :revdate %><span id="revdate"><%= attr :revdate %></span><% end %>
      <% if attr? :revremark %><br><span id="revremark"><%= attr :revremark %></span><% end %>
      <% end %>
      <% if (attr? :toc) && (attr? 'toc-placement', 'auto') %>
      <div id="toc" class="<%= attr 'toc-class', 'toc' %>">
        <div id="toctitle"><%= attr 'toc-title' %></div>
<%= template.class.outline(self, (attr :toclevels, 2).to_i) %>
      </div>
      <% end %>
    </div>
    <% end %>
    <div id="content">
<%= content %>
    </div>
    <% unless !footnotes? || attr?(:nofootnotes) %><div id="footnotes">
      <hr>
      <% footnotes.each do |fn| %>
      <div class="footnote" id="_footnote_<%= fn.index %>">
        <a href="#_footnoteref_<%= fn.index %>"><%= fn.index %></a>. <%= fn.text %>
      </div>
      <% end %>
    </div>
    <% end %>
    <div id="footer">
      <div id="footer-text">
        <% if attr? :revnumber %>Version <%= attr :revnumber %><br><% end %>
        Last updated <%= attr :docdatetime %>
      </div>
    </div>
  </body>
</html>
    EOS
  end
end

class EmbeddedTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><% unless notitle || !has_header? %><h1#{id}><%= header.title %></h1>
<% end %><%= content %>
<% unless !footnotes? || attr?(:nofootnotes) %><div id="footnotes">
  <hr>
  <% footnotes.each do |fn| %>
  <div class="footnote" id="_footnote_<%= fn.index %>">
    <a href="#_footnoteref_<%= fn.index %>"><%= fn.index %></a>. <%= fn.text %>
  </div>
  <% end %>
</div><% end %>
    EOS
  end
end

class BlockTocTemplate < BaseTemplate
  def result(node)
    doc = node.document

    return '' unless doc.attr?('toc')

    if node.id
      id_attr = %( id="#{node.id}")
      title_id_attr = ''
    elsif doc.embedded? || !doc.attr?('toc-placement', 'auto')
      id_attr = ' id="toc"'
      title_id_attr = ' id="toctitle"'
    else
      id_attr = ''
      title_id_attr = ''
    end
    title = node.title? ? node.title : (doc.attr 'toc-title')
    levels = node.attr?('levels') ? node.attr('levels').to_i : doc.attr('toclevels', 2).to_i
    role = node.attr?('role') ? node.attr('role') : doc.attr('toc-class', 'toc')

    %(\n<div#{id_attr} class="#{role}">
<div#{title_id_attr} class="title">#{title}</div>
#{DocumentTemplate.outline(doc, levels)}
</div>)
  end

  def template
    :invoke_result
  end
end

class BlockPreambleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div id="preamble">
  <div class="sectionbody">
<%= content %>
  </div>
</div>
    EOS
  end
end

class SectionTemplate < BaseTemplate
  def result(sec)
    slevel = sec.level
    # QUESTION should this check be done in section?
    if slevel == 0 && sec.special
      slevel = 1
    end
    htag = "h#{slevel + 1}"
    id = sec.id && " id=\"#{sec.id}\""

    if slevel == 0
      %(<h1#{id}>#{sec.title}</h1>
#{sec.content})
    else
      role = sec.attr?('role') ? " #{sec.attr('role')}" : nil
      if !sec.special && (sec.attr? 'numbered') && slevel < 4
        sectnum = "#{sec.sectnum} "
      else
        sectnum = nil
      end

      if slevel == 1
        content = %(  <div class="sectionbody">
#{sec.content}
  </div>)
      else
        content = sec.content
      end
      %(<div class="sect#{slevel}#{role}">
  <#{htag}#{id}>#{sectnum}#{sec.attr 'caption'}#{sec.title}</#{htag}>
#{content}
</div>)
    end
  end

  def template
    :invoke_result
  end
end

class BlockFloatingTitleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><h<%= @level + 1 %>#{id} class="#{style_class false}#{role_class}"><%= title %></h<%= @level + 1 %>>
    EOS
  end
end

class BlockDlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><%
if attr? :style, 'qanda' %>
<div#{id} class="qlist#{style_class}#{role_class}">
  #{title_div}
  <ol>
  <% content.each do |dt, dd| %>
    <li>
      <p><em><%= dt.text %></em></p>
      <% unless dd.nil? %>
      <% if dd.text? %>
      <p><%= dd.text %></p>
      <% end %>
      <% if dd.blocks? %>
<%= dd.content %>
      <% end %>
      <% end %>
    </li>
  <% end %>
  </ol>
</div>
<% elsif attr? :style, 'horizontal' %>
<div#{id} class="hdlist#{role_class}">
  #{title_div}
  <table>
    <colgroup>
      <col<% if attr? :labelwidth %> style="width:<%= attr :labelwidth %>%;"<% end %>>
      <col<% if attr? :itemwidth %> style="width:<%= attr :itemwidth %>%;"<% end %>>
    </colgroup>
    <% content.each do |dt, dd| %>
    <tr>
      <td class="hdlist1<% if attr? 'strong-option' %> strong<% end %>">
        <%= dt.text %>
        <br>
      </td>
      <td class="hdlist2"><% unless dd.nil? %><% if dd.text? %>
        <p style="margin-top: 0;"><%= dd.text %></p><% end %><% if dd.blocks? %>
<%= dd.content %><% end %><% end %>
      </td>
    </tr>
    <% end %>
  </table>
</div>
<% else %>
<div#{id} class="dlist#{style_class}#{role_class}">
  #{title_div}
  <dl>
    <% content.each do |dt, dd| %>
    <dt<% if !(attr? :style) %> class="hdlist1"<% end %>>
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
<% end %>
    EOS
  end
end

class BlockListingTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="listingblock#{role_class}">
  #{title_div :caption => true}
  <div class="content monospaced">
    <% if attr? :style, 'source' %>
    <pre class="highlight<% if attr? 'source-highlighter', 'coderay' %> CodeRay<% end %>"><code#{attribute('class', :language)}><%= template.preserve_endlines(content, self) %></code></pre>
    <% else %>
    <pre><%= template.preserve_endlines(content, self) %></pre>
    <% end %>
  </div>
</div>
    EOS
  end
end

class BlockLiteralTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="literalblock#{role_class}">
  #{title_div}
  <div class="content monospaced">
    <pre><%= template.preserve_endlines(content, self) %></pre>
  </div>
</div>
    EOS
  end
end

class BlockAdmonitionTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="admonitionblock <%= attr :name %>#{role_class}">
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
        #{title_div}
        <%= content %>
      </td>
    </tr>
  </table>
</div>
    EOS
  end
end

class BlockParagraphTemplate < BaseTemplate
  def paragraph(id, role, title, content)
    %(<div#{id && " id=\"#{id}\""} class=\"paragraph#{role && " #{role}"}\">#{title && "
  <div class=\"title\">#{title}</div>"}  
  <p>#{content}</p>
</div>)
  end

  def result(node)
    paragraph(node.id, node.attr('role'), (node.title? ? node.title : nil), node.content)
  end

  def template
    :invoke_result
  end
end

class BlockSidebarTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="sidebarblock#{role_class}">
  <div class="content">
    #{title_div}
<%= content %>
  </div>
</div>
    EOS
  end
end

class BlockExampleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="exampleblock#{role_class}">
  #{title_div :caption => true}
  <div class="content">
<%= content %>
  </div>
</div>
    EOS
  end
end

class BlockOpenTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="openblock#{role_class}">
  #{title_div}
  <div class="content">
<%= content %>
  </div>
</div>
    EOS
  end
end

class BlockPassTemplate < BaseTemplate
  def template
    :content
  end
end

class BlockQuoteTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="quoteblock#{role_class}">
  #{title_div}
  <blockquote>
<%= content %>
  </blockquote>
  <div class="attribution">
    <% if attr? :citetitle %>
    <cite><%= attr :citetitle %></cite>
    <% end %>
    <% if attr? :attribution %>
    <% if attr? :citetitle %>
    <br>
    <% end %>
    <%= "&#8212; \#{attr :attribution}" %>
    <% end %>
  </div>
</div>
    EOS
  end
end

class BlockVerseTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="verseblock#{role_class}">
  #{title_div}
  <pre class="content"><%= template.preserve_endlines(content, self) %></pre>
  <div class="attribution">
    <% if attr? :citetitle %>
    <cite><%= attr :citetitle %></cite>
    <% end %>
    <% if attr? :attribution %>
    <% if attr? :citetitle %>
    <br>
    <% end %>
    <%= "&#8212; \#{attr :attribution}" %>
    <% end %>
  </div>
</div>
    EOS
  end
end

class BlockUlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="ulist#{style_class}#{role_class}">
  #{title_div}
  <ul>
  <% content.each do |item| %>
    <li>
      <p><%= item.text %></p>
      <% if item.blocks? %>
<%= item.content %>
      <% end %>
    </li>
  <% end %>
  </ul>
</div>
    EOS
  end
end

class BlockOlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="olist#{style_class}#{role_class}">
  #{title_div}
  <ol class="<%= attr :style %>"#{attribute('start', :start)}>
  <% content.each do |item| %>
    <li>
      <p><%= item.text %></p>
      <% if item.blocks? %>
<%= item.content %>
      <% end %>
    </li>
  <% end %>
  </ol>
</div>
    EOS
  end
end

class BlockColistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="colist#{style_class}#{role_class}">
  #{title_div}
  <% if attr? :icons %>
  <table>
    <% content.each_with_index do |item, i| %>
    <tr>
      <td><img src="<%= icon_uri("callouts/\#{i + 1}") %>" alt="<%= i + 1 %>"></td>
      <td><%= item.text %></td>
    </tr>
    <% end %>
  </table>
  <% else %>
  <ol>
  <% content.each do |item| %>
    <li>
      <p><%= item.text %></p>
    </li>
  <% end %>
  </ol>
  <% end %>
</div>
    EOS
  end
end

class BlockTableTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><table#{id} class="tableblock frame-<%= attr :frame, 'all' %> grid-<%= attr :grid, 'all'%>#{role_class}" style="<%
if !(attr? 'autowidth-option') %>width:<%= attr :tablepcwidth %>%; <% end %><%
if attr? :float %>float: <%= attr :float %>; <% end %>">
  <% if title? %>
  <caption class="title"><% unless @caption.nil? %><%= @caption %><% end %><%= title %></caption>
  <% end %>
  <% if (attr :rowcount) >= 0 %>
  <colgroup>
    <% if attr? 'autowidth-option' %>
    <% @columns.each do %>
    <col>
    <% end %>
    <% else %>
    <% @columns.each do |col| %>
    <col style="width:<%= col.attr :colpcwidth %>%;">
    <% end %>
    <% end %>
  </colgroup>
  <% [:head, :foot, :body].select {|tsec| !@rows[tsec].empty? }.each do |tsec| %>
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

class BlockImageTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="imageblock#{style_class}#{role_class}"<% if (attr? :align) || (attr? :float)
%> style="<% if attr? :align %>text-align: <%= attr :align %><% if attr? :float %>; <% end %><% end %><% if attr? :float %>float: <%= attr :float %><% end %>"<% end
%>>
  <div class="content">
    <% if attr? :link %>
    <a class="image" href="<%= attr :link %>"><img src="<%= image_uri(attr :target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}></a>
    <% else %>
    <img src="<%= image_uri(attr :target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}>
    <% end %>
  </div>
  #{title_div :caption => true}
</div>
    EOS
  end
end

class BlockAudioTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="audioblock#{style_class}#{role_class}">
  #{title_div :caption => true}
  <div class="content">
    <audio src="<%= media_uri(attr :target) %>"<% if
        attr? 'autoplay-option' %> autoplay<% end %><%
        unless attr? 'nocontrols-option' %> controls<% end %><%
        if attr? 'loop-option' %> loop<% end %>>
      Your browser does not support the audio tag.
    </audio>
  </div>
</div>
    EOS
  end
end

class BlockVideoTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="videoblock#{style_class}#{role_class}">
  #{title_div :caption => true}
  <div class="content">
    <video src="<%= media_uri(attr :target) %>"#{attribute('width', :width)}#{attribute('height', :height)}<%
        if attr? 'poster' %> poster="<%= media_uri(attr :poster) %>"<% end %><%
        if attr? 'autoplay-option' %> autoplay<% end %><%
        unless attr? 'nocontrols-option' %> controls<% end %><%
        if attr? 'loop-option' %> loop<% end %>>
      Your browser does not support the video tag.
    </video>
  </div>
</div>
    EOS
  end
end

class BlockRulerTemplate < BaseTemplate
  def result(node)
    '<hr>'
  end

  def template
    :invoke_result
  end
end

class BlockPageBreakTemplate < BaseTemplate
  def result(node)
    '<div style="page-break-after: always;"></div>'
  end

  def template
    :invoke_result
  end
end

class InlineBreakTemplate < BaseTemplate
  def result(node)
    "#{node.text}<br>"
  end

  def template
    :invoke_result
  end
end

class InlineCalloutTemplate < BaseTemplate
  def result(node)
    if node.attr? 'icons'
      src = node.icon_uri("callouts/#{node.text}")
      %(<img src="#{src}" alt="#{node.text}">)
    else
      "<b>&lt;#{node.text}&gt;</b>"
    end
  end

  def template
    :invoke_result
  end
end

class InlineQuotedTemplate < BaseTemplate
  NO_TAGS = ['', '']

  QUOTED_TAGS = {
    :emphasis => ['<em>', '</em>'],
    :strong => ['<strong>', '</strong>'],
    :monospaced => ['<code>', '</code>'],
    :superscript => ['<sup>', '</sup>'],
    :subscript => ['<sub>', '</sub>'],
    :double => ['&#8220;', '&#8221;'],
    :single => ['&#8216;', '&#8217;']
  }

  def quote_text(text, type, role)
    start_tag, end_tag = QUOTED_TAGS[type] || NO_TAGS
    if role
      "#{start_tag}<span class=\"#{role}\">#{text}</span>#{end_tag}"
    else
      "#{start_tag}#{text}#{end_tag}"
    end
  end

  def result(node)
    quote_text(node.text, node.type, node.attr('role'))
  end

  def template
    :invoke_result
  end
end

class InlineAnchorTemplate < BaseTemplate
  def anchor(target, text, type, document, window = nil)
    case type
    when :xref
      text = document.references[:ids].fetch(target, "[#{target}]") if text.nil?
      %(<a href="##{target}">#{text}</a>)
    when :ref
      %(<a id="#{target}"></a>)
    when :link
      %(<a href="#{target}"#{window && " target=\"#{window}\""}>#{text}</a>)
    when :bibref
      %(<a id="#{target}"></a>[#{target}])
    end
  end

  def result(node)
    anchor(node.target, node.text, node.type, node.document, (node.type == :link ? node.attr('window') : nil))
  end

  def template
    :invoke_result
  end
end

class InlineImageTemplate < BaseTemplate
  def template
    # care is taken here to avoid a space inside the optional <a> tag
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><span class="image#{role_class}"><%
if attr? :link %><a class="image" href="<%= attr :link %>"><%
end %><img src="<%= image_uri(@target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}#{attribute('title', :title)}><%
if attr? :link%></a><% end
%></span>
    EOS
  end
end

class InlineFootnoteTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><%
if @type == :xref
%><span class="footnoteref">[<a class="footnote" href="#_footnote_<%= attr :index %>" title="View footnote."><%= attr :index %></a>]</span><%
else
%><span class="footnote"<% if @id %> id="_footnote_<%= @id %>"<% end %>>[<a id="_footnoteref_<%= attr :index %>" class="footnote" href="#_footnote_<%= attr :index %>" title="View footnote."><%= attr :index %></a>]</span><%
end %>
    EOS
  end
end

class InlineIndextermTemplate < BaseTemplate
  def result(node)
    node.type == :visible ? node.text : ''
  end

  def template
    :invoke_result
  end
end

end # module HTML5
end # module Asciidoctor
