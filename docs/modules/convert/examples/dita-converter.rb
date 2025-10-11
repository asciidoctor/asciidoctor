class DitaConverter < Asciidoctor::Converter::Base
  register_for 'dita'

  def initialize *args
    super
    outfilesuffix '.dita'
  end

  def convert_document node
    <<~EOS.chomp
    <!DOCTYPE topic PUBLIC "-//OASIS//DTD DITA Topic//EN" "topic.dtd">
    <topic>
    <title>#{node.doctitle}</title>
    <body>
    #{node.content}
    </body>
    </topic>
    EOS
  end

  def convert_section node
    <<~EOS.chomp
    <section id="#{node.id}">
    <title>#{node.title}</title>
    #{node.content}
    </section>
    EOS
  end

  def convert_paragraph node
    %(<p>#{node.content}</p>)
  end

  def convert_inline_quoted node
    node.type == :strong ? %(<b>#{node.text}</b>) : node.text
  end
end
