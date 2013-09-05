module Asciidoctor
# Public: Methods to perform substitutions on lines of AsciiDoc text. This module
# is intented to be mixed-in to Section and Block to provide operations for performing
# the necessary substitutions.
module Substituters

  SUBS = {
    :basic    => [:specialcharacters],
    :normal   => [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements],
    :verbatim => [:specialcharacters, :callouts],
    :title    => [:specialcharacters, :quotes, :replacements, :macros, :attributes, :post_replacements],
    :header   => [:specialcharacters, :attributes],
    :pass     => [:attributes, :macros]
  }

  COMPOSITE_SUBS = {
    :none => [],
    :normal => SUBS[:normal],
    :verbatim => SUBS[:verbatim]
  }

  SUB_OPTIONS = {
    :block  => COMPOSITE_SUBS.keys + SUBS[:normal] + [:callouts],
    :inline => COMPOSITE_SUBS.keys + SUBS[:normal]
  }

  # Internal: A String Array of passthough (unprocessed) text captured from this block
  attr_reader :passthroughs

  # Public: Apply the specified substitutions to the lines of text
  #
  # source  - The String or String Array of text to process
  # subs    - The substitutions to perform. Can be a Symbol or a Symbol Array (default: :normal)
  # expand -  A Boolean to control whether sub aliases are expanded (default: true)
  #
  # returns Either a String or String Array, whichever matches the type of the first argument
  def apply_subs source, subs = :normal, expand = false
    if subs == :normal
      subs = SUBS[:normal]
    elsif subs.nil?
      return source
    elsif expand
      if subs.is_a? Symbol
        subs = COMPOSITE_SUBS[subs] || [subs]
      else
        effective_subs = []
        subs.each do |key|
          if COMPOSITE_SUBS.has_key? key
            effective_subs.push(*COMPOSITE_SUBS[key])
          else
            effective_subs << key
          end
        end

        subs = effective_subs
      end
    end

    return source if subs.empty?

    multiline = source.is_a?(Array)
    text = multiline ? source.join : source

    if (has_passthroughs = subs.include?(:macros))
      text = extract_passthroughs(text)
    end

    subs.each do |type|
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
      when :highlight
        text = highlight_source(text, subs.include?(:callouts))
      when :callouts
        text = sub_callouts(text) unless subs.include?(:highlight)
      when :post_replacements
        text = sub_post_replacements(text)
      else
        warn "asciidoctor: WARNING: unknown substitution type #{type}"
      end
    end
    text = restore_passthroughs(text) if has_passthroughs

    multiline ? text.lines.entries : text
  end

  # Public: Apply normal substitutions.
  #
  # lines  - The lines of text to process. Can be a String or a String Array
  #
  # returns - A String with normal substitutions performed
  def apply_normal_subs(lines)
    apply_subs lines.is_a?(Array) ? lines.join : lines
  end

  # Public: Apply substitutions for titles.
  #
  # title  - The String title to process
  #
  # returns - A String with title substitutions performed
  def apply_title_subs(title)
    apply_subs title, SUBS[:title]
  end

  # Public: Apply substitutions for header metadata and attribute assignments
  #
  # text    - String containing the text process
  #
  # returns - A String with header substitutions performed
  def apply_header_subs(text)
    apply_subs text, SUBS[:header]
  end

=begin
  # Public: Apply explicit substitutions, if specified, otherwise normal substitutions.
  #
  # lines  - The lines of text to process. Can be a String or a String Array
  #
  # returns - A String with substitutions applied
  def apply_para_subs(lines)
    if (subs = attr('subs', nil, false))
      apply_subs lines.join, resolve_subs(subs)
    else
      apply_subs lines.join
    end
  end

  # Public: Apply substitutions for titles
  #
  # lines  - A String Array containing the lines of text process
  #
  # returns - A String with literal (verbatim) substitutions performed
  def apply_literal_subs(lines)
    if (subs = attr('subs', nil, false))
      apply_subs lines.join, resolve_subs(subs)
    elsif @style == 'source' && @document.attributes['basebackend'] == 'html' &&
      ((highlighter = @document.attributes['source-highlighter']) == 'coderay' ||
      highlighter == 'pygments') && attr?('language')
      highlight_source lines.join, highlighter, callouts
    else
      apply_subs lines.join, SUBS[:verbatim]
    end
  end

  # Public: Apply substitutions for passthrough text
  #
  # lines  - A String Array containing the lines of text process
  #
  # returns - A String with passthrough substitutions performed
  def apply_passthrough_subs(lines)
    if (subs = attr('subs', nil, false))
      subs = resolve_subs(subs)
    else
      subs = SUBS[:pass]
    end
    apply_subs lines.join, subs
  end
=end

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
      elsif m[3].nil? || m[3].empty?
        subs = []
      else
        subs = resolve_pass_subs m[3]
      end

      # TODO move unescaping closing square bracket to an operation
      @passthroughs << {:text => m[2] || m[4].gsub('\]', ']'), :subs => subs}
      index = @passthroughs.size - 1
      "\e#{index}\e"
    } unless !(result.include?('+++') || result.include?('$$') || result.include?('pass:'))

    result.gsub!(REGEXP[:pass_lit]) {
      # alias match for Ruby 1.8.7 compat
      m = $~

      unescaped_attrs = nil
      # honor the escape
      if m[3].start_with? '\\'
        next m[2].nil? ? "#{m[1]}#{m[3][1..-1]}" : "#{m[1]}[#{m[2]}]#{m[3][1..-1]}"
      elsif m[1] == '\\' && !m[2].nil?
        unescaped_attrs = "[#{m[2]}]"
      end

      if unescaped_attrs.nil? && !m[2].nil?
        attributes = parse_attributes(m[2])
      else
        attributes = {}
      end

      @passthroughs << {:text => m[4], :subs => [:specialcharacters], :attributes => attributes, :literal => true}
      index = @passthroughs.size - 1
      "#{unescaped_attrs || m[1]}\e#{index}\e"
    } unless !result.include?('`')

    result
  end

  # Internal: Restore the passthrough text by reinserting into the placeholder positions
  #
  # text - The String text into which to restore the passthrough text
  #
  # returns The String text with the passthrough text restored
  def restore_passthroughs(text)
    return text if @passthroughs.nil? || @passthroughs.empty? || !text.include?("\e")

    text.gsub(REGEXP[:pass_placeholder]) {
      pass = @passthroughs[$1.to_i];
      text = apply_subs(pass[:text], pass.fetch(:subs, []))
      pass[:literal] ? Inline.new(self, :quoted, text, :type => :monospaced, :attributes => pass.fetch(:attributes, {})).render : text
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
  alias :sub_specialchars :sub_specialcharacters

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
  def sub_attributes(data, opts = {})
    return data if data.nil? || data.empty?

    string_data = data.is_a? String
    # normalizes data type to an array (string becomes single-element array)
    lines = string_data ? [data] : data

    result = []
    lines.each {|line|
      reject = false
      line = line.gsub(REGEXP[:attr_ref]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # escaped attribute, return unescaped
        if !m[1].nil? || !m[4].nil?
          "{#{m[2]}}"
        elsif (directive = m[3])
          offset = directive.length + 1
          expr = m[2][offset..-1]
          case directive
          when 'set'
            args = expr.split(':')
            _, value = Lexer::store_attribute(args[0], args[1] || '', @document)
            if value.nil?
              # since this is an assignment, only drop-line applies here (skip and drop imply the same result)
              if @document.attributes.fetch('attribute-undefined', COMPLIANCE[:attribute_undefined]) == 'drop-line'
                Debug.debug { "Undefining attribute: #{key}, line marked for removal" }
                break ''
              end
            end
            ''
          when 'counter', 'counter2'
            args = expr.split(':')
            val = @document.counter(args[0], args[1])
            directive == 'counter2' ? '' : val
          else
            # if we get here, our attr_ref regex is too loose
            warn "asciidoctor: WARNING: illegal attribute directive: #{m[2]}"
            ''
          end
        elsif (key = m[2].downcase) && @document.attributes.has_key?(key)
          @document.attributes[key]
        elsif INTRINSICS.has_key? key
          INTRINSICS[key]
        else
          case (opts[:attribute_missing] || @document.attributes.fetch('attribute-missing', COMPLIANCE[:attribute_missing]))
          when 'skip'
            "{#{key}}"
          when 'drop-line'
            Debug.debug { "Missing attribute: #{key}, line marked for removal" }
            break ''
          else # 'drop'
            ''
          end
        end
      } if line.include? '{'

      result << line unless reject
    }

    string_data ? result.join : result
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
    use_link_attrs = @document.attributes.has_key?('linkattrs')
    experimental = @document.attributes.has_key?('experimental')

    if experimental
      if found[:macroish_short_form] && (result.include?('kbd:') || result.include?('btn:'))
        result.gsub!(REGEXP[:kbd_btn_macro]) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if (captured = m[0]).start_with? '\\'
            next captured[1..-1]
          end

          if captured.start_with?('kbd')
            keys = unescape_bracketed_text m[1]

            if keys == '+'
              keys = ['+']
            else
              # need to use closure to work around lack of negative lookbehind
              keys = keys.split(REGEXP[:kbd_delim]).inject([]) {|c, key|
                if key.end_with?('++')
                  c << key[0..-3].strip
                  c << '+'
                else
                  c << key.strip
                end
                c
              }
            end
            Inline.new(self, :kbd, nil, :attributes => {'keys' => keys}).render
          elsif captured.start_with?('btn')
            label = unescape_bracketed_text m[1]
            Inline.new(self, :button, label).render
          end
        }
      end

      if found[:macroish] && result.include?('menu:')
        result.gsub!(REGEXP[:menu_macro]) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if (captured = m[0]).start_with? '\\'
            next captured[1..-1]
          end

          menu = m[1]
          items = m[2]

          if items.nil?
            submenus = []
            menuitem = nil
          else
            if (delim = items.include?('&gt;') ? '&gt;' : (items.include?(',') ? ',' : nil))
              submenus = items.split(delim).map(&:strip)
              menuitem = submenus.pop
            else
              submenus = []
              menuitem = items.rstrip
            end
          end

          Inline.new(self, :menu, nil, :attributes => {'menu' => menu, 'submenus' => submenus, 'menuitem' => menuitem}).render
        }
      end

      if result.include?('"') && result.include?('&gt;')
        result.gsub!(REGEXP[:menu_inline_macro]) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if (captured = m[0]).start_with? '\\'
            next captured[1..-1]
          end

          input = m[1]

          menu, *submenus = input.split('&gt;').map(&:strip)
          menuitem = submenus.pop
          Inline.new(self, :menu, nil, :attributes => {'menu' => menu, 'submenus' => submenus, 'menuitem' => menuitem}).render
        }
      end
    end

    # FIXME this location is somewhat arbitrary, probably need to be able to control ordering
    # TODO this handling needs some cleanup
    if (extensions = @document.extensions) && extensions.inline_macros? && found[:macroish]
      extensions.load_inline_macro_processors(@document).each do |processor|
        result.gsub!(processor.regexp) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if m[0].start_with? '\\'
            next m[0][1..-1]
          end

          target = m[1]
          if processor.options[:short_form]
            attributes = {}
          else
            posattrs = processor.options.fetch(:pos_attrs, [])
            attributes = parse_attributes(m[2], posattrs, :sub_input => true, :unescape_input => true)
          end
          processor.process self, target, attributes
        }
      end
    end

    if found[:macroish] && (result.include?('image:') || result.include?('icon:'))
      # image:filename.png[Alt Text]
      result.gsub!(REGEXP[:image_macro]) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end

        raw_attrs = unescape_bracketed_text m[2]
        if m[0].start_with? 'icon:'
          type = 'icon'
          posattrs = ['size']
        else
          type = 'image'
          posattrs = ['alt', 'width', 'height']
        end
        target = sub_attributes(m[1])
        unless type == 'icon'
          @document.register(:images, target)
        end
        attrs = parse_attributes(raw_attrs, posattrs)
        if !attrs['alt']
          attrs['alt'] = File.basename(target, File.extname(target))
        end
        Inline.new(self, :image, nil, :type => type, :target => target, :attributes => attrs).render
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

        terms = unescape_bracketed_text(m[1] || m[2]).split(',').map(&:strip)
        @document.register(:indexterms, [*terms])
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
        @document.register(:indexterms, [text])
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
        elsif target.end_with?('):')
          target = target[0..-3]
          suffix = '):'
        end
        @document.register(:links, target)

        attrs = nil
        #text = !m[3].nil? ? sub_attributes(m[3].gsub('\]', ']')) : ''
        if !m[3].to_s.empty?
          if use_link_attrs && (m[3].start_with?('"') || m[3].include?(','))
            attrs = parse_attributes(sub_attributes(m[3].gsub('\]', ']')), [])
            text = attrs[1]
          else
            text = sub_attributes(m[3].gsub('\]', ']'))
          end

          if text.end_with? '^'
            text = text.chop
            attrs ||= {}
            attrs['window'] = '_blank' unless attrs.has_key?('window')
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
        if use_link_attrs && (m[2].start_with?('"') || m[2].include?(','))
          attrs = parse_attributes(sub_attributes(m[2].gsub('\]', ']')), [])
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

        if text.end_with? '^'
          text = text.chop
          attrs ||= {}
          attrs['window'] = '_blank' unless attrs.has_key?('window')
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
          id, text = m[2].split(',', 2).map(&:strip)
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
          id, reftext = m[1].split(',', 2).map(&:strip)
          id.sub!(REGEXP[:dbl_quoted], '\2')
          reftext.sub!(REGEXP[:m_dbl_quoted], '\2') unless reftext.nil?
        else
          id = m[2]
          reftext = !m[3].empty? ? m[3] : nil
        end

        if id.include? '#'
          path, fragment = id.split('#')
        else
          path = nil
          fragment = id
        end

        # handles form: id
        if path.nil?
          refid = fragment
          target = "##{fragment}"
        # handles forms: doc#, doc.adoc#, doc#id and doc.adoc#id
        else
          path = Helpers.rootname(path)
          # the referenced path is this document, or its contents has been included in this document
          if @document.attr?('docname', path) || @document.references[:includes].include?(path)
            refid = fragment
            path = nil
            target = "##{fragment}"
          else
            refid = fragment.nil? ? path : "#{path}##{fragment}"
            path = "#{path}#{@document.attr 'outfilesuffix', '.html'}"
            target = fragment.nil? ? path : "#{path}##{fragment}"
          end
        end
        Inline.new(self, :anchor, reftext, :type => :xref, :target => target, :attributes => {'path' => path, 'fragment' => fragment, 'refid' => refid}).render
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
        id, reftext = m[1].split(',').map(&:strip)
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
      if m[1] == '\\'
        # we have to do a sub since we aren't sure it's the first char
        next m[0].sub('\\', '')
      end
      Inline.new(self, :callout, m[3], :id => @document.callouts.read_next_id).render
    }
  end

  # Public: Substitute post replacements
  #
  # text - The String text to process
  #
  # returns The String with the post replacements rendered using the backend templates
  def sub_post_replacements(text)
    if @document.attributes['hardbreaks']
      lines = text.lines.entries
      return text if lines.size == 1
      last = lines.pop
      lines.map {|line| Inline.new(self, :break, line.rstrip.chomp(LINE_BREAK), :type => :line).render }.push(last) * EOL
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
    unescaped_attrs = nil
    if match[0].start_with? '\\'
      if scope == :constrained && !match[2].nil?
        unescaped_attrs = "[#{match[2]}]"
      else
        return match[0][1..-1]
      end
    end

    if scope == :constrained
      if unescaped_attrs.nil?
        attributes = parse_quoted_text_attributes(match[2])
        id = attributes.nil? ? nil : attributes.delete('id')
        "#{match[1]}#{Inline.new(self, :quoted, match[3], :type => type, :id => id, :attributes => attributes).render}"
      else
        "#{unescaped_attrs}#{Inline.new(self, :quoted, match[3], :type => type, :attributes => {}).render}"
      end
    else
      attributes = parse_quoted_text_attributes(match[1])
      id = attributes.nil? ? nil : attributes.delete('id')
      Inline.new(self, :quoted, match[2], :type => type, :id => id, :attributes => attributes).render
    end
  end

  # Internal: Parse the attributes that are defined on quoted text
  #
  # str       - A String of unprocessed attributes (space-separated roles or the id/role shorthand syntax)
  #
  # returns nil if str is nil, an empty Hash if str is empty, otherwise a Hash of attributes (role and id only)
  def parse_quoted_text_attributes(str)
    return nil if str.nil?
    return {} if str.empty?
    str = sub_attributes(str) if str.include?('{')
    str = str.strip
    # for compliance, only consider first positional attribute
    str, _ = str.split(',', 2) if str.include?(',')

    if str.empty?
      {}
    elsif str.start_with?('.') || str.start_with?('#')
      segments = str.split('#', 2)

      if segments.length > 1
        id, *more_roles = segments[1].split('.')
      else
        id = nil
        more_roles = []
      end

      roles = segments[0].empty? ? [] : segments[0].split('.')
      if roles.length > 1
        roles.shift
      end

      if more_roles.length > 0
        roles.concat more_roles
      end

      attrs = {}
      attrs['id'] = id unless id.nil?
      attrs['role'] = roles.empty? ? nil : (roles * ' ')
      attrs
    else
      {'role' => str}
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
    text.strip.tr(EOL, ' ').gsub('\]', ']')
  end

  # Internal: Resolve the list of comma-delimited subs against the possible options.
  #
  # subs - A comma-delimited String of substitution aliases
  #
  # returns An Array of Symbols representing the substitution operation
  def resolve_subs subs, type = :block, subject = nil
    return [] if subs.nil? || subs.empty?
    candidates = []
    subs.split(',').each do |val|
      key = val.strip.to_sym
      # special case to disable callouts for inline subs
      if key == :verbatim && type == :inline
        candidates << :specialcharacters
      elsif COMPOSITE_SUBS.has_key? key
        candidates.push(*COMPOSITE_SUBS[key])
      else
        candidates << key
      end
    end
    # weed out invalid options and remove duplicates (first wins)
    resolved = candidates & SUB_OPTIONS[type]
    if (invalid = candidates - resolved).size > 0
      warn "asciidoctor: WARNING: invalid substitution type#{invalid.size > 1 ? 's' : ''}#{subject ? ' for ' : nil}#{subject}: #{invalid * ', '}"
    end
    resolved
  end

  def resolve_block_subs subs, subject
    resolve_subs subs, :block, subject
  end

  def resolve_pass_subs subs
    resolve_subs subs, :inline, 'passthrough macro'
  end

  # Public: Highlight the source code if a source highlighter is defined
  # on the document, otherwise return the text unprocessed
  #
  # Callout marks are stripped from the source prior to passing it to the
  # highlighter, then later restored in rendered form, so they are not
  # incorrectly processed by the source highlighter.
  #
  # source - the source code String to highlight
  # sub_callouts - a Boolean flag indicating whether callout marks should be substituted
  #
  # returns the highlighted source code, if a source highlighter is defined
  # on the document, otherwise the unprocessed text
  def highlight_source(source, sub_callouts, highlighter = nil)
    highlighter ||= @document.attributes['source-highlighter']
    Helpers.require_library highlighter, (highlighter == 'pygments' ? 'pygments.rb' : highlighter)
    callout_marks = {}
    lineno = 0
    callout_on_last = false
    if sub_callouts
      last = -1
      # extract callout marks, indexed by line number
      source = source.split(EOL).map {|line|
        lineno = lineno + 1
        line.gsub(REGEXP[:callout_scan]) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if m[1] == '\\'
            m[0].sub('\\', '')
          else
            (callout_marks[lineno] ||= []) << m[3]
            last = lineno
            nil
          end
        }
      } * EOL
      callout_on_last = (last == lineno)
    end

    linenums_mode = nil

    case highlighter
      when 'coderay'
        result = ::CodeRay::Duo[attr('language', 'text').to_sym, :html, {
            :css => @document.attributes.fetch('coderay-css', 'class').to_sym,
            :line_numbers => (linenums_mode = (attr?('linenums') ? @document.attributes.fetch('coderay-linenums-mode', 'table').to_sym : nil)),
            :line_number_anchors => false}].highlight(source)
      when 'pygments'
        lexer = ::Pygments::Lexer[attr('language')]
        if lexer
          opts = { :cssclass => 'pyhl', :classprefix => 'tok-', :nobackground => true }
          opts[:noclasses] = true unless @document.attributes.fetch('pygments-css', 'class') == 'class'
          if attr? 'linenums'
            opts[:linenos] = (linenums_mode = @document.attributes.fetch('pygments-linenums-mode', 'table').to_sym).to_s
          end

          # FIXME stick these regexs into constants
          if linenums_mode == :table
            result = lexer.highlight(source, :options => opts).
                sub(/<div class="pyhl">(.*)<\/div>/m, '\1').
                gsub(/<pre[^>]*>(.*?)<\/pre>\s*/m, '\1')
          else
            result = lexer.highlight(source, :options => opts).
                sub(/<div class="pyhl"><pre[^>]*>(.*?)<\/pre><\/div>/m, '\1')
          end
        else
          result = source
        end
    end

    if !sub_callouts || callout_marks.empty?
      result
    else
      lineno = 0
      reached_code = linenums_mode != :table
      result.split(EOL).map {|line|
        unless reached_code
          unless line.include?('<td class="code">')
            next line
          end
          reached_code = true
        end
        lineno = lineno + 1
        if (conums = callout_marks.delete(lineno))
          tail = nil
          if callout_on_last && callout_marks.empty? && (pos = line.index '</pre>')
            tail = line[pos..-1]
            line = line[0...pos]
          end
          if conums.size == 1
            %(#{line}#{Inline.new(self, :callout, conums.first, :id => @document.callouts.read_next_id).render }#{tail})
          else
            conums_markup = conums.map {|conum| Inline.new(self, :callout, conum, :id => @document.callouts.read_next_id).render } * ' '
            %(#{line}#{conums_markup}#{tail})
          end
        else
          line
        end
      } * EOL
    end
  end
end
end
