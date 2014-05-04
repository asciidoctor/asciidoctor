module Asciidoctor
  class Timings
    def initialize
      @log = {}
      @timers = {}
    end

    def start key
      @timers[key] = ::Time.now
    end

    def record key
      @log[key] = (::Time.now - (@timers.delete key))
    end

    def read_parse
      (time = (@log[:read] || 0) + (@log[:parse] || 0)) > 0 ? time : nil
    end

    def convert
      @log[:convert] || 0
    end

    def read_parse_convert
      (time = (@log[:read] || 0) + (@log[:parse] || 0) + (@log[:convert] || 0)) > 0 ? time : nil
    end

    def total
      (time = (@log[:read] || 0) + (@log[:parse] || 0) + (@log[:convert] || 0) + (@log[:write] || 0)) > 0 ? time : nil
    end

    def print_report to = $stdout, subject = nil
      to.puts %(Input file: #{subject}) if subject
      to.puts %(  Time to read and parse source: #{'%05.5f' % read_parse})
      to.puts %(  Time to convert document: #{'%05.5f' % convert})
      to.puts %(  Total time (read, parse and convert): #{'%05.5f' % read_parse_convert})
    end
  end
end
