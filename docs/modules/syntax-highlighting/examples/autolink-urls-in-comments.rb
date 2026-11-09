class ExtendedRougeSyntaxHighlighter < (Asciidoctor::SyntaxHighlighter.for 'rouge')
  register_for 'rouge'

  def create_formatter node, source, lang, opts
    formatter = super
    formatter.singleton_class.prepend (Module.new do
      def safe_span tok, safe_val
        if tok.token_chain[0].matches? ::Rouge::Token::Tokens::Comment
          safe_val = safe_val.gsub(/https?:\/\/\S+/, '<a href="\&">\&</a>')
        end
        super
      end
    end)
    formatter
  end
end
