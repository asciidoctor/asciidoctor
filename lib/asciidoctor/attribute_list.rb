module Asciidoctor
# Public: Handles parsing AsciiDoc attribute lists into a Hash of key/value
# pairs. By default, attributes must each be separated by a comma and quotes
# may be used around the value. If a key is not detected, the value is assigned
# to a 1-based positional key, The positional attributes can be "rekeyed" when
# given a posattrs array either during parsing or after the fact.
#
# Examples
#
#    attrlist = Asciidoctor::AttributeList.new('astyle')
#
#    attrlist.parse
#    => {0 => 'astyle'} 
#
#    attrlist.rekey(['style'])
#    => {'style' => 'astyle'}
#
#    attrlist = Asciidoctor::AttributeList.new('quote, Famous Person, Famous Book (2001)')
#
#    attrlist.parse(['style', 'attribution', 'citetitle'])
#    => {'style' => 'quote', 'attribution' => 'Famous Person', 'citetitle' => 'Famous Book (2001)'} 
#
class AttributeList

  # Public: Regular expressions for detecting the boundary of a value
  BOUNDARY_PATTERNS = {
    '"' => /.*?[^\\](?=")/,
    '\'' => /.*?[^\\](?=')/,
    ',' => /.*?(?=[ \t]*(,|$))/
  }

  # Public: Regular expressions for unescaping quoted characters
  UNESCAPE_PATTERNS = {
    '\\"' => /\\"/,
    '\\\'' => /\\'/ 
  }

  # Public: Regular expressions for skipping blanks and delimiters
  SKIP_PATTERNS = {
    :blank => /[ \t]+/,
    ',' => /[ \t]*(,|$)/
  }

  # Public: A regular expression for an attribute name
  # TODO named attributes cannot contain dash characters
  NAME_PATTERN = /[A-Za-z:_][A-Za-z:_\-\.]*/

  def initialize(source, block = nil, quotes = ['\'', '"'], delimiter = ',', escape_char = '\\')
    @scanner = ::StringScanner.new source
    @block = block
    @quotes = quotes
    @escape_char = escape_char
    @delimiter = delimiter
    @attributes = nil
  end

  def parse_into(attributes, posattrs = [])
    attributes.update(parse(posattrs))
  end

  def parse(posattrs = [])
    return @attributes unless @attributes.nil?

    @attributes = {}
    # not sure if I want this assignment or not
    #attributes[0] = @scanner.string
    index = 0

    while parse_attribute(index, posattrs)
      break if @scanner.eos?
      skip_delimiter
      index += 1
    end

    @attributes
  end

  def rekey(posattrs)
    AttributeList.rekey(@attributes, posattrs)
  end

  def self.rekey(attributes, pos_attrs)
    pos_attrs.each_with_index do |key, index|
      next if key.nil?
      pos = index + 1
      unless (val = attributes[pos]).nil?
        attributes[key] = val
        #QUESTION should we delete the positional key?
        #attributes.delete pos
      end
    end

    attributes
  end

  def parse_attribute(index = 0, pos_attrs = [])
    single_quoted_value = false
    skip_blank
    first = @scanner.peek(1)
    # example: "quote" || 'quote'
    if @quotes.include? first
      value = nil
      name = parse_attribute_value @scanner.get_byte
      if first == '\''
        single_quoted_value = true
      end
    else
      name = scan_name

      skipped = 0
      c = nil
      if @scanner.eos?
        if name.nil?
          return false
        end
      else
        skipped = skip_blank || 0
        c = @scanner.get_byte
      end

      # example: quote
      if c.nil? || c == @delimiter
        value = nil
      # example: Sherlock Holmes || =foo=
      elsif c != '=' || name.nil?
        remainder = scan_to_delimiter
        name = '' if name.nil?
        name += ' ' * skipped + c
        name += remainder unless remainder.nil?
        value = nil
      else
        skip_blank
        # example: foo=,
        if @scanner.peek(1) == @delimiter
          value = nil
        else
          c = @scanner.get_byte

          # example: foo="bar" || foo='bar' || foo="ba\"zaar" || foo='ba\'zaar' || foo='ba"zaar' (all spaces ignored)
          if @quotes.include? c
            value = parse_attribute_value c
            if c == '\''
              single_quoted_value = true
            end
          # example: foo=bar (all spaces ignored)
          elsif !c.nil?
            value = c + scan_to_delimiter
          end
        end
      end
    end

    if value.nil?
      resolved_name = single_quoted_value && !@block.nil? ? @block.apply_normal_subs(name) : name
      if !(pos_name = pos_attrs[index]).nil?
        @attributes[pos_name] = resolved_name
      else
        #@attributes[index + 1] = resolved_name
      end
      # not sure if we want to always assign the positional key
      @attributes[index + 1] = resolved_name
      # not sure if I want this assignment or not
      #@attributes[resolved_name] = nil
    else
      resolved_value = value
      # example: options="opt1,opt2,opt3"
      # opts is an alias for options
      if name == 'options' || name == 'opts'
        name = 'options'
        resolved_value.split(',').each do |o|
          @attributes["#{o.strip}-option"] = ''
        end
      elsif single_quoted_value && !@block.nil?
        resolved_value = @block.apply_normal_subs(value)
      end
      @attributes[name] = resolved_value
    end

    true
  end

  def parse_attribute_value(quote)
    # empty quoted value
    if @scanner.peek(1) == quote
      @scanner.get_byte 
      return ''
    end

    value = scan_to_quote quote
    if value.nil?
      quote + scan_to_delimiter
    else
      @scanner.get_byte
      value.gsub(UNESCAPE_PATTERNS[@escape_char + quote], quote)
    end
  end

  def skip_blank
    @scanner.skip SKIP_PATTERNS[:blank]
  end

  def skip_delimiter
    @scanner.skip SKIP_PATTERNS[@delimiter]
  end

  def scan_name
    @scanner.scan NAME_PATTERN
  end

  def scan_to_delimiter
    @scanner.scan BOUNDARY_PATTERNS[@delimiter]
  end

  def scan_to_quote(quote)
    @scanner.scan BOUNDARY_PATTERNS[quote]
  end

end
end
