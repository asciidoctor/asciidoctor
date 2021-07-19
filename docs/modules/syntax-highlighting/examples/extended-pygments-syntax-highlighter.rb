class ExtendedPygmentsSyntaxHighlighter < (Asciidoctor::SyntaxHighlighter.for 'pygments')
  register_for 'pygments'

  def docinfo? location
    false
  end
end
