require 'asciidoctor/backends/_stylesheets'

module Asciidoctor
class BaseTemplate
  # create template matter to insert a style class from the role attribute if specified
  def role_class
    %(<%= role? ? " \#{role}" : nil %>)
  end

  # create template matter to insert a style class from the style attribute if specified
  def style_class(sibling = true)
    delimiter = sibling ? ' ' : ''
    %(<%= @style && "#{delimiter}\#{@style}" %>)
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
      toc_level = %(<ul class="sectlevel#{sec_level}">\n)
      sections.each do |section|
        section_num = section.numbered ? %(#{section.sectnum} ) : nil
        toc_level = %(#{toc_level}<li><a href=\"##{section.id}\">#{section_num}#{section.captioned_title}</a></li>\n)
        if section.level < to_depth && (child_toc_level = outline(section, to_depth))
          toc_level = %(#{toc_level}<li>\n#{child_toc_level}\n</li>\n)
        end
      end
      toc_level = %(#{toc_level}</ul>)
    end
    toc_level
  end

  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><!DOCTYPE html>
<html<%= (attr? 'nolang') ? nil : %( lang="\#{attr 'lang', 'en'}") %>>
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
<title><%= doctitle(:sanitize => true) || (attr 'untitled-label') %></title><%
if DEFAULT_STYLESHEET_KEYS.include?(attr 'stylesheet')
  if @safe >= SafeMode::SECURE || (attr? 'linkcss') %>
<link rel="stylesheet" href="<%= normalize_web_path(DEFAULT_STYLESHEET_NAME, (attr :stylesdir, '')) %>"><%
  else %>
<style>
<%= ::Asciidoctor::HTML5.default_asciidoctor_stylesheet %>
</style><%
  end
elsif attr? :stylesheet
  if @safe >= SafeMode::SECURE || (attr? 'linkcss') %>
<link rel="stylesheet" href="<%= normalize_web_path((attr :stylesheet), (attr :stylesdir, '')) %>"><%
  else %>
<style>
<%= read_asset normalize_system_path((attr :stylesheet), (attr :stylesdir, '')), true %>
</style><%
  end
end
if attr? 'icons', 'font'
  if !(attr 'iconfont-remote', '').nil? %>
<link rel="stylesheet" href="<%= attr 'iconfont-cdn', 'http://cdnjs.cloudflare.com/ajax/libs/font-awesome/3.2.1/css/font-awesome.min.css' %>"><%
  else %>
<link rel="stylesheet" href="<%= normalize_web_path(%(\#{attr 'iconfont-name', 'font-awesome'}.css), (attr 'stylesdir', '')) %>"><%
  end
end
case attr 'source-highlighter'
when 'coderay'
  if (attr 'coderay-css', 'class') == 'class'
    if @safe >= SafeMode::SECURE || (attr? 'linkcss') %>
<link rel="stylesheet" href="<%= normalize_web_path('asciidoctor-coderay.css', (attr :stylesdir, '')) %>"><%
    else %>
<style>
<%= ::Asciidoctor::HTML5.default_coderay_stylesheet %>
</style><%
    end
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
<body#{id} class="<%= doctype %><%= (attr? 'toc-class') && (attr? 'toc') && (attr? 'toc-placement', 'auto') ? %( \#{attr 'toc-class'} toc-\#{attr 'toc-position'}) : nil %>"<%= (attr? 'max-width') ? %( style="max-width: \#{attr 'max-width'};") : nil %>><%
unless noheader %>
<div id="header"><%
  if doctype == 'manpage' %>
<h1><%= doctitle %> Manual Page</h1><%
    if (attr? :toc) && (attr? 'toc-placement', 'auto') %>
<div id="toc" class="<%= attr 'toc-class', 'toc' %>">
<div id="toctitle"><%= attr 'toc-title' %></div>
<%= template.class.outline(self, (attr :toclevels, 2).to_i) %>
</div><%
    end %>
<h2><%= attr 'manname-title' %></h2>
<div class="sectionbody">
<p><%= %(\#{attr 'manname'} - \#{attr 'manpurpose'}) %></p>
</div><%
  else
    if has_header?
      unless notitle %>
<h1><%= @header.title %></h1><%
      end %><%
      if attr? :author %>
<span id="author" class="author"><%= attr :author %></span><br><%
        if attr? :email %>
<span id="email" class="email"><%= sub_macros(attr :email) %></span><br><%
        end
        if (authorcount = (attr :authorcount).to_i) > 1
          (2..authorcount).each do |idx| %><span id="author<%= idx %>" class="author"><%= attr "author_\#{idx}" %></span><br><%
            if attr? "email_\#{idx}" %>
<span id="email<%= idx %>" class="email"><%= sub_macros(attr "email_\#{idx}") %></span><br><%
            end
          end
        end
      end
      if attr? :revnumber %>
<span id="revnumber"><%= ((attr 'version-label') || '').downcase %> <%= attr :revnumber %><%= (attr? :revdate) ? ',' : '' %></span><%
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
    end
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
<%= %(\#{attr 'version-label'} \#{attr :revnumber}) %><br><%
end
if attr? 'last-update-label' %>
<%= %(\#{attr 'last-update-label'} \#{attr :docdatetime}) %><%
end %>
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
    role = node.role? ? node.role : (doc.attr 'toc-class', 'toc')

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
      role = sec.role? ? " #{sec.role}" : nil
      if sec.numbered
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
<#{htag}#{id}>#{anchor}#{link_start}#{sectnum}#{sec.captioned_title}#{link_end}</#{htag}>
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
if @style == 'qanda'
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
elsif @style == 'horizontal'
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
<td class="hdlist1<%= (option? 'strong') ? 'strong' : nil %>"><%
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
<dt<%= @style.nil? ? %( class="hdlist1") : nil %>><%= dt.text %></dt><%
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
  def result(node)
    nowrap = (!node.document.attr? 'prewrap') || (node.option? 'nowrap')
    if node.style == 'source'
      language = node.attr 'language'
      language_classes = language ? %(#{language} language-#{language}) : nil
      case node.attr 'source-highlighter'
      when 'coderay'
        pre_class = nowrap ? ' class="CodeRay nowrap"' : ' class="CodeRay"'
        code_class = language ? %( class="#{language_classes}") : nil
      when 'highlightjs', 'highlight.js'
        pre_class = nowrap ? ' class="highlight nowrap"' : ' class="highlight"'
        code_class = language ? %( class="#{language_classes}") : nil
      when 'prettify'
        pre_class = %( class="prettyprint#{nowrap ? ' nowrap' : nil}#{(node.attr? 'linenums') ? ' linenums' : nil})
        pre_class = language ? %(#{pre_class} #{language_classes}") : %(#{pre_class}")
        code_class = nil
      when 'html-pipeline'
        pre_class = language ? %( lang="#{language}") : nil
        code_class = nil
      else
        pre_class = nowrap ? ' class="highlight nowrap"' : ' class="highlight"'
        code_class = language ? %( class="#{language_classes}") : nil
      end
      pre = %(<pre#{pre_class}><code#{code_class}>#{preserve_endlines(node.content, node)}</code></pre>)
    else
      pre = %(<pre#{nowrap ? ' class="nowrap"' : nil}>#{preserve_endlines(node.content, node)}</pre>)
    end

    %(<div#{node.id && " id=\"#{node.id}\""} class="listingblock#{node.role && " #{node.role}"}">#{node.title? ? "
<div class=\"title\">#{node.captioned_title}</div>" : nil}
<div class="content monospaced">
#{pre}
</div>
</div>\n)
  end

  def template
    :invoke_result
  end
end

class BlockLiteralTemplate < BaseTemplate
  def result(node)
    nowrap = (!node.document.attr? 'prewrap') || (node.option? 'nowrap')
    %(<div#{node.id && " id=\"#{node.id}\""} class="literalblock#{node.role && " #{node.role}"}">#{node.title? ? "
<div class=\"title\">#{node.title}</div>" : nil}
<div class="content monospaced">
<pre#{nowrap ? ' class="nowrap"' : nil}>#{preserve_endlines(node.content, node)}</pre>
</div>
</div>\n)
  end

  def template
    :invoke_result
  end
end

class BlockAdmonitionTemplate < BaseTemplate
  def result(node)
    id = node.id
    name = node.attr 'name'
    role = node.role
    title = node.title? ? node.title : nil
    if node.document.attr? 'icons'
      if node.document.attr? 'icons', 'font'
        caption = %(<i class="icon-#{name}" title="#{node.caption}"></i>)
      else
        caption = %(<img src="#{node.icon_uri(name)}" alt="#{node.caption}">)
      end
    else
      caption = %(<div class="title">#{node.caption}</div>)
    end
    %(<div#{id && " id=\"#{id}\""} class="admonitionblock #{name}#{role && " #{role}"}">
<table>
<tr>
<td class="icon">
#{caption}
</td>
<td class="content">#{title ? "
<div class=\"title\">#{title}</div>" : nil}
#{node.content}
</td>
</tr>
</table>
</div>\n)
  end

  def template
    :invoke_result
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
    paragraph(node.id, node.role, (node.title? ? node.title : nil), node.content)
  end

  def template
    :invoke_result
  end
end

class BlockSidebarTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="sidebarblock#{role_class}">
<div class="content"><%= title? ? %(
<div class="title">\#{title}</div>) : nil %>
<%= content %>
</div>
</div>
    EOS
  end
end

class BlockExampleTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="exampleblock#{role_class}"><%= title? ? %(
<div class="title">\#{captioned_title}</div>) : nil %>
<div class="content">
<%= content %>
</div>
</div>
    EOS
  end
end

class BlockOpenTemplate < BaseTemplate
  def result(node)
    open_block(node, node.id, node.style, node.role, node.title? ? node.title : nil, node.content)
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
<%#encoding:UTF-8%><div#{id} class="quoteblock#{role_class}"><%= title? ? %(
<div class="title">\#{title}</div>) : nil %>
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
<%#encoding:UTF-8%><div#{id} class="verseblock#{role_class}"><%= title? ? %(
<div class="title">\#{title}</div>) : nil %>
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
<%#encoding:UTF-8%><div#{id} class="ulist<%= (checklist = (option? 'checklist')) ? ' checklist' : nil %>#{style_class}#{role_class}"><%= title? ? %(
<div class="title">\#{title}</div>) : nil %>
<ul<%= checklist ? ' class="checklist"' : (!@style.nil? ? %( class="\#{@style}") : nil) %>><%
if checklist
  # could use &#9745 (checked ballot) and &#9744 (ballot) w/o font instead
  marker_checked = (@document.attr? 'icons', 'font') ? '<i class="icon-check"></i> ' : '<input type="checkbox" data-item-complete="1" checked disabled> '
  marker_unchecked = (@document.attr? 'icons', 'font') ? '<i class="icon-check-empty"></i> ' : '<input type="checkbox" data-item-complete="0" disabled> '
end
content.each do |item| %>
<li>
<p><% if checklist && (item.attr? 'checkbox') %><%= (item.attr? 'checked') ? marker_checked : marker_unchecked %><% end %><%= item.text %></p><%
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
<%#encoding:UTF-8%><div#{id} class="olist#{style_class}#{role_class}"><%= title? ? %(
<div class="title">\#{title}</div>) : nil %>
<ol class="<%= @style %>"<%= (keyword = list_marker_keyword) ? %( type="\#{keyword}") : nil %>#{attribute('start', :start)}><%
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
<%#encoding:UTF-8%><div#{id} class="colist#{style_class}#{role_class}"><%= title? ? %(
<div class="title">\#{title}</div>) : nil %><%
if @document.attr? 'icons' %>
<table><%
  content.each_with_index do |item, i| %>
<tr>
<td><%
    if @document.attr? 'icons', 'font' %><%= %(<i class="conum" data-value="\#{i + 1}"></i><b>\#{i + 1}</b>) %><%
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
if !(option? 'autowidth') %>width:<%= attr :tablepcwidth %>%; <% end %><%
if attr? :float %>float: <%= attr :float %>; <% end %>"><%
if title? %>
<caption class="title"><%= captioned_title %></caption><%
end
if (attr :rowcount) >= 0 %>
<colgroup><%
  if option? 'autowidth'
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
          case cell.style
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
</div><%= title? ? %(
<div class="title">\#{captioned_title}</div>) : nil %>
</div>
    EOS
  end
end

class BlockAudioTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div#{id} class="audioblock#{style_class}#{role_class}"><%= title? ? %(
<div class="title">\#{captioned_title}</div>) : nil %>
<div class="content">
<audio src="<%= media_uri(attr :target) %>"<%
if option? 'autoplay' %> autoplay<% end %><%
unless option? 'nocontrols' %> controls<% end %><%
if option? 'loop' %> loop<% end %>>
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
<%#encoding:UTF-8%><div#{id} class="videoblock#{style_class}#{role_class}"><%= title? ? %(
<div class="title">\#{captioned_title}</div>) : nil %>
<div class="content">
<video src="<%= media_uri(attr :target) %>"#{attribute('width', :width)}#{attribute('height', :height)}<%
if attr? 'poster' %> poster="<%= media_uri(attr :poster) %>"<% end %><%
if option? 'autoplay' %> autoplay<% end %><%
unless option? 'nocontrols' %> controls<% end %><%
if option? 'loop' %> loop<% end %>>
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
    if node.document.attr? 'icons', 'font'
      %(<i class="conum" data-value="#{node.text}"></i><b>(#{node.text})</b>)
    elsif node.document.attr? 'icons'
      src = node.icon_uri("callouts/#{node.text}")
      %(<img src="#{src}" alt="#{node.text}">)
    else
      "<b>(#{node.text})</b>"
    end
  end

  def template
    :invoke_result
  end
end

class InlineQuotedTemplate < BaseTemplate
  NO_TAGS = [nil, nil, nil]

  QUOTE_TAGS = {
    :emphasis => ['<em>', '</em>', true],
    :strong => ['<strong>', '</strong>', true],
    :monospaced => ['<code>', '</code>', true],
    :superscript => ['<sup>', '</sup>', true],
    :subscript => ['<sub>', '</sub>', true],
    :double => ['&#8220;', '&#8221;', false],
    :single => ['&#8216;', '&#8217;', false]
  }

  def quote_text(text, type, id, role)
    open, close, is_tag = QUOTE_TAGS[type] || NO_TAGS
    anchor = id.nil? ? nil : %(<a id="#{id}"></a>)
    if role
      if is_tag
        quoted_text = %(#{open.chop} class="#{role}">#{text}#{close})
      else
        quoted_text = %(<span class="#{role}">#{open}#{text}#{close}</span>)
      end
    elsif open.nil?
      quoted_text = text
    else
      quoted_text = %(#{open}#{text}#{close})
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
      %(<a href="#{target}"#{node.role? ? " class=\"#{node.role}\"" : nil}#{(node.attr? 'window') ? " target=\"#{node.attr 'window'}\"" : nil}>#{text}</a>)
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
  def image(target, type, node)
    if type == 'icon' && (node.document.attr? 'icons', 'font') 
      style_class = "icon-#{target}"
      if node.attr? 'size'
        style_class = "#{style_class} icon-#{node.attr 'size'}"
      end
      if node.attr? 'rotate'
        style_class = "#{style_class} icon-rotate-#{node.attr 'rotate'}"
      end
      if node.attr? 'flip'
        style_class = "#{style_class} icon-flip-#{node.attr 'flip'}"
      end
      img = %(<i class="#{style_class}"></i>)
      span = false
    else
      if type == 'icon'
        resolved_target = node.icon_uri target
      else
        resolved_target = node.image_uri target
      end

      attrs = ['alt', 'width', 'height', 'title'].map {|name|
        if node.attr? name
          %( #{name}="#{node.attr name}")
        else
          nil
        end
      }.join

      img = %(<img src="#{resolved_target}"#{attrs}>)
      span = true
    end

    if node.attr? 'link'
      img = %(<a class="image" href="#{node.attr 'link'}"#{(node.attr? 'window') ? " target=\"#{node.attr 'window'}\"" : nil}>#{img}</a>)
    end

    span ? %(<span class="image#{node.role? ? " #{node.role}" : nil}">#{img}</span>) : img
  end

  def result(node)
    image(node.target, node.type, node)
  end

  def template
    :invoke_result
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
