class TextConverter
  include Asciidoctor::Converter
  register_for 'text'
  def initialize *args
    super
    outfilesuffix '.txt'
  end
  def convert node, transform = node.node_name, opts = nil
    case transform
    when 'document'
      [node.title, node.content].join(?\n).strip
    when 'section'
      ?\n + [node.title, node.content].join(?\n).rstrip
    when 'paragraph'
      ?\n + normalize_space(node.content)
    when 'ulist', 'olist', 'colist'
      ?\n + node.items.map do |item|
        normalize_space(item.text) + (item.blocks? ? ?\n + item.content : '')
      end.join(?\n)
    when 'dlist'
      ?\n + node.items.map do |terms, dd|
        terms.map(&:text).join(', ') +
          (dd&.text? ? ?\n + normalize_space(dd.text) : '') +
          (dd&.blocks? ? ?\n + dd.content : '')
      end.join(?\n)
    when 'table'
      ?\n + node.rows.th_h.map do |_, rows|
        rows.each do |cells|
          cell.each do |cell|
            cell.content
          end
        end
      end.join(?\n)
    else
      transform.start_with?('inline_') ? node.text : [?\n, node.content].compact.join
    end
  end

  def normalize_space text
    text.tr ?\n, ' '
  end
end
