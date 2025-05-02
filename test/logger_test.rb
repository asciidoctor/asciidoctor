# frozen_string_literal: true

require_relative 'test_helper'

context 'Logger' do
  MyLogger = Class.new Logger

  context 'LoggerManager' do
    test 'provides access to logger via static logger method' do
      logger = Asciidoctor::LoggerManager.logger
      refute_nil logger
      assert_kind_of Logger, logger
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
        assert_kind_of Logger, Asciidoctor::LoggerManager.logger
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

    test 'should set level to value specified by level kwarg' do
      out_string, err_string, log_level = redirect_streams do |out, err|
        logger = Asciidoctor::Logger.new level: 'fatal'
        logger.warn 'this is a call'
        [out.string, err.string, logger.level]
      end
      assert_empty out_string
      assert_empty err_string
      assert_equal Logger::Severity::FATAL, log_level
    end

    test 'should configure logger with progname set to asciidoctor' do
      assert_equal 'asciidoctor', Asciidoctor::Logger.new.progname
    end

    test 'should configure logger with level set to WARN by default' do
      assert_equal Logger::Severity::WARN, Asciidoctor::Logger.new.level
    end

    test 'configures default logger with progname set to asciidoctor' do
      assert_equal 'asciidoctor', Asciidoctor::LoggerManager.logger.progname
    end

    test 'configures default logger with level set to WARN' do
      assert_equal Logger::Severity::WARN, Asciidoctor::LoggerManager.logger.level
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

    test 'NullLogger level is not nil' do
      logger = Asciidoctor::NullLogger.new
      refute_nil logger.level
      assert_equal Logger::UNKNOWN, logger.level
    end

    test 'MemoryLogger level is not nil' do
      logger = Asciidoctor::MemoryLogger.new
      refute_nil logger.level
      assert_equal Logger::UNKNOWN, logger.level
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
