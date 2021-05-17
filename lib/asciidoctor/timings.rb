# frozen_string_literal: true
module Asciidoctor
  class Timings
    def initialize
      @log = {}
      @timers = {}
    end

    def start key
      @timers[key] = now
    end

    def record key
      @log[key] = (now - (@timers.delete key))
    end

    def time *keys
      time = keys.reduce(0) {|sum, key| sum + (@log[key] || 0) }
      time > 0 ? time : nil
    end

    def read
      time :read
    end

    def parse
      time :parse
    end

    def read_parse
      time :read, :parse
    end

    def convert
      time :convert
    end

    def read_parse_convert
      time :read, :parse, :convert
    end

    def write
      time :write
    end

    def total
      time :read, :parse, :convert, :write
    end

    def print_report to = $stdout, subject = nil
      to.puts %(Input file: #{subject}) if subject
      to.puts %(  Time to read and parse source: #{sprintf '%05.5f', read_parse.to_f})
      to.puts %(  Time to convert document: #{sprintf '%05.5f', convert.to_f})
      to.puts %(  Total time (read, parse and convert): #{sprintf '%05.5f', read_parse_convert.to_f})
    end

    private

    if (::Process.const_defined? :CLOCK_MONOTONIC, false) && (defined? ::Process.clock_gettime) == 'method'
      CLOCK_ID = ::Process::CLOCK_MONOTONIC
      def now
        ::Process.clock_gettime CLOCK_ID
      end
    else
      def now
        ::Time.now
      end
    end
  end
end
