# Public: Methods to perform substitutions on lines of AsciiDoc text. This module
# is intented to be mixed-in to Section and Block to provide operations for performing
# the necessary substitutions.
module Asciidoctor
  module Substituters

    COMPOSITE_SUBS = {
      :none => [],
      :normal => [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements],
      :verbatim => [:specialcharacters, :callouts]
    }

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
          puts "asciidoctor: WARNING: unknown substitution type " + type.to_s
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
      apply_subs(lines.join, COMPOSITE_SUBS[:verbatim])
    end

    # Public: Apply substitutions for header metadata and attribute assignments
    #
    # text    - String containing the text process
    #
    # returns - A String with header substitutions performed
    def apply_header_subs(text)
      apply_subs(text, [:specialcharacters, :attributes])
    end

    # Public: Apply substitutions for passthrough text
    #
    # lines  - A String Array containing the lines of text process
    #
    # returns - A String Array with passthrough substitutions performed
    def apply_passthrough_subs(lines)
      apply_subs(lines, [:attributes, :macros])
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
        # TODO warn if we don't recognize the sub
        if m[1] == '$$'
          subs = [:specialcharacters]
        elsif !m[3].nil? && !m[3].empty?
          subs = m[3].split(',').map {|sub| sub.to_sym}
        else
          subs = []
        end
        @passthroughs << {:text => m[2] || m[4].gsub('\]', ']'), :subs => subs}
        "\x0" + (@passthroughs.size - 1).to_s + "\x0"
      } unless !(result.include?('+++') || result.include?('$$') || result.include?('pass:'))

      result.gsub!(REGEXP[:pass_lit]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[2].start_with? '\\'
          next m[1] + m[2][1..-1]
        end
        @passthroughs << {:text => m[3], :subs => [:specialcharacters], :literal => true}
        m[1] + "\x0" + (@passthroughs.size - 1).to_s + "\x0"
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
      REPLACEMENTS.each {|pattern, replacement|
        result.gsub!(pattern, replacement)
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
    # document - The document to which this text belongs, required to access global attributes map
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
          if !$1.empty? || !$3.empty?
            '{' + $2 + '}'
          elsif document.attributes.has_key? $2
            document.attributes[$2]
          elsif INTRINSICS.has_key? $2
            INTRINSICS[$2]
          else
            Asciidoctor.debug 'Missing attribute: ' + $2 + ', line marked for removal'
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

      # inline images, image:target.ext[Alt]
      result.gsub!(REGEXP[:image_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        target = sub_attributes(m[1])
        attrs = parse_attributes(m[2], ['alt', 'width', 'height'])
        if !attrs.has_key?('alt') || attrs['alt'].empty?
          attrs['alt'] = File.basename(target, File.extname(target))
        end
        Inline.new(self, :image, nil, :target => target, :attributes => attrs).render
      } unless !result.include?('image:')

      # inline urls, target[text] (optionally prefixed with link: and optionally surrounded by <>)
      result.gsub!(REGEXP[:link_inline]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[2].start_with? '\\'
          next m[1] + m[2][1..-1] + (m[3] || '')
        # not a valid macro syntax w/o trailing square brackets
        # we probably shouldn't even get here...our regex is doing too much
        elsif m[1] == 'link:' && m[3].nil?
          next m[0]
        end
        prefix = (m[1] != 'link:' ? m[1] : '')
        target = m[2]
        # strip the <> around the link
        if prefix.end_with? '&lt;'
          prefix = prefix[0..-5]
        end
        if target.end_with? '&gt;'
          target = target[0..-5]
        end
        text = !m[3].nil? ? sub_attributes(m[3].gsub('\]', ']')) : ''
        prefix + Inline.new(self, :anchor, (!text.empty? ? text : target), :type => :link, :target => target).render
      } unless !result.include?('http')

      # inline link macros, link:target[text]
      result.gsub!(REGEXP[:link_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        target = m[1]
        text = sub_attributes(m[2].gsub('\]', ']'))
        Inline.new(self, :anchor, (!text.empty? ? text : target), :type => :link, :target => target).render
      } unless !result.include?('link:')

      result.gsub!(REGEXP[:xref_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        if !m[1].nil?
          id, reftext = m[1].split(',')
        else
          id = m[2]
          reftext = !m[3].empty? ? m[3] : nil
        end
        Inline.new(self, :anchor, reftext, :type => :xref, :target => id).render
      }

      result.gsub!(REGEXP[:anchor_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        id, reftext = m[1].split(',')
        if reftext.nil?
          reftext = '[' + id + ']' 
        end
        # NOTE the reftext should also match what's in our references dic
        if !document.references.has_key? id
          Asciidoctor.debug 'Missing reference for anchor ' + id
        end
        Inline.new(self, :anchor, reftext, :type => :ref, :target => id).render
      } unless !result.include?('[[')

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
          next '&lt' + m[1] + '&gt;'
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
      text.gsub(REGEXP[:line_break]) { Inline.new(self, :break, $1, :type => :line).render }
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
        (match[1] || '') + Inline.new(self, :quoted, match[3], :type => type, :attributes => parse_attributes(match[2])).render
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
    def parse_attributes(attrline, posattrs = ['role'])
      return nil if attrline.nil?
      return {} if attrline.empty?
      AttributeList.new(attrline, self).parse(posattrs)
    end
  end
end
