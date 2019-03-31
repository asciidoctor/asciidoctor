module TomParse

  # Encapsulate parsed tomdoc documentation.
  #
  # TODO: Currently uses lazy evaluation, eventually this should
  # be removed and simply parsed all at once.
  #
  class Parser

    #
    attr_accessor :raw

    # Public: Initialize a TomDoc object.
    #
    # text - The raw text of a method or class/module comment.
    #
    # Returns new TomDoc instance.
    def initialize(text, parse_options={})
      @raw = text.to_s.strip

      @arguments        = []
      @options          = []
      @examples         = []
      @returns          = []
      @raises           = []
      @signatures       = []
      @signature_fields = []
      @tags             = []

      #parse unless @raw.empty?
    end

    # Raw documentation text.
    #
    # Returns String of raw documentation text.
    def to_s
      @raw
    end

    # Validate given comment text.
    #
    # Returns true if comment is valid, otherwise false.
    def self.valid?(text)
      new(text).valid?
    end

    # Validate raw comment.
    #
    # TODO: This needs improvement.
    #
    # Returns true if comment is valid, otherwise false.
    def valid?
      begin
        new(text).validate
        true
      rescue ParseError
        false
      end
    end

    # Validate raw comment.
    #
    # Returns true if comment is valid.
    # Raises ParseError if comment is not valid.
    def validate
      if !raw.include?('Returns')
        raise ParseError.new("No `Returns' statement.")
      end

      if sections.size < 2
        raise ParseError.new("No description section found.")
      end

      true
    end

    # The raw comment text cleaned-up and ready for section parsing.
    #
    # Returns cleaned-up comment String.
    def tomdoc
      lines = raw.split("\n")

      # remove remark symbol
      if lines.all?{ |line| /^\s*#/ =~ line }   
        lines = lines.map do |line|
          line =~ /^(\s*#)/ ? line.sub($1, '') : nil
        end
      end

      # for some reason the first line is coming in without indention
      # regardless, so we temporary remove it
      first = lines.shift

      # remove indention
      spaces = lines.map do |line|
        next if line.strip.empty?
        md = /^(\s*)/.match(line)
        md ? md[1].size : nil
      end.compact

      space = spaces.min || 0
      lines = lines.map do |line|
        if line.strip.empty?
          line.strip
        else
          line[space..-1]
        end
      end

      # put first line back
      lines.unshift(first.sub(/^\s*/,'')) if first

      lines.compact.join("\n")
    end

    # List of comment sections. These are divided simply on "\n\n".
    #
    # Returns Array of comment sections.
    def sections
      parsed {
        @sections
      }
    end

    # Description of method or class/module.
    #
    # Returns description String.
    def description
      parsed {
        @description
      }
    end

    # Arguments list.
    #
    # Returns list of arguments.
    def arguments
      parsed {
        @arguments
      }
    end
    alias args arguments

    # Keyword arguments, aka Options.
    #
    # Returns list of options.
    def options
      parsed {
        @options
      }
    end
    alias keyword_arguments options

    # List of use examples of a method or class/module.
    #
    # Returns String of examples.
    def examples
      parsed {
        @examples
      }
    end

    # Description of a methods yield procedure.
    #
    # Returns String decription of yield procedure.
    def yields
      parsed {
        @yields
      }
    end

    # The list of retrun values a method can return.
    #
    # Returns Array of method return descriptions.
    def returns
      parsed {
        @returns
      }
    end

    # A list of errors a method might raise.
    #
    # Returns Array of method raises descriptions.
    def raises
      parsed {
        @raises
      }
    end

    # A list of alternate method signatures.
    #
    # Returns Array of signatures.
    def signatures
      parsed {
        @signatures 
      }
    end

    # A list of signature fields.
    #
    # Returns Array of field definitions.
    def signature_fields
      parsed {
        @signature_fields
      }
    end

    # List of tags.
    #
    # Returns an associatve array of tags. [Array<Array<String>>]
    def tags
      parsed {
        @tags
      }
    end

    # Method status, can be `Public`, `Internal` or `Deprecated`.
    #
    # Returns [String]
    def status
      parsed {
        @status
      }
    end

    # Check if method is public.
    #
    # Returns true if method is public.
    def public?
      parsed {
        @status == 'Public'
      }
    end

    # Check if method is internal.
    #
    # Returns true if method is internal.
    def internal?
      parsed {
        @status == 'Internal'
      }
    end

    # Check if method is deprecated.
    #
    # Returns true if method is deprecated.
    def deprecated?
      parsed {
        @status == 'Deprecated'
      }
    end

=begin
    # Internal: Parse the Tomdoc formatted comment.
    #
    # Returns true if there was a comment to parse.
    def parse
      @parsed = true

      sections = tomdoc.split("\n\n")

      return false if sections.empty?

      # The description is always the first section, but it may have
      # multiple paragraphs. This routine collects those together.
      desc = [sections.shift]
      loop do
         s = sections.first
         break if s.nil?                  # got nothing
         break if s =~ /^\w+\s+\-/m       # argument line
         break if section_type(s) != nil  # another section type
         desc << sections.shift
      end
      sections = [desc.join("\n\n")] + sections
  
      @sections = sections.dup

      parse_description(sections.shift)

      if sections.first && sections.first =~ /^\w+\s+\-/m
        parse_arguments(sections.shift)
      end

      current = sections.shift
      while current
        case type = section_type(current)
        #when :arguments
        #  parse_arguments(current)
        #when :options
        #  parse_options(current)
        when :examples
          parse_examples(current, sections)
        when :yields
          parse_yields(current)
        when :returns
          parse_returns(current)  # also does raises
        when :raises
          parse_returns(current)  # also does returns
        when :signature
          parse_signature(current, sections)
        when Symbol
          parse_tag(current)
        end
        current = sections.shift
      end

      return @parsed
    end
=end

    # Internal: Parse the Tomdoc formatted comment.
    #
    # Returns true if there was a comment to parse.
    def parse
      @parsed = true

      sections = smart_split(tomdoc)

      return false if sections.empty?

      # We are assuming that the first section is always description.
      # And it should be, but people aren't always proper, so perhaps
      # this can be made a little smarter in the future.
      parse_description(sections.shift)

      # The second section may be arguments.
      if sections.first && sections.first =~ /^\w+\s+\-/m
        parse_arguments(sections.shift)
      end

      current = sections.shift
      while current
        case type = section_type(current)
        when :arguments
          parse_arguments(current)
        when :options
          parse_options(current)
        when :example
          parse_example(current)
        when :examples
          parse_examples(current)
        when :yields
          parse_yields(current)
        when :returns
          parse_returns(current)
        when :raises
          parse_raises(current)
        when :signature
          parse_signature(current)
        when Symbol
          parse_tag(current)
        end
        current = sections.shift
      end

      return @parsed
    end

  private

    # Has the comment been parsed yet?
    def parsed(&block)
      parse unless @parsed
      block.call
    end

    # Split the documentation up into proper sections.
    # The method works by building up a list of linenos
    # of where each section begins.
    #
    # Returns an array section strings. [Array<String>]
    def smart_split(doc)
      splits = []
      index  = -1

      lines = doc.lines.to_a

      # Remove any blank lines off the top.
      lines.shift while lines.first && lines.first.strip.empty?

      # Keep a copy of the lines for later use.
      doc_lines = lines.dup
     

      # The first line may have a `Public`/`Private`/`Deprecated` marker.
      # So we just skip the first line.
      lines.shift
      index += 1

      # The description is always the first section, but it may have
      # multiple paragraphs. And the second section may be an arguments
      # list without a header. This loop handles that.
      while line = lines.shift
        index += 1
        if argument_line?(line)
          splits << index
          break
        elsif section_type(line)
          splits << index
          break
        end
      end
      
      # The rest of the the document should have identifiable section markers.
      while line = lines.shift
        index += 1
        if section_type(line)
          splits << index
        end
      end

      # Now we split the documentation up into sections using
      # the line indexes we collected above.
      sections = []
      b = 0
      splits.shift if splits.first == 0
      splits.each do |i|
        sections << doc_lines[b...i].join
        b = i
      end
      sections << doc_lines[b..-1].join

      return sections
    end

    # Check if a line of text could be an argument definition.
    # I.e. it has a word followed by a dash.
    #
    # Return [Boolean]
    def argument_line?(line)
      /^\w+\s+\-/m =~ line.strip
    end

    # Determine section type.
    def section_type(section)
      case section
      when /\AArguments\s*$/
        :arguments
      when /\AOptions\s*$/
        :options
      when /\AExamples\s*$/
        :examples
      when /\AExample\s*$/
        :example
      when /\ASignature(s)?\s*$/
        :signature
      when /^Yield(s)?/
        :yields
      when /^Return(s)?/
        :returns
      when /^Raise(s)?/
        :raises
      when /\A([A-Z]\w+)\:\ /
        $1.to_sym
      else
        nil
      end
    end

    # Recognized description status.
    TOMDOC_STATUS = ['Internal', 'Public', 'Deprecated']

    # Parse description.
    #
    # section - String containig description.
    #
    # Returns nothing.
    def parse_description(section)
      if md = /^([A-Z]\w+\:)/.match(section)
        @status = md[1].chomp(':')
        if TOMDOC_STATUS.include?(@status)
          @description = md.post_match.strip
        else
          @description = section.strip
        end
      else
        @description = section.strip
      end   
    end

    # Parse arguments section. Arguments occur subsequent to
    # the description.
    #
    # section - String containing argument definitions.
    #
    # Returns nothing.
    def parse_arguments(section)
      args = []
      last_indent = nil

      section.lines.each do |line|
        next if /^Arguments\s*$/i =~ line  # optional header
        next if line.strip.empty?
        indent = line.scan(/^\s*/)[0].to_s.size

        if last_indent && indent >= last_indent
          args.last.description << "\r\n" + line
        else
          param, desc = line.split(" - ")
          args << Argument.new(param.strip, desc.to_s.strip) if param #&& desc
          last_indent = indent + 1
        end
      end

      args.each do |arg|
        arg.parse(arg.description)
      end

      @arguments = args
    end

    # the description.
    #
    # section - String containing argument definitions.
    #
    # Returns nothing.
    def parse_options(section)
      opts = []
      last_indent = nil

      section.lines.each do |line|
        next if /^\s*Options\s*$/i =~ line  # optional header
        next if line.strip.empty?
        indent = line.scan(/^\s*/)[0].to_s.size

        if last_indent && indent > 0 && indent >= last_indent
          opts.last.description << "\r\n" + line
        else
          param, desc = line.split(" - ")
          opts << Option.new(param.strip, desc.strip) if param && desc
        end

        last_indent = indent
      end

      #opts.each do |opt|
      #  opt.parse(arg.description)
      #end

      @options = opts
    end

    # Parse example.
    #
    # section  - String starting with `Example`.
    #
    # Returns nothing.
    def parse_example(section)
      # remove the initial `Example` line and right strip
      section = section.sub(/.*?\n/, '')
      example = clean_example(section)
      @examples << example unless example.strip.empty?
    end

    # Parse examples.
    #
    # section  - String starting with `Examples`.
    #
    # Returns nothing.
    def parse_examples(section)
      # remove the initial `Examples` line and right strip
      section = section.sub(/.*?\n/, '')
      section.split("\n\n").each do |ex|
        next if ex.strip.empty?
        example = clean_example(ex)
        @examples << example
      end
    end

    # Parse yields section.
    #
    # section - String contaning Yields line.
    #
    # Returns nothing.
    def parse_yields(section)
      @yields = section.strip
    end

    # Parse returns section.
    #
    # section - String contaning Returns and/or Raises lines.
    #
    # Returns nothing.
    def parse_returns(section)
      text = section.gsub(/\s+/, ' ').strip
      @returns << text
    end

    # Parse raises section.
    #
    # section - String contaning Raises text.
    #
    # Returns nothing.
    def parse_raises(section)
      text = section.gsub(/\s+/, ' ').strip
      @raises << text.strip
    end

    # Parse signature section.
    #
    # IMPORTANT! This is not mojombo TomDoc! Rather signatures are simply
    # a list of alternate ways to call a method, e.g. when *args is used but
    # only specific argument patterns are possible.
    #
    # section - String starting with `Signature`.
    #
    # Returns nothing.
    def parse_signature(section)
      signatures = []

      section = section.sub(/^\s*Signature(s)?/, '').strip

      lines = section.lines.to_a

      lines.each do |line|
        next if line.strip.empty?
        signatures << line.strip
      end

      @signatures = signatures

      #if line =~ /^\w+\s*\-/m
      #  parse_signature_fields(sections.shift)
      #end
    end

=begin
    # Subsequent to Signature section there can be field
    # definitions.
    #
    # section  - String subsequent to signatures.
    #
    # Returns nothing.
    def parse_signature_fields(section)
      args = []
      last_indent = nil

      section.split("\n").each do |line|
        next if line.strip.empty?
        indent = line.scan(/^\s*/)[0].to_s.size

        if last_indent && indent > last_indent
          args.last.description << line.squeeze(" ")
        else
          param, desc = line.split(" - ")
          args << Argument.new(param.strip, desc.strip) if param && desc
        end

        last_indent = indent
      end

      @signature_fields = args
    end
=end

    # Tags are arbitrary sections designated by a capitalized label and a colon.
    #
    # label   - String name of the tag.
    # section - String of the tag section.
    #
    # Returns nothing.
    def parse_tag(section)
      md = /^([A-Z]\w+)\:\ /m.match(section)
 
      label = md[1]
      desc  = md.post_match

      warn "No label?" unless label

      @tags << [label, desc.strip] if label
    end

  private

    def clean_example(text)
      lines = text.rstrip.lines.to_a
      # remove blank lines from top
      lines.shift while lines.first.strip.empty?
      # determine the indention
      indent = least_indent(lines)
      # remove the indention
      tab = " " * indent
      lines = lines.map{ |line| line.sub(tab, '') }
      # put the lines back together
      lines.join
    end

    # Given a multi-line string, determine the minimum indention.
    def least_indent(lines)
      indents = []
      lines.map do |line|
        next if line.strip.empty?
        if md = /^\ */.match(line)
          indents << md[0].size
        end
      end
      indents.min || 0
    end

  end

end
