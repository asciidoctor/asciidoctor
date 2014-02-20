module Asciidoctor
  class Timings
    attr_reader :read, :parse, :convert, :write
    def initialize
      @read = @parse = @convert = @write = nil
      @timers = {}
    end

    def start key
      @timers[key] = ::Time.now
    end

    def record key
      instance_variable_set %(@#{key}), (::Time.now - (@timers.delete key))
    end

    def read_parse
      if @read || @parse
        (@read || 0) + (@parse || 0)
      else
        nil
      end
    end

    def read_parse_convert
      if @read || @parse || @convert
        (@read || 0) + (@parse || 0) + (@convert || 0)
      else
        nil
      end
    end

    def total
      if @read || @parse || @convert || @write
        (@read || 0) + (@parse || 0) + (@convert || 0) + (@write || 0)
      else
        nil
      end
    end

    def print_report to = $stdout, subject = nil
      to.puts %(Input file: #{subject}) if subject
      to.puts %(  Time to read and parse source: #{'%05.5f' % read_parse})
      to.puts %(  Time to convert document: #{@convert ? '%05.5f' % @convert : 'n/a'})
      to.puts %(  Total time to read, parse and convert: #{'%05.5f' % read_parse_convert})
    end
  end
end
