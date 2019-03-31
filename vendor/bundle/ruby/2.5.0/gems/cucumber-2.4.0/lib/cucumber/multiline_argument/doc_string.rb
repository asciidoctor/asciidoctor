module Cucumber
  module MultilineArgument
    class DocString < SimpleDelegator
      def append_to(array)
        array << self.to_s
      end
    end
  end
end
