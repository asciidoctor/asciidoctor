module Asciidoctor
  # A built-in {Converter} implementation that generates Troff Manpage output
  # consistent with the a2x tool from AsciiDoc Python.
  class Converter::ManPageConverter < Converter::BuiltIn
    QUOTE_TAGS = {
      :emphasis    => ['\fI',      '\fR',       true],
      :strong      => ['\fB',      '\fR',       true],
      :monospaced  => ['<code>',   '</code>',   true],
      :superscript => ['<sup>',    '</sup>',    true],
      :subscript   => ['<sub>',    '</sub>',    true],
      :double      => ['"',        '"',         false],
      :single      => ["'",        "'",         false],
      :mark        => ['<mark>',   '</mark>',   true],
      :asciimath   => ['\\$',      '\\$',       false],
      :latexmath   => ['\\(',      '\\)',       false]
      # Opal can't resolve these constants when referenced here
      #:asciimath   => INLINE_MATH_DELIMITERS[:asciimath] + [false],
      #:latexmath   => INLINE_MATH_DELIMITERS[:latexmath] + [false]
    }
    QUOTE_TAGS.default = [nil, nil, nil]

    def initialize backend, opts = {}
      @xml_mode = opts[:htmlsyntax] == 'xml'
      @void_element_slash = @xml_mode ? '/' : nil
      @stylesheets = Stylesheets.instance
    end


    # Folds each endline into a single space, escapes special man characters,
    # reverts HTML entity references back to their original form, strips trailing
    # whitespace and, optionally, appends a newline
    def manify(str, append_newline = true, preserve_space = false)
      if preserve_space
        str = str.gsub("\t", (' ' * 8))
      else
        str = str.tr_s("\n\t ", ' ')
      end
      str
        .gsub(/\./, '\\\&.')
        .gsub('-', '\\-')
        .gsub('&lt;', '<')
        .gsub('&gt;', '>')
        .gsub('&#169;', '\\(co')
        .gsub('&#174;', '\\(rg')
        .gsub('&#8482;', '\\(tm')
        .gsub('&#8201;', ' ') #.gsub('&#8201;&#8212;&#8201;', ' \\(em ')
        .gsub('&#8203;', '')
        .gsub('&#8212;', '\\-\\-') # .gsub('&#8212;', '\\(em')
        .gsub('&#8230;', '...') #.gsub('&#8230;', '\\\&...')
        .gsub('&#8217;', '\\(cq')
        .gsub('&#8592;', '\\(<-')
        .gsub('&#8594;', '\\(->')
        .gsub('&#8656;', '\\(lA')
        .gsub('&#8658;', '\\(rA')
        .gsub('\'', '\\(aq')
        .rstrip + (append_newline ? EOL : '')
    end

    def document node
      result = []
      slash = @void_element_slash
      br = %(<br#{slash}>)
      asset_uri_scheme = (node.attr 'asset-uri-scheme', 'https')
      asset_uri_scheme = %(#{asset_uri_scheme}:) unless asset_uri_scheme.empty?
      cdn_base = %(#{asset_uri_scheme}//cdnjs.cloudflare.com/ajax/libs)
      linkcss = node.safe >= SafeMode::SECURE || (node.attr? 'linkcss')
      # TODO
      # lang_attribute = (node.attr? 'nolang') ? nil : %( lang="#{node.attr 'lang', 'en'}")
      header_title     = node.doctitle.split('(').first
      header_number    = node.doctitle.split('(').last.chop
      header_author    = (node.attr? 'authors') ? (node.attr 'authors') : '[see the "AUTHORS" section]'
      header_generator = "Asciidoctor #{ node.attr 'asciidoctor-version' }"
      header_date      = node.attr 'docdate'
      header_manual    = (manual = (node.attr? 'manmanual') ? (node.attr 'manmanual') : '\ \&')
      header_source    = (source = (node.attr? 'mansource') ? (node.attr 'mansource') : '\ \&')
      result << %Q('\\" t
.\\"     Title: #{ header_title.downcase }
.\\"    Author: #{ header_author }
.\\" Generator: #{ header_generator }
.\\"      Date: #{ header_date }
.\\"    Manual: #{ header_manual }
.\\"    Source: #{ header_source }
.\\"  Language: English
.\\"
.TH "#{ manify header_title.upcase, false }" "#{ header_number }" "#{ header_date }" "#{manify header_source, false}" "#{manify header_manual, false}"
.ie \\n\(.g .ds Aq \\\(aq
.el       .ds Aq '
.nh
.ad l)
      if node.attr? 'stem'
        result << %(<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  tex2jax: {
    inlineMath: [#{INLINE_MATH_DELIMITERS[:latexmath]}],
    displayMath: [#{BLOCK_MATH_DELIMITERS[:latexmath]}],
    ignoreClass: "nostem|nolatexmath"
  },
  asciimath2jax: {
    delimiters: [#{BLOCK_MATH_DELIMITERS[:asciimath]}],
    ignoreClass: "nostem|noasciimath"
  }
});
</script>
<script src="#{cdn_base}/mathjax/2.4.0/MathJax.js?config=TeX-MML-AM_HTMLorMML"></script>)
      end

      unless node.noheader
        if node.attr? 'manpurpose'
          result << %(.SH "#{node.attr 'manname-title'}"\n.sp)
          result << %(#{node.attr 'mantitle'} \\- #{node.attr 'manpurpose'})
        end
      end

      result << %(#{node.content})

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << %(<div id="footnotes">
<hr#{slash}>)
        node.footnotes.each do |footnote|
          result << %(<div class="footnote" id="_footnote_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a>. #{footnote.text}
</div>)
        end
        result << '</div>'
      end
      if node.attr? 'authors'
        result << %Q(.SH "AUTHOR(S)"
.PP
\\fB#{ node.attr 'authors' }\\fR
.RS 4
Author(s).
.RE
)
      end
      result * EOL
    end

    def embedded node
      result = []
      if !node.notitle && node.has_header?
        result << %(.SH #{node.header.title}
.sp)
      end

      result << node.content

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << %(<div id="footnotes">
<hr#{@void_element_slash}>)
        node.footnotes.each do |footnote|
          result << %(<div class="footnote" id="_footnote_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a> #{footnote.text}
</div>)
        end

        result << '</div>'
      end

      result * EOL
    end

    def section node
      slevel = node.level
      # QUESTION should the check for slevel be done in section?
      slevel = 1 if slevel == 0 && node.special

      if slevel <= 1
        %(.SH "#{node.title}"
.sp
#{node.content})
      else
        %(.SS "#{node.captioned_title}"
.PP
#{slevel == 1 ? %[.sp\n#{node.content}\n] : node.content})
      end
    end

    def admonition node
      result = []
      result << %(\\fB#{node.title}\\fR\n.br) if node.title?
      result << %(.if n \\{\\
.sp
.\\}
.RS 4
.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
.ps +1
\\fB#{ node.caption }\\fR
.ps -1
.br
#{ manify node.content }
.sp .5v
.RE)
      result * EOL
    end

    def colist node
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['colist', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")

      result << %(<div#{id_attribute}#{class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?

      if node.document.attr? 'icons'
        result << '<table>'

        font_icons = node.document.attr? 'icons', 'font'
        node.items.each_with_index do |item, i|
          num = i + 1
          num_element = if font_icons
            %(<i class="conum" data-value="#{num}"></i><b>#{num}</b>)
          else
            %(<img src="#{node.icon_uri "callouts/#{num}"}" alt="#{num}"#{@void_element_slash}>)
          end
          result << %(<tr>
<td>#{num_element}</td>
<td>#{item.text}</td>
</tr>)
        end

        result << '</table>'
      else
        result << '<ol>'
        node.items.each do |item|
          result << %(<li>
<p>#{item.text}</p>
</li>)
        end
        result << '</ol>'
      end

      result << '</div>'
      result * EOL
    end

    def dlist node
      result = []
      counter = 0
      node.items.each do |terms, dd|
        counter += 1
        [*terms].each do |dt|
          result << %(#{manify dt.text}.RS 4)
        end
        if dd
          result << %(#{manify dd.text, false}) if dd.text?
          result << '.sp' if dd.text? && dd.blocks?
          result << %(#{dd.content}) if dd.blocks?
          result << ".RE"
          result << ".PP" unless node.items.size == counter
        end
      end

      result * EOL
    end

    def example node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : nil

      %(<div#{id_attribute} class="#{(role = node.role) ? ['exampleblock', role] * ' ' : 'exampleblock'}">
#{title_element}<div class="content">
#{node.content}
</div>
</div>)
    end

    def floating_title node
      tag_name = %(h#{node.level + 1})
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = [node.style, node.role].compact
      %(<#{tag_name}#{id_attribute} class="#{classes * ' '}">#{node.title}</#{tag_name}>)
    end

    def image node
      align = (node.attr? 'align') ? (node.attr 'align') : nil
      float = (node.attr? 'float') ? (node.attr 'float') : nil
      style_attribute = if align || float
        styles = [align ? %(text-align: #{align}) : nil, float ? %(float: #{float}) : nil].compact
        %( style="#{styles * ';'}")
      end

      width_attribute = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
      height_attribute = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : nil

      img_element = %(<img src="#{node.image_uri node.attr('target')}" alt="#{node.attr 'alt'}"#{width_attribute}#{height_attribute}#{@void_element_slash}>)
      if (link = node.attr 'link')
        img_element = %(<a class="image" href="#{link}">#{img_element}</a>)
      end
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['imageblock', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : nil

      %(<div#{id_attribute}#{class_attribute}#{style_attribute}>
<div class="content">
#{img_element}
</div>#{title_element}
</div>)
    end

    def listing node
      result = []
      result << %(\\fB#{node.title}\\fR\n.br) if node.title?
      result << %(.sp
.if n \\{\\
.RS 4
.\\}
.nf
#{manify node.content, true, true}
.fi
.if n \\{\\
.RE
.\\})
      result * EOL
    end

    def literal node
      result = []
      result << %(\\fB#{node.title}\\fR\n.br) if node.title?
      result << %(.sp
.if n \\{\\
.RS 4
.\\}
.nf
#{manify node.content, true, true}
.fi
.if n \\{\\
.RE
.\\}
)
      result * EOL
    end

    def stem node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
      open, close = BLOCK_MATH_DELIMITERS[node.style.to_sym]

      unless ((equation = node.content).start_with? open) && (equation.end_with? close)
        equation = %(#{open}#{equation}#{close})
      end

      %(<div#{id_attribute} class="#{(role = node.role) ? ['stemblock', role] * ' ' : 'stemblock'}">
#{title_element}<div class="content">
#{equation}
</div>
</div>)
    end

    def olist node
      result = []
      result << %(\\fB#{node.title}\\fR\n.br) if node.title?

      node.items.each_with_index do |item, idx|
        result << %(.sp
.RS 4
.ie n \\{\\
\\h'-04' #{idx + 1}.\\h'+01'\\c
.\\}
.el \\{\\
.sp -1
.IP " #{idx + 1}." 4.2
.\\}
#{manify item.text}#{(item.blocks?) ? item.content : ''}
.RE)
      end
      result * EOL
    end

    def open node
      if (style = node.style) == 'abstract'
        if node.parent == node.document && node.document.doctype == 'book'
          warn 'asciidoctor: WARNING: abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
          ''
        else
          id_attr = node.id ? %( id="#{node.id}") : nil
          title_el = node.title? ? %(<div class="title">#{node.title}</div>) : nil
          %(<div#{id_attr} class="quoteblock abstract#{(role = node.role) && " #{role}"}">
#{title_el}<blockquote>
#{node.content}
</blockquote>
</div>)
        end
      elsif style == 'partintro' && (node.level != 0 || node.parent.context != :section || node.document.doctype != 'book')
        warn 'asciidoctor: ERROR: partintro block can only be used when doctype is book and it\'s a child of a book part. Excluding block content.'
        ''
      else
          id_attr = node.id ? %( id="#{node.id}") : nil
          title_el = node.title? ? %(<div class="title">#{node.title}</div>) : nil
        %(<div#{id_attr} class="openblock#{style && style != 'open' ? " #{style}" : ''}#{(role = node.role) && " #{role}"}">
#{title_el}<div class="content">
#{node.content}
</div>
</div>)
      end
    end

    def page_break node
      ''
    end

    def paragraph node
      %(#{manify node.content}.sp)
    end

    def preamble node
      node.content
    end

    def quote node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['quoteblock', node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : nil
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil
      if attribution || citetitle
        cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : nil
        attribution_text = attribution ? %(&#8212; #{attribution}#{citetitle ? "<br#{@void_element_slash}>\n" : nil}) : nil
        attribution_element = %(\n<div class="attribution">\n#{attribution_text}#{cite_element}\n</div>)
      else
        attribution_element = nil
      end

      %(<div#{id_attribute}#{class_attribute}>#{title_element}
<blockquote>
#{node.content}
</blockquote>#{attribution_element}
</div>)
    end

    def thematic_break node
      %(<hr#{@void_element_slash}>)
    end

    def sidebar node
      id_attribute = node.id ? %( id="#{node.id}") : nil
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : nil
      %(<div#{id_attribute} class="#{(role = node.role) ? ['sidebarblock', role] * ' ' : 'sidebarblock'}">
<div class="content">
#{title_element}#{node.content}
</div>
</div>)
    end

    def table node
      result = []
      result << %(#{node.captioned_title}) if node.title?
      if (node.attr 'rowcount') > 0
        result << %(|#{'=' * 4}\n.br)
        [:head, :foot, :body].select {|tsec| !node.rows[tsec].empty? }.each do |tsec|
          node.rows[tsec].each do |row|
            row.each do |cell|
              if tsec == :head
                cell_content = cell.text
              else
                case cell.style
                when :asciidoc
                  cell_content = %(#{cell.content})
                when :verse
                  cell_content = %(#{cell.text})
                when :literal
                  cell_content = %(#{cell.text})
                else
                  cell_content = ''
                  cell.content.each do |text|
                    cell_content = %(#{cell_content}#{text})
                  end
                end
              end
              result << %(| #{cell_content}\n.br)
            end
            if tsec == :foot
              result << %(.br)
            else
              result << %(.sp)
            end
          end
        end
      end
      result << %(|#{'=' * 4}\n)
      result * EOL
    end

    def ulist node
      node.items.map {|li|
        %[.sp
.RS 4
.ie n \\{\\
\\h'-04'\\(bu\\h'+03'\\c
.\\}
.el \\{\\
.sp -1
.IP \\(bu 2.3
.\\}
#{manify li.text, false}#{li.blocks? ? li.content : nil}
.RE]
      } * EOL
    end

    def verse node
      result = []
      result << %(\\fB#{node.title}\\fR\n.br) if node.title?
      title_element = node.title? ? %(\\fB#{node.title}\\fR\n.br) : nil
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil

      result << %(.sp
#{title_element}
.nf
#{node.content}
.br
#{citetitle} #{attribution}
.fi
)
      result * EOL
    end

    def inline_anchor node
      target = node.target
      case node.type
      when :link
        if target.start_with? 'mailto:'
          target[7..-1]
        else
          target
        end
      else
        target
      end
    end

    def inline_break node
      %(#{node.text}<br#{@void_element_slash}>)
    end

    def inline_button node
      %(<b class="button">#{node.text}</b>)
    end

    def inline_callout node
      if node.document.attr? 'icons', 'font'
        %(<i class="conum" data-value="#{node.text}"></i><b>(#{node.text})</b>)
      elsif node.document.attr? 'icons'
        src = node.icon_uri("callouts/#{node.text}")
        %(<img src="#{src}" alt="#{node.text}"#{@void_element_slash}>)
      else
        %(<b class="conum">(#{node.text})</b>)
      end
    end

    def inline_footnote node
      if (index = node.attr 'index')
        if node.type == :xref
          %(<span class="footnoteref">[<a class="footnote" href="#_footnote_#{index}" title="View footnote.">#{index}</a>]</span>)
        else
          id_attr = node.id ? %( id="_footnote_#{node.id}") : nil
          %(<span class="footnote"#{id_attr}>[<a id="_footnoteref_#{index}" class="footnote" href="#_footnote_#{index}" title="View footnote.">#{index}</a>]</span>)
        end
      elsif node.type == :xref
        %(<span class="footnoteref red" title="Unresolved footnote reference.">[#{node.text}]</span>)
      end
    end

    def inline_image node
      if (type = node.type) == 'icon' && (node.document.attr? 'icons', 'font')
        img = node.attr 'title'
      elsif type == 'icon' && !(node.document.attr? 'icons')
        img = node.attr 'alt'
      else
        if node.attr? 'title'
          img = (node.attr? 'alt') ? %(#{node.attr 'alt'} > #{node.attr 'title'}) : node.attr('title')
        elsif node.attr? 'alt'
          img = node.attr 'alt'
        end
      end

      if node.attr? 'link'
        (img != nil) ? %(.URL "#{node.attr 'link'}" "#{img}"\n) : node.attr('link')
      else
        (img != nil) ? %(\\fB[#{img}]\\fR\n) : ''
      end
    end

    def inline_indexterm node
      node.type == :visible ? node.text : ''
    end

    def inline_kbd node
      if (keys = node.attr 'keys').size == 1
        %([#{keys[0]}])
      else
        key_combo = keys.join(' + ')
        %([#{key_combo}])
      end
    end

    def inline_menu node
      menu = node.attr 'menu'
      if !(submenus = node.attr 'submenus').empty?
        submenu_path = submenus.join(' > ')
        %(\\fB#{menu} > #{submenu_path} > #{node.attr 'menuitem'}\\fR\n)
      elsif (menuitem = node.attr 'menuitem')
        %(\\fB#{menu} > #{menuitem}\\fR\n)
      else
        %(\\fB #{menu}\\fR\n)
      end
    end

    def inline_quoted node
      case node.type
      when :emphasis
        %[\\fI#{node.text}\\fR]
      when :strong
        %[\\fB#{node.text}\\fR]
      when :single
        %[\\(oq#{node.text}\\(cq]
      when :double
        %[\\(lq#{node.text}\\(rq]
      else
        node.text
      end
    end

    def append_boolean_attribute name, xml
      xml ? %( #{name}="#{name}") : %( #{name})
    end
  end
end
