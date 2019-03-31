# -*- coding: utf-8 -*-
require 'fileutils'
require 'multi_json'
require 'cucumber/configuration'
require 'cucumber/load_path'
require 'cucumber/formatter/duration'
require 'cucumber/file_specs'
require 'cucumber/filters'
require 'cucumber/formatter/fanout'
require 'cucumber/formatter/event_bus_report'
require 'cucumber/gherkin/i18n'
require 'cucumber/step_match_search'

module Cucumber
  module FixRuby21Bug9285
    def message
      String(super).gsub("@ rb_sysopen ", "")
    end
  end

  class FileException < Exception
    attr :path

    def initialize(original_exception, path)
      super(original_exception)
      @path = path
    end
  end

  class FileNotFoundException < FileException
  end

  class FeatureFolderNotFoundException < FileException
    include FixRuby21Bug9285 if Cucumber::RUBY_2_1 || Cucumber::RUBY_2_2 || Cucumber::RUBY_2_3
  end

  require 'cucumber/core'
  require 'cucumber/runtime/user_interface'
  require 'cucumber/runtime/support_code'
  class Runtime
    attr_reader :results, :support_code, :configuration

    include Cucumber::Core
    include Formatter::Duration
    include Runtime::UserInterface

    def initialize(configuration = Configuration.default)
      @configuration = Configuration.new(configuration)
      @support_code = SupportCode.new(self, @configuration)
      @results = Formatter::LegacyApi::Results.new
    end

    # Allows you to take an existing runtime and change its configuration
    def configure(new_configuration)
      @configuration = Configuration.new(new_configuration)
      @support_code.configure(@configuration)
    end

    require 'cucumber/wire/plugin'
    def run!
      load_step_definitions
      install_wire_plugin
      fire_after_configuration_hook
      self.visitor = report

      receiver = Test::Runner.new(report)
      compile features, receiver, filters
    end

    def features_paths
      @configuration.paths
    end

    def dry_run?
      @configuration.dry_run?
    end

    def scenarios(status = nil)
      @results.scenarios(status)
    end

    def steps(status = nil)
      @results.steps(status)
    end

    def unmatched_step_definitions
      @support_code.unmatched_step_definitions
    end

    def begin_scenario(scenario)
      @support_code.fire_hook(:begin_scenario, scenario)
    end

    def end_scenario(scenario)
      @support_code.fire_hook(:end_scenario)
    end

    # Returns Ast::DocString for +string_without_triple_quotes+.
    #
    def doc_string(string_without_triple_quotes, content_type='', line_offset=0)
      location = Core::Ast::Location.of_caller
      Core::Ast::DocString.new(string_without_triple_quotes, content_type, location)
    end

  private

    def fire_after_configuration_hook #:nodoc
      @support_code.fire_hook(:after_configuration, @configuration)
    end

    require 'cucumber/core/gherkin/document'
    def features
      @features ||= feature_files.map do |path|
        source = NormalisedEncodingFile.read(path)
        Cucumber::Core::Gherkin::Document.new(path, source)
      end
    end

    def feature_files
      filespecs.files
    end

    def filespecs
      @filespecs ||= FileSpecs.new(@configuration.feature_files)
    end

    class NormalisedEncodingFile
      COMMENT_OR_EMPTY_LINE_PATTERN = /^\s*#|^\s*$/ #:nodoc:
      ENCODING_PATTERN = /^\s*#\s*encoding\s*:\s*([^\s]+)/ #:nodoc:

      def self.read(path)
        new(path).read
      end

      def initialize(path)
        begin
          @file = File.new(path)
          set_encoding
        rescue Errno::EACCES => e
          raise FileNotFoundException.new(e, File.expand_path(path))
        rescue Errno::ENOENT => e
          raise FeatureFolderNotFoundException.new(e, path)
        end
      end

      def read
        @file.read.encode("UTF-8")
      end

      private

      def set_encoding
        @file.each do |line|
          if ENCODING_PATTERN =~ line
            @file.set_encoding $1
            break
          end
          break unless COMMENT_OR_EMPTY_LINE_PATTERN =~ line
        end
        @file.rewind
      end
    end

    require 'cucumber/formatter/legacy_api/adapter'
    require 'cucumber/formatter/legacy_api/runtime_facade'
    require 'cucumber/formatter/legacy_api/results'
    require 'cucumber/formatter/ignore_missing_messages'
    require 'cucumber/formatter/fail_fast'
    require 'cucumber/core/report/summary'
    def report
      return @report if @report
      reports = [summary_report, event_bus_report] + formatters
      reports << fail_fast_report if @configuration.fail_fast?
      @report ||= Formatter::Fanout.new(reports)
    end

    def summary_report
      @summary_report ||= Core::Report::Summary.new
    end

    def event_bus_report
      @event_bus_report ||= Formatter::EventBusReport.new(@configuration)
    end

    def fail_fast_report
      @fail_fast_report ||= Formatter::FailFast.new(@configuration)
    end

    def formatters
      @formatters ||= @configuration.formatter_factories { |factory, path_or_io, options|
        create_formatter(factory, path_or_io, options)
      }
    end

    def create_formatter(factory, path_or_io, options)
      if !legacy_formatter?(factory)
        return factory.new(@configuration) if path_or_io.nil?
        return factory.new(@configuration.with_options(out_stream: path_or_io))
      end
      results = Formatter::LegacyApi::Results.new
      runtime_facade = Formatter::LegacyApi::RuntimeFacade.new(results, @support_code, @configuration)
      formatter = factory.new(runtime_facade, path_or_io, options)
      Formatter::LegacyApi::Adapter.new(
        Formatter::IgnoreMissingMessages.new(formatter),
        results, @configuration)
    end

    def legacy_formatter?(factory)
      factory.instance_method(:initialize).arity > 1
    end

    def failure?
      if @configuration.wip?
        summary_report.test_cases.total_passed > 0
      else
        summary_report.test_cases.total_failed > 0 || summary_report.test_steps.total_failed > 0 ||
          (@configuration.strict? && (summary_report.test_steps.total_undefined > 0 || summary_report.test_steps.total_pending > 0))
      end
    end
    public :failure?

    require 'cucumber/core/test/filters'
    def filters
      tag_expressions = @configuration.tag_expressions
      name_regexps = @configuration.name_regexps
      tag_limits = @configuration.tag_limits
      [].tap do |filters|
        filters << Filters::TagLimits.new(tag_limits) if tag_limits.any?
        filters << Cucumber::Core::Test::TagFilter.new(tag_expressions)
        filters << Cucumber::Core::Test::NameFilter.new(name_regexps)
        filters << Cucumber::Core::Test::LocationsFilter.new(filespecs.locations)
        filters << Filters::Randomizer.new(@configuration.seed) if @configuration.randomize?
        filters << Filters::Quit.new
        # TODO: can we just use RbLanguages's step definitions directly?
        step_match_search = StepMatchSearch.new(@support_code.ruby.method(:step_matches), @configuration)
        filters << Filters::ActivateSteps.new(step_match_search, @configuration)
        @configuration.filters.each do |filter|
          filters << filter
        end
        unless configuration.dry_run?
          filters << Filters::ApplyAfterStepHooks.new(@support_code)
          filters << Filters::ApplyBeforeHooks.new(@support_code)
          filters << Filters::ApplyAfterHooks.new(@support_code)
          filters << Filters::ApplyAroundHooks.new(@support_code)
          # need to do this last so it becomes the first test step
          filters << Filters::PrepareWorld.new(self)
        end
      end
    end

    def load_step_definitions
      files = @configuration.support_to_load + @configuration.step_defs_to_load
      @support_code.load_files!(files)
    end

    def install_wire_plugin
      Cucumber::Wire::Plugin.new(@configuration).install if @configuration.all_files_to_load.any? {|f| f =~ %r{\.wire$} }
    end

    def log
      Cucumber.logger
    end

  end

end
