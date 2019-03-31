module Cucumber
  # Only used for keeping track of available and invoked step definitions
  # in a way that also works for other programming languages (i.e. cuke4duke)
  # Used for reporting purposes only (usage formatter).
  class StepDefinitionLight
    attr_reader :regexp_source, :location

    def initialize(regexp_source, location)
      @regexp_source, @location = regexp_source, location
    end

    def eql?(o)
      regexp_source == o.regexp_source && location == o.location
    end

    def hash
      regexp_source.hash + 31*location.to_s.hash
    end
  end
end
