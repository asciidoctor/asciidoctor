module Asciidoctor
# A utility class for working with the built-in stylesheets.
#--
# QUESTION create methods for link_*_stylesheet?
# QUESTION create method for user stylesheet?
class Stylesheets
  DEFAULT_STYLESHEET_NAME = 'asciidoctor.css'
  DEFAULT_PYGMENTS_STYLE = 'default'
  STYLESHEETS_DIR = ::File.join DATA_DIR, 'stylesheets'
  PygmentsBgColorRx = /^\.pygments +\{ *background: *([^;]+);/

  @__instance__ = new

  def self.instance
    @__instance__
  end

  def primary_stylesheet_name
    DEFAULT_STYLESHEET_NAME
  end

  # Public: Read the contents of the default Asciidoctor stylesheet
  #
  # returns the [String] Asciidoctor stylesheet data
  def primary_stylesheet_data
    @primary_stylesheet_data ||= ::File.read(::File.join(STYLESHEETS_DIR, 'asciidoctor-default.css'), mode: FILE_READ_MODE).rstrip
  end

  def embed_primary_stylesheet
    %(<style>
#{primary_stylesheet_data}
</style>)
  end

  def write_primary_stylesheet target_dir = '.'
    ::File.write (::File.join target_dir, primary_stylesheet_name), primary_stylesheet_data, mode: FILE_WRITE_MODE
  end

  def coderay_stylesheet_name
    'coderay-asciidoctor.css'
  end

  # Public: Read the contents of the default CodeRay stylesheet
  #
  # returns the [String] CodeRay stylesheet data
  def coderay_stylesheet_data
    # NOTE use the following lines to load a built-in theme instead
    # unless load_coderay.nil?
    #   ::CodeRay::Encoders[:html]::CSS.new(:default).stylesheet
    # end
    @coderay_stylesheet_data ||= ::File.read(::File.join(STYLESHEETS_DIR, coderay_stylesheet_name), mode: FILE_READ_MODE).rstrip
  end

  def embed_coderay_stylesheet
    %(<style>
#{coderay_stylesheet_data}
</style>)
  end

  def write_coderay_stylesheet target_dir = '.'
    ::File.write (::File.join target_dir, coderay_stylesheet_name), coderay_stylesheet_data, mode: FILE_WRITE_MODE
  end

  def pygments_stylesheet_name style = nil
    %(pygments-#{style || DEFAULT_PYGMENTS_STYLE}.css)
  end

  def pygments_background style = nil
    load_pygments && PygmentsBgColorRx =~ (::Pygments.css '.pygments', style: style || DEFAULT_PYGMENTS_STYLE) ? $1 : nil
  end

  # Public: Generate the Pygments stylesheet with the specified style.
  #
  # returns the [String] Pygments stylesheet data
  def pygments_stylesheet_data style = nil
    if load_pygments
      style ||= DEFAULT_PYGMENTS_STYLE
      (@pygments_stylesheet_data ||= {})[style] ||=
          ((::Pygments.css '.listingblock .pygments', classprefix: 'tok-', style: style) || '/* Failed to load Pygments CSS. */').
          sub('.listingblock .pygments  {', '.listingblock .pygments, .listingblock .pygments code {')
    else
      '/* Pygments CSS disabled. Pygments is not available. */'
    end
  end

  def embed_pygments_stylesheet style = nil
    %(<style>
#{pygments_stylesheet_data style}
</style>)
  end

  def write_pygments_stylesheet target_dir = '.', style = nil
    ::File.write (::File.join target_dir, (pygments_stylesheet_name style)), (pygments_stylesheet_data style), mode: FILE_WRITE_MODE
  end

  #def load_coderay
  #  (defined? ::CodeRay::Duo) ? true : !(Helpers.require_library 'coderay', true, :ignore).nil?
  #end

  def load_pygments
    (defined? ::Pygments::Lexer) ? true : !(Helpers.require_library 'pygments', 'pygments.rb', :ignore).nil?
  end
end
end
