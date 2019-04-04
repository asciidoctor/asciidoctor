# frozen_string_literal: true
require 'set'

# NOTE RUBY_ENGINE == 'opal' conditional blocks like this are filtered by the Opal preprocessor
if RUBY_ENGINE == 'opal'
  # this require is satisfied by the Asciidoctor.js build; it augments the Ruby environment for Asciidoctor.js
  require 'asciidoctor/js'
else
  autoload :Base64, 'base64'
  require 'cgi/util'
  autoload :OpenURI, 'open-uri'
  autoload :Pathname, 'pathname'
  autoload :StringScanner, 'strscan'
  autoload :URI, 'uri'
end

# Public: The main application interface (API) for Asciidoctor. This API provides methods to parse AsciiDoc content and
# convert it to various output formats using built-in or third-party converters or Tilt-supported templates.
#
# An AsciiDoc document can be as simple as a single line of content, though it more commonly starts with a document
# header that declares the document title and document attribute definitions. The document header is then followed by
# zero or more section titles, optionally nested, to organize the paragraphs, blocks, lists, etc. of the document.
#
# By default, the processor converts the AsciiDoc document to HTML 5 using a built-in converter. However, this behavior
# can be changed by specifying a different backend (e.g., +docbook+). A backend is a keyword for an output format (e.g.,
# DocBook). That keyword, in turn, is used to select a converter, which carries out the request to convert the document
# to that format.
#
# In addition to this API, Asciidoctor also provides a command-line interface (CLI) named +asciidoctor+ for converting
# AsciiDoc content. See the provided man(ual) page for usage and options.
#
# Examples
#
#   # Convert an AsciiDoc file
#   Asciidoctor.convert_file 'document.adoc', safe: :safe
#
#   # Convert an AsciiDoc string
#   puts Asciidoctor.convert "I'm using *Asciidoctor* version {asciidoctor-version}.", safe: :safe
#
#   # Convert an AsciiDoc file using Tilt-supported templates
#   Asciidoctor.convert_file 'document.adoc', safe: :safe, template_dir: '/path/to/templates'
#
#   # Parse an AsciiDoc file into a document object
#   doc = Asciidoctor.load_file 'document.adoc', safe: :safe
#
#   # Parse an AsciiDoc string into a document object
#   doc = Asciidoctor.load "= Document Title\n\nfirst paragraph\n\nsecond paragraph", safe: :safe
#
module Asciidoctor
  # alias the RUBY_ENGINE constant inside the Asciidoctor namespace and define a precomputed alias for runtime
  RUBY_ENGINE_OPAL = (RUBY_ENGINE = ::RUBY_ENGINE) == 'opal'

  module SafeMode
    # A safe mode level that disables any of the security features enforced
    # by Asciidoctor (Ruby is still subject to its own restrictions).
    UNSAFE = 0;

    # A safe mode level that closely parallels safe mode in AsciiDoc. This value
    # prevents access to files which reside outside of the parent directory of
    # the source file and disables any macro other than the include::[] directive.
    SAFE = 1;

    # A safe mode level that disallows the document from setting attributes
    # that would affect the conversion of the document, in addition to all the
    # security features of SafeMode::SAFE. For instance, this level forbids
    # changing the backend or source-highlighter using an attribute defined
    # in the source document header. This is the most fundamental level of
    # security for server deployments (hence the name).
    SERVER = 10;

    # A safe mode level that disallows the document from attempting to read
    # files from the file system and including the contents of them into the
    # document, in additional to all the security features of SafeMode::SERVER.
    # For instance, this level disallows use of the include::[] directive and the
    # embedding of binary content (data uri), stylesheets and JavaScripts
    # referenced by the document.(Asciidoctor and trusted extensions may still
    # be allowed to embed trusted content into the document).
    #
    # Since Asciidoctor is aiming for wide adoption, this level is the default
    # and is recommended for server deployments.
    SECURE = 20;

    # A planned safe mode level that disallows the use of passthrough macros and
    # prevents the document from setting any known attributes, in addition to all
    # the security features of SafeMode::SECURE.
    #
    # Please note that this level is not currently implemented (and therefore not
    # enforced)!
    #PARANOID = 100;

    @names_by_value = {}.tap {|accum| (constants false).each {|sym| accum[const_get sym, false] = sym.to_s.downcase } }

    def self.value_for_name name
      const_get name.upcase, false
    end

    def self.name_for_value value
      @names_by_value[value]
    end

    def self.names
      @names_by_value.values
    end
  end

  # Flags to control compliance with the behavior of AsciiDoc
  module Compliance
    @keys = ::Set.new
    class << self
      attr_reader :keys

      # Defines a new compliance key and assigns an initial value.
      def define key, value
        instance_variable_set %(@#{key}), value
        singleton_class.send :attr_accessor, key
        @keys << key
        nil
      end
    end

    # AsciiDoc terminates paragraphs adjacent to
    # block content (delimiter or block attribute list)
    # This option allows this behavior to be modified
    # TODO what about literal paragraph?
    # Compliance value: true
    define :block_terminates_paragraph, true

    # AsciiDoc does not parse paragraphs with a verbatim style
    # (i.e., literal, listing, source, verse) as verbatim content.
    # This options allows this behavior to be modified
    # Compliance value: false
    define :strict_verbatim_paragraphs, true

    # AsciiDoc supports both atx (single-line) and setext (underlined) section titles.
    # This option can be used to disable the setext variant.
    # Compliance value: true
    define :underline_style_section_titles, true

    # Asciidoctor will unwrap the content in a preamble
    # if the document has a title and no sections.
    # Compliance value: false
    define :unwrap_standalone_preamble, true

    # AsciiDoc drops lines that contain references to missing attributes.
    # This behavior is not intuitive to most writers.
    # Asciidoctor allows this behavior to be configured.
    # Possible options are 'skip', 'drop', 'drop-line', and 'warn'.
    # Compliance value: 'drop-line'
    define :attribute_missing, 'skip'

    # AsciiDoc drops lines that contain an attribute unassignemnt.
    # This behavior may need to be tuned depending on the circumstances.
    # Compliance value: 'drop-line'
    define :attribute_undefined, 'drop-line'

    # Asciidoctor will allow the id, role and options to be set
    # on blocks using a shorthand syntax (e.g., #idname.rolename%optionname)
    # Compliance value: false
    define :shorthand_property_syntax, true

    # Asciidoctor will attempt to resolve the target of a cross reference by
    # matching its reference text (reftext or title) (e.g., <<Section Title>>)
    # Compliance value: false
    define :natural_xrefs, true

    # Asciidoctor will start counting at the following number
    # when creating a unique id when there is a conflict
    # Compliance value: 2
    define :unique_id_start_index, 2

    # Asciidoctor will recognize commonly-used Markdown syntax
    # to the degree it does not interfere with existing
    # AsciiDoc syntax and behavior.
    # Compliance value: false
    define :markdown_syntax, true
  end

  # The absolute root directory of the Asciidoctor RubyGem
  ROOT_DIR = ::File.dirname ::File.absolute_path __dir__ unless defined? ROOT_DIR

  # The absolute lib directory of the Asciidoctor RubyGem
  LIB_DIR = ::File.join ROOT_DIR, 'lib'

  # The absolute data directory of the Asciidoctor RubyGem
  DATA_DIR = ::File.join ROOT_DIR, 'data'

  # The user's home directory, as best we can determine it
  # IMPORTANT this rescue is required for running Asciidoctor on GitHub.com
  USER_HOME = ::Dir.home rescue (::ENV['HOME'] || ::Dir.pwd)

  # The newline character used for output; stored in constant table as an optimization
  LF = ?\n

  # The null character to use for splitting attribute values
  NULL = ?\0

  # String for matching tab character
  TAB = ?\t

  # Maximum integer value for "boundless" operations; equal to MAX_SAFE_INTEGER in JavaScript
  MAX_INT = 9007199254740991

  # Alias UTF_8 encoding for convenience / speed
  UTF_8 = ::Encoding::UTF_8

  # Byte arrays for UTF-* Byte Order Marks
  BOM_BYTES_UTF_8 = [0xef, 0xbb, 0xbf]
  BOM_BYTES_UTF_16LE = [0xff, 0xfe]
  BOM_BYTES_UTF_16BE = [0xfe, 0xff]

  # The mode to use when opening a file for reading
  FILE_READ_MODE = RUBY_ENGINE_OPAL ? 'r' : 'rb:utf-8:utf-8'

  # The mode to use when opening a URI for reading
  URI_READ_MODE = FILE_READ_MODE

  # The mode to use when opening a file for writing
  FILE_WRITE_MODE = RUBY_ENGINE_OPAL ? 'w' : 'w:utf-8'

  # The default document type
  # Can influence markup generated by the converters
  DEFAULT_DOCTYPE = 'article'

  # The backend determines the format of the converted output, default to html5
  DEFAULT_BACKEND = 'html5'

  DEFAULT_STYLESHEET_KEYS = ['', 'DEFAULT'].to_set

  DEFAULT_STYLESHEET_NAME = 'asciidoctor.css'

  # Pointers to the preferred version for a given backend.
  BACKEND_ALIASES = {
    'html'    => 'html5',
    'docbook' => 'docbook5'
  }

  # Default page widths for calculating absolute widths
  DEFAULT_PAGE_WIDTHS = {
    'docbook' => 425
  }

  # Default extensions for the respective base backends
  DEFAULT_EXTENSIONS = {
    'html' => '.html',
    'docbook' => '.xml',
    'pdf' => '.pdf',
    'epub' => '.epub',
    'manpage' => '.man',
    'asciidoc' => '.adoc'
  }

  # A map of file extensions that are recognized as AsciiDoc documents
  # TODO .txt should be deprecated
  ASCIIDOC_EXTENSIONS = {
    '.adoc' => true,
    '.asciidoc' => true,
    '.asc' => true,
    '.ad' => true,
    # TODO .txt should be deprecated
    '.txt' => true
  }

  SETEXT_SECTION_LEVELS = {
    '=' => 0,
    '-' => 1,
    '~' => 2,
    '^' => 3,
    '+' => 4
  }

  ADMONITION_STYLES = ['NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION'].to_set

  ADMONITION_STYLE_HEADS = ['N', 'T', 'I', 'W', 'C'].to_set

  PARAGRAPH_STYLES = ['comment', 'example', 'literal', 'listing', 'normal', 'open', 'pass', 'quote', 'sidebar', 'source', 'verse', 'abstract', 'partintro'].to_set

  VERBATIM_STYLES = ['literal', 'listing', 'source', 'verse'].to_set

  DELIMITED_BLOCKS = {
    '--'   => [:open, ['comment', 'example', 'literal', 'listing', 'pass', 'quote', 'sidebar', 'source', 'verse', 'admonition', 'abstract', 'partintro'].to_set],
    '----' => [:listing, ['literal', 'source'].to_set],
    '....' => [:literal, ['listing', 'source'].to_set],
    '====' => [:example, ['admonition'].to_set],
    '****' => [:sidebar, ::Set.new],
    '____' => [:quote, ['verse'].to_set],
    '++++' => [:pass, ['stem', 'latexmath', 'asciimath'].to_set],
    '|===' => [:table, ::Set.new],
    ',===' => [:table, ::Set.new],
    ':===' => [:table, ::Set.new],
    '!===' => [:table, ::Set.new],
    '////' => [:comment, ::Set.new],
    '```'  => [:fenced_code, ::Set.new]
  }

  DELIMITED_BLOCK_HEADS = {}.tap {|accum| DELIMITED_BLOCKS.each_key {|k| accum[k.slice 0, 2] = true } }
  DELIMITED_BLOCK_TAILS = {}.tap {|accum| DELIMITED_BLOCKS.each_key {|k| accum[k] = k[k.length - 1] if k.length == 4 } }

  # NOTE the 'figure' key as a string is historical and used by image blocks
  CAPTION_ATTR_NAMES = { example: 'example-caption', 'figure' => 'figure-caption', listing: 'listing-caption', table: 'table-caption' }

  LAYOUT_BREAK_CHARS = {
    '\'' => :thematic_break,
    '<'  => :page_break
  }

  MARKDOWN_THEMATIC_BREAK_CHARS = {
    '-'  => :thematic_break,
    '*'  => :thematic_break,
    '_'  => :thematic_break
  }

  HYBRID_LAYOUT_BREAK_CHARS = LAYOUT_BREAK_CHARS.merge MARKDOWN_THEMATIC_BREAK_CHARS

  #LIST_CONTEXTS = [:ulist, :olist, :dlist, :colist]

  NESTABLE_LIST_CONTEXTS = [:ulist, :olist, :dlist]

  # TODO validate use of explicit style name above ordered list (this list is for selecting an implicit style)
  ORDERED_LIST_STYLES = [:arabic, :loweralpha, :lowerroman, :upperalpha, :upperroman] #, :lowergreek]

  ORDERED_LIST_KEYWORDS = {
    #'arabic'     => '1',
    #'decimal'    => '1',
    'loweralpha' => 'a',
    'lowerroman' => 'i',
    #'lowergreek' => 'a',
    'upperalpha' => 'A',
    'upperroman' => 'I'
  }

  ATTR_REF_HEAD = '{'

  LIST_CONTINUATION = '+'

  # NOTE AsciiDoc Python allows + to be preceded by TAB; Asciidoctor does not
  HARD_LINE_BREAK = ' +'

  LINE_CONTINUATION = ' \\'

  LINE_CONTINUATION_LEGACY = ' +'

  BLOCK_MATH_DELIMITERS = {
    asciimath: ['\$', '\$'],
    latexmath: ['\[', '\]'],
  }

  INLINE_MATH_DELIMITERS = {
    asciimath: ['\$', '\$'],
    latexmath: ['\(', '\)'],
  }

  (STEM_TYPE_ALIASES = {
    'latexmath' => 'latexmath',
    'latex' => 'latexmath',
    'tex' => 'latexmath'
  }).default = 'asciimath'

  FONT_AWESOME_VERSION = '4.7.0'

  HIGHLIGHT_JS_VERSION = '9.15.6'

  MATHJAX_VERSION = '2.7.5'

  # attributes which be changed within the content of the document (but not
  # header) because it has semantic meaning; ex. sectnums
  FLEXIBLE_ATTRIBUTES = ['sectnums']

  # A collection of regular expressions used by the parser.
  #
  # NOTE The following pattern, which appears frequently, captures the
  # contents between square brackets, ignoring escaped closing brackets
  # (closing brackets prefixed with a backslash '\' character)
  #
  #   Pattern: \[(|#{CC_ALL}*?[^\\])\]
  #   Matches: [enclosed text] and [enclosed [text\]], not [enclosed text \\] or [\\] (as these require a trailing space)
  #
  # NOTE \w only matches ASCII word characters, whereas [[:word:]] or \p{Word} matches any character in the Unicode word category.
  #(pseudo)module Rx

    ## Regular expression character classes (to ensure regexp compatibility between Ruby and JavaScript)
    ## CC stands for "character class", CG stands for "character class group"

    unless RUBY_ENGINE == 'opal'
      # CC_ALL is any character, including newlines (must be accompanied by multiline regexp flag)
      CC_ALL = '.'
      # CC_ANY is any character except newlines
      CC_ANY = '.'
      CC_EOL = '$'
      CC_ALPHA = CG_ALPHA = '\p{Alpha}'
      CC_ALNUM = CG_ALNUM = '\p{Alnum}'
      CG_BLANK = '\p{Blank}'
      CC_WORD  = CG_WORD = '\p{Word}'
    end

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
    IncludeDirectiveRx = /^(\\)?include::([^\[][^\[]*)\[(#{CC_ANY}+)?\]$/

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
    InvalidAttributeNameCharsRx = /[^-#{CC_WORD}]/

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
    AttributeReferenceRx = /(\\)?\{(#{CG_WORD}[-#{CC_WORD}]*|(set|counter2?):#{CC_ANY}+?)(\\)?\}/

    ## Paragraphs and delimited blocks

    # Matches an anchor (i.e., id + optional reference text) on a line above a block.
    #
    # Examples
    #
    #   [[idname]]
    #   [[idname,Reference Text]]
    #
    BlockAnchorRx = /^\[\[(?:|([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)(?:, *(#{CC_ANY}+))?)\]\]$/

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
    BlockAttributeLineRx = /^\[(?:|[#{CC_WORD}.#%{,"']#{CC_ANY}*|\[(?:|[#{CC_ALPHA}_:][#{CC_WORD}:.-]*(?:, *#{CC_ANY}+)?)\])\]$/

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
    InlineSectionAnchorRx = / (\\)?\[\[([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)(?:, *(#{CC_ANY}+))?\]\]$/

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
    AnyListRx = %r(^(?:[ \t]*(?:-|\*\**|\.\.*|\u2022|\d+\.|[a-zA-Z]\.|[IVXivx]+\))[ \t]|(?!//[^/])[ \t]*[^ \t]#{CC_ANY}*?(?::::{0,2}|;;)(?:$|[ \t])|<?\d+>[ \t]))

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
    ListRxMap = {
      ulist: UnorderedListRx,
      olist: OrderedListRx,
      dlist: DescriptionListRx,
      colist: CalloutListRx,
    }

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
    # NOTE we've relaxed the match for target to accomodate the short format (e.g., name::[attrlist])
    CustomBlockMacroRx = /^(#{CG_WORD}[-#{CC_WORD}]*)::(|\S|\S#{CC_ANY}*?\S)\[(#{CC_ANY}+)?\]$/

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
    InlineAnchorRx = /(\\)?(?:\[\[([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)(?:, *(#{CC_ANY}+?))?\]\]|anchor:([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)\[(?:\]|(#{CC_ANY}*?[^\\])\]))/

    # Scans for a non-escaped anchor (i.e., id + optional reference text) in the flow of text.
    InlineAnchorScanRx = /(?:^|[^\\\[])\[\[([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)(?:, *(#{CC_ANY}+?))?\]\]|(?:^|[^\\])anchor:([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)\[(?:\]|(#{CC_ANY}*?[^\\])\])/

    # Scans for a leading, non-escaped anchor (i.e., id + optional reference text).
    LeadingInlineAnchorRx = /^\[\[([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)(?:, *(#{CC_ANY}+?))?\]\]/

    # Matches a bibliography anchor at the start of the list item text (in a bibliography list).
    #
    # Examples
    #
    #   [[[Fowler_1997]]] Fowler M. ...
    #
    InlineBiblioAnchorRx = /^\[\[\[([#{CC_ALPHA}_:][#{CC_WORD}:.-]*)(?:, *(#{CC_ANY}+?))?\]\]\]/

    # Matches an inline e-mail address.
    #
    #   doc.writer@example.com
    #
    InlineEmailRx = %r(([\\>:/])?#{CG_WORD}(?:&amp;|[#{CC_WORD}.%+-])*@#{CG_ALNUM}[#{CC_ALNUM}_.-]*\.[a-zA-Z]{2,5}\b)

    # Matches an inline footnote macro, which is allowed to span multiple lines.
    #
    # Examples
    #   footnote:[text] (not referenceable)
    #   footnote:id[text] (referenceable)
    #   footnote:id[] (reference)
    #   footnoteref:[id,text] (legacy)
    #   footnoteref:[id] (legacy)
    #
    InlineFootnoteMacroRx = /\\?footnote(?:(ref):|:([\w-]+)?)\[(?:|(#{CC_ALL}*?[^\\]))\]/m

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
    #
    # FIXME revisit! the main issue is we need different rules for implicit vs explicit
    InlineLinkRx = %r((^|link:|#{CG_BLANK}|&lt;|[>\(\)\[\];])(\\?(?:https?|file|ftp|irc)://[^\s\[\]<]*([^\s.,\[\]<]))(?:\[(|#{CC_ALL}*?[^\\])\])?)m

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
    MacroNameRx = /^#{CG_WORD}[-#{CC_WORD}]*$/

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
    #   menu:View[Page Style > No Style]
    #   menu:View[Page Style, No Style]
    #
    InlineMenuMacroRx = /\\?menu:(#{CG_WORD}|[#{CC_WORD}&][^\n\[]*[^\s\[])\[ *(#{CC_ALL}*?[^\\])?\]/m

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
    #   `text` (compat)
    #
    # NOTE we always capture the attributes so we know when to use compatible (i.e., legacy) behavior
    InlinePassRx = {
      false => ['+', '`', /(^|[^#{CC_WORD};:])(?:\[([^\]]+)\])?(\\?(\+|`)(\S|\S#{CC_ALL}*?\S)\4)(?!#{CG_WORD})/m],
      true  => ['`', nil, /(^|[^`#{CC_WORD}])(?:\[([^\]]+)\])?(\\?(`)([^`\s]|[^`\s]#{CC_ALL}*?\S)\4)(?![`#{CC_WORD}])/m]
    }

    # Matches an inline plus passthrough spanning multiple lines, but only when it occurs directly
    # inside constrained monospaced formatting in non-compat mode.
    #
    # Examples
    #
    #   +text+
    #
    SinglePlusInlinePassRx = /^(\\)?\+(\S|\S#{CC_ALL}*?\S)\+$/m

    # Matches several variants of the passthrough inline macro, which may span multiple lines.
    #
    # Examples
    #
    #   +++text+++
    #   $$text$$
    #   pass:quotes[text]
    #
    # NOTE we have to support an empty pass:[] for compatibility with AsciiDoc Python
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
    # NOTE AsciiDoc Python allows + to be preceded by TAB; Asciidoctor does not
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
    UriSniffRx = %r(^#{CG_ALPHA}[#{CC_ALNUM}.+-]+:/{0,2})

    # Detects XML tags
    XmlSanitizeRx = /<[^>]+>/
  #end

  INTRINSIC_ATTRIBUTES = {
    'startsb'    => '[',
    'endsb'      => ']',
    'vbar'       => '|',
    'caret'      => '^',
    'asterisk'   => '*',
    'tilde'      => '~',
    'plus'       => '&#43;',
    'backslash'  => '\\',
    'backtick'   => '`',
    'blank'      => '',
    'empty'      => '',
    'sp'         => ' ',
    'two-colons' => '::',
    'two-semicolons' => ';;',
    'nbsp'       => '&#160;',
    'deg'        => '&#176;',
    'zwsp'       => '&#8203;',
    'quot'       => '&#34;',
    'apos'       => '&#39;',
    'lsquo'      => '&#8216;',
    'rsquo'      => '&#8217;',
    'ldquo'      => '&#8220;',
    'rdquo'      => '&#8221;',
    'wj'         => '&#8288;',
    'brvbar'     => '&#166;',
    'pp'         => '&#43;&#43;',
    'cpp'        => 'C&#43;&#43;',
    'amp'        => '&',
    'lt'         => '<',
    'gt'         => '>'
  }

  QUOTE_SUBS = {}.tap do |accum|
    # unconstrained quotes:: can appear anywhere
    # constrained quotes:: must be bordered by non-word characters
    # NOTE these substitutions are processed in the order they appear here and
    # the order in which they are replaced is important
    accum[false] = normal = [
      # **strong**
      [:strong, :unconstrained, /\\?(?:\[([^\]]+)\])?\*\*(#{CC_ALL}+?)\*\*/m],
      # *strong*
      [:strong, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+)\])?\*(\S|\S#{CC_ALL}*?\S)\*(?!#{CG_WORD})/m],
      # "`double-quoted`"
      [:double, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+)\])?"`(\S|\S#{CC_ALL}*?\S)`"(?!#{CG_WORD})/m],
      # '`single-quoted`'
      [:single, :constrained, /(^|[^#{CC_WORD};:`}])(?:\[([^\]]+)\])?'`(\S|\S#{CC_ALL}*?\S)`'(?!#{CG_WORD})/m],
      # ``monospaced``
      [:monospaced, :unconstrained, /\\?(?:\[([^\]]+)\])?``(#{CC_ALL}+?)``/m],
      # `monospaced`
      [:monospaced, :constrained, /(^|[^#{CC_WORD};:"'`}])(?:\[([^\]]+)\])?`(\S|\S#{CC_ALL}*?\S)`(?![#{CC_WORD}"'`])/m],
      # __emphasis__
      [:emphasis, :unconstrained, /\\?(?:\[([^\]]+)\])?__(#{CC_ALL}+?)__/m],
      # _emphasis_
      [:emphasis, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+)\])?_(\S|\S#{CC_ALL}*?\S)_(?!#{CG_WORD})/m],
      # ##mark## (referred to in AsciiDoc Python as unquoted)
      [:mark, :unconstrained, /\\?(?:\[([^\]]+)\])?##(#{CC_ALL}+?)##/m],
      # #mark# (referred to in AsciiDoc Python as unquoted)
      [:mark, :constrained, /(^|[^#{CC_WORD}&;:}])(?:\[([^\]]+)\])?#(\S|\S#{CC_ALL}*?\S)#(?!#{CG_WORD})/m],
      # ^superscript^
      [:superscript, :unconstrained, /\\?(?:\[([^\]]+)\])?\^(\S+?)\^/],
      # ~subscript~
      [:subscript, :unconstrained, /\\?(?:\[([^\]]+)\])?~(\S+?)~/]
    ]

    accum[true] = compat = normal.drop 0
    # ``quoted''
    compat[2] = [:double, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+)\])?``(\S|\S#{CC_ALL}*?\S)''(?!#{CG_WORD})/m]
    # `quoted'
    compat[3] = [:single, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+)\])?`(\S|\S#{CC_ALL}*?\S)'(?!#{CG_WORD})/m]
    # ++monospaced++
    compat[4] = [:monospaced, :unconstrained, /\\?(?:\[([^\]]+)\])?\+\+(#{CC_ALL}+?)\+\+/m]
    # +monospaced+
    compat[5] = [:monospaced, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+)\])?\+(\S|\S#{CC_ALL}*?\S)\+(?!#{CG_WORD})/m]
    # #unquoted#
    #compat[8] = [:unquoted, *compat[8][1..-1]]
    # ##unquoted##
    #compat[9] = [:unquoted, *compat[9][1..-1]]
    # 'emphasis'
    compat.insert 3, [:emphasis, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+)\])?'(\S|\S#{CC_ALL}*?\S)'(?!#{CG_WORD})/m]
  end

  # NOTE order of replacements is significant
  REPLACEMENTS = [
    # (C)
    [/\\?\(C\)/, '&#169;', :none],
    # (R)
    [/\\?\(R\)/, '&#174;', :none],
    # (TM)
    [/\\?\(TM\)/, '&#8482;', :none],
    # foo -- bar (where either space character can be a newline)
    # NOTE this necessarily drops the newline if it appears at end of line
    [/(^|\n| |\\)--( |\n|$)/, '&#8201;&#8212;&#8201;', :none],
    # foo--bar
    [/(#{CG_WORD})\\?--(?=#{CG_WORD})/, '&#8212;&#8203;', :leading],
    # ellipsis
    [/\\?\.\.\./, '&#8230;&#8203;', :none],
    # right single quote
    [/\\?`'/, '&#8217;', :none],
    # apostrophe (inside a word)
    [/(#{CG_ALNUM})\\?'(?=#{CG_ALPHA})/, '&#8217;', :leading],
    # right arrow ->
    [/\\?-&gt;/, '&#8594;', :none],
    # right double arrow =>
    [/\\?=&gt;/, '&#8658;', :none],
    # left arrow <-
    [/\\?&lt;-/, '&#8592;', :none],
    # left double arrow <=
    [/\\?&lt;=/, '&#8656;', :none],
    # restore entities
    [/\\?(&)amp;((?:[a-zA-Z][a-zA-Z]+\d{0,2}|#\d\d\d{0,4}|#x[\da-fA-F][\da-fA-F][\da-fA-F]{0,3});)/, '', :bounding]
  ]

  class << self

  # Public: Parse the AsciiDoc source input into a {Document}
  #
  # Accepts input as an IO (or StringIO), String or String Array object. If the
  # input is a File, the object is expected to be opened for reading and is not
  # closed afterwards by this method. Information about the file (filename,
  # directory name, etc) gets assigned to attributes on the Document object.
  #
  # input   - the AsciiDoc source as a IO, String or Array.
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See {Document#initialize} for details about these options.
  #
  # Returns the Document
  def load input, options = {}
    options = options.merge

    if (timings = options[:timings])
      timings.start :read
    end

    if (logger = options[:logger]) && logger != LoggerManager.logger
      LoggerManager.logger = logger
    end

    if !(attrs = options[:attributes])
      attrs = {}
    elsif ::Hash === attrs
      attrs = attrs.merge
    elsif (defined? ::Java::JavaUtil::Map) && ::Java::JavaUtil::Map === attrs
      attrs = attrs.dup
    elsif ::Array === attrs
      attrs = {}.tap do |accum|
        attrs.each do |entry|
          k, _, v = entry.partition '='
          accum[k] = v
        end
      end
    elsif ::String === attrs
      # condense and convert non-escaped spaces to null, unescape escaped spaces, then split on null
      attrs = {}.tap do |accum|
        attrs.gsub(SpaceDelimiterRx, '\1' + NULL).gsub(EscapedSpaceRx, '\1').split(NULL).each do |entry|
          k, _, v = entry.partition '='
          accum[k] = v
        end
      end
    elsif (attrs.respond_to? :keys) && (attrs.respond_to? :[])
      # coerce attrs to a real Hash
      attrs = {}.tap {|accum| attrs.keys.each {|k| accum[k] = attrs[k] } }
    else
      raise ::ArgumentError, %(illegal type for attributes option: #{attrs.class.ancestors.join ' < '})
    end

    if ::File === input
      options[:input_mtime] = input.mtime
      # NOTE defer setting infile and indir until we get a better sense of their purpose
      # TODO cli checks if input path can be read and is file, but might want to add check to API too
      attrs['docfile'] = input_path = ::File.absolute_path input.path
      attrs['docdir'] = ::File.dirname input_path
      attrs['docname'] = Helpers.basename input_path, (attrs['docfilesuffix'] = Helpers.extname input_path)
      source = input.read
    elsif input.respond_to? :read
      # NOTE tty, pipes & sockets can't be rewound, but can't be sniffed easily either
      # just fail the rewind operation silently to handle all cases
      input.rewind rescue nil
      source = input.read
    elsif ::String === input
      source = input
    elsif ::Array === input
      source = input.drop 0
    elsif input
      raise ::ArgumentError, %(unsupported input type: #{input.class})
    end

    if timings
      timings.record :read
      timings.start :parse
    end

    options[:attributes] = attrs
    doc = options[:parse] == false ? (Document.new source, options) : (Document.new source, options).parse

    timings.record :parse if timings
    doc
  rescue => ex
    begin
      context = %(asciidoctor: FAILED: #{attrs['docfile'] || '<stdin>'}: Failed to load AsciiDoc document)
      if ex.respond_to? :exception
        # The original message must be explicitly preserved when wrapping a Ruby exception
        wrapped_ex = ex.exception %(#{context} - #{ex.message})
        # JRuby automatically sets backtrace; MRI did not until 2.6
        wrapped_ex.set_backtrace ex.backtrace
      else
        # Likely a Java exception class
        wrapped_ex = ex.class.new context, ex
        wrapped_ex.stack_trace = ex.stack_trace
      end
    rescue
      wrapped_ex = ex
    end
    raise wrapped_ex
  end

  # Public: Parse the contents of the AsciiDoc source file into an Asciidoctor::Document
  #
  # input   - the String AsciiDoc source filename
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See Asciidoctor::Document#initialize for details about options.
  #
  # Returns the Asciidoctor::Document
  def load_file filename, options = {}
    ::File.open(filename, FILE_READ_MODE) {|file| self.load file, options }
  end

  # Public: Parse the AsciiDoc source input into an Asciidoctor::Document and
  # convert it to the specified backend format.
  #
  # Accepts input as an IO (or StringIO), String or String Array object. If the
  # input is a File, the object is expected to be opened for reading and is not
  # closed afterwards by this method. Information about the file (filename,
  # directory name, etc) gets assigned to attributes on the Document object.
  #
  # If the :to_file option is true, and the input is a File, the output is
  # written to a file adjacent to the input file, having an extension that
  # corresponds to the backend format. Otherwise, if the :to_file option is
  # specified, the file is written to that file. If :to_file is not an absolute
  # path, it is resolved relative to :to_dir, if given, otherwise the
  # Document#base_dir. If the target directory does not exist, it will not be
  # created unless the :mkdirs option is set to true. If the file cannot be
  # written because the target directory does not exist, or because it falls
  # outside of the Document#base_dir in safe mode, an IOError is raised.
  #
  # If the output is going to be written to a file, the header and footer are
  # included unless specified otherwise (writing to a file implies creating a
  # standalone document). Otherwise, the header and footer are not included by
  # default and the converted result is returned.
  #
  # input   - the String AsciiDoc source filename
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See Asciidoctor::Document#initialize for details about options.
  #
  # Returns the Document object if the converted String is written to a
  # file, otherwise the converted String
  def convert input, options = {}
    (options = options.merge).delete :parse
    to_dir = options.delete :to_dir
    mkdirs = options.delete :mkdirs

    case (to_file = options.delete :to_file)
    when true, nil
      unless (write_to_target = to_dir)
        sibling_path = ::File.absolute_path input.path if ::File === input
      end
      to_file = nil
    when false
      to_file = nil
    when '/dev/null'
      return self.load input, options
    else
      options[:to_file] = write_to_target = to_file unless (stream_output = to_file.respond_to? :write)
    end

    unless options.key? :standalone
      if sibling_path || write_to_target
        options[:standalone] = true
      elsif options.key? :header_footer
        options[:standalone] = options[:header_footer]
      end
    end

    # NOTE outfile may be controlled by document attributes, so resolve outfile after loading
    if sibling_path
      options[:to_dir] = outdir = ::File.dirname sibling_path
    elsif write_to_target
      if to_dir
        if to_file
          options[:to_dir] = ::File.dirname ::File.expand_path ::File.join to_dir, to_file
        else
          options[:to_dir] = ::File.expand_path to_dir
        end
      elsif to_file
        options[:to_dir] = ::File.dirname ::File.expand_path to_file
      end
    end

    # NOTE :to_dir is always set when outputting to a file
    # NOTE :to_file option only passed if assigned an explicit path
    doc = self.load input, options

    if sibling_path # write to file in same directory
      outfile = ::File.join outdir, %(#{doc.attributes['docname']}#{doc.outfilesuffix})
      raise ::IOError, %(input file and output file cannot be the same: #{outfile}) if outfile == sibling_path
    elsif write_to_target # write to explicit file or directory
      working_dir = (options.key? :base_dir) ? (::File.expand_path options[:base_dir]) : ::Dir.pwd
      # QUESTION should the jail be the working_dir or doc.base_dir???
      jail = doc.safe >= SafeMode::SAFE ? working_dir : nil
      if to_dir
        outdir = doc.normalize_system_path(to_dir, working_dir, jail, target_name: 'to_dir', recover: false)
        if to_file
          outfile = doc.normalize_system_path(to_file, outdir, nil, target_name: 'to_dir', recover: false)
          # reestablish outdir as the final target directory (in the case to_file had directory segments)
          outdir = ::File.dirname outfile
        else
          outfile = ::File.join outdir, %(#{doc.attributes['docname']}#{doc.outfilesuffix})
        end
      elsif to_file
        outfile = doc.normalize_system_path(to_file, working_dir, jail, target_name: 'to_dir', recover: false)
        # establish outdir as the final target directory (in the case to_file had directory segments)
        outdir = ::File.dirname outfile
      end

      if ::File === input && outfile == (::File.absolute_path input.path)
        raise ::IOError, %(input file and output file cannot be the same: #{outfile})
      end

      if mkdirs
        Helpers.mkdir_p outdir
      else
        # NOTE we intentionally refer to the directory as it was passed to the API
        raise ::IOError, %(target directory does not exist: #{to_dir} (hint: set :mkdirs option)) unless ::File.directory? outdir
      end
    else # write to stream
      outfile = to_file
      outdir = nil
    end

    if outfile && !stream_output
      output = doc.convert 'outfile' => outfile, 'outdir' => outdir
    else
      output = doc.convert
    end

    if outfile
      doc.write output, outfile

      # NOTE document cannot control this behavior if safe >= SafeMode::SERVER
      # NOTE skip if stylesdir is a URI
      if !stream_output && doc.safe < SafeMode::SECURE && (doc.attr? 'linkcss') && (doc.attr? 'copycss') &&
          (doc.basebackend? 'html') && !((stylesdir = (doc.attr 'stylesdir')) && (Helpers.uriish? stylesdir))
        if (stylesheet = doc.attr 'stylesheet')
          if DEFAULT_STYLESHEET_KEYS.include? stylesheet
            copy_asciidoctor_stylesheet = true
          elsif !(Helpers.uriish? stylesheet)
            copy_user_stylesheet = true
          end
        end
        copy_syntax_hl_stylesheet = (syntax_hl = doc.syntax_highlighter) && (syntax_hl.write_stylesheet? doc)
        if copy_asciidoctor_stylesheet || copy_user_stylesheet || copy_syntax_hl_stylesheet
          stylesoutdir = doc.normalize_system_path(stylesdir, outdir, doc.safe >= SafeMode::SAFE ? outdir : nil)
          if mkdirs
            Helpers.mkdir_p stylesoutdir
          else
            raise ::IOError, %(target stylesheet directory does not exist: #{stylesoutdir} (hint: set :mkdirs option)) unless ::File.directory? stylesoutdir
          end

          if copy_asciidoctor_stylesheet
            Stylesheets.instance.write_primary_stylesheet stylesoutdir
          # FIXME should Stylesheets also handle the user stylesheet?
          elsif copy_user_stylesheet
            if (stylesheet_src = doc.attr 'copycss').empty?
              stylesheet_src = doc.normalize_system_path stylesheet
            else
              # NOTE in this case, copycss is a source location (but cannot be a URI)
              stylesheet_src = doc.normalize_system_path stylesheet_src
            end
            stylesheet_dest = doc.normalize_system_path stylesheet, stylesoutdir, (doc.safe >= SafeMode::SAFE ? outdir : nil)
            # NOTE don't warn if src can't be read and dest already exists (see #2323)
            if stylesheet_src != stylesheet_dest && (stylesheet_data = doc.read_asset stylesheet_src,
                warn_on_failure: !(::File.file? stylesheet_dest), label: 'stylesheet')
              ::File.write stylesheet_dest, stylesheet_data, mode: FILE_WRITE_MODE
            end
          end
          syntax_hl.write_stylesheet doc, stylesoutdir if copy_syntax_hl_stylesheet
        end
      end
      doc
    else
      output
    end
  end

  # Deprecated: Use {Asciidoctor.convert} instead.
  alias render convert

  # Public: Parse the contents of the AsciiDoc source file into an
  # Asciidoctor::Document and convert it to the specified backend format.
  #
  # input   - the String AsciiDoc source filename
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See Asciidoctor::Document#initialize for details about options.
  #
  # Returns the Document object if the converted String is written to a
  # file, otherwise the converted String
  def convert_file filename, options = {}
    ::File.open(filename, FILE_READ_MODE) {|file| self.convert file, options }
  end

  # Deprecated: Use {Asciidoctor.convert_file} instead.
  alias render_file convert_file

  # Internal: Automatically load the Asciidoctor::Extensions module.
  #
  # Requires the Asciidoctor::Extensions module if the name is :Extensions.
  # Otherwise, delegates to the super method.
  #
  # This method provides the same functionality as using autoload on
  # Asciidoctor::Extensions, except that the constant isn't recognized as
  # defined prior to it being loaded.
  #
  # Returns the resolved constant, if resolved, otherwise nothing.
  def const_missing name
    if name == :Extensions
      require_relative 'asciidoctor/extensions'
      Extensions
    else
      super
    end
  end unless RUBY_ENGINE == 'opal'

  end

  unless RUBY_ENGINE == 'opal'
    autoload :SyntaxHighlighter, %(#{LIB_DIR}/asciidoctor/syntax_highlighter)
    autoload :Timings, %(#{LIB_DIR}/asciidoctor/timings)
  end
end

# core extensions
require_relative 'asciidoctor/core_ext'

# modules and helpers
require_relative 'asciidoctor/helpers'
require_relative 'asciidoctor/logging'
require_relative 'asciidoctor/substitutors'
require_relative 'asciidoctor/version'

# abstract classes
require_relative 'asciidoctor/abstract_node'
require_relative 'asciidoctor/abstract_block'

# concrete classes
require_relative 'asciidoctor/attribute_list'
require_relative 'asciidoctor/block'
require_relative 'asciidoctor/callouts'
require_relative 'asciidoctor/converter'
require_relative 'asciidoctor/document'
require_relative 'asciidoctor/inline'
require_relative 'asciidoctor/list'
require_relative 'asciidoctor/parser'
require_relative 'asciidoctor/path_resolver'
require_relative 'asciidoctor/reader'
require_relative 'asciidoctor/section'
require_relative 'asciidoctor/stylesheets'
require_relative 'asciidoctor/table'
require_relative 'asciidoctor/writer'

if RUBY_ENGINE == 'opal'
  require_relative 'asciidoctor/syntax_highlighter'
  require_relative 'asciidoctor/timings'
  # this require is satisfied by the Asciidoctor.js build; it supplies compile and runtime overrides for Asciidoctor.js
  require 'asciidoctor/js/postscript'
end
