# frozen_string_literal: true
module Asciidoctor
  # A collection of regular expression constants used by the parser. (For speed, these are not defined in the Rx module,
  # but rather directly in the Asciidoctor module).
  #
  # NOTE The following pattern, which appears frequently, captures the contents between square brackets, ignoring
  # escaped closing brackets (closing brackets prefixed with a backslash '\' character)
  #
  #   Pattern: \[(|#{CC_ALL}*?[^\\])\]
  #   Matches: [enclosed text] and [enclosed [text\]], not [enclosed text \\] or [\\] (as these require a trailing space)
  module Rx; end

  ## Document header

  # Matches the author info line immediately following the document title.
  #
  # Examples
  #
  #   Doc Writer <doc@example.com>
  #   Mary_Sue Brontë
  #
  AuthorInfoLineRx = /^(#{CG_WORD}[#{CC_WORD}\-'.]*)(?: +(#{CG_WORD}[#{CC_WORD}\-'.]*))?(?: +(#{CG_WORD}[#{CC_WORD}\-'.]*))?(?: +<([^>]+)>)?$/

  # Matches the delimiter that separates multiple authors.
  #
  # Examples
  #
  #   Doc Writer; Junior Writer
  #
  AuthorDelimiterRx = /;(?: |$)/

  # Matches the revision info line, which appears immediately following
  # the author info line beneath the document title.
  #
  # Examples
  #
  #   v1.0
  #   2013-01-01
  #   v1.0, 2013-01-01: Ring in the new year release
  #   1.0, Jan 01, 2013
  #
  RevisionInfoLineRx = /^(?:[^\d{]*(#{CC_ANY}*?),)? *(?!:)(#{CC_ANY}*?)(?: *(?!^),?: *(#{CC_ANY}*))?$/

  # Matches the title and volnum in the manpage doctype.
  #
  # Examples
  #
  #   = asciidoctor(1)
  #   = asciidoctor ( 1 )
  #
  ManpageTitleVolnumRx = /^(#{CC_ANY}+?) *\( *(#{CC_ANY}+?) *\)$/

  # Matches the name and purpose in the manpage doctype.
  #
  # Examples
  #
  #   asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats
  #
  ManpageNamePurposeRx = /^(#{CC_ANY}+?) +- +(#{CC_ANY}+)$/

  ## Preprocessor directives

  # Matches a conditional preprocessor directive (e.g., ifdef, ifndef, ifeval and endif).
  #
  # Examples
  #
  #   ifdef::basebackend-html[]
  #   ifndef::theme[]
  #   ifeval::["{asciidoctor-version}" >= "0.1.0"]
  #   ifdef::asciidoctor[Asciidoctor!]
  #   endif::theme[]
  #   endif::basebackend-html[]
  #   endif::[]
  #
  ConditionalDirectiveRx = /^(\\)?(ifdef|ifndef|ifeval|endif)::(\S*?(?:([,+])\S*?)?)\[(#{CC_ANY}+)?\]$/

  # Matches a restricted (read as safe) eval expression.
  #
  # Examples
  #
  #   "{asciidoctor-version}" >= "0.1.0"
  #
  EvalExpressionRx = /^(#{CC_ANY}+?) *([=!><]=|[><]) *(#{CC_ANY}+)$/

  # Matches an include preprocessor directive.
  #
  # Examples
  #
  #   include::chapter1.ad[]
  #   include::example.txt[lines=1;2;5..10]
  #
  IncludeDirectiveRx = /^(\\)?include::([^\s\[](?:[^\[]*[^\s\[])?)\[(#{CC_ANY}+)?\]$/

  # Matches a trailing tag directive in an include file.
  #
  # Examples
  #
  #   // tag::try-catch[]
  #   try {
  #     someMethod();
  #   catch (Exception e) {
  #     log(e);
  #   }
  #   // end::try-catch[]
  # NOTE m flag is required for Asciidoctor.js
  TagDirectiveRx = /\b(?:tag|(e)nd)::(\S+?)\[\](?=$|[ \r])/m

  ## Attribute entries and references

  # Matches a document attribute entry.
  #
  # Examples
  #
  #   :foo: bar
  #   :First Name: Dan
  #   :sectnums!:
  #   :!toc:
  #   :long-entry: Attribute value lines ending in ' \' \
  #                are joined together as a single value, \
  #                collapsing the line breaks and indentation to \
  #                a single space.
  #
  AttributeEntryRx = /^:(!?#{CG_WORD}[^:]*):(?:[ \t]+(#{CC_ANY}*))?$/

  # Matches invalid characters in an attribute name.
  InvalidAttributeNameCharsRx = /[^#{CC_WORD}-]/

  # Matches a pass inline macro that surrounds the value of an attribute
  # entry once it has been parsed.
  #
  # Examples
  #
  #   pass:[text]
  #   pass:a[{a} {b} {c}]
  #
  if RUBY_ENGINE == 'opal'
    # NOTE In JavaScript, ^ and $ match the boundaries of the string when the m flag is not set
    AttributeEntryPassMacroRx = /^pass:([a-z]+(?:,[a-z-]+)*)?\[(#{CC_ALL}*)\]$/
  else
    AttributeEntryPassMacroRx = /\Apass:([a-z]+(?:,[a-z-]+)*)?\[(.*)\]\Z/m
  end

  # Matches an inline attribute reference.
  #
  # Examples
  #
  #   {foobar} or {app_name} or {product-version}
  #   {counter:sequence-name:1}
  #   {set:foo:bar}
  #   {set:name!}
  #
  AttributeReferenceRx = /(\\)?\{(#{CG_WORD}[#{CC_WORD}-]*|(set|counter2?):#{CC_ANY}+?)(\\)?\}/

  ## Paragraphs and delimited blocks

  # Matches an anchor (i.e., id + optional reference text) on a line above a block.
  #
  # Examples
  #
  #   [[idname]]
  #   [[idname,Reference Text]]
  #
  BlockAnchorRx = /^\[\[(?:|([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)(?:, *(#{CC_ANY}+))?)\]\]$/

  # Matches an attribute list above a block element.
  #
  # Examples
  #
  #   # strictly positional
  #   [quote, Adam Smith, Wealth of Nations]
  #
  #   # name/value pairs
  #   [NOTE, caption="Good to know"]
  #
  #   # as attribute reference
  #   [{lead}]
  #
  BlockAttributeListRx = /^\[(|[#{CC_WORD}.#%{,"']#{CC_ANY}*)\]$/

  # A combined pattern that matches either a block anchor or a block attribute list.
  #
  # TODO this one gets hit a lot, should be optimized as much as possible
  BlockAttributeLineRx = /^\[(?:|[#{CC_WORD}.#%{,"']#{CC_ANY}*|\[(?:|[#{CC_ALPHA}_:][#{CC_WORD}\-:.]*(?:, *#{CC_ANY}+)?)\])\]$/

  # Matches a title above a block.
  #
  # Examples
  #
  #   .Title goes here
  #
  BlockTitleRx = /^\.(\.?[^ \t.]#{CC_ANY}*)$/

  # Matches an admonition label at the start of a paragraph.
  #
  # Examples
  #
  #   NOTE: Just a little note.
  #   TIP: Don't forget!
  #
  AdmonitionParagraphRx = /^(#{ADMONITION_STYLES.to_a.join '|'}):[ \t]+/

  # Matches a literal paragraph, which is a line of text preceded by at least one space.
  #
  # Examples
  #
  #   <SPACE>Foo
  #   <TAB>Foo
  LiteralParagraphRx = /^([ \t]+#{CC_ANY}*)$/

  # Matches a comment block.
  #
  # Examples
  #
  #   ////
  #   This is a block comment.
  #   It can span one or more lines.
  #   ////
  #CommentBlockRx = %r(^/{4,}$)

  # Matches a comment line.
  #
  # Examples
  #
  #   // note to author
  #
  #CommentLineRx = %r(^//(?=[^/]|$))

  ## Section titles

  # Matches an Atx (single-line) section title.
  #
  # Examples
  #
  #   == Foo
  #   // ^ a level 1 (h2) section title
  #
  #   == Foo ==
  #   // ^ also a level 1 (h2) section title
  #
  AtxSectionTitleRx = /^(=={0,5})[ \t]+(#{CC_ANY}+?)(?:[ \t]+\1)?$/

  # Matches an extended Atx section title that includes support for the Markdown variant.
  ExtAtxSectionTitleRx = /^(=={0,5}|#\#{0,5})[ \t]+(#{CC_ANY}+?)(?:[ \t]+\1)?$/

  # Matches the title only (first line) of an Setext (two-line) section title.
  # The title cannot begin with a dot and must have at least one alphanumeric character.
  SetextSectionTitleRx = /^((?!\.)#{CC_ANY}*?#{CG_ALNUM}#{CC_ANY}*)$/

  # Matches an anchor (i.e., id + optional reference text) inside a section title.
  #
  # Examples
  #
  #   Section Title [[idname]]
  #   Section Title [[idname,Reference Text]]
  #
  InlineSectionAnchorRx = / (\\)?\[\[([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)(?:, *(#{CC_ANY}+))?\]\]$/

  # Matches invalid ID characters in a section title.
  #
  # NOTE uppercase chars not included since expression is only run on a lowercase string
  InvalidSectionIdCharsRx = /<[^>]+>|&(?:[a-z][a-z]+\d{0,2}|#\d\d\d{0,4}|#x[\da-f][\da-f][\da-f]{0,3});|[^ #{CC_WORD}\-.]+?/

  # Matches an explicit section level style like sect1
  #
  SectionLevelStyleRx = /^sect\d$/

  ## Lists

  # Detects the start of any list item.
  #
  # NOTE we only have to check as far as the blank character because we know it means non-whitespace follows.
  # IMPORTANT if this regexp does not agree with the regexp for each list type, the parser will hang.
  AnyListRx = %r(^(?:[ \t]*(?:-|\*\**|\.\.*|\u2022|\d+\.|[a-zA-Z]\.|[IVXivx]+\))[ \t]|(?!//[^/])[ \t]*[^ \t]#{CC_ANY}*?(?::::{0,2}|;;)(?:$|[ \t])|<(?:\d+|\.)>[ \t]))

  # Matches an unordered list item (one level for hyphens, up to 5 levels for asterisks).
  #
  # Examples
  #
  #   * Foo
  #   - Foo
  #
  # NOTE we know trailing (.*) will match at least one character because we strip trailing spaces
  UnorderedListRx = /^[ \t]*(-|\*\**|\u2022)[ \t]+(#{CC_ANY}*)$/

  # Matches an ordered list item (explicit numbering or up to 5 consecutive dots).
  #
  # Examples
  #
  #   . Foo
  #   .. Foo
  #   1. Foo (arabic, default)
  #   a. Foo (loweralpha)
  #   A. Foo (upperalpha)
  #   i. Foo (lowerroman)
  #   I. Foo (upperroman)
  #
  # NOTE leading space match is not always necessary, but is used for list reader
  # NOTE we know trailing (.*) will match at least one character because we strip trailing spaces
  OrderedListRx = /^[ \t]*(\.\.*|\d+\.|[a-zA-Z]\.|[IVXivx]+\))[ \t]+(#{CC_ANY}*)$/

  # Matches the ordinals for each type of ordered list.
  OrderedListMarkerRxMap = {
    arabic: /\d+\./,
    loweralpha: /[a-z]\./,
    lowerroman: /[ivx]+\)/,
    upperalpha: /[A-Z]\./,
    upperroman: /[IVX]+\)/,
    #lowergreek: /[a-z]\]/,
  }

  # Matches a description list entry.
  #
  # Examples
  #
  #   foo::
  #   bar:::
  #   baz::::
  #   blah;;
  #
  #   # the term may be followed by a description on the same line...
  #
  #   foo:: The metasyntactic variable that commonly accompanies 'bar' (see also, <<bar>>).
  #
  #   # ...or on a separate line, which may optionally be indented
  #
  #   foo::
  #     The metasyntactic variable that commonly accompanies 'bar' (see also, <<bar>>).
  #
  #   # attribute references may be used in both the term and the description
  #
  #   {foo-term}:: {foo-desc}
  #
  # NOTE we know trailing (.*) will match at least one character because we strip trailing spaces
  # NOTE must skip line comment when looking for next list item inside list
  DescriptionListRx = %r(^(?!//[^/])[ \t]*([^ \t]#{CC_ANY}*?)(:::{0,2}|;;)(?:$|[ \t]+(#{CC_ANY}*)$))

  # Matches a sibling description list item (excluding the delimiter specified by the key).
  # NOTE must skip line comment when looking for sibling list item
  DescriptionListSiblingRx = {
    '::' => %r(^(?!//[^/])[ \t]*([^ \t]#{CC_ANY}*?[^:]|[^ \t:])(::)(?:$|[ \t]+(#{CC_ANY}*)$)),
    ':::' => %r(^(?!//[^/])[ \t]*([^ \t]#{CC_ANY}*?[^:]|[^ \t:])(:::)(?:$|[ \t]+(#{CC_ANY}*)$)),
    '::::' => %r(^(?!//[^/])[ \t]*([^ \t]#{CC_ANY}*?[^:]|[^ \t:])(::::)(?:$|[ \t]+(#{CC_ANY}*)$)),
    ';;' => %r(^(?!//[^/])[ \t]*([^ \t]#{CC_ANY}*?)(;;)(?:$|[ \t]+(#{CC_ANY}*)$))
  }

  # Matches a callout list item.
  #
  # Examples
  #
  #   <1> Explanation
  #
  # or
  #
  #   <.> Explanation with automatic number
  #
  # NOTE we know trailing (.*) will match at least one character because we strip trailing spaces
  CalloutListRx = /^<(\d+|\.)>[ \t]+(#{CC_ANY}*)$/

  # Matches a callout reference inside literal text.
  #
  # Examples
  #   <1> (optionally prefixed by //, #, -- or ;; line comment chars)
  #   <1> <2> (multiple callouts on one line)
  #   <!--1--> (for XML-based languages)
  #   <.> (auto-numbered)
  #
  # NOTE extract regexps are applied line-by-line, so we can use $ as end-of-line char
  CalloutExtractRx = %r(((?://|#|--|;;) ?)?(\\)?<!?(|--)(\d+|\.)\3>(?=(?: ?\\?<!?\3(?:\d+|\.)\3>)*$))
  CalloutExtractRxt = '(\\\\)?<()(\\d+|\\.)>(?=(?: ?\\\\?<(?:\\d+|\\.)>)*$)'
  CalloutExtractRxMap = ::Hash.new {|h, k| h[k] = /(#{k.empty? ? '' : "#{::Regexp.escape k} ?"})?#{CalloutExtractRxt}/ }
  # NOTE special characters have not been replaced when scanning
  CalloutScanRx = /\\?<!?(|--)(\d+|\.)\1>(?=(?: ?\\?<!?\1(?:\d+|\.)\1>)*#{CC_EOL})/
  # NOTE special characters have already been replaced when converting to an SGML format
  CalloutSourceRx = %r(((?://|#|--|;;) ?)?(\\)?&lt;!?(|--)(\d+|\.)\3&gt;(?=(?: ?\\?&lt;!?\3(?:\d+|\.)\3&gt;)*#{CC_EOL}))
  CalloutSourceRxt = "(\\\\)?&lt;()(\\d+|\\.)&gt;(?=(?: ?\\\\?&lt;(?:\\d+|\\.)&gt;)*#{CC_EOL})"
  CalloutSourceRxMap = ::Hash.new {|h, k| h[k] = /(#{k.empty? ? '' : "#{::Regexp.escape k} ?"})?#{CalloutSourceRxt}/ }

  # A Hash of regexps for lists used for dynamic access.
  ListRxMap = { ulist: UnorderedListRx, olist: OrderedListRx, dlist: DescriptionListRx, colist: CalloutListRx }

  ## Tables

  # Parses the column spec (i.e., colspec) for a table.
  #
  # Examples
  #
  #   1*h,2*,^3e
  #
  ColumnSpecRx = /^(?:(\d+)\*)?([<^>](?:\.[<^>]?)?|(?:[<^>]?\.)?[<^>])?(\d+%?|~)?([a-z])?$/

  # Parses the start and end of a cell spec (i.e., cellspec) for a table.
  #
  # Examples
  #
  #   2.3+<.>m
  #
  # FIXME use step-wise scan (or treetop) rather than this mega-regexp
  CellSpecStartRx = /^[ \t]*(?:(\d+(?:\.\d*)?|(?:\d*\.)?\d+)([*+]))?([<^>](?:\.[<^>]?)?|(?:[<^>]?\.)?[<^>])?([a-z])?$/
  CellSpecEndRx = /[ \t]+(?:(\d+(?:\.\d*)?|(?:\d*\.)?\d+)([*+]))?([<^>](?:\.[<^>]?)?|(?:[<^>]?\.)?[<^>])?([a-z])?$/

  # Block macros

  # Matches the custom block macro pattern.
  #
  # Examples
  #
  #   gist::123456[]
  #
  #--
  # NOTE we've relaxed the match for target to accommodate the short format (e.g., name::[attrlist])
  CustomBlockMacroRx = /^(#{CG_WORD}[#{CC_WORD}-]*)::(|\S|\S#{CC_ANY}*?\S)\[(#{CC_ANY}+)?\]$/

  # Matches an image, video or audio block macro.
  #
  # Examples
  #
  #   image::filename.png[Caption]
  #   video::http://youtube.com/12345[Cats vs Dogs]
  #
  BlockMediaMacroRx = /^(image|video|audio)::(\S|\S#{CC_ANY}*?\S)\[(#{CC_ANY}+)?\]$/

  # Matches the TOC block macro.
  #
  # Examples
  #
  #   toc::[]
  #   toc::[levels=2]
  #
  BlockTocMacroRx = /^toc::\[(#{CC_ANY}+)?\]$/

  ## Inline macros

  # Matches an anchor (i.e., id + optional reference text) in the flow of text.
  #
  # Examples
  #
  #   [[idname]]
  #   [[idname,Reference Text]]
  #   anchor:idname[]
  #   anchor:idname[Reference Text]
  #
  InlineAnchorRx = /(\\)?(?:\[\[([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)(?:, *(#{CC_ANY}+?))?\]\]|anchor:([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)\[(?:\]|(#{CC_ANY}*?[^\\])\]))/

  # Scans for a non-escaped anchor (i.e., id + optional reference text) in the flow of text.
  InlineAnchorScanRx = /(?:^|[^\\\[])\[\[([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)(?:, *(#{CC_ANY}+?))?\]\]|(?:^|[^\\])anchor:([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)\[(?:\]|(#{CC_ANY}*?[^\\])\])/

  # Scans for a leading, non-escaped anchor (i.e., id + optional reference text).
  LeadingInlineAnchorRx = /^\[\[([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)(?:, *(#{CC_ANY}+?))?\]\]/

  # Matches a bibliography anchor at the start of the list item text (in a bibliography list).
  #
  # Examples
  #
  #   [[[Fowler_1997]]] Fowler M. ...
  #
  InlineBiblioAnchorRx = /^\[\[\[([#{CC_ALPHA}_:][#{CC_WORD}\-:.]*)(?:, *(#{CC_ANY}+?))?\]\]\]/

  # Matches an inline e-mail address.
  #
  #   doc.writer@example.com
  #
  InlineEmailRx = %r(([\\>:/])?#{CG_WORD}(?:&amp;|[#{CC_WORD}\-.%+])*@#{CG_ALNUM}[#{CC_ALNUM}_\-.]*\.[a-zA-Z]{2,5}\b)

  # Matches an inline footnote macro, which is allowed to span multiple lines.
  #
  # Examples
  #   footnote:[text] (not referenceable)
  #   footnote:id[text] (referenceable)
  #   footnote:id[] (reference)
  #   footnoteref:[id,text] (legacy)
  #   footnoteref:[id] (legacy)
  #
  InlineFootnoteMacroRx = %r(\\?footnote(?:(ref):|:([#{CC_WORD}-]+)?)\[(?:|(#{CC_ALL}*?[^\\]))\](?!</a>))m

  # Matches an image or icon inline macro.
  #
  # Examples
  #
  #   image:filename.png[Alt Text]
  #   image:http://example.com/images/filename.png[Alt Text]
  #   image:filename.png[More [Alt\] Text] (alt text becomes "More [Alt] Text")
  #   icon:github[large]
  #
  # NOTE be as non-greedy as possible by not allowing newline or left square bracket in target
  InlineImageMacroRx = /\\?i(?:mage|con):([^:\s\[](?:[^\n\[]*[^\s\[])?)\[(|#{CC_ALL}*?[^\\])\]/m

  # Matches an indexterm inline macro, which may span multiple lines.
  #
  # Examples
  #
  #   indexterm:[Tigers,Big cats]
  #   (((Tigers,Big cats)))
  #   indexterm2:[Tigers]
  #   ((Tigers))
  #
  InlineIndextermMacroRx = /\\?(?:(indexterm2?):\[(#{CC_ALL}*?[^\\])\]|\(\((#{CC_ALL}+?)\)\)(?!\)))/m

  # Matches either the kbd or btn inline macro.
  #
  # Examples
  #
  #   kbd:[F3]
  #   kbd:[Ctrl+Shift+T]
  #   kbd:[Ctrl+\]]
  #   kbd:[Ctrl,T]
  #   btn:[Save]
  #
  InlineKbdBtnMacroRx = /(\\)?(kbd|btn):\[(#{CC_ALL}*?[^\\])\]/m

  # Matches an implicit link and some of the link inline macro.
  #
  # Examples
  #
  #   https://github.com
  #   https://github.com[GitHub]
  #   <https://github.com>
  #   link:https://github.com[]
  #   "https://github.com[]"
  #   (https://github.com) <= parenthesis not included in autolink
  #
  InlineLinkRx = %r((^|link:|#{CG_BLANK}|&lt;|[>\(\)\[\];"'])(\\?(?:https?|file|ftp|irc)://)(?:([^\s\[\]]+)\[(|#{CC_ALL}*?[^\\])\]|([^\s\[\]<]*([^\s,.?!\[\]<\)]))))m

  # Match a link or e-mail inline macro.
  #
  # Examples
  #
  #   link:path[label]
  #   mailto:doc.writer@example.com[]
  #
  # NOTE be as non-greedy as possible by not allowing space or left square bracket in target
  InlineLinkMacroRx = /\\?(?:link|(mailto)):(|[^:\s\[][^\s\[]*)\[(|#{CC_ALL}*?[^\\])\]/m

  # Matches the name of a macro.
  #
  MacroNameRx = /^#{CG_WORD}[#{CC_WORD}-]*$/

  # Matches a stem (and alternatives, asciimath and latexmath) inline macro, which may span multiple lines.
  #
  # Examples
  #
  #   stem:[x != 0]
  #   asciimath:[x != 0]
  #   latexmath:[\sqrt{4} = 2]
  #
  InlineStemMacroRx = /\\?(stem|(?:latex|ascii)math):([a-z]+(?:,[a-z-]+)*)?\[(#{CC_ALL}*?[^\\])\]/m

  # Matches a menu inline macro.
  #
  # Examples
  #
  #   menu:File[Save As...]
  #   menu:Edit[]
  #   menu:View[Page Style > No Style]
  #   menu:View[Page Style, No Style]
  #
  InlineMenuMacroRx = /\\?menu:(#{CG_WORD}|[#{CC_WORD}&][^\n\[]*[^\s\[])\[ *(?:|(#{CC_ALL}*?[^\\]))\]/m

  # Matches an implicit menu inline macro.
  #
  # Examples
  #
  #   "File > New..."
  #
  InlineMenuRx = /\\?"([#{CC_WORD}&][^"]*?[ \n]+&gt;[ \n]+[^"]*)"/

  # Matches an inline passthrough, which may span multiple lines.
  #
  # Examples
  #
  #   +text+
  #   [x-]+text+
  #   [x-]`text`
  #   `text` (compat only)
  #   [role]`text` (compat only)
  #
  # NOTE we always capture the attributes so we know when to use compatible (i.e., legacy) behavior
  InlinePassRx = {
    false => ['+', '-]', /((?:^|[^#{CC_WORD};:\\])(?=(\[)|\+)|\\(?=\[)|(?=\\\+))(?:\2(x-|[^\]]+ x-)\]|(?:\[([^\]]+)\])?(?=(\\)?\+))(\5?(\+|`)(\S|\S#{CC_ALL}*?\S)\7)(?!#{CG_WORD})/m],
    true => ['`', nil, /(^|[^`#{CC_WORD}])(?:(\Z)()|\[([^\]]+)\](?=(\\))?)?(\5?(`)([^`\s]|[^`\s]#{CC_ALL}*?\S)\7)(?![`#{CC_WORD}])/m],
  }

  # Matches several variants of the passthrough inline macro, which may span multiple lines.
  #
  # Examples
  #
  #   +++text+++
  #   $$text$$
  #   pass:quotes[text]
  #
  # NOTE we have to support an empty pass:[] for compatibility with AsciiDoc.py
  InlinePassMacroRx = /(?:(?:(\\?)\[([^\]]+)\])?(\\{0,2})(\+\+\+?|\$\$)(#{CC_ALL}*?)\4|(\\?)pass:([a-z]+(?:,[a-z-]+)*)?\[(|#{CC_ALL}*?[^\\])\])/m

  # Matches an xref (i.e., cross-reference) inline macro, which may span multiple lines.
  #
  # Examples
  #
  #   <<id,reftext>>
  #   xref:id[reftext]
  #
  # NOTE special characters have already been escaped, hence the entity references
  # NOTE { is included in start characters to support target that begins with attribute reference in title content
  InlineXrefMacroRx = %r(\\?(?:&lt;&lt;([#{CC_WORD}#/.:{]#{CC_ALL}*?)&gt;&gt;|xref:([#{CC_WORD}#/.:{]#{CC_ALL}*?)\[(?:\]|(#{CC_ALL}*?[^\\])\])))m

  ## Layout

  # Matches a trailing + preceded by at least one space character,
  # which forces a hard line break (<br> tag in HTML output).
  #
  # NOTE AsciiDoc.py allows + to be preceded by TAB; Asciidoctor does not
  #
  # Examples
  #
  #   Humpty Dumpty sat on a wall, +
  #   Humpty Dumpty had a great fall.
  #
  if RUBY_ENGINE == 'opal'
    # NOTE In JavaScript, ^ and $ only match the start and end of line if the multiline flag is present
    HardLineBreakRx = /^(#{CC_ANY}*) \+$/m
  else
    # NOTE In Ruby, ^ and $ always match start and end of line
    HardLineBreakRx = /^(.*) \+$/
  end

  # Matches a Markdown horizontal rule.
  #
  # Examples
  #
  #   --- or - - -
  #   *** or * * *
  #   ___ or _ _ _
  #
  MarkdownThematicBreakRx = /^ {0,3}([-*_])( *)\1\2\1$/

  # Matches an AsciiDoc or Markdown horizontal rule or AsciiDoc page break.
  #
  # Examples
  #
  #   ''' (horizontal rule)
  #   <<< (page break)
  #   --- or - - - (horizontal rule, Markdown)
  #   *** or * * * (horizontal rule, Markdown)
  #   ___ or _ _ _ (horizontal rule, Markdown)
  #
  ExtLayoutBreakRx = /^(?:'{3,}|<{3,}|([-*_])( *)\1\2\1)$/

  ## General

  # Matches consecutive blank lines.
  #
  # Examples
  #
  #   one
  #
  #   two
  #
  BlankLineRx = /\n{2,}/

  # Matches a comma or semi-colon delimiter.
  #
  # Examples
  #
  #   one,two
  #   three;four
  #
  #DataDelimiterRx = /[,;]/

  # Matches whitespace (space, tab, newline) escaped by a backslash.
  #
  # Examples
  #
  #   three\ blind\ mice
  #
  EscapedSpaceRx = /\\([ \t\n])/

  # Detects if text is a possible candidate for the replacements substitution.
  #
  ReplaceableTextRx = /[&']|--|\.\.\.|\([CRT]M?\)/

  # Matches a whitespace delimiter, a sequence of spaces, tabs, and/or newlines.
  # Matches the parsing rules of %w strings in Ruby.
  #
  # Examples
  #
  #   one two	 three   four
  #   five	six
  #
  # TODO change to /(?<!\\)[ \t\n]+/ once lookbehind assertions are implemented in all modern browsers
  SpaceDelimiterRx = /([^\\])[ \t\n]+/

  # Matches a + or - modifier in a subs list
  #
  SubModifierSniffRx = /[+-]/

  # Matches one or more consecutive digits at the end of a line.
  #
  # Examples
  #
  #   docbook5
  #   html5
  #
  TrailingDigitsRx = /\d+$/

  # Detects strings that resemble URIs.
  #
  # Examples
  #   http://domain
  #   https://domain
  #   file:///path
  #   data:info
  #
  #   not c:/sample.adoc or c:\sample.adoc
  #
  if RUBY_ENGINE == 'opal'
    UriSniffRx = %r(^#{CG_ALPHA}[#{CC_ALNUM}.+-]+:/{0,2})
  else
    UriSniffRx = %r(\A#{CG_ALPHA}[#{CC_ALNUM}.+-]+:/{0,2})
  end

  # Detects XML tags
  XmlSanitizeRx = /<[^>]+>/
end
