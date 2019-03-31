module YARD

  class DocstringParser
    def parse(content, object = nil, handler = nil)
      @object = object
      @handler = handler
      @raw_text = content

      if object
        text = parse_tomdoc(content)
      else        
        text = parse_content(content)
      end

      # Remove trailing/leading whitespace / newlines
      @text = text.gsub(/\A[\r\n\s]+|[\r\n\s]+\Z/, '')
      call_directives_after_parse
      call_after_parse_callbacks

      self
    end

    #
    def parse_tomdoc(content)
      tomdoc = TomDoc.yard_parse(self, content)
      tomdoc.description.to_s
    end

    public :create_tag
  end

end
