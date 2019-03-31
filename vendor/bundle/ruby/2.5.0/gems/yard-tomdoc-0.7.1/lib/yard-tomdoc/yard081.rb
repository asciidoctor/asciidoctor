module YARD

  # Plugin parser for parsing TomDoc formatted comments.
  #
  class TomDocParser < DocstringParser

    #
    def parse_content(content)
      # TODO: move TomDoc.yard_parse code to here when old versions are no longer supported
      tomdoc = TomDoc.yard_parse(self, content)
      text   = tomdoc.description.to_s

      # Remove trailing/leading whitespace / newlines
      @text = text.gsub(/\A[\r\n\s]+|[\r\n\s]+\Z/, '')
    end

    public :create_tag
  end

  # Set the parser as default when parsing
  YARD::Docstring.default_parser = TomDocParser

  # TODO: what about reset callbacks ?
end

