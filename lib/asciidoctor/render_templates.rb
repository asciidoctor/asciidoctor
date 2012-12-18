class BaseTemplate
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
    self.is_a?(DocumentTemplate) ? output.gsub(/^\s*\n/, '') : output
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
  def styleclass(key)
    '<%= attr?(:' + key.to_s + ') ? \' \' + attr(:' + key.to_s + ') : \'\' %>'
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
      <% unless notitle || !has_header %>
      <h1><%= header.title %></h1>
      <% if attr? :author %><span id='author'><%= attr :author %></span><br><% end %>
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
<h1 id='<%= id ? id : section_id %>'><%= title %></h1>
<%= content %>
<% else %>
<div class='sect<%= level %>#{role}'>
  <h<%= level + 1 %> id='<%= id ? id : section_id %>'><%= title %></h<%= level + 1 %>>
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
      <p><%= dd.text %></p>
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
    <pre class='highlight#{styleclass(:language)}'><code><%= content %></code></pre>
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
    <pre><%= content %></pre>
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
  <pre class='content'><%= content %></pre>
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
<div#{id} class='ulist#{role}'>
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
