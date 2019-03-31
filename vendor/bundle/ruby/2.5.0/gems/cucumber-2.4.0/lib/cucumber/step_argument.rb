module Cucumber
  # Defines the location and value of a captured argument from the step
  # text
  class StepArgument
    def self.arguments_from(regexp, step_name)
      match = regexp.match(step_name)
      if match
        n = 0
        match.captures.map do |val|
          n += 1
          offset = match.offset(n)[0]
          new(offset, val)
        end
      else
        nil
      end
    end

    attr_reader :offset, :val

    def initialize(offset, val)
      @offset, @val = offset, val
    end
  end
end
