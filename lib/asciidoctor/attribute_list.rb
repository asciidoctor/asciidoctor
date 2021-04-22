# frozen_string_literal: true
module Asciidoctor
# Public: Handles parsing AsciiDoc attribute lists into a Hash of key/value
# pairs. By default, attributes must each be separated by a comma and quotes
# may be used around the value. If a key is not detected, the value is assigned
# to a 1-based positional key, The positional attributes can be "rekeyed" when
# given a positional_attrs array either during parsing or after the fact.
#
# Examples
#
#    attrlist = Asciidoctor::AttributeList.new('astyle')
#
#    attrlist.parse
#    => { 0 => 'astyle' }
#
#    attrlist.rekey(['style'])
#    => { 'style' => 'astyle' }
#
#    attrlist = Asciidoctor::AttributeList.new('quote, Famous Person, Famous Book (2001)')
#
#    attrlist.parse(['style', 'attribution', 'citetitle'])
#    => { 'style' => 'quote', 'attribution' => 'Famous Person', 'citetitle' => 'Famous Book (2001)' }
#
class AttributeList
  APOS = '\''
  BACKSLASH = '\\'
  QUOT = '"'

  # Public: Regular expressions for detecting the boundary of a value
  BoundaryRx = {
    QUOT => /.*?[^\\](?=")/,
    APOS => /.*?[^\\](?=')/,
    ',' => /.*?(?=[ \t]*(,|$))/
  }

  # Public: Regular expressions for unescaping quoted characters
  EscapedQuotes = {
    QUOT => '\\"',
    APOS => '\\\''
  }

  # Public: A regular expression for an attribute name (approx. name token from XML)
  # TODO named attributes cannot contain dash characters
  NameRx = /#{CG_WORD}[#{CC_WORD}\-.]*/

  BlankRx = /[ \t]+/

  # Public: Regular expressions for skipping delimiters
  SkipRx = {
    ',' => /[ \t]*(,|$)/
  }

  def initialize source, block = nil, delimiter = ','
    @scanner = ::StringScanner.new source
    @block = block
    @delimiter = delimiter
    @delimiter_skip_pattern = SkipRx[delimiter]
    @delimiter_boundary_pattern = BoundaryRx[delimiter]
    @attributes = nil
  end

  def parse_into attributes, positional_attrs = []
    attributes.update parse positional_attrs
  end

  def parse positional_attrs = []
    # return if already parsed
    return @attributes if @attributes

    @attributes = {}
    index = 0

    while parse_attribute index, positional_attrs
      break if @scanner.eos?
      skip_delimiter
      index += 1
    end

    @attributes
  end

  def rekey positional_attrs
    AttributeList.rekey @attributes, positional_attrs
  end

  def self.rekey attributes, positional_attrs
    positional_attrs.each_with_index do |key, index|
      if key && (val = attributes[index + 1])
        # QUESTION should we delete the positional key?
        attributes[key] = val
      end
    end
    attributes
  end

  private

  def parse_attribute index, positional_attrs
    continue = true
    skip_blank
    case @scanner.peek 1
    # example: "quote" || "foo
    when QUOT
      name = parse_attribute_value @scanner.get_byte
    # example: 'quote' || 'foo
    when APOS
      name = parse_attribute_value @scanner.get_byte
      single_quoted = true unless name.start_with? APOS
    else
      skipped = ((name = scan_name) && skip_blank) || 0
      if @scanner.eos?
        return unless name || (@scanner.string.rstrip.end_with? @delimiter)
        # example: quote (at eos)
        continue = nil
      # example: quote,
      elsif (c = @scanner.get_byte) == @delimiter
        @scanner.unscan
      elsif name
        # example: foo=...
        if c == '='
          skip_blank
          case (c = @scanner.get_byte)
          # example: foo="bar" || foo="ba\"zaar" || foo="bar
          when QUOT
            value = parse_attribute_value c
          # example: foo='bar' || foo='ba\'zaar' || foo='ba"zaar' || foo='bar
          when APOS
            value = parse_attribute_value c
            single_quoted = true unless value.start_with? APOS
          # example: foo=,
          when @delimiter
            value = ''
            @scanner.unscan
          # example: foo= (at eos)
          when nil
            value = ''
          # example: foo=bar || foo=None
          else
            value = %(#{c}#{scan_to_delimiter})
            return true if value == 'None'
          end
        # example: foo bar
        else
          name = %(#{name}#{' ' * skipped}#{c}#{scan_to_delimiter})
        end
      # example: =foo= || !foo
      else
        name = %(#{c}#{scan_to_delimiter})
      end
    end

    if value
      # example: options="opt1,opt2,opt3" || opts="opts1,opt2,opt3"
      case name
      when 'options', 'opts'
        if value.include? ','
          value = value.delete ' ' if value.include? ' '
          (value.split ',').each {|opt| @attributes[%(#{opt}-option)] = '' unless opt.empty? }
        else
          @attributes[%(#{value}-option)] = '' unless value.empty?
        end
      else
        if single_quoted && @block
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
      name = @block.apply_subs name if single_quoted && @block
      if (positional_attr_name = positional_attrs[index]) && name
        @attributes[positional_attr_name] = name
      end
      # QUESTION should we assign the positional key even when it's claimed by a positional attribute?
      @attributes[index + 1] = name
    end

    continue
  end

  def parse_attribute_value quote
    # empty quoted value
    if (@scanner.peek 1) == quote
      @scanner.get_byte
      ''
    elsif (value = scan_to_quote quote)
      @scanner.get_byte
      (value.include? BACKSLASH) ? (value.gsub EscapedQuotes[quote], quote) : value
    # leading quote only
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
    @scanner.scan BoundaryRx[quote]
  end
end
end
