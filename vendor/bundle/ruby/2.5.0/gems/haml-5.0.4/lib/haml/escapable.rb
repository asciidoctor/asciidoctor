# frozen_string_literal: true
module Haml
  # Like Temple::Filters::Escapable, but with support for escaping by
  # Haml::Herlpers.html_escape and Haml::Herlpers.escape_once.
  class Escapable < Temple::Filter
    def initialize(*)
      super
      @escape_code = "::Haml::Helpers.html_escape((%s))"
      @escaper = eval("proc {|v| #{@escape_code % 'v'} }")
      @once_escape_code = "::Haml::Helpers.escape_once((%s))"
      @once_escaper = eval("proc {|v| #{@once_escape_code % 'v'} }")
      @escape = false
    end

    def on_escape(flag, exp)
      old = @escape
      @escape = flag
      compile(exp)
    ensure
      @escape = old
    end

    # The same as Haml::AttributeBuilder.build_attributes
    def on_static(value)
      [:static,
       if @escape == :once
         @once_escaper[value]
       elsif @escape
         @escaper[value]
       else
         value
       end
      ]
    end

    # The same as Haml::AttributeBuilder.build_attributes
    def on_dynamic(value)
      [:dynamic,
       if @escape == :once
         @once_escape_code % value
       elsif @escape
         @escape_code % value
       else
         "(#{value}).to_s"
       end
      ]
    end
  end
end
