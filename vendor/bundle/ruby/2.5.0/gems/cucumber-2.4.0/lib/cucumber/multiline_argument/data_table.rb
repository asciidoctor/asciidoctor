require 'forwardable'
require 'cucumber/gherkin/data_table_parser'
require 'cucumber/gherkin/formatter/escaping'
require 'cucumber/core/ast/describes_itself'

module Cucumber
  module MultilineArgument
    # Step Definitions that match a plain text Step with a multiline argument table
    # will receive it as an instance of Table. A Table object holds the data of a
    # table parsed from a feature file and lets you access and manipulate the data
    # in different ways.
    #
    # For example:
    #
    #   Given I have:
    #     | a | b |
    #     | c | d |
    #
    # And a matching StepDefinition:
    #
    #   Given /I have:/ do |table|
    #     data = table.raw
    #   end
    #
    # This will store <tt>[['a', 'b'], ['c', 'd']]</tt> in the <tt>data</tt> variable.
    #
    class DataTable
      class Different < StandardError
        def initialize(table)
          super("Tables were not identical:\n#{table}")
        end
      end

      class Builder
        attr_reader :rows

        def initialize
          @rows = []
        end

        def row(row)
          @rows << row
        end

        def eof
        end
      end

      include Enumerable
      include Core::Ast::DescribesItself
      extend Forwardable

      NULL_CONVERSIONS = Hash.new({ :strict => false, :proc => lambda{ |cell_value| cell_value } }).freeze

      attr_accessor :file
      def_delegator :@ast_table, :location

      def self.default_arg_name #:nodoc:
        "table"
      end

      class << self
        def from(data, location = Core::Ast::Location.of_caller)
          case data
          when Array
            from_array(data, location)
          when String
            parse(data, location)
          else
            raise ArgumentError, "expected data to be a String or an Array."
          end
        end

        private
        def parse(text, location = Core::Ast::Location.of_caller)
          builder = Builder.new
          parser = Cucumber::Gherkin::DataTableParser.new(builder)
          parser.parse(text)
          from_array(builder.rows, location)
        end

        def from_array(data, location = Core::Ast::Location.of_caller)
          new Core::Ast::DataTable.new(data, location)
        end
      end


      # @param data [Core::Ast::DataTable] the data for the table
      # @param conversion_procs [Hash] see map_columns!
      # @param header_mappings [Hash] see map_headers!
      # @param header_conversion_proc [Proc] see map_headers!
      def initialize(data, conversion_procs = NULL_CONVERSIONS.dup, header_mappings = {}, header_conversion_proc = nil)
        raise ArgumentError, "data must be a Core::Ast::DataTable" unless data.kind_of? Core::Ast::DataTable
        ast_table = data
        # Verify that it's square
        ast_table.transpose
        @cell_matrix = create_cell_matrix(ast_table)
        @conversion_procs = conversion_procs
        @header_mappings = header_mappings
        @header_conversion_proc = header_conversion_proc
        @ast_table = ast_table
      end

      def append_to(array)
        array << self
      end

      def to_step_definition_arg
        dup
      end

      # Creates a copy of this table, inheriting any column and header mappings
      # registered with #map_column! and #map_headers!.
      #
      def dup
        self.class.new(Core::Ast::DataTable.new(raw, location), @conversion_procs.dup, @header_mappings.dup, @header_conversion_proc)
      end

      # Returns a new, transposed table. Example:
      #
      #   | a | 7 | 4 |
      #   | b | 9 | 2 |
      #
      # Gets converted into the following:
      #
      #   | a | b |
      #   | 7 | 9 |
      #   | 4 | 2 |
      #
      def transpose
        self.class.new(Core::Ast::DataTable.new(raw.transpose, location), @conversion_procs.dup, @header_mappings.dup, @header_conversion_proc)
      end

      # Converts this table into an Array of Hash where the keys of each
      # Hash are the headers in the table. For example, a Table built from
      # the following plain text:
      #
      #   | a | b | sum |
      #   | 2 | 3 | 5   |
      #   | 7 | 9 | 16  |
      #
      # Gets converted into the following:
      #
      #   [{'a' => '2', 'b' => '3', 'sum' => '5'}, {'a' => '7', 'b' => '9', 'sum' => '16'}]
      #
      # Use #map_column! to specify how values in a column are converted.
      #
      def hashes
        @hashes ||= build_hashes
      end

      # Converts this table into an Array of Hashes where the keys are symbols.
      # For example, a Table built from the following plain text:
      #
      #   | foo | Bar | Foo Bar |
      #   | 2   | 3   | 5       |
      #   | 7   | 9   | 16      |
      #
      # Gets converted into the following:
      #
      #   [{:foo => '2', :bar => '3', :foo_bar => '5'}, {:foo => '7', :bar => '9', :foo_bar => '16'}]
      #
      def symbolic_hashes
        @header_conversion_proc = lambda { |h| symbolize_key(h) }
        @symbolic_hashes ||= build_hashes
      end

      # Converts this table into a Hash where the first column is
      # used as keys and the second column is used as values
      #
      #   | a | 2 |
      #   | b | 3 |
      #
      # Gets converted into the following:
      #
      #   {'a' => '2', 'b' => '3'}
      #
      # The table must be exactly two columns wide
      #
      def rows_hash
        return @rows_hash if @rows_hash
        verify_table_width(2)
        @rows_hash = self.transpose.hashes[0]
      end

      # Gets the raw data of this table. For example, a Table built from
      # the following plain text:
      #
      #   | a | b |
      #   | c | d |
      #
      # gets converted into the following:
      #
      #   [['a', 'b'], ['c', 'd']]
      #
      def raw
        cell_matrix.map do |row|
          row.map do |cell|
            cell.value
          end
        end
      end

      def column_names #:nodoc:
        @col_names ||= cell_matrix[0].map { |cell| cell.value }
      end

      def rows
        hashes.map do |hash|
          hash.values_at *headers
        end
      end

      def each_cells_row(&proc) #:nodoc:
        cells_rows.each(&proc)
      end

      # Matches +pattern+ against the header row of the table.
      # This is used especially for argument transforms.
      #
      # Example:
      #  | column_1_name | column_2_name |
      #  | x             | y             |
      #
      #  table.match(/table:column_1_name,column_2_name/) #=> non-nil
      #
      # Note: must use 'table:' prefix on match
      def match(pattern)
        header_to_match = "table:#{headers.join(',')}"
        pattern.match(header_to_match)
      end

      # Redefines the table headers. This makes it possible to use
      # prettier and more flexible header names in the features.  The
      # keys of +mappings+ are Strings or regular expressions
      # (anything that responds to #=== will work) that may match
      # column headings in the table.  The values of +mappings+ are
      # desired names for the columns.
      #
      # Example:
      #
      #   | Phone Number | Address |
      #   | 123456       | xyz     |
      #   | 345678       | abc     |
      #
      # A StepDefinition receiving this table can then map the columns
      # with both Regexp and String:
      #
      #   table.map_headers!(/phone( number)?/i => :phone, 'Address' => :address)
      #   table.hashes
      #   # => [{:phone => '123456', :address => 'xyz'}, {:phone => '345678', :address => 'abc'}]
      #
      # You may also pass in a block if you wish to convert all of the headers:
      #
      #   table.map_headers! { |header| header.downcase }
      #   table.hashes.keys
      #   # => ['phone number', 'address']
      #
      # When a block is passed in along with a hash then the mappings in the hash take precendence:
      #
      #   table.map_headers!('Address' => 'ADDRESS') { |header| header.downcase }
      #   table.hashes.keys
      #   # => ['phone number', 'ADDRESS']
      #
      def map_headers!(mappings={}, &block)
        # TODO: Remove this method for 2.0
        clear_cache!
        @header_mappings = mappings
        @header_conversion_proc = block
      end

      # Returns a new Table where the headers are redefined. See #map_headers!
      def map_headers(mappings={}, &block)
        self.class.new(Core::Ast::DataTable.new(raw, location), @conversion_procs.dup, mappings, block)
      end

      # Change how #hashes converts column values. The +column_name+ argument identifies the column
      # and +conversion_proc+ performs the conversion for each cell in that column. If +strict+ is
      # true, an error will be raised if the column named +column_name+ is not found. If +strict+
      # is false, no error will be raised. Example:
      #
      #   Given /^an expense report for (.*) with the following posts:$/ do |table|
      #     posts_table.map_column!('amount') { |a| a.to_i }
      #     posts_table.hashes.each do |post|
      #       # post['amount'] is a Fixnum, rather than a String
      #     end
      #   end
      #
      def map_column!(column_name, strict=true, &conversion_proc)
        # TODO: Remove this method for 2.0
        @conversion_procs[column_name.to_s] = { :strict => strict, :proc => conversion_proc }
        self
      end

      # Returns a new Table with an additional column mapping. See #map_column!
      def map_column(column_name, strict=true, &conversion_proc)
        conversion_procs = @conversion_procs.dup
        conversion_procs[column_name.to_s] = { :strict => strict, :proc => conversion_proc }
        self.class.new(Core::Ast::DataTable.new(raw, location), conversion_procs, @header_mappings.dup, @header_conversion_proc)
      end

      # Compares +other_table+ to self. If +other_table+ contains columns
      # and/or rows that are not in self, new columns/rows are added at the
      # relevant positions, marking the cells in those rows/columns as
      # <tt>surplus</tt>. Likewise, if +other_table+ lacks columns and/or
      # rows that are present in self, these are marked as <tt>missing</tt>.
      #
      # <tt>surplus</tt> and <tt>missing</tt> cells are recognised by formatters
      # and displayed so that it's easy to read the differences.
      #
      # Cells that are different, but <em>look</em> identical (for example the
      # boolean true and the string "true") are converted to their Object#inspect
      # representation and preceded with (i) - to make it easier to identify
      # where the difference actually is.
      #
      # Since all tables that are passed to StepDefinitions always have String
      # objects in their cells, you may want to use #map_column! before calling
      # #diff!. You can use #map_column! on either of the tables.
      #
      # A Different error is raised if there are missing rows or columns, or
      # surplus rows. An error is <em>not</em> raised for surplus columns. An
      # error is <em>not</em> raised for misplaced (out of sequence) columns.
      # Whether to raise or not raise can be changed by setting values in
      # +options+ to true or false:
      #
      # * <tt>missing_row</tt> : Raise on missing rows (defaults to true)
      # * <tt>surplus_row</tt> : Raise on surplus rows (defaults to true)
      # * <tt>missing_col</tt> : Raise on missing columns (defaults to true)
      # * <tt>surplus_col</tt> : Raise on surplus columns (defaults to false)
      # * <tt>misplaced_col</tt> : Raise on misplaced columns (defaults to false)
      #
      # The +other_table+ argument can be another Table, an Array of Array or
      # an Array of Hash (similar to the structure returned by #hashes).
      #
      # Calling this method is particularly useful in <tt>Then</tt> steps that take
      # a Table argument, if you want to compare that table to some actual values.
      #
      def diff!(other_table, options={})
        options = {
          :missing_row   => true,
          :surplus_row   => true,
          :missing_col   => true,
          :surplus_col   => false,
          :misplaced_col => false
        }.merge(options)

        other_table = ensure_table(other_table)
        other_table.convert_headers!
        other_table.convert_columns!
        ensure_green!

        convert_headers!
        convert_columns!

        original_width = cell_matrix[0].length
        @cell_matrix, other_table_cell_matrix = pad_and_match(@cell_matrix, other_table.cell_matrix)
        padded_width = cell_matrix[0].length

        missing_col = cell_matrix[0].detect{|cell| cell.status == :undefined}
        surplus_col = padded_width > original_width
        misplaced_col = cell_matrix[0] != other_table.cell_matrix[0]

        require_diff_lcs
        cell_matrix.extend(Diff::LCS)
        changes = cell_matrix.diff(other_table_cell_matrix).flatten

        inserted = 0
        missing  = 0

        row_indices = Array.new(other_table_cell_matrix.length) {|n| n}

        last_change = nil
        missing_row_pos = nil
        insert_row_pos  = nil

        changes.each do |change|
          if(change.action == '-')
            missing_row_pos = change.position + inserted
            cell_matrix[missing_row_pos].each{|cell| cell.status = :undefined}
            row_indices.insert(missing_row_pos, nil)
            missing += 1
          else # '+'
            insert_row_pos = change.position + missing
            inserted_row = change.element
            inserted_row.each{|cell| cell.status = :comment}
            cell_matrix.insert(insert_row_pos, inserted_row)
            row_indices[insert_row_pos] = nil
            inspect_rows(cell_matrix[missing_row_pos], inserted_row) if last_change && last_change.action == '-'
            inserted += 1
          end
          last_change = change
        end

        other_table_cell_matrix.each_with_index do |other_row, i|
          row_index = row_indices.index(i)
          row = cell_matrix[row_index] if row_index
          if row
            (original_width..padded_width).each do |col_index|
              surplus_cell = other_row[col_index]
              row[col_index].value = surplus_cell.value if row[col_index]
            end
          end
        end

        clear_cache!
        should_raise =
          missing_row_pos && options[:missing_row] ||
          insert_row_pos  && options[:surplus_row] ||
          missing_col     && options[:missing_col] ||
          surplus_col     && options[:surplus_col] ||
          misplaced_col   && options[:misplaced_col]
        raise Different.new(self) if should_raise
      end

      def to_hash(cells) #:nodoc:
        hash = Hash.new do |hash, key|
          hash[key.to_s] if key.is_a?(Symbol)
        end
        column_names.each_with_index do |column_name, column_index|
          hash[column_name] = cells.value(column_index)
        end
        hash
      end

      def index(cells) #:nodoc:
        cells_rows.index(cells)
      end

      def verify_column(column_name) #:nodoc:
        raise %{The column named "#{column_name}" does not exist} unless raw[0].include?(column_name)
      end

      def verify_table_width(width) #:nodoc:
        raise %{The table must have exactly #{width} columns} unless raw[0].size == width
      end

      def has_text?(text) #:nodoc:
        raw.flatten.compact.detect{|cell_value| cell_value.index(text)}
      end

      def cells_rows #:nodoc:
        @rows ||= cell_matrix.map do |cell_row|
          Cells.new(self, cell_row)
        end
      end

      def headers #:nodoc:
        raw.first
      end

      def header_cell(col) #:nodoc:
        cells_rows[0][col]
      end

      def cell_matrix #:nodoc:
        @cell_matrix
      end

      def col_width(col) #:nodoc:
        columns[col].__send__(:width)
      end

      def to_s(options = {}) #:nodoc:
        # TODO: factor out this code so we don't depend on such a big lump of old cruft
        require 'cucumber/formatter/pretty'
        require 'cucumber/formatter/legacy_api/adapter'
        options = {:color => true, :indent => 2, :prefixes => TO_S_PREFIXES}.merge(options)
        io = StringIO.new

        c = Cucumber::Term::ANSIColor.coloring?
        Cucumber::Term::ANSIColor.coloring = options[:color]
        formatter = Formatter::Pretty.new(nil, io, options)
        formatter.instance_variable_set('@indent', options[:indent])
        Formatter::LegacyApi::Ast::MultilineArg.for(self).accept(Formatter::Fanout.new([formatter]))
        Cucumber::Term::ANSIColor.coloring = c
        io.rewind
        s = "\n" + io.read + (" " * (options[:indent] - 2))
        s
      end

      def description_for_visitors
        :legacy_table
      end

      def columns #:nodoc:
        @columns ||= cell_matrix.transpose.map do |cell_row|
          Cells.new(self, cell_row)
        end
      end

      def to_json(*args)
        raw.to_json(*args)
      end

      private

      TO_S_PREFIXES = Hash.new('    ')
      TO_S_PREFIXES[:comment]   = '(+) '
      TO_S_PREFIXES[:undefined] = '(-) '

      protected

      def build_hashes
        convert_headers!
        convert_columns!
        cells_rows[1..-1].map do |row|
          row.to_hash
        end
      end

      def inspect_rows(missing_row, inserted_row) #:nodoc:
        missing_row.each_with_index do |missing_cell, col|
          inserted_cell = inserted_row[col]
          if(missing_cell.value != inserted_cell.value && (missing_cell.value.to_s == inserted_cell.value.to_s))
            missing_cell.inspect!
            inserted_cell.inspect!
          end
        end
      end

      def create_cell_matrix(ast_table) #:nodoc:
        ast_table.raw.map do |raw_row|
          line = raw_row.line rescue -1
          raw_row.map do |raw_cell|
            Cell.new(raw_cell, self, line)
          end
        end
      end

      def convert_columns! #:nodoc:
        @conversion_procs.each do |column_name, conversion_proc|
          verify_column(column_name) if conversion_proc[:strict]
        end

        cell_matrix.transpose.each do |col|
          column_name = col[0].value
          conversion_proc = @conversion_procs[column_name][:proc]
          col[1..-1].each do |cell|
            cell.value = conversion_proc.call(cell.value)
          end
        end
      end

      def convert_headers! #:nodoc:
        header_cells = cell_matrix[0]

        if @header_conversion_proc
          header_values = header_cells.map { |cell| cell.value } - @header_mappings.keys
          @header_mappings = @header_mappings.merge(Hash[*header_values.zip(header_values.map(&@header_conversion_proc)).flatten])
        end

        @header_mappings.each_pair do |pre, post|
          mapped_cells = header_cells.select { |cell| pre === cell.value }
          raise "No headers matched #{pre.inspect}" if mapped_cells.empty?
          raise "#{mapped_cells.length} headers matched #{pre.inspect}: #{mapped_cells.map { |c| c.value }.inspect}" if mapped_cells.length > 1
          mapped_cells[0].value = post
          if @conversion_procs.has_key?(pre)
            @conversion_procs[post] = @conversion_procs.delete(pre)
          end
        end
      end

      def require_diff_lcs #:nodoc:
        begin
          require 'diff/lcs'
        rescue LoadError => e
          e.message << "\n Please gem install diff-lcs\n"
          raise e
        end
      end

      def clear_cache! #:nodoc:
        @hashes = @rows_hash = @col_names = @rows = @columns = nil
      end

      # Pads two cell matrices to same column width and matches columns according to header value.
      # The first cell matrix is the reference matrix with the second matrix matched against it.
      def pad_and_match(a_cell_matrix, other_cell_matrix) #:nodoc:
        clear_cache!
        cols = a_cell_matrix.transpose
        unmatched_cols = other_cell_matrix.transpose


        header_values = cols.map(&:first)
        matched_cols = []

        header_values.each_with_index do |v, i|
          mapped_index = unmatched_cols.index{|unmapped_col| unmapped_col.first == v}
          if (mapped_index)
            matched_cols << unmatched_cols.delete_at(mapped_index)
          else
            mark_as_missing(cols[i])
            empty_col = other_cell_matrix.collect {SurplusCell.new(nil, self, -1)}
            empty_col.first.value = v
            matched_cols << empty_col
          end
        end


        empty_col = cell_matrix.collect {SurplusCell.new(nil, self, -1)}
        unmatched_cols.each do
          cols << empty_col
        end

        return cols.transpose, (matched_cols + unmatched_cols).transpose
      end

      def ensure_table(table_or_array) #:nodoc:
        return table_or_array if DataTable === table_or_array
        DataTable.from(table_or_array)
      end

      def ensure_array_of_array(array)
        Hash === array[0] ? hashes_to_array(array) : array
      end

      def hashes_to_array(hashes) #:nodoc:
        header = hashes[0].keys.sort
        [header] + hashes.map{|hash| header.map{|key| hash[key]}}
      end

      def ensure_green! #:nodoc:
        each_cell{|cell| cell.status = :passed}
      end

      def each_cell(&proc) #:nodoc:
        cell_matrix.each{|row| row.each(&proc)}
      end

      def mark_as_missing(col) #:nodoc:
        col.each do |cell|
          cell.status = :undefined
        end
      end

      def symbolize_key(key)
        key.downcase.tr(' ', '_').to_sym
      end

      # Represents a row of cells or columns of cells
      class Cells #:nodoc:
        include Enumerable
        include Cucumber::Gherkin::Formatter::Escaping

        attr_reader :exception

        def initialize(table, cells)
          @table, @cells = table, cells
        end

        def accept(visitor)
          return if Cucumber.wants_to_quit
          each do |cell|
            visitor.visit_table_cell(cell)
          end
          nil
        end

        # For testing only
        def to_sexp #:nodoc:
          [:row, line, *@cells.map{|cell| cell.to_sexp}]
        end

        def to_hash #:nodoc:
          @to_hash ||= @table.to_hash(self)
        end

        def value(n) #:nodoc:
          self[n].value
        end

        def [](n)
          @cells[n]
        end

        def line
          @cells[0].line
        end

        def dom_id
          "row_#{line}"
        end

        def each(&proc)
          @cells.each(&proc)
        end

        private

        def index
          @table.index(self)
        end

        def width
          map{|cell| cell.value ? escape_cell(cell.value.to_s).unpack('U*').length : 0}.max
        end
      end

      class Cell #:nodoc:
        attr_reader :line, :table
        attr_accessor :status, :value

        def initialize(value, table, line)
          @value, @table, @line = value, table, line
        end

        def inspect!
          @value = "(i) #{value.inspect}"
        end

        def ==(o)
          SurplusCell === o || value == o.value
        end

        def eql?(o)
          self == o
        end

        def hash
          0
        end

        # For testing only
        def to_sexp #:nodoc:
          [:cell, @value]
        end
      end

      class SurplusCell < Cell #:nodoc:
        def status
          :comment
        end

        def ==(o)
          true
        end

        def hash
          0
        end
      end
    end
  end
end
