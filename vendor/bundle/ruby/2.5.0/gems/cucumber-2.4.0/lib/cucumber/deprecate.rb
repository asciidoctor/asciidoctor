require 'cucumber/platform'
require 'cucumber/gherkin/formatter/ansi_escapes'

module Cucumber
  module Deprecate
    module ForUsers
      AnsiEscapes = Cucumber::Gherkin::Formatter::AnsiEscapes

      def self.call(message, method, remove_after_version)
        STDERR.puts AnsiEscapes.failed + "\nWARNING: ##{method} is deprecated and will be removed after version #{remove_after_version}. #{message}.\n(Called from #{caller[2]})" + AnsiEscapes.reset
      end
    end

    module ForDevelopers
      def self.call(message, method, remove_after_version)
        if Cucumber::VERSION > remove_after_version
          raise "This method is due for removal after version #{remove_after_version}"
        end
      end
    end

    Strategy = $0.match(/rspec$/) ? ForDevelopers : ForUsers
  end

  def self.deprecate(*args)
    Deprecate::Strategy.call(*args)
  end

end
