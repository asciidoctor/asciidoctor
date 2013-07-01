module Asciidoctor
module Extensions
  class << self

    def extensions
      @extensions ||= {}
    end

    def register_include_handler(handler)
      extensions[:include] = handler
    end

    def unregister_include_handler
      extensions.delete(:include)
    end

    def include_handler
      extensions[:include]
    end

  end
=begin
  class IncludeHandler
    def handles?
      true
    end

    def process document, target, attributes
      raise 'Not implemented'
    end
  end
=end
end
end
