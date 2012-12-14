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
  end

  def template
    raise "You chilluns need to make your own template"
  end
end

class DocumentTemplate < BaseTemplate
  def template
    @template ||= ::ERB.new <<-EOF
      <!DOCTYPE html>
      <html lang='en'>
        <head>
          <meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>
          <meta name='generator' content='Asciidoctor <%= attributes["asciidoctor-version"] %>'>
          <title><%= title ? title : (doctitle ? doctitle : '') %></title>
        </head>
        <body class='<%= attributes["doctype"] %>'>
          <div id='header'>
            <% if doctitle %>
              <h1><%= doctitle %></h1>
            <% end %>
          </div>
          <div id='content'>
            <%= content %>
          </div>
          <div id='footer'>
            <div id='footer-text'>
              Last updated <%= [attributes['localdate'], attributes['localtime']].join(' ') %>
            </div>
          </div>
        </body>
      </html>
    EOF
  end
end

class SectionPreambleTemplate < BaseTemplate
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
      <div class='sect<%= level %>'>
        <% if !anchor.nil? %>
          <a name='<%= anchor %>'></a>
        <% end %>
        <h<%= level + 1 %> id='<%= section_id %>'><%= name %></h<%= level + 1 %>>
        <% if level == 1 %>
          <div class='sectionbody'><%= content %></div>
        <% else %>
          <%= content %>
        <% end %>
      </div>
    EOF
  end
end

class SectionAnchorTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <a name='<%= content %>'></a>
    EOF
  end
end

class SectionDlistTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='dlist'>
        <dl>
          <% content.each do |dt, dd| %>
            <dt class='hdlist1'>
              <% if !dt.anchor.nil? and !dt.anchor.empty? %>
              <a id='<%= dt.anchor %>'></a>
              <% end %>
              <%= dt.text %>
            </dt>
            <% unless dd.nil? %>
              <dd>
                <p><%= dd.text %></p>
                <% if !dd.blocks.empty? %>
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

class SectionListingTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='listingblock'>
        <div class='content'>
          <div class='highlight'>
            <pre><%= content %></pre>
          </div>
        </div>
      </div>
    EOF
  end
end

class SectionLiteralTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='literalblock'>
        <div class='content'>
          <pre><tt><%= content %></tt></pre>
        </div>
      </div>
    EOF
  end
end

class SectionNoteTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='admonitionblock'>
        <table>
          <tr>
            <td class='icon'></td>
            <td class='content'>
              <% if !title.nil? %>
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

class SectionParagraphTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='paragraph'>
        <% if !title.nil? %>
          <div class='title'><%= title %></div>
        <% end %>
        <p><%= content %></p>
      </div>
    EOF
  end
end

class SectionSidebarTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='sidebarblock'>
        <div class='content'>
          <p><%= content %></p>
        </div>
      </div>
    EOF
  end
end

class SectionUlistTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='ulist'>
        <ul>
        <% content.each do |li| %>
          <li>
            <p><%= li.text %></p>
            <% if !li.blocks.empty? %>
            <%= li.content %>
            <% end %>
          </li>
        <% end %>
        </ul>
      </div>
    EOF
  end
end

class SectionOlistTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='olist arabic'>
        <ol class='arabic'>
        <% content.each do |li| %>
          <li>
            <p><%= li.text %></p>
            <% if !li.blocks.empty? %>
            <%= li.content %>
            <% end %>
          </li>
        <% end %>
        </ol>
      </div>
    EOF
  end
end

=begin
../gitscm-next/templates/section_colist.html.erb
<div class='colist arabic'>
  <ol>
    <% content.each do |li| %>
      <li><p><%= li %></p></li>
    <% end %>
  </ol>
</div>
../gitscm-next/templates/section_example.html.erb
<div class='exampleblock'>
  <div class='content'>
    <div class='literalblock'>
      <div class='content'>
        <pre><tt><%= content %></tt></pre>
      </div>
    </div>
  </div>
</div>
../gitscm-next/templates/section_oblock.html.erb
<div class='openblock'>
  <div class='content'>
    <%= content %>
  </div>
</div>
../gitscm-next/templates/section_olist.html.erb
<div class='olist arabic'>
  <ol class='arabic'>
    <% content.each do |li| %>
      <li><p><%= li %></p></li>
    <% end %>
  </ol>
</div>
../gitscm-next/templates/section_quote.html.erb
<div class='quoteblock'>
  <div class='content'>
    <%= content %>
  </div>
</div>
../gitscm-next/templates/section_verse.html.erb
<div class='verseblock'>
  <pre class='content'><%= content %></pre>
</div>
=end
