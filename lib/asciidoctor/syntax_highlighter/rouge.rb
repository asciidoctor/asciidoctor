# frozen_string_literal: true
module Asciidoctor
class SyntaxHighlighter::RougeAdapter < SyntaxHighlighter::Base
  register_for 'rouge'

  def initialize *args
    super
    @requires_stylesheet = @style = nil
  end

  def highlight?
    library_available?
  end

  def highlight node, source, lang, opts
    @style ||= (style = opts[:style]) && (style_available? style) || DEFAULT_STYLE
    @requires_stylesheet = true if opts[:css_mode] == :class
    lexer = create_lexer node, source, lang, opts
    formatter = create_formatter node, source, lang, opts
    highlighted = formatter.format lexer.lex source
    if opts[:number_lines] && opts[:callouts]
      [highlighted, (idx = highlighted.index CodeCellStartTagCs) ? idx + CodeCellStartTagCs.length : nil]
    else
      highlighted
    end
  end

  def format node, lang, opts
    if (query_idx = lang && (lang.index '?'))
      lang = lang.slice 0, query_idx
    end
    if opts[:css_mode] != :class && (@style = (style = opts[:style]) && (style_available? style) || DEFAULT_STYLE) && (pre_style_attr_val = base_style @style)
      opts[:transform] = proc {|pre| pre['style'] = pre_style_attr_val }
    end
    super
  end

  def docinfo? location
    @requires_stylesheet && location == :head
  end

  def docinfo location, doc, opts
    if opts[:linkcss]
      %(<link rel="stylesheet" href="#{doc.normalize_web_path (stylesheet_basename @style), (doc.attr 'stylesdir', ''), false}"#{opts[:self_closing_tag_slash]}>)
    else
      %(<style>
#{read_stylesheet @style}
</style>)
    end
  end

  def write_stylesheet? doc
    @requires_stylesheet
  end

  def write_stylesheet doc, to_dir
    ::File.write (::File.join to_dir, (stylesheet_basename @style)), (read_stylesheet @style), mode: FILE_WRITE_MODE
  end

  def create_lexer node, source, lang, opts
    if lang.include? '?'
      # NOTE cgi-style options only properly supported in Rouge >= 2.1
      if (lexer = ::Rouge::Lexer.find_fancy lang)
        unless lexer.tag != 'php' || (node.option? 'mixed') || ((lexer_opts = lexer.options).key? 'start_inline')
          lexer = lexer.class.new lexer_opts.merge 'start_inline' => true
        end
      end
    elsif (lexer = ::Rouge::Lexer.find lang)
      lexer = lexer.tag == 'php' && !(node.option? 'mixed') ? (lexer.new start_inline: true) : lexer.new
    end if lang
    lexer || ::Rouge::Lexers::PlainText.new
  end

  def create_formatter node, source, lang, opts
    formatter = opts[:css_mode] == :class ?
      (::Rouge::Formatters::HTML.new inline_theme: @style) :
      (::Rouge::Formatters::HTMLInline.new (::Rouge::Theme.find @style).new)
    if (highlight_lines = opts[:highlight_lines])
      formatter = RougeExt::Formatters::HTMLLineHighlighter.new formatter, lines: highlight_lines
    end
    opts[:number_lines] ? (RougeExt::Formatters::HTMLTable.new formatter, start_line: opts[:start_line_number]) : formatter
  end

  module Loader
    private

    def library_available?
      (@@library_status ||= load_library) == :loaded ? true : nil
    end

    def load_library
      (defined? RougeExt) ? :loaded : (Helpers.require_library %(#{::File.dirname __dir__}/rouge_ext), 'rouge', :warn).nil? ? :unavailable : :loaded
    end
  end

  module Styles
    include Loader

    def read_stylesheet style
      library_available? ? @@stylesheet_cache[style || DEFAULT_STYLE] : '/* Rouge CSS disabled because Rouge is not available. */'
    end

    def stylesheet_basename style
      %(rouge-#{style || DEFAULT_STYLE}.css)
    end

    private

    def base_style style
      library_available? ? @@base_style_cache[style || DEFAULT_STYLE] : nil
    end

    def style_available? style
      (::Rouge::Theme.find style) && style
    end

    @@base_style_cache = ::Hash.new do |cache, key|
      base_style = (theme = ::Rouge::Theme.find key).base_style
      (val = base_style[:fg]) && ((style ||= []) << %(color: #{theme.palette val}))
      (val = base_style[:bg]) && ((style ||= []) << %(background-color: #{theme.palette val}))
      @@base_style_cache = cache.merge key => (resolved_base_style = style && (style.join ';'))
      resolved_base_style
    end
    @@stylesheet_cache = ::Hash.new do |cache, key|
      @@stylesheet_cache = cache.merge key => (stylesheet = ((::Rouge::Theme.find key).render scope: BASE_SELECTOR))
      stylesheet
    end

    DEFAULT_STYLE = 'github'
    BASE_SELECTOR = 'pre.rouge'

    private_constant :BASE_SELECTOR
  end

  extend Styles # exports static methods
  include Styles # adds methods to instance
  include Loader # adds methods to instance

  CodeCellStartTagCs = '<td class="code">'

  private_constant :CodeCellStartTagCs
end
end
