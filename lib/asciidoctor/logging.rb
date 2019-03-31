# frozen_string_literal: true
require 'logger'

module Asciidoctor
class Logger < ::Logger
  attr_reader :max_severity

  def initialize *args
    super
    self.progname = 'asciidoctor'
    self.formatter = BasicFormatter.new
    self.level = WARN
  end

  def add severity, message = nil, progname = nil
    if (severity ||= UNKNOWN) > (@max_severity ||= severity)
      @max_severity = severity
    end
    super
  end

  class BasicFormatter < Formatter
    SEVERITY_LABELS = { 'WARN' => 'WARNING', 'FATAL' => 'FAILED' }

    def call severity, _, progname, msg
      %(#{progname}: #{SEVERITY_LABELS[severity] || severity}: #{::String === msg ? msg : msg.inspect}#{LF})
    end
  end

  module AutoFormattingMessage
    def inspect
      (sloc = self[:source_location]) ? %(#{sloc}: #{self[:text]}) : self[:text]
    end
  end
end

class MemoryLogger < ::Logger
  SEVERITY_LABELS = {}.tap {|accum| (Severity.constants false).each {|c| accum[Severity.const_get c, false] = c } }

  attr_reader :messages

  def initialize
    self.level = WARN
    @messages = []
  end

  def add severity, message = nil, progname = nil
    message = block_given? ? yield : progname unless message
    @messages << { severity: SEVERITY_LABELS[severity || UNKNOWN], message: message }
    true
  end

  def clear
    @messages.clear
  end

  def empty?
    @messages.empty?
  end

  def max_severity
    empty? ? nil : @messages.map {|m| Severity.const_get m[:severity], false }.max
  end
end

class NullLogger < ::Logger
  attr_reader :max_severity

  def initialize
    self.level = WARN
  end

  def add severity, message = nil, progname = nil
    if (severity ||= UNKNOWN) > (@max_severity ||= severity)
      @max_severity = severity
    end
    true
  end
end

module LoggerManager
  @logger_class = Logger
  class << self
    attr_accessor :logger_class

    # NOTE subsequent calls to logger access the logger via the logger property directly
    def logger pipe = $stderr
      memoize_logger
      @logger ||= (@logger_class.new pipe)
    end

    def logger= new_logger
      @logger = new_logger || (@logger_class.new $stderr)
    end

    private

    def memoize_logger
      class << self
        alias logger logger # suppresses warning from CRuby
        attr_reader :logger
      end
    end
  end
end

module Logging
  # Private: Mixes the {Logging} module as static methods into any class that includes the {Logging} module.
  #
  # into - The Class that includes the {Logging} module
  #
  # Returns nothing
  private_class_method def self.included into
    into.extend Logging
  end || :included

  def logger
    LoggerManager.logger
  end

  def message_with_context text, context = {}
    ({ text: text }.merge context).extend Logger::AutoFormattingMessage
  end
end
end
