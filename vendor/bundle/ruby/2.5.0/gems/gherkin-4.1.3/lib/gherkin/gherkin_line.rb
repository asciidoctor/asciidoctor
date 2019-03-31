module Gherkin
  class GherkinLine
    attr_reader :indent, :trimmed_line_text
    def initialize(line_text, line_number)
      @line_text = line_text
      @line_number = line_number
      @trimmed_line_text = @line_text.lstrip
      @indent = @line_text.length - @trimmed_line_text.length
    end

    def start_with?(prefix)
      @trimmed_line_text.start_with?(prefix)
    end

    def start_with_title_keyword?(keyword)
      start_with?(keyword+':') # The C# impl is more complicated. Find out why.
    end

    def get_rest_trimmed(length)
      @trimmed_line_text[length..-1].strip
    end

    def empty?
      @trimmed_line_text.empty?
    end

    def get_line_text(indent_to_remove)
      indent_to_remove ||= 0
      if indent_to_remove < 0 || indent_to_remove > indent
        @trimmed_line_text
      else
        @line_text[indent_to_remove..-1]
      end
    end

    def table_cells
      cells = []

      self.split_table_cells(@trimmed_line_text) do |item, column|
        cell_indent = item.length - item.lstrip.length
        span = Span.new(@indent + column + cell_indent, item.strip)
        cells.push(span)
      end

      cells
    end

    def split_table_cells(row)
      col = 0
      start_col = col + 1
      cell = ''
      first_cell = true
      while col < row.length
        char = row[col]
        col += 1
        if char == '|'
          if first_cell
            # First cell (content before the first |) is skipped
            first_cell = false
          else
            yield cell, start_col
          end
          cell = ''
          start_col = col + 1
        elsif char == '\\'
          char = row[col]
          col += 1
          if char == 'n'
            cell += "\n"
          else
            cell += '\\' unless ['|', '\\'].include?(char)
            cell += char
          end
        else
          cell += char
        end
      end
      # Last cell (content after the last |) is skipped
    end

    def tags
      column = @indent + 1;
      items = @trimmed_line_text.strip.split('@')
      items = items[1..-1] # ignore before the first @
      items.map do |item|
        length = item.length
        span = Span.new(column, '@' + item.strip)
        column += length + 1
        span
      end
    end

    class Span < Struct.new(:column, :text); end
  end
end
