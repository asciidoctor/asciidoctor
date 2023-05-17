# frozen_string_literal: true
module Asciidoctor
# Public: Methods to perform substitutions on lines of AsciiDoc text. This module
# is intended to be mixed-in to Section and Block to provide operations for performing
# the necessary substitutions.
module Substitutors
  SpecialCharsRx = /[<&>]/
  SpecialCharsTr = { '>' => '&gt;', '<' => '&lt;', '&' => '&amp;' }

  # Detects if text is a possible candidate for the quotes substitution.
  QuotedTextSniffRx = { false => /[*_`#^~]/, true => /[*'_+#^~]/ }

  (BASIC_SUBS = [:specialcharacters]).freeze
  (HEADER_SUBS = [:specialcharacters, :attributes]).freeze
  (NO_SUBS = []).freeze
  (NORMAL_SUBS = [:specialcharacters, :quotes, :attributes, :replacements, :macros, :post_replacements]).freeze
  (REFTEXT_SUBS = [:specialcharacters, :quotes, :replacements]).freeze
  (VERBATIM_SUBS = [:specialcharacters, :callouts]).freeze

  SUB_GROUPS = {
    none: NO_SUBS,
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

  # Public: Apply the specified substitutions to the text.
  #
  # text  - The String or String Array of text to process; must not be nil.
  # subs  - The substitutions to perform; must be a Symbol Array or nil (default: NORMAL_SUBS).
  #
  # Returns a String or String Array to match the type of the text argument with substitutions applied.
  def apply_subs text, subs = NORMAL_SUBS
    return text if text.empty? || !subs

    if (is_multiline = ::Array === text)
      text = text[1] ? (text.join LF) : text[0]
    end

    if subs.include? :macros
      text = extract_passthroughs text
      unless @passthroughs.empty?
        passthrus = @passthroughs
        # NOTE placeholders can move around, so we can only clear in the outermost substitution call
        @passthroughs_locked ||= (clear_passthrus = true)
      end
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

    if passthrus
      text = restore_passthroughs text
      if clear_passthrus
        passthrus.clear
        @passthroughs_locked = nil
      end
    end

    is_multiline ? (text.split LF, -1) : text
  end

  # Public: Apply normal substitutions.
  #
  # An alias for apply_subs with default remaining arguments.
  #
  # text  - The String text to which to apply normal substitutions
  #
  # Returns the String with normal substitutions applied.
  def apply_normal_subs text
    apply_subs text, NORMAL_SUBS
  end

  # Public: Apply substitutions for header metadata and attribute assignments
  #
  # text    - String containing the text process
  #
  # Returns A String with header substitutions performed
  def apply_header_subs text
    apply_subs text, HEADER_SUBS
  end

  # Public: Apply substitutions for titles.
  #
  # title  - The String title to process
  #
  # Returns A String with title substitutions performed
  alias apply_title_subs apply_subs

  # Public: Apply substitutions for reftext.
  #
  # text - The String to process
  #
  # Returns a String with all substitutions from the reftext substitution group applied
  def apply_reftext_subs text
    apply_subs text, REFTEXT_SUBS
  end

  # Public: Substitute special characters (i.e., encode XML)
  #
  # The special characters <, &, and > get replaced with &lt;, &amp;, and &gt;, respectively.
  #
  # text - The String text to process.
  #
  # Returns The String text with special characters replaced.
  if RUBY_ENGINE == 'opal'
    def sub_specialchars text
      (text.include? ?>) || (text.include? ?&) || (text.include? ?<) ? (text.gsub SpecialCharsRx, SpecialCharsTr) : text
    end
  else
    CGI = ::CGI
    def sub_specialchars text
      if (text.include? ?>) || (text.include? ?&) || (text.include? ?<)
        (text.include? ?') || (text.include? ?") ? (text.gsub SpecialCharsRx, SpecialCharsTr) : (CGI.escape_html text)
      else
        text
      end
    end
  end
  alias sub_specialcharacters sub_specialchars

  # Public: Substitute quoted text (includes emphasis, strong, monospaced, etc.)
  #
  # text - The String text to process
  #
  # returns The converted [String] text
  def sub_quotes text
    if QuotedTextSniffRx[compat = @document.compat_mode].match? text
      QUOTE_SUBS[compat].each do |type, scope, pattern|
        text = text.gsub(pattern) { convert_quoted_text $~, type, scope }
      end
    end
    text
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
  #        * :attribute_missing controls how to handle a missing attribute (see Compliance.attribute_missing for values)
  #        * :drop_line_severity the severity level at which to log a dropped line (:info or :ignore)
  #
  # Returns the [String] text with the attribute references replaced with resolved values
  def sub_attributes text, opts = {}
    doc_attrs = @document.attributes
    drop = drop_line = drop_line_severity = drop_empty_line = attribute_undefined = attribute_missing = nil
    text = text.gsub AttributeReferenceRx do
      # escaped attribute, return unescaped
      if $1 == RS || $4 == RS
        %({#{$2}})
      elsif $3
        case (args = $2.split ':', 3).shift
        when 'set'
          _, value = Parser.store_attribute args[0], args[1] || '', @document
          # NOTE since this is an assignment, only drop-line applies here (skip and drop imply the same result)
          if value || (attribute_undefined ||= (doc_attrs['attribute-undefined'] || Compliance.attribute_undefined)) != 'drop-line'
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
        case (attribute_missing ||= (opts[:attribute_missing] || doc_attrs['attribute-missing'] || Compliance.attribute_missing))
        when 'drop'
          drop = drop_empty_line = DEL
        when 'drop-line'
          if (drop_line_severity ||= (opts[:drop_line_severity] || :info)) == :info
            logger.info { %(dropping line containing reference to missing attribute: #{key}) }
          #elsif drop_line_severity == :warn
          #  logger.warn %(dropping line containing reference to missing attribute: #{key})
          end
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
        lines = (text.squeeze DEL).split LF, -1
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

  # Public: Substitute replacement characters (e.g., copyright, trademark, etc.)
  #
  # text - The String text to process
  #
  # returns The [String] text with the replacement characters substituted
  def sub_replacements text
    REPLACEMENTS.each do |pattern, replacement, restore|
      text = text.gsub(pattern) { do_replacement $~, replacement, restore }
    end if ReplaceableTextRx.match? text
    text
  end

  # Public: Substitute inline macros (e.g., links, images, etc)
  #
  # Replace inline macros, which may span multiple lines, in the provided text
  #
  # source - The String text to process
  #
  # returns The converted String text
  def sub_macros text
    #return text if text.nil_or_empty?
    # some look ahead assertions to cut unnecessary regex calls
    found_square_bracket = text.include? '['
    found_colon = text.include? ':'
    found_macroish = found_square_bracket && found_colon
    found_macroish_short = found_macroish && (text.include? ':[')
    doc_attrs = (doc = @document).attributes

    # TODO allow position of substitution to be controlled (before or after other macros)
    # TODO this handling needs some cleanup
    if (extensions = doc.extensions) && extensions.inline_macros? # && found_macroish
      extensions.inline_macros.each do |extension|
        text = text.gsub extension.instance.regexp do
          # honor the escape
          next $&.slice 1, $&.length if (match = $&).start_with? RS
          if $~.names.empty?
            target, content = $1, $2
          else
            target, content = ($~[:target] rescue nil), ($~[:content] rescue nil)
          end
          attributes = (default_attrs = (ext_config = extension.config)[:default_attrs]) ? default_attrs.merge : {}
          if content
            if content.empty?
              attributes['text'] = content unless ext_config[:content_model] == :attributes
            else
              content = normalize_text content, true, true
              # QUESTION should we store the unparsed attrlist in the attrlist key?
              if ext_config[:content_model] == :attributes
                parse_attributes content, ext_config[:positional_attrs] || ext_config[:pos_attrs] || [], into: attributes
              else
                attributes['text'] = content
              end
            end
            # NOTE for convenience, map content (unparsed attrlist) to target when format is short
            target ||= ext_config[:format] == :short ? content : target
          end
          if Inline === (replacement = extension.process_method[self, target, attributes])
            if (inline_subs = replacement.attributes.delete 'subs') && (inline_subs = expand_subs inline_subs, 'custom inline macro')
              replacement.text = apply_subs replacement.text, inline_subs
            end
            replacement.convert
          elsif replacement
            logger.info { %(expected substitution value for custom inline macro to be of type Inline; got #{replacement.class}: #{match}) }
            replacement
          else
            ''
          end
        end
      end
    end

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
                keys[-1] += delim
              else
                keys = keys.split(delim).map {|key| key.strip }
              end
            else
              keys = [keys]
            end
            (Inline.new self, :kbd, nil, attributes: { 'keys' => keys }).convert
          else # $2 == 'btn'
            (Inline.new self, :button, (normalize_text $3, true, true)).convert
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
        target = $1
        attrs = parse_attributes $2, posattrs, unescape_input: true
        unless type == 'icon'
          doc.register :images, target
          attrs['imagesdir'] = doc_attrs['imagesdir']
        end
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
          if (attrlist = normalize_text $2, true, true).include? '='
            if (primary = (attrs = (AttributeList.new attrlist, self).parse)[1])
              attrs['terms'] = [primary]
              if (see_also = attrs['see-also'])
                attrs['see-also'] = (see_also.include? ',') ? (see_also.split ',').map {|it| it.lstrip } : [see_also]
              end
            else
              attrs = { 'terms' => attrlist }
            end
          else
            attrs = { 'terms' => (split_simple_csv attrlist) }
          end
          (Inline.new self, :indexterm, nil, attributes: attrs).convert
        when 'indexterm2'
          # honor the escape
          next $&.slice 1, $&.length if $&.start_with? RS

          # indexterm2:[Tigers]
          if (term = normalize_text $2, true, true).include? '='
            term = (attrs = (AttributeList.new term, self).parse)[1] || (attrs = nil) || term
            if attrs && (see_also = attrs['see-also'])
              attrs['see-also'] = (see_also.include? ',') ? (see_also.split ',').map {|it| it.lstrip } : [see_also]
            end
          end
          (Inline.new self, :indexterm, term, attributes: attrs, type: :visible).convert
        else
          encl_text = $3
          # honor the escape
          if $&.start_with? RS
            # escape concealed index term, but process nested flow index term
            if (encl_text.start_with? '(') && (encl_text.end_with? ')')
              encl_text = encl_text.slice 1, encl_text.length - 2
              visible, before, after = true, '(', ')'
            else
              next $&.slice 1, $&.length
            end
          else
            visible = true
            if encl_text.start_with? '('
              if encl_text.end_with? ')'
                encl_text, visible = (encl_text.slice 1, encl_text.length - 2), false
              else
                encl_text, before, after = (encl_text.slice 1, encl_text.length), '(', ''
              end
            elsif encl_text.end_with? ')'
              encl_text, before, after = encl_text.chop, '', ')'
            end
          end
          if visible
            # ((Tigers))
            if (term = normalize_text encl_text, true).include? ';&'
              if term.include? ' &gt;&gt; '
                term, _, see = term.partition ' &gt;&gt; '
                attrs = { 'see' => see }
              elsif term.include? ' &amp;&gt; '
                term, *see_also = term.split ' &amp;&gt; '
                attrs = { 'see-also' => see_also }
              end
            end
            subbed_term = (Inline.new self, :indexterm, term, attributes: attrs, type: :visible).convert
          else
            # (((Tigers,Big cats)))
            attrs = {}
            if (terms = normalize_text encl_text, true).include? ';&'
              if terms.include? ' &gt;&gt; '
                terms, _, see = terms.partition ' &gt;&gt; '
                attrs['see'] = see
              elsif terms.include? ' &amp;&gt; '
                terms, *see_also = terms.split ' &amp;&gt; '
                attrs['see-also'] = see_also
              end
            end
            attrs['terms'] = split_simple_csv terms
            subbed_term = (Inline.new self, :indexterm, nil, attributes: attrs).convert
          end
          before ? %(#{before}#{subbed_term}#{after}) : subbed_term
        end
      end
    end

    if found_colon && (text.include? '://')
      # inline urls, target[text] (optionally prefixed with link: and optionally surrounded by <>)
      text = text.gsub InlineLinkRx do
        if (target = $2 + ($3 || $5)).start_with? RS
          # honor the escape
          next ($&.slice 0, (rs_idx = $1.length)) + ($&.slice rs_idx + 1, $&.length)
        end

        prefix, suffix = $1, ''
        # NOTE if $4 is set, we're looking at a formal macro (e.g., https://example.org[])
        if $4
          prefix = '' if prefix == 'link:'
          link_text = nil if (link_text = $4).empty?
        else
          # invalid macro syntax (link: prefix w/o trailing square brackets or enclosed in double quotes)
          # FIXME we probably shouldn't even get here when the link: prefix is present; the regex is doing too much
          case prefix
          when 'link:', ?", ?'
            next $&
          end
          case $6
          when ';'
            if (prefix.start_with? '&lt;') && (target.end_with? '&gt;')
              # move surrounding <> out of URL
              prefix = prefix.slice 4, prefix.length
              target = target.slice 0, target.length - 4
            elsif (target = target.chop).end_with? ')'
              # move trailing ); out of URL
              target = target.chop
              suffix = ');'
            else
              # move trailing ; out of URL
              suffix = ';'
            end
            # NOTE handle case when modified target is a URI scheme (e.g., http://)
            next $& if target.end_with? '://'
          when ':'
            if (target = target.chop).end_with? ')'
              # move trailing ): out of URL
              target = target.chop
              suffix = '):'
            else
              # move trailing : out of URL
              suffix = ':'
            end
            # NOTE handle case when modified target is a URI scheme (e.g., http://)
            next $& if target.end_with? '://'
          end
        end

        attrs, link_opts = nil, { type: :link }

        if link_text
          new_link_text = link_text = link_text.gsub ESC_R_SB, R_SB if link_text.include? R_SB
          if !doc.compat_mode && (link_text.include? '=')
            # NOTE if an equals sign (=) is present, extract attributes from link text
            link_text, attrs = extract_attributes_from_text link_text, ''
            new_link_text = link_text
            link_opts[:id] = attrs['id']
          end

          if link_text.end_with? '^'
            new_link_text = link_text = link_text.chop
            if attrs
              attrs['window'] ||= '_blank'
            else
              attrs = { 'window' => '_blank' }
            end
          end

          if new_link_text && new_link_text.empty?
            # NOTE it's not possible for the URI scheme to be bare in this case
            link_text = (doc_attrs.key? 'hide-uri-scheme') ? (target.sub UriSniffRx, '') : target
            bare = true
          end
        else
          # NOTE it's not possible for the URI scheme to be bare in this case
          link_text = (doc_attrs.key? 'hide-uri-scheme') ? (target.sub UriSniffRx, '') : target
          bare = true
        end

        if bare
          if attrs
            attrs['role'] = (attrs.key? 'role') ? %(bare #{attrs['role']}) : 'bare'
          else
            attrs = { 'role' => 'bare' }
          end
        end

        doc.register :links, (link_opts[:target] = target)
        link_opts[:attributes] = attrs if attrs
        %(#{prefix}#{(Inline.new self, :anchor, link_text, link_opts).convert}#{suffix})
      end
    end

    if found_macroish && ((text.include? 'link:') || (text.include? 'ilto:'))
      # inline link macros, link:target[text]
      text = text.gsub InlineLinkMacroRx do
        # honor the escape
        if $&.start_with? RS
          next $&.slice 1, $&.length
        elsif (mailto = $1)
          target = 'mailto:' + (mailto_text = $2)
        else
          target = $2
        end
        attrs, link_opts = nil, { type: :link }
        unless (link_text = $3).empty?
          link_text = link_text.gsub ESC_R_SB, R_SB if link_text.include? R_SB
          if mailto
            if !doc.compat_mode && (link_text.include? ',')
              # NOTE if a comma (,) is present, extract attributes from link text
              link_text, attrs = extract_attributes_from_text link_text, ''
              link_opts[:id] = attrs['id']
              if attrs.key? 2
                if attrs.key? 3
                  target = %(#{target}?subject=#{Helpers.encode_uri_component attrs[2]}&amp;body=#{Helpers.encode_uri_component attrs[3]})
                else
                  target = %(#{target}?subject=#{Helpers.encode_uri_component attrs[2]})
                end
              end
            end
          elsif !doc.compat_mode && (link_text.include? '=')
            # NOTE if an equals sign (=) is present, extract attributes from link text
            link_text, attrs = extract_attributes_from_text link_text, ''
            link_opts[:id] = attrs['id']
          end

          if link_text.end_with? '^'
            link_text = link_text.chop
            if attrs
              attrs['window'] ||= '_blank'
            else
              attrs = { 'window' => '_blank' }
            end
          end
        end

        if link_text.empty?
          # mailto is a special case, already processed
          if mailto
            link_text = mailto_text
          else
            if doc_attrs.key? 'hide-uri-scheme'
              if (link_text = target.sub UriSniffRx, '').empty?
                link_text = target
              end
            else
              link_text = target
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
        Inline.new(self, :anchor, link_text, link_opts).convert
      end
    end

    if text.include? '@'
      text = text.gsub InlineEmailRx do
        # honor the escape
        next $1 == RS ? ($&.slice 1, $&.length) : $& if $1

        target = 'mailto:' + (address = $&)
        # QUESTION should this be registered as an e-mail address?
        doc.register(:links, target)

        Inline.new(self, :anchor, address, type: :link, target: target).convert
      end
    end

    if found_square_bracket && @context == :list_item && @parent.style == 'bibliography'
      text = text.sub(InlineBiblioAnchorRx) { (Inline.new self, :anchor, $2, type: :bibref, id: $1).convert }
    end

    if (found_square_bracket && text.include?('[[')) || (found_macroish && text.include?('or:'))
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
        Inline.new(self, :anchor, reftext, type: :ref, id: id).convert
      end
    end

    #if (text.include? ';&l') || (found_macroish && (text.include? 'xref:'))
    if ((text.include? '&') && (text.include? ';&l')) || (found_macroish && (text.include? 'xref:'))
      text = text.gsub InlineXrefMacroRx do
        # honor the escape
        next $&.slice 1, $&.length if $&.start_with? RS

        attrs = {}
        if (refid = $1)
          if refid.include? ','
            refid, _, link_text = refid.partition ','
            link_text = nil if (link_text = link_text.lstrip).empty?
          end
        else
          macro = true
          refid = $2
          if (link_text = $3)
            link_text = link_text.gsub ESC_R_SB, R_SB if link_text.include? R_SB
            # NOTE if an equals sign (=) is present, extract attributes from link text
            link_text, attrs = extract_attributes_from_text link_text if !doc.compat_mode && (link_text.include? '=')
          end
        end

        if doc.compat_mode
          fragment = refid
        elsif (hash_idx = refid.index '#') && refid[hash_idx - 1] != '&'
          if hash_idx > 0
            if (fragment_len = refid.length - 1 - hash_idx) > 0
              path, fragment = (refid.slice 0, hash_idx), (refid.slice hash_idx + 1, fragment_len)
            else
              path = refid.chop
            end
            if macro
              if path.end_with? '.adoc'
                src2src = path = path.slice 0, path.length - 5
              elsif !(Helpers.extname? path)
                src2src = path
              end
            elsif path.end_with?(*ASCIIDOC_EXTENSIONS.keys)
              src2src = path = path.slice 0, (path.rindex '.')
            else
              src2src = path
            end
          else
            target, fragment = refid, (refid.slice 1, refid.length)
          end
        elsif macro
          if refid.end_with? '.adoc'
            src2src = path = refid.slice 0, refid.length - 5
          elsif Helpers.extname? refid
            path = refid
          else
            fragment = refid
          end
        else
          fragment = refid
        end

        # handles: #id
        if target
          refid = fragment
          logger.info %(possible invalid reference: #{refid}) if logger.info? && !doc.catalog[:refs][refid]
        elsif path
          # handles: path#, path#id, path.adoc#, path.adoc#id, or path.adoc (xref macro only)
          # the referenced path is the current document, or its contents have been included in the current document
          if src2src && (doc.attributes['docname'] == path || doc.catalog[:includes][path])
            if fragment
              refid, path, target = fragment, nil, %(##{fragment})
              logger.info %(possible invalid reference: #{refid}) if logger.info? && !doc.catalog[:refs][refid]
            else
              refid, path, target = nil, nil, '#'
            end
          else
            refid, path = path, %(#{doc.attributes['relfileprefix'] || ''}#{path}#{src2src ? (doc.attributes.fetch 'relfilesuffix', doc.outfilesuffix) : ''})
            if fragment
              refid, target = %(#{refid}##{fragment}), %(#{path}##{fragment})
            else
              target = path
            end
          end
        # handles: id (in compat mode or when natural xrefs are disabled)
        elsif doc.compat_mode || !Compliance.natural_xrefs
          refid, target = fragment, %(##{fragment})
          logger.info %(possible invalid reference: #{refid}) if logger.info? && !doc.catalog[:refs][refid]
        # handles: id
        elsif doc.catalog[:refs][fragment]
          refid, target = fragment, %(##{fragment})
        # handles: Node Title or Reference Text
        # do reverse lookup on fragment if not a known ID and resembles reftext (contains a space or uppercase char)
        elsif ((fragment.include? ' ') || fragment.downcase != fragment) && (refid = doc.resolve_id fragment)
          fragment, target = refid, %(##{refid})
        else
          refid, target = fragment, %(##{fragment})
          logger.info %(possible invalid reference: #{refid}) if logger.info?
        end
        attrs['path'] = path
        attrs['fragment'] = fragment
        attrs['refid'] = refid
        Inline.new(self, :anchor, link_text, type: :xref, target: target, attributes: attrs).convert
      end
    end

    if found_macroish && (text.include? 'tnote')
      text = text.gsub InlineFootnoteMacroRx do
        # honor the escape
        next $&.slice 1, $&.length if $&.start_with? RS

        # footnoteref
        if $1
          if $3
            id, content = $3.split ',', 2
            logger.warn %(found deprecated footnoteref macro: #{$&}; use footnote macro with target instead) unless doc.compat_mode
          else
            next $&
          end
        # footnote
        else
          id = $2
          content = $3
        end

        if id
          if (footnote = doc.footnotes.find {|candidate| candidate.id == id })
            index, content = footnote.index, footnote.text
            type, target, id = :xref, id, nil
          elsif content
            content = restore_passthroughs(normalize_text content, true, true)
            index = doc.counter('footnote-number')
            doc.register(:footnotes, Document::Footnote.new(index, id, content))
            type, target = :ref, nil
          else
            logger.warn %(invalid footnote reference: #{id})
            type, target, content, id = :xref, id, id, nil
          end
        elsif content
          content = restore_passthroughs(normalize_text content, true, true)
          index = doc.counter('footnote-number')
          doc.register(:footnotes, Document::Footnote.new(index, id, content))
          type = target = nil
        else
          next $&
        end
        Inline.new(self, :footnote, content, attributes: { 'index' => index }, id: id, target: target, type: type).convert
      end
    end

    text
  end

  # Public: Substitute post replacements
  #
  # text - The String text to process
  #
  # Returns the converted String text
  def sub_post_replacements text
    #if attr? 'hardbreaks-option', nil, true
    if @attributes['hardbreaks-option'] || @document.attributes['hardbreaks-option']
      lines = text.split LF, -1
      return text if lines.size < 2
      last = lines.pop
      (lines.map do |line|
        Inline.new(self, :break, (line.end_with? HARD_LINE_BREAK) ? (line.slice 0, line.length - 2) : line, type: :line).convert
      end << last).join LF
    elsif (text.include? PLUS) && (text.include? HARD_LINE_BREAK)
      text.gsub(HardLineBreakRx) { Inline.new(self, :break, $1, type: :line).convert }
    else
      text
    end
  end

  # Public: Apply verbatim substitutions on source (for use when highlighting is disabled).
  #
  # source - the source code String on which to apply verbatim substitutions
  # process_callouts - a Boolean flag indicating whether callout marks should be substituted
  #
  # Returns the substituted source
  def sub_source source, process_callouts
    process_callouts ? sub_callouts(sub_specialchars source) : (sub_specialchars source)
  end

  # Public: Substitute callout source references
  #
  # text - The String text to process
  #
  # Returns the converted String text
  def sub_callouts text
    callout_rx = (attr? 'line-comment') ? CalloutSourceRxMap[attr 'line-comment'] : CalloutSourceRx
    autonum = 0
    text.gsub callout_rx do
      # honor the escape
      if $2
        # use sub since it might be behind a line comment
        $&.sub RS, ''
      else
        Inline.new(self, :callout, $4 == '.' ? (autonum += 1).to_s : $4, id: @document.callouts.read_next_id, attributes: { 'guard' => $1 || ($3 == '--' ? ['<!--', '-->'] : nil) }).convert
      end
    end
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
  # verbatim substitutions applied
  def highlight_source source, process_callouts
    # NOTE the call to highlight? is a defensive check since, normally, we wouldn't arrive here unless it returns true
    return sub_source source, process_callouts unless (syntax_hl = @document.syntax_highlighter) && syntax_hl.highlight?

    source, callout_marks = extract_callouts source if process_callouts

    doc_attrs = @document.attributes
    syntax_hl_name = syntax_hl.name
    if (linenums_mode = (attr? 'linenums') ? (doc_attrs[%(#{syntax_hl_name}-linenums-mode)] || :table).to_sym : nil) &&
        (start_line_number = (attr 'start', 1).to_i) < 1
      start_line_number = 1
    end
    highlight_lines = resolve_lines_to_highlight source, (attr 'highlight'), start_line_number if attr? 'highlight'

    highlighted, source_offset = syntax_hl.highlight self, source, (attr 'language'),
      callouts: callout_marks,
      css_mode: (doc_attrs[%(#{syntax_hl_name}-css)] || :class).to_sym,
      highlight_lines: highlight_lines,
      number_lines: linenums_mode,
      start_line_number: start_line_number,
      style: doc_attrs[%(#{syntax_hl_name}-style)]

    # fix passthrough placeholders that got caught up in syntax highlighting
    highlighted = highlighted.gsub HighlightedPassSlotRx, %(#{PASS_START}\\1#{PASS_END}) unless @passthroughs.empty?

    # NOTE highlight method may have depleted callouts
    callout_marks.nil_or_empty? ? highlighted : (restore_callouts highlighted, callout_marks, source_offset)
  end

  # Public: Resolve the line numbers in the specified source to highlight from the provided spec.
  #
  # e.g., highlight="1-5, !2, 10" or highlight=1-5;!2,10
  #
  # source - The String source.
  # spec   - The lines specifier (e.g., "1-5, !2, 10" or "1..5;!2;10")
  # start  - The line number of the first line (optional, default: false)
  #
  # Returns an [Array] of unique, sorted line numbers.
  def resolve_lines_to_highlight source, spec, start = nil
    lines = []
    spec = spec.delete ' ' if spec.include? ' '
    ((spec.include? ',') ? (spec.split ',') : (spec.split ';')).map do |entry|
      if entry.start_with? '!'
        entry = entry.slice 1, entry.length
        negate = true
      end
      if (delim = (entry.include? '..') ? '..' : ((entry.include? '-') ? '-' : nil))
        from, _, to = entry.partition delim
        to = (source.count LF) + 1 if to.empty? || (to = to.to_i) < 0
        if negate
          lines -= (from.to_i..to).to_a
        else
          lines |= (from.to_i..to).to_a
        end
      elsif negate
        lines.delete entry.to_i
      elsif !lines.include?(line = entry.to_i)
        lines << line
      end
    end
    # If the start attribute is defined, then the lines to highlight specified by the provided spec should be relative to the start value.
    unless (shift = start ? start - 1 : 0) == 0
      lines = lines.map {|it| it - shift }
    end
    lines.sort
  end

  # Public: Extract the passthrough text from the document for reinsertion after processing.
  #
  # text - The String from which to extract passthrough fragments
  #
  # Returns the String text with passthrough regions substituted with placeholders
  def extract_passthroughs text
    compat_mode = @document.compat_mode
    passthrus = @passthroughs
    text = text.gsub InlinePassMacroRx do
      if (boundary = $4) # $$, ++, or +++
        # skip ++ in compat mode, handled as normal quoted text
        next %(#{$2 ? "#{$1}[#{$2}]#{$3}" : "#{$1}#{$3}"}++#{extract_passthroughs $5}++) if compat_mode && boundary == '++'

        if (attrlist = $2)
          if (escape_count = $3.length) > 0
            # NOTE we don't look for nested unconstrained pass macros
            next %(#{$1}[#{attrlist}]#{RS * (escape_count - 1)}#{boundary}#{$5}#{boundary})
          elsif $1 == RS
            preceding = %([#{attrlist}])
          elsif boundary == '++'
            if attrlist == 'x-'
              old_behavior = true
              attributes = {}
            elsif attrlist.end_with? ' x-'
              old_behavior = true
              attributes = parse_quoted_text_attributes attrlist.slice 0, attrlist.length - 3
            else
              attributes = parse_quoted_text_attributes attrlist
            end
          else
            attributes = parse_quoted_text_attributes attrlist
          end
        elsif (escape_count = $3.length) > 0
          # NOTE we don't look for nested unconstrained pass macros
          next %(#{RS * (escape_count - 1)}#{boundary}#{$5}#{boundary})
        end
        subs = (boundary == '+++' ? [] : BASIC_SUBS)

        if attributes
          if old_behavior
            passthrus[passthru_key = passthrus.size] = { text: $5, subs: NORMAL_SUBS, type: :monospaced, attributes: attributes }
          else
            passthrus[passthru_key = passthrus.size] = { text: $5, subs: subs, type: :unquoted, attributes: attributes }
          end
        else
          passthrus[passthru_key = passthrus.size] = { text: $5, subs: subs }
        end
      else # pass:[]
        # NOTE we don't look for nested pass:[] macros
        # honor the escape
        next $&.slice 1, $&.length if $6 == RS
        if (subs = $7)
          passthrus[passthru_key = passthrus.size] = { text: (normalize_text $8, nil, true), subs: (resolve_pass_subs subs) }
        else
          passthrus[passthru_key = passthrus.size] = { text: (normalize_text $8, nil, true) }
        end
      end

      %(#{preceding || ''}#{PASS_START}#{passthru_key}#{PASS_END})
    end if (text.include? '++') || (text.include? '$$') || (text.include? 'ss:')

    pass_inline_char1, pass_inline_char2, pass_inline_rx = InlinePassRx[compat_mode]
    text = text.gsub pass_inline_rx do
      preceding = $1
      attrlist = $4 || $3
      escaped = true if $5
      quoted_text = $6
      format_mark = $7
      content = $8

      if compat_mode
        old_behavior = true
      elsif attrlist && (attrlist == 'x-' || (attrlist.end_with? ' x-'))
        old_behavior = old_behavior_forced = true
      end

      if attrlist
        if escaped
          # honor the escape of the formatting mark
          next %(#{preceding}[#{attrlist}]#{quoted_text.slice 1, quoted_text.length})
        elsif preceding == RS
          # honor the escape of the attributes
          next %(#{preceding}[#{attrlist}]#{quoted_text}) if old_behavior_forced && format_mark == '`'
          preceding = %([#{attrlist}])
        elsif old_behavior_forced
          attributes = attrlist == 'x-' ? {} : (parse_quoted_text_attributes attrlist.slice 0, attrlist.length - 3)
        else
          attributes = parse_quoted_text_attributes attrlist
        end
      elsif escaped
        # honor the escape of the formatting mark
        next %(#{preceding}#{quoted_text.slice 1, quoted_text.length})
      elsif compat_mode && preceding == RS
        next quoted_text
      end

      if compat_mode
        passthrus[passthru_key = passthrus.size] = { text: content, subs: BASIC_SUBS, attributes: attributes, type: :monospaced }
      elsif attributes
        if old_behavior
          subs = format_mark == '`' ? BASIC_SUBS : NORMAL_SUBS
          passthrus[passthru_key = passthrus.size] = { text: content, subs: subs, attributes: attributes, type: :monospaced }
        else
          passthrus[passthru_key = passthrus.size] = { text: content, subs: BASIC_SUBS, attributes: attributes, type: :unquoted }
        end
      else
        passthrus[passthru_key = passthrus.size] = { text: content, subs: BASIC_SUBS }
      end

      %(#{preceding}#{PASS_START}#{passthru_key}#{PASS_END})
    end if (text.include? pass_inline_char1) || (pass_inline_char2 && (text.include? pass_inline_char2))

    # NOTE we need to do the stem in a subsequent step to allow it to be escaped by the former
    text = text.gsub InlineStemMacroRx do
      # honor the escape
      next $&.slice 1, $&.length if $&.start_with? RS

      if (type = $1.to_sym) == :stem
        type = STEM_TYPE_ALIASES[@document.attributes['stem']].to_sym
      end
      subs = $2
      content = normalize_text $3, nil, true
      # NOTE drop enclosing $ signs around latexmath for backwards compatibility with AsciiDoc.py
      content = content.slice 1, content.length - 2 if type == :latexmath && (content.start_with? '$') && (content.end_with? '$')
      subs = subs ? (resolve_pass_subs subs) : ((@document.basebackend? 'html') ? BASIC_SUBS : nil)
      passthrus[passthru_key = passthrus.size] = { text: content, subs: subs, type: type }
      %(#{PASS_START}#{passthru_key}#{PASS_END})
    end if (text.include? ':') && ((text.include? 'stem:') || (text.include? 'math:'))

    text
  end

  # Public: Restore the passthrough text by reinserting into the placeholder positions
  #
  # text  - The String text into which to restore the passthrough text
  #
  # returns The String text with the passthrough text restored
  def restore_passthroughs text
    passthrus = @passthroughs
    text.gsub PassSlotRx do
      if (pass = passthrus[$1.to_i])
        subbed_text = apply_subs(pass[:text], pass[:subs])
        if (type = pass[:type])
          if (attributes = pass[:attributes])
            id = attributes['id']
          end
          subbed_text = Inline.new(self, :quoted, subbed_text, type: type, id: id, attributes: attributes).convert
        end
        subbed_text.include?(PASS_START) ? restore_passthroughs(subbed_text) : subbed_text
      else
        logger.error %(unresolved passthrough detected: #{text})
        '??pass??'
      end
    end
  end

  # Public: Resolve the list of comma-delimited subs against the possible options.
  #
  # subs     - The comma-delimited String of substitution names or aliases.
  # type     - A Symbol representing the context for which the subs are being resolved (default: :block).
  # defaults - An Array of substitutions to start with when computing incremental substitutions (default: nil).
  # subject  - The String to use in log messages to communicate the subject for which subs are being resolved (default: nil)
  #
  # Returns An Array of Symbols representing the substitution operation or nothing if no subs are found.
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
    # weed out invalid options and remove duplicates (order is preserved; first occurrence wins)
    resolved = candidates & SUB_OPTIONS[type]
    unless (candidates - resolved).empty?
      invalid = candidates - resolved
      logger.warn %(invalid substitution type#{invalid.size > 1 ? 's' : ''}#{subject ? ' for ' : ''}#{subject}: #{invalid.join ', '})
    end
    resolved
  end

  # Public: Call resolve_subs for the :block type.
  def resolve_block_subs subs, defaults, subject
    resolve_subs subs, :block, defaults, subject
  end

  # Public: Call resolve_subs for the :inline type with the subject set as passthrough macro.
  def resolve_pass_subs subs
    resolve_subs subs, :inline, nil, 'passthrough macro'
  end

  # Public: Expand all groups in the subs list and return. If no subs are resolved, return nil.
  #
  # subs - The substitutions to expand; can be a Symbol, Symbol Array, or String
  # subject - The String to use in log messages to communicate the subject for which subs are being resolved (default: nil)
  #
  # Returns a Symbol Array of substitutions to pass to apply_subs or nil if no substitutions were resolved.
  def expand_subs subs, subject = nil
    case subs
    when ::Symbol
      subs == :none ? nil : SUB_GROUPS[subs] || [subs]
    when ::Array
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
    else
      resolve_subs subs, :inline, nil, subject
    end
  end

  # Internal: Commit the requested substitutions to this block.
  #
  # Looks for an attribute named "subs". If present, resolves substitutions
  # from the value of that attribute and assigns them to the subs property on
  # this block. Otherwise, uses the substitutions assigned to the default_subs
  # property, if specified, or selects a default set of substitutions based on
  # the content model of the block.
  #
  # Returns nothing
  def commit_subs
    unless (default_subs = @default_subs)
      case @content_model
      when :simple
        default_subs = NORMAL_SUBS
      when :verbatim
        # NOTE :literal with listparagraph-option gets folded into text of list item later
        default_subs = @context == :verse ? NORMAL_SUBS : VERBATIM_SUBS
      when :raw
        # TODO make pass subs a compliance setting; AsciiDoc.py performs :attributes and :macros on a pass block
        default_subs = @context == :stem ? BASIC_SUBS : NO_SUBS
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

    nil
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
    return {} if attrlist ? attrlist.empty? : true
    attrlist = normalize_text attrlist, true, true if opts[:unescape_input]
    attrlist = @document.sub_attributes attrlist if opts[:sub_input] && (attrlist.include? ATTR_REF_HEAD)
    # substitutions are only performed on attribute values if block is not nil
    block = self if opts[:sub_result]
    if (into = opts[:into])
      AttributeList.new(attrlist, block).parse_into(into, posattrs)
    else
      AttributeList.new(attrlist, block).parse(posattrs)
    end
  end

  private

  # This method is used in cases when the attrlist can be mixed with the text of a macro.
  # If no attributes are detected aside from the first positional attribute, and the first positional
  # attribute matches the attrlist, then the original text is returned.
  def extract_attributes_from_text text, default_text = nil
    attrlist = (text.include? LF) ? (text.tr LF, ' ') : text
    if (resolved_text = (attrs = (AttributeList.new attrlist, self).parse)[1])
      # NOTE if resolved text remains unchanged, clear attributes and return unparsed text
      resolved_text == attrlist ? [text, attrs.clear] : [resolved_text, attrs]
    else
      [default_text, attrs]
    end
  end

  # Internal: Extract the callout numbers from the source to prepare it for syntax highlighting.
  def extract_callouts source
    callout_marks = {}
    autonum = lineno = 0
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
          (callout_marks[lineno] ||= []) << [$1 || ($3 == '--' ? ['<!--', '-->'] : nil), $4 == '.' ? (autonum += 1).to_s : $4]
          last_lineno = lineno
          ''
        end
      end
    end.join LF
    if last_lineno
      source = %(#{source}#{LF}) if last_lineno == lineno
    else
      callout_marks = nil
    end
    [source, callout_marks]
  end

  # Internal: Restore the callout numbers to the highlighted source.
  def restore_callouts source, callout_marks, source_offset = nil
    if source_offset
      preamble = source.slice 0, source_offset
      source = source.slice source_offset, source.length
    else
      preamble = ''
    end
    lineno = 0
    preamble + ((source.split LF, -1).map do |line|
      if (conums = callout_marks.delete lineno += 1)
        if conums.size == 1
          guard, numeral = conums[0]
          %(#{line}#{Inline.new(self, :callout, numeral, id: @document.callouts.read_next_id, attributes: { 'guard' => guard }).convert})
        else
          %(#{line}#{conums.map do |guard_it, numeral_it|
            Inline.new(self, :callout, numeral_it, id: @document.callouts.read_next_id, attributes: { 'guard' => guard_it }).convert
          end.join ' '})
        end
      else
        line
      end
    end.join LF)
  end

  # Internal: Convert a quoted text region
  #
  # match  - The MatchData for the quoted text region
  # type   - The quoting type (single, double, strong, emphasis, monospaced, etc)
  # scope  - The scope of the quoting (constrained or unconstrained)
  #
  # Returns The converted String text for the quoted text region
  def convert_quoted_text match, type, scope
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
          id = (attributes = parse_quoted_text_attributes attrlist)['id']
          type = :unquoted if type == :mark
        end
        %(#{match[1]}#{Inline.new(self, :quoted, match[3], type: type, id: id, attributes: attributes).convert})
      end
    else
      if (attrlist = match[1])
        id = (attributes = parse_quoted_text_attributes attrlist)['id']
        type = :unquoted if type == :mark
      end
      Inline.new(self, :quoted, match[2], type: type, id: id, attributes: attributes).convert
    end
  end

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
        m[1] + replacement + m[2]
      else # :leading
        m[1] + replacement
      end
    end
  end

  # Internal: Inserts text into a formatted text enclosure; used by xreftext
  alias sub_placeholder sprintf unless RUBY_ENGINE == 'opal'

  # Internal: Parse the attributes that are defined on quoted (aka formatted) text
  #
  # str - A non-nil String of unprocessed attributes;
  #       space-separated roles (e.g., role1 role2) or the id/role shorthand syntax (e.g., #idname.role)
  #
  # Returns a Hash of attributes (role and id only)
  def parse_quoted_text_attributes str
    # NOTE attributes are typically resolved after quoted text, so substitute eagerly
    str = sub_attributes str if str.include? ATTR_REF_HEAD
    # for compliance, only consider first positional attribute (very unlikely)
    str = str.slice 0, (str.index ',') if str.include? ','
    if (str = str.strip).empty?
      {}
    elsif (str.start_with? '.', '#') && Compliance.shorthand_property_syntax
      before, _, after = str.partition '#'
      attrs = {}
      if after.empty?
        attrs['role'] = (before.tr '.', ' ').lstrip if before.length > 1
      else
        id, _, roles = after.partition '.'
        attrs['id'] = id unless id.empty?
        if roles.empty?
          attrs['role'] = (before.tr '.', ' ').lstrip if before.length > 1
        elsif before.length > 1
          attrs['role'] = ((before + '.' + roles).tr '.', ' ').lstrip
        else
          attrs['role'] = roles.tr '.', ' '
        end
      end
      attrs
    else
      { 'role' => str }
    end
  end

  # Internal: Normalize text to prepare it for parsing.
  #
  # If normalize_whitespace is true, strip surrounding whitespace and fold newlines. If unescape_closing_square_bracket
  # is set, unescape any escaped closing square brackets.
  #
  # Returns the normalized text String
  def normalize_text text, normalize_whitespace = nil, unescape_closing_square_brackets = nil
    unless text.empty?
      text = text.strip.tr LF, ' ' if normalize_whitespace
      text = text.gsub ESC_R_SB, R_SB if unescape_closing_square_brackets && (text.include? R_SB)
    end
    text
  end

  # Internal: Split text formatted as CSV with support
  # for double-quoted values (in which commas are ignored)
  def split_simple_csv str
    if str.empty?
      []
    elsif str.include? '"'
      values = []
      accum = ''
      quote_open = nil
      str.each_char do |c|
        case c
        when ','
          if quote_open
            accum += c
          else
            values << accum.strip
            accum = ''
          end
        when '"'
          quote_open = !quote_open
        else
          accum += c
        end
      end
      values << accum.strip
    else
      str.split(',').map {|it| it.strip }
    end
  end
end
end
