require 'cucumber/formatter/json'

module Cucumber
  module Formatter
    # The formatter used for <tt>--format json_pretty</tt>
    class JsonPretty < Json
    end
  end
end

