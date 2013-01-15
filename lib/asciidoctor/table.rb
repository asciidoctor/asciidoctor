module Asciidoctor
  # Public: Methods and constants for managing AsciiDoc table content in a document.
  # It supports all three of AsciiDoc's table formats: psv, dsv and csv.
  class Table < AbstractBlock
  
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
  
    # Public: A compiled Regexp to match a blank line
    BLANK_LINE_PATTERN = /\n[[:blank:]]*\n/
  
    # Public: Get/Set the String caption (unused, necessary for compatibility w/ next_block)
    attr_accessor :caption
  
    # Public: Get/Set the columns for this table
    attr_accessor :columns
  
    # Public: Get/Set the Rows struct for this table (encapsulates head, foot
    # and body rows)
    attr_accessor :rows
  
    def initialize(parent, attributes)
      super(parent, :table)
      # QUESTION since caption is on block, should it go to AbstractBlock?
      @caption = nil
      @rows = Rows.new([], [], [])
      @columns = []

      unless @attributes.has_key? 'tablepcwidth'
        # smell like we need a utility method here
        # to resolve an integer width from potential bogus input
        pcwidth = attributes['width']
        pcwidth_intval = pcwidth.to_i.abs
        if pcwidth_intval == 0 && pcwidth != "0" || pcwidth_intval > 100
          pcwidth_intval = 100
        end
        @attributes['tablepcwidth'] = pcwidth_intval
      end

      if @document.attributes.has_key? 'pagewidth'
        @attributes['tableabswidth'] ||=
            ((@attributes['tablepcwidth'].to_f / 100) * @document.attributes['pagewidth']).round
      end
    end
  
    # Internal: Creates the Column objects from the column spec
    #
    # returns nothing
    def create_columns(col_specs)
      total_width = 0
      @columns = col_specs.inject([]) {|collector, col_spec|
        total_width += col_spec['width']
        collector << Column.new(self, collector.size, col_spec)
        collector
      }
  
      if !@columns.empty?
        @attributes['colcount'] = @columns.size
        even_width = (100.0 / @columns.size).floor
        @columns.each {|c| c.assign_width(total_width, even_width) }
      end

      nil
    end
  
    # Internal: Partition the rows into header, footer and body as determined
    # by the options on the table
    #
    # returns nothing
    def partition_header_footer(attributes)
      # set rowcount before splitting up body rows
      @attributes['rowcount'] = @rows.body.size
  
      if !rows.body.empty? && attributes.has_key?('header-option')
        head = rows.body.shift
        # styles aren't applied to header row
        head.each {|c| c.attributes.delete('style') }
        # QUESTION why does AsciiDoc use an array for head? is it
        # possible to have more than one based on the syntax?
        rows.head = [head]
      end
  
      if !rows.body.empty? && attributes.has_key?('footer-option')
        rows.foot = [rows.body.pop]
      end
      
      nil
    end
  
    # Public: Get the rendered String content for this Block.  If the block
    # has child blocks, the content method should cause them to be
    # rendered and returned as content that can be included in the
    # parent block's template.
    def render
      Asciidoctor.debug { "Now attempting to render for table my own bad #{self}" }
      Asciidoctor.debug { "Parent is #{@parent}" }
      Asciidoctor.debug { "Renderer is #{renderer}" }
      renderer.render('block_table', self) 
    end
  
  end
  
  # Public: A struct that encapsulates the collection of rows (head, foot, body) for a table
  Table::Rows = Struct.new(:head, :foot, :body)
  
  # Public: Methods to manage the columns of an AsciiDoc table. In particular, it
  # keeps track of the column specs
  class Table::Column < AbstractNode
    def initialize(table, index, attributes = {})
      super(table, :column)
      attributes['colnumber'] = index + 1
      attributes['width'] ||= 1
      attributes['halign'] ||= 'left'
      attributes['valign'] ||= 'top'
      update_attributes(attributes)
    end
  
    # Internal: Calculate and assign the widths (percentage and absolute) for this column
    #
    # This method assigns the colpcwidth and colabswidth attributes.
    #
    # returns nothing
    def assign_width(total_width, even_width)
      if total_width > 0
        width = ((@attributes['width'].to_f / total_width) * 100).floor
      else
        width = even_width
      end
      @attributes['colpcwidth'] = width
      if parent.attributes.has_key? 'tableabswidth'
        @attributes['colabswidth'] = ((width.to_f / 100) * parent.attributes['tableabswidth']).round
      end

      nil
    end
  end
  
  # Public: Methods for managing the a cell in an AsciiDoc table.
  class Table::Cell < AbstractNode

    # Public: An Integer of the number of columns this cell will span (default: nil)
    attr_accessor :colspan

    # Public: An Integer of the number of rows this cell will span (default: nil)
    attr_accessor :rowspan

    # Public: An alias to the parent block (which is always a Column)
    alias :column :parent

    # Public: The internal Asciidoctor::Document for a cell that has the asciidoc style
    attr_reader :inner_document
  
    def initialize(column, text, attributes = {})
      super(column, :cell)
      @text = text
      @colspan = nil
      @rowspan = nil
      # TODO feels hacky
      if !column.nil?
        update_attributes(column.attributes)
      end
      if !attributes.nil?
        if attributes.has_key? 'colspan'
          @colspan = attributes['colspan']
          attributes.delete('colspan') 
        end
        if attributes.has_key? 'rowspan'
          @rowspan = attributes['rowspan']
          attributes.delete('rowspan') 
        end
        update_attributes(attributes)
      end
      if @attributes['style'] == :asciidoc
        @inner_document = Document.new(@text, :header_footer => false, :parent => @document)
      end
    end
  
    # Public: Get the text with normal substitutions applied for this cell. Used for cells in the head rows
    def text
      apply_normal_subs(@text)
    end
  
    # Public: Handles the body data (tbody, tfoot), applying styles and partitioning into paragraphs
    def content
      style = attr('style')
      if style == :asciidoc
        @inner_document.render
      else
        text.split(Table::BLANK_LINE_PATTERN).map {|p|
          !style || style == :header ? p : Inline.new(parent, :quoted, p, :type => attr('style')).render
        }
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
  
    def initialize(table, attributes = {})
      @table = table
      if attributes.has_key? 'format'
        @format = attributes['format']
        if !Table::DATA_FORMATS.include? @format
          raise "Illegal table format: #@format"
        end
      else
        @format = Table::DEFAULT_DATA_FORMAT
      end
  
      if @format == 'psv' && !attributes.has_key?('separator') && table.document.nested?
        @delimiter = '!'
      else
        @delimiter = attributes.fetch('separator', Table::DEFAULT_DELIMITERS[@format])
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
    # returns MatchData if the line contains the delimiter, false otherwise
    def match_delimiter(line)
      line.match @delimiter_re
    end
  
    # Public: Skip beyond the matched delimiter because it was a false positive
    # (either because it was escaped or in a quoted context)
    #
    # returns the String after the match
    def skip_matched_delimiter(match, escaped = false)
      @buffer << (escaped ? match.pre_match.chop : match.pre_match) << @delimiter
      match.post_match
    end
  
    # Public: Determines whether the buffer has unclosed quotes. Used for CSV data.
    #
    # returns true if the buffer has unclosed quotes, false if it doesn't or it 
    # isn't quoted data
    def buffer_has_unclosed_quotes?(append = nil)
      record = "#@buffer#{append}".strip
      record.start_with?('"') && !record.start_with?('""') && !record.end_with?('"')
    end
  
    # Public: Determines whether the buffer contains quoted data. Used for CSV data.
    #
    # returns true if the buffer starts with a double quote (and not an escaped double quote),
    # false otherwise
    def buffer_quoted?
      @buffer.lstrip!
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
      next_line
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
      if format == 'psv'
        cell_spec = take_cell_spec
        repeat = cell_spec.fetch('repeatcol', 1)
        cell_spec.delete('repeatcol')
      else
        cell_spec = nil
        repeat = 1
        if format == 'csv'
          if !cell_text.empty? && cell_text.include?('"')
            # this may not be perfect logic, but it hits the 99%
            if cell_text.start_with?('"') && cell_text.end_with?('"')
              # unquote
              cell_text = cell_text[1..-2].strip
            end
            
            # collapses escaped quotes
            cell_text = cell_text.tr_s('"', '"')
          end
        end
      end
  
      1.upto(repeat) {|i|
        # make column resolving an operation
        if @col_count == -1
          @table.columns << Table::Column.new(@table, @current_row.size + i - 1)
          column = @table.columns.last 
        else
          # QUESTION is this right for cells that span columns?
          column = @table.columns[@current_row.size]
        end
  
        cell = Table::Cell.new(column, cell_text, cell_spec)
        unless cell.rowspan.nil? || cell.rowspan == 1
          activate_rowspan(cell.rowspan, (cell.colspan || 1))
        end
        @col_visits += (cell.colspan || 1)
        @current_row << cell
        # don't close the row if we're on the first line and the column count has not been set explicitly
        # TODO perhaps the col_count/linenum logic should be in end_of_row? (or a should_end_row? method)
        close_row if end_of_row? && (@col_count != -1 || @linenum > 0 || (eol && i == repeat))
      }
      @open_cell = false
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
        @active_rowspans[i] ||= 0
        @active_rowspans[i] += colspan 
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
      @col_visits + @active_rowspans.first
    end
  
    # Internal: Advance to the next line (which may come after the parser begins processing
    # the next line if the last cell had wrapped content).
    def next_line
      @linenum += 1
    end
  
  end
end
