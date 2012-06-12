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
      <div class='man-page'>
        <div id='header'>
          <% if document %>
            <% if document.header %>
              <h2><%= document.header.name %></h2>
              <div class='sectionbody'><%= document.header.content %></div>
            <% elsif document.preamble %>
              <div class=preamble'>
                <div class='sectionbody'>
                  <%= document.preamble.content %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <%= content %>
      </div>
    EOF
  end
end

class SectionTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='sect<%= level %>'>
        <% if !anchor.nil? %>
          <a name='<%= anchor %>'>
        <% end %>
        <h<%= level + 1 %> id='<%= section_id %>'><%= name %></h<%= level + 1 %>>
        <% if !anchor.nil? %>
          </a>
        <% end %>
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
            <dt class='hdlist1'><%= dt %></dt>
            <% unless dd.nil? || dd.empty? %>
              <dd><%= dd %></dd>
            <% end %>
          <% end %>
        </dl>
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

class SectionParagraphTemplate < BaseTemplate
  def template
    @template ||= ERB.new <<-EOF
      <div class='paragraph'>
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
            <li><p><%= li %></p></li>
          <% end %>
        </ul>
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
../gitscm-next/templates/section_listing.html.erb
<div class='listingblock'>
  <div class='content'>
    <pre><tt><%= content %></tt></pre>
  </div>
</div>
../gitscm-next/templates/section_note.html.erb
<div class='admonitionblock'>
  <table>
    <tr>
      <td class='icon'><div class='title'>Note</div></td>
      <td class='content'><%= content %></td>
    </tr>
  </table>
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
