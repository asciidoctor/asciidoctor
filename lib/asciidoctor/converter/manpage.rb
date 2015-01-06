module Asciidoctor
  # A built-in {Converter} implementation that generates Troff Manpage output
  # The output follows groff man page definition:
  # http://www.gnu.org/software/groff/manual/html_node/Man-usage.html#Man-usage
  # but also tries to be consistent with the a2x tool from AsciiDoc Python.
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
      # TODO:
      # Use this list to make sure manify changes '.' at the beginning of line
      # except when used in one of these commands.
      # TODO: Complete the list
      @used_troff_dot_commands = ['.SH ', '.SS ', '.PP', '.RS', '.RE', '.de', '.if']
    end

    # optionally folds each endline into a single space, escapes special man characters,
    # reverts HTML entity references back to their original form, strips trailing
    # whitespace and, optionally, appends a newline
    def manify(str, append_newline = false, preserve_space = true)
      if preserve_space
        str = str.gsub("\t", (' ' * 8))
      else
        str = str.tr_s("\n\t ", ' ')
      end
      # TODO:
      # Do not manify . everywhere since it is used for troff macros
      # To begin a line with a literal period, use the zero-width non-printing
      # escape sequence \& to get the period away from the beginning of the
      # line, which is the only place it is treated specially: \&. This line
      # begins with a dot.
      # http://web.archive.org/web/20060102165607/http://people.debian.org/~branden/talks/wtfm/wtfm.pdf
      # .gsub(/\./, '\\\&.')
      str.
        gsub('^.$', '\\\&.').     # lone . is also used in troff to indicate paragraph continuation with visual separator
        gsub('-', '\\-').
        gsub('&lt;', '<').
        gsub('&gt;', '>').
        gsub('&#169;', '\\(co').  # copyright sign
        gsub('&#174;', '\\(rg').  # registered sign
        gsub('&#8482;', '\\(tm'). # trademark sign
        gsub('&#8201;', ' ').     # thin space #gsub('&#8201;&#8212;&#8201;', ' \\(em ').
        gsub('&#8203;', '').      # zero width space
        gsub('&#8211;', '\\(en'). # en-dash
        gsub('&#8212;', '\\(em'). # em-dash
        gsub('&#8216;', '\\(oq'). # left single quotation mark
        gsub('&#8217;', '\\(cq'). # right single quotation mark
        gsub('&#8220;', '\\(lq'). # left double quotation mark
        gsub('&#8221;', '\\(rq'). # right double quotation mark
        gsub('&#8230;', '...').   # horizontal ellipsis #gsub('&#8230;', '\\\&...').
        gsub('&#8592;', '\\(<-'). # leftwards arrow
        gsub('&#8594;', '\\(->'). # rightwards arrow
        gsub('&#8656;', '\\(lA'). # leftwards double arrow
        gsub('&#8658;', '\\(rA'). # rightwards double arrow
        gsub('\'', '\\(aq').      # apostrophe-quote
        rstrip + (append_newline ? EOL : '')
    end

    def document node
      result = []
      # TODO
      # lang_attribute = (node.attr? 'nolang') ? nil : %( lang="#{node.attr 'lang', 'en'}")
      header_title     = (node.attr? 'mantitle') ? (node.attr 'mantitle') : node.doctitle.split('(').first
      header_number    = node.doctitle.split('(').last.chop
      header_author    = (node.attr? 'authors') ? (node.attr 'authors') : '[see the "AUTHORS" section]'
      header_generator = "Asciidoctor #{ node.attr 'asciidoctor-version' }"
      header_date      = node.attr 'docdate'
      header_manual    = (node.attr? 'manmanual') ? (node.attr 'manmanual') : '\ \&'
      header_source    = (node.attr? 'mansource') ? (node.attr 'mansource') : '\ \&'
      result << %Q('\\" t
.\\"     Title: #{ header_title.downcase }
.\\"    Author: #{ header_author }
.\\" Generator: #{ header_generator }
.\\"      Date: #{ header_date }
.\\"    Manual: #{ header_manual }
.\\"    Source: #{ header_source }
.\\"  Language: English
.\\")
      # .TH name section(1-8) date version
      # Don't capitalize name, that's a presentation decision.
      result << %Q(.TH "#{ manify header_title, false }" "#{ header_number }" "#{ header_date }" "#{manify header_source, false}" "#{manify header_manual, false}")
      # http://bugs.debian.org/507673
      # http://lists.gnu.org/archive/html/groff/2009-02/msg00013.html
      result << %(.ie \\n\(.g .ds Aq \\\(aq
.el       .ds Aq ')
      # disable hyphenation
      result << %Q(.nh)
      # disable justification (adjust text to left margin only)
      result << %Q(.ad l)
      # URL portability. Taken from:
      # http://web.archive.org/web/20060102165607/http://people.debian.org/~branden/talks/wtfm/wtfm.pdf
      # Use: .URL "http://www.debian.org" "Debian" "*"
      # The first argument is the URL, the second is the text to be
      # hyperlinked, and the third (optional) argument is any text that needs
      # to immediately trail the hyperlink without intervening whitespace
      # GNU roff defines a URL macro; what the above does is test for the
      # presence of GNU roff, and source the www.tmac macro definition file
      # (which itself also defines URL) if it is — this overrides the
      # definition just made, but leaves it intact for non-GNU roff
      # implementations.
      result << %(.\\" URL Portability
.de URL
\\\\$2 \\\(laURL: \\\\$1 \\\(ra\\\\$3
..
.if \\n[.g] .mso www.tmac)

      unless node.noheader
        if node.attr? 'manpurpose'
          #.SH Unnumbered section heading
          result << %(.SH "#{manify node.attr 'manname-title'}")
          result << %(#{manify node.attr 'mantitle'} \\- #{manify node.attr 'manpurpose'})
        end
      end

      result << %(#{node.content})

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << %(.SH "NOTES")
        node.footnotes.each do |footnote|
          result << %(#{footnote.index}". #{footnote.text})
        end
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
        result << %(.SH "NOTES")
        node.footnotes.each do |footnote|
          result << %(#{footnote.index}. #{footnote.text})
        end
      end

      result * EOL
    end

    def section node
      slevel = node.level
      # QUESTION should the check for slevel be done in section?
      slevel = 1 if slevel == 0 && node.special
      result = []
      if slevel <= 1
        result << %(.SH "#{manify node.title}"
#{node.content})
      else
        result << %(.SS "#{manify node.captioned_title}")
        result << node.content
      end
      result * EOL
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

    def audio node
      ''
    end

    def colist node
      result = []
      result << %(.B #{manify node.title}) if node.title?
      result << %(.TS
tab\(:\);
r lw\(\\n\(.lu*75u/100u\).)

      node.items.each_with_index do |item, index|
        result << %(\\fB#{index + 1}.\\fR\\h'-2n':T{
#{manify item.text}
T})
      end
      result << ".TE"
      result * EOL
    end

    def dlist node
      result = []
      counter = 0
      node.items.each do |terms, dd|
        case node.style
        when 'qanda'
          counter += 1
          [*terms].each do |dt|
            result << ".sp"
            result << %(#{counter}. #{manify dt.text}\n.RS 4)
          end
        when 'horizontal'
          counter += 1
          [*terms].each do |dt|
            result << ".sp"
            result << %(#{manify dt.text}\n.RS 4)
          end
        else
          counter += 1
          [*terms].each do |dt|
            result << ".sp"
            result << %(.B #{manify dt.text}\n.RS 4)
          end
        end
        if dd
          result << %(#{manify dd.text}) if dd.text?
          result << ".sp" if dd.text? && dd.blocks?
          result << %(#{dd.content}) if dd.blocks?
        end
        result << ".RE"
      end
      result * EOL
    end

    def example node
      result = []
      result << %(.B #{node.captioned_title}\n.br) if node.title?
      result << %(.if n \\{\\
.sp
.\\}
.RS 4
.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
#{ manify node.content }
.sp .5v
.RE)
      result * EOL
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
#{manify item.text})
        result << item.content if item.blocks?
        result << ".RE"
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
      if node.title?
        %(.B #{manify node.title}
.br
#{manify node.content}
)
      else
        # Change paragraph separator to .sp instead of .PP
        # .PP breaks indentation of outher blocks.
        %(.sp
#{manify node.content})
      end
    end

    def pass node
      node.content
    end

    def preamble node
      node.content
    end

    def quote node
      result = []
      title_element = node.title? ? %(.in +.3i\n\\fB#{node.title}\\fR\n.br\n.in\n) : nil
      attribution_line = (node.attr? 'citetitle') ? %(#{node.attr 'citetitle'} ) : nil
      attribution_line = (node.attr? 'attribution') ? %(#{attribution_line}\\\(em #{node.attr 'attribution'}) : nil
      result << %(#{title_element}.in +.5i
.ll -.5i
.nf
#{node.content}
.fi
.br
.in
.ll)
      if attribution_line
        result << %(.in +.3i
.ll -.3i
#{attribution_line}
.in
.ll)
      end
      result * EOL
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

    def stem node
      title_element = node.title? ? %(\\fB#{node.title}\\fR\n.br\n) : nil
      open, close = BLOCK_MATH_DELIMITERS[node.style.to_sym]

      unless ((equation = node.content).start_with? open) && (equation.end_with? close)
        equation = %(#{open}#{equation}#{close})
      end

      %(#{title_element}#{equation})
    end

    # FIXME: The reason this method is so complicated is because we are not
    # receiving empty(marked) cells when there are colspans or rowspans. This
    # method has to create a map of all cells and in the case of rowspans
    # create empty cells as placeholders of the span.
    # To fix this, asciidoctor needs to provide an API to tell the user if a
    # given cell is being used as a colspan or rowspan.
    def table node
      result = ""
      if node.title?
        result += %Q(.sp
.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
.B #{manify node.captioned_title}
)
      end
      result += %(.TS
allbox tab(:);)
      row_header = []
      row_text = []
      row_index = 0
      [:head, :body, :foot].each do |tsec|
        node.rows[tsec].each do |row|
          row_header[row_index] ||= []
          row_text[row_index] ||= []
          # result += "\n"
          # l left-adjusted
          # r right-adjusted
          # c centered-adjusted
          # n numerical align
          # a alphabetic align
          # s spanned
          # ^ vertically spanned
          remaining_cells = row.size
          row.each_with_index do |cell, cell_index|
            remaining_cells -= 1
            row_header[row_index][cell_index] ||= []
            # Add an empty cell if this is a rowspan cell
            if row_header[row_index][cell_index] == ["^t"]
              row_text[row_index] <<  %Q(T{\n.sp\nT}:)
            end
            row_text[row_index] <<  %Q(T{\n.sp\n)
            cell_halign = case cell.attr 'halign'
                          when 'right'
                            'r'
                          when 'left'
                            'l'
                          when 'center'
                            'c'
                          else
                            'l'
                          end
            if tsec == :head
              if row_header[row_index].empty? ||
                 row_header[row_index][cell_index].empty?
                row_header[row_index][cell_index] << cell_halign + "tB"
              else
                row_header[row_index][cell_index + 1] ||= []
                row_header[row_index][cell_index + 1] << cell_halign + "tB"
              end
              row_text[row_index] << (cell.text + "\n")
            elsif tsec == :body
              if row_header[row_index].empty? ||
                 row_header[row_index][cell_index].empty?
                row_header[row_index][cell_index] << cell_halign + "t"
              else
                row_header[row_index][cell_index + 1] ||= []
                row_header[row_index][cell_index + 1] << cell_halign + "t"
              end
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
              row_text[row_index] << (cell_content + "\n")
            elsif tsec == :foot
              if row_header[row_index].empty? ||
                 row_header[row_index][cell_index].empty?
                row_header[row_index][cell_index] << cell_halign + "tB"
              else
                row_header[row_index][cell_index + 1] ||= []
                row_header[row_index][cell_index + 1] << cell_halign + "tB"
              end
              row_text[row_index] << (cell.text + "\n")
            end
            if cell.colspan && cell.colspan > 1
              (cell.colspan - 1).times do |i|
                if row_header[row_index].empty? ||
                   row_header[row_index][cell_index].empty?
                  row_header[row_index][cell_index + i] << "st"
                else
                  row_header[row_index][cell_index + 1 + i] ||= []
                  row_header[row_index][cell_index + 1 + i] << "st"
                end
              end
            end
            if cell.rowspan && cell.rowspan > 1
              (cell.rowspan - 1).times do |i|
                row_header[row_index + 1 + i] ||= []
                if row_header[row_index + 1 + i].empty? ||
                   row_header[row_index + 1 + i][cell_index].empty?
                  row_header[row_index + 1 + i][cell_index] ||= []
                  row_header[row_index + 1 + i][cell_index] << "^t"
                else
                  row_header[row_index + 1 + i][cell_index + 1] ||= []
                  row_header[row_index + 1 + i][cell_index + 1] << "^t"
                end
              end
            end
            if remaining_cells >= 1
              row_text[row_index] << %Q(T}:)
            else
              row_text[row_index] << %Q(T}\n)
            end
          end
          row_index += 1
        end
      end
      row_header.each do |row|
        result += "\n"
        row.each_with_index do |cell, i|
          result += cell.join(' ')
          result += ' ' if row.size > i+1
        end
      end
      result += ".\n"
      row_text.each do |row|
        result += row.join('')
      end
      result += %(.TE\n.sp 1\n)
    end

    def thematic_break node
      ''
    end

    def toc node
      ''
    end

    def ulist node
      result = []
      result << %(\\fB#{node.title}\\fR) if node.title?
      node.items.map {|item|
        result << %[.sp
.RS 4
.ie n \\{\\
\\h'-04'\\(bu\\h'+03'\\c
.\\}
.el \\{\\
.sp -1
.IP \\(bu 2.3
.\\}
#{manify item.text}]
        result << item.content if item.blocks?
        result << ".RE"
      }
      result * EOL
    end

    def verse node
      result = []
      title_element = node.title? ? %(.in +.3i\n\\fB#{node.title}\\fR\n.br\n.in\n) : nil
      attribution_line = (node.attr? 'citetitle') ? %(#{node.attr 'citetitle'} ) : nil
      attribution_line = (node.attr? 'attribution') ? %(#{attribution_line}\\\(em #{node.attr 'attribution'}) : nil
      result << %(#{title_element}.in +.5i
.ll -.5i
.nf
#{node.content}
.fi
.br
.in
.ll)
      if attribution_line
        result << %(.in +.3i
.ll -.3i
#{attribution_line}
.in
.ll)
      end
      result * EOL
    end

    def video node
      start_param = (node.attr? 'start', nil, false) ? %(&start=#{node.attr 'start'}) : nil
      end_param = (node.attr? 'end', nil, false) ? %(&end=#{node.attr 'end'}) : nil
      %(.URL "#{node.media_uri(node.attr 'target')}#{start_param}#{end_param}" "#{node.captioned_title}")
    end

    def inline_anchor node
      target = node.target
      case node.type
      when :xref
        refid = (node.attr 'refid') || target
        # NOTE we lookup text in converter because DocBook doesn't need this logic
        text = node.text || (node.document.references[:ids][refid] || %([#{refid}]))
        # FIXME shouldn't target be refid? logic seems confused here
        %(\n.URL "#{target}" "#{manify text}"\n)
      when :ref
        %(\n.URL "#{target}"\n)
      when :link
        %(\n.URL "#{target}" "#{manify node.text}"\n)
      when :bibref
        %(\n.URL "#{target}"\n)
      else
        %(\n.URL "#{target}"\n)
      end
    end

    def inline_break node
      %(#{node.text}\n.br)
    end

    def inline_button node
      %([#{node.text}])
    end

    def inline_callout node
      %(\\fB#{node.text}\\fR\n)
    end

    def inline_footnote node
      if (index = node.attr 'index')
        %(\n.URL "#{index}" "View footnote."\n)
      elsif node.type == :xref
        %(\n.URL "[#{node.text}]" "Unresolved footnote reference."\n)
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
        (img != nil) ? %(\n.URL "#{node.attr 'link'}" "#{img}"\n) : node.attr('link')
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
  end
end
