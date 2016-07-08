# encoding: UTF-8
module Asciidoctor
# Public: Methods to perform substitutions on lines of AsciiDoc text. This module
# is intented to be mixed-in to Section and Block to provide operations for performing
# the necessary substitutions.
module Substitutors

  SPECIAL_CHARS = {
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;'
  }

  SPECIAL_CHARS_PATTERN = /[#{SPECIAL_CHARS.keys.join}]/

  SUBS = {
    :basic    => [:specialcharacters],
    :normal   => [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements],
    :verbatim => [:specialcharacters, :callouts],
    :title    => [:specialcharacters, :quotes, :replacements, :macros, :attributes, :post_replacements],
    :header   => [:specialcharacters, :attributes],
    # by default, AsciiDoc performs :attributes and :macros on a pass block
    # TODO make this a compliance setting
    :pass     => []
  }

  COMPOSITE_SUBS = {
    :none => [],
    :normal => SUBS[:normal],
    :verbatim => SUBS[:verbatim],
    :specialchars => [:specialcharacters]
  }

  SUB_SYMBOLS = {
    :a => :attributes,
    :m => :macros,
    :n => :normal,
    :p => :post_replacements,
    :q => :quotes,
    :r => :replacements,
    :c => :specialcharacters,
    :v => :verbatim
  }

  SUB_OPTIONS = {
    :block  => COMPOSITE_SUBS.keys + SUBS[:normal] + [:callouts],
    :inline => COMPOSITE_SUBS.keys + SUBS[:normal]
  }

  SUB_HIGHLIGHT = ['coderay', 'pygments']

  # Delimiters and matchers for the passthrough placeholder
  # See http://www.aivosto.com/vbtips/control-characters.html#listabout for characters to use

  # SPA, start of guarded protected area (\u0096)
  PASS_START = "\u0096"

  # EPA, end of guarded protected area (\u0097)
  PASS_END = "\u0097"

  # match placeholder record
  PASS_MATCH = /\u0096(\d+)\u0097/

  # fix placeholder record after syntax highlighting
  PASS_MATCH_HI = /<span[^>]*>\u0096<\/span>[^\d]*(\d+)[^\d]*<span[^>]*>\u0097<\/span>/

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
    if !subs
      return source
    elsif subs == :normal
      subs = SUBS[:normal]
    elsif expand
      if ::Symbol === subs
        subs = COMPOSITE_SUBS[subs] || [subs]
      else
        effective_subs = []
        subs.each do |key|
          if COMPOSITE_SUBS.has_key? key
            effective_subs += COMPOSITE_SUBS[key]
          else
            effective_subs << key
          end
        end

        subs = effective_subs
      end
    end

    return source if subs.empty?

    text = (multiline = ::Array === source) ? source * EOL : source

    if (has_passthroughs = subs.include? :macros)
      text = extract_passthroughs text
      has_passthroughs = false if @passthroughs.empty?
    end

    subs.each do |type|
      case type
      when :specialcharacters
        text = sub_specialchars text
      when :quotes
        text = sub_quotes text
      when :attributes
        text = sub_attributes(text.split EOL) * EOL
      when :replacements
        text = sub_replacements text
      when :macros
        text = sub_macros text
      when :highlight
        text = highlight_source text, (subs.include? :callouts)
      when :callouts
        text = sub_callouts text unless subs.include? :highlight
      when :post_replacements
        text = sub_post_replacements text
      else
        warn %(asciidoctor: WARNING: unknown substitution type #{type})
      end
    end
    text = restore_passthroughs text if has_passthroughs

    multiline ? (text.split EOL) : text
  end

  # Public: Apply normal substitutions.
  #
  # lines  - The lines of text to process. Can be a String or a String Array
  #
  # returns - A String with normal substitutions performed
  def apply_normal_subs(lines)
    apply_subs(::Array === lines ? lines * EOL : lines)
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

  # Internal: Extract the passthrough text from the document for reinsertion after processing.
  #
  # text - The String from which to extract passthrough fragements
  #
  # returns - The text with the passthrough region substituted with placeholders
  def extract_passthroughs(text)
    compat_mode = @document.compat_mode
    text = text.gsub(PassInlineMacroRx) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      preceding = nil

      if (boundary = m[4]).nil_or_empty? # pass:[]
        if m[6] == '\\'
          # NOTE we don't look for nested pass:[] macros
          next m[0][1..-1]
        end

        @passthroughs[pass_key = @passthroughs.size] = {:text => (unescape_brackets m[8]), :subs => (m[7].nil_or_empty? ? [] : (resolve_pass_subs m[7]))}
      else # $$, ++ or +++
        # skip ++ in compat mode, handled as normal quoted text
        if compat_mode && boundary == '++'
          next m[2].nil_or_empty? ?
              %(#{m[1]}#{m[3]}++#{extract_passthroughs m[5]}++) :
              %(#{m[1]}[#{m[2]}]#{m[3]}++#{extract_passthroughs m[5]}++)
        end

        attributes = m[2]

        # fix non-matching group results in Opal under Firefox
        if ::RUBY_ENGINE_OPAL
          attributes = nil if attributes == ''
        end

        escape_count = m[3].size
        content = m[5]
        old_behavior = false

        if attributes
          if escape_count > 0
            # NOTE we don't look for nested unconstrained pass macros
            # must enclose string following next in " for Opal
            next "#{m[1]}[#{attributes}]#{'\\' * (escape_count - 1)}#{boundary}#{m[5]}#{boundary})"
          elsif m[1] == '\\'
            preceding = %([#{attributes}])
            attributes = nil
          else
            if boundary == '++' && (attributes.end_with? 'x-')
              old_behavior = true
              attributes = attributes[0...-2]
            end
            attributes = parse_attributes attributes
          end
        elsif escape_count > 0
          # NOTE we don't look for nested unconstrained pass macros
          # must enclose string following next in " for Opal
          next "#{m[1]}[#{attributes}]#{'\\' * (escape_count - 1)}#{boundary}#{m[5]}#{boundary}"
        end
        subs = (boundary == '+++' ? [] : [:specialcharacters])

        pass_key = @passthroughs.size
        if attributes
          if old_behavior
            @passthroughs[pass_key] = {:text => content, :subs => SUBS[:normal], :type => :monospaced, :attributes => attributes}
          else
            @passthroughs[pass_key] = {:text => content, :subs => subs, :type => :unquoted, :attributes => attributes}
          end
        else
          @passthroughs[pass_key] = {:text => content, :subs => subs}
        end
      end

      %(#{preceding}#{PASS_START}#{pass_key}#{PASS_END})
    } if (text.include? '++') || (text.include? '$$') || (text.include? 'ss:')

    pass_inline_char1, pass_inline_char2, pass_inline_rx = PassInlineRx[compat_mode]
    text = text.gsub(pass_inline_rx) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      preceding = m[1]
      attributes = m[2]
      escape_mark = (m[3].start_with? '\\') ? '\\' : nil
      format_mark = m[4]
      content = m[5]

      # fix non-matching group results in Opal under Firefox
      if ::RUBY_ENGINE_OPAL
        attributes = nil if attributes == ''
      end

      if compat_mode
        old_behavior = true
      else
        if (old_behavior = (attributes && (attributes.end_with? 'x-')))
          attributes = attributes[0...-2]
        end
      end

      if attributes
        if format_mark == '`' && !old_behavior
          # must enclose string following next in " for Opal
          next "#{preceding}[#{attributes}]#{escape_mark}`#{extract_passthroughs content}`"
        end

        if escape_mark
          # honor the escape of the formatting mark (must enclose string following next in " for Opal)
          next "#{preceding}[#{attributes}]#{m[3][1..-1]}"
        elsif preceding == '\\'
          # honor the escape of the attributes
          preceding = %([#{attributes}])
          attributes = nil
        else
          attributes = parse_attributes attributes
        end
      elsif format_mark == '`' && !old_behavior
        # must enclose string following next in " for Opal
        next "#{preceding}#{escape_mark}`#{extract_passthroughs content}`"
      elsif escape_mark
        # honor the escape of the formatting mark (must enclose string following next in " for Opal)
        next "#{preceding}#{m[3][1..-1]}"
      end

      pass_key = @passthroughs.size
      if compat_mode
        @passthroughs[pass_key] = {:text => content, :subs => [:specialcharacters], :attributes => attributes, :type => :monospaced}
      elsif attributes
        if old_behavior
          subs = (format_mark == '`' ? [:specialcharacters] : SUBS[:normal])
          @passthroughs[pass_key] = {:text => content, :subs => subs, :attributes => attributes, :type => :monospaced}
        else
          @passthroughs[pass_key] = {:text => content, :subs => [:specialcharacters], :attributes => attributes, :type => :unquoted}
        end
      else
        @passthroughs[pass_key] = {:text => content, :subs => [:specialcharacters]}
      end

      %(#{preceding}#{PASS_START}#{pass_key}#{PASS_END})
    } if (text.include? pass_inline_char1) || (pass_inline_char2 && (text.include? pass_inline_char2))

    # NOTE we need to do the stem in a subsequent step to allow it to be escaped by the former
    text = text.gsub(StemInlineMacroRx) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      # honor the escape
      if m[0].start_with? '\\'
        next m[0][1..-1]
      end

      if (type = m[1].to_sym) == :stem
        type = ((default_stem_type = document.attributes['stem']).nil_or_empty? ? 'asciimath' : default_stem_type).to_sym
      end
      content = unescape_brackets m[3]
      if m[2].nil_or_empty?
        subs = (@document.basebackend? 'html') ? [:specialcharacters] : []
      else
        subs = resolve_pass_subs m[2]
      end

      @passthroughs[pass_key = @passthroughs.size] = {:text => content, :subs => subs, :type => type}
      %(#{PASS_START}#{pass_key}#{PASS_END})
    } if (text.include? ':') && ((text.include? 'stem:') || (text.include? 'math:'))

    text
  end

  # Internal: Restore the passthrough text by reinserting into the placeholder positions
  #
  # text  - The String text into which to restore the passthrough text
  # outer - A Boolean indicating whether we are in the outer call (default: true)
  #
  # returns The String text with the passthrough text restored
  def restore_passthroughs text, outer = true
    if outer && (@passthroughs.empty? || !text.include?(PASS_START))
      return text
    end

    text.gsub(PASS_MATCH) {
      # NOTE we can't remove entry from map because placeholder may have been duplicated by other substitutions
      pass = @passthroughs[$~[1].to_i]
      subbed_text = (subs = pass[:subs]) ? apply_subs(pass[:text], subs) : pass[:text]
      if (type = pass[:type])
        subbed_text = Inline.new(self, :quoted, subbed_text, :type => type, :attributes => pass[:attributes]).convert
      end
      subbed_text.include?(PASS_START) ? restore_passthroughs(subbed_text, false) : subbed_text
    }
  ensure
    # free memory if in outer call...we don't need these anymore
    @passthroughs.clear if outer
  end

  # Public: Substitute special characters (i.e., encode XML)
  #
  # Special characters are defined in the Asciidoctor::SPECIAL_CHARS Array constant
  #
  # text - The String text to process
  #
  # returns The String text with special characters replaced
  def sub_specialchars(text)
    SUPPORTS_GSUB_RESULT_HASH ?
      text.gsub(SPECIAL_CHARS_PATTERN, SPECIAL_CHARS) :
      text.gsub(SPECIAL_CHARS_PATTERN) { SPECIAL_CHARS[$&] }
  end
  alias :sub_specialcharacters :sub_specialchars

  # Public: Substitute quoted text (includes emphasis, strong, monospaced, etc)
  #
  # text - The String text to process
  #
  # returns The converted String text
  def sub_quotes(text)
    if ::RUBY_ENGINE_OPAL
      result = text
      QUOTE_SUBS[@document.compat_mode].each {|type, scope, pattern|
        result = result.gsub(pattern) { convert_quoted_text $~, type, scope }
      }
    else
      # NOTE interpolation is faster than String#dup
      result = %(#{text})
      # NOTE using gsub! here as an MRI Ruby optimization
      QUOTE_SUBS[@document.compat_mode].each {|type, scope, pattern|
        result.gsub!(pattern) { convert_quoted_text $~, type, scope }
      }
    end

    result
  end

  # Public: Substitute replacement characters (e.g., copyright, trademark, etc)
  #
  # text - The String text to process
  #
  # returns The String text with the replacement characters substituted
  def sub_replacements(text)
    if ::RUBY_ENGINE_OPAL
      result = text
      REPLACEMENTS.each {|pattern, replacement, restore|
        result = result.gsub(pattern) {
          do_replacement $~, replacement, restore
        }
      }
    else
      # NOTE interpolation is faster than String#dup
      result = %(#{text})
      # NOTE Using gsub! as optimization
      REPLACEMENTS.each {|pattern, replacement, restore|
        result.gsub!(pattern) {
          do_replacement $~, replacement, restore
        }
      }
    end

    result
  end

  # Internal: Substitute replacement text for matched location
  #
  # returns The String text with the replacement characters substituted
  def do_replacement m, replacement, restore
    if (matched = m[0]).include? '\\'
      matched.tr '\\', ''
    else
      case restore
      when :none
        replacement
      when :leading
        %(#{m[1]}#{replacement})
      when :bounding
        %(#{m[1]}#{replacement}#{m[2]})
      end
    end
  end

  # Public: Substitute attribute references
  #
  # Attribute references are in the format +{name}+.
  #
  # If an attribute referenced in the line is missing, the line is dropped.
  #
  # text     - The String text to process
  #
  # returns The String text with the attribute references replaced with attribute values
  #--
  # NOTE it's necessary to perform this substitution line-by-line
  # so that a missing key doesn't wipe out the whole block of data
  # when attribute-undefined and/or attribute-missing is drop-line
  def sub_attributes data, opts = {}
    return data if data.nil_or_empty?

    # normalizes data type to an array (string becomes single-element array)
    if (string_data = ::String === data)
      data = [data]
    end

    doc_attrs = @document.attributes
    attribute_missing = nil
    result = []
    data.each do |line|
      reject = false
      reject_if_empty = false
      line = line.gsub(AttributeReferenceRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # escaped attribute, return unescaped
        if m[1] == '\\' || m[4] == '\\'
          %({#{m[2]}})
        elsif !m[3].nil_or_empty?
          offset = (directive = m[3]).length + 1
          expr = m[2][offset..-1]
          case directive
          when 'set'
            args = expr.split(':')
            _, value = Parser.store_attribute(args[0], args[1] || '', @document)
            unless value
              # since this is an assignment, only drop-line applies here (skip and drop imply the same result)
              if doc_attrs.fetch('attribute-undefined', Compliance.attribute_undefined) == 'drop-line'
                reject = true
                break ''
              end
            end
            reject_if_empty = true
            ''
          when 'counter', 'counter2'
            args = expr.split(':')
            val = @document.counter(args[0], args[1])
            if directive == 'counter2'
              reject_if_empty = true
              ''
            else
              val
            end
          else
            # if we get here, our AttributeReference regex is too loose
            warn %(asciidoctor: WARNING: illegal attribute directive: #{m[3]})
            m[0]
          end
        elsif doc_attrs.key?(key = m[2].downcase)
          doc_attrs[key]
        elsif INTRINSIC_ATTRIBUTES.key? key
          INTRINSIC_ATTRIBUTES[key]
        else
          case (attribute_missing ||= (opts[:attribute_missing] || doc_attrs.fetch('attribute-missing', Compliance.attribute_missing)))
          when 'skip'
            m[0]
          when 'drop-line'
            warn %(asciidoctor: WARNING: dropping line containing reference to missing attribute: #{key})
            reject = true
            break ''
          when 'warn'
            warn %(asciidoctor: WARNING: skipping reference to missing attribute: #{key})
            m[0]
          else # 'drop'
            # QUESTION should we warn in this case?
            reject_if_empty = true
            ''
          end
        end
      } if line.include? '{'

      result << line unless reject || (reject_if_empty && line.empty?)
    end

    string_data ? result * EOL : result
  end

  # Public: Substitute inline macros (e.g., links, images, etc)
  #
  # Replace inline macros, which may span multiple lines, in the provided text
  #
  # source - The String text to process
  #
  # returns The converted String text
  def sub_macros(source)
    return source if source.nil_or_empty?

    # some look ahead assertions to cut unnecessary regex calls
    found = {}
    found[:square_bracket] = source.include?('[')
    found[:round_bracket] = source.include?('(')
    found[:colon] = found_colon = source.include?(':')
    found[:macroish] = (found[:square_bracket] && found_colon)
    found[:macroish_short_form] = (found[:square_bracket] && found_colon && source.include?(':['))
    use_link_attrs = @document.attributes.has_key?('linkattrs')
    experimental = @document.attributes.has_key?('experimental')

    # NOTE interpolation is faster than String#dup
    result = %(#{source})

    if experimental
      if found[:macroish_short_form] && (result.include?('kbd:') || result.include?('btn:'))
        result = result.gsub(KbdBtnInlineMacroRx) {
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
              keys = keys.split(KbdDelimiterRx).inject([]) {|c, key|
                if key.end_with?('++')
                  c << key[0..-3].strip
                  c << '+'
                else
                  c << key.strip
                end
                c
              }
            end
            Inline.new(self, :kbd, nil, :attributes => {'keys' => keys}).convert
          elsif captured.start_with?('btn')
            label = unescape_bracketed_text m[1]
            Inline.new(self, :button, label).convert
          end
        }
      end

      if found[:macroish] && result.include?('menu:')
        result = result.gsub(MenuInlineMacroRx) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if (captured = m[0]).start_with? '\\'
            next captured[1..-1]
          end

          menu = m[1]
          items = m[2]

          if !items
            submenus = []
            menuitem = nil
          else
            if (delim = items.include?('&gt;') ? '&gt;' : (items.include?(',') ? ',' : nil))
              submenus = items.split(delim).map {|it| it.strip }
              menuitem = submenus.pop
            else
              submenus = []
              menuitem = items.rstrip
            end
          end

          Inline.new(self, :menu, nil, :attributes => {'menu' => menu, 'submenus' => submenus, 'menuitem' => menuitem}).convert
        }
      end

      if result.include?('"') && result.include?('&gt;')
        result = result.gsub(MenuInlineRx) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if (captured = m[0]).start_with? '\\'
            next captured[1..-1]
          end

          input = m[1]

          menu, *submenus = input.split('&gt;').map {|it| it.strip }
          menuitem = submenus.pop
          Inline.new(self, :menu, nil, :attributes => {'menu' => menu, 'submenus' => submenus, 'menuitem' => menuitem}).convert
        }
      end
    end

    # FIXME this location is somewhat arbitrary, probably need to be able to control ordering
    # TODO this handling needs some cleanup
    if (extensions = @document.extensions) && extensions.inline_macros? # && found[:macroish]
      extensions.inline_macros.each do |extension|
        result = result.gsub(extension.instance.regexp) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if m[0].start_with? '\\'
            next m[0][1..-1]
          end

          target = m[1]
          attributes = if extension.config[:format] == :short
            # if content_model is :attributes, set target to nil and parse attributes
            # maybe if content_model is :text, we should put content into text attribute
            {}
          else
            if extension.config[:content_model] == :attributes
              parse_attributes m[2], (extension.config[:pos_attrs] || []), :sub_input => true, :unescape_input => true
            else
              { 'text' => (unescape_bracketed_text m[2]) }
            end
          end
          extension.process_method[self, target, attributes]
        }
      end
    end

    if found[:macroish] && (result.include?('image:') || result.include?('icon:'))
      # image:filename.png[Alt Text]
      result = result.gsub(ImageInlineMacroRx) {
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
        attrs['alt'] ||= Helpers.basename(target, true).tr('_-', ' ')
        Inline.new(self, :image, nil, :type => type, :target => target, :attributes => attrs).convert
      }
    end

    if found[:macroish_short_form] || found[:round_bracket]
      # indexterm:[Tigers,Big cats]
      # (((Tigers,Big cats)))
      # indexterm2:[Tigers]
      # ((Tigers))
      result = result.gsub(IndextermInlineMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~

        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end

        # fix non-matching group results in Opal under Firefox
        if ::RUBY_ENGINE_OPAL
          m[1] = nil if m[1] == ''
        end

        num_brackets = 0
        text_in_brackets = nil
        unless (macro_name = m[1])
          text_in_brackets = m[3]
          if (text_in_brackets.start_with? '(') && (text_in_brackets.end_with? ')')
            text_in_brackets = text_in_brackets[1...-1]
            num_brackets = 3
          else
            num_brackets = 2
          end
        end

        # non-visible
        if macro_name == 'indexterm' || num_brackets == 3
          if !macro_name
            # (((Tigers,Big cats)))
            terms = split_simple_csv normalize_string(text_in_brackets)
          else
            # indexterm:[Tigers,Big cats]
            terms = split_simple_csv normalize_string(m[2], true)
          end
          @document.register(:indexterms, [*terms])
          Inline.new(self, :indexterm, nil, :attributes => {'terms' => terms}).convert
        # visible
        else
          if !macro_name
            # ((Tigers))
            text = normalize_string text_in_brackets
          else
            # indexterm2:[Tigers]
            text = normalize_string m[2], true
          end
          @document.register(:indexterms, [text])
          Inline.new(self, :indexterm, text, :type => :visible).convert
        end
      }
    end

    if found_colon && (result.include? '://')
      # inline urls, target[text] (optionally prefixed with link: and optionally surrounded by <>)
      result = result.gsub(LinkInlineRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[2].start_with? '\\'
          # must enclose string following next in " for Opal
          next "#{m[1]}#{m[2][1..-1]}#{m[3]}"
        end
        # fix non-matching group results in Opal under Firefox
        if ::RUBY_ENGINE_OPAL
          m[3] = nil if m[3] == ''
        end
        # not a valid macro syntax w/o trailing square brackets
        # we probably shouldn't even get here...our regex is doing too much
        if m[1] == 'link:' && !m[3]
          next m[0]
        end
        prefix = (m[1] != 'link:' ? m[1] : '')
        target = m[2]
        suffix = ''
        unless m[3] || target !~ UriTerminator
          case $~[0]
          when ')'
            # strip the trailing )
            target = target[0..-2]
            suffix = ')'
          when ';'
            # strip the <> around the link
            if prefix.start_with?('&lt;') && target.end_with?('&gt;')
              prefix = prefix[4..-1]
              target = target[0..-5]
            # strip the ); from the end of the link
            elsif target.end_with?(');')
              target = target[0..-3]
              suffix = ');'
            else
              target = target[0..-2]
              suffix = ';'
            end
          when ':'
            # strip the ): from the end of the link
            if target.end_with?('):')
              target = target[0..-3]
              suffix = '):'
            else
              target = target[0..-2]
              suffix = ':'
            end
          end
        end
        @document.register(:links, target)

        link_opts = { :type => :link, :target => target }
        attrs = nil
        #text = m[3] ? sub_attributes(m[3].gsub('\]', ']')) : ''
        if m[3].nil_or_empty?
          text = ''
        else
          if use_link_attrs && (m[3].start_with?('"') || (m[3].include?(',') && m[3].include?('=')))
            attrs = parse_attributes(sub_attributes(m[3].gsub('\]', ']')), [])
            link_opts[:id] = (attrs.delete 'id') if attrs.has_key? 'id'
            text = attrs[1] || ''
          else
            text = sub_attributes(m[3].gsub('\]', ']'))
          end

          # TODO enable in Asciidoctor 1.5.1
          # support pipe-separated text and title
          #unless attrs && (attrs.has_key? 'title')
          #  if text.include? '|'
          #    attrs ||= {}
          #    text, attrs['title'] = text.split '|', 2
          #  end
          #end

          if text.end_with? '^'
            text = text.chop
            if attrs
              attrs['window'] ||= '_blank'
            else
              attrs = {'window' => '_blank'}
            end
          end
        end

        if text.empty?
          if @document.attr? 'hide-uri-scheme'
            text = target.sub UriSniffRx, ''
          else
            text = target
          end

          if attrs
            attrs['role'] = %(bare #{attrs['role']}).chomp ' '
          else
            attrs = {'role' => 'bare'}
          end
        end

        link_opts[:attributes] = attrs if attrs
        %(#{prefix}#{Inline.new(self, :anchor, text, link_opts).convert}#{suffix})
      }
    end

    if found[:macroish] && (result.include? 'link:') || (result.include? 'mailto:')
      # inline link macros, link:target[text]
      result = result.gsub(LinkInlineMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        raw_target = m[1]
        mailto = m[0].start_with?('mailto:')
        target = mailto ? %(mailto:#{raw_target}) : raw_target

        link_opts = { :type => :link, :target => target }
        attrs = nil
        #text = sub_attributes(m[2].gsub('\]', ']'))
        text = if use_link_attrs && (m[2].start_with?('"') || m[2].include?(','))
          attrs = parse_attributes(sub_attributes(m[2].gsub('\]', ']')), [])
          link_opts[:id] = (attrs.delete 'id') if attrs.key? 'id'
          if mailto
            if attrs.key? 2
              target = link_opts[:target] = "#{target}?subject=#{Helpers.encode_uri(attrs[2])}"

              if attrs.key? 3
                target = link_opts[:target] = "#{target}&amp;body=#{Helpers.encode_uri(attrs[3])}"
              end
            end
          end
          attrs[1]
        else
          sub_attributes(m[2].gsub('\]', ']'))
        end

        # QUESTION should a mailto be registered as an e-mail address?
        @document.register(:links, target)

        # TODO enable in Asciidoctor 1.5.1
        # support pipe-separated text and title
        #unless attrs && (attrs.key? 'title')
        #  if text.include? '|'
        #    attrs ||= {}
        #    text, attrs['title'] = text.split '|', 2
        #  end
        #end

        if text.end_with? '^'
          text = text.chop
          if attrs
            attrs['window'] ||= '_blank'
          else
            attrs = {'window' => '_blank'}
          end
        end

        if text.empty?
          # mailto is a special case, already processed
          if mailto
            text = raw_target
          else
            if @document.attr? 'hide-uri-scheme'
              text = raw_target.sub UriSniffRx, ''
            else
              text = raw_target
            end

            if attrs
              attrs['role'] = %(bare #{attrs['role']}).chomp ' '
            else
              attrs = {'role' => 'bare'}
            end
          end
        end

        link_opts[:attributes] = attrs if attrs
        Inline.new(self, :anchor, text, link_opts).convert
      }
    end

    if result.include? '@'
      result = result.gsub(EmailInlineMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        address = m[0]
        if (lead = m[1])
          case lead
          when '\\'
            next address[1..-1]
          else
            next address
          end
        end

        target = %(mailto:#{address})
        # QUESTION should this be registered as an e-mail address?
        @document.register(:links, target)

        Inline.new(self, :anchor, address, :type => :link, :target => target).convert
      }
    end

    if found[:macroish_short_form] && result.include?('footnote')
      result = result.gsub(FootnoteInlineMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        if m[1] == 'footnote'
          id = nil
          # REVIEW it's a dirty job, but somebody's gotta do it
          text = restore_passthroughs(sub_inline_xrefs(sub_inline_anchors(normalize_string m[2], true)), false)
          index = @document.counter('footnote-number')
          @document.register(:footnotes, Document::Footnote.new(index, id, text))
          type = nil
          target = nil
        else
          id, text = m[2].split(',', 2)
          id = id.strip
          # NOTE In Opal, text is set to empty string if comma is missing
          if text.nil_or_empty?
            if (footnote = @document.references[:footnotes].find {|fn| fn.id == id })
              index = footnote.index
              text = footnote.text
            else
              index = nil
              text = id
            end
            target = id
            id = nil
            type = :xref
          else
            # REVIEW it's a dirty job, but somebody's gotta do it
            text = restore_passthroughs(sub_inline_xrefs(sub_inline_anchors(normalize_string text, true)), false)
            index = @document.counter('footnote-number')
            @document.register(:footnotes, Document::Footnote.new(index, id, text))
            type = :ref
            target = nil
          end
        end
        Inline.new(self, :footnote, text, :attributes => {'index' => index}, :id => id, :target => target, :type => type).convert
      }
    end

    sub_inline_xrefs(sub_inline_anchors(result, found), found)
  end

  # Internal: Substitute normal and bibliographic anchors
  def sub_inline_anchors(text, found = nil)
    if (!found || found[:square_bracket]) && text.include?('[[[')
      text = text.gsub(InlineBiblioAnchorRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        id = reftext = m[1]
        Inline.new(self, :anchor, reftext, :type => :bibref, :target => id).convert
      }
    end

    if ((!found || found[:square_bracket]) && text.include?('[[')) ||
        ((!found || found[:macroish]) && text.include?('anchor:'))
      text = text.gsub(InlineAnchorRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        # fix non-matching group results in Opal under Firefox
        if ::RUBY_ENGINE_OPAL
          m[1] = nil if m[1] == ''
          m[2] = nil if m[2] == ''
          m[4] = nil if m[4] == ''
        end
        id = m[1] || m[3]
        reftext = m[2] || m[4] || %([#{id}])
        # enable if we want to allow double quoted values
        #id = id.sub(DoubleQuotedRx, '\2')
        #if reftext
        #  reftext = reftext.sub(DoubleQuotedMultiRx, '\2')
        #else
        #  reftext = "[#{id}]"
        #end
        Inline.new(self, :anchor, reftext, :type => :ref, :target => id).convert
      }
    end

    text
  end

  # Internal: Substitute cross reference links
  def sub_inline_xrefs(text, found = nil)
    if (!found || found[:macroish]) || text.include?('&lt;&lt;')
      text = text.gsub(XrefInlineMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? '\\'
          next m[0][1..-1]
        end
        # fix non-matching group results in Opal under Firefox
        if ::RUBY_ENGINE_OPAL
          m[1] = nil if m[1] == ''
        end
        if m[1]
          id, reftext = m[1].split(',', 2).map {|it| it.strip }
          id = id.sub(DoubleQuotedRx, '\2')
          # NOTE In Opal, reftext is set to empty string if comma is missing
          reftext = if reftext.nil_or_empty?
            nil
          else
            reftext.sub(DoubleQuotedMultiRx, '\2')
          end
        else
          id = m[2]
          reftext = m[3] unless m[3].nil_or_empty?
        end

        if id.include? '#'
          path, fragment = id.split('#')
        # QUESTION perform this check and throw it back if it fails?
        #elsif (start_chr = id.chr) == '.' || start_chr == '/'
        #  next m[0][1..-1]
        else
          path = nil
          fragment = id
        end

        # handles forms: doc#, doc.adoc#, doc#id and doc.adoc#id
        if path
          path = Helpers.rootname(path)
          # the referenced path is this document, or its contents has been included in this document
          if @document.attributes['docname'] == path || @document.references[:includes].include?(path)
            refid = fragment
            path = nil
            target = %(##{fragment})
          else
            refid = fragment ? %(#{path}##{fragment}) : path
            path = "#{@document.attributes['relfileprefix']}#{path}#{@document.attributes.fetch 'outfilesuffix', '.html'}"
            target = fragment ? %(#{path}##{fragment}) : path
          end
        # handles form: id or Section Title
        else
          # resolve fragment as reftext if cannot be resolved as refid and looks like reftext
          if !(@document.references[:ids].has_key? fragment) &&
              ((fragment.include? ' ') || fragment.downcase != fragment) &&
              (resolved_id = RUBY_MIN_VERSION_1_9 ? (@document.references[:ids].key fragment) : (@document.references[:ids].index fragment))
            fragment = resolved_id
          end
          refid = fragment
          target = %(##{fragment})
        end
        Inline.new(self, :anchor, reftext, :type => :xref, :target => target, :attributes => {'path' => path, 'fragment' => fragment, 'refid' => refid}).convert
      }
    end

    text
  end

  # Public: Substitute callout source references
  #
  # text - The String text to process
  #
  # Returns the converted String text
  def sub_callouts(text)
    # FIXME cache this dynamic regex
    callout_rx = (attr? 'line-comment') ? /(?:#{::Regexp.escape(attr 'line-comment')} )?#{CalloutSourceRxt}/ : CalloutSourceRx
    text.gsub(callout_rx) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      # honor the escape
      if m[1] == '\\'
        # we have to do a sub since we aren't sure it's the first char
        next m[0].sub('\\', '')
      end
      Inline.new(self, :callout, m[3], :id => @document.callouts.read_next_id).convert
    }
  end

  # Public: Substitute post replacements
  #
  # text - The String text to process
  #
  # Returns the converted String text
  def sub_post_replacements(text)
    if (@document.attributes.has_key? 'hardbreaks') || (@attributes.has_key? 'hardbreaks-option')
      lines = (text.split EOL)
      return text if lines.size == 1
      last = lines.pop
      lines.map {|line| Inline.new(self, :break, line.rstrip.chomp(LINE_BREAK), :type => :line).convert }.push(last) * EOL
    elsif text.include? '+'
      text.gsub(LineBreakRx) { Inline.new(self, :break, $~[1], :type => :line).convert }
    else
      text
    end
  end

  # Internal: Convert a quoted text region
  #
  # match  - The MatchData for the quoted text region
  # type   - The quoting type (single, double, strong, emphasis, monospaced, etc)
  # scope  - The scope of the quoting (constrained or unconstrained)
  #
  # Returns The converted String text for the quoted text region
  def convert_quoted_text(match, type, scope)
    unescaped_attrs = nil
    if match[0].start_with? '\\'
      if scope == :constrained && !(attrs = match[2]).nil_or_empty?
        unescaped_attrs = %([#{attrs}])
      else
        return match[0][1..-1]
      end
    end

    if scope == :constrained
      if unescaped_attrs
        %(#{unescaped_attrs}#{Inline.new(self, :quoted, match[3], :type => type).convert})
      else
        if (attributes = parse_quoted_text_attributes(match[2]))
          id = attributes.delete 'id'
          type = :unquoted if type == :mark
        else
          id = nil
        end
        %(#{match[1]}#{Inline.new(self, :quoted, match[3], :type => type, :id => id, :attributes => attributes).convert})
      end
    else
      if (attributes = parse_quoted_text_attributes(match[1]))
        id = attributes.delete 'id'
        type = :unquoted if type == :mark
      else
        id = nil
      end
      Inline.new(self, :quoted, match[2], :type => type, :id => id, :attributes => attributes).convert
    end
  end

  # Internal: Parse the attributes that are defined on quoted text
  #
  # str       - A String of unprocessed attributes (space-separated roles or the id/role shorthand syntax)
  #
  # returns nil if str is nil, an empty Hash if str is empty, otherwise a Hash of attributes (role and id only)
  def parse_quoted_text_attributes(str)
    return unless str
    return {} if str.empty?
    str = sub_attributes(str) if str.include?('{')
    str = str.strip
    # for compliance, only consider first positional attribute
    str, _ = str.split(',', 2) if str.include?(',')

    if str.empty?
      {}
    elsif (str.start_with?('.') || str.start_with?('#')) && Compliance.shorthand_property_syntax
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
      attrs['id'] = id if id
      attrs['role'] = roles * ' ' unless roles.empty?
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
    return unless attrline
    return {} if attrline.empty?
    attrline = @document.sub_attributes(attrline) if opts[:sub_input]
    attrline = unescape_bracketed_text(attrline) if opts[:unescape_input]
    block = nil
    if opts.fetch(:sub_result, true)
      # substitutions are only performed on attribute values if block is not nil
      block = self
    end

    if (into = opts[:into])
      AttributeList.new(attrline, block).parse_into(into, posattrs)
    else
      AttributeList.new(attrline, block).parse(posattrs)
    end
  end

  # Internal: Strip bounding whitespace, fold endlines and unescaped closing
  # square brackets from text extracted from brackets
  def unescape_bracketed_text(text)
    return '' if text.empty?
    # FIXME make \] a regex
    text.strip.tr(EOL, ' ').gsub('\]', ']')
  end

  # Internal: Strip bounding whitespace and fold endlines
  def normalize_string str, unescape_brackets = false
    if str.empty?
      ''
    elsif unescape_brackets
      unescape_brackets str.strip.tr(EOL, ' ')
    else
      str.strip.tr(EOL, ' ')
    end
  end

  # Internal: Unescape closing square brackets.
  # Intended for text extracted from square brackets.
  def unescape_brackets str
    # FIXME make \] a regex
    str.empty? ? '' : str.gsub('\]', ']')
  end

  # Internal: Split text formatted as CSV with support
  # for double-quoted values (in which commas are ignored)
  def split_simple_csv str
    if str.empty?
      values = []
    elsif str.include? '"'
      values = []
      current = []
      quote_open = false
      str.each_char do |c|
        case c
        when ','
          if quote_open
            current.push c
          else
            values << current.join.strip
            current = []
          end
        when '"'
          quote_open = !quote_open
        else
          current.push c
        end
      end

      values << current.join.strip
    else
      values = str.split(',').map {|it| it.strip }
    end

    values
  end

  # Internal: Resolve the list of comma-delimited subs against the possible options.
  #
  # subs - A comma-delimited String of substitution aliases
  #
  # returns An Array of Symbols representing the substitution operation
  def resolve_subs subs, type = :block, defaults = nil, subject = nil
    return [] if subs.nil_or_empty?
    candidates = nil
    modifiers_present = SubModifierSniffRx =~ subs
    subs.tr(' ', '').split(',').each do |key|
      modifier_operation = nil
      if modifiers_present
        if (first = key.chr) == '+'
          modifier_operation = :append
          key = key[1..-1]
        elsif first == '-'
          modifier_operation = :remove
          key = key[1..-1]
        elsif key.end_with? '+'
          modifier_operation = :prepend
          key = key.chop
        end
      end
      key = key.to_sym
      # special case to disable callouts for inline subs
      if type == :inline && (key == :verbatim || key == :v)
        resolved_keys = [:specialcharacters]
      elsif COMPOSITE_SUBS.key? key
        resolved_keys = COMPOSITE_SUBS[key]
      elsif type == :inline && key.length == 1 && (SUB_SYMBOLS.key? key)
        resolved_key = SUB_SYMBOLS[key]
        if (candidate = COMPOSITE_SUBS[resolved_key])
          resolved_keys = candidate
        else
          resolved_keys = [resolved_key]
        end
      else
        resolved_keys = [key]
      end

      if modifier_operation
        candidates ||= (defaults ? defaults.dup : [])
        case modifier_operation
        when :append
          candidates += resolved_keys
        when :prepend
          candidates = resolved_keys + candidates
        when :remove
          candidates -= resolved_keys
        end
      else
        candidates ||= []
        candidates += resolved_keys
      end
    end
    # weed out invalid options and remove duplicates (first wins)
    # TODO may be use a set instead?
    resolved = candidates & SUB_OPTIONS[type]
    unless (candidates - resolved).empty?
      invalid = candidates - resolved
      warn %(asciidoctor: WARNING: invalid substitution type#{invalid.size > 1 ? 's' : ''}#{subject ? ' for ' : nil}#{subject}: #{invalid * ', '})
    end
    resolved
  end

  def resolve_block_subs subs, defaults, subject
    resolve_subs subs, :block, defaults, subject
  end

  def resolve_pass_subs subs
    resolve_subs subs, :inline, nil, 'passthrough macro'
  end

  # Public: Highlight the source code if a source highlighter is defined
  # on the document, otherwise return the text unprocessed
  #
  # Callout marks are stripped from the source prior to passing it to the
  # highlighter, then later restored in converted form, so they are not
  # incorrectly processed by the source highlighter.
  #
  # source - the source code String to highlight
  # process_callouts - a Boolean flag indicating whether callout marks should be substituted
  #
  # returns the highlighted source code, if a source highlighter is defined
  # on the document, otherwise the source with verbatim substituions applied
  def highlight_source source, process_callouts, highlighter = nil
    case (highlighter ||= @document.attributes['source-highlighter'])
    when 'coderay'
      unless (highlighter_loaded = defined? ::CodeRay) || @document.attributes['coderay-unavailable']
        if (Helpers.require_library 'coderay', true, :warn).nil?
          # prevent further attempts to load CodeRay
          @document.set_attr 'coderay-unavailable', ''
        else
          highlighter_loaded = true
        end
      end
    when 'pygments'
      unless (highlighter_loaded = defined? ::Pygments) || @document.attributes['pygments-unavailable']
        if (Helpers.require_library 'pygments', 'pygments.rb', :warn).nil?
          # prevent further attempts to load Pygments
          @document.set_attr 'pygments-unavailable', ''
        else
          highlighter_loaded = true
        end
      end
    else
      # unknown highlighting library (something is misconfigured if we arrive here)
      highlighter_loaded = false
    end

    return sub_source source, process_callouts unless highlighter_loaded

    lineno = 0
    callout_on_last = false
    if process_callouts
      callout_marks = {}
      last = -1
      # FIXME cache this dynamic regex
      callout_rx = (attr? 'line-comment') ? /(?:#{::Regexp.escape(attr 'line-comment')} )?#{CalloutExtractRxt}/ : CalloutExtractRx
      # extract callout marks, indexed by line number
      source = source.split(EOL).map {|line|
        lineno = lineno + 1
        line.gsub(callout_rx) {
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
      callout_marks = nil if callout_marks.empty?
    else
      callout_marks = nil
    end

    linenums_mode = nil
    highlight_lines = nil

    case highlighter
    when 'coderay'
      if (linenums_mode = (attr? 'linenums') ? (@document.attributes['coderay-linenums-mode'] || :table).to_sym : nil)
        if attr? 'highlight', nil, false
          highlight_lines = resolve_lines_to_highlight(attr 'highlight', nil, false)
        end
      end
      result = ::CodeRay::Duo[attr('language', :text, false).to_sym, :html, {
          :css => (@document.attributes['coderay-css'] || :class).to_sym,
          :line_numbers => linenums_mode,
          :line_number_anchors => false,
          :highlight_lines => highlight_lines,
          :bold_every => false}].highlight source
    when 'pygments'
      lexer = ::Pygments::Lexer[attr('language', nil, false)] || ::Pygments::Lexer['text']
      opts = { :cssclass => 'pyhl', :classprefix => 'tok-', :nobackground => true }
      unless (@document.attributes['pygments-css'] || 'class') == 'class'
        opts[:noclasses] = true
        opts[:style] = (@document.attributes['pygments-style'] || Stylesheets::DEFAULT_PYGMENTS_STYLE)
      end
      if attr? 'highlight', nil, false
        unless (highlight_lines = resolve_lines_to_highlight(attr 'highlight', nil, false)).empty?
          opts[:hl_lines] = highlight_lines * ' '
        end
      end
      if attr? 'linenums'
        # TODO we could add the line numbers in ourselves instead of having to strip out the junk
        # FIXME move these regular expressions into constants
        if (opts[:linenos] = @document.attributes['pygments-linenums-mode'] || 'table') == 'table'
          linenums_mode = :table
          # NOTE these subs clean out HTML that messes up our styles
          result = lexer.highlight(source, :options => opts).
              sub(/<div class="pyhl">(.*)<\/div>/m, '\1').
              gsub(/<pre[^>]*>(.*?)<\/pre>\s*/m, '\1')
        else
          result = lexer.highlight(source, :options => opts).
              sub(/<div class="pyhl"><pre[^>]*>(.*?)<\/pre><\/div>/m, '\1')
        end
      else
        # nowrap gives us just the highlighted source; won't work when we need linenums though
        opts[:nowrap] = true
        result = lexer.highlight(source, :options => opts)
      end
    end

    # fix passthrough placeholders that got caught up in syntax highlighting
    unless @passthroughs.empty?
      result = result.gsub PASS_MATCH_HI, %(#{PASS_START}\\1#{PASS_END})
    end

    if process_callouts && callout_marks
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
          if callout_on_last && callout_marks.empty?
            # QUESTION when does this happen?
            if (pos = line.index '</pre>')
              tail = line[pos..-1]
              line = %(#{line[0...pos].chomp ' '} )
            else
              # Give conum on final line breathing room if trailing space in source is dropped
              line = %(#{line.chomp ' '} )
            end
          end
          if conums.size == 1
            %(#{line}#{Inline.new(self, :callout, conums[0], :id => @document.callouts.read_next_id).convert }#{tail})
          else
            conums_markup = conums.map {|conum| Inline.new(self, :callout, conum, :id => @document.callouts.read_next_id).convert } * ' '
            %(#{line}#{conums_markup}#{tail})
          end
        else
          line
        end
      } * EOL
    else
      result
    end
  end

  # e.g., highlight="1-5, !2, 10" or highlight=1-5;!2,10
  def resolve_lines_to_highlight spec
    lines = []
    spec.delete(' ').split(DataDelimiterRx).map do |entry|
      negate = false
      if entry.start_with? '!'
        entry = entry[1..-1]
        negate = true
      end
      if entry.include? '-'
        s, e = entry.split '-', 2
        line_nums = (s.to_i..e.to_i).to_a
        if negate
          lines -= line_nums
        else
          lines.concat line_nums
        end
      else
        if negate
          lines.delete entry.to_i
        else
          lines << entry.to_i
        end
      end
    end
    lines.sort.uniq
  end

  # Public: Apply verbatim substitutions on source (for use when highlighting is disabled).
  #
  # source - the source code String on which to apply verbatim substitutions
  # process_callouts - a Boolean flag indicating whether callout marks should be substituted
  #
  # returns the substituted source
  def sub_source source, process_callouts
    return process_callouts ? sub_callouts(sub_specialchars(source)) : sub_specialchars(source)
  end

  # Internal: Lock-in the substitutions for this block
  #
  # Looks for an attribute named "subs". If present, resolves the
  # substitutions and assigns it to the subs property on this block.
  # Otherwise, assigns a set of default substitutions based on the
  # content model of the block.
  #
  # Returns nothing
  def lock_in_subs
    if @default_subs
      default_subs = @default_subs
    else
      case @content_model
      when :simple
        default_subs = SUBS[:normal]
      when :verbatim
        if @context == :listing || (@context == :literal && !(option? 'listparagraph'))
          default_subs = SUBS[:verbatim]
        elsif @context == :verse
          default_subs = SUBS[:normal]
        else
          default_subs = SUBS[:basic]
        end
      when :raw
        if @context == :stem
          default_subs = SUBS[:basic]
        else
          default_subs = SUBS[:pass]
        end
      else
        return
      end
    end

    if (custom_subs = @attributes['subs'])
      @subs = resolve_block_subs custom_subs, default_subs, @context
    else
      @subs = default_subs.dup
    end

    # QUESION delegate this logic to a method?
    if @context == :listing && @style == 'source' && @attributes['language'] &&
        @document.basebackend?('html') && SUB_HIGHLIGHT.include?(@document.attributes['source-highlighter'])
      @subs = @subs.map {|sub| sub == :specialcharacters ? :highlight : sub }
    end
  end
end
end
