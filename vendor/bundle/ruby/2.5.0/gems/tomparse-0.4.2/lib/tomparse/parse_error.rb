module TomParse

  # Raised when comment can't be parsed, which means it's most
  # likely not valid TomDoc.
  #
  class ParseError < RuntimeError
    # Create new ParseError object.
    #
    # doc - document string
    #
    def initialize(doc)
      @doc = doc
    end

    # Provide access to document string.
    #
    # Returns String.
    def message
      @doc
    end

    # Provide access to document string.
    #
    # Returns String.
    def to_s
      @doc
    end
  end

end
