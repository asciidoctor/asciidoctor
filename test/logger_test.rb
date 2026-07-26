# frozen_string_literal: true

require_relative 'test_helper'

context 'Logger' do
  MyLogger = Class.new Asciidoctor::Logger

  context 'LoggerManager' do
    test 'provides access to logger via static logger method' do
      logger = Asciidoctor::LoggerManager.logger
      refute_nil logger
      assert_kind_of Asciidoctor::Logger, logger
    end

    test 'allows logger instance to be changed' do
      old_logger = Asciidoctor::LoggerManager.logger
      new_logger = MyLogger.new $stdout
      begin
        Asciidoctor::LoggerManager.logger = new_logger
        assert_same new_logger, Asciidoctor::LoggerManager.logger
      ensure
        Asciidoctor::LoggerManager.logger = old_logger
      end
    end

    test 'setting logger instance to falsy value resets instance to default logger' do
      old_logger = Asciidoctor::LoggerManager.logger
      begin
        Asciidoctor::LoggerManager.logger = MyLogger.new $stdout
        Asciidoctor::LoggerManager.logger = nil
        refute_nil Asciidoctor::LoggerManager.logger
        assert_kind_of Asciidoctor::Logger, Asciidoctor::LoggerManager.logger
      ensure
        Asciidoctor::LoggerManager.logger = old_logger
      end
    end

    test 'creates logger instance from static logger_class property' do
      old_logger_class = Asciidoctor::LoggerManager.logger_class
      old_logger = Asciidoctor::LoggerManager.logger
      begin
        Asciidoctor::LoggerManager.logger_class = MyLogger
        Asciidoctor::LoggerManager.logger = nil
        refute_nil Asciidoctor::LoggerManager.logger
        assert_kind_of MyLogger, Asciidoctor::LoggerManager.logger
      ensure
        Asciidoctor::LoggerManager.logger_class = old_logger_class
        Asciidoctor::LoggerManager.logger = old_logger
      end
    end
  end

  context 'Logger' do
    test 'should set logdev to $stderr by default' do
      out_string, err_string = redirect_streams do |out, err|
        logger = Asciidoctor::Logger.new
        logger.warn 'this is a call'
        [out.string, err.string]
      end
      assert_empty out_string
      refute_empty err_string
      assert_includes err_string, 'this is a call'
    end

    test 'should set logdev to specified file' do
      log_file = Tempfile.new %w(asciidoctor- .log)
      logger = Asciidoctor::Logger.new log_file
      logger.warn 'this is a call'
      logger.close
      log_file_contents = File.read log_file
      assert_equal 'asciidoctor: WARNING: this is a call', log_file_contents.lines.pop.chomp
    end

    test 'should set logdev to specified file with additional options' do
      log_file = Tempfile.new %w(asciidoctor- .log)
      logger = Asciidoctor::Logger.new log_file, formatter: nil, level: Asciidoctor::Logger::DEBUG
      logger.debug 'this is a sign of life'
      logger.close
      log_file_contents = File.read log_file
      assert_includes log_file_contents.lines.pop.chomp, 'DEBUG -- asciidoctor: this is a sign of life'
    end

    test 'should set level to value specified by level kwarg' do
      out_string, err_string, log_level = redirect_streams do |out, err|
        logger = Asciidoctor::Logger.new level: 'fatal'
        logger.warn 'this is a call'
        [out.string, err.string, logger.level]
      end
      assert_empty out_string
      assert_empty err_string
      assert_equal Asciidoctor::Logger::Severity::FATAL, log_level
    end

    test 'should configure logger with progname set to asciidoctor' do
      assert_equal 'asciidoctor', Asciidoctor::Logger.new.progname
    end

    test 'should configure logger with level set to WARN by default' do
      assert_equal Asciidoctor::Logger::Severity::WARN, Asciidoctor::Logger.new.level
    end

    test 'configures default logger with progname set to asciidoctor' do
      assert_equal 'asciidoctor', Asciidoctor::LoggerManager.logger.progname
    end

    test 'configures default logger with level set to WARN' do
      assert_equal Asciidoctor::Logger::Severity::WARN, Asciidoctor::LoggerManager.logger.level
    end

    test 'configures default logger to write messages to $stderr' do
      out_string, err_string = redirect_streams do |out, err|
        Asciidoctor::LoggerManager.logger.warn 'this is a call'
        [out.string, err.string]
      end
      assert_empty out_string
      refute_empty err_string
      assert_includes err_string, 'this is a call'
    end

    test 'configures default logger to use a formatter that matches traditional format' do
      err_string = redirect_streams do |_, err|
        Asciidoctor::LoggerManager.logger.warn 'this is a call'
        Asciidoctor::LoggerManager.logger.fatal 'it cannot be done'
        err.string
      end
      assert_includes err_string, %(asciidoctor: WARNING: this is a call)
      assert_includes err_string, %(asciidoctor: FAILED: it cannot be done)
    end

    test 'should accept level as an integer' do
      logger = Asciidoctor::Logger.new level: Asciidoctor::Logger::Severity::ERROR
      assert_equal Asciidoctor::Logger::Severity::ERROR, logger.level
    end

    test 'should accept warning as an alias for warn when setting level' do
      logger = Asciidoctor::Logger.new level: 'warning'
      assert_equal Asciidoctor::Logger::Severity::WARN, logger.level
    end

    test 'should support severity predicate methods' do
      logger = Asciidoctor::Logger.new level: Asciidoctor::Logger::Severity::WARN
      refute logger.debug?
      refute logger.info?
      assert logger.warn?
      assert logger.error?
      assert logger.fatal?
    end

    test 'should evaluate block lazily when message is a block' do
      evaluated = false
      redirect_streams do
        logger = Asciidoctor::Logger.new level: Asciidoctor::Logger::Severity::FATAL
        logger.warn do
          evaluated = true
          'lazy message'
        end
      end
      refute evaluated
    end

    test 'should write message returned by block' do
      err_string = redirect_streams do |_, err|
        logger = Asciidoctor::Logger.new
        logger.warn { 'block message' }
        err.string
      end
      assert_includes err_string, 'block message'
    end

    test 'log is an alias for add' do
      err_string = redirect_streams do |_, err|
        logger = Asciidoctor::Logger.new
        logger.log Asciidoctor::Logger::Severity::WARN, 'via log alias'
        err.string
      end
      assert_includes err_string, 'via log alias'
    end

    test 'should track max severity across calls' do
      logger = Asciidoctor::Logger.new level: Asciidoctor::Logger::Severity::UNKNOWN
      assert_nil logger.max_severity
      logger.add Asciidoctor::Logger::Severity::WARN
      assert_equal Asciidoctor::Logger::Severity::WARN, logger.max_severity
      logger.add Asciidoctor::Logger::Severity::ERROR
      assert_equal Asciidoctor::Logger::Severity::ERROR, logger.max_severity
      logger.add Asciidoctor::Logger::Severity::INFO
      assert_equal Asciidoctor::Logger::Severity::ERROR, logger.max_severity
    end

    test 'NullLogger level is not nil' do
      logger = Asciidoctor::NullLogger.new
      refute_nil logger.level
      assert_equal Asciidoctor::Logger::UNKNOWN, logger.level
    end

    test 'NullLogger tracks max severity without writing' do
      logger = Asciidoctor::NullLogger.new
      assert_nil logger.max_severity
      logger.warn 'discarded'
      assert_equal Asciidoctor::Logger::Severity::WARN, logger.max_severity
      logger.error 'discarded'
      assert_equal Asciidoctor::Logger::Severity::ERROR, logger.max_severity
    end

    test 'MemoryLogger level is not nil' do
      logger = Asciidoctor::MemoryLogger.new
      refute_nil logger.level
      assert_equal Asciidoctor::Logger::UNKNOWN, logger.level
    end

    test 'MemoryLogger stores messages with their severity' do
      logger = Asciidoctor::MemoryLogger.new
      logger.warn 'first'
      logger.error 'second'
      assert_equal 2, logger.messages.size
      assert_equal :WARN, logger.messages[0][:severity]
      assert_equal :ERROR, logger.messages[1][:severity]
    end

    test 'MemoryLogger#add accepts a block for the message' do
      logger = Asciidoctor::MemoryLogger.new
      logger.add(Asciidoctor::Logger::Severity::WARN) { 'block message' }
      assert_equal 'block message', logger.messages[0][:message]
    end

    test 'MemoryLogger#clear empties the message list' do
      logger = Asciidoctor::MemoryLogger.new
      logger.warn 'one'
      refute_empty logger
      logger.clear
      assert_empty logger
      assert_nil logger.max_severity
    end

    test 'MemoryLogger#max_severity returns nil when empty' do
      assert_nil Asciidoctor::MemoryLogger.new.max_severity
    end

    test 'MemoryLogger#max_severity returns highest severity logged' do
      logger = Asciidoctor::MemoryLogger.new
      logger.warn 'w'
      logger.error 'e'
      logger.info 'i'
      assert_equal Asciidoctor::Logger::Severity::ERROR, logger.max_severity
    end
  end

  context ':logger API option' do
    test 'should be able to set logger when invoking load API' do
      old_logger = Asciidoctor::LoggerManager.logger
      new_logger = MyLogger.new $stdout
      begin
        Asciidoctor.load 'contents', logger: new_logger
        assert_same new_logger, Asciidoctor::LoggerManager.logger
      ensure
        Asciidoctor::LoggerManager.logger = old_logger
      end
    end

    test 'should be able to set logger when invoking load_file API' do
      old_logger = Asciidoctor::LoggerManager.logger
      new_logger = MyLogger.new $stdout
      begin
        Asciidoctor.load_file fixture_path('basic.adoc'), logger: new_logger
        assert_same new_logger, Asciidoctor::LoggerManager.logger
      ensure
        Asciidoctor::LoggerManager.logger = old_logger
      end
    end

    test 'should be able to set logger when invoking convert API' do
      old_logger = Asciidoctor::LoggerManager.logger
      new_logger = MyLogger.new $stdout
      begin
        Asciidoctor.convert 'contents', logger: new_logger
        assert_same new_logger, Asciidoctor::LoggerManager.logger
      ensure
        Asciidoctor::LoggerManager.logger = old_logger
      end
    end

    test 'should be able to set logger when invoking convert_file API' do
      old_logger = Asciidoctor::LoggerManager.logger
      new_logger = MyLogger.new $stdout
      begin
        Asciidoctor.convert_file fixture_path('basic.adoc'), to_file: false, logger: new_logger
        assert_same new_logger, Asciidoctor::LoggerManager.logger
      ensure
        Asciidoctor::LoggerManager.logger = old_logger
      end
    end

    test 'should be able to set logger to NullLogger by setting :logger option to a falsy value' do
      [nil, false].each do |falsy_val|
        old_logger = Asciidoctor::LoggerManager.logger
        begin
          Asciidoctor.load 'contents', logger: falsy_val
          assert_kind_of Asciidoctor::NullLogger, Asciidoctor::LoggerManager.logger
        ensure
          Asciidoctor::LoggerManager.logger = old_logger
        end
      end
    end
  end

  context 'Logging' do
    test 'including Logging gives instance methods on module access to logging infrastructure' do
      module SampleModuleA
        include Asciidoctor::Logging
        def retrieve_logger
          logger
        end
      end

      class SampleClassA
        include SampleModuleA
      end
      assert_same Asciidoctor::LoggerManager.logger, SampleClassA.new.retrieve_logger
      assert SampleClassA.public_method_defined? :logger
    end

    test 'including Logging gives static methods on module access to logging infrastructure' do
      module SampleModuleB
        include Asciidoctor::Logging
        def self.retrieve_logger
          logger
        end
      end

      assert_same Asciidoctor::LoggerManager.logger, SampleModuleB.retrieve_logger
    end

    test 'including Logging gives instance methods on class access to logging infrastructure' do
      class SampleClassC
        include Asciidoctor::Logging
        def retrieve_logger
          logger
        end
      end

      assert_same Asciidoctor::LoggerManager.logger, SampleClassC.new.retrieve_logger
      assert SampleClassC.public_method_defined? :logger
    end

    test 'including Logging gives static methods on class access to logging infrastructure' do
      class SampleClassD
        include Asciidoctor::Logging
        def self.retrieve_logger
          logger
        end
      end

      assert_same Asciidoctor::LoggerManager.logger, SampleClassD.retrieve_logger
    end

    test 'can create an auto-formatting message with context' do
      class SampleClassE
        include Asciidoctor::Logging
        def create_message cursor
          message_with_context 'Asciidoctor was here', source_location: cursor
        end
      end

      cursor = Asciidoctor::Reader::Cursor.new 'file.adoc', fixturedir, 'file.adoc', 5
      message = SampleClassE.new.create_message cursor
      assert_equal 'Asciidoctor was here', message[:text]
      assert_same cursor, message[:source_location]
      assert_equal 'file.adoc: line 5: Asciidoctor was here', message.inspect
    end

    test 'writes message prefixed with program name and source location to stderr' do
      input = <<~'EOS'
      [#first]
      first paragraph

      [#first]
      another first paragraph
      EOS
      messages = redirect_streams do |_, err|
        convert_string_to_embedded input
        err.string.chomp
      end
      assert_equal 'asciidoctor: WARNING: <stdin>: line 5: id assigned to block already in use: first', messages
    end
  end
end
