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
    UNSAFE = 0

    # A safe mode level that closely parallels safe mode in AsciiDoc. This value
    # prevents access to files which reside outside of the parent directory of
    # the source file and disables any macro other than the include::[] directive.
    SAFE = 1

    # A safe mode level that disallows the document from setting attributes
    # that would affect the conversion of the document, in addition to all the
    # security features of SafeMode::SAFE. For instance, this level forbids
    # changing the backend or source-highlighter using an attribute defined
    # in the source document header. This is the most fundamental level of
    # security for server deployments (hence the name).
    SERVER = 10

    # A safe mode level that disallows the document from attempting to read
    # files from the file system and including the contents of them into the
    # document, in additional to all the security features of SafeMode::SERVER.
    # For instance, this level disallows use of the include::[] directive and the
    # embedding of binary content (data uri), stylesheets and JavaScripts
    # referenced by the document. (Asciidoctor and trusted extensions may still
    # be allowed to embed trusted content into the document).
    #
    # Since Asciidoctor is aiming for wide adoption, this level is the default
    # and is recommended for server deployments.
    SECURE = 20

    # A planned safe mode level that disallows the use of passthrough macros and
    # prevents the document from setting any known attributes, in addition to all
    # the security features of SafeMode::SECURE.
    #
    # Please note that this level is not currently implemented (and therefore not
    # enforced)!
    #PARANOID = 100

    @names_by_value = (constants false).map {|sym| [(const_get sym), sym.to_s.downcase] }.sort {|(a), (b)| a <=> b }.to_h

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

    # Asciidoctor will unwrap the content in a preamble if the document has a
    # title and no sections, then discard the empty preamble.
    # Compliance value: false
    define :unwrap_standalone_preamble, true

    # AsciiDoc drops lines that contain references to missing attributes.
    # This behavior is not intuitive to most writers.
    # Asciidoctor allows this behavior to be configured.
    # Possible options are 'skip', 'drop', 'drop-line', and 'warn'.
    # Compliance value: 'drop-line'
    define :attribute_missing, 'skip'

    # AsciiDoc drops lines that contain an attribute unassignment.
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
    'html' => 'html5',
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

  ADMONITION_STYLE_HEADS = ::Set.new.tap {|accum| ADMONITION_STYLES.each {|s| accum << s.chr } }

  PARAGRAPH_STYLES = ['comment', 'example', 'literal', 'listing', 'normal', 'open', 'pass', 'quote', 'sidebar', 'source', 'verse', 'abstract', 'partintro'].to_set

  VERBATIM_STYLES = ['literal', 'listing', 'source', 'verse'].to_set

  DELIMITED_BLOCKS = {
    '--' => [:open, ['comment', 'example', 'literal', 'listing', 'pass', 'quote', 'sidebar', 'source', 'verse', 'admonition', 'abstract', 'partintro'].to_set],
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
    '```' => [:fenced_code, ::Set.new]
  }

  DELIMITED_BLOCK_HEADS = {}.tap {|accum| DELIMITED_BLOCKS.each_key {|k| accum[k.slice 0, 2] = true } }
  DELIMITED_BLOCK_TAILS = {}.tap {|accum| DELIMITED_BLOCKS.each_key {|k| accum[k] = k[k.length - 1] if k.length == 4 } }

  # NOTE the 'figure' key as a string is historical and used by image blocks
  CAPTION_ATTRIBUTE_NAMES = { example: 'example-caption', 'figure' => 'figure-caption', listing: 'listing-caption', table: 'table-caption' }

  LAYOUT_BREAK_CHARS = {
    '\'' => :thematic_break,
    '<' => :page_break
  }

  MARKDOWN_THEMATIC_BREAK_CHARS = {
    '-' => :thematic_break,
    '*' => :thematic_break,
    '_' => :thematic_break
  }

  HYBRID_LAYOUT_BREAK_CHARS = LAYOUT_BREAK_CHARS.merge MARKDOWN_THEMATIC_BREAK_CHARS

  #LIST_CONTEXTS = [:ulist, :olist, :dlist, :colist]

  NESTABLE_LIST_CONTEXTS = [:ulist, :olist, :dlist]

  # TODO validate use of explicit style name above ordered list (this list is for selecting an implicit style)
  ORDERED_LIST_STYLES = [:arabic, :loweralpha, :lowerroman, :upperalpha, :upperroman] #, :lowergreek]

  ORDERED_LIST_KEYWORDS = {
    #'arabic' => '1',
    #'decimal' => '1',
    'loweralpha' => 'a',
    'lowerroman' => 'i',
    #'lowergreek' => 'a',
    'upperalpha' => 'A',
    'upperroman' => 'I'
  }

  ATTR_REF_HEAD = '{'

  LIST_CONTINUATION = '+'

  # NOTE AsciiDoc.py allows + to be preceded by TAB; Asciidoctor does not
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

  HIGHLIGHT_JS_VERSION = '9.18.3'

  MATHJAX_VERSION = '2.7.9'

  DEFAULT_ATTRIBUTES = {
    'appendix-caption' => 'Appendix',
    'appendix-refsig' => 'Appendix',
    'caution-caption' => 'Caution',
    'chapter-refsig' => 'Chapter',
    #'encoding' => 'UTF-8',
    'example-caption' => 'Example',
    'figure-caption' => 'Figure',
    'important-caption' => 'Important',
    'last-update-label' => 'Last updated',
    #'listing-caption' => 'Listing',
    'note-caption' => 'Note',
    'part-refsig' => 'Part',
    #'preface-title' => 'Preface',
    'prewrap' => '',
    'sectids' => '',
    'section-refsig' => 'Section',
    'table-caption' => 'Table',
    'tip-caption' => 'Tip',
    'toc-placement' => 'auto',
    'toc-title' => 'Table of Contents',
    'untitled-label' => 'Untitled',
    'version-label' => 'Version',
    'warning-caption' => 'Warning',
  }

  # attributes which be changed throughout the flow of the document (e.g., sectnums)
  FLEXIBLE_ATTRIBUTES = ['sectnums']

  INTRINSIC_ATTRIBUTES = {
    'startsb' => '[',
    'endsb' => ']',
    'vbar' => '|',
    'caret' => '^',
    'asterisk' => '*',
    'tilde' => '~',
    'plus' => '&#43;',
    'backslash' => '\\',
    'backtick' => '`',
    'blank' => '',
    'empty' => '',
    'sp' => ' ',
    'two-colons' => '::',
    'two-semicolons' => ';;',
    'nbsp' => '&#160;',
    'deg' => '&#176;',
    'zwsp' => '&#8203;',
    'quot' => '&#34;',
    'apos' => '&#39;',
    'lsquo' => '&#8216;',
    'rsquo' => '&#8217;',
    'ldquo' => '&#8220;',
    'rdquo' => '&#8221;',
    'wj' => '&#8288;',
    'brvbar' => '&#166;',
    'pp' => '&#43;&#43;',
    'cpp' => 'C&#43;&#43;',
    'amp' => '&',
    'lt' => '<',
    'gt' => '>'
  }

  # Regular expression character classes (to ensure regexp compatibility between Ruby and JavaScript)
  # CC stands for "character class", CG stands for "character class group"
  unless RUBY_ENGINE == 'opal'
    # CC_ALL is any character, including newlines (must be accompanied by multiline regexp flag)
    CC_ALL = '.'
    # CC_ANY is any character except newlines
    CC_ANY = '.'
    CC_EOL = '$'
    CC_ALPHA = CG_ALPHA = '\p{Alpha}'
    CC_ALNUM = CG_ALNUM = '\p{Alnum}'
    CG_BLANK = '\p{Blank}'
    CC_WORD = CG_WORD = '\p{Word}'
  end

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
      # ##mark## (referred to in AsciiDoc.py as unquoted)
      [:mark, :unconstrained, /\\?(?:\[([^\]]+)\])?##(#{CC_ALL}+?)##/m],
      # #mark# (referred to in AsciiDoc.py as unquoted)
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
    # NOTE this necessarily drops the newline if replacement appears at end of line
    [/(?: |\n|^|\\)--(?: |\n|$)/, '&#8201;&#8212;&#8201;', :none],
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
  def self.const_missing name
    if name == :Extensions
      require_relative 'asciidoctor/extensions'
      Extensions
    else
      super
    end
  end unless RUBY_ENGINE == 'opal'

  unless RUBY_ENGINE == 'opal'
    autoload :SyntaxHighlighter, %(#{__dir__}/asciidoctor/syntax_highlighter)
    autoload :Timings, %(#{__dir__}/asciidoctor/timings)
  end
end

# core extensions
require_relative 'asciidoctor/core_ext'

# modules and helpers
require_relative 'asciidoctor/helpers'
require_relative 'asciidoctor/logging'
require_relative 'asciidoctor/rx'
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

# main API entry points
require_relative 'asciidoctor/load'
require_relative 'asciidoctor/convert'

if RUBY_ENGINE == 'opal'
  require_relative 'asciidoctor/syntax_highlighter'
  require_relative 'asciidoctor/timings'
  # this require is satisfied by the Asciidoctor.js build; it supplies compile and runtime overrides for Asciidoctor.js
  require 'asciidoctor/js/postscript'
end
