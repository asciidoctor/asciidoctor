RUBY_ENGINE = 'unknown' unless defined? RUBY_ENGINE
RUBY_ENGINE_OPAL = (RUBY_ENGINE == 'opal')
RUBY_ENGINE_JRUBY = (RUBY_ENGINE == 'jruby')
RUBY_MIN_VERSION_1_9 = (RUBY_VERSION >= '1.9')
RUBY_MIN_VERSION_2 = (RUBY_VERSION >= '2')

require 'set'

# NOTE "RUBY_ENGINE == 'opal'" conditional blocks are filtered by the Opal preprocessor
if RUBY_ENGINE == 'opal'
  require 'encoding' # needed for String.bytes method
  require 'strscan'
  require 'asciidoctor/opal_ext'
else
  autoload :Base64, 'base64'
  autoload :FileUtils, 'fileutils'
  autoload :OpenURI, 'open-uri'
  autoload :StringScanner, 'strscan'
end

# ideally we should use require_relative instead of modifying the LOAD_PATH
$:.unshift File.dirname __FILE__

# Public: Methods for parsing AsciiDoc input files and converting documents
# using eRuby templates.
#
# AsciiDoc documents comprise a header followed by zero or more sections.
# Sections are composed of blocks of content.  For example:
#
#   = Doc Title
#
#   == Section 1
#
#   This is a paragraph block in the first section.
#
#   == Section 2
#
#   This section has a paragraph block and an olist block.
#
#   . Item 1
#   . Item 2
#
# Examples:
#
# Use built-in converter:
#
#   Asciidoctor.convert_file 'sample.adoc'
#
# Use custom (Tilt-supported) templates:
#
#   Asciidoctor.convert_file 'sample.adoc', :template_dir => 'path/to/templates'
#
module Asciidoctor

  # alias the RUBY_ENGINE constant inside the Asciidoctor namespace
  RUBY_ENGINE = ::RUBY_ENGINE

  module SafeMode

    # A safe mode level that disables any of the security features enforced
    # by Asciidoctor (Ruby is still subject to its own restrictions).
    UNSAFE = 0;

    # A safe mode level that closely parallels safe mode in AsciiDoc. This value
    # prevents access to files which reside outside of the parent directory of
    # the source file and disables any macro other than the include::[] macro.
    SAFE = 1;

    # A safe mode level that disallows the document from setting attributes
    # that would affect the conversion of the document, in addition to all the
    # security features of SafeMode::SAFE. For instance, this level disallows
    # changing the backend or the source-highlighter using an attribute defined
    # in the source document. This is the most fundamental level of security
    # for server-side deployments (hence the name).
    SERVER = 10;

    # A safe mode level that disallows the document from attempting to read
    # files from the file system and including the contents of them into the
    # document, in additional to all the security features of SafeMode::SERVER.
    # For instance, this level disallows use of the include::[] macro and the
    # embedding of binary content (data uri), stylesheets and JavaScripts
    # referenced by the document.(Asciidoctor and trusted extensions may still
    # be allowed to embed trusted content into the document).
    #
    # Since Asciidoctor is aiming for wide adoption, this level is the default
    # and is recommended for server-side deployments.
    SECURE = 20;

    # A planned safe mode level that disallows the use of passthrough macros and
    # prevents the document from setting any known attributes, in addition to all
    # the security features of SafeMode::SECURE.
    #
    # Please note that this level is not currently implemented (and therefore not
    # enforced)!
    #PARANOID = 100;

  end

  # Flags to control compliance with the behavior of AsciiDoc
  module Compliance
    @keys = [].to_set
    class << self
      attr :keys
    end

    # Defines a new compliance key and assigns an initial value.
    def self.define key, value
      if key == :keys || (self.respond_to? key)
        raise ::ArgumentError, %(Illegal key name: #{key})
      end
      instance_variable_set %(@#{key}), value
      class << self; self; end.send :attr_accessor, key
      @keys << key
    end

    # AsciiDoc terminates paragraphs adjacent to
    # block content (delimiter or block attribute list)
    # This option allows this behavior to be modified
    # TODO what about literal paragraph?
    # Compliance value: true
    define :block_terminates_paragraph, true

    # AsciiDoc does not treat paragraphs labeled with a verbatim style
    # (literal, listing, source, verse) as verbatim
    # This options allows this behavior to be modified
    # Compliance value: false
    define :strict_verbatim_paragraphs, true

    # NOT CURRENTLY USED
    # AsciiDoc allows start and end delimiters around
    # a block to be different lengths
    # Enabling this option requires matching lengths
    # Compliance value: false
    #define :congruent_block_delimiters, true

    # AsciiDoc supports both single-line and underlined
    # section titles.
    # This option disables the underlined variant.
    # Compliance value: true
    define :underline_style_section_titles, true

    # Asciidoctor will unwrap the content in a preamble
    # if the document has a title and no sections.
    # Compliance value: false
    define :unwrap_standalone_preamble, true

    # AsciiDoc drops lines that contain references to missing attributes.
    # This behavior is not intuitive to most writers
    # Compliance value: 'drop-line'
    define :attribute_missing, 'skip'

    # AsciiDoc drops lines that contain an attribute unassignemnt.
    # This behavior may need to be tuned depending on the circumstances.
    # Compliance value: 'drop-line'
    define :attribute_undefined, 'drop-line'

    # Asciidoctor will allow the id, role and options to be set
    # on blocks using a shorthand syntax (e.g., #idname.rolename%optionname)
    define :shorthand_property_syntax, true

    # Asciidoctor will recognize commonly-used Markdown syntax
    # to the degree it does not interfere with existing
    # AsciiDoc syntax and behavior.
    # Compliance value: false
    define :markdown_syntax, true
  end

  # The absolute root path of the Asciidoctor RubyGem
  ROOT_PATH = ::File.dirname ::File.dirname ::File.expand_path __FILE__

  # The absolute lib path of the Asciidoctor RubyGem
  LIB_PATH = ::File.join ROOT_PATH, 'lib'

  # The absolute data path of the Asciidoctor RubyGem
  DATA_PATH = ::File.join ROOT_PATH, 'data'

  # The user's home directory, as best we can determine it
  # NOTE not using infix rescue for performance reasons, see: https://github.com/jruby/jruby/issues/1816
  begin
    USER_HOME = ::Dir.home
  rescue
    USER_HOME = ::ENV['HOME'] || ::Dir.pwd
  end

  # Flag to indicate whether encoding can be coerced to UTF-8
  # _All_ input data must be force encoded to UTF-8 if Encoding.default_external is *not* UTF-8
  # Addresses failures performing string operations that are reported as "invalid byte sequence in US-ASCII" 
  # Ruby 1.8 doesn't seem to experience this problem (perhaps because it isn't validating the encodings)
  COERCE_ENCODING = !::RUBY_ENGINE_OPAL && ::RUBY_MIN_VERSION_1_9

  # Flag to indicate whether encoding of external strings needs to be forced to UTF-8
  FORCE_ENCODING = COERCE_ENCODING && ::Encoding.default_external != ::Encoding::UTF_8

  # Byte arrays for UTF-* Byte Order Marks
  # hex escape sequence used for Ruby 1.8 compatibility
  BOM_BYTES_UTF_8 = "\xef\xbb\xbf".bytes.to_a
  BOM_BYTES_UTF_16LE = "\xff\xfe".bytes.to_a
  BOM_BYTES_UTF_16BE = "\xfe\xff".bytes.to_a

  # Flag to indicate that line length should be calculated using a unicode mode hint
  FORCE_UNICODE_LINE_LENGTH = !::RUBY_MIN_VERSION_1_9

  # Flag to indicate whether gsub can use a Hash to map matches to replacements
  SUPPORTS_GSUB_RESULT_HASH = ::RUBY_MIN_VERSION_1_9 && !::RUBY_ENGINE_OPAL

  # The endline character used for output; stored in constant table as an optimization
  EOL = "\n"

  # The null character to use for splitting attribute values
  NULL = "\0"

  # String for matching tab character
  TAB = "\t"

  # Regexp for replacing tab character
  TAB_PATTERN = /\t/

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
    'asciidoc' => '.adoc'
  }

  # Set of file extensions recognized as AsciiDoc documents (stored as a truth hash)
  ASCIIDOC_EXTENSIONS = {
    '.asciidoc' => true,
    '.adoc' => true,
    '.ad' => true,
    '.asc' => true,
    # TODO .txt should be deprecated
    '.txt' => true
  }

  SECTION_LEVELS = {
    '=' => 0,
    '-' => 1,
    '~' => 2,
    '^' => 3,
    '+' => 4
  }

  ADMONITION_STYLES = ['NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION'].to_set

  PARAGRAPH_STYLES = ['comment', 'example', 'literal', 'listing', 'normal', 'pass', 'quote', 'sidebar', 'source', 'verse', 'abstract', 'partintro'].to_set

  VERBATIM_STYLES = ['literal', 'listing', 'source', 'verse'].to_set

  DELIMITED_BLOCKS = {
    '--'   => [:open, ['comment', 'example', 'literal', 'listing', 'pass', 'quote', 'sidebar', 'source', 'verse', 'admonition', 'abstract', 'partintro'].to_set],
    '----' => [:listing, ['literal', 'source'].to_set],
    '....' => [:literal, ['listing', 'source'].to_set],
    '====' => [:example, ['admonition'].to_set],
    '****' => [:sidebar, ::Set.new],
    '____' => [:quote, ['verse'].to_set],
    '""'   => [:quote, ['verse'].to_set],
    '++++' => [:pass, ['stem', 'latexmath', 'asciimath'].to_set],
    '|===' => [:table, ::Set.new],
    ',===' => [:table, ::Set.new],
    ':===' => [:table, ::Set.new],
    '!===' => [:table, ::Set.new],
    '////' => [:comment, ::Set.new],
    '```'  => [:fenced_code, ::Set.new]
  }

  DELIMITED_BLOCK_LEADERS = DELIMITED_BLOCKS.keys.map {|key| key[0..1] }.to_set

  LAYOUT_BREAK_LINES = {
    '\'' => :thematic_break,
    '-'  => :thematic_break,
    '*'  => :thematic_break,
    '_'  => :thematic_break,
    '<'  => :page_break
  }

  #LIST_CONTEXTS = [:ulist, :olist, :dlist, :colist]

  NESTABLE_LIST_CONTEXTS = [:ulist, :olist, :dlist]

  # TODO validate use of explicit style name above ordered list (this list is for selecting an implicit style)
  ORDERED_LIST_STYLES = [:arabic, :loweralpha, :lowerroman, :upperalpha, :upperroman] #, :lowergreek]

  ORDERED_LIST_KEYWORDS = {
    'loweralpha' => 'a',
    'lowerroman' => 'i',
    'upperalpha' => 'A',
    'upperroman' => 'I'
    #'lowergreek' => 'a'
    #'arabic'     => '1'
    #'decimal'    => '1'
  }

  LIST_CONTINUATION = '+'

  # NOTE AsciiDoc Python recognizes both a preceding TAB and a space
  LINE_BREAK = ' +'

  LINE_CONTINUATION = ' \\'

  LINE_CONTINUATION_LEGACY = ' +'

  BLOCK_MATH_DELIMITERS = {
    :asciimath => ['\\$', '\\$'],
    :latexmath => ['\\[', '\\]'],
  }

  INLINE_MATH_DELIMITERS = {
    :asciimath => ['\\$', '\\$'],
    :latexmath => ['\\(', '\\)'],
  }

  # attributes which be changed within the content of the document (but not
  # header) because it has semantic meaning; ex. sectnums
  FLEXIBLE_ATTRIBUTES = %w(sectnums)

  # A collection of regular expressions used by the parser.
  #
  # NOTE: The following pattern, which appears frequently, captures the
  # contents between square brackets, ignoring escaped closing brackets
  # (closing brackets prefixed with a backslash '\' character)
  #
  #   Pattern: (?:\[((?:\\\]|[^\]])*?)\])
  #   Matches: [enclosed text here] or [enclosed [text\] here]
  #
  #(pseudo)module Rx

    ## Regular expression character classes (to ensure regexp compatibility between Ruby and JavaScript)
    ## CC stands for "character class", CG stands for "character class group"

    # NOTE \w matches only the ASCII word characters, whereas [[:word:]] or \p{Word} matches any character in the Unicode word category.

    # character classes for the Regexp engine(s) in JavaScript
    if RUBY_ENGINE == 'opal'
      CC_ALPHA = 'a-zA-Z'
      CG_ALPHA = '[a-zA-Z]'
      CC_ALNUM = 'a-zA-Z0-9'
      CG_ALNUM = '[a-zA-Z0-9]'
      CG_BLANK = '[ \\t]'
      CC_EOL   = '(?=\\n|$)'
      CG_GRAPH = '[\\x21-\\x7E]' # non-blank character
      CC_WORD  = 'a-zA-Z0-9_'
      CG_WORD  = '[a-zA-Z0-9_]'
    # character classes for the Regexp engine in Ruby >= 2 (Ruby 1.9 supports \p{} but has problems w/ encoding)
    elsif ::RUBY_MIN_VERSION_2
      CC_ALPHA = CG_ALPHA = '\p{Alpha}'
      CC_ALNUM = CG_ALNUM = '\p{Alnum}'
      CG_BLANK = '\p{Blank}'
      CC_EOL   = '$'
      CG_GRAPH = '\p{Graph}'
      CC_WORD  = CG_WORD = '\p{Word}'
    # character classes for the Regexp engine in Ruby < 2
    else
      CC_ALPHA = '[:alpha:]'
      CG_ALPHA = '[[:alpha:]]'
      CC_ALNUM = '[:alnum:]'
      CG_ALNUM = '[[:alnum:]]'
      CG_BLANK = '[[:blank:]]'
      CC_EOL   = '$'
      CG_GRAPH = '[[:graph:]]' # non-blank character
      if ::RUBY_MIN_VERSION_1_9
        CC_WORD = '[:word:]'
        CG_WORD = '[[:word:]]'
      else
        # NOTE Ruby 1.8 cannot match word characters beyond the ASCII range; if you need this feature, upgrade!
        CC_WORD = '[:alnum:]_'
        CG_WORD = '[[:alnum:]_]'
      end
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

    # Matches the revision info line, which appears immediately following
    # the author info line beneath the document title.
    #
    # Examples
    #
    #   v1.0, 2013-01-01: Ring in the new year release
    #
    RevisionInfoLineRx = /^(?:\D*(.*?),)?(?:\s*(?!:)(.*?))(?:\s*(?!^):\s*(.*))?$/

    # Matches the title and volnum in the manpage doctype.
    #
    # Examples
    #
    #   = asciidoctor ( 1 ) 
    #
    ManpageTitleVolnumRx = /^(.*)\((.*)\)$/

    # Matches the name and purpose in the manpage doctype.
    #
    # Examples
    #
    #   asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats
    #
    ManpageNamePurposeRx = /^(.*?)#{CG_BLANK}+-#{CG_BLANK}+(.*)$/

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
    ConditionalDirectiveRx = /^\\?(ifdef|ifndef|ifeval|endif)::(\S*?(?:([,\+])\S+?)?)\[(.+)?\]$/

    # Matches a restricted (read as safe) eval expression.
    #
    # Examples
    #
    #   "{asciidoctor-version}" >= "0.1.0"
    #
    EvalExpressionRx = /^(\S.*?)#{CG_BLANK}*(==|!=|<=|>=|<|>)#{CG_BLANK}*(\S.*)$/

    # Matches an include preprocessor directive.
    #
    # Examples
    #
    #   include::chapter1.ad[]
    #   include::example.txt[lines=1;2;5..10]
    #
    IncludeDirectiveRx = /^\\?include::([^\[]+)\[(.*?)\]$/

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
    TagDirectiveRx = /\b(?:tag|end)::\S+\[\]$/

    ## Attribute entries and references

    # Matches a document attribute entry.
    #
    # Examples
    #
    #   :foo: bar
    #   :First Name: Dan
    #   :sectnums!:
    #   :!toc:
    #   :long-entry: Attribute value lines ending in ' +'
    #                are joined together as a single value,
    #                collapsing the line breaks and indentation to
    #                a single space.
    #
    AttributeEntryRx = /^:(!?\w.*?):(?:#{CG_BLANK}+(.*))?$/

    # Matches invalid characters in an attribute name.
    InvalidAttributeNameCharsRx = /[^\w\-]/

    # Matches the pass inline macro allowed in value of attribute assignment.
    #
    # Examples
    #
    #   pass:[text]
    #
    AttributeEntryPassMacroRx = /^pass:([a-z,]*)\[(.*)\]$/

    # Matches an inline attribute reference.
    #
    # Examples
    #
    #   {foo}
    #   {counter:pcount:1}
    #   {set:foo:bar}
    #   {set:name!}
    #
    AttributeReferenceRx = /(\\)?\{((set|counter2?):.+?|\w+(?:[\-]\w+)*)(\\)?\}/

    ## Paragraphs and delimited blocks

    # Matches an anchor (i.e., id + optional reference text) on a line above a block.
    #
    # Examples
    #
    #   [[idname]]
    #   [[idname,Reference Text]]
    #
    BlockAnchorRx = /^\[\[(?:|([#{CC_ALPHA}:_][#{CC_WORD}:.-]*)(?:,#{CG_BLANK}*(\S.*))?)\]\]$/

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
    BlockAttributeListRx = /^\[(|#{CG_BLANK}*[#{CC_WORD}\{,.#"'%].*)\]$/

    # A combined pattern that matches either a block anchor or a block attribute list.
    #
    # TODO this one gets hit a lot, should be optimized as much as possible
    BlockAttributeLineRx = /^\[(|#{CG_BLANK}*[#{CC_WORD}\{,.#"'%].*|\[(?:|[#{CC_ALPHA}:_][#{CC_WORD}:.-]*(?:,#{CG_BLANK}*\S.*)?)\])\]$/

    # Matches a title above a block.
    #
    # Examples
    #
    #   .Title goes here
    #
    BlockTitleRx = /^\.([^\s.].*)$/

    # Matches an admonition label at the start of a paragraph.
    #
    # Examples
    #
    #   NOTE: Just a little note.
    #   TIP: Don't forget!
    #
    AdmonitionParagraphRx = /^(#{ADMONITION_STYLES.to_a * '|'}):#{CG_BLANK}/

    # Matches a literal paragraph, which is a line of text preceded by at least one space.
    #
    # Examples
    #
    #   <SPACE>Foo
    #   <TAB>Foo
    LiteralParagraphRx = /^(#{CG_BLANK}+.*)$/

    # Matches a comment block.
    #
    # Examples
    #
    #   ////
    #   This is a block comment.
    #   It can span one or more lines.
    #   ////
    CommentBlockRx = %r{^/{4,}$}

    # Matches a comment line.
    #
    # Examples
    #
    #   // an then whatever
    #
    CommentLineRx = %r{^//(?:[^/]|$)}

    ## Section titles

    # Matches a single-line (Atx-style) section title.
    #
    # Examples
    #
    #   == Foo
    #   # ^ a level 1 (h2) section title
    #
    #   == Foo ==
    #   # ^ also a level 1 (h2) section title
    #
    # match[1] is the delimiter, whose length determines the level
    # match[2] is the title itself
    # match[3] is an inline anchor, which becomes the section id
    AtxSectionRx = /^((?:=|#){1,6})#{CG_BLANK}+(\S.*?)(?:#{CG_BLANK}+\1)?$/

    # Matches the restricted section name for a two-line (Setext-style) section title.
    # The name cannot begin with a dot and has at least one alphanumeric character.
    SetextSectionTitleRx = /^((?=.*#{CG_WORD}+.*)[^.].*?)$/

    # Matches the underline in a two-line (Setext-style) section title.
    #
    # Examples
    #
    #   ======  || ------ || ~~~~~~ || ^^^^^^ || ++++++
    #
    SetextSectionLineRx = /^(?:=|-|~|\^|\+)+$/

    # Matches an anchor (i.e., id + optional reference text) inside a section title.
    #
    # Examples
    #
    #   Section Title [[idname]]
    #   Section Title [[idname,Reference Text]]
    #
    InlineSectionAnchorRx = /^(.*?)#{CG_BLANK}+(\\)?\[\[([#{CC_ALPHA}:_][#{CC_WORD}:.-]*)(?:,#{CG_BLANK}*(\S.*?))?\]\]$/

    # Matches invalid characters in a section id.
    InvalidSectionIdCharsRx = /&(?:[a-zA-Z]{2,}|#\d{2,5}|#x[a-fA-F0-9]{2,4});|[^#{CC_WORD}]+?/

    # Matches the block style used to designate a section title as a floating title.
    #
    # Examples
    #
    #   [float]
    #   = Floating Title
    #
    FloatingTitleStyleRx = /^(?:float|discrete)\b/

    ## Lists

    # Detects the start of any list item.
    AnyListRx = /^(?:<?\d+>#{CG_BLANK}+#{CG_GRAPH}|#{CG_BLANK}*(?:-|(?:\*|\.){1,5}|\d+\.|[a-zA-Z]\.|[IVXivx]+\))#{CG_BLANK}+#{CG_GRAPH}|#{CG_BLANK}*.*?(?::{2,4}|;;)(?:#{CG_BLANK}+#{CG_GRAPH}|$))/

    # Matches an unordered list item (one level for hyphens, up to 5 levels for asterisks).
    #
    # Examples
    #
    #   * Foo
    #   - Foo
    #
    UnorderedListRx = /^#{CG_BLANK}*(-|\*{1,5})#{CG_BLANK}+(.*)$/

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
    OrderedListRx = /^#{CG_BLANK}*(\.{1,5}|\d+\.|[a-zA-Z]\.|[IVXivx]+\))#{CG_BLANK}+(.*)$/

    # Matches the ordinals for each type of ordered list.
    OrderedListMarkerRxMap = {
      :arabic => /\d+[.>]/,
      :loweralpha => /[a-z]\./,
      :lowerroman => /[ivx]+\)/,
      :upperalpha => /[A-Z]\./,
      :upperroman => /[IVX]+\)/
      #:lowergreek => /[a-z]\]/
    }

    # Matches a definition list item.
    #
    # Examples
    #
    #   foo::
    #   foo:::
    #   foo::::
    #   foo;;
    #
    #   # should be followed by a definition, on the same line...
    #
    #   foo:: That which precedes 'bar' (see also, <<bar>>)
    #
    #   # ...or on a separate line
    #
    #   foo::
    #     That which precedes 'bar' (see also, <<bar>>)
    #
    #   # the term may be an attribute reference
    #
    #   {foo_term}:: {foo_def}
    #
    # NOTE negative match for comment line is intentional since that isn't handled when looking for next list item
    # QUESTION should we check for line comment in regex or when scanning the lines?
    # 
    DefinitionListRx = /^(?!\/\/)#{CG_BLANK}*(.*?)(:{2,4}|;;)(?:#{CG_BLANK}+(.*))?$/

    # Matches a sibling definition list item (which does not include the keyed type).
    DefinitionListSiblingRx = {
      # (?:.*?[^:])? - a non-capturing group which grabs longest sequence of characters that doesn't end w/ colon
      '::' => /^(?!\/\/)#{CG_BLANK}*((?:.*[^:])?)(::)(?:#{CG_BLANK}+(.*))?$/,
      ':::' => /^(?!\/\/)#{CG_BLANK}*((?:.*[^:])?)(:::)(?:#{CG_BLANK}+(.*))?$/,
      '::::' => /^(?!\/\/)#{CG_BLANK}*((?:.*[^:])?)(::::)(?:#{CG_BLANK}+(.*))?$/,
      ';;' => /^(?!\/\/)#{CG_BLANK}*(.*)(;;)(?:#{CG_BLANK}+(.*))?$/
    }

    # Matches a callout list item.
    #
    # Examples
    #
    #   <1> Foo
    #
    CalloutListRx = /^<?(\d+)>#{CG_BLANK}+(.*)/

    # Matches a callout reference inside literal text.
    # 
    # Examples
    #   <1> (optionally prefixed by //, # or ;; line comment chars)
    #   <1> <2> (multiple callouts on one line)
    #   <!--1--> (for XML-based languages)
    #
    # NOTE special characters are already be replaced at this point during conversion to an SGML format
    CalloutConvertRx = /(?:(?:\/\/|#|;;) ?)?(\\)?&lt;!?(--|)(\d+)\2&gt;(?=(?: ?\\?&lt;!?\2\d+\2&gt;)*#{CC_EOL})/
    # NOTE (con't) ...but not while scanning
    CalloutQuickScanRx = /\\?<!?(--|)(\d+)\1>(?=(?: ?\\?<!?\1\d+\1>)*#{CC_EOL})/
    CalloutScanRx = /(?:(?:\/\/|#|;;) ?)?(\\)?<!?(--|)(\d+)\2>(?=(?: ?\\?<!?\2\d+\2>)*#{CC_EOL})/

    # A Hash of regexps for lists used for dynamic access.
    ListRxMap = {
      :ulist => UnorderedListRx,
      :olist => OrderedListRx,
      :dlist => DefinitionListRx,
      :colist => CalloutListRx
    }

    ## Tables

    # Parses the column spec (i.e., colspec) for a table.
    #
    # Examples
    #
    #   1*h,2*,^3e
    #
    ColumnSpecRx = /^(?:(\d+)\*)?([<^>](?:\.[<^>]?)?|(?:[<^>]?\.)?[<^>])?(\d+%?)?([a-z])?$/

    # Parses the start and end of a cell spec (i.e., cellspec) for a table.
    #
    # Examples
    #
    #   2.3+<.>m
    #
    # FIXME use step-wise scan (or treetop) rather than this mega-regexp
    CellSpecStartRx = /^#{CG_BLANK}*(?:(\d+(?:\.\d*)?|(?:\d*\.)?\d+)([*+]))?([<^>](?:\.[<^>]?)?|(?:[<^>]?\.)?[<^>])?([a-z])?$/
    CellSpecEndRx = /#{CG_BLANK}+(?:(\d+(?:\.\d*)?|(?:\d*\.)?\d+)([*+]))?([<^>](?:\.[<^>]?)?|(?:[<^>]?\.)?[<^>])?([a-z])?$/

    # Block macros

    # Matches the general block macro pattern.
    #
    # Examples
    # 
    #   gist::123456[]
    #
    #--
    # NOTE we've relaxed the match for target to accomodate the short format (e.g., name::[attrlist])
    GenericBlockMacroRx = /^(#{CG_WORD}+)::(\S*?)\[((?:\\\]|[^\]])*?)\]$/

    # Matches an image, video or audio block macro.
    #
    # Examples
    #
    #   image::filename.png[Caption]
    #   video::http://youtube.com/12345[Cats vs Dogs]
    #
    MediaBlockMacroRx = /^(image|video|audio)::(\S+?)\[((?:\\\]|[^\]])*?)\]$/

    # Matches the TOC block macro.
    #
    # Examples
    #
    #   toc::[]
    #   toc::[levels=2]
    #
    TocBlockMacroRx = /^toc::\[(.*?)\]$/

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
    InlineAnchorRx = /\\?(?:\[\[([#{CC_ALPHA}:_][#{CC_WORD}:.-]*)(?:,#{CG_BLANK}*(\S.*?))?\]\]|anchor:(\S+)\[(.*?[^\\])?\])/

    # Matches a bibliography anchor anywhere inline.
    #
    # Examples
    #
    #   [[[Foo]]]
    #
    InlineBiblioAnchorRx = /\\?\[\[\[([#{CC_WORD}:][#{CC_WORD}:.-]*?)\]\]\]/

    # Matches an inline e-mail address.
    #
    #   doc.writer@example.com
    #
    EmailInlineMacroRx = /([\\>:\/])?#{CG_WORD}[#{CC_WORD}.%+-]*@#{CG_ALNUM}[#{CC_ALNUM}.-]*\.#{CG_ALPHA}{2,4}\b/

    # Matches an inline footnote macro, which is allowed to span multiple lines.
    #
    # Examples
    #   footnote:[text]
    #   footnoteref:[id,text]
    #   footnoteref:[id]
    #
    FootnoteInlineMacroRx = /\\?(footnote(?:ref)?):\[(.*?[^\\])\]/m

    # Matches an image or icon inline macro.
    #
    # Examples
    #
    #   image:filename.png[Alt Text]
    #   image:http://example.com/images/filename.png[Alt Text]
    #   image:filename.png[More [Alt\] Text] (alt text becomes "More [Alt] Text")
    #   icon:github[large]
    #
    ImageInlineMacroRx = /\\?(?:image|icon):([^:\[][^\[]*)\[((?:\\\]|[^\]])*?)\]/

    # Matches an indexterm inline macro, which may span multiple lines.
    #
    # Examples
    #
    #   indexterm:[Tigers,Big cats]
    #   (((Tigers,Big cats)))
    #   indexterm2:[Tigers]
    #   ((Tigers))
    #
    IndextermInlineMacroRx = /\\?(?:(indexterm2?):\[(.*?[^\\])\]|\(\((.+?)\)\)(?!\)))/m

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
    KbdBtnInlineMacroRx = /\\?(?:kbd|btn):\[((?:\\\]|[^\]])+?)\]/

    # Matches the delimiter used for kbd value.
    #
    # Examples
    #
    #   Ctrl + Alt+T
    #   Ctrl,T
    #
    KbdDelimiterRx = /(?:\+|,)(?=#{CG_BLANK}*[^\1])/

    # Matches an implicit link and some of the link inline macro.
    #
    # Examples
    # 
    #   http://github.com
    #   http://github.com[GitHub]
    #
    # FIXME revisit! the main issue is we need different rules for implicit vs explicit
    LinkInlineRx = %r{(^|link:|&lt;|[\s>\(\)\[\];])(\\?(?:https?|file|ftp|irc)://[^\s\[\]<]*[^\s.,\[\]<])(?:\[((?:\\\]|[^\]])*?)\])?}

    # Match a link or e-mail inline macro.
    #
    # Examples
    #
    #   link:path[label]
    #   mailto:doc.writer@example.com[]
    #
    LinkInlineMacroRx = /\\?(?:link|mailto):([^\s\[]+)(?:\[((?:\\\]|[^\]])*?)\])/

    # Matches a stem (and alternatives, asciimath and latexmath) inline macro, which may span multiple lines.
    #
    # Examples
    #
    #   stem:[x != 0]
    #   asciimath:[x != 0]
    #   latexmath:[\sqrt{4} = 2]
    #
    StemInlineMacroRx = /\\?(stem|(?:latex|ascii)math):([a-z,]*)\[(.*?[^\\])\]/m

    # Matches a menu inline macro.
    #
    # Examples
    #
    #   menu:File[New...]
    #   menu:View[Page Style > No Style]
    #   menu:View[Page Style, No Style]
    #
    MenuInlineMacroRx = /\\?menu:(#{CG_WORD}|#{CG_WORD}.*?\S)\[#{CG_BLANK}*(.+?)?\]/

    # Matches an implicit menu inline macro.
    #
    # Examples
    #
    #   "File > New..."
    #
    MenuInlineRx = /\\?"(#{CG_WORD}[^"]*?#{CG_BLANK}*&gt;#{CG_BLANK}*[^" \t][^"]*)"/

    # Matches an inline passthrough value, which may span multiple lines.
    #
    # Examples
    #
    #   +text+
    #   `text` (compat)
    #
    # NOTE we always capture the attributes so we know when to use compatible (i.e., legacy) behavior
    PassInlineRx = {
      false => ['+', '`', /(^|[^#{CC_WORD};:])(?:\[([^\]]+?)\])?(\\?(\+|`)(\S|\S.*?\S)\4)(?!#{CC_WORD})/m],
      true  => ['`', nil, /(^|[^`#{CC_WORD}])(?:\[([^\]]+?)\])?(\\?(`)([^`\s]|[^`\s].*?\S)\4)(?![`#{CC_WORD}])/m]
    }

    # Matches several variants of the passthrough inline macro, which may span multiple lines.
    #
    # Examples
    #
    #   +++text+++
    #   $$text$$
    #   pass:quotes[text]
    #
    PassInlineMacroRx = /(?:(?:(\\?)\[([^\]]+?)\])?(\\{0,2})(\+{2,3}|\${2})(.*?)\4|(\\?)pass:([a-z,]*)\[(.*?[^\\])\])/m

    # Matches an xref (i.e., cross-reference) inline macro, which may span multiple lines.
    #
    # Examples
    #
    #   <<id,reftext>>
    #   xref:id[reftext]
    #
    # NOTE special characters have already been escaped, hence the entity references
    XrefInlineMacroRx = /\\?(?:&lt;&lt;([#{CC_WORD}":].*?)&gt;&gt;|xref:([#{CC_WORD}":].*?)\[(.*?)\])/m

    ## Layout

    # Matches a trailing + preceded by at least one space character,
    # which forces a hard line break (<br> tag in HTML outputs).
    #
    # Examples
    #
    #    +
    #   Foo +
    #
    # NOTE: JavaScript only treats ^ and $ as line boundaries in multiline regexp
    LineBreakRx = if RUBY_ENGINE == 'opal'
      /^(.*)[ \t]\+$/m
    else
      /^(.*)[[:blank:]]\+$/
    end

    # Matches an AsciiDoc horizontal rule or AsciiDoc page break.
    #
    # Examples
    #
    #   ''' (horizontal rule)
    #   <<< (page break)
    #
    LayoutBreakLineRx = /^('|<){3,}$/

    # Matches an AsciiDoc or Markdown horizontal rule or AsciiDoc page break.
    #
    # Examples
    #
    #   ''' or ' ' ' (horizontal rule)
    #   --- or - - - (horizontal rule)
    #   *** or * * * (horizontal rule)
    #   <<< (page break)
    #
    LayoutBreakLinePlusRx = /^(?:'|<){3,}$|^ {0,3}([-\*_])( *)\1\2\1$/

    ## General

    # Matches a blank line.
    #
    # NOTE allows for empty space in line as it could be left by the template engine
    BlankLineRx = /^#{CG_BLANK}*\n/

    # Matches a comma or semi-colon delimiter.
    #
    # Examples
    #
    #   one,two
    #   three;four
    #
    DataDelimiterRx = /,|;/ 

    # Matches one or more consecutive digits on a single line.
    #
    # Examples
    #
    #   29
    #
    DigitsRx = /^\d+$/

    # Matches a single-line of text enclosed in double quotes, capturing the quote char and text.
    #
    # Examples
    #
    #   "Who goes there?"
    #
    DoubleQuotedRx = /^("|)(.*)\1$/

    # Matches multiple lines of text enclosed in double quotes, capturing the quote char and text.
    #
    # Examples
    #
    #   "I am a run-on sentence and I like
    #   to take up multiple lines and I
    #   still want to be matched."
    #
    DoubleQuotedMultiRx = /^("|)(.*)\1$/m

    # Matches one or more consecutive digits at the end of a line.
    #
    # Examples
    #
    #   docbook45
    #   html5
    #
    TrailingDigitsRx = /\d+$/

    # Matches a space escaped by a backslash.
    #
    # Examples
    # 
    #   one\ two\ three
    #
    EscapedSpaceRx = /\\(#{CG_BLANK})/

    # Matches a space delimiter that's not escaped.
    #
    # Examples
    #
    #   one two	three	four
    #
    SpaceDelimiterRx = /([^\\])#{CG_BLANK}+/

    # Matches a + or - modifier in a subs list
    #
    SubModifierSniffRx = /[+-]/

    # Matches any character with multibyte support explicitly enabled (length of multibyte char = 1)
    #
    # NOTE If necessary to hide use of the language modifier (u) from JavaScript, use (Regexp.new '.', false, 'u')
    #
    UnicodeCharScanRx = unless RUBY_ENGINE == 'opal'
      FORCE_UNICODE_LINE_LENGTH ? /./u : nil
    end

    # Detects strings that resemble URIs.
    #
    # Examples
    #   http://domain
    #   https://domain
    #   data:info
    #
    UriSniffRx = %r{^#{CG_ALPHA}[#{CC_ALNUM}.+-]*:/{0,2}}

    # Detects the end of an implicit URI in the text
    #
    # Examples
    #
    #   (http://google.com)
    #   &gt;http://google.com&lt;
    #   (See http://google.com):
    #
    UriTerminator = /[);:]$/

    # Detects XML tags
    XmlSanitizeRx = /<[^>]+>/

    # Unused

    # Detects any fenced block delimiter, including:
    #   listing, literal, example, sidebar, quote, passthrough, table and fenced code
    # Does not match open blocks or air quotes
    # TIP position the most common blocks towards the front of the pattern
    #BlockDelimiterRx = %r{^(?:(?:-|\.|=|\*|_|\+|/){4,}|[\|,;!]={3,}|(?:`|~){3,}.*)$}

    # Matches an escaped single quote within a word
    #
    # Examples
    #
    #   Here\'s Johnny!
    #
    #EscapedSingleQuoteRx = /(#{CG_WORD})\\'(#{CG_WORD})/
    # an alternative if our backend generates single-quoted html/xml attributes
    #EscapedSingleQuoteRx = /(#{CG_WORD}|=)\\'(#{CG_WORD})/

    # Matches whitespace at the beginning of the line
    #LeadingSpacesRx = /^(#{CG_BLANK}*)/

    # Matches parent directory references at the beginning of a path
    #LeadingParentDirsRx = /^(?:\.\.\/)*/

    #StripLineWise = /\A(?:\s*\n)?(.*?)\s*\z/m
  #end

  INTRINSIC_ATTRIBUTES = {
    'startsb'    => '[',
    'endsb'      => ']',
    'vbar'       => '|',
    'caret'      => '^',
    'asterisk'   => '*',
    'tilde'      => '~',
    'plus'       => '&#43;',
    'apostrophe' => '\'',
    'backslash'  => '\\',
    'backtick'   => '`',
    'empty'      => '',
    'sp'         => ' ',
    'space'      => ' ',
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
    'amp'        => '&',
    'lt'         => '<',
    'gt'         => '>'
  }

  # unconstrained quotes:: can appear anywhere
  # constrained quotes:: must be bordered by non-word characters
  # NOTE these substitutions are processed in the order they appear here and
  # the order in which they are replaced is important
  quote_subs = [
    # **strong**
    [:strong, :unconstrained, /\\?(?:\[([^\]]+?)\])?\*\*(.+?)\*\*/m],

    # *strong*
    [:strong, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?\*(\S|\S.*?\S)\*(?!#{CG_WORD})/m],

    # "`double-quoted`"
    [:double, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?"`(\S|\S.*?\S)`"(?!#{CG_WORD})/m],

    # '`single-quoted`'
    [:single, :constrained, /(^|[^#{CC_WORD};:`}])(?:\[([^\]]+?)\])?'`(\S|\S.*?\S)`'(?!#{CG_WORD})/m],

    # ``monospaced``
    [:monospaced, :unconstrained, /\\?(?:\[([^\]]+?)\])?``(.+?)``/m],

    # `monospaced`
    [:monospaced, :constrained, /(^|[^#{CC_WORD};:"'`}])(?:\[([^\]]+?)\])?`(\S|\S.*?\S)`(?![#{CC_WORD}"'`])/m],

    # __emphasis__
    [:emphasis, :unconstrained, /\\?(?:\[([^\]]+?)\])?__(.+?)__/m],

    # _emphasis_
    [:emphasis, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?_(\S|\S.*?\S)_(?!#{CG_WORD})/m],

    # ##mark## (referred to in AsciiDoc Python as unquoted)
    [:mark, :unconstrained, /\\?(?:\[([^\]]+?)\])?##(.+?)##/m],

    # #mark# (referred to in AsciiDoc Python as unquoted)
    [:mark, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?#(\S|\S.*?\S)#(?!#{CG_WORD})/m],

    # ^superscript^
    [:superscript, :unconstrained, /\\?(?:\[([^\]]+?)\])?\^(\S*?)\^/m],

    # ~subscript~
    [:subscript, :unconstrained, /\\?(?:\[([^\]]+?)\])?~(\S*?)~/m]
  ]

  compat_quote_subs = quote_subs.dup
  # ``quoted''
  compat_quote_subs[2] = [:double, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?``(\S|\S.*?\S)''(?!#{CG_WORD})/m]
  # `quoted'
  compat_quote_subs[3] = [:single, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?`(\S|\S.*?\S)'(?!#{CG_WORD})/m]
  # ++monospaced++
  compat_quote_subs[4] = [:monospaced, :unconstrained, /\\?(?:\[([^\]]+?)\])?\+\+(.+?)\+\+/m]
  # +monospaced+
  compat_quote_subs[5] = [:monospaced, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?\+(\S|\S.*?\S)\+(?!#{CG_WORD})/m]
  # 'emphasis'
  compat_quote_subs.insert 3, [:emphasis, :constrained, /(^|[^#{CC_WORD};:}])(?:\[([^\]]+?)\])?'(\S|\S.*?\S)'(?!#{CG_WORD})/m]

  QUOTE_SUBS = {
    false => quote_subs,
    true  => compat_quote_subs
  }
  quote_subs = nil
  compat_quote_subs = nil

  # NOTE in Ruby 1.8.7, [^\\] does not match start of line,
  # so we need to match it explicitly
  # order is significant
  REPLACEMENTS = [
    # (C)
    [/\\?\(C\)/, '&#169;', :none],
    # (R)
    [/\\?\(R\)/, '&#174;', :none],
    # (TM)
    [/\\?\(TM\)/, '&#8482;', :none],
    # foo -- bar
    [/(^|\n| |\\)--( |\n|$)/, '&#8201;&#8212;&#8201;', :none],
    # foo--bar
    [/(#{CG_WORD})\\?--(?=#{CG_WORD})/, '&#8212;', :leading],
    # ellipsis
    [/\\?\.\.\./, '&#8230;', :leading],
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
    [/\\?(&)amp;((?:[a-zA-Z]+|#\d{2,5}|#x[a-fA-F0-9]{2,4});)/, '', :bounding]
  ]

  class << self

  # Public: Parse the AsciiDoc source input into a {Document}
  #
  # Accepts input as an IO (or StringIO), String or String Array object. If the
  # input is a File, information about the file is stored in attributes on the
  # Document object.
  #
  # input   - the AsciiDoc source as a IO, String or Array.
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See {Document#initialize} for details about these options.
  #
  # Returns the Document
  def load input, options = {}
    options = options.dup
    if (timings = options[:timings])
      timings.start :read
    end

    attributes = options[:attributes] = if !(attrs = options[:attributes])
      {}
    elsif (attrs.is_a? ::Hash) || (::RUBY_ENGINE_JRUBY && (attrs.is_a? ::Java::JavaUtil::Map))
      attrs.dup
    elsif attrs.is_a? ::Array
      attrs.inject({}) do |accum, entry|
        k, v = entry.split '=', 2
        accum[k] = v || ''
        accum
      end
    elsif attrs.is_a? ::String
      # convert non-escaped spaces into null character, so we split on the
      # correct spaces chars, and restore escaped spaces
      capture_1 = ::RUBY_ENGINE_OPAL ? '$1' : '\1'
      attrs = attrs.gsub(SpaceDelimiterRx, %(#{capture_1}#{NULL})).gsub(EscapedSpaceRx, capture_1)

      attrs.split(NULL).inject({}) do |accum, entry|
        k, v = entry.split '=', 2
        accum[k] = v || ''
        accum
      end
    elsif (attrs.respond_to? :keys) && (attrs.respond_to? :[])
      # convert it to a Hash as we know it
      original_attrs = attrs
      attrs = {}
      original_attrs.keys.each do |key|
        attrs[key] = original_attrs[key]
      end
      attrs
    else
      raise ::ArgumentError, %(illegal type for attributes option: #{attrs.class.ancestors})
    end

    lines = nil
    if input.is_a? ::File
      lines = input.readlines
      input_mtime = input.mtime
      input = ::File.new ::File.expand_path input.path
      input_path = input.path
      # hold off on setting infile and indir until we get a better sense of their purpose
      attributes['docfile'] = input_path
      attributes['docdir'] = ::File.dirname input_path
      attributes['docname'] = ::File.basename input_path, (::File.extname input_path)
      attributes['docdate'] = docdate = input_mtime.strftime('%Y-%m-%d')
      attributes['doctime'] = doctime = input_mtime.strftime('%H:%M:%S %Z')
      attributes['docdatetime'] = %(#{docdate} #{doctime})
    elsif input.respond_to? :readlines
      # NOTE tty, pipes & sockets can't be rewound, but can't be sniffed easily either
      # just fail the rewind operation silently to handle all cases
      begin
        input.rewind
      rescue
      end
      lines = input.readlines
    elsif input.is_a? ::String
      lines = input.lines.entries
    elsif input.is_a? ::Array
      lines = input.dup
    else
      raise ::ArgumentError, %(Unsupported input type: #{input.class})
    end

    if timings
      timings.record :read
      timings.start :parse
    end

    doc = (options[:parse] == false ? (Document.new lines, options) : (Document.new lines,options).parse)
    timings.record :parse if timings
    doc
  end

  # Public: Parse the contents of the AsciiDoc source file into an Asciidoctor::Document
  #
  # Accepts input as an IO, String or String Array object. If the
  # input is a File, information about the file is stored in
  # attributes on the Document.
  #
  # input   - the String AsciiDoc source filename
  # options - a String, Array or Hash of options to control processing (default: {})
  #           String and Array values are converted into a Hash.
  #           See Asciidoctor::Document#initialize for details about options.
  #
  # Returns the Asciidoctor::Document
  def load_file filename, options = {}
    self.load ::File.new(filename || ''), options
  end

  # Public: Parse the AsciiDoc source input into an Asciidoctor::Document and
  # convert it to the specified backend format.
  #
  # Accepts input as an IO, String or String Array object. If the
  # input is a File, information about the file is stored in
  # attributes on the Document.
  #
  # If the :in_place option is true, and the input is a File, the output is
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
    options = options.dup
    to_file = options.delete(:to_file)
    to_dir = options.delete(:to_dir)
    mkdirs = options.delete(:mkdirs) || false
    timings = options[:timings]

    case to_file
    when true, nil
      write_to_same_dir = !to_dir && (input.is_a? ::File)
      stream_output = false
      write_to_target = to_dir
      to_file = nil
    when false
      write_to_same_dir = false
      stream_output = false
      write_to_target = false
      to_file = nil
    else
      write_to_same_dir = false
      stream_output = to_file.respond_to? :write
      write_to_target = stream_output ? false : to_file
    end

    if !options.key?(:header_footer) && (write_to_same_dir || write_to_target)
      options[:header_footer] = true
    end

    doc = self.load input, options

    if to_file == '/dev/null'
      return doc
    elsif write_to_same_dir
      infile = ::File.expand_path input.path
      outfile = ::File.join ::File.dirname(infile), %(#{doc.attributes['docname']}#{doc.attributes['outfilesuffix']})
      if outfile == infile
        raise ::IOError, 'Input file and output file are the same!'
      end
      outdir = ::File.dirname outfile
    elsif write_to_target
      working_dir = options.has_key?(:base_dir) ? ::File.expand_path(options[:base_dir]) : ::File.expand_path(::Dir.pwd)
      # QUESTION should the jail be the working_dir or doc.base_dir???
      jail = doc.safe >= SafeMode::SAFE ? working_dir : nil
      if to_dir
        outdir = doc.normalize_system_path(to_dir, working_dir, jail, :target_name => 'to_dir', :recover => false)
        if to_file
          outfile = doc.normalize_system_path(to_file, outdir, nil, :target_name => 'to_dir', :recover => false)
          # reestablish outdir as the final target directory (in the case to_file had directory segments)
          outdir = ::File.dirname outfile
        else
          outfile = ::File.join outdir, %(#{doc.attributes['docname']}#{doc.attributes['outfilesuffix']})
        end
      elsif to_file
        outfile = doc.normalize_system_path(to_file, working_dir, jail, :target_name => 'to_dir', :recover => false)
        # establish outdir as the final target directory (in the case to_file had directory segments)
        outdir = ::File.dirname outfile
      end

      unless ::File.directory? outdir
        if mkdirs
          ::FileUtils.mkdir_p outdir
        else
          # NOTE we intentionally refer to the directory as it was passed to the API
          raise ::IOError, %(target directory does not exist: #{to_dir})
        end
      end
    else
      outfile = to_file
      outdir = nil
    end

    timings.start :convert if timings
    output = doc.convert
    timings.record :convert if timings

    if outfile
      timings.start :write if timings
      unless stream_output
        doc.attributes['outfile'] = outfile
        doc.attributes['outdir'] = outdir
      end
      doc.write output, outfile
      timings.record :write if timings

      # NOTE document cannot control this behavior if safe >= SafeMode::SERVER
      if !stream_output && doc.safe < SafeMode::SECURE && (doc.attr? 'basebackend-html') &&
          (doc.attr? 'linkcss') && (doc.attr? 'copycss')
        copy_asciidoctor_stylesheet = DEFAULT_STYLESHEET_KEYS.include?(stylesheet = (doc.attr 'stylesheet'))
        copy_user_stylesheet = !copy_asciidoctor_stylesheet && !stylesheet.nil_or_empty?
        copy_coderay_stylesheet = (doc.attr? 'source-highlighter', 'coderay') && (doc.attr 'coderay-css', 'class') == 'class'
        copy_pygments_stylesheet = (doc.attr? 'source-highlighter', 'pygments') && (doc.attr 'pygments-css', 'class') == 'class'
        if copy_asciidoctor_stylesheet || copy_user_stylesheet || copy_coderay_stylesheet || copy_pygments_stylesheet
          outdir = doc.attr('outdir')
          stylesoutdir = doc.normalize_system_path(doc.attr('stylesdir'), outdir,
              doc.safe >= SafeMode::SAFE ? outdir : nil)
          Helpers.mkdir_p stylesoutdir if mkdirs

          if copy_asciidoctor_stylesheet
            Stylesheets.instance.write_primary_stylesheet stylesoutdir
          # FIXME should Stylesheets also handle the user stylesheet?
          elsif copy_user_stylesheet
            if (stylesheet_src = (doc.attr 'copycss')).empty?
              stylesheet_src = doc.normalize_system_path stylesheet
            else
              stylesheet_src = doc.normalize_system_path stylesheet_src
            end
            stylesheet_dst = doc.normalize_system_path stylesheet, stylesoutdir, (doc.safe >= SafeMode::SAFE ? outdir : nil)
            unless stylesheet_src == stylesheet_dst || (stylesheet_content = doc.read_asset stylesheet_src).nil?
              ::File.open(stylesheet_dst, 'w') {|f|
                f.write stylesheet_content
              }
            end
          end

          if copy_coderay_stylesheet
            Stylesheets.instance.write_coderay_stylesheet stylesoutdir
          elsif copy_pygments_stylesheet
            Stylesheets.instance.write_pygments_stylesheet stylesoutdir, (doc.attr 'pygments-style')
          end
        end
      end
      doc
    else
      output
    end
  end

  # Alias render to convert to maintain backwards compatibility
  alias :render :convert

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
    self.convert ::File.new(filename || ''), options
  end

  # Alias render_file to convert_file to maintain backwards compatibility
  alias :render_file :convert_file

  end

  if RUBY_ENGINE == 'opal'
    require 'asciidoctor/debug'
    require 'asciidoctor/version'
    require 'asciidoctor/timings'
  else
    autoload :Debug,   'asciidoctor/debug'
    autoload :VERSION, 'asciidoctor/version'
    autoload :Timings, 'asciidoctor/timings'
  end
end

# core extensions
require 'asciidoctor/core_ext'

# modules
require 'asciidoctor/helpers'
require 'asciidoctor/substitutors'

# abstract classes
require 'asciidoctor/abstract_node'
require 'asciidoctor/abstract_block'

# concrete classes
require 'asciidoctor/attribute_list'
require 'asciidoctor/block'
require 'asciidoctor/callouts'
require 'asciidoctor/converter'
require 'asciidoctor/converter/html5' if RUBY_ENGINE_OPAL
require 'asciidoctor/document'
require 'asciidoctor/inline'
require 'asciidoctor/list'
require 'asciidoctor/parser'
require 'asciidoctor/path_resolver'
require 'asciidoctor/reader'
require 'asciidoctor/section'
require 'asciidoctor/stylesheets'
require 'asciidoctor/table'
