module Asciidoctor
  # A built-in {Converter} implementation that generates the man page (troff) format.
  #
  # The output follows the groff man page definition while also trying to be
  # consistent with the output produced by the a2x tool from AsciiDoc Python.
  #
  # See http://www.gnu.org/software/groff/manual/html_node/Man-usage.html#Man-usage
  class Converter::ManPageConverter < Converter::BuiltIn
    LF = %(\n)
    TAB = %(\t)
    WHITESPACE = %(#{LF}#{TAB} )
    ET = ' ' * 8
    ESC = %(\u001b)      # troff leader marker
    ESC_BS = %(#{ESC}\\) # escaped backslash (indicates troff formatting sequence)
    ESC_FS = %(#{ESC}.)  # escaped full stop (indicates troff macro)

    # Converts HTML entity references back to their original form, escapes
    # special man characters and strips trailing whitespace.
    #
    # It's crucial that text only ever pass through manify once.
    #
    # str  - the String to convert
    # opts - an Hash of options to control processing (default: {})
    #        * :preserve_space a Boolean that indicates whether to preserve spaces (only expanding tabs) if true
    #          or to collapse all adjacent whitespace to a single space if false (default: true)
    #        * :append_newline a Boolean that indicates whether to append an endline to the result (default: false)
    def manify str, opts = {}
      str = ((opts.fetch :preserve_space, true) ? (str.gsub TAB, ET) : (str.tr_s WHITESPACE, ' ')).
        gsub(/(?:\A|[^#{ESC}])\\/, '\&(rs'). # literal backslash (not a troff escape sequence)
        gsub(/^\./, '\\\&.').     # leading . is used in troff for macro call or other formatting; replace with \&.
        # drop orphaned \c escape lines, unescape troff macro, quote adjacent character, isolate macro line
        gsub(/^(?:#{ESC}\\c\n)?#{ESC}\.((?:URL|MTO) ".*?" ".*?" )( |[^\s]*)(.*?)(?: *#{ESC}\\c)?$/) {
          (rest = $3.lstrip).empty? ? %(.#$1"#$2") : %(.#$1"#$2"#{LF}#{rest})
        }.
        gsub('-', '\-').
        gsub('&lt;', '<').
        gsub('&gt;', '>').
        gsub('&#160;', '\~').     # non-breaking space
        gsub('&#169;', '\(co').   # copyright sign
        gsub('&#174;', '\(rg').   # registered sign
        gsub('&#8482;', '\(tm').  # trademark sign
        gsub('&#8201;', ' ').     # thin space
        gsub('&#8211;', '\(en').  # en dash
        gsub(/&#8212(?:;&#8203;)?/, '\(em'). # em dash
        gsub('&#8216;', '\(oq').  # left single quotation mark
        gsub('&#8217;', '\(cq').  # right single quotation mark
        gsub('&#8220;', '\(lq').  # left double quotation mark
        gsub('&#8221;', '\(rq').  # right double quotation mark
        gsub(/&#8230;(?:&#8203;)?/, '...'). # horizontal ellipsis
        gsub('&#8592;', '\(<-').  # leftwards arrow
        gsub('&#8594;', '\(->').  # rightwards arrow
        gsub('&#8656;', '\(lA').  # leftwards double arrow
        gsub('&#8658;', '\(rA').  # rightwards double arrow
        gsub('&#8203;', '\:').    # zero width space
        gsub('\'', '\(aq').       # apostrophe-quote
        gsub(/<\/?BOUNDARY>/, '').# artificial boundary
        gsub(ESC_BS, '\\').       # unescape troff backslash (NOTE update if more escaped are added)
        rstrip                    # strip trailing space
      opts[:append_newline] ? %(#{str}#{LF}) : str
    end

    def skip_with_warning node, name = nil
      warn %(asciidoctor: WARNING: converter missing for #{name || node.node_name} node in manpage backend)
      nil
    end

    def document node
      unless node.attr? 'mantitle'
        raise 'asciidoctor: ERROR: doctype must be set to manpage when using manpage backend'
      end
      mantitle = node.attr 'mantitle'
      manvolnum = node.attr 'manvolnum', '1'
      manname = node.attr 'manname', mantitle
      docdate = (node.attr? 'reproducible') ? nil : (node.attr 'docdate')
      # NOTE the first line enables the table (tbl) preprocessor, necessary for non-Linux systems
      result = [%('\\" t
.\\"     Title: #{mantitle}
.\\"    Author: #{(node.attr? 'authors') ? (node.attr 'authors') : '[see the "AUTHORS" section]'}
.\\" Generator: Asciidoctor #{node.attr 'asciidoctor-version'})]
      result << %(.\\"      Date: #{docdate}) if docdate
      result << %(.\\"    Manual: #{(manual = node.attr 'manmanual') || '\ \&'}
.\\"    Source: #{(source = node.attr 'mansource') || '\ \&'}
.\\"  Language: English
.\\")
      # TODO add document-level setting to disable capitalization of manname
      result << %(.TH "#{manify manname.upcase}" "#{manvolnum}" "#{docdate}" "#{source ? (manify source) : '\ \&'}" "#{manual ? (manify manual) : '\ \&'}")
      # define portability settings
      # see http://bugs.debian.org/507673
      # see http://lists.gnu.org/archive/html/groff/2009-02/msg00013.html
      result << '.ie \n(.g .ds Aq \(aq'
      result << '.el       .ds Aq \''
      # set sentence_space_size to 0 to prevent extra space between sentences separated by a newline
      # the alternative is to add \& at the end of the line
      result << '.ss \n[.ss] 0'
      # disable hyphenation
      result << '.nh'
      # disable justification (adjust text to left margin only)
      result << '.ad l'
      # define URL macro for portability
      # see http://web.archive.org/web/20060102165607/http://people.debian.org/~branden/talks/wtfm/wtfm.pdf
      #
      # Use: .URL "http://www.debian.org" "Debian" "."
      #
      # * First argument: the URL
      # * Second argument: text to be hyperlinked
      # * Third (optional) argument: text that needs to immediately trail
      #   the hyperlink without intervening whitespace
      result << '.de URL
\\\\$2 \(laURL: \\\\$1 \(ra\\\\$3
..
.if \n[.g] .mso www.tmac'
      result << %(.LINKSTYLE #{node.attr 'man-linkstyle', 'blue R < >'})

      unless node.noheader
        if node.attr? 'manpurpose'
          result << %(.SH "#{node.attr 'manname-title'}"
#{manify mantitle} \\- #{manify node.attr 'manpurpose'})
        end
      end

      result << node.content

      # QUESTION should NOTES come after AUTHOR(S)?
      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << '.SH "NOTES"'
        result.concat(node.footnotes.map {|fn| %(#{fn.index}. #{fn.text}) })
      end

      # FIXME detect single author and use appropriate heading; itemize the authors if multiple
      if node.attr? 'authors'
        result << %(.SH "AUTHOR(S)"
.sp
\\fB#{node.attr 'authors'}\\fP
.RS 4
Author(s).
.RE)
      end

      result * LF
    end

    # NOTE embedded doesn't really make sense in the manpage backend
    def embedded node
      result = [node.content]

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << '.SH "NOTES"'
        result.concat(node.footnotes.map {|fn| %(#{fn.index}. #{fn.text}) })
      end

      # QUESTION should we add an AUTHOR(S) section?

      result * LF
    end

    def section node
      slevel = node.level
      # QUESTION should the check for slevel be done in section?
      slevel = 1 if slevel == 0 && node.special
      result = []
      if slevel > 1
        macro = 'SS'
        # QUESTION why captioned title? why not for slevel == 1?
        stitle = node.captioned_title
      else
        macro = 'SH'
        stitle = node.title.upcase
      end
      result << %(.#{macro} "#{manify stitle}"
#{node.content})
      result * LF
    end

    def admonition node
      result = []
      result << %(.if n \\{\\
.sp
.\\}
.RS 4
.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
.ps +1
.B #{node.caption}#{node.title? ? "\\fP #{manify node.title}" : nil}
.ps -1
.br
#{resolve_content node}
.sp .5v
.RE)
      result * LF
    end

    alias :audio :skip_with_warning

    def colist node
      result = []
      result << %(.sp
.B #{manify node.title}
.br) if node.title?
      result << '.TS
tab(:);
r lw(\n(.lu*75u/100u).'

      node.items.each_with_index do |item, index|
        result << %(\\fB(#{index + 1})\\fP\\h'-2n':T{
#{manify item.text}
T})
      end
      result << '.TE'
      result * LF
    end

    # TODO implement title for dlist
    # TODO implement horizontal (if it makes sense)
    def dlist node
      result = []
      counter = 0
      node.items.each do |terms, dd|
        counter += 1
        case node.style
        when 'qanda'
          result << %(.sp
#{counter}. #{manify([*terms].map {|dt| dt.text }.join ' ')}
.RS 4)
        else
          result << %(.sp
#{manify([*terms].map {|dt| dt.text }.join ', ')}
.RS 4)
        end
        if dd
          result << (manify dd.text) if dd.text?
          result << dd.content if dd.blocks?
        end
        result << '.RE'
      end
      result * LF
    end

    def example node
      result = []
      result << %(.sp
.B #{manify node.captioned_title}
.br) if node.title?
      result << %(.RS 4
#{resolve_content node}
.RE)
      result * LF
    end

    def floating_title node
      %(.SS "#{manify node.title}")
    end

    alias :image :skip_with_warning

    def listing node
      result = []
      result << %(.sp
.B #{manify node.captioned_title}
.br) if node.title?
      result << %(.sp
.if n \\{\\
.RS 4
.\\}
.nf
#{manify node.content}
.fi
.if n \\{\\
.RE
.\\})
      result * LF
    end

    def literal node
      result = []
      result << %(.sp
.B #{manify node.title}
.br) if node.title?
      result << %(.sp
.if n \\{\\
.RS 4
.\\}
.nf
#{manify node.content}
.fi
.if n \\{\\
.RE
.\\})
      result * LF
    end

    def olist node
      result = []
      result << %(.sp
.B #{manify node.title}
.br) if node.title?

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
        result << '.RE'
      end
      result * LF
    end

    def open node
      case node.style
      when 'abstract', 'partintro'
        resolve_content node
      else
        node.content
      end
    end

    # TODO use Page Control https://www.gnu.org/software/groff/manual/html_node/Page-Control.html#Page-Control
    alias :page_break :skip

    def paragraph node
      if node.title?
        %(.sp
.B #{manify node.title}
.br
#{manify node.content})
      else
        %(.sp
#{manify node.content})
      end
    end

    alias :preamble :content

    def quote node
      result = []
      if node.title?
        result << %(.sp
.in +.3i
.B #{manify node.title}
.br
.in)
      end
      attribution_line = (node.attr? 'citetitle') ? %(#{node.attr 'citetitle'} ) : nil
      attribution_line = (node.attr? 'attribution') ? %[#{attribution_line}\\(em #{node.attr 'attribution'}] : nil
      result << %(.in +.3i
.ll -.3i
.nf
#{resolve_content node}
.fi
.br
.in
.ll)
      if attribution_line
        result << %(.in +.5i
.ll -.5i
#{attribution_line}
.in
.ll)
      end
      result * LF
    end

    alias :sidebar :skip_with_warning

    def stem node
      title_element = node.title? ? %(.sp
.B #{manify node.title}
.br) : nil
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
      result = []
      if node.title?
        result << %(.sp
.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
.B #{manify node.captioned_title})
      end
      result << '.TS
allbox tab(:);'
      row_header = []
      row_text = []
      row_index = 0
      [:head, :body, :foot].each do |tsec|
        node.rows[tsec].each do |row|
          row_header[row_index] ||= []
          row_text[row_index] ||= []
          # result << LF
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
            if row_header[row_index][cell_index] == ['^t']
              row_text[row_index] << %(T{#{LF}.sp#{LF}T}:)
            end
            row_text[row_index] << %(T{#{LF}.sp#{LF})
            cell_halign = (cell.attr 'halign', 'left')[0..0]
            if tsec == :head
              if row_header[row_index].empty? ||
                 row_header[row_index][cell_index].empty?
                row_header[row_index][cell_index] << %(#{cell_halign}tB)
              else
                row_header[row_index][cell_index + 1] ||= []
                row_header[row_index][cell_index + 1] << %(#{cell_halign}tB)
              end
              row_text[row_index] << %(#{cell.text}#{LF})
            elsif tsec == :body
              if row_header[row_index].empty? ||
                 row_header[row_index][cell_index].empty?
                row_header[row_index][cell_index] << %(#{cell_halign}t)
              else
                row_header[row_index][cell_index + 1] ||= []
                row_header[row_index][cell_index + 1] << %(#{cell_halign}t)
              end
              case cell.style
              when :asciidoc
                cell_content = cell.content
              when :verse, :literal
                cell_content = cell.text
              else
                cell_content = cell.content.join
              end
              row_text[row_index] << %(#{cell_content}#{LF})
            elsif tsec == :foot
              if row_header[row_index].empty? ||
                 row_header[row_index][cell_index].empty?
                row_header[row_index][cell_index] << %(#{cell_halign}tB)
              else
                row_header[row_index][cell_index + 1] ||= []
                row_header[row_index][cell_index + 1] << %(#{cell_halign}tB)
              end
              row_text[row_index] << %(#{cell.text}#{LF})
            end
            if cell.colspan && cell.colspan > 1
              (cell.colspan - 1).times do |i|
                if row_header[row_index].empty? ||
                   row_header[row_index][cell_index].empty?
                  row_header[row_index][cell_index + i] << 'st'
                else
                  row_header[row_index][cell_index + 1 + i] ||= []
                  row_header[row_index][cell_index + 1 + i] << 'st'
                end
              end
            end
            if cell.rowspan && cell.rowspan > 1
              (cell.rowspan - 1).times do |i|
                row_header[row_index + 1 + i] ||= []
                if row_header[row_index + 1 + i].empty? ||
                   row_header[row_index + 1 + i][cell_index].empty?
                  row_header[row_index + 1 + i][cell_index] ||= []
                  row_header[row_index + 1 + i][cell_index] << '^t'
                else
                  row_header[row_index + 1 + i][cell_index + 1] ||= []
                  row_header[row_index + 1 + i][cell_index + 1] << '^t'
                end
              end
            end
            if remaining_cells >= 1
              row_text[row_index] << 'T}:'
            else
              row_text[row_index] << %(T}#{LF})
            end
          end
          row_index += 1
        end
      end

      #row_header.each do |row|
      #  result << LF
      #  row.each_with_index do |cell, i|
      #    result << (cell.join ' ')
      #    result << ' ' if row.size > i + 1
      #  end
      #end
      # FIXME temporary fix to get basic table to display
      result << LF
      result << row_header.first.map {|r| 'lt'}.join(' ')

      result << %(.#{LF})
      row_text.each do |row|
        result << row.join
      end
      result << %(.TE#{LF}.sp)
      result.join
    end

    def thematic_break node
      '.sp
.ce
\l\'\n(.lu*25u/100u\(ap\''
    end

    alias :toc :skip

    def ulist node
      result = []
      result << %(.sp
.B #{manify node.title}
.br) if node.title?
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
        result << '.RE'
      }
      result * LF
    end

    # FIXME git uses [verse] for the synopsis; detect this special case
    def verse node
      result = []
      if node.title?
        result << %(.sp
.B #{manify node.title}
.br)
      end
      attribution_line = (node.attr? 'citetitle') ? %(#{node.attr 'citetitle'} ) : nil
      attribution_line = (node.attr? 'attribution') ? %[#{attribution_line}\\(em #{node.attr 'attribution'}] : nil
      result << %(.sp
.nf
#{manify node.content}
.fi
.br)
      if attribution_line
        result << %(.in +.5i
.ll -.5i
#{attribution_line}
.in
.ll)
      end
      result * LF
    end

    def video node
      start_param = (node.attr? 'start', nil, false) ? %(&start=#{node.attr 'start'}) : nil
      end_param = (node.attr? 'end', nil, false) ? %(&end=#{node.attr 'end'}) : nil
      %(.sp
#{manify node.captioned_title} (video) <#{node.media_uri(node.attr 'target')}#{start_param}#{end_param}>)
    end

    def inline_anchor node
      target = node.target
      case node.type
      when :link
        if (text = node.text) == target
          text = nil
        else
          text = text.gsub '"', %[#{ESC_BS}(dq]
        end
        if target.start_with? 'mailto:'
          macro = 'MTO'
          target = target[7..-1].sub '@', %[#{ESC_BS}(at]
        else
          macro = 'URL'
        end
        %(#{ESC_BS}c#{LF}#{ESC_FS}#{macro} "#{target}" "#{text}" )
      when :xref
        refid = (node.attr 'refid') || target
        node.text || (node.document.references[:ids][refid] || %([#{refid}]))
      when :ref, :bibref
        # These are anchor points, which shouldn't be visual
        ''
      else
        warn %(asciidoctor: WARNING: unknown anchor type: #{node.type.inspect})
      end
    end

    def inline_break node
      %(#{node.text}
.br)
    end

    def inline_button node
      %(#{ESC_BS}fB[#{ESC_BS}0#{node.text}#{ESC_BS}0]#{ESC_BS}fP)
    end

    def inline_callout node
      %(#{ESC_BS}fB(#{node.text})#{ESC_BS}fP)
    end

    # TODO supposedly groff has footnotes, but we're in search of an example
    def inline_footnote node
      if (index = node.attr 'index')
        %([#{index}])
      elsif node.type == :xref
        %([#{node.text}])
      end
    end

    def inline_image node
      # NOTE alt should always be set
      alt_text = (node.attr? 'alt') ? (node.attr 'alt') : node.target
      (node.attr? 'link') ? %([#{alt_text}] <#{node.attr 'link'}>) : %([#{alt_text}])
    end

    def inline_indexterm node
      node.type == :visible ? node.text : ''
    end

    def inline_kbd node
      if (keys = node.attr 'keys').size == 1
        keys[0]
      else
        keys.join %(#{ESC_BS}0+#{ESC_BS}0)
      end
    end

    def inline_menu node
      caret = %[#{ESC_BS}0#{ESC_BS}(fc#{ESC_BS}0]
      menu = node.attr 'menu'
      if !(submenus = node.attr 'submenus').empty?
        submenu_path = submenus.map {|item| %(#{ESC_BS}fI#{item}#{ESC_BS}fP) }.join caret
        %(#{ESC_BS}fI#{menu}#{ESC_BS}fP#{caret}#{submenu_path}#{caret}#{ESC_BS}fI#{node.attr 'menuitem'}#{ESC_BS}fP)
      elsif (menuitem = node.attr 'menuitem')
        %(#{ESC_BS}fI#{menu}#{caret}#{menuitem}#{ESC_BS}fP)
      else
        %(#{ESC_BS}fI#{menu}#{ESC_BS}fP)
      end
    end

    # NOTE use fake <BOUNDARY> element to prevent creating artificial word boundaries
    def inline_quoted node
      case node.type
      when :emphasis
        %(#{ESC_BS}fI<BOUNDARY>#{node.text}</BOUNDARY>#{ESC_BS}fP)
      when :strong
        %(#{ESC_BS}fB<BOUNDARY>#{node.text}</BOUNDARY>#{ESC_BS}fP)
      when :monospaced
        %(#{ESC_BS}f[CR]<BOUNDARY>#{node.text}</BOUNDARY>#{ESC_BS}fP)
      when :single
        %[#{ESC_BS}(oq<BOUNDARY>#{node.text}</BOUNDARY>#{ESC_BS}(cq]
      when :double
        %[#{ESC_BS}(lq<BOUNDARY>#{node.text}</BOUNDARY>#{ESC_BS}(rq]
      else
        node.text
      end
    end

    def resolve_content node
      node.content_model == :compound ? node.content : %(.sp#{LF}#{manify node.content})
    end
  end
end
