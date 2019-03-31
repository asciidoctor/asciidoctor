module TomParse
  require 'tomparse/parser'
  require 'tomparse/parse_error'
  require 'tomparse/argument'
  require 'tomparse/option'

  # Main interface to parser.
  #
  # comment - code comment [String]
  #
  def self.parse(comment, parse_options={})
    TomDoc.new(comment, parse_options)
  end

  # Encapsulate parsed tomdoc documentation.
  #
  # TODO: Currently uses lazy evaluation, eventually this should
  # be removed and simply parsed all at once.
  #
  class TomDoc

    attr_accessor :raw

    # Public: Initialize a TomDoc object.
    #
    # text - The raw text of a method or class/module comment.
    #
    # Returns new TomDoc instance.
    def initialize(text, parse_options={})
      @parser = Parser.new(text, parse_options)
      @parser.parse
    end

    # Raw documentation text.
    #
    # Returns String of raw documentation text.
    def to_s
      @parser.raw
    end

    # Validate given comment text.
    #
    # Returns true if comment is valid, otherwise false.
    def self.valid?(text)
      new(text).valid?
    end

    # Validate raw comment.
    #
    # Returns true if comment is valid, otherwise false.
    def valid?
      @parser.valid?
    end

    # Validate raw comment.
    #
    # Returns true if comment is valid.
    # Raises ParseError if comment is not valid.
    def validate
      @parser.validate
    end

    # TODO: Should we clean the raw documentation here and then pass it on to the parser?

    # The raw comment text cleaned-up and ready for section parsing.
    #
    # Returns cleaned-up comment String.
    def tomdoc
      return @parser.tomdoc
    end

    # List of comment sections. These are divided simply on "\n\n".
    #
    # Returns Array of comment sections.
    def sections
      @parser.sections
    end

    # Description of method or class/module.
    #
    # Returns description String.
    def description
      @parser.description
    end

    # Arguments list.
    #
    # Returns list of arguments.
    def arguments
      @parser.arguments
    end
    alias args arguments

    # Keyword arguments, aka Options.
    #
    # Returns list of options.
    def options
      @parser.options
    end
    alias keyword_arguments options

    # List of use examples of a method or class/module.
    #
    # Returns String of examples.
    def examples
      @parser.examples
    end

    # Description of a methods yield procedure.
    #
    # Returns String decription of yield procedure.
    def yields
      @parser.yields
    end

    # The list of retrun values a method can return.
    #
    # Returns Array of method return descriptions.
    def returns
      @parser.returns
    end

    # A list of errors a method might raise.
    #
    # Returns Array of method raises descriptions.
    def raises
      @parser.raises
    end

    # A list of alternate method signatures.
    #
    # Returns Array of signatures.
    def signatures
      @parser.signatures 
    end

    # Deprecated: A list of signature fields.
    #
    # TODO: Presently this will always return an empty list. It will either
    # be removed or renamed in future version.
    #
    # Returns Array of field definitions.
    def signature_fields
      @parser.signature_fields
    end

    # List of tags.
    #
    # Returns an associatve array of tags. [Array<Array<String>>]
    def tags
      @parser.tags
    end

    # Check if method is public.
    #
    # Returns true if method is public.
    def public?
      @parser.public?
    end

    # Check if method is internal.
    #
    # Returns true if method is internal.
    def internal?
      @parser.internal?
    end

    # Check if method is deprecated.
    #
    # Returns true if method is deprecated.
    def deprecated?
      @parser.deprecated?
    end

  end

end
