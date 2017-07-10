# encoding: UTF-8
module Asciidoctor
# Public: Methods and constants for managing AsciiDoc table content in a document.
# It supports all three of AsciiDoc's table formats: psv, dsv and csv.
class Table < AbstractBlock

  # Public: A data object that encapsulates the collection of rows (head, foot, body) for a table
  class Rows
    attr_accessor :head, :foot, :body

    def initialize head = [], foot = [], body = []
      @head = head
      @foot = foot
      @body = body
    end

    alias [] send

    # Public: Returns the rows grouped by section.
    #
    # Creates a 2-dimensional array of two element entries. The first element
    # is the section name as a symbol. The second element is the Array of rows
    # in that section. The entries are in document order (head, foot, body).
    #
    # Returns a 2-dimentional Array of rows grouped by section.
    def by_section
      [[:head, @head], [:foot, @foot], [:body, @body]]
    end
  end

  # Public: Get/Set the columns for this table
  attr_accessor :columns

  # Public: Get/Set the Rows struct for this table (encapsulates head, foot
  # and body rows)
  attr_accessor :rows

  # Public: Boolean specifies whether this table has a header row
  attr_accessor :has_header_option

  # Public: Get the caption for this table
  attr_reader :caption

  def initialize parent, attributes
    super parent, :table
    @rows = Rows.new
    @columns = []

    @has_header_option = attributes.key? 'header-option'

    # smell like we need a utility method here
    # to resolve an integer width from potential bogus input
    if (pcwidth = attributes['width'])
      if (pcwidth_intval = pcwidth.to_i) > 100 || pcwidth_intval < 1
        pcwidth_intval = 100 unless pcwidth_intval == 0 && (pcwidth == '0' || pcwidth == '0%')
      end
    else
      pcwidth_intval = 100
    end
    @attributes['tablepcwidth'] = pcwidth_intval

    if @document.attributes.key? 'pagewidth'
      # FIXME calculate more accurately (only used in DocBook output)
      @attributes['tableabswidth'] ||=
          ((@attributes['tablepcwidth'].to_f / 100) * @document.attributes['pagewidth']).round
    end

    attributes['orientation'] = 'landscape' if attributes.key? 'rotate-option'
  end

  # Internal: Returns whether the current row being processed is
  # the header row
  def header_row?
    @has_header_option && @rows.body.empty?
  end

  # Internal: Creates the Column objects from the column spec
  #
  # returns nothing
  def create_columns colspecs
    cols = []
    width_base = 0
    colspecs.each do |colspec|
      width_base += colspec['width']
      cols << (Column.new self, cols.size, colspec)
    end
    unless (@columns = cols).empty?
      @attributes['colcount'] = cols.size
      assign_column_widths(width_base == 0 ? nil : width_base)
    end
    nil
  end

  # Internal: Assign column widths to columns
  #
  # This method rounds the percentage width values to 4 decimal places and
  # donates the balance to the final column.
  #
  # This method assumes there's at least one column in the columns array.
  #
  # width_base - the total of the relative column values used for calculating percentage widths (default: nil)
  #
  # returns nothing
  def assign_column_widths width_base = nil
    pf = 10.0 ** 4 # precision factor (multipler / divisor) for managing precision of calculated result
    total_width = col_pcwidth = 0

    if width_base
      @columns.each {|col| total_width += (col_pcwidth = col.assign_width nil, width_base, pf) }
    else
      col_pcwidth = ((100 * pf / @columns.size).to_i) / pf
      # or...
      #col_pcwidth = (100.0 / @columns.size).truncate 4
      col_pcwidth = col_pcwidth.to_i if col_pcwidth.to_i == col_pcwidth
      @columns.each {|col| total_width += col.assign_width col_pcwidth }
    end

    # donate balance, if any, to final column (using half up rounding)
    unless total_width == 100
      @columns[-1].assign_width(((100 - total_width + col_pcwidth) * pf).round / pf)
      # or (manual half up rounding)...
      #numerator = (raw_numerator = (100 - total_width + col_pcwidth) * pf).to_i
      #numerator += 1 if raw_numerator >= numerator + 0.5
      #@columns[-1].assign_width numerator / pf
      # or...
      #@columns[-1].assign_width((100 - total_width + col_pcwidth).round 4)
    end

    nil
  end

  # Internal: Partition the rows into header, footer and body as determined
  # by the options on the table
  #
  # returns nothing
  def partition_header_footer(attrs)
    # set rowcount before splitting up body rows
    @attributes['rowcount'] = @rows.body.size

    num_body_rows = @rows.body.size
    if num_body_rows > 0 && @has_header_option
      head = @rows.body.shift
      num_body_rows -= 1
      # styles aren't applied to header row
      head.each {|c| c.style = nil }
      # QUESTION why does AsciiDoc use an array for head? is it
      # possible to have more than one based on the syntax?
      @rows.head = [head]
    end

    if num_body_rows > 0 && attrs.key?('footer-option')
      @rows.foot = [@rows.body.pop]
    end

    nil
  end
end

# Public: Methods to manage the columns of an AsciiDoc table. In particular, it
# keeps track of the column specs
class Table::Column < AbstractNode
  # Public: Get/Set the Symbol style for this column.
  attr_accessor :style

  def initialize table, index, attributes = {}
    super table, :column
    @style = attributes['style']
    attributes['colnumber'] = index + 1
    attributes['width'] ||= 1
    attributes['halign'] ||= 'left'
    attributes['valign'] ||= 'top'
    update_attributes(attributes)
  end

  # Public: An alias to the parent block (which is always a Table)
  alias table parent

  # Internal: Calculate and assign the widths (percentage and absolute) for this column
  #
  # This method assigns the colpcwidth and colabswidth attributes.
  #
  # returns the resolved colpcwidth value
  def assign_width col_pcwidth, width_base = nil, pf = 10000.0
    if width_base
      col_pcwidth = ((@attributes['width'].to_f / width_base) * 100 * pf).to_i / pf
      # or...
      #col_pcwidth = (@attributes['width'].to_f * 100.0 / width_base).truncate 4
      col_pcwidth = col_pcwidth.to_i if col_pcwidth.to_i == col_pcwidth
    end
    @attributes['colpcwidth'] = col_pcwidth
    if parent.attributes.key? 'tableabswidth'
      # FIXME calculate more accurately (only used in DocBook output)
      @attributes['colabswidth'] = ((col_pcwidth / 100.0) * parent.attributes['tableabswidth']).round
    end
    col_pcwidth
  end
end

# Public: Methods for managing the a cell in an AsciiDoc table.
class Table::Cell < AbstractNode
  # Public: Get/Set the Symbol style for this cell (default: nil)
  attr_accessor :style

  # Public: An Integer of the number of columns this cell will span (default: nil)
  attr_accessor :colspan

  # Public: An Integer of the number of rows this cell will span (default: nil)
  attr_accessor :rowspan

  # Public: An alias to the parent block (which is always a Column)
  alias column parent

  # Public: The internal Asciidoctor::Document for a cell that has the asciidoc style
  attr_reader :inner_document

  def initialize column, cell_text, attributes = {}, opts = {}
    super column, :cell
    if column
      cell_style = (in_header_row = column.table.header_row?) ? nil : column.attributes['style']
      # REVIEW feels hacky to inherit all attributes from column
      update_attributes column.attributes
    else
      in_header_row = cell_style = nil
    end
    if attributes
      @colspan = attributes.delete 'colspan'
      @rowspan = attributes.delete 'rowspan'
      # TODO eventually remove the style attribute from the attributes hash
      #cell_style = attributes.delete 'style' unless in_header_row || !(attributes.key? 'style')
      cell_style = attributes['style'] unless in_header_row || !(attributes.key? 'style')
      if opts[:strip_text]
        if cell_style == :literal || cell_style == :verse
          cell_text = cell_text.rstrip
          cell_text = cell_text.slice 1, cell_text.length - 1 while cell_text.start_with? LF
        else
          cell_text = cell_text.strip
        end
      end
      update_attributes attributes
    else
      @colspan = nil
      @rowspan = nil
    end
    # NOTE only true for non-header rows
    if cell_style == :asciidoc
      # FIXME hide doctitle from nested document; temporary workaround to fix
      # nested document seeing doctitle and assuming it has its own document title
      parent_doctitle = @document.attributes.delete('doctitle')
      # NOTE we need to process the first line of content as it may not have been processed
      # the included content cannot expect to match conditional terminators in the remaining
      # lines of table cell content, it must be self-contained logic
      # QUESTION should we reset cell_text to nil?
      # QUESTION is is faster to check for :: before splitting?
      inner_document_lines = cell_text.split LF, -1
      if (unprocessed_line1 = inner_document_lines[0]).include? '::'
        preprocessed_lines = (PreprocessorReader.new @document, [unprocessed_line1]).readlines
        unless unprocessed_line1 == preprocessed_lines[0] && preprocessed_lines.size < 2
          inner_document_lines.shift
          inner_document_lines.unshift(*preprocessed_lines) unless preprocessed_lines.empty?
        end
      end unless inner_document_lines.empty?
      @inner_document = Document.new(inner_document_lines, :header_footer => false, :parent => @document, :cursor => opts[:cursor])
      @document.attributes['doctitle'] = parent_doctitle unless parent_doctitle.nil?
    end
    @text = cell_text
    @style = cell_style
  end

  # Public: Get the String text of this cell with substitutions applied.
  #
  # Used for cells in the head row as well as text-only (non-AsciiDoc) cells in
  # the foot row and body.
  #
  # This method shouldn't be used for cells that have the AsciiDoc style.
  #
  # Returns the converted String text for this Cell
  def text
    apply_subs @text, (@style == :literal ? BASIC_SUBS : NORMAL_SUBS)
  end

  # Public: Set the String text.
  #
  # This method shouldn't be used for cells that have the AsciiDoc style.
  #
  # Returns the new String text assigned to this Cell
  def text= val
    @text = val
  end

  # Public: Handles the body data (tbody, tfoot), applying styles and partitioning into paragraphs
  #
  # This method should not be used for cells in the head row or that have the literal or verse style.
  #
  # Returns the converted String for this Cell
  def content
    if @style == :asciidoc
      @inner_document.convert
    else
      text.split(BlankLineRx).map do |p|
        !@style || @style == :header ? p : Inline.new(parent, :quoted, p, :type => @style).convert
      end
    end
  end

  def to_s
    "#{super.to_s} - [text: #@text, colspan: #{@colspan || 1}, rowspan: #{@rowspan || 1}, attributes: #@attributes]"
  end
end

# Public: Methods for managing the parsing of an AsciiDoc table. Instances of this
# class are primarily responsible for tracking the buffer of a cell as the parser
# moves through the lines of the table using tail recursion. When a cell boundary
# is located, the previous cell is closed, an instance of Table::Cell is
# instantiated, the row is closed if the cell satisifies the column count and,
# finally, a new buffer is allocated to track the next cell.
class Table::ParserContext
  # Public: An Array of String keys that represent the table formats in AsciiDoc
  #--
  # QUESTION should we recognize !sv as a valid format value?
  FORMATS = ['psv', 'csv', 'dsv', 'tsv'].to_set

  # Public: A Hash mapping the AsciiDoc table formats to default delimiters
  DELIMITERS = {
    'psv' => ['|', /\|/],
    'csv' => [',', /,/],
    'dsv' => [':', /:/],
    'tsv' => [%(\t), /\t/],
    '!sv' => ['!', /!/]
  }

  # Public: The Table currently being parsed
  attr_accessor :table

  # Public: The AsciiDoc table format (psv, dsv, or csv)
  attr_accessor :format

  # Public: Get the expected column count for a row
  #
  # colcount is the number of columns to pull into a row
  # A value of -1 means we use the number of columns found
  # in the first line as the colcount
  attr_reader :colcount

  # Public: The String buffer of the currently open cell
  attr_accessor :buffer

  # Public: The cell delimiter for this table.
  attr_reader :delimiter

  # Public: The cell delimiter compiled Regexp for this table.
  attr_reader :delimiter_re

  def initialize reader, table, attributes = {}
    @reader = reader
    @table = table
    # IMPORTANT if reader.cursor becomes a reference, this assignment would require .dup
    @last_cursor = reader.cursor

    if attributes.key? 'format'
      if FORMATS.include?(xsv = attributes['format'])
        if xsv == 'tsv'
          # NOTE tsv is just an alias for csv with a tab separator
          @format = 'csv'
        elsif (@format = xsv) == 'psv' && table.document.nested?
          xsv = '!sv'
        end
      else
        warn %(asciidoctor: ERROR: #{reader.prev_line_info}: illegal table format: #{xsv})
        @format, xsv = 'psv', (table.document.nested? ? '!sv' : 'psv')
      end
    else
      @format, xsv = 'psv', (table.document.nested? ? '!sv' : 'psv')
    end

    if attributes.key? 'separator'
      if (sep = attributes['separator']).nil_or_empty?
        @delimiter, @delimiter_re = DELIMITERS[xsv]
      # QUESTION should we support any other escape codes or multiple tabs?
      elsif sep == '\t'
        @delimiter, @delimiter_re = DELIMITERS['tsv']
      else
        @delimiter, @delimiter_re = sep, /#{::Regexp.escape sep}/
      end
    else
      @delimiter, @delimiter_re = DELIMITERS[xsv]
    end

    @colcount = table.columns.empty? ? -1 : table.columns.size
    @buffer = ''
    @cellspecs = []
    @cell_open = false
    @active_rowspans = [0]
    @column_visits = 0
    @current_row = []
    @linenum = -1
  end

  # Public: Checks whether the line provided starts with the cell delimiter
  # used by this table.
  #
  # returns true if the line starts with the delimiter, false otherwise
  def starts_with_delimiter?(line)
    line.start_with? @delimiter
  end

  # Public: Checks whether the line provided contains the cell delimiter
  # used by this table.
  #
  # returns Regexp MatchData if the line contains the delimiter, false otherwise
  def match_delimiter(line)
    @delimiter_re.match(line)
  end

  # Public: Skip past the matched delimiter because it's inside quoted text.
  #
  # returns the String after the match
  def skip_past_delimiter(match)
    @buffer = %(#{@buffer}#{match.pre_match}#{@delimiter})
    match.post_match
  end

  # Public: Skip past the matched delimiter because it's escaped.
  #
  # returns the String after the match
  def skip_past_escaped_delimiter(match)
    @buffer = %(#{@buffer}#{match.pre_match.chop}#{@delimiter})
    match.post_match
  end

  # Public: Determines whether the buffer has unclosed quotes. Used for CSV data.
  #
  # returns true if the buffer has unclosed quotes, false if it doesn't or it
  # isn't quoted data
  def buffer_has_unclosed_quotes? append = nil
    if (record = append ? (buffer + append).strip : buffer.strip).start_with? '"'
      if ((trailing_quote = record.end_with? '"') && (record.end_with? '""')) || (record.start_with? '""')
        ((record = record.gsub '""', '').start_with? '"') && !(record.end_with? '"')
      else
        !trailing_quote
      end
    else
      false
    end
  end

  # Public: Takes a cell spec from the stack. Cell specs precede the delimiter, so a
  # stack is used to carry over the spec from the previous cell to the current cell
  # when the cell is being closed.
  #
  # returns The cell spec Hash captured from parsing the previous cell
  def take_cellspec
    @cellspecs.shift
  end

  # Public: Puts a cell spec onto the stack. Cell specs precede the delimiter, so a
  # stack is used to carry over the spec to the next cell.
  #
  # returns nothing
  def push_cellspec(cellspec = {})
    # this shouldn't be nil, but we check anyway
    @cellspecs << (cellspec || {})
    nil
  end

  # Public: Marks that the cell should be kept open. Used when the end of the line is
  # reached and the cell may contain additional text.
  #
  # returns nothing
  def keep_cell_open
    @cell_open = true
    nil
  end

  # Public: Marks the cell as closed so that the parser knows to instantiate a new cell
  # instance and add it to the current row.
  #
  # returns nothing
  def mark_cell_closed
    @cell_open = false
    nil
  end

  # Public: Checks whether the current cell is still open
  #
  # returns true if the cell is marked as open, false otherwise
  def cell_open?
    @cell_open
  end

  # Public: Checks whether the current cell has been marked as closed
  #
  # returns true if the cell is marked as closed, false otherwise
  def cell_closed?
    !@cell_open
  end

  # Public: If the current cell is open, close it. In additional, push the
  # cell spec captured from the end of this cell onto the stack for use
  # by the next cell.
  #
  # returns nothing
  def close_open_cell(next_cellspec = {})
    push_cellspec next_cellspec
    close_cell(true) if cell_open?
    advance
    nil
  end

  # Public: Close the current cell, instantiate a new Table::Cell, add it to
  # the current row and, if the number of expected columns for the current
  # row has been met, close the row and begin a new one.
  #
  # returns nothing
  def close_cell(eol = false)
    if @format == 'psv'
      strip_text = true
      cell_text = @buffer
      @buffer = ''
      if (cellspec = take_cellspec)
        repeat = cellspec.delete('repeatcol') || 1
      else
        warn %(asciidoctor: ERROR: #{@last_cursor.line_info}: table missing leading separator, recovering automatically)
        cellspec = {}
        repeat = 1
      end
    else
      strip_text = false
      cell_text = @buffer.strip
      @buffer = ''
      cellspec = nil
      repeat = 1
      if @format == 'csv'
        if !cell_text.empty? && cell_text.include?('"')
          # this may not be perfect logic, but it hits the 99%
          if cell_text.start_with?('"') && cell_text.end_with?('"')
            # unquote
            cell_text = cell_text[1...-1].strip
          end

          # collapse escaped quotes
          cell_text = cell_text.squeeze('"')
        end
      end
    end

    1.upto(repeat) do |i|
      # TODO make column resolving an operation
      if @colcount == -1
        @table.columns << (column = Table::Column.new(@table, @table.columns.size + i - 1))
        if cellspec && (cellspec.key? 'colspan') && (extra_cols = cellspec['colspan'].to_i - 1) > 0
          offset = @table.columns.size
          extra_cols.times do |j|
            @table.columns << Table::Column.new(@table, offset + j)
          end
        end
      else
        # QUESTION is this right for cells that span columns?
        unless (column = @table.columns[@current_row.size])
          warn %(asciidoctor: ERROR: #{@last_cursor.line_info}: dropping cell because it exceeds specified number of columns)
          return
        end
      end

      cell = Table::Cell.new(column, cell_text, cellspec, :cursor => @last_cursor, :strip_text => strip_text)
      @last_cursor = @reader.cursor
      unless !cell.rowspan || cell.rowspan == 1
        activate_rowspan(cell.rowspan, (cell.colspan || 1))
      end
      @column_visits += (cell.colspan || 1)
      @current_row << cell
      # don't close the row if we're on the first line and the column count has not been set explicitly
      # TODO perhaps the colcount/linenum logic should be in end_of_row? (or a should_end_row? method)
      close_row if end_of_row? && (@colcount != -1 || @linenum > 0 || (eol && i == repeat))
    end
    @cell_open = false
    nil
  end

  # Public: Close the row by adding it to the Table and resetting the row
  # Array and counter variables.
  #
  # returns nothing
  def close_row
    @table.rows.body << @current_row
    # don't have to account for active rowspans here
    # since we know this is first row
    @colcount = @column_visits if @colcount == -1
    @column_visits = 0
    @current_row = []
    @active_rowspans.shift
    @active_rowspans[0] ||= 0
    nil
  end

  # Public: Activate a rowspan. The rowspan Array is consulted when
  # determining the effective number of cells in the current row.
  #
  # returns nothing
  def activate_rowspan(rowspan, colspan)
    1.upto(rowspan - 1).each {|i|
      # longhand assignment used for Opal compatibility
      @active_rowspans[i] = (@active_rowspans[i] || 0) + colspan
    }
    nil
  end

  # Public: Check whether we've met the number of effective columns for the current row.
  def end_of_row?
    @colcount == -1 || effective_column_visits == @colcount
  end

  # Public: Calculate the effective column visits, which consists of the number of
  # cells plus any active rowspans.
  def effective_column_visits
    @column_visits + @active_rowspans[0]
  end

  # Internal: Advance to the next line (which may come after the parser begins processing
  # the next line if the last cell had wrapped content).
  def advance
    @linenum += 1
  end

end
end
