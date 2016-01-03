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

    alias :[] :send
  end

  # Public: A String key that specifies the default table format in AsciiDoc (psv)
  DEFAULT_DATA_FORMAT = 'psv'

  # Public: An Array of String keys that represent the table formats in AsciiDoc
  DATA_FORMATS = ['psv', 'dsv', 'csv']

  # Public: A Hash mapping the AsciiDoc table formats to their default delimiters
  DEFAULT_DELIMITERS = {
    'psv' => '|',
    'dsv' => ':',
    'csv' => ','
  }

  # Public: A Hash mapping styles abbreviations to styles that can be applied
  # to a table column or cell
  TEXT_STYLES = {
    'd' => :none,
    's' => :strong,
    'e' => :emphasis,
    'm' => :monospaced,
    'h' => :header,
    'l' => :literal,
    'v' => :verse,
    'a' => :asciidoc
  }

  # Public: A Hash mapping alignment abbreviations to alignments (horizontal
  # and vertial) that can be applies to a table column or cell
  ALIGNMENTS = {
    :h => {
      '<' => 'left',
      '>' => 'right',
      '^' => 'center'
    },
    :v => {
      '<' => 'top',
      '>' => 'bottom',
      '^' => 'middle'
    }
  }

  # Public: Get/Set the columns for this table
  attr_accessor :columns

  # Public: Get/Set the Rows struct for this table (encapsulates head, foot
  # and body rows)
  attr_accessor :rows

  # Public: Boolean specifies whether this table has a header row
  attr_accessor :has_header_option

  def initialize parent, attributes
    super parent, :table
    @rows = Rows.new
    @columns = []

    @has_header_option = attributes.key? 'header-option'

    # smell like we need a utility method here
    # to resolve an integer width from potential bogus input
    pcwidth = attributes['width']
    pcwidth_intval = pcwidth.to_i.abs
    if pcwidth_intval == 0 && pcwidth != '0' || pcwidth_intval > 100
      pcwidth_intval = 100
    end
    @attributes['tablepcwidth'] = pcwidth_intval

    if @document.attributes.key? 'pagewidth'
      @attributes['tableabswidth'] ||=
          ((@attributes['tablepcwidth'].to_f / 100) * @document.attributes['pagewidth']).round
    end
  end

  # Internal: Returns whether the current row being processed is
  # the header row
  def header_row?
    @has_header_option && @rows.body.empty?
  end

  # Internal: Creates the Column objects from the column spec
  #
  # returns nothing
  def create_columns col_specs
    cols = []
    width_base = 0
    col_specs.each do |col_spec|
      width_base += col_spec['width']
      cols << (Column.new self, cols.size, col_spec)
    end
    unless (@columns = cols).empty?
      @attributes['colcount'] = cols.size
      assign_col_widths(width_base == 0 ? nil : width_base)
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
  def assign_col_widths width_base = nil
    pf = 10.0 ** 4 # precision factor (multipler / divisor) for managing precision of calculated result
    total_width = col_pcwidth = 0

    if width_base
      @columns.each {|col| total_width += (col_pcwidth = col.assign_width nil, width_base, pf) }
    else
      col_pcwidth = ((100 * pf / @columns.size).to_i) / pf
      col_pcwidth = col_pcwidth.to_i if col_pcwidth.to_i == col_pcwidth
      @columns.each {|col| total_width += col.assign_width col_pcwidth }
    end

    # donate balance, if any, to final column
    @columns[-1].assign_width(((100 - total_width + col_pcwidth) * pf).round / pf) unless total_width == 100

    nil
  end

  # Internal: Partition the rows into header, footer and body as determined
  # by the options on the table
  #
  # returns nothing
  def partition_header_footer(attributes)
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

    if num_body_rows > 0 && attributes.key?('footer-option')
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
  alias :table :parent

  # Internal: Calculate and assign the widths (percentage and absolute) for this column
  #
  # This method assigns the colpcwidth and colabswidth attributes.
  #
  # returns the resolved colpcwidth value
  def assign_width col_pcwidth, width_base = nil, pf = 10000.0
    if width_base
      col_pcwidth = ((@attributes['width'].to_f / width_base) * 100 * pf).to_i / pf
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
  alias :column :parent

  # Public: The internal Asciidoctor::Document for a cell that has the asciidoc style
  attr_reader :inner_document

  def initialize column, text, attributes = {}, cursor = nil
    super column, :cell
    @text = text
    @style = nil
    @colspan = nil
    @rowspan = nil
    # TODO feels hacky
    if column
      @style = column.attributes['style']
      update_attributes(column.attributes)
    end
    if attributes
      @colspan = attributes.delete('colspan')
      @rowspan = attributes.delete('rowspan')
      # TODO eventualy remove the style attribute from the attributes hash
      #@style = attributes.delete('style') if attributes.key? 'style'
      @style = attributes['style'] if attributes.key? 'style'
      update_attributes(attributes)
    end
    # only allow AsciiDoc cells in non-header rows
    if @style == :asciidoc && !column.table.header_row?
      # FIXME hide doctitle from nested document; temporary workaround to fix
      # nested document seeing doctitle and assuming it has its own document title
      parent_doctitle = @document.attributes.delete('doctitle')
      # NOTE we need to process the first line of content as it may not have been processed
      # the included content cannot expect to match conditional terminators in the remaining
      # lines of table cell content, it must be self-contained logic
      inner_document_lines = @text.split(EOL)
      unless inner_document_lines.empty? || !inner_document_lines[0].include?('::')
        unprocessed_lines = inner_document_lines[0]
        processed_lines = PreprocessorReader.new(@document, unprocessed_lines).readlines
        if processed_lines != unprocessed_lines
          inner_document_lines.shift
          inner_document_lines.unshift(*processed_lines)
        end
      end
      @inner_document = Document.new(inner_document_lines, :header_footer => false, :parent => @document, :cursor => cursor)
      @document.attributes['doctitle'] = parent_doctitle unless parent_doctitle.nil?
    end
  end

  # Public: Get the text with normal substitutions applied for this cell. Used for cells in the head rows
  def text
    apply_normal_subs(@text).strip
  end

  # Public: Handles the body data (tbody, tfoot), applying styles and partitioning into paragraphs
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

  # Public: The Table currently being parsed
  attr_accessor :table

  # Public: The AsciiDoc table format (psv, dsv or csv)
  attr_accessor :format

  # Public: Get the expected column count for a row
  #
  # col_count is the number of columns to pull into a row
  # A value of -1 means we use the number of columns found
  # in the first line as the col_count
  attr_reader :col_count

  # Public: The String buffer of the currently open cell
  attr_accessor :buffer

  # Public: The cell delimiter for this table.
  attr_reader :delimiter

  # Public: The cell delimiter compiled Regexp for this table.
  attr_reader :delimiter_re

  def initialize(reader, table, attributes = {})
    @reader = reader
    @table = table
    # TODO if reader.cursor becomes a reference, this would require .dup
    @last_cursor = reader.cursor
    if (@format = attributes['format'])
      unless Table::DATA_FORMATS.include? @format
        raise %(Illegal table format: #{@format})
      end
    else
      @format = Table::DEFAULT_DATA_FORMAT
    end

    @delimiter = if @format == 'psv' && !(attributes.key? 'separator') && table.document.nested?
      '!'
    else
      attributes['separator'] || Table::DEFAULT_DELIMITERS[@format]
    end
    @delimiter_re = /#{Regexp.escape @delimiter}/
    @col_count = table.columns.empty? ? -1 : table.columns.size
    @buffer = ''
    @cell_specs = []
    @cell_open = false
    @active_rowspans = [0]
    @col_visits = 0
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

  # Public: Skip beyond the matched delimiter because it was a false positive
  # (either because it was escaped or in a quoted context)
  #
  # returns the String after the match
  def skip_matched_delimiter(match, escaped = false)
    @buffer = %(#{@buffer}#{escaped ? match.pre_match.chop : match.pre_match}#{@delimiter})
    match.post_match
  end

  # Public: Determines whether the buffer has unclosed quotes. Used for CSV data.
  #
  # returns true if the buffer has unclosed quotes, false if it doesn't or it
  # isn't quoted data
  def buffer_has_unclosed_quotes?(append = nil)
    record = %(#{@buffer}#{append}).strip
    record.start_with?('"') && !record.start_with?('""') && !record.end_with?('"')
  end

  # Public: Determines whether the buffer contains quoted data. Used for CSV data.
  #
  # returns true if the buffer starts with a double quote (and not an escaped double quote),
  # false otherwise
  def buffer_quoted?
    @buffer = @buffer.lstrip
    @buffer.start_with?('"') && !@buffer.start_with?('""')
  end

  # Public: Takes a cell spec from the stack. Cell specs precede the delimiter, so a
  # stack is used to carry over the spec from the previous cell to the current cell
  # when the cell is being closed.
  #
  # returns The cell spec Hash captured from parsing the previous cell
  def take_cell_spec()
    @cell_specs.shift
  end

  # Public: Puts a cell spec onto the stack. Cell specs precede the delimiter, so a
  # stack is used to carry over the spec to the next cell.
  #
  # returns nothing
  def push_cell_spec(cell_spec = {})
    # this shouldn't be nil, but we check anyway
    @cell_specs << (cell_spec || {})
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
  def close_open_cell(next_cell_spec = {})
    push_cell_spec next_cell_spec
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
    cell_text = @buffer.strip
    @buffer = ''
    if @format == 'psv'
      cell_spec = take_cell_spec
      if cell_spec
        repeat = cell_spec.fetch('repeatcol', 1)
        cell_spec.delete('repeatcol')
      else
        warn %(asciidoctor: ERROR: #{@last_cursor.line_info}: table missing leading separator, recovering automatically)
        cell_spec = {}
        repeat = 1
      end
    else
      cell_spec = nil
      repeat = 1
      if @format == 'csv'
        if !cell_text.empty? && cell_text.include?('"')
          # this may not be perfect logic, but it hits the 99%
          if cell_text.start_with?('"') && cell_text.end_with?('"')
            # unquote
            cell_text = cell_text[1...-1].strip
          end

          # collapses escaped quotes
          cell_text = cell_text.tr_s('"', '"')
        end
      end
    end

    1.upto(repeat) do |i|
      # TODO make column resolving an operation
      if @col_count == -1
        @table.columns << (column = Table::Column.new(@table, @table.columns.size + i - 1))
        if cell_spec && (cell_spec.key? 'colspan') && (extra_cols = cell_spec['colspan'].to_i - 1) > 0
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

      cell = Table::Cell.new(column, cell_text, cell_spec, @last_cursor)
      @last_cursor = @reader.cursor
      unless !cell.rowspan || cell.rowspan == 1
        activate_rowspan(cell.rowspan, (cell.colspan || 1))
      end
      @col_visits += (cell.colspan || 1)
      @current_row << cell
      # don't close the row if we're on the first line and the column count has not been set explicitly
      # TODO perhaps the col_count/linenum logic should be in end_of_row? (or a should_end_row? method)
      close_row if end_of_row? && (@col_count != -1 || @linenum > 0 || (eol && i == repeat))
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
    @col_count = @col_visits if @col_count == -1
    @col_visits = 0
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
    @col_count == -1 || effective_col_visits == @col_count
  end

  # Public: Calculate the effective column visits, which consists of the number of
  # cells plus any active rowspans.
  def effective_col_visits
    @col_visits + @active_rowspans[0]
  end

  # Internal: Advance to the next line (which may come after the parser begins processing
  # the next line if the last cell had wrapped content).
  def advance
    @linenum += 1
  end

end
end
