require 'cucumber'
require 'cucumber/core/ast/location'

module Cucumber
  class FileSpecs
    FILE_COLON_LINE_PATTERN = /^([\w\W]*?)(?::([\d:]+))?$/ #:nodoc:

    def initialize(file_specs)
      Cucumber.logger.debug("Features:\n")
      @file_specs = file_specs.map { |s| FileSpec.new(s) }
      Cucumber.logger.debug("\n")
    end

    def locations
      @file_specs.map(&:locations).flatten
    end

    def files
      @file_specs.map(&:file).uniq
    end

    class FileSpec
      def initialize(s)
        @file, @lines = *FILE_COLON_LINE_PATTERN.match(s).captures
        Cucumber.logger.debug("  * #{@file}\n")
        @lines = String(@lines).split(':').map { |line| Integer(line) }
      end

      attr_reader :file

      def locations
        return [ Core::Ast::Location.new(@file) ] if @lines.empty?
        @lines.map { |line| Core::Ast::Location.new(@file, line) }
      end
    end
  end
end
