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
    none: NONE_SUBS,
    normal: NORMAL_SUBS,
    verbatim: VERBATIM_SUBS,
    specialchars: BASIC_SUBS,
  }

  SUB_HINTS = {
    a: :attributes,
    m: :macros,
    n: :normal,
    p: :post_replacements,
    q: :quotes,
    r: :replacements,
    c: :specialcharacters,
    v: :verbatim,
  }

  SUB_OPTIONS = {
    block:  SUB_GROUPS.keys + NORMAL_SUBS + [:callouts],
    inline: SUB_GROUPS.keys + NORMAL_SUBS,
  }

  CAN = ?\u0018
  DEL = ?\u007f

  # Delimiters and matchers for the passthrough placeholder
  # See http://www.aivosto.com/vbtips/control-characters.html#listabout for characters to use

  # SPA, start of guarded protected area (\u0096)
  PASS_START = ?\u0096

  # EPA, end of guarded protected area (\u0097)
  PASS_END = ?\u0097

  # match passthrough slot
  PassSlotRx = /#{PASS_START}(\d+)#{PASS_END}/

  # fix passthrough slot after syntax highlighting
  HighlightedPassSlotRx = %r(<span\b[^>]*>#{PASS_START}</span>[^\d]*(\d+)[^\d]*<span\b[^>]*>#{PASS_END}</span>)

  RS = '\\'

  R_SB = ']'

  ESC_R_SB = '\]'

  PLUS = '+'

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
    passes = @passthroughs
    text = text.gsub InlinePassMacroRx do
      preceding = nil

      if (boundary = $4) # $$, ++, or +++
        # skip ++ in compat mode, handled as normal quoted text
        if compat_mode && boundary == '++'
          next $2 ? %(#{$1}[#{$2}]#{$3}++#{extract_passthroughs $5}++) : %(#{$1}#{$3}++#{extract_passthroughs $5}++)
        end

        attributes = $2
        escape_count = $3.length
        content = $5
        old_behavior = false

        if attributes
          if escape_count > 0
            # NOTE we don't look for nested unconstrained pass macros
            next %(#{$1}[#{attributes}]#{RS * (escape_count - 1)}#{boundary}#{$5}#{boundary})
          elsif $1 == RS
            preceding = %([#{attributes}])
            attributes = nil
          else
            if boundary == '++' && (attributes.end_with? 'x-')
              old_behavior = true
              attributes = attributes.slice 0, attributes.length - 2
            end
            attributes = parse_quoted_text_attributes attributes
          end
        elsif escape_count > 0
          # NOTE we don't look for nested unconstrained pass macros
          next %(#{RS * (escape_count - 1)}#{boundary}#{$5}#{boundary})
        end
        subs = (boundary == '+++' ? [] : BASIC_SUBS)

        pass_key = passes.size
        if attributes
          if old_behavior
            passes[pass_key] = { text: content, subs: NORMAL_SUBS, type: :monospaced, attributes: attributes }
          else
            passes[pass_key] = { text: content, subs: subs, type: :unquoted, attributes: attributes }
          end
        else
          passes[pass_key] = { text: content, subs: subs }
        end
      else # pass:[]
        # NOTE we don't look for nested pass:[] macros
        # honor the escape
        next $&.slice 1, $&.length if $6 == RS

        passes[pass_key = passes.size] = { text: (unescape_brackets $8), subs: ($7 ? (resolve_pass_subs $7) : nil) }
      end

      %(#{preceding}#{PASS_START}#{pass_key}#{PASS_END})
    end if (text.include? '++') || (text.include? '$$') || (text.include? 'ss:')

    pass_inline_char1, pass_inline_char2, pass_inline_rx = InlinePassRx[compat_mode]
    text = text.gsub pass_inline_rx do
      preceding = $1
      attributes = $2
      escape_mark = RS if (quoted_text = $3).start_with? RS
      format_mark = $4
      content = $5

      if compat_mode
        old_behavior = true
      else
        if (old_behavior = (attributes && (attributes.end_with? 'x-')))
          attributes = attributes.slice 0, attributes.length - 2
        end
      end

      if attributes
        if format_mark == '`' && !old_behavior
          # extract nested single-plus passthrough; otherwise return unprocessed
          next (extract_inner_passthrough content, %(#{preceding}[#{attributes}]#{escape_mark}), attributes)
        elsif escape_mark
          # honor the escape of the formatting mark
          next %(#{preceding}[#{attributes}]#{quoted_text.slice 1, quoted_text.length})
        elsif preceding == RS
          # honor the escape of the attributes
          preceding = %([#{attributes}])
          attributes = nil
        else
          attributes = parse_quoted_text_attributes attributes
        end
      elsif format_mark == '`' && !old_behavior
        # extract nested single-plus passthrough; otherwise return unprocessed
        next (extract_inner_passthrough content, %(#{preceding}#{escape_mark}))
      elsif escape_mark
        # honor the escape of the formatting mark
        next %(#{preceding}#{quoted_text.slice 1, quoted_text.length})
      end

      pass_key = passes.size
      if compat_mode
        passes[pass_key] = { text: content, subs: BASIC_SUBS, attributes: attributes, type: :monospaced }
      elsif attributes
        if old_behavior
          subs = (format_mark == '`' ? BASIC_SUBS : NORMAL_SUBS)
          passes[pass_key] = { text: content, subs: subs, attributes: attributes, type: :monospaced }
        else
          passes[pass_key] = { text: content, subs: BASIC_SUBS, attributes: attributes, type: :unquoted }
        end
      else
        passes[pass_key] = { text: content, subs: BASIC_SUBS }
      end

      %(#{preceding}#{PASS_START}#{pass_key}#{PASS_END})
    end if (text.include? pass_inline_char1) || (pass_inline_char2 && (text.include? pass_inline_char2))

    # NOTE we need to do the stem in a subsequent step to allow it to be escaped by the former
    text = text.gsub InlineStemMacroRx do
      # honor the escape
      next $&.slice 1, $&.length if $&.start_with? RS

      if (type = $1.to_sym) == :stem
        type = STEM_TYPE_ALIASES[@document.attributes['stem']].to_sym
      end
      content = unescape_brackets $3
      subs = $2 ? (resolve_pass_subs $2) : ((@document.basebackend? 'html') ? BASIC_SUBS : nil)
      passes[pass_key = passes.size] = { text: content, subs: subs, type: type }
      %(#{PASS_START}#{pass_key}#{PASS_END})
    end if (text.include? ':') && ((text.include? 'stem:') || (text.include? 'math:'))

    text
  end

  def extract_inner_passthrough text, pre, attributes = nil
    if (text.end_with? '+') && (text.start_with? '+', '\+') && SinglePlusInlinePassRx =~ text
      if $1
        %(#{pre}`+#{$2}+`)
      else
        @passthroughs[pass_key = @passthroughs.size] = attributes ?
            { text: $2, subs: BASIC_SUBS, attributes: attributes, type: :unquoted } :
            { text: $2, subs: BASIC_SUBS }
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
    passes = @passthroughs
    # passthroughs may have been eagerly restored (e.g., footnotes)
    #if outer && (passes.empty? || !text.include?(PASS_START))
    #  return text
    #end

    text.gsub PassSlotRx do
      # NOTE we can't remove entry from map because placeholder may have been duplicated by other substitutions
      pass = passes[$1.to_i]
      subbed_text = apply_subs(pass[:text], pass[:subs])
      if (type = pass[:type])
        subbed_text = Inline.new(self, :quoted, subbed_text, type: type, attributes: pass[:attributes]).convert
      end
      subbed_text.include?(PASS_START) ? restore_passthroughs(subbed_text, false) : subbed_text
    end
  ensure
    # free memory if in outer call...we don't need these anymore
    passes.clear if outer
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
  def sub_specialchars text
    (text.include? '<') || (text.include? '&') || (text.include? '>') ? (text.gsub SpecialCharsRx, SpecialCharsTr) : text
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
    text = text.gsub AttributeReferenceRx do
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
      # drop lines from text
      if drop_empty_line
        lines = (text.tr_s DEL, DEL).split LF, -1
        if drop_line
          (lines.reject {|line| line == DEL || line == CAN || (line.start_with? CAN) || (line.include? CAN) }.join LF).delete DEL
        else
          (lines.reject {|line| line == DEL }.join LF).delete DEL
        end
      elsif text.include? LF
        (text.split LF, -1).reject {|line| line == CAN || (line.start_with? CAN) || (line.include? CAN) }.join LF
      else
        ''
      end
    else
      text
    end
  end

  # Public: Substitute inline macros (e.g., links, images, etc)
  #
  # Replace inline macros, which may span multiple lines, in the provided text
  #
  # source - The String text to process
  #
  # returns The converted String text
  def sub_macros(text)
    #return text if text.nil_or_empty?
    # some look ahead assertions to cut unnecessary regex calls
    found = {}
    found_square_bracket = found[:square_bracket] = text.include? '['
    found_colon = text.include? ':'
    found_macroish = found[:macroish] = found_square_bracket && found_colon
    found_macroish_short = found_macroish && (text.include? ':[')
    doc_attrs = (doc = @document).attributes

    if doc_attrs.key? 'experimental'
      if found_macroish_short && ((text.include? 'kbd:') || (text.include? 'btn:'))
        text = text.gsub InlineKbdBtnMacroRx do
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
            (Inline.new self, :kbd, nil, attributes: { 'keys' => keys }).convert
          else # $2 == 'btn'
            (Inline.new self, :button, (unescape_bracketed_text $3)).convert
          end
        end
      end

      if found_macroish && (text.include? 'menu:')
        text = text.gsub InlineMenuMacroRx do
          # honor the escape
          next $&.slice 1, $&.length if $&.start_with? RS

          menu = $1
          if (items = $2)
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

          Inline.new(self, :menu, nil, attributes: { 'menu' => menu, 'submenus' => submenus, 'menuitem' => menuitem }).convert
        end
      end

      if (text.include? '"') && (text.include? '&gt;')
        text = text.gsub InlineMenuRx do
          # honor the escape
          next $&.slice 1, $&.length if $&.start_with? RS

          menu, *submenus = $1.split('&gt;').map {|it| it.strip }
          menuitem = submenus.pop
          Inline.new(self, :menu, nil, attributes: { 'menu' => menu, 'submenus' => submenus, 'menuitem' => menuitem }).convert
        end
      end
    end

    # FIXME this location is somewhat arbitrary, probably need to be able to control ordering
    # TODO this handling needs some cleanup
    if (extensions = doc.extensions) && extensions.inline_macros? # && found_macroish
      extensions.inline_macros.each do |extension|
        text = text.gsub extension.instance.regexp do
          # honor the escape
          next $&.slice 1, $&.length if $&.start_with? RS

          if $~.names.empty?
            target, content, extconf = $1, $2, extension.config
          else
            target, content, extconf = ($~[:target] rescue nil), ($~[:content] rescue nil), extension.config
          end
          attributes = (attributes = extconf[:default_attrs]) ? attributes.dup : {}
          if content.nil_or_empty?
            attributes['text'] = content if content && extconf[:content_model] != :attributes
          else
            content = unescape_bracketed_text content
            if extconf[:content_model] == :attributes
              # QUESTION should we store the text in the _text key?
              # NOTE bracked text has already been escaped
              parse_attributes content, extconf[:pos_attrs] || [], into: attributes
            else
              attributes['text'] = content
            end
          end
          # NOTE use content if target is not set (short form only); deprecated - remove in 1.6.0
          replacement = extension.process_method[self, target || content, attributes]
          Inline === replacement ? replacement.convert : replacement
        end
      end
    end

    if found_macroish && ((text.include? 'image:') || (text.include? 'icon:'))
      # image:filename.png[Alt Text]
      text = text.gsub InlineImageMacroRx do
        # honor the escape
        if $&.start_with? RS
          next $&.slice 1, $&.length
        elsif $&.start_with? 'icon:'
          type, posattrs = 'icon', ['size']
        else
          type, posattrs = 'image', ['alt', 'width', 'height']
        end
        if (target = $1).include? ATTR_REF_HEAD
          # TODO remove this special case once titles use normal substitution order
          target = sub_attributes target
        end
        attrs = parse_attributes $2, posattrs, unescape_input: true
        doc.register :images, [target, (attrs['imagesdir'] = doc_attrs['imagesdir'])] unless type == 'icon'
        attrs['alt'] ||= (attrs['default-alt'] = Helpers.basename(target, true).tr('_-', ' '))
        Inline.new(self, :image, nil, type: type, target: target, attributes: attrs).convert
      end
    end

    if ((text.include? '((') && (text.include? '))')) || (found_macroish_short && (text.include? 'dexterm'))
      # (((Tigers,Big cats)))
      # indexterm:[Tigers,Big cats]
      # ((Tigers))
      # indexterm2:[Tigers]
      text = text.gsub InlineIndextermMacroRx do
        case $1
        when 'indexterm'
          # honor the escape
          next $&.slice 1, $&.length if $&.start_with? RS

          # indexterm:[Tigers,Big cats]
          terms = split_simple_csv normalize_string $2, true
          doc.register :indexterms, terms
          (Inline.new self, :indexterm, nil, attributes: { 'terms' => terms }).convert
        when 'indexterm2'
          # honor the escape
          next $&.slice 1, $&.length if $&.start_with? RS

          # indexterm2:[Tigers]
          term = normalize_string $2, true
          doc.register :indexterms, [term]
          (Inline.new self, :indexterm, term, type: :visible).convert
        else
          text = $3
          # honor the escape
          if $&.start_with? RS
            # escape concealed index term, but process nested flow index term
            if (text.start_with? '(') && (text.end_with? ')')
              text = text.slice 1, text.length - 2
              visible, before, after = true, '(', ')'
            else
              next $&.slice 1, $&.length
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
            subbed_term = (Inline.new self, :indexterm, term, type: :visible).convert
          else
            # (((Tigers,Big cats)))
            terms = split_simple_csv(normalize_string text)
            doc.register :indexterms, terms
            subbed_term = (Inline.new self, :indexterm, nil, attributes: { 'terms' => terms }).convert
          end
          before ? %(#{before}#{subbed_term}#{after}) : subbed_term
        end
      end
    end

    if found_colon && (text.include? '://')
      # inline urls, target[text] (optionally prefixed with link: and optionally surrounded by <>)
      text = text.gsub InlineLinkRx do
        target = $2
        # honor the escape
        next %(#{$1}#{target.slice 1, target.length}#{$3}) if target.start_with? RS

        # NOTE if text is non-nil, then we've matched a formal macro (i.e., trailing square brackets)
        captured, prefix, text, suffix = $&, $1, (macro = $3) || '', ''
        if prefix == 'link:'
          if macro
            prefix = ''
          else
            # invalid macro syntax (link: prefix w/o trailing square brackets)
            # we probably shouldn't even get here...our regex is doing too much
            next captured
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
              prefix = prefix.slice 4, prefix.length
              target = target.slice 0, target.length - 4
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
          return captured if target.end_with? '://'
        end

        attrs, link_opts = nil, { type: :link }
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
          # NOTE it's not possible for the URI scheme to be bare in this case
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
      end
    end

    if found_macroish && ((text.include? 'link:') || (text.include? 'mailto:'))
      # inline link macros, link:target[text]
      text = text.gsub InlineLinkMacroRx do
        # honor the escape
        if $&.start_with? RS
          next $&.slice 1, $&.length
        elsif (mailto = $1)
          target = %(mailto:#{$2})
          mailto_text = $2
        else
          target = $2
        end
        attrs, link_opts = nil, { type: :link }
        unless (text = $3).empty?
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
            text = mailto_text
          else
            if doc_attrs.key? 'hide-uri-scheme'
              if (text = target.sub UriSniffRx, '').empty?
                text = target
              end
            else
              text = target
            end
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
      end
    end

    if text.include? '@'
      text = text.gsub InlineEmailRx do
        # honor the escapes
        next ($1 == RS ? ($&.slice 1, $&.length) : $&) if $1

        target = %(mailto:#{$&})
        # QUESTION should this be registered as an e-mail address?
        doc.register(:links, target)

        Inline.new(self, :anchor, $&, type: :link, target: target).convert
      end
    end

    if found_macroish && (text.include? 'tnote')
      text = text.gsub InlineFootnoteMacroRx do
        # honor the escape
        next $&.slice 1, $&.length if $&.start_with? RS

        # $1 is footnoteref (legacy)
        id, text = $1 ? ($3 || '').split(',', 2) : [$2, $3]

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
          next $&
        end
        Inline.new(self, :footnote, text, attributes: { 'index' => index }, id: id, target: target, type: type).convert
      end
    end

    sub_inline_xrefs(sub_inline_anchors(text, found), found)
  end

  # Internal: Substitute normal and bibliographic anchors
  def sub_inline_anchors(text, found = nil)
    if @context == :list_item && @parent.style == 'bibliography'
      text = text.sub InlineBiblioAnchorRx do
        # NOTE target property on :bibref is deprecated
        Inline.new(self, :anchor, %([#{$2 || $1}]), type: :bibref, id: $1, target: $1).convert
      end
    end

    if ((!found || found[:square_bracket]) && text.include?('[[')) ||
        ((!found || found[:macroish]) && text.include?('or:'))
      text = text.gsub InlineAnchorRx do
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
        Inline.new(self, :anchor, reftext, type: :ref, id: id, target: id).convert
      end
    end

    text
  end

  # Internal: Substitute cross reference links
  def sub_inline_xrefs(content, found = nil)
    if ((found ? found[:macroish] : (content.include? '[')) && (content.include? 'xref:')) || ((content.include? '&') && (content.include? 'lt;&'))
      content = content.gsub InlineXrefMacroRx do
        # honor the escape
        next $&.slice 1, $&.length if $&.start_with? RS

        attrs, doc = {}, @document
        if (refid = $1)
          refid, text = refid.split ',', 2
          text = text.lstrip if text
        else
          macro = true
          refid = $2
          if (text = $3)
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
        Inline.new(self, :anchor, text, type: :xref, target: target, attributes: attrs).convert
      end
    end

    content
  end

  # Public: Substitute callout source references
  #
  # text - The String text to process
  #
  # Returns the converted String text
  def sub_callouts(text)
    callout_rx = (attr? 'line-comment') ? CalloutSourceRxMap[attr 'line-comment'] : CalloutSourceRx
    autonum = 0
    text.gsub callout_rx do
      # honor the escape
      if $2
        # use sub since it might be behind a line comment
        $&.sub(RS, '')
      else
        Inline.new(self, :callout, $4 == '.' ? (autonum += 1).to_s : $4, id: @document.callouts.read_next_id, attributes: { 'guard' => $1 }).convert
      end
    end
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
      (lines.map do |line|
        Inline.new(self, :break, (line.end_with? HARD_LINE_BREAK) ? (line.slice 0, line.length - 2) : line, type: :line).convert
      end.push last).join LF
    elsif (text.include? PLUS) && (text.include? HARD_LINE_BREAK)
      text.gsub(HardLineBreakRx) { Inline.new(self, :break, $1, type: :line).convert }
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
        return match[0].slice 1, match[0].length
      end
    end

    if scope == :constrained
      if unescaped_attrs
        %(#{unescaped_attrs}#{Inline.new(self, :quoted, match[3], type: type).convert})
      else
        if (attrlist = match[2])
          id = (attributes = parse_quoted_text_attributes attrlist).delete 'id'
          type = :unquoted if type == :mark
        end
        %(#{match[1]}#{Inline.new(self, :quoted, match[3], type: type, id: id, attributes: attributes).convert})
      end
    else
      if (attrlist = match[1])
        id = (attributes = parse_quoted_text_attributes attrlist).delete 'id'
        type = :unquoted if type == :mark
      end
      Inline.new(self, :quoted, match[2], type: type, id: id, attributes: attributes).convert
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
    str = sub_attributes str if str.include? ATTR_REF_HEAD
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
      { 'role' => str }
    end
  end

  # Internal: Parse attributes in name or name=value format from a comma-separated String
  #
  # attrlist - A comma-separated String list of attributes in name or name=value format.
  # posattrs - An Array of positional attribute names (default: []).
  # opts     - A Hash of options to control how the string is parsed (default: {}):
  #            :into           - The Hash to parse the attributes into (optional, default: false).
  #            :sub_input      - A Boolean that indicates whether to substitute attributes prior to
  #                              parsing (optional, default: false).
  #            :sub_result     - A Boolean that indicates whether to apply substitutions
  #                              single-quoted attribute values (optional, default: true).
  #            :unescape_input - A Boolean that indicates whether to unescape square brackets prior
  #                              to parsing (optional, default: false).
  #
  # Returns an empty Hash if attrlist is nil or empty, otherwise a Hash of parsed attributes.
  def parse_attributes attrlist, posattrs = [], opts = {}
    return {} unless attrlist && !attrlist.empty?
    attrlist = @document.sub_attributes attrlist if opts[:sub_input] && (attrlist.include? ATTR_REF_HEAD)
    attrlist = unescape_bracketed_text attrlist if opts[:unescape_input]
    # substitutions are only performed on attribute values if block is not nil
    block = self if opts[:sub_result]
    if (into = opts[:into])
      AttributeList.new(attrlist, block).parse_into(into, posattrs)
    else
      AttributeList.new(attrlist, block).parse(posattrs)
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

  # Internal: Strip bounding whitespace, fold newlines and unescape closing
  # square brackets from text extracted from brackets
  def unescape_bracketed_text text
    if (text = text.strip.tr LF, ' ').include? R_SB
      text = text.gsub ESC_R_SB, R_SB
    end unless text.empty?
    text
  end

  # Internal: Strip bounding whitespace and fold newlines
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
          key = key.slice 1, key.length
        elsif first == '-'
          modifier_operation = :remove
          key = key.slice 1, key.length
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
        candidates ||= (defaults ? (defaults.drop 0) : [])
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

  # Public: Highlight (i.e., colorize) the source code during conversion using a syntax highlighter, if activated by the
  # source-highlighter document attribute. Otherwise return the text with verbatim substitutions applied.
  #
  # If the process_callouts argument is true, this method will extract the callout marks from the source before passing
  # it to the syntax highlighter, then subsequently restore those callout marks to the highlighted source so the callout
  # marks don't confuse the syntax highlighter.
  #
  # source - the source code String to syntax highlight
  # process_callouts - a Boolean flag indicating whether callout marks should be located and substituted
  #
  # Returns the highlighted source code, if a syntax highlighter is defined on the document, otherwise the source with
  # verbatim substituions applied
  def highlight_source source, process_callouts
    # NOTE the call to highlight? is a defensive check since, normally, we wouldn't arrive here unless it returns true
    return sub_source source, process_callouts unless (syntax_hl = @document.syntax_highlighter) && syntax_hl.highlight?

    if process_callouts
      callout_marks = {}
      lineno = 0
      last_lineno = nil
      callout_rx = (attr? 'line-comment') ? CalloutExtractRxMap[attr 'line-comment'] : CalloutExtractRx
      # extract callout marks, indexed by line number
      source = (source.split LF, -1).map do |line|
        lineno += 1
        line.gsub callout_rx do
          # honor the escape
          if $2
            # use sub since it might be behind a line comment
            $&.sub RS, ''
          else
            (callout_marks[lineno] ||= []) << [$1, $4]
            last_lineno = lineno
            nil
          end
        end
      end.join LF
      if last_lineno
        source = %(#{source}#{LF}) if last_lineno == lineno
      else
        callout_marks = nil
      end
    end

    doc_attrs = @document.attributes
    syntax_hl_name = syntax_hl.name
    if (linenums_mode = (attr? 'linenums', nil, false) ? (doc_attrs[%(#{syntax_hl_name}-linenums-mode)] || :table).to_sym : nil)
      start_line_number = 1 if (start_line_number = (attr 'start', nil, 1).to_i) < 1
    end
    highlight_lines = resolve_lines_to_highlight source, (attr 'highlight') if attr? 'highlight', nil, false

    highlighted, source_offset = syntax_hl.highlight self, source, (attr 'language', nil, false),
      callouts: callout_marks,
      css_mode: (doc_attrs[%(#{syntax_hl_name}-css)] || :class).to_sym,
      highlight_lines: highlight_lines,
      line_numbers: linenums_mode,
      start_line_number: start_line_number,
      style: doc_attrs[%(#{syntax_hl_name}-style)]

    # fix passthrough placeholders that got caught up in syntax highlighting
    highlighted = highlighted.gsub HighlightedPassSlotRx, %(#{PASS_START}\\1#{PASS_END}) unless @passthroughs.empty?

    # NOTE highlight method may have depleted callouts
    if callout_marks.nil_or_empty?
      highlighted
    else
      if source_offset
        preamble = highlighted.slice 0, source_offset
        highlighted = highlighted.slice source_offset, highlighted.length
      else
        preamble = ''
      end
      autonum = lineno = 0
      preamble + ((highlighted.split LF, -1).map do |line|
        if (conums = callout_marks.delete lineno += 1)
          if conums.size == 1
            guard, conum = conums[0]
            %(#{line}#{Inline.new(self, :callout, conum == '.' ? (autonum += 1).to_s : conum, id: @document.callouts.read_next_id, attributes: { 'guard' => guard }).convert})
          else
            %(#{line}#{conums.map do |guard_it, conum_it|
              Inline.new(self, :callout, conum_it == '.' ? (autonum += 1).to_s : conum_it, id: @document.callouts.read_next_id, attributes: { 'guard' => guard_it }).convert
            end.join ' '})
          end
        else
          line
        end
      end.join LF)
    end
  end

  # e.g., highlight="1-5, !2, 10" or highlight=1-5;!2,10
  def resolve_lines_to_highlight source, spec
    lines = []
    spec = spec.delete ' ' if spec.include? ' '
    ((spec.include? ',') ? (spec.split ',') : (spec.split ';')).map do |entry|
      negate = false
      if entry.start_with? '!'
        entry = entry.slice 1, entry.length
        negate = true
      end
      if (delim = (entry.include? '..') ? '..' : ((entry.include? '-') ? '-' : nil))
        from, to = entry.split delim, 2
        to = (source.count LF) + 1 if to.empty? || (to = to.to_i) < 0
        line_nums = (from.to_i..to).to_a
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

  alias sub_placeholder sprintf

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
      @subs = default_subs.drop 0
    end

    # QUESION delegate this logic to a method?
    if @context == :listing && @style == 'source' && (syntax_hl = @document.syntax_highlighter) &&
        syntax_hl.highlight? && (idx = @subs.index :specialcharacters)
      @subs[idx] = :highlight
    end

    @subs
  end
end
end
