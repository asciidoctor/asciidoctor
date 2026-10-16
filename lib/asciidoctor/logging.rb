# frozen_string_literal: true

unless RUBY_ENGINE == 'opal'
  require 'logger' if Gem.loaded_specs.key? 'logger'
end

module Asciidoctor
class BasicLogger
  module Severity
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
    FATAL = 4
    UNKNOWN = 5
  end

  include Severity

  class Formatter
    def call severity, time, progname, msg
      %(#{severity[0]}, [#{time.strftime '%Y-%m-%dT%H:%M:%S.%6N'} ##{$$}] #{severity.rjust 5} -- #{progname}: #{::String === msg ? msg : msg.inspect}#{LF})
    end
  end

  attr_reader :level

  attr_accessor :progname

  attr_accessor :formatter

  # NOTE shift_age, shift_size, and other options are accepted for compatibility with ::Logger, but ignored
  def initialize logdev, _shift_age = nil, _shift_size = nil, level: DEBUG, progname: nil, formatter: nil, **_opts
    if logdev && logdev != ::File::NULL
      @logdev = ::String === logdev ? (::File.open logdev, 'a') : logdev
      @logdev.sync = true if @logdev.respond_to? :sync=
    else
      @logdev = nil
    end
    self.level = level
    @progname = progname
    @formatter = formatter
    @default_formatter = Formatter.new
  end

  def level= severity
    @level = ::Integer === severity ? severity : (LEVELS[severity.to_s.downcase] || UNKNOWN)
  end

  def add severity, message = nil, progname = nil
    return true if (severity ||= UNKNOWN) < @level || !@logdev
    progname ||= @progname
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end
    formatter = @formatter || @default_formatter
    @logdev.write formatter.call (SEVERITY_LABELS[severity] || 'ANY'), ::Time.now, progname, message
    true
  end

  alias log add

  def << msg
    @logdev&.write msg
  end

  def close
    @logdev&.close
    @logdev = nil
  end

  (Severity.constants false).each do |const|
    severity = Severity.const_get const
    method_name = const.to_s.downcase
    define_method method_name do |message = nil, &block|
      add severity, message, &block
    end
    define_method %(#{method_name}?) do
      @level <= severity
    end
  end

  LEVELS = (Severity.constants false).map {|c| [c.to_s.downcase, (Severity.const_get c)] }.to_h # rubocop:disable Style/MapToHash
  private_constant :LEVELS

  SEVERITY_LABELS = %w(DEBUG INFO WARN ERROR FATAL ANY)
  private_constant :SEVERITY_LABELS
end

# NOTE extend ::Logger if the logger gem is available to give users access to all its features
class Logger < ((defined? ::Logger) ? ::Logger : BasicLogger)
  attr_reader :max_severity

  def initialize *args, **opts
    opts[:progname] = 'asciidoctor'
    opts[:formatter] = BasicFormatter.new unless opts.key? :formatter
    opts[:level] = WARN unless opts.key? :level
    args = [$stderr] if args.empty?
    super
  end

  def level= severity
    super (severity.to_s.downcase == 'warning' ? WARN : severity)
  end

  def add severity, message = nil, progname = nil
    if (severity ||= UNKNOWN) > (@max_severity ||= severity)
      @max_severity = severity
    end
    super
  end

  class BasicFormatter < Formatter
    SEVERITY_LABEL_SUBSTITUTES = { 'WARN' => 'WARNING', 'FATAL' => 'FAILED' }

    def call severity, _, progname, msg
      %(#{progname}: #{SEVERITY_LABEL_SUBSTITUTES[severity] || severity}: #{::String === msg ? msg : msg.inspect}#{LF})
    end
  end

  module AutoFormattingMessage
    def inspect
      (sloc = self[:source_location]) ? %(#{sloc}: #{self[:text]}) : self[:text]
    end
  end
end

class MemoryLogger < Logger
  SEVERITY_SYMBOL_BY_VALUE = (Severity.constants false).map {|c| [(Severity.const_get c), c] }.to_h # rubocop:disable Style/MapToHash

  attr_reader :messages

  def initialize
    super nil, level: UNKNOWN
    @messages = []
  end

  def add severity, message = nil, progname = nil
    message ||= block_given? ? yield : progname
    @messages << { severity: SEVERITY_SYMBOL_BY_VALUE[severity || UNKNOWN], message: message }
    true
  end

  def clear
    @messages.clear
  end

  def empty?
    @messages.empty?
  end

  def max_severity
    empty? ? nil : @messages.map {|m| Severity.const_get m[:severity] }.max
  end
end

class NullLogger < Logger
  def initialize
    super nil, level: UNKNOWN
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

    # Returns the specified Logger
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
  def self.included into
    into.extend Logging
  end
  private_class_method :included # use separate declaration for Ruby 2.0.x

  def logger
    LoggerManager.logger
  end

  def message_with_context text, context = {}
    ({ text: text }.merge context).extend Logger::AutoFormattingMessage
  end
end
end
