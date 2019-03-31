module Cucumber
  module RbSupport
    # Wrapper for Before, After and AfterStep hooks
    class RbHook
      attr_reader :tag_expressions, :location

      def initialize(rb_language, tag_expressions, proc)
        @rb_language = rb_language
        @tag_expressions = tag_expressions
        @proc = proc
        @location = Cucumber::Core::Ast::Location.from_source_location(*@proc.source_location)
      end

      def invoke(pseudo_method, arguments, &block)
        @rb_language.current_world.cucumber_instance_exec(false, pseudo_method, *[arguments, block].flatten.compact, &@proc)
      end
    end
  end
end
