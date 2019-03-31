require 'cucumber/core/test/result'

module Cucumber
  # Raised when there is no matching StepDefinition for a step.
  class Undefined < Core::Test::Result::Undefined
    def self.from(result, step_name)
      if result.is_a?(self)
        return result.with_message(with_prefix(result.message))
      end

      begin
        raise self.new(with_prefix(step_name))
      rescue => exception
        return exception
      end
    end

    def self.with_prefix(step_name)
      %(Undefined step: "#{step_name}")
    end
  end

  # Raised when there is no matching StepDefinition for a step called
  # from within another step definition.
  class UndefinedDynamicStep < StandardError
    def initialize(step_name)
      super %(Undefined dynamic step: "#{step_name}")
    end
  end

  # Raised when a StepDefinition's block invokes World#pending
  class Pending < Core::Test::Result::Pending
  end

  # Raised when a step matches 2 or more StepDefinitions
  class Ambiguous < StandardError
    def initialize(step_name, step_definitions, used_guess)
      message = "Ambiguous match of \"#{step_name}\":\n\n"
      message << step_definitions.map{|sd| sd.backtrace_line}.join("\n")
      message << "\n\n"
      message << "You can run again with --guess to make Cucumber be more smart about it\n" unless used_guess
      super(message)
    end
  end

  class TagExcess < StandardError
    def initialize(messages)
      super(messages.join("\n"))
    end
  end
end
