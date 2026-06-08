# frozen_string_literal: true

module Asciidoctor
class Logger
  module Severity
    DEBUG   = 0
    INFO    = 1
    WARN    = 2
    ERROR   = 3
    FATAL   = 4
    UNKNOWN = 5
  end

  # Makes severity constants (DEBUG, WARN, etc.) directly accessible on the class, e.g. Logger::WARN
  include Severity

  # Index matches the Severity integer value; index 5 (UNKNOWN) maps to 'ANY' to match stdlib Logger output
  SEVERITY_LABELS = %w(DEBUG INFO WARN ERROR FATAL ANY).freeze

  attr_reader :level
  attr_accessor :progname
  attr_accessor :formatter
  attr_reader :max_severity

  def initialize logdev = $stderr, *_, level: WARN, progname: 'asciidoctor', **opts
    # *_ absorbs positional args from stdlib Logger's shift_age/shift_size (ignored, no log rotation)
    @logdev = logdev && (::String === logdev ? (::File.open logdev, 'a') : logdev)
    @logdev.sync = true if @logdev.respond_to? :sync=
    @level = resolve_level level
    @progname = progname
    # formatter: nil is an explicit opt-in to the plain Formatter; absence of the key uses BasicFormatter
    @formatter = opts.key?(:formatter) ? (opts[:formatter] || Formatter.new) : BasicFormatter.new
  end

  def level= value
    @level = resolve_level value
  end

  def add severity, message = nil, progname = nil
    # Initialize @max_severity lazily on first call; update only when severity increases
    if (severity ||= UNKNOWN) > (@max_severity ||= severity)
      @max_severity = severity
    end
    return true if severity < @level || !@logdev
    progname ||= @progname
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end
    @logdev.write (@formatter || Formatter.new).call(SEVERITY_LABELS[severity] || 'ANY', ::Time.now, progname, message)
    true
  end
  alias log add

  def close
    @logdev&.close
    @logdev = nil
  end

  # Generates debug/info/warn/error/fatal/unknown and their predicate variants (debug?, etc.)
  # severity_val is captured in the closure so each method gets its own fixed integer
  (Severity.constants false).sort_by {|c| Severity.const_get c }.each do |const|
    method_name = const.to_s.downcase
    severity_val = Severity.const_get const
    define_method method_name do |message = nil, &block|
      add severity_val, message, &block
    end
    define_method :"#{method_name}?" do
      @level <= severity_val
    end
  end

  # 'warning' accepted as an alias for 'warn' for compatibility with CLI input
  LEVEL_COERCE = {
    'debug' => DEBUG,
    'info' => INFO,
    'warn' => WARN,
    'warning' => WARN,
    'error' => ERROR,
    'fatal' => FATAL,
    'unknown' => UNKNOWN,
  }.freeze

  def resolve_level value
    ::Integer === value ? value : (LEVEL_COERCE[value.to_s.downcase] || UNKNOWN)
  end

  class Formatter
    def call severity, time, progname, msg
      datetime = time.strftime '%Y-%m-%dT%H:%M:%S.%6N'
      # $$ is the PID of the current process (see https://ruby-doc.org/3.4/globals_rdoc.html)
      # ##{$$} produces a literal '#' followed by the interpolated PID, e.g. #12345
      # Output: "D, [2026-06-08T12:00:00.000000 #12345] DEBUG -- asciidoctor: message\n"
      %(#{severity[0]}, [#{datetime} ##{$$}] #{severity.rjust 5} -- #{progname}: #{::String === msg ? msg : msg.inspect}\n)
    end
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
  # Reverse map: integer severity value → symbol name (e.g. 2 → :WARN), built once at class load time
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
      # Redefine logger as a plain attr_reader so subsequent calls bypass the lazy-init branch
      class << self
        alias logger logger # suppresses redefinition warning from CRuby
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
