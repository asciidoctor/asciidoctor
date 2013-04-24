module Asciidoctor
# Public: Methods to perform substitutions on lines of AsciiDoc text. This module
# is intented to be mixed-in to Section and Block to provide operations for performing
# the necessary substitutions.
module Substituters

  COMPOSITE_SUBS = {
    :none => [],
    :normal => [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements],
    :verbatim => [:specialcharacters, :callouts]
  }

  SUB_OPTIONS = COMPOSITE_SUBS.keys + COMPOSITE_SUBS[:normal]

  # Internal: A String Array of passthough (unprocessed) text captured from this block
  attr_reader :passthroughs

  # Public: Apply the specified substitutions to the lines of text
  #
  # lines   - The lines of text to process. Can be a String or a String Array 
  # subs    - The substitutions to perform. Can be a Symbol or a Symbol Array (default: COMPOSITE_SUBS[:normal])
  # 
  # returns Either a String or String Array, whichever matches the type of the first argument
  def apply_subs(lines, subs = COMPOSITE_SUBS[:normal])
    if subs.nil?
      subs = []
    elsif subs.is_a? Symbol
      subs = [subs]
    end

    if !subs.empty?
      # QUESTION is this most efficient operation?
      subs = subs.map {|key|
        COMPOSITE_SUBS.has_key?(key) ? COMPOSITE_SUBS[key] : key
      }.flatten
    end

    return lines if subs.empty?

    multiline = lines.is_a?(Array)
    text = multiline ? lines.join : lines

    passthroughs = subs.include?(:macros)
    text = extract_passthroughs(text) if passthroughs
    
    subs.each {|type|
      case type
      when :specialcharacters
        text = sub_specialcharacters(text)
      when :quotes
        text = sub_quotes(text)
      when :attributes
        text = sub_attributes(text.lines.entries).join
      when :replacements
        text = sub_replacements(text)
      when :macros
        text = sub_macros(text)
      when :callouts
        text = sub_callouts(text)
      when :post_replacements
        text = sub_post_replacements(text)
      else
        puts "asciidoctor: WARNING: unknown substitution type #{type}"
      end
    }
    text = restore_passthroughs(text) if passthroughs

    multiline ? text.lines.entries : text
  end

  # Public: Apply normal substitutions.
  #
  # lines  - The lines of text to process. Can be a String or a String Array 
  #
  # returns - A String with normal substitutions performed
  def apply_normal_subs(lines)
    apply_subs(lines.is_a?(Array) ? lines.join : lines)
  end

  # Public: Apply substitutions for titles.
  #
  # title  - The String title to process
  #
  # returns - A String with title substitutions performed
  def apply_title_subs(title)
    apply_subs(title, [:specialcharacters, :quotes, :replacements, :macros, :attributes, :post_replacements])
  end

  # Public: Apply substitutions for titles
  #
  # lines  - A String Array containing the lines of text process
  #
  # returns - A String with literal (verbatim) substitutions performed
  def apply_literal_subs(lines)
    if attr? 'subs'
      apply_subs(lines.join, resolve_subs(attr 'subs'))
    elsif @document.attributes['basebackend'] == 'html' && attr('style') == 'source' &&
      @document.attributes['source-highlighter'] == 'coderay' && attr?('language')
      sub_callouts(highlight_source(lines.join))
    else
      apply_subs(lines.join, COMPOSITE_SUBS[:verbatim])
    end
  end

  # Public: Apply substitutions for header metadata and attribute assignments
  #
  # text    - String containing the text process
  #
  # returns - A String with header substitutions performed
  def apply_header_subs(text)
    apply_subs(text, [:specialcharacters, :attributes])
  end

  # Public: Apply explicit substitutions, if specified, otherwise normal substitutions.
  #
  # lines  - The lines of text to process. Can be a String or a String Array 
  #
  # returns - A String with substitutions applied
  def apply_para_subs(lines)
    if attr? 'subs'
      apply_subs(lines.join, resolve_subs(attr 'subs'))
    else
      apply_subs(lines.join)
    end
  end

  # Public: Apply substitutions for passthrough text
  #
  # lines  - A String Array containing the lines of text process
  #
  # returns - A String with passthrough substitutions performed
  def apply_passthrough_subs(lines)
    if attr? 'subs'
      subs = resolve_subs(attr('subs'))
    else
      subs = [:attributes, :macros]
    end
    apply_subs(lines.join, subs)
  end

  # Internal: Extract the passthrough text from the document for reinsertion after processing.
  #
  # text - The String from which to extract passthrough fragements
  #
  # returns - The text with the passthrough region substituted with placeholders
  def extract_passthroughs(text)
    result = text.dup

    result.gsub!(REGEXP[:pass_macro]) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      # honor the escape
      if m[0].start_with? '\\'
        next m[0][1..-1]
      end

      if m[1] == '$$'
        subs = [:specialcharacters]
      elsif !m[3].nil? && !m[3].empty?
        subs = resolve_subs(m[3])
      else
        subs = []
      end

      # TODO move unescaping closing square bracket to an operation
      @passthroughs << {:text => m[2] || m[4].gsub('\]', ']'), :subs => subs}
      index = @passthroughs.size - 1
      "\x0#{index}\x0"
    } unless !(result.include?('+++') || result.include?('$$') || result.include?('pass:'))

    result.gsub!(REGEXP[:pass_lit]) {
      # alias match for Ruby 1.8.7 compat
      m = $~

      # honor the escape
      if m[2].start_with? '\\'
        next "#{m[1]}#{m[2][1..-1]}"
      end
      
      @passthroughs << {:text => m[3], :subs => [:specialcharacters], :literal => true}
      index = @passthroughs.size - 1
      "#{m[1]}\x0#{index}\x0"
    } unless !result.include?('`')

    result
  end

  # Internal: Restore the passthrough text by reinserting into the placeholder positions
  #
  # text - The String text into which to restore the passthrough text
  #
  # returns The String text with the passthrough text restored
  def restore_passthroughs(text)
    return text if @passthroughs.nil? || @passthroughs.empty? || !text.include?("\x0")
    
    text.gsub(REGEXP[:pass_placeholder]) {
      pass = @passthroughs[$1.to_i];
      text = apply_subs(pass[:text], pass.fetch(:subs, []))
      pass[:literal] ? Inline.new(self, :quoted, text, :type => :monospaced).render : text
    }
  end

  # Public: Substitute special characters (i.e., encode XML)
  #
  # Special characters are defined in the Asciidoctor::SPECIAL_CHARS Array constant
  #
  # text - The String text to process
  #
  # returns The String text with special characters replaced
  def sub_specialcharacters(text)
    # this syntax only available in Ruby 1.9
    #text.gsub(SPECIAL_CHARS_PATTERN, SPECIAL_CHARS)

    text.gsub(SPECIAL_CHARS_PATTERN) { SPECIAL_CHARS[$&] }
  end

  # Public: Substitute quoted text (includes emphasis, strong, monospaced, etc)
  #
  # text - The String text to process
  #
  # returns The String text with quoted text rendered using the backend templates
  def sub_quotes(text)
    result = text.dup

    QUOTE_SUBS.each {|type, scope, pattern|
      result.gsub!(pattern) { transform_quoted_text($~, type, scope) }
    }
    
    result
  end

  # Public: Substitute replacement characters (e.g., copyright, trademark, etc)
  #
  # text - The String text to process
  #
  # returns The String text with the replacement characters substituted
  def sub_replacements(text)
    result = text.dup

    REPLACEMENTS.each {|pattern, replacement, restore|
      result.gsub!(pattern) {
        matched = $&
        head = $1
        tail = $2
        if matched.include?('\\')
          matched.tr('\\', '')
        else
          case restore
          when :none
            replacement
          when :leading
            "#{head}#{replacement}"
          when :bounding
            "#{head}#{replacement}#{tail}" 
          end
        end
      }
    }
    
    result
  end

  # Public: Substitute attribute references
  #
  # Attribute references are in the format {name}.
  #
  # If an attribute referenced in the line is missing, the line is dropped.
  #
  # text     - The String text to process
  #
  # returns The String text with the attribute references replaced with attribute values
  #--
  # NOTE it's necessary to perform this substitution line-by-line
  # so that a missing key doesn't wipe out the whole block of data
  def sub_attributes(data)
    return data if data.nil? || data.empty?

    # normalizes data type to an array (string becomes single-element array)
    lines = Array(data)

    result = lines.map {|line|
      reject = false
      subject = line.dup
      subject.gsub!(REGEXP[:attr_ref]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        key = m[2].downcase
        # escaped attribute
        if !$1.empty? || !$3.empty?
          "{#$2}"
        elsif m[2].start_with?('counter:')
          args = m[2].split(':')
          @document.counter(args[1], args[2])
        elsif m[2].start_with?('counter2:')
          args = m[2].split(':')
          @document.counter(args[1], args[2])
          ''
        elsif document.attributes.has_key? key
          @document.attributes[key]
        elsif INTRINSICS.has_key? key
          INTRINSICS[key]
        else
          Debug.debug { "Missing attribute: #{m[2]}, line marked for removal" }
          reject = true
          break '{undefined}'
        end
      } if subject.include?('{')

      !reject ? subject : nil
    }.compact

    data.is_a?(String) ? result.join : result
  end

  # Public: Substitute inline macros (e.g., links, images, etc)
  #
  # Replace inline macros, which may span multiple lines, in the provided text
  #
  # text - The String text to process
  #
  # returns The String with the inline macros rendered using the backend templates
  def sub_macros(text)
    return text if text.nil? || text.empty?

    result = text.dup

    # some look ahead assertions to cut unnecessary regex calls
    found = {}
    found[:square_bracket] = result.include?('[')
    found[:round_bracket] = result.include?('(')
    found[:colon] = result.include?(':')
    found[:at] = result.include?('@')
    found[:macroish] = (found[:square_bracket] && found[:colon])
    found[:macroish_short_form] = (found[:square_bracket] && found[:colon] && result.include?(':['))
    found[:uri] = (found[:colon] && result.include?('://'))
    link_attrs = @document.attributes.has_key?('linkattrs')

    if found[:macroish] && result.include?('image:')
      # image:filename.png[Alt Text]
      result.gsub!(REGEXP[:image_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        target = sub_attributes(m[1])
        @document.register(:images, target)
        attrs = parse_attributes(unescape_bracketed_text(m[2]), ['alt', 'width', 'height'])
        if !attrs['alt']
          attrs['alt'] = File.basename(target, File.extname(target))
        end
        Inline.new(self, :image, nil, :target => target, :attributes => attrs).render
      }
    end

    if found[:macroish_short_form] || found[:round_bracket]
      # indexterm:[Tigers,Big cats]
      # (((Tigers,Big cats)))
      result.gsub!(REGEXP[:indexterm_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end

        terms = unescape_bracketed_text(m[1] || m[2]).split(REGEXP[:csv_delimiter])
        document.register(:indexterms, [*terms])
        Inline.new(self, :indexterm, text, :attributes => {'terms' => terms}).render
      }
    
      # indexterm2:[Tigers]
      # ((Tigers))
      result.gsub!(REGEXP[:indexterm2_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end

        text = unescape_bracketed_text(m[1] || m[2])
        document.register(:indexterms, [text])
        Inline.new(self, :indexterm, text, :type => :visible).render
      }
    end

    if found[:uri]
      # inline urls, target[text] (optionally prefixed with link: and optionally surrounded by <>)
      result.gsub!(REGEXP[:link_inline]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[2].start_with? '\\'
          next "#{m[1]}#{m[2][1..-1]}#{m[3]}"
        # not a valid macro syntax w/o trailing square brackets
        # we probably shouldn't even get here...our regex is doing too much
        elsif m[1] == 'link:' && m[3].nil?
          next m[0]
        end
        prefix = (m[1] != 'link:' ? m[1] : '')
        target = m[2]
        suffix = ''
        # strip the <> around the link
        if prefix.start_with?('&lt;') && target.end_with?('&gt;')
          prefix = prefix[4..-1]
          target = target[0..-5]
        elsif prefix.start_with?('(') && target.end_with?(')')
          target = target[0..-2]
          suffix = ')'
        end
        @document.register(:links, target)

        attrs = nil
        #text = !m[3].nil? ? sub_attributes(m[3].gsub('\]', ']')) : ''
        if !m[3].to_s.empty?
          if link_attrs && (m[3].start_with?('"') || m[3].include?(','))
            attrs = parse_attributes(sub_attributes(m[3].gsub('\]', ']')))
            text = attrs[1]
          else
            text = sub_attributes(m[3].gsub('\]', ']'))
          end
        else
          text = ''
        end

        "#{prefix}#{Inline.new(self, :anchor, (!text.empty? ? text : target), :type => :link, :target => target, :attributes => attrs).render}#{suffix}"
      }
    end

    if found[:macroish] && (result.include?('link:') || result.include?('mailto:'))
      # inline link macros, link:target[text]
      result.gsub!(REGEXP[:link_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        raw_target = m[1]
        mailto = m[0].start_with?('mailto:')
        target = mailto ? "mailto:#{raw_target}" : raw_target

        attrs = nil
        #text = sub_attributes(m[2].gsub('\]', ']'))
        if link_attrs && (m[2].start_with?('"') || m[2].include?(','))
          attrs = parse_attributes(sub_attributes(m[2].gsub('\]', ']')))
          text = attrs[1]
          if mailto
            if attrs.has_key? 2
              target = "#{target}?subject=#{Helpers.encode_uri(attrs[2])}"

              if attrs.has_key? 3
                target = "#{target}&amp;body=#{Helpers.encode_uri(attrs[3])}"
              end
            end
          end
        else
          text = sub_attributes(m[2].gsub('\]', ']'))
        end
        # QUESTION should a mailto be registered as an e-mail address?
        @document.register(:links, target)

        Inline.new(self, :anchor, (!text.empty? ? text : raw_target), :type => :link, :target => target, :attributes => attrs).render
      }
    end

    if found[:at]
      result.gsub!(REGEXP[:email_inline]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        address = m[0]
        case address[0..0]
        when '\\'
          next address[1..-1]
        when '>', ':'
          next address
        end

        target = "mailto:#{address}"
        # QUESTION should this be registered as an e-mail address?
        @document.register(:links, target)

        Inline.new(self, :anchor, address, :type => :link, :target => target).render
      }
    end

    if found[:macroish_short_form] && result.include?('footnote')
      result.gsub!(REGEXP[:footnote_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        if m[1] == 'footnote'
          # hmmmm
          text = restore_passthroughs(m[2])
          id = nil
          index = @document.counter('footnote-number')
          @document.register(:footnotes, Document::Footnote.new(index, id, text))
          type = nil
          target = nil
        else
          id, text = m[2].split(REGEXP[:csv_delimiter], 2)
          if !text.nil?
            # hmmmm
            text = restore_passthroughs(text)
            index = @document.counter('footnote-number')
            @document.register(:footnotes, Document::Footnote.new(index, id, text))
            type = :ref
            target = nil
          else
            footnote = @document.references[:footnotes].find {|fn| fn.id == id }
            target = id
            id = nil
            index = footnote.index
            text = footnote.text
            type = :xref
          end
        end
        Inline.new(self, :footnote, text, :attributes => {'index' => index}, :id => id, :target => target, :type => type).render
      }
    end

    if found[:macroish] || result.include?('&lt;&lt;')
      result.gsub!(REGEXP[:xref_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        if !m[1].nil?
          id, reftext = m[1].split(REGEXP[:csv_delimiter], 2)
          id.sub!(REGEXP[:dbl_quoted], '\2')
          reftext.sub!(REGEXP[:m_dbl_quoted], '\2') unless reftext.nil?
        else
          id = m[2]
          reftext = !m[3].empty? ? m[3] : nil
        end
        Inline.new(self, :anchor, reftext, :type => :xref, :target => id).render
      }
    end

    if found[:square_bracket] && result.include?('[[[')
      result.gsub!(REGEXP[:biblio_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        id = reftext = m[1]
        Inline.new(self, :anchor, reftext, :type => :bibref, :target => id).render
      }
    end

    if found[:square_bracket] && result.include?('[[')
      result.gsub!(REGEXP[:anchor_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        id, reftext = m[1].split(REGEXP[:csv_delimiter])
        id.sub!(REGEXP[:dbl_quoted], '\2')
        if reftext.nil?
          reftext = "[#{id}]"
        else
          reftext.sub!(REGEXP[:m_dbl_quoted], '\2')
        end
        # NOTE the reftext should also match what's in our references dic
        if !@document.references[:ids].has_key? id
          Debug.debug { "Missing reference for anchor #{id}" }
        end
        Inline.new(self, :anchor, reftext, :type => :ref, :target => id).render
      }
    end

    result
  end

  # Public: Substitute callout references
  #
  # text - The String text to process
  #
  # returns The String with the callout references rendered using the backend templates
  def sub_callouts(text)
    text.gsub(REGEXP[:callout_render]) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      # honor the escape
      if m[0].start_with? '\\'
        next "&lt;#{m[1]}&gt;"
      end
      Inline.new(self, :callout, m[1], :id => document.callouts.read_next_id).render
    }
  end

  # Public: Substitute post replacements
  #
  # text - The String text to process
  #
  # returns The String with the post replacements rendered using the backend templates
  def sub_post_replacements(text)
    if @document.attr? 'hardbreaks'
      lines = text.lines.entries
      return text if lines.size == 1
      last = lines.pop
      "#{lines.map {|line| Inline.new(self, :break, line.rstrip.chomp(LINE_BREAK), :type => :line).render } * "\n"}\n#{last}"
    else
      text.gsub(REGEXP[:line_break]) { Inline.new(self, :break, $1, :type => :line).render }
    end
  end

  # Internal: Transform (render) a quoted text region
  #
  # match  - The MatchData for the quoted text region
  # type   - The quoting type (single, double, strong, emphasis, monospaced, etc)
  # scope  - The scope of the quoting (constrained or unconstrained)
  #
  # returns The rendered text for the quoted text region
  def transform_quoted_text(match, type, scope)
    if match[0].start_with? '\\'
      match[0][1..-1]
    elsif scope == :constrained
      "#{match[1]}#{Inline.new(self, :quoted, match[3], :type => type, :attributes => parse_attributes(match[2])).render}"
    else
      Inline.new(self, :quoted, match[2], :type => type, :attributes => parse_attributes(match[1])).render
    end
  end

  # Internal: Parse the attributes in the attribute line
  #
  # attrline  - A String of unprocessed attributes (key/value pairs)
  # posattrs  - The keys for positional attributes
  #
  # returns nil if attrline is nil, an empty Hash if attrline is empty, otherwise a Hash of parsed attributes
  def parse_attributes(attrline, posattrs = ['role'], opts = {})
    return nil if attrline.nil?
    return {} if attrline.empty?
    attrline = @document.sub_attributes(attrline) if opts[:sub_input]
    attrline = unescape_bracketed_text(attrline) if opts[:unescape_input]
    block = nil
    if opts.fetch(:sub_result, true)
      # substitutions are only performed on attribute values if block is not nil
      block = self
    end
    
    if opts.has_key?(:into)
      AttributeList.new(attrline, block).parse_into(opts[:into], posattrs)
    else
      AttributeList.new(attrline, block).parse(posattrs)
    end
  end

  # Internal: Strip bounding whitespace, fold endlines and unescaped closing
  # square brackets from text extracted from brackets
  def unescape_bracketed_text(text)
    return '' if text.empty?
    text.strip.tr("\n", ' ').gsub('\]', ']')
  end

  # Internal: Resolve the list of comma-delimited subs against the possible options.
  #
  # subs - A comma-delimited String of substitution aliases
  #
  # returns An Array of Symbols representing the substitution operation
  def resolve_subs(subs)
    candidates = subs.split(',').map {|sub| sub.strip.to_sym}
    resolved = candidates & SUB_OPTIONS 
    if (invalid = candidates - resolved).size > 0
      puts "asciidoctor: WARNING: invalid passthrough macro substitution operation#{invalid.size > 1 ? 's' : ''}: #{invalid * ', '}"
    end 
    resolved
  end

  # Public: Highlight the source code if a source highlighter is defined
  # on the document, otherwise return the text unprocessed
  #
  # source - the source code String to highlight
  #
  # returns the highlighted source code, if a source highlighter is defined
  # on the document, otherwise the unprocessed text
  def highlight_source(source)
    Helpers.require_library 'coderay'
    ::CodeRay::Duo[attr('language', 'text').to_sym, :html, {
        :css => @document.attributes.fetch('coderay-css', 'class').to_sym,
        :line_numbers => (attr?('linenums') ? @document.attributes.fetch('coderay-linenums-mode', 'table').to_sym : nil),
        :line_number_anchors => false}].highlight(source).chomp
  end
end
end
