class BaseTemplate
  BLANK_LINES_PATTERN = /^\s*\n/
  LINE_FEED_ENTITY = '&#10;' # or &#x0A;

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

  def initialize
  end

  def self.inherited(klass)
    @template_classes ||= []
    @template_classes << klass
  end

  def self.template_classes
    @template_classes
  end

  # We're ignoring locals for now. Shut up.
  def render(obj = Object.new, locals = {})
    output = template.result(obj.instance_eval {binding})
    (self.is_a?(DocumentTemplate) || self.is_a?(EmbeddedTemplate)) ? output.gsub(BLANK_LINES_PATTERN, '').gsub(LINE_FEED_ENTITY, "\n") : output
  end

  def template
    raise "You chilluns need to make your own template"
  end

  # create template matter to insert an attribute if the variable has a value
  def attribute(name, var = nil)
    var = var.nil? ? name : var
    if var.is_a? Symbol
      '<%= attr?(:' + var.to_s + ') ? ' + '\' ' + name + '=\\\'\' + attr(:' + var.to_s + ') + \'\\\'\' : \'\' %>'
    else
      '<%= ' + var + ' ? ' + '\' ' + name + '=\\\'\' + ' + var + ' + \'\\\'\' : \'\' %>'
    end
  end

  # create template matter to insert a style class if the variable has a value
  def styleclass(key, offset = true)
    '<%= attr?(:' + key.to_s + ') ? ' + (offset ? '\' \' + ' : '') + 'attr(:' + key.to_s + ') : \'\' %>'
  end

  # create template matter to insert an id if one is specified for the block
  def id
    attribute('id')
  end

  # create template matter to insert a style class from the role attribute if specified
  def role
    styleclass(:role)
  end
end

class DocumentTemplate < BaseTemplate
  def template
    @template ||= ::ERB.new <<-EOF
<%#encoding:UTF-8%>
<!DOCTYPE html>
<html lang='en'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=<%= attr :encoding %>'>
    <meta name='generator' content='Asciidoctor <%= attr 'asciidoctor-version' %>'>
    <% if attr? :description %><meta name='description' content='<%= attr :description %>'><% end %>
    <% if attr? :keywords %><meta name='keywords' content='<%= attr :keywords %>'><% end %>
    <title><%= doctitle %></title>
    <% unless attr(:stylesheet, '').empty? %>
    <link rel='stylesheet' href='<%= attr(:stylesdir, '') + attr(:stylesheet) %>' type='text/css'>
    <% end %>
  </head>
  <body class='<%= doctype %>'>
    <% unless noheader %>
    <div id='header'>
      <% if has_header %>
      <% unless notitle %>
      <h1><%= header.title %></h1>
      <% end %>
      <% if attr? :author %><span id='author'><%= attr :author %></span><br><% end %>
      <% if attr? :email %><span id='email' class='monospaced'>&lt;<%= attr :email %>&gt;</span><br><% end %>
      <% if attr? :revnumber %><span id='revnumber'>version <%= attr :revnumber %><%= attr?(:revdate) ? ',' : '' %></span><% end %>
      <% if attr? :revdate %><span id='revdate'><%= attr :revdate %></span><% end %>
      <% if attr? :revremark %><br><span id='revremark'><%= attr :revremark %></span><% end %>
      <% end %>
    </div>
    <% end %>
    <div id='content'>
<%= content %>
    </div>
    <div id='footer'>
      <div id='footer-text'>
        Last updated <%= attr :localdatetime %>
      </div>
    </div>
  </body>
</html>
    EOF
  end
end

class EmbeddedTemplate < BaseTemplate
  def template
    @template ||= ::ERB.new <<-EOF
<%#encoding:UTF-8%>
<%= content %>
    EOF
  end
end

class BlockPreambleTemplate < BaseTemplate
  def template
    @template ||= ::ERB.new <<-EOF
<div id='preamble'>
  <div class='sectionbody'>
<%= content %>
  </div>
</div>
    EOF
  end
end

class SectionTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<% if level == 0 %>
<h1#{id}><%= title %></h1>
<%= content %>
<% else %>
<div class='sect<%= level %>#{role}'>
  <h<%= level + 1 %>#{id}><%= title %></h<%= level + 1 %>>
  <% if level == 1 %>
  <div class='sectionbody'>
<%= content %>
  </div>
  <% else %>
<%= content %>
  <% end %>
</div>
<% end %>
    EOF
  end
end

class BlockDlistTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='dlist#{role}'>
  <% if title %>
  <div class='title'><%= title %></div>
  <% end %>
  <dl>
    <% content.each do |dt, dd| %>
    <dt class='hdlist1'>
      <% unless dt.anchor.nil? || dt.anchor.empty? %>
      <a id='<%= dt.anchor %>'></a>
      <% end %>
      <%= dt.text %>
    </dt>
    <% unless dd.nil? %>
    <dd>
      <% unless dd.text.empty? %>
      <p><%= dd.text %></p>
      <% end %>
      <% unless dd.blocks.empty? %>
<%= dd.content %> 
      <% end %>
    </dd>
    <% end %>
    <% end %>
  </dl>
</div>
    EOF
  end
end

class BlockListingTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='listingblock#{role}'>
  <% if title %>
  <div class='title'><%= title %></div>
  <% end %>
  <div class='content monospaced'>
    <pre class='highlight#{styleclass(:language)}'><code><%= content.gsub("\n", LINE_FEED_ENTITY) %></code></pre>
  </div>
</div>
    EOF
  end
end

class BlockLiteralTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='literalblock#{role}'>
  <% if title %>
  <div class='title'><%= title %></div>
  <% end %>
  <div class='content monospaced'>
    <pre><%= content.gsub("\n", LINE_FEED_ENTITY) %></pre>
  </div>
</div>
    EOF
  end
end

class BlockAdmonitionTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='admonitionblock#{role}'>
  <table>
    <tr>
      <td class='icon'>
        <% if attr? :caption %>
        <div class='title'><%= attr :caption %></div>
        <% end %>
      </td>
      <td class='content'>
        <% unless title.nil? %>
        <div class='title'><%= title %></div>
        <% end %>
        <%= content %>
      </td>
    </tr>
  </table>
</div>
    EOF
  end
end

class BlockParagraphTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<%#encoding:UTF-8%>
<div#{id} class='paragraph#{role}'>
  <% unless title.nil? %>
  <div class='title'><%= title %></div>
  <% end %>
  <p><%= content %></p>
</div>
    EOF
  end
end

class BlockSidebarTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='sidebarblock#{role}'>
  <div class='content'>
    <% unless title.nil? %>
    <div class='title'><%= title %></div>
    <% end %>
<%= content %>
  </div>
</div>
    EOF
  end
end

class BlockExampleTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='exampleblock#{role}'>
  <div class='content'>
    <% unless title.nil? %>
    <div class='title'><%= title %></div>
    <% end %>
<%= content %>
  </div>
</div>
    EOF
  end
end

class BlockOpenTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='openblock#{role}'>
  <% unless title.nil? %>
  <div class='title'><%= title %></div>
  <% end %>
  <div class='content'>
<%= content %>
  </div>
</div>
    EOF
  end
end

class BlockQuoteTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='quoteblock#{role}'>
  <% unless title.nil? %>
  <div class='title'><%= title %></div>
  <% end %>
  <div class='content'>
<%= content %>
  </div>
  <div class='attribution'>
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
    EOF
  end
end

class BlockVerseTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='verseblock#{role}'>
  <% unless title.nil? %>
  <div class='title'><%= title %></div>
  <% end %>
  <pre class='content'><%= content.gsub("\n", LINE_FEED_ENTITY) %></pre>
  <div class='attribution'>
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
    EOF
  end
end

class BlockUlistTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='ulist#{styleclass(:style)}#{role}'>
  <% unless title.nil? %>
  <div class='title'><%= title %></div>
  <% end %>
  <ul>
  <% content.each do |li| %>
    <li>
      <p><%= li.text %></p>
      <% unless li.blocks.empty? %>
<%= li.content %>
      <% end %>
    </li>
  <% end %>
  </ul>
</div>
    EOF
  end
end

class BlockOlistTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='olist <%= attr :style %>#{role}'>
  <% unless title.nil? %>
  <div class='title'><%= title %></div>
  <% end %>
  <ol class='<%= attr :style %>'#{attribute('start', :start)}>
  <% content.each do |li| %>
    <li>
      <p><%= li.text %></p>
      <% unless li.blocks.empty? %>
<%= li.content %>
      <% end %>
    </li>
  <% end %>
  </ol>
</div>
    EOF
  end
end

class BlockImageTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<div#{id} class='imageblock#{role}'>
  <div class='content'>
    <% if attr :link %>
    <a class='image' href='<%= attr :link %>'><img src='<%= attr :target %>' alt='<%= attr :alt %>'#{attribute('width', :width)}#{attribute('height', :height)}></a>
    <% else %>
    <img src='<%= attr :target %>' alt='<%= attr :alt %>'#{attribute('width', :width)}#{attribute('height', :height)}>
    <% end %>
  </div>
  <% if title %>
  <div class='title'><%= title %></div>
  <% end %>
</div>
    EOF
  end
end

class BlockRulerTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<hr>
    EOF
  end
end

class InlineBreakTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<%= text %><br>
    EOF
  end
end

class InlineCalloutTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<b><%= text %></b>
    EOF
  end
end

class InlineQuotedTemplate < BaseTemplate
  # we use double quotes for the class attribute to prevent quote processing
  # seems hackish, though AsciiDoc has this same issue
  def template
    @template ||= ERB.new <<-EOF
<%= QUOTED_TAGS[type].first %><% 
if attr? :role %><span class="#{styleclass(:role, false)}"><%
end %><%= text %><%
if attr? :role %></span><%
end %><%= QUOTED_TAGS[type].last %>
    EOF
  end
end

class InlineLinkTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
<a href='<%= target %>'><%= text %></a>
    EOF
  end
end

class InlineImageTemplate < BaseTemplate
  def template
    # care is taken here to avoid a space inside the optional <a> tag
    @template ||= ERB.new <<-EOF
<span class='image#{role}'>
  <%
  if attr :link %><a class='image' href='<%= attr :link %>'><%
  end %><img src='<%= target %>' alt='<%= attr :alt %>'#{attribute('width', :width)}#{attribute('height', :height)}#{attribute('title', :title)}><%
  if attr :link%></a><% end
  %>
</span>
    EOF
  end
end
