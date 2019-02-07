# frozen_string_literal: true
module Asciidoctor
class SyntaxHighlighter::PygmentsAdapter < SyntaxHighlighter::Base
  register_for 'pygments'

  def initialize *args
    super
    @requires_stylesheet = nil
    @style = nil
  end

  def highlight?
    library_available?
  end

  def highlight node, source, lang, opts
    lexer = (::Pygments::Lexer.find_by_alias lang) || (::Pygments::Lexer.find_by_mimetype 'text/plain')
    @requires_stylesheet = true unless (noclasses = opts[:css_mode] != :class)
    highlight_opts = {
      classprefix: TOKEN_CLASS_PREFIX,
      cssclass: WRAPPER_CLASS,
      nobackground: true,
      noclasses: noclasses,
      startinline: lexer.name == 'PHP' && !(node.option? 'mixed'),
      stripnl: false,
      style: (@style ||= (style = opts[:style]) && (style_available? style) || DEFAULT_STYLE),
    }
    if (highlight_lines = opts[:highlight_lines])
      highlight_opts[:hl_lines] = highlight_lines.join ' '
    end
    if (linenos = opts[:number_lines]) && (highlight_opts[:linenostart] = opts[:start_line_number]) && (highlight_opts[:linenos] = linenos) == :table
      if (highlighted = lexer.highlight source, options: highlight_opts)
        highlighted = highlighted.sub StyledLinenoColumnStartTagsRx, LinenoColumnStartTagsCs if noclasses
        highlighted = highlighted.sub WrapperTagRx, PreTagCs
        opts[:callouts] ? [highlighted, (idx = highlighted.index CodeCellStartTagCs) ? idx + CodeCellStartTagCs.length : nil] : highlighted
      else
        node.sub_specialchars source # handles nil response from ::Pygments::Lexer#highlight
      end
    elsif (highlighted = lexer.highlight source, options: highlight_opts)
      highlighted = highlighted.gsub StyledLinenoSpanTagRx, LinenoSpanTagCs if linenos && noclasses
      highlighted.sub WrapperTagRx, '\1'
    else
      node.sub_specialchars source # handles nil response from ::Pygments::Lexer#highlight
    end
  end

  def format node, lang, opts
    if opts[:css_mode] != :class && (@style = (style = opts[:style]) && (style_available? style) || DEFAULT_STYLE) &&
        (pre_style_attr_val = base_style @style)
      opts[:transform] = proc {|pre| pre['style'] = pre_style_attr_val }
    end
    super
  end

  def docinfo? location
    @requires_stylesheet && location == :footer
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

  module Loader
    private

    def library_available?
      (@@library_status ||= load_library) == :loaded ? true : nil
    end

    def load_library
      (defined? ::Pygments::Lexer) ? :loaded : (Helpers.require_library 'pygments', 'pygments.rb', :warn).nil? ? :unavailable : :loaded
    end
  end

  module Styles
    include Loader

    def read_stylesheet style
      library_available? ? @@stylesheet_cache[style || DEFAULT_STYLE] || '/* Failed to load Pygments CSS. */' : '/* Pygments CSS disabled because Pygments is not available. */'
    end

    def stylesheet_basename style
      %(pygments-#{style || DEFAULT_STYLE}.css)
    end

    private

    def base_style style
      library_available? ? @@base_style_cache[style || DEFAULT_STYLE] : nil
    end

    def style_available? style
      (((@@available_styles ||= ::Pygments.styles.to_set).include? style) rescue nil) && style
    end

    @@base_style_cache = ::Hash.new do |cache, key|
      if BaseStyleRx =~ @@stylesheet_cache[key]
        @@base_style_cache = cache.merge key => (style = $1.strip)
        style
      end
    end
    @@stylesheet_cache = ::Hash.new do |cache, key|
      if (stylesheet = ::Pygments.css BASE_SELECTOR, classprefix: TOKEN_CLASS_PREFIX, style: key)
        @@stylesheet_cache = cache.merge key => stylesheet
        stylesheet
      end
    end

    DEFAULT_STYLE = 'default'
    BASE_SELECTOR = 'pre.pygments'
    TOKEN_CLASS_PREFIX = 'tok-'

    BaseStyleRx = /^#{BASE_SELECTOR.gsub '.', '\\.'} +\{([^}]+?)\}/

    private_constant :BASE_SELECTOR, :TOKEN_CLASS_PREFIX, :BaseStyleRx
  end

  extend Styles # exports static methods
  include Loader, Styles # adds methods to instance

  CodeCellStartTagCs = '<td class="code">'
  LinenoColumnStartTagsCs = '<td class="linenos"><div class="linenodiv"><pre>'
  LinenoSpanTagCs = '<span class="lineno">\1</span>'
  PreTagCs = '<pre>\1</pre>'
  StyledLinenoColumnStartTagsRx = /<td><div class="linenodiv" style="[^"]+?"><pre style="[^"]+?">/
  StyledLinenoSpanTagRx = %r(<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">( *\d+ )</span>)
  WRAPPER_CLASS = 'lineno' # doesn't appear in output; Pygments appends "table" to this value to make nested table class
  # NOTE <pre> has style attribute when pygments-css=style
  # NOTE <div> has trailing newline when pygments-linenums-mode=table
  # NOTE initial <span></span> preserves leading blank lines
  WrapperTagRx = %r(<div class="#{WRAPPER_CLASS}"><pre\b[^>]*?>(.*)</pre></div>\n*)m

  private_constant :CodeCellStartTagCs, :LinenoColumnStartTagsCs, :LinenoSpanTagCs, :PreTagCs, :StyledLinenoColumnStartTagsRx, :StyledLinenoSpanTagRx, :WrapperTagRx, :WRAPPER_CLASS
end
end
