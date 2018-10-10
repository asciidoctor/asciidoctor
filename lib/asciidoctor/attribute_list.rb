# encoding: UTF-8
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
  BACKSLASH = '\\'
  APOS = '\''

  # Public: Regular expressions for detecting the boundary of a value
  BoundaryRxs = {
    '"' => /.*?[^\\](?=")/,
    APOS => /.*?[^\\](?=')/,
    ',' => /.*?(?=[ \t]*(,|$))/
  }

  # Public: Regular expressions for unescaping quoted characters
  EscapedQuotes = {
    '"' => '\\"',
    APOS => '\\\''
  }

  # Public: A regular expression for an attribute name (approx. name token from XML)
  # TODO named attributes cannot contain dash characters
  NameRx = /#{CG_WORD}[#{CC_WORD}\-.]*/

  BlankRx = /[ \t]+/

  # Public: Regular expressions for skipping blanks and delimiters
  SkipRxs = {
    :blank => BlankRx,
    ',' => /[ \t]*(,|$)/
  }

  def initialize source, block = nil, delimiter = ','
    @scanner = ::StringScanner.new source
    @block = block
    @delimiter = delimiter
    @delimiter_skip_pattern = SkipRxs[delimiter]
    @delimiter_boundary_pattern = BoundaryRxs[delimiter]
    @attributes = nil
  end

  def parse_into attributes, posattrs = []
    attributes.update(parse posattrs)
  end

  def parse posattrs = []
    # return if already parsed
    return @attributes if @attributes

    @attributes = {}
    # QUESTION do we want to store the attribute list as the zero-index attribute?
    #attributes[0] = @scanner.string
    index = 0

    while parse_attribute index, posattrs
      break if @scanner.eos?
      skip_delimiter
      index += 1
    end

    @attributes
  end

  def rekey posattrs
    AttributeList.rekey @attributes, posattrs
  end

  def self.rekey attributes, pos_attrs
    pos_attrs.each_with_index do |key, index|
      next unless key
      pos = index + 1
      if (val = attributes[pos])
        # QUESTION should we delete the positional key?
        attributes[key] = val
      end
    end

    attributes
  end

  def parse_attribute index = 0, pos_attrs = []
    single_quoted_value = false
    skip_blank
    # example: "quote"
    if (first = @scanner.peek(1)) == '"'
      name = parse_attribute_value @scanner.get_byte
      value = nil
    # example: 'quote'
    elsif first == APOS
      name = parse_attribute_value @scanner.get_byte
      value = nil
      single_quoted_value = true unless name.start_with? APOS
    else
      name = scan_name

      skipped = 0
      c = nil
      if @scanner.eos?
        return false unless name
      else
        skipped = skip_blank || 0
        c = @scanner.get_byte
      end

      # example: quote
      if !c || c == @delimiter
        value = nil
      # example: Sherlock Holmes || =foo=
      elsif c != '=' || !name
        name = %(#{name}#{' ' * skipped}#{c}#{scan_to_delimiter})
        value = nil
      else
        skip_blank
        if @scanner.peek(1)
          # example: foo="bar" || foo="ba\"zaar"
          if (c = @scanner.get_byte) == '"'
            value = parse_attribute_value c
          # example: foo='bar' || foo='ba\'zaar' || foo='ba"zaar'
          elsif c == APOS
            value = parse_attribute_value c
            single_quoted_value = true unless value.start_with? APOS
          # example: foo=,
          elsif c == @delimiter
            value = ''
          # example: foo=bar (all spaces ignored)
          else
            value = %(#{c}#{scan_to_delimiter})
            return true if value == 'None'
          end
        end
      end
    end

    if value
      # example: options="opt1,opt2,opt3"
      # opts is an alias for options
      case name
      when 'options', 'opts'
        if value.include? ','
          value = value.delete ' ' if value.include? ' '
          (value.split ',').each {|opt| @attributes[%(#{opt}-option)] = '' unless opt.empty? }
        else
          @attributes[%(#{value = value.strip}-option)] = ''
        end
        @attributes['options'] = value
      else
        if single_quoted_value && @block
          case name
          when 'title', 'reftext'
            @attributes[name] = value
          else
            @attributes[name] = @block.apply_subs value
          end
        else
          @attributes[name] = value
        end
      end
    else
      resolved_name = single_quoted_value && @block ? (@block.apply_subs name) : name
      if (pos_name = pos_attrs[index])
        @attributes[pos_name] = resolved_name
      end
      # QUESTION should we always assign the positional key?
      @attributes[index + 1] = resolved_name
      # QUESTION should we assign the resolved name as an attribute?
      #@attributes[resolved_name] = nil
    end

    true
  end

  def parse_attribute_value quote
    # empty quoted value
    if @scanner.peek(1) == quote
      @scanner.get_byte
      return ''
    end

    if (value = scan_to_quote quote)
      @scanner.get_byte
      if value.include? BACKSLASH
        value.gsub EscapedQuotes[quote], quote
      else
        value
      end
    else
      %(#{quote}#{scan_to_delimiter})
    end
  end

  def skip_blank
    @scanner.skip BlankRx
  end

  def skip_delimiter
    @scanner.skip @delimiter_skip_pattern
  end

  def scan_name
    @scanner.scan NameRx
  end

  def scan_to_delimiter
    @scanner.scan @delimiter_boundary_pattern
  end

  def scan_to_quote quote
    @scanner.scan BoundaryRxs[quote]
  end

end
end
