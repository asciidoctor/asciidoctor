class MyPygmentsAdapter < (Asciidoctor::SyntaxHighlighter.for 'pygments')
  register_for :pygments

  def write_stylesheet? doc
    false
  end

  def docinfo location, doc, opts
    slash = opts[:self_closing_tag_slash]
    %(<link rel="stylesheet" href="/styles/syntax-theme.css"#{slash}>)
  end
end
