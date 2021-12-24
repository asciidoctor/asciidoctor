class ExtendedPygmentsSyntaxHighlighter < (Asciidoctor::SyntaxHighlighter.for 'pygments')
  register_for :pygments

  def docinfo location, doc, opts
    stylesheet = doc.attr 'pygments-stylesheet', './pygments.css'
    if opts[:linkcss]
      %(<link rel="stylesheet" href="#{stylesheet}"#{opts[:self_closing_tag_slash]}>)
    else
      stylesheet = doc.normalize_system_path stylesheet
      %(<style>
#{doc.read_asset stylesheet, label: 'stylesheet', normalize: true}
</style>)
    end
  end
end
