# encoding: UTF-8
module Asciidoctor
# Public: Methods to perform substitutions on lines of AsciiDoc text. This module
# is intented to be mixed-in to Section and Block to provide operations for performing
# the necessary substitutions.
module Substitutors
  SpecialCharsRx = /[<&>]/
  SpecialCharsTr = { '>' => '&gt;', '<' => '&lt;', '&' => '&amp;' }

  # Detects if text is a possible candidate for the quotes substitution.
  QuotedTextSniffRx = { false => /[*_`#^~]/, true => /[*'_+#^~]/ }

  (BASIC_SUBS = [:specialcharacters]).freeze
  (HEADER_SUBS = [:specialcharacters, :attributes]).freeze
  (NORMAL_SUBS = [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements]).freeze
  (NONE_SUBS = []).freeze
  (TITLE_SUBS = [:specialcharacters, :quotes, :replacements, :macros, :attributes, :post_replacements]).freeze
  (REFTEXT_SUBS = [:specialcharacters, :quotes, :replacements]).freeze
  (VERBATIM_SUBS = [:specialcharacters, :callouts]).freeze

  SUB_GROUPS = {
    :none => NONE_SUBS,
    :normal => NORMAL_SUBS,
    :verbatim => VERBATIM_SUBS,
    :specialchars => BASIC_SUBS
  }

  SUB_HINTS = {
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
    :block  => SUB_GROUPS.keys + NORMAL_SUBS + [:callouts],
    :inline => SUB_GROUPS.keys + NORMAL_SUBS
  }

  SUB_HIGHLIGHT = ['coderay', 'pygments']

  if ::RUBY_MIN_VERSION_1_9
    CAN = %(\u0018)
    DEL = %(\u007f)

    # Delimiters and matchers for the passthrough placeholder
    # See http://www.aivosto.com/vbtips/control-characters.html#listabout for characters to use

    # SPA, start of guarded protected area (\u0096)
    PASS_START = %(\u0096)

    # EPA, end of guarded protected area (\u0097)
    PASS_END = %(\u0097)
  else
    CAN = 24.chr
    DEL = 127.chr
    PASS_START = 150.chr
    PASS_END = 151.chr
  end

  # match passthrough slot
  PassSlotRx = /#{PASS_START}(\d+)#{PASS_END}/

  # fix passthrough slot after syntax highlighting
  HighlightedPassSlotRx = %r(<span\b[^>]*>#{PASS_START}</span>[^\d]*(\d+)[^\d]*<span\b[^>]*>#{PASS_END}</span>)

  RS = '\\'

  R_SB = ']'

  ESC_R_SB = '\]'

  PLUS = '+'

  PygmentsWrapperDivRx = %r(<div class="pyhl">(.*)</div>)m
  # NOTE handles all permutations of <pre> wrapper
  # NOTE trailing whitespace appears when pygments-linenums-mode=table; <pre> has style attribute when pygments-css=inline
  PygmentsWrapperPreRx = %r(<pre\b[^>]*?>(.*?)</pre>\s*)m

  # Internal: A String Array of passthough (unprocessed) text captured from this block
  attr_reader :passthroughs

  # Public: Apply the specified substitutions to the text.
  #
  # text  - The String or String Array of text to process; must not be nil.
  # subs  - The substitutions to perform; must be a Symbol Array or nil (default: NORMAL_SUBS).
  #
  # Returns a String or String Array to match the type of the text argument with substitutions applied.
  def apply_subs text, subs = NORMAL_SUBS
    return text if text.empty? || !subs

    if (multiline = ::Array === text)
      #text = text.size > 1 ? (text.join LF) : text[0]
      text = text[1] ? (text.join LF) : text[0]
    end

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
        text = sub_attributes text if text.include? ATTR_REF_HEAD
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
        logger.warn %(unknown substitution type #{type})
      end
    end
    text = restore_passthroughs text if has_passthroughs

    multiline ? (text.split LF, -1) : text
  end

  # Public: Apply normal substitutions.
  #
  # An alias for apply_subs with default remaining arguments.
  #
  # text  - The String text to which to apply normal substitutions
  #
  # Returns the String with normal substitutions applied.
  def apply_normal_subs text
    apply_subs text
  end

  # Public: Apply substitutions for titles.
  #
  # title  - The String title to process
  #
  # returns - A String with title substitutions performed
  def apply_title_subs(title)
    apply_subs title, TITLE_SUBS
  end

  # Public: Apply substitutions for reftext.
  #
  # text - The String to process
  #
  # Returns a String with all substitutions from the reftext substitution group applied
  def apply_reftext_subs text
    apply_subs text, REFTEXT_SUBS
  end

  # Public: Apply substitutions for header metadata and attribute assignments
  #
  # text    - String containing the text process
  #
  # returns - A String with header substitutions performed
  def apply_header_subs(text)
    apply_subs text, HEADER_SUBS
  end

  # Internal: Extract the passthrough text from the document for reinsertion after processing.
  #
  # text - The String from which to extract passthrough fragements
  #
  # returns - The text with the passthrough region substituted with placeholders
  def extract_passthroughs(text)
    compat_mode = @document.compat_mode
    text = text.gsub(InlinePassMacroRx) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      preceding = nil

      if (boundary = m[4]) # $$, ++, or +++
        # skip ++ in compat mode, handled as normal quoted text
        if compat_mode && boundary == '++'
          next m[2] ?
              %(#{m[1]}[#{m[2]}]#{m[3]}++#{extract_passthroughs m[5]}++) :
              %(#{m[1]}#{m[3]}++#{extract_passthroughs m[5]}++)
        end

        attributes = m[2]
        escape_count = m[3].length
        content = m[5]
        old_behavior = false

        if attributes
          if escape_count > 0
            # NOTE we don't look for nested unconstrained pass macros
            next %(#{m[1]}[#{attributes}]#{RS * (escape_count - 1)}#{boundary}#{m[5]}#{boundary})
          elsif m[1] == RS
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
          next %(#{RS * (escape_count - 1)}#{boundary}#{m[5]}#{boundary})
        end
        subs = (boundary == '+++' ? [] : BASIC_SUBS)

        pass_key = @passthroughs.size
        if attributes
          if old_behavior
            @passthroughs[pass_key] = {:text => content, :subs => NORMAL_SUBS, :type => :monospaced, :attributes => attributes}
          else
            @passthroughs[pass_key] = {:text => content, :subs => subs, :type => :unquoted, :attributes => attributes}
          end
        else
          @passthroughs[pass_key] = {:text => content, :subs => subs}
        end
      else # pass:[]
        if m[6] == RS
          # NOTE we don't look for nested pass:[] macros
          next m[0][1..-1]
        end

        @passthroughs[pass_key = @passthroughs.size] = {:text => (unescape_brackets m[8]), :subs => (m[7] ? (resolve_pass_subs m[7]) : nil)}
      end

      %(#{preceding}#{PASS_START}#{pass_key}#{PASS_END})
    } if (text.include? '++') || (text.include? '$$') || (text.include? 'ss:')

    pass_inline_char1, pass_inline_char2, pass_inline_rx = InlinePassRx[compat_mode]
    text = text.gsub(pass_inline_rx) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      preceding = m[1]
      attributes = m[2]
      escape_mark = RS if m[3].start_with? RS
      format_mark = m[4]
      content = m[5]

      if compat_mode
        old_behavior = true
      else
        if (old_behavior = (attributes && (attributes.end_with? 'x-')))
          attributes = attributes[0...-2]
        end
      end

      if attributes
        if format_mark == '`' && !old_behavior
          # extract nested single-plus passthrough; otherwise return unprocessed
          next (extract_inner_passthrough content, %(#{preceding}[#{attributes}]#{escape_mark}), attributes)
        end

        if escape_mark
          # honor the escape of the formatting mark
          next %(#{preceding}[#{attributes}]#{m[3][1..-1]})
        elsif preceding == RS
          # honor the escape of the attributes
          preceding = %([#{attributes}])
          attributes = nil
        else
          attributes = parse_attributes attributes
        end
      elsif format_mark == '`' && !old_behavior
        # extract nested single-plus passthrough; otherwise return unprocessed
        next (extract_inner_passthrough content, %(#{preceding}#{escape_mark}))
      elsif escape_mark
        # honor the escape of the formatting mark
        next %(#{preceding}#{m[3][1..-1]})
      end

      pass_key = @passthroughs.size
      if compat_mode
        @passthroughs[pass_key] = {:text => content, :subs => BASIC_SUBS, :attributes => attributes, :type => :monospaced}
      elsif attributes
        if old_behavior
          subs = (format_mark == '`' ? BASIC_SUBS : NORMAL_SUBS)
          @passthroughs[pass_key] = {:text => content, :subs => subs, :attributes => attributes, :type => :monospaced}
        else
          @passthroughs[pass_key] = {:text => content, :subs => BASIC_SUBS, :attributes => attributes, :type => :unquoted}
        end
      else
        @passthroughs[pass_key] = {:text => content, :subs => BASIC_SUBS}
      end

      %(#{preceding}#{PASS_START}#{pass_key}#{PASS_END})
    } if (text.include? pass_inline_char1) || (pass_inline_char2 && (text.include? pass_inline_char2))

    # NOTE we need to do the stem in a subsequent step to allow it to be escaped by the former
    text = text.gsub(InlineStemMacroRx) {
      # alias match for Ruby 1.8.7 compat
      m = $~
      # honor the escape
      if m[0].start_with? RS
        next m[0][1..-1]
      end

      if (type = m[1].to_sym) == :stem
        type = STEM_TYPE_ALIASES[@document.attributes['stem']].to_sym
      end
      content = unescape_brackets m[3]
      subs = m[2] ? (resolve_pass_subs m[2]) : ((@document.basebackend? 'html') ? BASIC_SUBS : nil)
      @passthroughs[pass_key = @passthroughs.size] = {:text => content, :subs => subs, :type => type}
      %(#{PASS_START}#{pass_key}#{PASS_END})
    } if (text.include? ':') && ((text.include? 'stem:') || (text.include? 'math:'))

    text
  end

  def extract_inner_passthrough text, pre, attributes = nil
    if (text.end_with? '+') && (text.start_with? '+', '\+') && SinglePlusInlinePassRx =~ text
      if $1
        %(#{pre}`+#{$2}+`)
      else
        @passthroughs[pass_key = @passthroughs.size] = attributes ?
            { :text => $2, :subs => BASIC_SUBS, :attributes => attributes, :type => :unquoted } :
            { :text => $2, :subs => BASIC_SUBS }
        %(#{pre}`#{PASS_START}#{pass_key}#{PASS_END}`)
      end
    else
      %(#{pre}`#{text}`)
    end
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

    text.gsub(PassSlotRx) {
      # NOTE we can't remove entry from map because placeholder may have been duplicated by other substitutions
      pass = @passthroughs[$1.to_i]
      subbed_text = apply_subs(pass[:text], pass[:subs])
      if (type = pass[:type])
        subbed_text = Inline.new(self, :quoted, subbed_text, :type => type, :attributes => pass[:attributes]).convert
      end
      subbed_text.include?(PASS_START) ? restore_passthroughs(subbed_text, false) : subbed_text
    }
  ensure
    # free memory if in outer call...we don't need these anymore
    @passthroughs.clear if outer
  end


  if RUBY_ENGINE == 'opal'
    def sub_quotes text
      if QuotedTextSniffRx[compat = @document.compat_mode].match? text
        QUOTE_SUBS[compat].each do |type, scope, pattern|
          text = text.gsub(pattern) { convert_quoted_text $~, type, scope }
        end
      end
      text
    end

    def sub_replacements text
      if ReplaceableTextRx.match? text
        REPLACEMENTS.each do |pattern, replacement, restore|
          text = text.gsub(pattern) { do_replacement $~, replacement, restore }
        end
      end
      text
    end
  else
    # Public: Substitute quoted text (includes emphasis, strong, monospaced, etc)
    #
    # text - The String text to process
    #
    # returns The converted String text
    def sub_quotes text
      if QuotedTextSniffRx[compat = @document.compat_mode].match? text
        # NOTE interpolation is faster than String#dup
        text = %(#{text})
        QUOTE_SUBS[compat].each do |type, scope, pattern|
          # NOTE using gsub! here as an MRI Ruby optimization
          text.gsub!(pattern) { convert_quoted_text $~, type, scope }
        end
      end
      text
    end

    # Public: Substitute replacement characters (e.g., copyright, trademark, etc)
    #
    # text - The String text to process
    #
    # returns The String text with the replacement characters substituted
    def sub_replacements text
      if ReplaceableTextRx.match? text
        # NOTE interpolation is faster than String#dup
        text = %(#{text})
        REPLACEMENTS.each do |pattern, replacement, restore|
          # NOTE Using gsub! as optimization
          text.gsub!(pattern) { do_replacement $~, replacement, restore }
        end
      end
      text
    end
  end

  # Public: Substitute special characters (i.e., encode XML)
  #
  # The special characters <, &, and > get replaced with &lt;,
  # &amp;, and &gt;, respectively.
  #
  # text - The String text to process.
  #
  # returns The String text with special characters replaced.
  if ::RUBY_MIN_VERSION_1_9
    def sub_specialchars text
      (text.include? '<') || (text.include? '&') || (text.include? '>') ? (text.gsub SpecialCharsRx, SpecialCharsTr) : text
    end
  else
    def sub_specialchars text
      (text.include? '<') || (text.include? '&') || (text.include? '>') ? (text.gsub(SpecialCharsRx) { SpecialCharsTr[$&] }) : text
    end
  end
  alias sub_specialcharacters sub_specialchars

  # Internal: Substitute replacement text for matched location
  #
  # returns The String text with the replacement characters substituted
  def do_replacement m, replacement, restore
    if (captured = m[0]).include? RS
      # we have to use sub since we aren't sure it's the first char
      captured.sub RS, ''
    else
      case restore
      when :none
        replacement
      when :bounding
        %(#{m[1]}#{replacement}#{m[2]})
      else # :leading
        %(#{m[1]}#{replacement})
      end
    end
  end

  # Public: Substitutes attribute references in the specified text
  #
  # Attribute references are in the format +{name}+.
  #
  # If an attribute referenced in the line is missing or undefined, the line may be dropped
  # based on the attribute-missing or attribute-undefined setting, respectively.
  #
  # text - The String text to process
  # opts - A Hash of options to control processing: (default: {})
  #        * :attribute_missing controls how to handle a missing attribute
  #
  # Returns the [String] text with the attribute references replaced with resolved values
  def sub_attributes text, opts = {}
    doc_attrs = @document.attributes
    drop = drop_line = drop_empty_line = attribute_undefined = attribute_missing = nil
    result = text.gsub AttributeReferenceRx do
      # escaped attribute, return unescaped
      if $1 == RS || $4 == RS
        %({#{$2}})
      elsif $3
        case (args = $2.split ':', 3).shift
        when 'set'
          _, value = Parser.store_attribute args[0], args[1] || '', @document
          # NOTE since this is an assignment, only drop-line applies here (skip and drop imply the same result)
          if value || (attribute_undefined ||= doc_attrs['attribute-undefined'] || Compliance.attribute_undefined) != 'drop-line'
            drop = drop_empty_line = DEL
          else
            drop = drop_line = CAN
          end
        when 'counter2'
          @document.counter(*args)
          drop = drop_empty_line = DEL
        else # 'counter'
          @document.counter(*args)
        end
      elsif doc_attrs.key?(key = $2.downcase)
        doc_attrs[key]
      elsif (value = INTRINSIC_ATTRIBUTES[key])
        value
      else
        case (attribute_missing ||= opts[:attribute_missing] || doc_attrs['attribute-missing'] || Compliance.attribute_missing)
        when 'drop'
          drop = drop_empty_line = DEL
        when 'drop-line'
          logger.warn %(dropping line containing reference to missing attribute: #{key})
          drop = drop_line = CAN
        when 'warn'
          logger.warn %(skipping reference to missing attribute: #{key})
          $&
        else # 'skip'
          $&
        end
      end
    end

    if drop
      # drop lines from result
      if drop_empty_line
        lines = (result.tr_s DEL, DEL).split LF, -1
        if drop_line
          (lines.reject {|line| line == DEL || line == CAN || (line.start_with? CAN) || (line.include? CAN) }.join LF).delete DEL
        else
          (lines.reject {|line| line == DEL }.join LF).delete DEL
        end
      elsif result.include? LF
        (result.split LF, -1).reject {|line| line == CAN || (line.start_with? CAN) || (line.include? CAN) }.join LF
      else
        ''
      end
    else
      result
    end
  end

  # Public: Substitute inline macros (e.g., links, images, etc)
  #
  # Replace inline macros, which may span multiple lines, in the provided text
  #
  # source - The String text to process
  #
  # returns The converted String text
  def sub_macros(source)
    #return source if source.nil_or_empty?
    # some look ahead assertions to cut unnecessary regex calls
    found = {}
    found_square_bracket = found[:square_bracket] = (source.include? '[')
    found_colon = source.include? ':'
    found_macroish = found[:macroish] = found_square_bracket && found_colon
    found_macroish_short = found_macroish && (source.include? ':[')
    doc_attrs = (doc = @document).attributes
    result = source

    if doc_attrs.key? 'experimental'
      if found_macroish_short && ((result.include? 'kbd:') || (result.include? 'btn:'))
        result = result.gsub(InlineKbdBtnMacroRx) {
          # honor the escape
          if $1
            $&.slice 1, $&.length
          elsif $2 == 'kbd'
            if (keys = $3.strip).include? R_SB
              keys = keys.gsub ESC_R_SB, R_SB
            end
            if keys.length > 1 && (delim_idx = (delim_idx = keys.index ',', 1) ?
                [delim_idx, (keys.index '+', 1)].compact.min : (keys.index '+', 1))
              delim = keys.slice delim_idx, 1
              # NOTE handle special case where keys ends with delimiter (e.g., Ctrl++ or Ctrl,,)
              if keys.end_with? delim
                keys = (keys.chop.split delim, -1).map {|key| key.strip }
                keys[-1] = %(#{keys[-1]}#{delim})
              else
                keys = keys.split(delim).map {|key| key.strip }
              end
            else
              keys = [keys]
            end
            (Inline.new self, :kbd, nil, :attributes => { 'keys' => keys }).convert
          else # $2 == 'btn'
            (Inline.new self, :button, (unescape_bracketed_text $3)).convert
          end
        }
      end

      if found_macroish && (result.include? 'menu:')
        result = result.gsub(InlineMenuMacroRx) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if (captured = m[0]).start_with? RS
            next captured[1..-1]
          end

          menu, items = m[1], m[2]

          if items
            items = items.gsub ESC_R_SB, R_SB if items.include? R_SB
            if (delim = items.include?('&gt;') ? '&gt;' : (items.include?(',') ? ',' : nil))
              submenus = items.split(delim).map {|it| it.strip }
              menuitem = submenus.pop
            else
              submenus, menuitem = [], items.rstrip
            end
          else
            submenus, menuitem = [], nil
          end

          Inline.new(self, :menu, nil, :attributes => {'menu' => menu, 'submenus' => submenus, 'menuitem' => menuitem}).convert
        }
      end

      if (result.include? '"') && (result.include? '&gt;')
        result = result.gsub(InlineMenuRx) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if (captured = m[0]).start_with? RS
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
    if (extensions = doc.extensions) && extensions.inline_macros? # && found_macroish
      extensions.inline_macros.each do |extension|
        result = result.gsub(extension.instance.regexp) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if m[0].start_with? RS
            next m[0][1..-1]
          end

          if (m.names rescue []).empty?
            target, content, extconf = m[1], m[2], extension.config
          else
            target, content, extconf = (m[:target] rescue nil), (m[:content] rescue nil), extension.config
          end
          attributes = (attributes = extconf[:default_attrs]) ? attributes.dup : {}
          if content.nil_or_empty?
            attributes['text'] = content if content && extconf[:content_model] != :attributes
          else
            content = unescape_bracketed_text content
            if extconf[:content_model] == :attributes
              # QUESTION should we store the text in the _text key?
              # QUESTION why is the sub_result option false? why isn't the unescape_input option true?
              parse_attributes content, extconf[:pos_attrs] || [], :sub_result => false, :into => attributes
            else
              attributes['text'] = content
            end
          end
          # NOTE use content if target is not set (short form only); deprecated - remove in 1.6.0
          replacement = extension.process_method[self, target || content, attributes]
          Inline === replacement ? replacement.convert : replacement
        }
      end
    end

    if found_macroish && ((result.include? 'image:') || (result.include? 'icon:'))
      # image:filename.png[Alt Text]
      result = result.gsub(InlineImageMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if (captured = $&).start_with? RS
          next captured[1..-1]
        end

        if captured.start_with? 'icon:'
          type, posattrs = 'icon', ['size']
        else
          type, posattrs = 'image', ['alt', 'width', 'height']
        end
        if (target = m[1]).include? ATTR_REF_HEAD
          # TODO remove this special case once titles use normal substitution order
          target = sub_attributes target
        end
        doc.register(:images, target) unless type == 'icon'
        attrs = parse_attributes(m[2], posattrs, :unescape_input => true)
        attrs['alt'] ||= (attrs['default-alt'] = Helpers.basename(target, true).tr('_-', ' '))
        Inline.new(self, :image, nil, :type => type, :target => target, :attributes => attrs).convert
      }
    end

    if ((result.include? '((') && (result.include? '))')) || (found_macroish_short && (result.include? 'dexterm'))
      # (((Tigers,Big cats)))
      # indexterm:[Tigers,Big cats]
      # ((Tigers))
      # indexterm2:[Tigers]
      result = result.gsub(InlineIndextermMacroRx) {
        case $1
        when 'indexterm'
          text = $2
          # honor the escape
          if (m0 = $&).start_with? RS
            next m0.slice 1, m0.length
          end
          # indexterm:[Tigers,Big cats]
          terms = split_simple_csv normalize_string text, true
          doc.register :indexterms, terms
          (Inline.new self, :indexterm, nil, :attributes => { 'terms' => terms }).convert
        when 'indexterm2'
          text = $2
          # honor the escape
          if (m0 = $&).start_with? RS
            next m0.slice 1, m0.length
          end
          # indexterm2:[Tigers]
          term = normalize_string text, true
          doc.register :indexterms, [term]
          (Inline.new self, :indexterm, term, :type => :visible).convert
        else
          text = $3
          # honor the escape
          if (m0 = $&).start_with? RS
            # escape concealed index term, but process nested flow index term
            if (text.start_with? '(') && (text.end_with? ')')
              text = text.slice 1, text.length - 2
              visible, before, after = true, '(', ')'
            else
              next m0.slice 1, m0.length
            end
          else
            visible = true
            if text.start_with? '('
              if text.end_with? ')'
                text, visible = (text.slice 1, text.length - 2), false
              else
                text, before, after = (text.slice 1, text.length), '(', ''
              end
            elsif text.end_with? ')'
              text, before, after = (text.slice 0, text.length - 1), '', ')'
            end
          end
          if visible
            # ((Tigers))
            term = normalize_string text
            doc.register :indexterms, [term]
            result = (Inline.new self, :indexterm, term, :type => :visible).convert
          else
            # (((Tigers,Big cats)))
            terms = split_simple_csv(normalize_string text)
            doc.register :indexterms, terms
            result = (Inline.new self, :indexterm, nil, :attributes => { 'terms' => terms }).convert
          end
          before ? %(#{before}#{result}#{after}) : result
        end
      }
    end

    if found_colon && (result.include? '://')
      # inline urls, target[text] (optionally prefixed with link: and optionally surrounded by <>)
      result = result.gsub(InlineLinkRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[2].start_with? RS
          next %(#{m[1]}#{m[2][1..-1]}#{m[3]})
        end
        # NOTE if text is non-nil, then we've matched a formal macro (i.e., trailing square brackets)
        prefix, target, text, suffix = m[1], m[2], (macro = m[3]) || '', ''
        if prefix == 'link:'
          if macro
            prefix = ''
          else
            # invalid macro syntax (link: prefix w/o trailing square brackets)
            # we probably shouldn't even get here...our regex is doing too much
            next m[0]
          end
        end
        unless macro || UriTerminatorRx !~ target
          case $&
          when ')'
            # strip trailing )
            target = target.chop
            suffix = ')'
          when ';'
            # strip <> around URI
            if prefix.start_with?('&lt;') && target.end_with?('&gt;')
              prefix = prefix[4..-1]
              target = target[0...-4]
            # strip trailing ;
            # check for trailing );
            elsif (target = target.chop).end_with?(')')
              target = target.chop
              suffix = ');'
            else
              suffix = ';'
            end
          when ':'
            # strip trailing :
            # check for trailing ):
            if (target = target.chop).end_with?(')')
              target = target.chop
              suffix = '):'
            else
              suffix = ':'
            end
          end
          # NOTE handle case when remaining target is a URI scheme (e.g., http://)
          return m[0] if target.end_with? '://'
        end

        attrs, link_opts = nil, { :type => :link }
        unless text.empty?
          text = text.gsub ESC_R_SB, R_SB if text.include? R_SB
          if !doc.compat_mode && (text.include? '=')
            text = (attrs = (AttributeList.new text, self).parse)[1] || ''
            link_opts[:id] = attrs.delete 'id' if attrs.key? 'id'
          end

          # TODO enable in Asciidoctor 1.6.x
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
              attrs = { 'window' => '_blank' }
            end
          end
        end

        if text.empty?
          text = (doc_attrs.key? 'hide-uri-scheme') ? (target.sub UriSniffRx, '') : target
          if attrs
            attrs['role'] = (attrs.key? 'role') ? %(bare #{attrs['role']}) : 'bare'
          else
            attrs = { 'role' => 'bare' }
          end
        end

        doc.register :links, (link_opts[:target] = target)
        link_opts[:attributes] = attrs if attrs
        %(#{prefix}#{Inline.new(self, :anchor, text, link_opts).convert}#{suffix})
      }
    end

    if found_macroish && ((result.include? 'link:') || (result.include? 'mailto:'))
      # inline link macros, link:target[text]
      result = result.gsub(InlineLinkMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? RS
          next m[0][1..-1]
        end
        target = (mailto = m[1]) ? %(mailto:#{m[2]}) : m[2]
        attrs, link_opts = nil, { :type => :link }
        unless (text = m[3]).empty?
          text = text.gsub ESC_R_SB, R_SB if text.include? R_SB
          if mailto
            if !doc.compat_mode && (text.include? ',')
              text = (attrs = (AttributeList.new text, self).parse)[1] || ''
              link_opts[:id] = attrs.delete 'id' if attrs.key? 'id'
              if attrs.key? 2
                if attrs.key? 3
                  target = %(#{target}?subject=#{Helpers.uri_encode attrs[2]}&amp;body=#{Helpers.uri_encode attrs[3]})
                else
                  target = %(#{target}?subject=#{Helpers.uri_encode attrs[2]})
                end
              end
            end
          elsif !doc.compat_mode && (text.include? '=')
            text = (attrs = (AttributeList.new text, self).parse)[1] || ''
            link_opts[:id] = attrs.delete 'id' if attrs.key? 'id'
          end

          # TODO enable in Asciidoctor 1.6.x
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
              attrs = { 'window' => '_blank' }
            end
          end
        end

        if text.empty?
          # mailto is a special case, already processed
          if mailto
            text = m[2]
          else
            text = (doc_attrs.key? 'hide-uri-scheme') ? (target.sub UriSniffRx, '') : target
            if attrs
              attrs['role'] = (attrs.key? 'role') ? %(bare #{attrs['role']}) : 'bare'
            else
              attrs = { 'role' => 'bare' }
            end
          end
        end

        # QUESTION should a mailto be registered as an e-mail address?
        doc.register :links, (link_opts[:target] = target)
        link_opts[:attributes] = attrs if attrs
        Inline.new(self, :anchor, text, link_opts).convert
      }
    end

    if result.include? '@'
      result = result.gsub(InlineEmailRx) {
        address, tip = $&, $1
        if tip
          next (tip == RS ? address[1..-1] : address)
        end

        target = %(mailto:#{address})
        # QUESTION should this be registered as an e-mail address?
        doc.register(:links, target)

        Inline.new(self, :anchor, address, :type => :link, :target => target).convert
      }
    end

    if found_macroish && (result.include? 'tnote')
      result = result.gsub(InlineFootnoteMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? RS
          next m[0][1..-1]
        end
        if m[1] # footnoteref (legacy)
          id, text = (m[3] || '').split(',', 2)
        else
          id, text = m[2], m[3]
        end
        if id
          if text
            # REVIEW it's a dirty job, but somebody's gotta do it
            text = restore_passthroughs(sub_inline_xrefs(sub_inline_anchors(normalize_string text, true)), false)
            index = doc.counter('footnote-number')
            doc.register(:footnotes, Document::Footnote.new(index, id, text))
            type, target = :ref, nil
          else
            if (footnote = doc.footnotes.find {|candidate| candidate.id == id })
              index, text = footnote.index, footnote.text
            else
              logger.warn %(invalid footnote reference: #{id})
              index, text = nil, id
            end
            type, target, id = :xref, id, nil
          end
        elsif text
          # REVIEW it's a dirty job, but somebody's gotta do it
          text = restore_passthroughs(sub_inline_xrefs(sub_inline_anchors(normalize_string text, true)), false)
          index = doc.counter('footnote-number')
          doc.register(:footnotes, Document::Footnote.new(index, id, text))
          type = target = nil
        else
          next m[0]
        end
        Inline.new(self, :footnote, text, :attributes => {'index' => index}, :id => id, :target => target, :type => type).convert
      }
    end

    sub_inline_xrefs(sub_inline_anchors(result, found), found)
  end

  # Internal: Substitute normal and bibliographic anchors
  def sub_inline_anchors(text, found = nil)
    if @context == :list_item && @parent.style == 'bibliography'
      text = text.sub(InlineBiblioAnchorRx) {
        # NOTE target property on :bibref is deprecated
        Inline.new(self, :anchor, %([#{$2 || $1}]), :type => :bibref, :id => $1, :target => $1).convert
      }
    end

    if ((!found || found[:square_bracket]) && text.include?('[[')) ||
        ((!found || found[:macroish]) && text.include?('or:'))
      text = text.gsub(InlineAnchorRx) {
        # honor the escape
        next $&.slice 1, $&.length if $1
        # NOTE reftext is only relevant for DocBook output; used as value of xreflabel attribute
        if (id = $2)
          reftext = $3
        else
          id = $4
          if (reftext = $5) && (reftext.include? R_SB)
            reftext = reftext.gsub ESC_R_SB, R_SB
          end
        end
        # NOTE target property on :ref is deprecated
        Inline.new(self, :anchor, reftext, :type => :ref, :id => id, :target => id).convert
      }
    end

    text
  end

  # Internal: Substitute cross reference links
  def sub_inline_xrefs(content, found = nil)
    if ((found ? found[:macroish] : (content.include? '[')) && (content.include? 'xref:')) || ((content.include? '&') && (content.include? 'lt;&'))
      content = content.gsub(InlineXrefMacroRx) {
        # alias match for Ruby 1.8.7 compat
        m = $~
        # honor the escape
        if m[0].start_with? RS
          next m[0][1..-1]
        end
        attrs, doc = {}, @document
        if (refid = m[1])
          refid, text = refid.split ',', 2
          text = text.lstrip if text
        else
          macro = true
          refid = m[2]
          if (text = m[3])
            text = text.gsub ESC_R_SB, R_SB if text.include? R_SB
            # NOTE if an equal sign (=) is present, parse text as attributes
            text = ((AttributeList.new text, self).parse_into attrs)[1] if !doc.compat_mode && (text.include? '=')
          end
        end

        if doc.compat_mode
          fragment = refid
        elsif (hash_idx = refid.index '#')
          if hash_idx > 0
            if (fragment_len = refid.length - hash_idx - 1) > 0
              path, fragment = (refid.slice 0, hash_idx), (refid.slice hash_idx + 1, fragment_len)
            else
              path = refid.slice 0, hash_idx
            end
            if (ext = ::File.extname path).empty?
              src2src = path
            elsif ASCIIDOC_EXTENSIONS[ext]
              src2src = (path = path.slice 0, path.length - ext.length)
            end
          else
            target, fragment = refid, (refid.slice 1, refid.length)
          end
        elsif macro && (refid.end_with? '.adoc')
          src2src = (path = refid.slice 0, refid.length - 5)
        else
          fragment = refid
        end

        # handles: #id
        if target
          refid = fragment
          logger.warn %(invalid reference: #{refid}) if $VERBOSE && !(doc.catalog[:ids].key? refid)
        elsif path
          # handles: path#, path#id, path.adoc#, path.adoc#id, or path.adoc (xref macro only)
          # the referenced path is the current document, or its contents have been included in the current document
          if src2src && (doc.attributes['docname'] == path || doc.catalog[:includes][path])
            if fragment
              refid, path, target = fragment, nil, %(##{fragment})
              logger.warn %(invalid reference: #{refid}) if $VERBOSE && !(doc.catalog[:ids].key? refid)
            else
              refid, path, target = nil, nil, '#'
            end
          else
            refid, path = path, %(#{doc.attributes['relfileprefix']}#{path}#{src2src ? (doc.attributes.fetch 'relfilesuffix', doc.outfilesuffix) : ''})
            if fragment
              refid, target = %(#{refid}##{fragment}), %(#{path}##{fragment})
            else
              target = path
            end
          end
        # handles: id (in compat mode or when natural xrefs are disabled)
        elsif doc.compat_mode || !Compliance.natural_xrefs
          refid, target = fragment, %(##{fragment})
          logger.warn %(invalid reference: #{refid}) if $VERBOSE && !(doc.catalog[:ids].key? refid)
        # handles: id
        elsif doc.catalog[:ids].key? fragment
          refid, target = fragment, %(##{fragment})
        # handles: Node Title or Reference Text
        # do reverse lookup on fragment if not a known ID and resembles reftext (contains a space or uppercase char)
        elsif (refid = doc.catalog[:ids].key fragment) && ((fragment.include? ' ') || fragment.downcase != fragment)
          fragment, target = refid, %(##{refid})
        else
          refid, target = fragment, %(##{fragment})
          logger.warn %(invalid reference: #{refid}) if $VERBOSE
        end
        attrs['path'], attrs['fragment'], attrs['refid'] = path, fragment, refid
        Inline.new(self, :anchor, text, :type => :xref, :target => target, :attributes => attrs).convert
      }
    end

    content
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
      if $1
        # we have to use sub since we aren't sure it's the first char
        next $&.sub(RS, '')
      end
      Inline.new(self, :callout, $3, :id => @document.callouts.read_next_id).convert
    }
  end

  # Public: Substitute post replacements
  #
  # text - The String text to process
  #
  # Returns the converted String text
  def sub_post_replacements(text)
    if (@document.attributes.key? 'hardbreaks') || (@attributes.key? 'hardbreaks-option')
      lines = text.split LF, -1
      return text if lines.size < 2
      last = lines.pop
      (lines.map {|line|
        Inline.new(self, :break, (line.end_with? HARD_LINE_BREAK) ? (line.slice 0, line.length - 2) : line, :type => :line).convert
      } << last).join LF
    elsif (text.include? PLUS) && (text.include? HARD_LINE_BREAK)
      text.gsub(HardLineBreakRx) { Inline.new(self, :break, $1, :type => :line).convert }
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
    if match[0].start_with? RS
      if scope == :constrained && (attrs = match[2])
        unescaped_attrs = %([#{attrs}])
      else
        return match[0][1..-1]
      end
    end

    if scope == :constrained
      if unescaped_attrs
        %(#{unescaped_attrs}#{Inline.new(self, :quoted, match[3], :type => type).convert})
      else
        if (attrlist = match[2])
          id = (attributes = parse_quoted_text_attributes attrlist).delete 'id'
          type = :unquoted if type == :mark
        end
        %(#{match[1]}#{Inline.new(self, :quoted, match[3], :type => type, :id => id, :attributes => attributes).convert})
      end
    else
      if (attrlist = match[1])
        id = (attributes = parse_quoted_text_attributes attrlist).delete 'id'
        type = :unquoted if type == :mark
      end
      Inline.new(self, :quoted, match[2], :type => type, :id => id, :attributes => attributes).convert
    end
  end

  # Internal: Parse the attributes that are defined on quoted (aka formatted) text
  #
  # str - A non-nil String of unprocessed attributes;
  #       space-separated roles (e.g., role1 role2) or the id/role shorthand syntax (e.g., #idname.role)
  #
  # Returns a Hash of attributes (role and id only)
  def parse_quoted_text_attributes str
    # NOTE attributes are typically resolved after quoted text, so substitute eagerly
    str = sub_attributes str, :multiline => true if str.include? ATTR_REF_HEAD
    # for compliance, only consider first positional attribute
    str = str.slice 0, (str.index ',') if str.include? ','

    if (str = str.strip).empty?
      {}
    elsif (str.start_with? '.', '#') && Compliance.shorthand_property_syntax
      segments = str.split('#', 2)

      if segments.size > 1
        id, *more_roles = segments[1].split('.')
      else
        id = nil
        more_roles = []
      end

      roles = segments[0].empty? ? [] : segments[0].split('.')
      if roles.size > 1
        roles.shift
      end

      if more_roles.size > 0
        roles.concat more_roles
      end

      attrs = {}
      attrs['id'] = id if id
      attrs['role'] = roles.join ' ' unless roles.empty?
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
    attrline = @document.sub_attributes attrline if opts[:sub_input] && (attrline.include? ATTR_REF_HEAD)
    attrline = unescape_bracketed_text attrline if opts[:unescape_input]
    # substitutions are only performed on attribute values if block is not nil
    block = opts.fetch(:sub_result, true) ? self : nil
    if (into = opts[:into])
      AttributeList.new(attrline, block).parse_into(into, posattrs)
    else
      AttributeList.new(attrline, block).parse(posattrs)
    end
  end

  # Expand all groups in the subs list and return. If no subs are resolve, return nil.
  #
  # subs - The substitutions to expand; can be a Symbol, Symbol Array or nil
  #
  # Returns a Symbol Array of substitutions to pass to apply_subs or nil if no substitutions were resolved.
  def expand_subs subs
    if ::Symbol === subs
      unless subs == :none
        SUB_GROUPS[subs] || [subs]
      end
    else
      expanded_subs = []
      subs.each do |key|
        unless key == :none
          if (sub_group = SUB_GROUPS[key])
            expanded_subs += sub_group
          else
            expanded_subs << key
          end
        end
      end

      expanded_subs.empty? ? nil : expanded_subs
    end
  end

  # Internal: Strip bounding whitespace, fold endlines and unescape closing
  # square brackets from text extracted from brackets
  def unescape_bracketed_text text
    if (text = text.strip.tr LF, ' ').include? R_SB
      text = text.gsub ESC_R_SB, R_SB
    end unless text.empty?
    text
  end

  # Internal: Strip bounding whitespace and fold endlines
  def normalize_string str, unescape_brackets = false
    unless str.empty?
      str = str.strip.tr LF, ' '
      str = str.gsub ESC_R_SB, R_SB if unescape_brackets && (str.include? R_SB)
    end
    str
  end

  # Internal: Unescape closing square brackets.
  # Intended for text extracted from square brackets.
  def unescape_brackets str
    if str.include? RS
      str = str.gsub ESC_R_SB, R_SB
    end unless str.empty?
    str
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
            current << c
          else
            values << current.join.strip
            current = []
          end
        when '"'
          quote_open = !quote_open
        else
          current << c
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
  # returns An Array of Symbols representing the substitution operation or nothing if no subs are found.
  def resolve_subs subs, type = :block, defaults = nil, subject = nil
    return if subs.nil_or_empty?
    # QUESTION should we store candidates as a Set instead of an Array?
    candidates = nil
    subs = subs.delete ' ' if subs.include? ' '
    modifiers_present = SubModifierSniffRx.match? subs
    subs.split(',').each do |key|
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
        resolved_keys = BASIC_SUBS
      elsif SUB_GROUPS.key? key
        resolved_keys = SUB_GROUPS[key]
      elsif type == :inline && key.length == 1 && (SUB_HINTS.key? key)
        resolved_key = SUB_HINTS[key]
        if (candidate = SUB_GROUPS[resolved_key])
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
    return unless candidates
    # weed out invalid options and remove duplicates (order is preserved; first occurence wins)
    resolved = candidates & SUB_OPTIONS[type]
    unless (candidates - resolved).empty?
      invalid = candidates - resolved
      logger.warn %(invalid substitution type#{invalid.size > 1 ? 's' : ''}#{subject ? ' for ' : ''}#{subject}: #{invalid.join ', '})
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
      unless (highlighter_loaded = defined? ::CodeRay) ||
          (defined? @@coderay_unavailable) || @document.attributes['coderay-unavailable']
        if (Helpers.require_library 'coderay', true, :warn).nil?
          # prevent further attempts to load CodeRay in this process
          @@coderay_unavailable = true
        else
          highlighter_loaded = true
        end
      end
    when 'pygments'
      unless (highlighter_loaded = defined? ::Pygments) ||
          (defined? @@pygments_unavailable) || @document.attributes['pygments-unavailable']
        if (Helpers.require_library 'pygments', 'pygments.rb', :warn).nil?
          # prevent further attempts to load Pygments in this process
          @@pygments_unavailable = true
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
      source = source.split(LF, -1).map {|line|
        lineno = lineno + 1
        line.gsub(callout_rx) {
          # alias match for Ruby 1.8.7 compat
          m = $~
          # honor the escape
          if m[1] == RS
            # we have to use sub since we aren't sure it's the first char
            m[0].sub RS, ''
          else
            (callout_marks[lineno] ||= []) << m[3]
            last = lineno
            nil
          end
        }
      }.join LF
      callout_on_last = (last == lineno)
      callout_marks = nil if callout_marks.empty?
    else
      callout_marks = nil
    end

    linenums_mode = nil
    highlight_lines = nil

    case highlighter
    when 'coderay'
      if (linenums_mode = (attr? 'linenums', nil, false) ? (@document.attributes['coderay-linenums-mode'] || :table).to_sym : nil)
        if attr? 'highlight', nil, false
          highlight_lines = resolve_highlight_lines(attr 'highlight', nil, false)
        end
      end
      result = ::CodeRay::Duo[attr('language', :text, false).to_sym, :html, {
          :css => (@document.attributes['coderay-css'] || :class).to_sym,
          :line_numbers => linenums_mode,
          :line_number_anchors => false,
          :highlight_lines => highlight_lines,
          :bold_every => false}].highlight source
    when 'pygments'
      lexer = ::Pygments::Lexer.find_by_alias(attr 'language', 'text', false) || ::Pygments::Lexer.find_by_mimetype('text/plain')
      opts = { :cssclass => 'pyhl', :classprefix => 'tok-', :nobackground => true, :stripnl => false }
      opts[:startinline] = !(option? 'mixed') if lexer.name == 'PHP'
      unless (@document.attributes['pygments-css'] || 'class') == 'class'
        opts[:noclasses] = true
        opts[:style] = (@document.attributes['pygments-style'] || Stylesheets::DEFAULT_PYGMENTS_STYLE)
      end
      if attr? 'highlight', nil, false
        unless (highlight_lines = resolve_highlight_lines(attr 'highlight', nil, false)).empty?
          opts[:hl_lines] = highlight_lines.join ' '
        end
      end
      # NOTE highlight can return nil if something goes wrong; fallback to source if this happens
      # TODO we could add the line numbers in ourselves instead of having to strip out the junk
      if (attr? 'linenums', nil, false) && (opts[:linenos] = @document.attributes['pygments-linenums-mode'] || 'table') == 'table'
        linenums_mode = :table
        if (result = lexer.highlight source, :options => opts)
          result = (result.sub PygmentsWrapperDivRx, '\1').gsub PygmentsWrapperPreRx, '\1'
        else
          result = sub_specialchars source
        end
      elsif (result = lexer.highlight source, :options => opts)
        if PygmentsWrapperPreRx =~ result
          result = $1
        end
      else
        result = sub_specialchars source
      end
    end

    # fix passthrough placeholders that got caught up in syntax highlighting
    result = result.gsub HighlightedPassSlotRx, %(#{PASS_START}\\1#{PASS_END}) unless @passthroughs.empty?

    if process_callouts && callout_marks
      lineno = 0
      reached_code = linenums_mode != :table
      result.split(LF, -1).map {|line|
        unless reached_code
          next line unless line.include?('<td class="code">')
          reached_code = true
        end
        lineno += 1
        if (conums = callout_marks.delete(lineno))
          tail = nil
          if callout_on_last && callout_marks.empty? && linenums_mode == :table
            if highlighter == 'coderay' && (pos = line.index '</pre>')
              line, tail = (line.slice 0, pos), (line.slice pos, line.length)
            elsif highlighter == 'pygments' && (pos = line.start_with? '</td>')
              line, tail = '', line
            end
          end
          if conums.size == 1
            %(#{line}#{Inline.new(self, :callout, conums[0], :id => @document.callouts.read_next_id).convert}#{tail})
          else
            conums_markup = conums.map {|conum| Inline.new(self, :callout, conum, :id => @document.callouts.read_next_id).convert }.join ' '
            %(#{line}#{conums_markup}#{tail})
          end
        else
          line
        end
      }.join LF
    else
      result
    end
  end

  # e.g., highlight="1-5, !2, 10" or highlight=1-5;!2,10
  def resolve_highlight_lines spec
    lines = []
    ((spec.include? ' ') ? (spec.delete ' ') : spec).split(DataDelimiterRx).map do |entry|
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
    process_callouts ? sub_callouts(sub_specialchars source) : (sub_specialchars source)
  end

  # Internal: Lock-in the substitutions for this block
  #
  # Looks for an attribute named "subs". If present, resolves substitutions
  # from the value of that attribute and assigns them to the subs property on
  # this block. Otherwise, uses the substitutions assigned to the default_subs
  # property, if specified, or selects a default set of substitutions based on
  # the content model of the block.
  #
  # Returns The Array of resolved substitutions now assigned to this block
  def lock_in_subs
    unless (default_subs = @default_subs)
      case @content_model
      when :simple
        default_subs = NORMAL_SUBS
      when :verbatim
        if @context == :listing || (@context == :literal && !(option? 'listparagraph'))
          default_subs = VERBATIM_SUBS
        elsif @context == :verse
          default_subs = NORMAL_SUBS
        else
          default_subs = BASIC_SUBS
        end
      when :raw
        # TODO make pass subs a compliance setting; AsciiDoc Python performs :attributes and :macros on a pass block
        default_subs = @context == :stem ? BASIC_SUBS : NONE_SUBS
      else
        return @subs
      end
    end

    if (custom_subs = @attributes['subs'])
      @subs = (resolve_block_subs custom_subs, default_subs, @context) || []
    else
      @subs = default_subs.dup
    end

    # QUESION delegate this logic to a method?
    if @context == :listing && @style == 'source' && (@attributes.key? 'language') && (@document.basebackend? 'html') &&
        (SUB_HIGHLIGHT.include? @document.attributes['source-highlighter']) && (idx = @subs.index :specialcharacters)
      @subs[idx] = :highlight
    end

    @subs
  end
end
end
