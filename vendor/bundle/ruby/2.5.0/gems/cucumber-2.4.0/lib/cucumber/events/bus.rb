module Cucumber
  module Events

    # Event bus
    #
    # Implements and in-process pub-sub events broadcaster allowing multiple observers
    # to subscribe to different events that fire as your tests are executed.
    #
    # @private
    class Bus

      def initialize(default_namespace)
        @default_namespace = default_namespace.to_s
        @handlers = {}
      end

      # Register for an event
      def register(event_id, handler_object = nil, &handler_proc)
        handler = handler_proc || handler_object
        raise ArgumentError.new("Please pass either an object or a handler block") unless handler
        event_class = parse_event_id(event_id)
        handlers_for(event_class) << handler
      end

      # Broadcast an event
      def notify(event)
        handlers_for(event.class).each { |handler| handler.call(event) }
      end

      private

      def handlers_for(event_class)
        @handlers[event_class.to_s] ||= []
      end

      def parse_event_id(event_id)
        case event_id
        when Class
          return event_id
        when String
          constantize(event_id)
        else
          constantize("#{@default_namespace}::#{camel_case(event_id)}")
        end
      end

      def camel_case(underscored_name)
        underscored_name.to_s.split("_").map { |word| word.upcase[0] + word[1..-1] }.join
      end

      # Thanks ActiveSupport
      # (Only needed to support Ruby 1.9.3 and JRuby)
      def constantize(camel_cased_word)
        names = camel_cased_word.split('::')

        # Trigger a built-in NameError exception including the ill-formed constant in the message.
        Object.const_get(camel_cased_word) if names.empty?

        # Remove the first blank element in case of '::ClassName' notation.
        names.shift if names.size > 1 && names.first.empty?

        names.inject(Object) do |constant, name|
          if constant == Object
            constant.const_get(name)
          else
            candidate = constant.const_get(name)
            next candidate if constant.const_defined?(name, false)
            next candidate unless Object.const_defined?(name)

            # Go down the ancestors to check if it is owned directly. The check
            # stops when we reach Object or the end of ancestors tree.
            constant = constant.ancestors.inject do |const, ancestor|
              break const    if ancestor == Object
              break ancestor if ancestor.const_defined?(name, false)
              const
            end

            # owner is in Object, so raise
            constant.const_get(name, false)
          end
        end
      end

    end
  end
end
