# frozen_string_literal: true
module Asciidoctor
class SyntaxHighlighter::CodeRayAdapter < SyntaxHighlighter::Base
  register_for 'coderay'

  def initialize *args
    super
    @pre_class = 'CodeRay'
    @requires_stylesheet = nil
  end

  def highlight?
    library_available?
  end

  def highlight node, source, lang, opts
    @requires_stylesheet = true if (css_mode = opts[:css_mode]) == :class
    lang = lang ? (::CodeRay::Scanners[lang = lang.to_sym] && lang rescue :text) : :text
    highlighted = ::CodeRay::Duo[lang, :html,
      css: css_mode,
      line_numbers: (line_numbers = opts[:number_lines]),
      line_number_start: opts[:start_line_number],
      line_number_anchors: false,
      highlight_lines: opts[:highlight_lines],
      bold_every: false,
    ].highlight source
    if line_numbers == :table && opts[:callouts]
      [highlighted, (idx = highlighted.index CodeCellStartTagCs) ? idx + CodeCellStartTagCs.length : nil]
    else
      highlighted
    end
  end

  def docinfo? location
    @requires_stylesheet && location == :head
  end

  def docinfo location, doc, opts
    if opts[:linkcss]
      %(<link rel="stylesheet" href="#{doc.normalize_web_path stylesheet_basename, (doc.attr 'stylesdir', ''), false}"#{opts[:self_closing_tag_slash]}>)
    else
      %(<style>
#{read_stylesheet}
</style>)
    end
  end

  def write_stylesheet? doc
    @requires_stylesheet
  end

  def write_stylesheet doc, to_dir
    ::File.write (::File.join to_dir, stylesheet_basename), read_stylesheet, mode: FILE_WRITE_MODE
  end

  module Loader
    private

    def library_available?
      (@@library_status ||= load_library) == :loaded ? true : nil
    end

    def load_library
      (defined? ::CodeRay::Duo) ? :loaded : (Helpers.require_library 'coderay', true, :warn).nil? ? :unavailable : :loaded
    end
  end

  module Styles
    include Loader

    def read_stylesheet
      @@stylesheet_cache ||= (::File.read (::File.join Stylesheets::STYLESHEETS_DIR, stylesheet_basename), mode: FILE_READ_MODE).rstrip
    end

    def stylesheet_basename
      'coderay-asciidoctor.css'
    end
  end

  extend Styles # exports static methods
  include Styles # adds methods to instance
  include Loader # adds methods to instance

  CodeCellStartTagCs = '<td class="code"><pre>'

  private_constant :CodeCellStartTagCs
end
end
