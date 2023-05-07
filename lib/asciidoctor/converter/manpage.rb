# frozen_string_literal: true
module Asciidoctor
# A built-in {Converter} implementation that generates the man page (troff) format.
#
# The output of this converter adheres to the man definition as defined by
# groff and uses the manpage output of the DocBook toolchain as a foundation.
# That means if you've previously been generating man pages using the a2x tool
# from AsciiDoc.py, you should be able to achieve a very similar result
# using this converter. Though you'll also get to enjoy some notable
# enhancements that have been added since, such as the customizable linkstyle.
#
# See http://www.gnu.org/software/groff/manual/html_node/Man-usage.html#Man-usage
class Converter::ManPageConverter < Converter::Base
  register_for 'manpage'

  WHITESPACE = %(#{LF}#{TAB} )
  ET = ' ' * 8
  ESC = ?\u001b # troff leader marker
  ESC_BS = %(#{ESC}\\) # escaped backslash (indicates troff formatting sequence)
  ESC_FS = %(#{ESC}.)  # escaped full stop (indicates troff macro)

  LiteralBackslashRx = /\A\\|(#{ESC})?\\/
  LeadingPeriodRx = /^\./
  EscapedMacroRx = /^(?:#{ESC}\\c\n)?#{ESC}\.((?:URL|MTO) "#{CC_ANY}*?" "#{CC_ANY}*?" )( |[^\s]*)(#{CC_ANY}*?)(?: *#{ESC}\\c)?$/
  MalformedEscapedMacroRx = /(#{ESC}\\c) (#{ESC}\.(?:URL|MTO) )/
  MockMacroRx = %r(</?(#{ESC}\\[^>]+)>)
  EmDashCharRefRx = /&#8212;(?:&#8203;)?/
  EllipsisCharRefRx = /&#8230;(?:&#8203;)?/
  WrappedIndentRx = /#{CG_BLANK}*#{LF}#{CG_BLANK}*/
  XMLMarkupRx = /&#?[a-z\d]+;|</
  PCDATAFilterRx = %r((&#?[a-z\d]+;|<#{ESC}\\f\(CR.*?</#{ESC}\\fP>|<[^>]+>)|([^&<]+))

  def initialize backend, opts = {}
    @backend = backend
    init_backend_traits basebackend: 'manpage', filetype: 'man', outfilesuffix: '.man', supports_templates: true
  end

  def convert_document node
    unless node.attr? 'mantitle'
      raise 'asciidoctor: ERROR: doctype must be set to manpage when using manpage backend'
    end
    mantitle = (node.attr 'mantitle').gsub InvalidSectionIdCharsRx, ''
    manvolnum = node.attr 'manvolnum', '1'
    manname = node.attr 'manname', mantitle
    manmanual = node.attr 'manmanual'
    mansource = node.attr 'mansource'
    docdate = (node.attr? 'reproducible') ? nil : (node.attr 'docdate')
    # NOTE the first line enables the table (tbl) preprocessor, necessary for non-Linux systems
    result = [%('\\" t
.\\"     Title: #{mantitle}
.\\"    Author: #{(node.attr? 'authors') ? (node.attr 'authors') : '[see the "AUTHOR(S)" section]'}
.\\" Generator: Asciidoctor #{node.attr 'asciidoctor-version'})]
    result << %(.\\"      Date: #{docdate}) if docdate
    result << %(.\\"    Manual: #{manmanual ? (manmanual.tr_s WHITESPACE, ' ') : '\ \&'}
.\\"    Source: #{mansource ? (mansource.tr_s WHITESPACE, ' ') : '\ \&'}
.\\"  Language: English
.\\")
    # TODO add document-level setting to disable capitalization of manname
    result << %(.TH "#{manify manname.upcase}" "#{manvolnum}" "#{docdate}" "#{mansource ? (manify mansource) : '\ \&'}" "#{manmanual ? (manify manmanual) : '\ \&'}")
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
    # Usage
    #
    # .URL "http://www.debian.org" "Debian" "."
    #
    # * First argument: the URL
    # * Second argument: text to be hyperlinked
    # * Third (optional) argument: text that needs to immediately trail the hyperlink without intervening whitespace
    result << '.de URL
\\fI\\\\$2\\fP <\\\\$1>\\\\$3
..
.als MTO URL
.if \n[.g] \{\
.  mso www.tmac
.  am URL
.    ad l
.  .
.  am MTO
.    ad l
.  .'
    result << %(.  LINKSTYLE #{node.attr 'man-linkstyle', 'blue R < >'})
    result << '.\}'

    unless node.noheader
      if node.attr? 'manpurpose'
        mannames = node.attr 'mannames', [manname]
        result << %(.SH "#{(node.attr 'manname-title', 'NAME').upcase}"
#{mannames.map {|n| (manify n).gsub '\-', '-' }.join ', '} \\- #{manify node.attr('manpurpose'), whitespace: :normalize})
      end
    end

    result << node.content

    # QUESTION should NOTES come after AUTHOR(S)?
    append_footnotes result, node

    unless (authors = node.authors).empty?
      if authors.size > 1
        result << '.SH "AUTHORS"'
        authors.each do |author|
          result << %(.sp
#{author.name})
        end
      else
        result << %(.SH "AUTHOR"
.sp
#{authors[0].name})
      end
    end

    result.join LF
  end

  # NOTE embedded doesn't really make sense in the manpage backend
  def convert_embedded node
    result = [node.content]

    append_footnotes result, node

    # QUESTION should we add an AUTHOR(S) section?

    result.join LF
  end

  def convert_section node
    result = []
    if node.level > 1
      macro = 'SS'
      # QUESTION why captioned title? why not when level == 1?
      stitle = node.captioned_title
    else
      macro = 'SH'
      stitle = uppercase_pcdata node.title
    end
    result << %(.#{macro} "#{manify stitle}"
#{node.content})
    result.join LF
  end

  def convert_admonition node
    result = []
    result << %(.if n .sp
.RS 4
.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
.ps +1
.B #{node.attr 'textlabel'}#{node.title? ? "\\fP: #{manify node.title}" : ''}
.ps -1
.br
#{enclose_content node}
.sp .5v
.RE)
    result.join LF
  end

  def convert_colist node
    result = []
    result << %(.sp
.B #{manify node.title}
.br) if node.title?
    result << '.TS
tab(:);
r lw(\n(.lu*75u/100u).'

    num = 0
    node.items.each do |item|
      result << %(\\fB(#{num += 1})\\fP\\h'-2n':T{)
      result << (manify item.text, whitespace: :normalize)
      result << item.content if item.blocks?
      result << 'T}'
    end
    result << '.TE'
    result.join LF
  end

  # TODO implement horizontal (if it makes sense)
  def convert_dlist node
    result = []
    result << %(.sp
.B #{manify node.title}
.br) if node.title?
    counter = 0
    node.items.each do |terms, dd|
      counter += 1
      case node.style
      when 'qanda'
        result << %(.sp
#{counter}. #{manify terms.map {|dt| dt.text }.join ' '}
.RS 4)
      else
        result << %(.sp
#{manify terms.map {|dt| dt.text }.join(', '), whitespace: :normalize}
.RS 4)
      end
      if dd
        result << (manify dd.text, whitespace: :normalize) if dd.text?
        result << dd.content if dd.blocks?
      end
      result << '.RE'
    end
    result.join LF
  end

  def convert_example node
    result = []
    result << (node.title? ? %(.sp
.B #{manify node.captioned_title}
.br) : '.sp')
    result << %(.RS 4
#{enclose_content node}
.RE)
    result.join LF
  end

  def convert_floating_title node
    %(.SS "#{manify node.title}")
  end

  def convert_image node
    result = []
    result << (node.title? ? %(.sp
.B #{manify node.captioned_title}
.br) : '.sp')
    result << %([#{manify node.alt}])
    result.join LF
  end

  def convert_listing node
    result = []
    result << %(.sp
.B #{manify node.captioned_title}
.br) if node.title?
    result << %(.sp
.if n .RS 4
.nf
.fam C
#{manify node.content, whitespace: :preserve}
.fam
.fi
.if n .RE)
    result.join LF
  end

  def convert_literal node
    result = []
    result << %(.sp
.B #{manify node.title}
.br) if node.title?
    result << %(.sp
.if n .RS 4
.nf
.fam C
#{manify node.content, whitespace: :preserve}
.fam
.fi
.if n .RE)
    result.join LF
  end

  def convert_sidebar node
    result = []
    result << (node.title? ? %(.sp
.B #{manify node.title}
.br) : '.sp')
    result << %(.RS 4
#{enclose_content node}
.RE)
    result.join LF
  end

  def convert_olist node
    result = []
    result << %(.sp
.B #{manify node.title}
.br) if node.title?

    start = (node.attr 'start', 1).to_i
    node.items.each_with_index do |item, idx|
      result << %(.sp
.RS 4
.ie n \\{\\
\\h'-04' #{numeral = idx + start}.\\h'+01'\\c
.\\}
.el \\{\\
.  sp -1
.  IP " #{numeral}." 4.2
.\\}
#{manify item.text, whitespace: :normalize})
      result << item.content if item.blocks?
      result << '.RE'
    end
    result.join LF
  end

  def convert_open node
    case node.style
    when 'abstract', 'partintro'
      enclose_content node
    else
      node.content
    end
  end

  def convert_page_break node
    '.bp'
  end

  def convert_paragraph node
    if node.title?
      %(.sp
.B #{manify node.title}
.br
#{manify node.content, whitespace: :normalize})
    else
      %(.sp
#{manify node.content, whitespace: :normalize})
    end
  end

  alias convert_pass content_only
  alias convert_preamble content_only

  def convert_quote node
    result = []
    if node.title?
      result << %(.sp
.RS 3
.B #{manify node.title}
.br
.RE)
    end
    attribution_line = (node.attr? 'citetitle') ? %(#{node.attr 'citetitle'} ) : nil
    attribution_line = (node.attr? 'attribution') ? %[#{attribution_line}\\(em #{node.attr 'attribution'}] : nil
    result << %(.RS 3
.ll -.6i
#{enclose_content node}
.br
.RE
.ll)
    if attribution_line
      result << %(.RS 5
.ll -.10i
#{attribution_line}
.RE
.ll)
    end
    result.join LF
  end

  def convert_stem node
    result = []
    result << (node.title? ? %(.sp
.B #{manify node.title}
.br) : '.sp')
    open, close = BLOCK_MATH_DELIMITERS[node.style.to_sym]
    if ((equation = node.content).start_with? open) && (equation.end_with? close)
      equation = equation.slice open.length, equation.length - open.length - close.length
    end
    result << %(#{manify equation, whitespace: :preserve} (#{node.style}))
    result.join LF
  end

  # FIXME: The reason this method is so complicated is because we are not
  # receiving empty(marked) cells when there are colspans or rowspans. This
  # method has to create a map of all cells and in the case of rowspans
  # create empty cells as placeholders of the span.
  # To fix this, asciidoctor needs to provide an API to tell the user if a
  # given cell is being used as a colspan or rowspan.
  def convert_table node
    result = []
    if node.title?
      result << %(.sp
.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
.B #{manify node.captioned_title}
)
    end
    result << '.TS
allbox tab(:);'
    row_header = []
    row_text = []
    row_index = 0
    node.rows.to_h.each do |tsec, rows|
      rows.each do |row|
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
          cell_halign = (cell.attr 'halign', 'left').chr
          if tsec == :body
            if row_header[row_index].empty? || row_header[row_index][cell_index].empty?
              row_header[row_index][cell_index] << %(#{cell_halign}t)
            else
              row_header[row_index][cell_index + 1] ||= []
              row_header[row_index][cell_index + 1] << %(#{cell_halign}t)
            end
            case cell.style
            when :asciidoc
              cell_content = cell.content
            when :literal
              cell_content = %(.nf#{LF}#{manify cell.text, whitespace: :preserve}#{LF}.fi)
            else
              cell_content = manify cell.content.join, whitespace: :normalize
            end
            row_text[row_index] << %(#{cell_content}#{LF})
          else # tsec == :head || tsec == :foot
            if row_header[row_index].empty? || row_header[row_index][cell_index].empty?
              row_header[row_index][cell_index] << %(#{cell_halign}tB)
            else
              row_header[row_index][cell_index + 1] ||= []
              row_header[row_index][cell_index + 1] << %(#{cell_halign}tB)
            end
            row_text[row_index] << %(#{manify cell.text, whitespace: :normalize}#{LF})
          end
          if cell.colspan && cell.colspan > 1
            (cell.colspan - 1).times do |i|
              if row_header[row_index].empty? || row_header[row_index][cell_index].empty?
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
              if row_header[row_index + 1 + i].empty? || row_header[row_index + 1 + i][cell_index].empty?
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
      end unless rows.empty?
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
    result << ('lt ' * row_header[0].size).chop

    result << %(.#{LF})
    row_text.each do |row|
      result << row.join
    end
    result << %(.TE#{LF}.sp)
    result.join
  end

  def convert_thematic_break node
    '.sp
.ce
\l\'\n(.lu*25u/100u\(ap\''
  end

  alias convert_toc skip

  def convert_ulist node
    result = []
    result << %(.sp
.B #{manify node.title}
.br) if node.title?
    node.items.map do |item|
      result << %[.sp
.RS 4
.ie n \\{\\
\\h'-04'\\(bu\\h'+03'\\c
.\\}
.el \\{\\
.  sp -1
.  IP \\(bu 2.3
.\\}
#{manify item.text, whitespace: :normalize}]
      result << item.content if item.blocks?
      result << '.RE'
    end
    result.join LF
  end

  def convert_verse node
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
#{manify node.content, whitespace: :preserve}
.fi
.br)
    if attribution_line
      result << %(.in +.5i
.ll -.5i
#{attribution_line}
.in
.ll)
    end
    result.join LF
  end

  def convert_video node
    start_param = (node.attr? 'start') ? %(&start=#{node.attr 'start'}) : ''
    end_param = (node.attr? 'end') ? %(&end=#{node.attr 'end'}) : ''
    result = []
    result << (node.title? ? %(.sp
.B #{manify node.title}
.br) : '.sp')
    result << %(<#{node.media_uri(node.attr 'target')}#{start_param}#{end_param}> (video))
    result.join LF
  end

  def convert_inline_anchor node
    target = node.target
    case node.type
    when :link
      if target.start_with? 'mailto:'
        macro = 'MTO'
        target = target.slice 7, target.length
      else
        macro = 'URL'
      end
      if (text = node.text) == target
        text = ''
      else
        text = text.gsub '"', %[#{ESC_BS}(dq]
      end
      target = target.sub '@', %[#{ESC_BS}(at] if macro == 'MTO'
      %(#{ESC_BS}c#{LF}#{ESC_FS}#{macro} "#{target}" "#{text}" )
    when :xref
      unless (text = node.text)
        if AbstractNode === (ref = (@refs ||= node.document.catalog[:refs])[refid = node.attributes['refid']] || (refid.nil_or_empty? ? (top = get_root_document node) : nil))
          if (@resolving_xref ||= (outer = true)) && outer && (text = ref.xreftext node.attr 'xrefstyle', nil, true)
            text = uppercase_pcdata text if ref.context === :section && ref.level < 2 && text == ref.title
          else
            text = top ? '[^top]' : %([#{refid}])
          end
          @resolving_xref = nil if outer
        else
          text = %([#{refid}])
        end
      end
      text
    when :ref, :bibref
      # These are anchor points, which shouldn't be visible
      ''
    else
      logger.warn %(unknown anchor type: #{node.type.inspect})
      nil
    end
  end

  def convert_inline_break node
    %(#{node.text}#{LF}#{ESC_FS}br)
  end

  def convert_inline_button node
    %(<#{ESC_BS}fB>[#{ESC_BS}0#{node.text}#{ESC_BS}0]</#{ESC_BS}fP>)
  end

  def convert_inline_callout node
    %(<#{ESC_BS}fB>(#{node.text})<#{ESC_BS}fP>)
  end

  def convert_inline_footnote node
    if (index = node.attr 'index')
      %([#{index}])
    elsif node.type == :xref
      %([#{node.text}])
    end
  end

  def convert_inline_image node
    (node.attr? 'link') ? %([#{node.alt}] <#{node.attr 'link'}>) : %([#{node.alt}])
  end

  def convert_inline_indexterm node
    node.type == :visible ? node.text : ''
  end

  def convert_inline_kbd node
    %[<#{ESC_BS}f(CR>#{(keys = node.attr 'keys').size == 1 ? keys[0] : (keys.join "#{ESC_BS}0+#{ESC_BS}0")}</#{ESC_BS}fP>]
  end

  def convert_inline_menu node
    caret = %[#{ESC_BS}0#{ESC_BS}(fc#{ESC_BS}0]
    menu = node.attr 'menu'
    if !(submenus = node.attr 'submenus').empty?
      submenu_path = submenus.map {|item| %(<#{ESC_BS}fI>#{item}</#{ESC_BS}fP>) }.join caret
      %(<#{ESC_BS}fI>#{menu}</#{ESC_BS}fP>#{caret}#{submenu_path}#{caret}<#{ESC_BS}fI>#{node.attr 'menuitem'}</#{ESC_BS}fP>)
    elsif (menuitem = node.attr 'menuitem')
      %(<#{ESC_BS}fI>#{menu}#{caret}#{menuitem}</#{ESC_BS}fP>)
    else
      %(<#{ESC_BS}fI>#{menu}</#{ESC_BS}fP>)
    end
  end

  # NOTE use fake XML elements to prevent creating artificial word boundaries
  def convert_inline_quoted node
    case node.type
    when :emphasis
      %(<#{ESC_BS}fI>#{node.text}</#{ESC_BS}fP>)
    when :strong
      %(<#{ESC_BS}fB>#{node.text}</#{ESC_BS}fP>)
    when :monospaced
      %[<#{ESC_BS}f(CR>#{node.text}</#{ESC_BS}fP>]
    when :single
      %[<#{ESC_BS}(oq>#{node.text}</#{ESC_BS}(cq>]
    when :double
      %[<#{ESC_BS}(lq>#{node.text}</#{ESC_BS}(rq>]
    else
      node.text
    end
  end

  def self.write_alternate_pages mannames, manvolnum, target
    return unless mannames && mannames.size > 1
    mannames.shift
    manvolext = %(.#{manvolnum})
    dir, basename = ::File.split target
    mannames.each do |manname|
      ::File.write ::File.join(dir, %(#{manname}#{manvolext})), %(.so #{basename}), mode: FILE_WRITE_MODE
    end
  end

  private

  def append_footnotes result, node
    if node.footnotes? && !(node.attr? 'nofootnotes')
      result << '.SH "NOTES"'
      node.footnotes.each do |fn|
        result << %(.IP [#{fn.index}])
        # NOTE restore newline in escaped macro that gets removed by normalize_text in substitutor
        if (text = fn.text).include? %(#{ESC}\\c #{ESC}.)
          text = (manify %(#{text.gsub MalformedEscapedMacroRx, %(\\1#{LF}\\2)} ), whitespace: :normalize).chomp ' '
        else
          text = manify text, whitespace: :normalize
        end
        result << text
      end
    end
  end

  # Converts HTML entity references back to their original form, escapes
  # special man characters and strips trailing whitespace.
  #
  # It's crucial that text only ever pass through manify once.
  #
  # str  - the String to convert
  # opts - an Hash of options to control processing (default: {})
  #        * :whitespace an enum that indicates how to handle whitespace; supported options are:
  #          :preserve - preserve spaces (only expanding tabs); :normalize - normalize whitespace
  #          (remove spaces around newlines); :collapse - collapse adjacent whitespace to a single
  #          space (default: :collapse)
  #        * :append_newline a Boolean that indicates whether to append a newline to the result (default: false)
  def manify str, opts = {}
    case opts.fetch :whitespace, :collapse
    when :preserve
      str = str.gsub TAB, ET
    when :normalize
      str = str.gsub WrappedIndentRx, LF
    else
      str = str.tr_s WHITESPACE, ' '
    end
    str = str
      .gsub(LiteralBackslashRx) { $1 ? $& : '\\(rs' } # literal backslash (not a troff escape sequence)
      .gsub(EllipsisCharRefRx, '...') # horizontal ellipsis
      .gsub(LeadingPeriodRx, '\\\&.') # leading . is used in troff for macro call or other formatting; replace with \&.
      .gsub(EscapedMacroRx) do # drop orphaned \c escape lines, unescape troff macro, quote adjacent character, isolate macro line
        (rest = $3.lstrip).empty? ? %(.#{$1}"#{$2}") : %(.#{$1}"#{$2.rstrip}"#{LF}#{rest})
      end
      .gsub('-', '\-')
      .gsub('&lt;', '<')
      .gsub('&gt;', '>')
      .gsub('&#43;', '+')       # plus sign; alternately could use \c(pl
      .gsub('&#160;', '\~')     # non-breaking space
      .gsub('&#169;', '\(co')   # copyright sign
      .gsub('&#174;', '\(rg')   # registered sign
      .gsub('&#8482;', '\(tm')  # trademark sign
      .gsub('&#176;', '\(de')   # degree sign
      .gsub('&#8201;', ' ')     # thin space
      .gsub('&#8211;', '\(en')  # en dash
      .gsub(EmDashCharRefRx, '\(em') # em dash
      .gsub('&#8216;', '\(oq')  # left single quotation mark
      .gsub('&#8217;', '\(cq')  # right single quotation mark
      .gsub('&#8220;', '\(lq')  # left double quotation mark
      .gsub('&#8221;', '\(rq')  # right double quotation mark
      .gsub('&#8592;', '\(<-')  # leftwards arrow
      .gsub('&#8594;', '\(->')  # rightwards arrow
      .gsub('&#8656;', '\(lA')  # leftwards double arrow
      .gsub('&#8658;', '\(rA')  # rightwards double arrow
      .gsub('&#8203;', '\:')    # zero width space
      .gsub('&amp;', '&')       # literal ampersand (NOTE must take place after any other replacement that includes &)
      .gsub('\'', '\*(Aq')      # apostrophe / neutral single quote
      .gsub(MockMacroRx, '\1')  # mock boundary
      .gsub(ESC_BS, '\\')       # unescape troff backslash (NOTE update if more escapes are added)
      .gsub(ESC_FS, '.')        # unescape full stop in troff commands (NOTE must take place after gsub(LeadingPeriodRx))
      .rstrip                   # strip trailing space
    opts[:append_newline] ? %(#{str}#{LF}) : str
  end

  def uppercase_pcdata string
    (XMLMarkupRx.match? string) ? string.gsub(PCDATAFilterRx) { $2 ? $2.upcase : $1 } : string.upcase
  end

  def enclose_content node
    node.content_model == :compound ? node.content : %(.sp#{LF}#{manify node.content, whitespace: :normalize})
  end

  def get_root_document node
    while (node = node.document).nested?
      node = node.parent_document
    end
    node
  end
end
end
