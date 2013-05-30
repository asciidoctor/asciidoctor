require 'asciidoctor/backends/_stylesheets'

module Asciidoctor
class BaseTemplate

  # create template matter to insert a style class from the role attribute if specified
  def role_class
    attrvalue('role')
  end

  # create template matter to insert a style class from the style attribute if specified
  def style_class(sibling = true)
    attrvalue('style', sibling, false)
  end

  def title_div(opts = {})
    if opts.has_key? :caption
      %q(<% if title? %><div class="title"><%= @caption %><%= title %></div><% end %>)
    else
      %q(<% if title? %><div class="title"><%= title %></div><% end %>)
    end
  end
end

module HTML5

class DocumentTemplate < BaseTemplate
  def self.outline(node, to_depth = 2)
    toc_level = nil
    sections = node.sections
    unless sections.empty?
      # FIXME the level for special sections should be set correctly in the model
      # sec_level will only be 0 if we have a book doctype with parts
      sec_level = sections.first.level
      if sec_level == 0 && sections.first.special
        sec_level = 1
      end
      toc_level = %(<ol type="none" class="sectlevel#{sec_level}">\n)
      numbered = node.document.attr? 'numbered'
      sections.each do |section|
        # need to check playback attributes for change in numbered setting
        # FIXME encapsulate me
        if section.attributes.has_key? :attribute_entries
          if (numbered_override = section.attributes[:attribute_entries].find {|entry| entry.name == 'numbered'})
            numbered = numbered_override.negate ? false : true
          end
        end
        section_num = numbered && !section.special && section.level > 0 && section.level < 4 ? %(#{section.sectnum} ) : nil
        toc_level = %(#{toc_level}<li><a href=\"##{section.id}\">#{section_num}#{section.caption}#{section.title}</a></li>\n)
        if section.level < to_depth && (child_toc_level = outline(section, to_depth))
          toc_level = %(#{toc_level}<li>\n#{child_toc_level}\n</li>\n)
        end
      end
      toc_level = %(#{toc_level}</ol>)
    end
    toc_level
  end

  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><!DOCTYPE html>
<html<%= !(attr? 'nolang') ? %( lang="\#{attr 'lang', 'en'}") : nil %>>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<%= attr :encoding %>">
<meta name="generator" content="Asciidoctor <%= attr 'asciidoctor-version' %>">
<meta name="viewport" content="width=device-width, initial-scale=1.0"><%
if attr? :description %>
<meta name="description" content="<%= attr :description %>"><%
end
if attr? :keywords %>
<meta name="keywords" content="<%= attr :keywords %>"><%
end %>
<title><%= doctitle %></title><%
if DEFAULT_STYLESHEET_KEYS.include?(attr 'stylesheet')
  if @safe >= SafeMode::SECURE || (attr? 'linkcss') %>
<link rel="stylesheet" href="<%= normalize_web_path(DEFAULT_STYLESHEET_NAME, (attr :stylesdir, '')) %>"><%
  else %>
<style>
<%= ::Asciidoctor::HTML5.default_asciidoctor_stylesheet %>
</style><%
  end
elsif attr? :stylesheet
  if attr? 'linkcss' %>
<link rel="stylesheet" href="<%= normalize_web_path((attr :stylesheet), (attr :stylesdir, '')) %>"><%
  else %>
<style>
<%= read_asset normalize_system_path((attr :stylesheet), (attr :stylesdir, '')), true %>
</style><%
  end
end
if attr? 'icons', 'font'
  if !(attr 'iconfont-remote', '').nil? %>
<link rel="stylesheet" href="<%= attr 'iconfont-cdn', 'http://cdnjs.cloudflare.com/ajax/libs/font-awesome/3.1.0/css' %>/<%= attr 'iconfont-name', 'font-awesome' %>.min.css"><%
  else %>
<link rel="stylesheet" href="<%= normalize_web_path(%(\#{attr 'iconfont-name', 'font-awesome'}.css), (attr 'stylesdir', '')) %>"><%
  end
end
case attr 'source-highlighter'
when 'coderay'
  if (attr 'coderay-css', 'class') == 'class' %>
<style>
<%= ::Asciidoctor::HTML5.default_coderay_stylesheet %>
</style><%
  end
when 'highlightjs', 'highlight.js' %>
<link rel="stylesheet" href="<%= attr :highlightjsdir, 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.3' %>/styles/<%= attr 'highlightjs-theme', 'default' %>.min.css">
<script src="<%= attr :highlightjsdir, 'http://cdnjs.cloudflare.com/ajax/libs/highlight.js/7.3' %>/highlight.min.js"></script>
<script>hljs.initHighlightingOnLoad()</script><%
when 'prettify' %>
<link rel="stylesheet" href="<%= attr 'prettifydir', 'http://cdnjs.cloudflare.com/ajax/libs/prettify/r298' %>/<%= attr 'prettify-theme', 'prettify' %>.min.css">
<script src="<%= attr 'prettifydir', 'http://cdnjs.cloudflare.com/ajax/libs/prettify/r298' %>/prettify.min.js"></script>
<script>document.addEventListener('DOMContentLoaded', prettyPrint)</script><%
end %><%= (docinfo_content = docinfo).empty? ? nil : %(
\#{docinfo_content}) %>
</head>
<body#{id} class="<%= doctype %><%= (attr? 'toc-class') && (attr? 'toc') && (attr? 'toc-placement', 'auto') ? %( \#{attr 'toc-class'}) : nil %>"<%= (attr? 'max-width') ? %( style="max-width: \#{attr 'max-width'};") : nil %>><%
unless noheader %>
<div id="header"><%
  if has_header?
    unless notitle %>
<h1><%= @header.title %></h1><%
    end %><%
    if attr? :author %>
<span id="author"><%= attr :author %></span><br><%
      if attr? :email %>
<span id="email"><%= sub_macros(attr :email) %></span><br><%
      end
    end
    if attr? :revnumber %>
<span id="revnumber">version <%= attr :revnumber %><%= (attr? :revdate) ? ',' : '' %></span><%
    end
    if attr? :revdate %>
<span id="revdate"><%= attr :revdate %></span><%
    end
    if attr? :revremark %>
<br><span id="revremark"><%= attr :revremark %></span><%
    end
  end
  if (attr? :toc) && (attr? 'toc-placement', 'auto') %>
<div id="toc" class="<%= attr 'toc-class', 'toc' %>">
<div id="toctitle"><%= attr 'toc-title' %></div>
<%= template.class.outline(self, (attr :toclevels, 2).to_i) %>
</div><%
  end %>
</div><%
end %>
<div id="content">
<%= content %>
</div><%
unless !footnotes? || (attr? :nofootnotes) %>
<div id="footnotes">
<hr><%
  footnotes.each do |fn| %>
<div class="footnote" id="_footnote_<%= fn.index %>">
<a href="#_footnoteref_<%= fn.index %>"><%= fn.index %></a>. <%= fn.text %>
</div><%
  end %>
</div><%
end %>
<div id="footer">
<div id="footer-text"><%
if attr? :revnumber %>
Version <%= attr :revnumber %><br><%
end %>
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
<% unless !footnotes? || (attr? :nofootnotes) %><div id="footnotes">
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

    return '' unless (doc.attr? 'toc')

    if node.id
      id_attr = %( id="#{node.id}")
      title_id_attr = ''
    elsif doc.embedded? || !(doc.attr? 'toc-placement')
      id_attr = ' id="toc"'
      title_id_attr = ' id="toctitle"'
    else
      id_attr = ''
      title_id_attr = ''
    end
    title = node.title? ? node.title : (doc.attr 'toc-title')
    levels = (node.attr? 'levels') ? (node.attr 'levels').to_i : (doc.attr 'toclevels', 2).to_i
    role = (node.attr? 'role') ? (node.attr 'role') : (doc.attr 'toc-class', 'toc')

    %(<div#{id_attr} class="#{role}">
<div#{title_id_attr} class="title">#{title}</div>
#{DocumentTemplate.outline(doc, levels)}
</div>\n)
  end

  def template
    :invoke_result
  end
end

class BlockPreambleTemplate < BaseTemplate
  def toc(node)
    if (node.attr? 'toc') && (node.attr? 'toc-placement', 'preamble')
      %(\n<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{DocumentTemplate.outline(node.document, (node.attr 'toclevels', 2).to_i)}
</div>)
    else
      ''
    end
  end

  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div id="preamble">
<div class="sectionbody">
<%= content %>
</div><%= template.toc(self) %>
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
    id = anchor = link_start = link_end = nil
    if sec.id
      id = %( id="#{sec.id}")
      if sec.document.attr? 'sectanchors'
        #if sec.document.attr? 'icons', 'font'
        #  anchor = %(<a class="anchor" href="##{sec.id}"><i class="icon-anchor"></i></a>)
        #else
          anchor = %(<a class="anchor" href="##{sec.id}"></a>)
        #end
      elsif sec.document.attr? 'sectlinks'
        link_start = %(<a class="link" href="##{sec.id}">)
        link_end = '</a>'
      end
    end

    if slevel == 0
      %(<h1#{id} class="sect0">#{anchor}#{link_start}#{sec.title}#{link_end}</h1>
#{sec.content}\n)
    else
      role = (sec.attr? 'role') ? " #{sec.attr 'role'}" : nil
      if !sec.special && (sec.document.attr? 'numbered') && slevel < 4
        sectnum = "#{sec.sectnum} "
      else
        sectnum = nil
      end

      if slevel == 1
        content = %(<div class="sectionbody">
#{sec.content}
</div>)
      else
        content = sec.content
      end
      %(<div class="sect#{slevel}#{role}">
<#{htag}#{id}>#{anchor}#{link_start}#{sectnum}#{sec.caption}#{sec.title}#{link_end}</#{htag}>
#{content}
</div>\n)
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
continuing = false
entries = content
last_index = entries.length - 1
if attr? 'style', 'qanda', false
%><div#{id} class="qlist#{style_class}#{role_class}"><%
if title? %>
<div class="title"><%= title %></div><%
end %>
<ol><%
  entries.each_with_index do |(dt, dd), index|
    last = (index == last_index)
    unless continuing %>
<li><%
    end %>
<p><em><%= dt.text %></em></p><%
    if !last && dd.nil?
      continuing = true
      next
    else
      continuing = false
    end
    unless dd.nil?
      if dd.text? %>
<p><%= dd.text %></p><%
      end
      if dd.blocks? %>
<%= dd.content %><%
      end
    end %>
</li><%
  end %>
</ol>
</div><%
elsif attr? 'style', 'horizontal', false
%><div#{id} class="hdlist#{role_class}"><%
if title? %>
<div class="title"><%= title %></div><%
end %>
<table><%
if (attr? :labelwidth) || (attr? :itemwidth) %>
<colgroup>
<col<% if attr? :labelwidth %> style="width:<%= (attr :labelwidth).chomp('%') %>%;"<% end %>>
<col<% if attr? :itemwidth %> style="width:<%= (attr :itemwidth).chomp('%') %>%;"<% end %>>
</colgroup><%
end %><%
  entries.each_with_index do |(dt, dd), index|
    last = (index == last_index)
    unless continuing %>
<tr>
<td class="hdlist1<%= (attr? 'strong-option') ? 'strong' : nil %>"><%
    end %>
<%= dt.text %>
<br><%
    if !last && dd.nil?
      continuing = true
      next
    else
      continuing = false
    end %>
</td>
<td class="hdlist2"><%
    unless dd.nil?
      if dd.text? %>
<p><%= dd.text %></p><%
      end
      if dd.blocks? %>
<%= dd.content %><%
      end
    end %>
</td>
</tr><%
  end %>
</table>
</div><%
else
%><div#{id} class="dlist#{style_class}#{role_class}"><%
if title? %>
<div class="title"><%= title %></div><%
end %>
<dl><%
  entries.each_with_index do |(dt, dd), index|
    last = (index == last_index) %>
<dt<%= !(attr? 'style', nil, false) ? %( class="hdlist1") : nil %>><%= dt.text %></dt><%
    unless dd.nil? %>
<dd><%
      if dd.text? %>
<p><%= dd.text %></p><%
      end %><%
      if dd.blocks? %>
<%= dd.content %><%
      end %>
</dd><%
    end
  end %>
</dl>
</div><%
end %>
    EOS
  end
end

class BlockListingTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="listingblock#{role_class}">
#{title_div :caption => true}
<div class="content monospaced"><%
if attr? 'style', 'source', false
  language = (language = (attr 'language')) ? %(\#{language} language-\#{language}) : nil
  case attr 'source-highlighter'
  when 'coderay'
    pre_class = ' class="CodeRay"'
    code_class = language ? %( class="\#{language}") : nil
  when 'highlightjs', 'highlight.js'
    pre_class = ' class="highlight"'
    code_class = language ? %( class="\#{language}") : nil
  when 'prettify'
    pre_class = %( class="prettyprint\#{(attr? 'linenums') ? ' linenums' : nil})
    pre_class = language ? %(\#{pre_class} \#{language}") : %(\#{pre_class}")
    code_class = nil
  else
    pre_class = ' class="highlight"'
    code_class = language ? %( class="\#{language}") : nil
  end %>
<pre<%= pre_class %>><code<%= code_class %>><%= template.preserve_endlines(content, self) %></code></pre><%
else %>
<pre><%= template.preserve_endlines(content, self) %></pre><%
end %>
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
<td class="icon"><%
if attr? 'icons', 'font' %>
<i class="icon-<%= attr :name %>" title="<%= @caption %>"></i><%
elsif attr? 'icons' %>
<img src="<%= icon_uri(attr :name) %>" alt="<%= @caption %>"><%
else %>
<div class="title"><%= @caption %></div><%
end %>
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
    %(<div#{id && " id=\"#{id}\""} class="paragraph#{role && " #{role}"}">#{title && "
<div class=\"title\">#{title}</div>"}
<p>#{content}</p>
</div>\n)
  end

  def result(node)
    paragraph(node.id, (node.attr 'role'), (node.title? ? node.title : nil), node.content)
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
  def result(node)
    open_block(node, node.id, (node.attr 'style', nil, false), (node.attr 'role'), node.title? ? node.title : nil, node.content)
  end

  def open_block(node, id, style, role, title, content)
    if style == 'abstract'
      if node.parent == node.document && node.document.attr?('doctype', 'book')
        puts 'asciidoctor: WARNING: abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
        ''
      else
        %(<div#{id && " id=\"#{id}\""} class="quoteblock abstract#{role && " #{role}"}">#{title &&
"<div class=\"title\">#{title}</div>"}
<blockquote>
#{content}
</blockquote>
</div>\n)
      end
    elsif style == 'partintro' && (!node.document.attr?('doctype', 'book') || !node.parent.is_a?(Asciidoctor::Section) || node.level != 0)
      puts 'asciidoctor: ERROR: partintro block can only be used when doctype is book and it\'s a child of a book part. Excluding block content.'
      ''
    else
      %(<div#{id && " id=\"#{id}\""} class="openblock#{style != 'open' ? " #{style}" : ''}#{role && " #{role}"}">#{title &&
"<div class=\"title\">#{title}</div>"}
<div class="content">
#{content}
</div>
</div>\n)
    end
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

class BlockQuoteTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="quoteblock#{role_class}">
#{title_div}
<blockquote>
<%= content %>
</blockquote><%
if (attr? :attribution) || (attr? :citetitle) %>
<div class="attribution"><%
  if attr? :citetitle %>
<cite><%= attr :citetitle %></cite><%
  end
  if attr? :attribution
    if attr? :citetitle %>
<br><%
    end %>
<%= "&#8212; \#{attr :attribution}" %><%
  end %>
</div><%
end %>
</div>
    EOS
  end
end

class BlockVerseTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="verseblock#{role_class}">
#{title_div}
<pre class="content"><%= template.preserve_endlines(content, self) %></pre><%
if (attr? :attribution) || (attr? :citetitle) %>
<div class="attribution"><%
  if attr? :citetitle %>
<cite><%= attr :citetitle %></cite><%
  end
  if attr? :attribution
    if attr? :citetitle %>
<br><%
    end %>
<%= "&#8212; \#{attr :attribution}" %><%
  end %>
  </div><%
end %>
</div>
    EOS
  end
end

class BlockUlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="ulist#{style_class}#{role_class}">
#{title_div}
<ul><%
content.each do |item| %>
<li>
<p><%= item.text %></p><%
  if item.blocks? %>
<%= item.content %><%
  end %>
</li><%
end %>
</ul>
</div>
    EOS
  end
end

class BlockOlistTemplate < BaseTemplate

  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><% style = attr 'style', nil, false %><div#{id} class="olist#{style_class}#{role_class}">
#{title_div}
<ol class="<%= style %>"<%= (type = ::Asciidoctor::ORDERED_LIST_KEYWORDS[style]) ? %( type="\#{type}") : nil %>#{attribute('start', :start)}><%
content.each do |item| %>
<li>
<p><%= item.text %></p><%
  if item.blocks? %>
<%= item.content %><%
  end %>
</li><%
end %>
</ol>
</div>
    EOS
  end
end

class BlockColistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="colist#{style_class}#{role_class}">
#{title_div}<%
if attr? :icons %>
<table><%
  content.each_with_index do |item, i| %>
<tr>
<td><%
    if attr? :icons, 'font' %><i class="conum"><%= i + 1 %></i><%
    else %><img src="<%= icon_uri("callouts/\#{i + 1}") %>" alt="<%= i + 1 %>"><%
    end %></td>
<td><%= item.text %></td>
</tr><%
  end %>
</table><%
else %>
<ol><%
  content.each do |item| %>
<li>
<p><%= item.text %></p>
</li><%
  end %>
</ol><%
end %>
</div>
    EOS
  end
end

class BlockTableTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><table#{id} class="tableblock frame-<%= attr :frame, 'all' %> grid-<%= attr :grid, 'all'%>#{role_class}" style="<%
if !(attr? 'autowidth-option') %>width:<%= attr :tablepcwidth %>%; <% end %><%
if attr? :float %>float: <%= attr :float %>; <% end %>"><%
if title? %>
<caption class="title"><% unless @caption.nil? %><%= @caption %><% end %><%= title %></caption><%
end
if (attr :rowcount) >= 0 %>
<colgroup><%
  if attr? 'autowidth-option'
    @columns.each do %>
<col><%
    end
  else
    @columns.each do |col| %>
<col style="width:<%= col.attr :colpcwidth %>%;"><%
    end
  end %> 
</colgroup><%
  [:head, :foot, :body].select {|tsec| !@rows[tsec].empty? }.each do |tsec| %>
<t<%= tsec %>><%
    @rows[tsec].each do |row| %>
<tr><%
      row.each do |cell| %>
<<%= tsec == :head ? 'th' : 'td' %> class="tableblock halign-<%= cell.attr :halign %> valign-<%= cell.attr :valign %>"#{attribute('colspan', 'cell.colspan')}#{attribute('rowspan', 'cell.rowspan')}<%
        cell_content = ''
        if tsec == :head
          cell_content = cell.text
        else
          case (cell.attr 'style', nil, false)
          when :asciidoc
            cell_content = %(<div>\#{cell.content}</div>)
          when :verse
            cell_content = %(<div class="verse">\#{template.preserve_endlines(cell.text, self)}</div>)
          when :literal
            cell_content = %(<div class="literal monospaced"><pre>\#{template.preserve_endlines(cell.text, self)}</pre></div>)
          when :header
            cell.content.each do |text|
              cell_content = %(\#{cell_content}<p class="tableblock header">\#{text}</p>)
            end
          else
            cell.content.each do |text|
              cell_content = %(\#{cell_content}<p class="tableblock">\#{text}</p>)
            end
          end
        end %><%= (@document.attr? 'cellbgcolor') ? %( style="background-color:\#{@document.attr 'cellbgcolor'};") : nil
        %>><%= cell_content %></<%= tsec == :head ? 'th' : 'td' %>><%
      end %>
</tr><%
    end %>
</t<%= tsec %>><%
  end
end %>
</table>
    EOS
  end
end

class BlockImageTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="imageblock#{style_class}#{role_class}"<%
if (attr? :align) || (attr? :float) %> style="<%
  if attr? :align %>text-align: <%= attr :align %><% if attr? :float %>; <% end %><% end %><% if attr? :float %>float: <%= attr :float %><% end %>"<%
end %>>
<div class="content"><%
if attr? :link %>
<a class="image" href="<%= attr :link %>"><img src="<%= image_uri(attr :target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}></a><%
else %>
<img src="<%= image_uri(attr :target) %>" alt="<%= attr :alt %>"#{attribute('width', :width)}#{attribute('height', :height)}><%
end %>
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
<audio src="<%= media_uri(attr :target) %>"<%
if attr? 'autoplay-option' %> autoplay<% end %><%
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
    %(<div style="page-break-after: always;"></div>\n)
  end

  def template
    :invoke_result
  end
end

class InlineBreakTemplate < BaseTemplate
  def result(node)
    %(#{node.text}<br>\n)
  end

  def template
    :invoke_result
  end
end

class InlineCalloutTemplate < BaseTemplate
  def result(node)
    if node.attr? 'icons', 'font'
      %(<i class="conum">#{node.text}</i>)
    elsif node.attr? 'icons'
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

  QUOTE_TAGS = {
    :emphasis => ['<em>', '</em>'],
    :strong => ['<strong>', '</strong>'],
    :monospaced => ['<code>', '</code>'],
    :superscript => ['<sup>', '</sup>'],
    :subscript => ['<sub>', '</sub>'],
    :double => ['&#8220;', '&#8221;'],
    :single => ['&#8216;', '&#8217;']
  }

  def quote_text(text, type, role)
    start_tag, end_tag = QUOTE_TAGS[type] || NO_TAGS
    if role
      if start_tag.start_with? '<'
        %(#{start_tag.chop} class="#{role}">#{text}#{end_tag})
      else
        %(#{start_tag}<span class="#{role}">#{text}</span>#{end_tag})
      end
    else
      "#{start_tag}#{text}#{end_tag}"
    end
  end

  def result(node)
    quote_text(node.text, node.type, (node.attr 'role'))
  end

  def template
    :invoke_result
  end
end

class InlineButtonTemplate < BaseTemplate
  def result(node)
    %(<b class="button">#{node.text}</b>)
  end

  def template
    :invoke_result
  end
end

class InlineKbdTemplate < BaseTemplate
  def result(node)
    keys = node.attr 'keys'
    if keys.size == 1
      %(<kbd>#{keys.first}</kbd>)
    else
      key_combo = keys.map{|key| %(<kbd>#{key}</kbd>+) }.join.chop
      %(<kbd class="keyseq">#{key_combo}</kbd>)
    end
  end

  def template
    :invoke_result
  end
end

class InlineMenuTemplate < BaseTemplate
  def menu(menu, submenus, menuitem)
    if !submenus.empty?
      submenu_path = submenus.map{|submenu| %(<span class="submenu">#{submenu}</span>&#160;&#9656; ) }.join.chop
      %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; #{submenu_path} <span class="menuitem">#{menuitem}</span></span>)
    elsif !menuitem.nil?
      %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; <span class="menuitem">#{menuitem}</span></span>)
    else
      %(<span class="menu">#{menu}</span>)
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
  def anchor(target, text, type, document, node)
    case type
    when :xref
      text = document.references[:ids].fetch(target, "[#{target}]") if text.nil?
      %(<a href="##{target}">#{text}</a>)
    when :ref
      %(<a id="#{target}"></a>)
    when :link
      %(<a href="#{target}"#{(node.attr? 'role') ? " class=\"#{node.attr 'role'}\"" : nil}#{(node.attr? 'window') ? " target=\"#{node.attr 'window'}\"" : nil}>#{text}</a>)
    when :bibref
      %(<a id="#{target}"></a>[#{target}])
    end
  end

  def result(node)
    anchor(node.target, node.text, node.type, node.document, node)
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
