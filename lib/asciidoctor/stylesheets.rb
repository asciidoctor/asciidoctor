# frozen_string_literal: true
module Asciidoctor
# A utility class for working with the built-in stylesheets.
#--
# QUESTION create methods for link_*_stylesheet?
# QUESTION create method for user stylesheet?
class Stylesheets
  DEFAULT_STYLESHEET_NAME = 'asciidoctor.css'
  STYLESHEETS_DIR = ::File.join DATA_DIR, 'stylesheets'

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
    @primary_stylesheet_data ||= (::File.read (::File.join STYLESHEETS_DIR, 'asciidoctor-default.css'), mode: FILE_READ_MODE).rstrip
  end

  # Deprecated: Generate code to embed the primary stylesheet
  #
  # Returns the [String] primary stylesheet data wrapped in a <style> tag
  def embed_primary_stylesheet
    %(<style>
#{primary_stylesheet_data}
</style>)
  end

  def write_primary_stylesheet target_dir = '.'
    ::File.write (::File.join target_dir, primary_stylesheet_name), primary_stylesheet_data, mode: FILE_WRITE_MODE
  end

  def coderay_stylesheet_name
    (SyntaxHighlighter.for 'coderay').stylesheet_basename
  end

  # Public: Read the contents of the default CodeRay stylesheet
  #
  # returns the [String] CodeRay stylesheet data
  def coderay_stylesheet_data
    (SyntaxHighlighter.for 'coderay').read_stylesheet
  end

  # Deprecated: Generate code to embed the CodeRay stylesheet
  #
  # Returns the [String] CodeRay stylesheet data wrapped in a <style> tag
  def embed_coderay_stylesheet
    %(<style>
#{coderay_stylesheet_data}
</style>)
  end

  def write_coderay_stylesheet target_dir = '.'
    ::File.write (::File.join target_dir, coderay_stylesheet_name), coderay_stylesheet_data, mode: FILE_WRITE_MODE
  end

  def pygments_stylesheet_name style = nil
    (SyntaxHighlighter.for 'pygments').stylesheet_basename style
  end

  # Public: Generate the Pygments stylesheet with the specified style.
  #
  # returns the [String] Pygments stylesheet data
  def pygments_stylesheet_data style = nil
    (SyntaxHighlighter.for 'pygments').read_stylesheet style
  end

  # Deprecated: Generate code to embed the Pygments stylesheet
  #
  # Returns the [String] Pygments stylesheet data for the specified style wrapped in a <style> tag
  def embed_pygments_stylesheet style = nil
    %(<style>
#{pygments_stylesheet_data style}
</style>)
  end

  def write_pygments_stylesheet target_dir = '.', style = nil
    ::File.write (::File.join target_dir, (pygments_stylesheet_name style)), (pygments_stylesheet_data style), mode: FILE_WRITE_MODE
  end
end
end
