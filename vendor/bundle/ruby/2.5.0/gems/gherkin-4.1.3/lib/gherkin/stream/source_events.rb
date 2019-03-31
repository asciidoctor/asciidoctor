module Gherkin
  module Stream
    class SourceEvents
      def initialize(paths)
        @paths = paths
      end

      def enum
        Enumerator.new do |y|
          @paths.each do |path|
            event = {
              'type' => 'source',
              'uri' => path,
              'data' => File.open(path, 'r:UTF-8', &:read),
              'media' => {
                'encoding' => 'utf-8',
                'type' => 'text/vnd.cucumber.gherkin+plain'
              }
            }
            y.yield(event)
          end
        end
      end
    end
  end
end
